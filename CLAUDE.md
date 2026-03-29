# FlowDSL — spec repo

## What this repo is
The canonical open specification for FlowDSL v1.0.0.
This is the source of truth for the FlowDSL language — the JSON Schema,
examples, and specification documentation.

FlowDSL is its own specification, not a derivative of any other.
It describes executable flow graphs — a concept that OpenAPI and AsyncAPI
do not address. They can be integrated, but are not required.

## Repo structure
```
schemas/
  flowdsl.schema.json           core flow schema (Draft-07)
  flowdsl-node.schema.json      node manifest schema (.flowdsl-node.json)
  flowdsl-registry.schema.json  registry index schema (repo.flowdsl.com)
  node-registry.schema.json     local service registry schema
examples/
  domain-pipeline.flowdsl.json  comprehensive 2-flow example (JSON)
  domain-pipeline.flowdsl.yaml  same example in YAML
  domain-drop-enrichment.flowdsl.yaml   event-driven enrichment pipeline
  webhook-alert.flowdsl.json    webhook → filter → SMS/Slack alerts
  email-triage.flowdsl.json     LLM classifies emails → auto-reply or Slack
  http-to-mongo.flowdsl.json    webhook → HTTP fetch → transform → MongoDB
  kafka-stream-filter.flowdsl.json  Kafka consume → enrich → filter → publish
  db-anomaly-detect.flowdsl.json    Postgres → LLM → severity routing → alerts
  integrations/
    asyncapi-integration.flowdsl.yaml   AsyncAPI integration pattern
  nodes/                        19 reference node manifests (.flowdsl-node.json)
docs/
  concepts.md                   core concepts (flow, node, edge, packet, checkpoint)
  delivery-modes.md             all 5 delivery modes in detail
  getting-started.md            first FlowDSL document tutorial
  node-manifest.md              node manifest format reference
  integrations/
    asyncapi.md                 AsyncAPI integration guide
    redelay.md                  redelay (Python/FastAPI) integration guide
```

## Schema files

### flowdsl.schema.json — core flow schema
Top-level: flowdsl (version), info, servers, externalDocs, flows, components.
All JSON fields use camelCase. Draft-07 format. $ref for cross-references.

### flowdsl-node.schema.json — node manifest
Defines the `.flowdsl-node.json` format for publishing nodes to the registry.
Fields: id (namespace/slug), name, version, kind, language, author, runtime
(handler, invocation, image), inputs/outputs ports, settingsSchema with x-ui extensions.

### flowdsl-registry.schema.json — registry index
Served at `repo.flowdsl.com/registry.json`. Lists all published nodes with
lightweight metadata (id, name, version, summary, kind, language, author, tags).

### node-registry.schema.json — local service registry
Maps operationId → runtime handlers within a service. Supports http/grpc/kafka/proc
invocation modes, deprecation flags, and container images.

## Key rules when editing this repo
- JSON Schema lives in schemas/flowdsl.schema.json — Draft-07 format
- All JSON fields use camelCase (e.g. operationId, batchSize, maxInFlight)
- Use $ref for all cross-references — never inline duplicate definitions
- YAML is human-readable presentation format — JSON is canonical
- File extensions: .flowdsl.json and .flowdsl.yaml
- Schema $id: https://flowdsl.com/schemas/v1/flowdsl.schema.json
- Never break backward compatibility within a major version

## Node kinds (10 enum values)
- source — external system event producer (no inputs)
- transform — reshape/map payload
- router — conditional routing to multiple outputs
- llm — LLM inference
- action — external side effect (write, notify)
- checkpoint — durable state persistence for replay
- publish — event bus publisher
- terminal — flow terminator / data sink (no outputs)
- integration — third-party platform connector
- subworkflow — delegates execution to a child FlowDSL workflow

## Node properties
- operationId (required) — unique snake_case identifier
- kind — semantic category (9 values)
- title, summary, description — documentation
- runtime (required) — language (go/python/nodejs), handler, invocation (proc/http/kafka/grpc), image, version
- inputs / outputs — typed NodePort arrays (name, description, schema)
- execution — timeoutMs, concurrency, maxRetries
- idempotency — enabled, keyExpression, ttlSeconds, store (mongo/redis)
- settings — user-configured key-value pairs
- x-ui — group, icon, color, position, registryId

## Events and packets (FlowDSL-native schema system)

FlowDSL defines its own first-class message types. External schema imports are optional.

### components.events
Named, versioned event definitions with rich metadata.

```yaml
components:
  events:
    UserCreated:
      summary: Fired when a new user registers
      version: "1.0.0"
      entityType: user          # domain entity (snake_case)
      action: created           # event verb (snake_case)
      tags: [user, registration]
      payload:
        schema:
          type: object
          properties:
            userId: { type: string }
            email:  { type: string }
      examples:
        - summary: New user
          value: { userId: "u_123", email: "user@example.com" }
```

Event fields: name, title, summary, description, version, entityType, action, tags, payload (MessageRef), examples.

### components.packets
Raw reusable JSON Schema shapes. Referenced by events or directly on node ports.

### MessageRef resolution order
1. `#/components/events/MyEvent`   — FlowDSL-native event (preferred)
2. `#/components/packets/MyPacket` — raw schema shape
3. `asyncapi#/components/messages/...` — external AsyncAPI import (optional, requires externalDocs.asyncapi)
4. `openapi#/components/schemas/...`  — external OpenAPI import (optional, requires externalDocs.openapi)

## Delivery modes (core concept)
| Mode           | Transport     | Durability     | Best for                     |
|----------------|---------------|----------------|------------------------------|
| direct         | in-process    | none           | fast local transforms        |
| ephemeralQueue | Redis/NATS    | low (volatile) | burst smoothing              |
| checkpoint     | Mongo/Redis   | stage-level    | high-throughput replay       |
| durableQueue   | MongoDB       | packet-level   | business-critical steps      |
| eventBus       | Kafka/Redis   | durable stream | external integration, fan-out|

## DeliveryPolicy full field set
- mode (enum, required)
- backend (for ephemeralQueue — redis, nats, kafka, memory)
- store (for durableQueue/checkpoint — mongo, redis)
- batching — enabled, batchSize, maxWaitMs
- maxInFlight — flow control (integer)
- retryPolicy — inline or $ref to components.policies
- recovery — replayFrom strategy
- eventBus — bus (kafka/redis/nats), topic, partitionKey
- ordering — none | perKey | strict (default: none)
- priority — 0-10 (default: 5)

## Retry policy
- maxAttempts, initialDelayMs
- backoff — fixed | linear | exponential
- maxDelayMs — cap on delay
- deadLetterQueue — boolean (default: true)

## Edge properties
- from, to (required) — source/destination node IDs
- when — optional condition expression (e.g. `output.severity == 'critical'`)
- delivery (required) — DeliveryPolicy object
- packet — $ref to packet/event type
- description — documentation

## Validation rules to enforce
- flowdsl version field must be present
- info.title and info.version required
- every flow needs at least one entrypoint
- node IDs must be unique within a flow
- edge from/to must reference existing node IDs
- durableQueue edges must define store
- eventBus edges must define eventBus.bus and eventBus.topic
- ephemeralQueue edges must define backend

## Examples inventory

### domain-pipeline.flowdsl.json / .yaml
Comprehensive example: 2 flows, 8 nodes, 13 packets.
Demonstrates all 5 delivery modes, batching, idempotency, retry policies,
execution constraints, conditional routing, x-ui styling.
- Flow 1: domain_drop_pipeline (rule_filter → dns_check → score_preselect → llm_analysis → publish_results)
- Flow 2: work_email_handler (priority_router → urgent_sms_alert, llm_summary → ticket_creator)

### domain-drop-enrichment.flowdsl.yaml
Event-driven enrichment pipeline using first-class events (components.events).
All edges use eventBus (Kafka) with partitionKey. Demonstrates fan-out/join pattern.
8 typed events with entityType, action, tags, and examples.

### integrations/asyncapi-integration.flowdsl.yaml
AsyncAPI integration pattern: FlowDSL events wrap asyncapi#/ $refs for stable node ports.
Shows externalDocs.asyncapi referencing external contract while keeping node contracts stable.

### webhook-alert.flowdsl.json
Webhook alert pipeline: 4 nodes (webhook_receiver → severity_filter → slack_notifier / sms_alert).
Demonstrates retryPolicy ($ref to components.policies), idempotency, execution constraints,
conditional routing with `when` expressions, and durableQueue delivery.

### email-triage.flowdsl.json
LLM email triage: 5 nodes (email_fetcher → llm_classifier → intent_router → email_sender / slack_notifier).
Demonstrates LLM kind nodes with execution timeouts, retryPolicy on durableQueue edges,
events (EmailReceived, EmailClassified), and idempotency on terminal nodes.

### http-to-mongo.flowdsl.json
HTTP-to-Mongo sync: 4 nodes (webhook_receiver → http_fetcher → json_transformer → mongo_writer).
Demonstrates checkpoint delivery mode, events (WebhookReceived, RecordSynced),
execution + idempotency on writer node.

### kafka-stream-filter.flowdsl.json
Kafka stream filter: 4 nodes (kafka_consumer → json_transformer → event_filter → kafka_producer).
Demonstrates eventBus delivery with partitionKey, batching on edges, events
(RawEventIngested, EventPublished), execution constraints, and idempotency.

### db-anomaly-detect.flowdsl.json
Database anomaly detection: 5 nodes (postgres_reader → llm_analyzer → severity_router
→ slack_notifier / sms_alert). Demonstrates batching, events (MetricsCollected,
AnomalyDetected), retryPolicy ($ref to components.policies), execution constraints,
and idempotency with different stores (mongo, redis).

### Node manifest examples (19 files in examples/nodes/)
- email-fetcher, webhook-receiver, kafka-consumer, postgres-reader (source)
- json-transformer (transform)
- filter-node, llm-router (router)
- llm-analyzer (llm)
- mongo-writer, slack-notifier, sms-alert, email-sender (action)
- http-fetcher, mongo-reader, kafka-producer, mysql-reader, mysql-writer, postgres-writer (integration/action)
- subworkflow (subworkflow)

All spec manifests carry `x-studio` extensions with Lucide icon names,
Studio colors, and packetPreview for direct consumption by FlowDSL Studio.

## Ecosystem context
- flowdsl/website — NuxtJS site at flowdsl.com (uses spec content as source of truth)
- flowdsl/studio — React Flow visual editor (loads registry + examples from spec)
- flowdsl/flowdsl-go — Go runtime and node SDK
- flowdsl/flowdsl-python — Python SDK + redelay integration
- coded.ai — commercial node marketplace
- clouded.ai — managed workflow hosting
- redelay — Python/FastAPI framework, FlowDSL integration partner

## Spec as source of truth
This repo is the single source of truth for node manifests, example flows,
and specification docs. Other repos consume spec artefacts:
- **Studio** loads `spec/examples/nodes/*.flowdsl-node.json` via Vite @spec alias
  and adapts them to RegistryNode format using `specAdapter.ts`.
  Studio examples import from `spec/examples/*.flowdsl.json`.
- **Website** reads spec docs as a Nuxt content source (prefix `/docs/spec-source/`)
  and serves schemas + examples from public/ via `make sync-spec`.
- **x-studio extensions** on spec manifests carry Studio-specific visual data:
  `lucideIcon`, `color`, `packetPreview` — no separate Studio registry files needed.

## Workflow registry vision (future — v1.1+)

### Goals
Extend FlowDSL to support native repositories of ready-to-use workflows
and nodes. This enables:
- Community-shared workflow templates (like npm for flows)
- Subworkflow composition (parent flows delegate to child workflows)
- coded.ai marketplace backed by the same registry format

### Planned schema additions

#### flowdsl-workflow.schema.json — workflow manifest
Describes a shareable workflow published to the registry.
```
id: "flowdsl/order-fulfillment"   # namespace/slug
name: "Order Fulfillment Pipeline"
version: "1.0.0"
summary: "End-to-end order processing from intake to shipping"
category: "e-commerce"
tags: ["order", "fulfillment", "shipping"]
author: { name: "FlowDSL Team", url: "https://flowdsl.com" }
license: "Apache-2.0"
published: true

# The actual FlowDSL document (embedded or $ref)
document:
  $ref: "./order-fulfillment.flowdsl.json"

# Node dependencies — which registry nodes this workflow requires
requiredNodes:
  - "flowdsl/webhook-receiver"
  - "flowdsl/json-transformer"
  - "flowdsl/mongo-writer"

# Input/output contract for subworkflow embedding
inputs:
  - name: "Order"
    schema: { type: object, properties: { orderId: { type: string } } }
outputs:
  - name: "Result"
    schema: { type: object, properties: { status: { type: string } } }

# Runtime requirements
minRuntimeVersion: "1.0.0"
requiredDeliveryModes: ["durableQueue", "eventBus"]
```

#### Subworkflow node kind
The `subworkflow` kind (already in v1 schemas) enables:
- `workflowRef` — reference to a workflow manifest by ID or URL
- `inputMapping` / `outputMapping` — map parent packet fields to child flow
- `timeoutMs` — overall child execution timeout
- `failOnChildError` — whether parent edge should retry/DLQ on child failure

This creates a composition model: large business processes are assembled
from smaller, tested, versioned sub-workflows.

#### Workflow registry index
Extension of `flowdsl-registry.schema.json` to include workflow entries
alongside node entries. The registry API at `repo.flowdsl.com` will serve both.

### Design principles for workflow registry
1. Workflows are versioned independently of the nodes they contain
2. A workflow manifest MUST declare all required nodes (dependency tree)
3. Subworkflow references use `namespace/slug@version` syntax
4. The runtime resolves workflow refs at flow load time, not at build time
5. Circular subworkflow references are forbidden (detected at validation)
6. Workflow manifests embed or reference the FlowDSL document — never both

## GitHub org
https://github.com/flowdsl

## Do not
- Do not add runtime implementation code to this repo
- Do not duplicate AsyncAPI or OpenAPI schema structures — reference them via externalDocs
- Do not change field naming convention from camelCase
- Do not remove or rename existing schema fields in v1 (breaking change)
- Do not make FlowDSL depend on AsyncAPI or OpenAPI — they are optional integrations
