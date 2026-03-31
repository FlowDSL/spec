---
title: Edge Object Reference
description: Complete field reference for the Edge object in FlowDSL.
weight: 404
---

Edges are declared as an array under the top-level `edges` key. Each edge connects a source node output to a destination node input and carries the delivery policy.

## Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `from` | string | Yes | Source: `"NodeName"` or `"NodeName.outputPort"` |
| `to` | string | Required | Destination: `"NodeName"` or `"NodeName.inputPort"` |
| `delivery` | DeliveryPolicy | Yes | The delivery policy governing this connection |
| `when` | string | No | Condition expression for conditional routing |

## `from` and `to` syntax

| Syntax | Meaning |
|--------|---------|
| `"NodeName"` | Any output/input port (when node has one port) |
| `"NodeName.portName"` | Specific named port |

Named port syntax is required when a node has multiple outputs (router nodes).

## Examples

### Simple edge

```yaml
edges:
  - from: ParseJson
    to: ValidateSchema
    delivery:
      mode: direct
      packet: RawPayload
```

### Named port edge (router)

```yaml
edges:
  - from: PriorityRouter.urgent
    to: UrgentHandler
    delivery:
      mode: durable
      packet: EventPayload

  - from: PriorityRouter.normal
    to: NormalHandler
    delivery:
      mode: ephemeral
      packet: EventPayload
```

### Conditional edge

```yaml
edges:
  - from: ScoreLead
    to: AssignToSalesRep
    when: "payload.score >= 80"
    delivery:
      mode: durable
      packet: ScoredLead

  - from: ScoreLead
    to: AddToNurture
    when: "payload.score < 80"
    delivery:
      mode: durable
      packet: ScoredLead
```

The `when` expression uses a simple predicate syntax evaluated against the packet payload. Supported operators: `==`, `!=`, `>`, `>=`, `<`, `<=`, `&&`, `||`, `!`.

### Edge with retry and idempotency

```yaml
edges:
  - from: PrepareInvoice
    to: SendInvoiceEmail
    delivery:
      mode: durable
      packet: InvoicePayload
      idempotencyKey: "{{payload.invoiceId}}-email"
      retryPolicy:
        maxAttempts: 3
        backoff: exponential
        initialDelay: PT3S
        maxDelay: PT60S
```

## Constraint: edges must form a DAG

FlowDSL documents must be directed acyclic graphs — edges must not form cycles. The validator rejects documents with cycles.

## Next steps

- [DeliveryPolicy reference](/docs/reference/spec/delivery-policy) — delivery policy fields
- [Edges concept](/docs/concepts/edges) — conceptual explanation
- [Node reference](/docs/reference/spec/node) — source and destination nodes
