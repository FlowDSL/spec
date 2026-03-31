# FlowDSL

**The open specification for describing executable event-driven flow graphs.**

> Nodes define business logic. Edges define delivery semantics. The runtime enforces guarantees.

FlowDSL is a sibling specification to [OpenAPI](https://www.openapis.org/) and [AsyncAPI](https://www.asyncapi.com/), focused on a different concern: **orchestration topology, edge delivery policies, and runtime execution semantics**.

- **OpenAPI** describes HTTP interfaces
- **AsyncAPI** describes event and message interfaces
- **FlowDSL** describes executable flow graphs and runtime guarantees

---

## Why FlowDSL?

Most flow tools force you to choose one transport for everything. FlowDSL lets each **edge** in your graph define its own delivery semantics — so a high-throughput pipeline can use direct in-process handoff between cheap steps, Redis streams for burst smoothing, durable MongoDB queues for expensive LLM calls, and Kafka for external publication — all in a single, readable document.

```yaml
edges:
  - from: rule_filter
    to: dns_check
    delivery:
      mode: direct          # fast, in-process — no persistence needed
      batching:
        batchSize: 1000

  - from: score_preselect
    to: llm_analysis
    when: "output.name == 'DomainShortlisted'"
    delivery:
      mode: durable    # expensive stage — must survive restart
      store: mongo
      retryPolicy:
        $ref: "#/components/policies/llmExpensiveRetry"

  - from: llm_analysis
    to: publish_results
    delivery:
      mode: stream        # publish to external systems via Kafka
      stream:
        bus: kafka
        topic: domains.analyzed
```

---

## Delivery Modes

| Mode | Durability | Replay | Restart-safe | Best for |
|---|---|---|---|---|
| `direct` | none | no | no | fast local transforms |
| `ephemeral` | low | limited | limited | burst smoothing (Redis) |
| `checkpoint` | stage-level | yes | yes from boundary | high-throughput stages |
| `durable` | packet-level | yes | yes | business-critical transitions |
| `stream` | durable stream | yes | yes | external integration, fan-out |

---

## Specification

The FlowDSL specification is defined as a JSON Schema:

```
schemas/
  flowdsl.schema.json     # Core FlowDSL JSON Schema (Draft-07)
```

FlowDSL documents can be written in **JSON** (canonical) or **YAML** (human-readable). The JSON form is always the source of truth for validation and tooling.

### Supported file extensions

- `.flowdsl.json`
- `.flowdsl.yaml` / `.flowdsl.yml`

---

## Quick Start

### Minimal FlowDSL document

```yaml
flowdsl: "1.0.0"

info:
  title: My First Flow
  version: "1.0.0"

externalDocs:
  asyncapi: /asyncapi.json

flows:
  my_flow:
    entrypoints:
      - message:
          $ref: "asyncapi#/components/messages/OrderPlaced"
    nodes:
      validate_order:
        operationId: validate_order
        title: Validate Order
        kind: transform
        runtime:
          language: python
          handler: app.nodes.orders.ValidateOrderNode
          invocation: http
        inputs:
          - message:
              $ref: "asyncapi#/components/messages/OrderPlaced"
        outputs:
          - name: OrderValid
            message:
              $ref: "#/components/packets/ValidOrderPacket"
      notify_fulfillment:
        operationId: notify_fulfillment
        title: Notify Fulfillment
        kind: action
        runtime:
          language: go
          handler: app.nodes.orders.NotifyFulfillmentNode
          invocation: proc
        inputs:
          - name: OrderValid
            message:
              $ref: "#/components/packets/ValidOrderPacket"
        outputs: []
    edges:
      - from: validate_order
        to: notify_fulfillment
        when: "output.name == 'OrderValid'"
        delivery:
          mode: durable
          store: mongo

components:
  packets:
    ValidOrderPacket:
      type: object
      required: [orderId, total]
      properties:
        orderId: { type: string }
        total: { type: number }
```

---

## Examples

```
examples/
  domain-pipeline.flowdsl.json    # High-throughput domain drop catch pipeline
  domain-pipeline.flowdsl.yaml    # Same pipeline in YAML
```

### [Domain Drop Catch Pipeline](examples/domain-pipeline.flowdsl.yaml)
High-throughput pipeline processing 1M+ expiring domains daily. Demonstrates `direct`, `ephemeral`, `durable`, and `stream` delivery modes in a single flow.

### [Work Email Handler](examples/domain-pipeline.flowdsl.yaml)
Stateful workflow for email processing with priority routing, SMS alerts, and LLM summarization. All edges use `durable` for full restart safety.

---

## Node Runtimes

FlowDSL nodes can be implemented in any supported language:

| Language | Invocation modes |
|---|---|
| `go` | `proc`, `http`, `kafka` |
| `python` | `http`, `kafka` |
| `nodejs` | `http`, `kafka` |

---

## Referencing AsyncAPI

FlowDSL references AsyncAPI message schemas instead of duplicating them:

```yaml
inputs:
  - message:
      $ref: "asyncapi#/components/messages/DomainExpiredPayload"
```

Point FlowDSL to your AsyncAPI document via `externalDocs.asyncapi`.

---

## Ecosystem

| Project | Description |
|---|---|
| **FlowDSL** (this repo) | Open specification + JSON Schema |
| **[FlowDSL Studio](https://flowdsl.com/studio)** | Visual editor and flow canvas |
| **Node Catalog** | Community and premium node marketplace *(coming soon)* |
| **Cloud Service** | Managed workflow hosting — deploy and run flows *(coming soon)* |
| **[redelay](https://redelay.com)** | Python/FastAPI framework with native FlowDSL integration |

---

## Repository Structure

```
flowdsl/
├── schemas/
│   └── flowdsl.schema.json       # Core JSON Schema (Draft-07)
├── examples/
│   ├── domain-pipeline.flowdsl.json
│   ├── domain-pipeline.flowdsl.yaml
│   └── email-workflow.flowdsl.yaml
├── docs/
│   ├── specification.md          # Full specification reference
│   ├── concepts.md               # Core concepts guide
│   ├── delivery-modes.md         # Delivery mode reference
│   └── integrations/
│       ├── asyncapi.md
│       ├── redelay.md
│       └── go-events.md
├── CHANGELOG.md
├── CONTRIBUTING.md
└── README.md
```

---

## Versioning

FlowDSL follows semantic versioning. The current version is **1.0.0** (draft).

Schema URL: `https://flowdsl.com/schemas/v1/flowdsl.schema.json`

---

## Contributing

FlowDSL is open source under the Apache 2.0 license. Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

Apache 2.0 — see [LICENSE](LICENSE).
