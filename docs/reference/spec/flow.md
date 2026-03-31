---
title: Flow Object Reference
description: Flow-level fields and structure in a FlowDSL document.
weight: 402
---

In FlowDSL 1.0, the flow graph is described directly at the document root — there is no separate "flow" wrapper object. The `nodes` and `edges` at the top level define the single flow in the document.

Future versions may support multiple flows per document. For now, one document = one flow.

## Flow identity

A flow's identity is derived from its document metadata:

```yaml
info:
  title: Order Fulfillment
  version: "2.1.0"
```

When loaded by the runtime, the flow is addressable as `order_fulfillment` (title converted to `snake_case`) or by an explicit flow ID if configured.

## Flow lifecycle states

| State | Description |
|-------|-------------|
| `draft` | Document written, not yet validated |
| `valid` | Passed schema and semantic validation |
| `deployed` | Loaded by the runtime, nodes connected |
| `active` | Processing events |
| `paused` | Deployed but not accepting new events |
| `archived` | Removed from the runtime |

## Source nodes

Nodes with no incoming edges are source nodes — they are the entry points for the flow. A flow can have multiple source nodes:

```yaml
nodes:
  OrderReceived:      # source: no incoming edge
    operationId: receive_order
    kind: source

  ManualOrderEntry:   # source: no incoming edge
    operationId: receive_manual_order
    kind: source
```

Both `OrderReceived` and `ManualOrderEntry` are entry points. The runtime starts a new execution context for each event arriving at either source.

## Terminal nodes

Nodes with no outgoing edges are terminal nodes — they end the flow:

```yaml
nodes:
  ArchiveLead:
    operationId: archive_lead
    kind: terminal   # No outgoing edges needed

  SpamFolder:
    operationId: move_to_spam
    kind: terminal
```

A flow completes when all active execution paths reach a terminal node (or have no more outgoing edges).

## Execution contexts

Each event that enters a flow through a source node creates an independent execution context. Execution contexts are isolated — they do not share state unless they write to a shared external system (database, Kafka topic).

The runtime assigns each execution context a unique `executionId` for tracing.

## Next steps

- [FlowDSL Document](/docs/reference/spec/flowdsl-document) — top-level document fields
- [Node reference](/docs/reference/spec/node) — node object fields
- [Flows concept](/docs/concepts/flows) — conceptual explanation
