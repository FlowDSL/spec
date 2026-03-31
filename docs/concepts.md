---
title: Core Concepts
description: Nodes, edges, delivery modes, and how they fit together.
---

## The flow graph

A FlowDSL document describes a **directed acyclic graph (DAG)**. Nodes are the vertices; edges are the directed connections between them.

```
ValidateOrder → ChargePayment → FulfillOrder → NotifyCustomer
```

The JSON/YAML document is always the source of truth. The visual canvas is a projection.

## Nodes

A node is a unit of business logic. It has no knowledge of how its output is delivered — that is the edge's responsibility.

```yaml
nodes:
  ChargePayment:
    operationId: charge_payment
    description: Charges the customer's payment method
```

**Naming conventions:**
- Node component names → `PascalCase`
- `operationId` values → `snake_case`

## Edges

An edge connects two nodes and carries a **delivery policy**.

```yaml
edges:
  - from: ChargePayment
    to: FulfillOrder
    delivery:
      mode: checkpoint
      packet: "asyncapi#/components/messages/PaymentConfirmed"
```

The `delivery.mode` field determines the transport and durability guarantee.

## Packets

A packet is an AsyncAPI message reference. FlowDSL never duplicates message schemas — it references them:

```yaml
packet: "asyncapi#/components/messages/OrderFulfilled"
```

## The runtime

The FlowDSL runtime reads the graph definition and:

1. Starts each node's handler
2. Wires up the transport layer according to each edge's delivery policy
3. Handles retries, checkpointing, and replay automatically

Your business logic never touches transport code.
