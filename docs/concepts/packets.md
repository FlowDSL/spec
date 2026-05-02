---
title: Packets
description: Packets are the typed data schemas for data flowing along edges in FlowDSL.
weight: 106
---

A packet is a typed schema that describes the data traveling along an edge. Every edge optionally declares a `packet` type in its delivery policy — the runtime uses this to validate the shape of data passing between nodes and to generate documentation in Studio.

## Native packets

Define packets directly in your FlowDSL document under `components.packets`. Each packet is a JSON Schema Draft-07 object:

```yaml
components:
  packets:
    OrderPayload:
      type: object
      properties:
        orderId:
          type: string
          description: Unique order identifier
        customerId:
          type: string
        items:
          type: array
          items:
            type: object
            properties:
              sku: { type: string }
              qty: { type: integer, minimum: 1 }
              price: { type: number }
            required: [sku, qty, price]
        total:
          type: number
          minimum: 0
        currency:
          type: string
          enum: [USD, EUR, GBP]
      required: [orderId, customerId, items, total, currency]

    PaymentResult:
      type: object
      properties:
        orderId: { type: string }
        chargeId: { type: string }
        status:
          type: string
          enum: [succeeded, failed, pending]
        amount: { type: number }
      required: [orderId, chargeId, status]
```

Reference a packet from an edge:

```yaml
edges:
  - from: ValidateOrder
    to: ChargePayment
    delivery:
      mode: durable
      packet: OrderPayload    # References components.packets.OrderPayload
```

## AsyncAPI-referenced packets

When you have an existing AsyncAPI document, reference its message schemas directly instead of duplicating them:

```yaml
# In your FlowDSL document
asyncapi: "./events.asyncapi.yaml"

edges:
  - from: OrderReceived
    to: ProcessOrder
    delivery:
      mode: durable
      packet: "asyncapi#/components/messages/OrderPlaced"
```

The runtime resolves the reference by loading the AsyncAPI document and extracting the message schema at the given JSON Pointer path. The packet is validated at runtime against the resolved schema.

## Namespaced refs (Redelay / Studio convention)

When a project loads multiple specs (typical Redelay setup: an
`/openapi.json` + an `/asyncapi.json` + the document's own packets),
refs need a namespace so the resolver knows which spec to consult.
Studio + Redelay use the form `<spec-name>#/components/...`:

| Form | Resolved against |
|---|---|
| `#/components/packets/UserCreateInput` | The flow document's own `components.packets` |
| `openapi:default#/components/schemas/UserCreateInput` | The project's `/openapi.json` |
| `asyncapi:default#/components/schemas/UserCreatedPayload` | The project's `/asyncapi.json` |

The `:default` suffix names the spec instance — projects with
multiple loaded OpenAPI documents (e.g. an internal-API spec + a
public-API spec) can disambiguate via different names. The vast
majority use only `:default`.

::callout{icon="i-lucide-info"}
**Namespace stripping at OpenAPI emission.** When Redelay emits a
flow's packet ref into `/openapi.json` (e.g. as a request-body
schema for a flow-driven HTTP endpoint), the dispatcher strips the
`openapi:default#` namespace so the published ref is a
standards-compliant local in-document ref:
`{"$ref": "#/components/schemas/UserCreateInput"}`. Without this,
Scalar / Swagger UI / SDK generators fail with
`Could not resolve reference: Failed to fetch`.
::

## Packet naming

| Convention | Correct | Incorrect |
|-----------|---------|-----------|
| PascalCase | `OrderPayload`, `EmailMessage` | `orderPayload`, `email_message` |
| Descriptive | `ClassifiedEmail` | `Payload`, `Data` |
| Role-specific | `SmsAlertInput`, `SmsAlertOutput` | `SmsPayload` (ambiguous) |

## Validation

The runtime validates packets at each edge:
- **At startup:** Verifies that all referenced packet names exist in `components.packets` or can be resolved from the referenced AsyncAPI document.
- **At runtime:** Validates each packet against its JSON Schema before delivery. Invalid packets are rejected and moved to the dead letter queue.

## When to define packets

Define a packet when:
- Multiple edges share the same schema (reuse the name)
- The schema is complex enough to benefit from a named definition
- You want Studio to show the packet structure in the NodeContractCard

Omit the `packet` field when:
- The edge is using `direct` mode between two nodes you control and schema validation is handled inside the node
- You are early in development and the schema is still evolving

## Summary

- Packets are JSON Schema Draft-07 objects defined under `components.packets`.
- Reference them by name on edge delivery policies.
- Or reference AsyncAPI messages using `asyncapi#/components/messages/MessageName`.
- PascalCase naming convention for all packet names.

## Next steps

- [Edges](/docs/concepts/edges) — how packets are used on edges
- [Connecting AsyncAPI](/docs/tutorials/connecting-asyncapi) — referencing AsyncAPI schemas
- [Components reference](/docs/reference/spec/components) — full components section reference
