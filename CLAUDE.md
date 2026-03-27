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
schemas/          JSON Schema definitions (Draft-07)
  flowdsl.schema.json     core schema — the full FlowDSL spec
examples/         example .flowdsl.json and .flowdsl.yaml documents
docs/             specification reference and concept guides
```

## Key rules when editing this repo
- JSON Schema lives in schemas/flowdsl.schema.json — Draft-07 format
- All JSON fields use camelCase (e.g. operationId, batchSize, maxInFlight)
- Use $ref for all cross-references — never inline duplicate definitions
- YAML is human-readable presentation format — JSON is canonical
- File extensions: .flowdsl.json and .flowdsl.yaml
- Schema $id: https://flowdsl.com/schemas/v1/flowdsl.schema.json
- Never break backward compatibility within a major version

## Events and packets (FlowDSL-native schema system)

FlowDSL defines its own first-class message types. External schema imports are optional.

### components.events
Named, versioned event definitions. The primary way to define typed messages.
Each event has a name, summary, and a payload (JSON Schema inline or ref to a packet).

```yaml
components:
  events:
    UserCreated:
      summary: Fired when a new user registers
      payload:
        schema:
          type: object
          properties:
            userId: { type: string }
            email:  { type: string }
```

### components.packets
Raw reusable JSON Schema shapes. Referenced by events or directly on node ports.

### MessageRef resolution order
1. `#/components/events/MyEvent`   — FlowDSL-native event (preferred)
2. `#/components/packets/MyPacket` — raw schema shape
3. `asyncapi#/components/messages/...` — external AsyncAPI import (optional, requires externalDocs.asyncapi)
4. `openapi#/components/schemas/...`  — external OpenAPI import (optional, requires externalDocs.openapi)

## Delivery modes (core concept)
- direct — in-process, no persistence, lowest latency
- ephemeralQueue — Redis/NATS, burst smoothing, limited recovery
- checkpoint — stage-level durability, replay from boundary
- durableQueue — packet-level durability, MongoDB, restart-safe
- eventBus — Kafka/Redis pub-sub, external integration and fan-out

## Validation rules to enforce
- flowdsl version field must be present
- info.title and info.version required
- every flow needs at least one entrypoint
- node IDs must be unique within a flow
- edge from/to must reference existing node IDs
- durableQueue edges must define store
- eventBus edges must define eventBus.bus and eventBus.topic
- ephemeralQueue edges must define backend

## Ecosystem context
- flowdsl/website — NuxtJS site at flowdsl.com
- flowdsl/studio — React Flow visual editor (open core)
- flowdsl/flowdsl-go — Go runtime and node SDK
- flowdsl/flowdsl-python — Python SDK + redelay integration
- coded.ai — commercial node marketplace
- clouded.ai — managed workflow hosting
- redelay — Python/FastAPI framework, FlowDSL integration partner

## GitHub org
https://github.com/flowdsl

## Do not
- Do not add runtime implementation code to this repo
- Do not duplicate AsyncAPI or OpenAPI schema structures — reference them via externalDocs
- Do not change field naming convention from camelCase
- Do not remove or rename existing schema fields in v1 (breaking change)
- Do not make FlowDSL depend on AsyncAPI or OpenAPI — they are optional integrations
