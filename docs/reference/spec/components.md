---
title: Components Reference
description: The components section of a FlowDSL document — packets, events, policies, and node templates.
weight: 409
---

The `components` section holds reusable definitions that can be referenced from the main flow document. It keeps the `nodes` and `edges` sections clean and avoids duplicating schema definitions.

## `components` fields

| Field | Type | Description |
|-------|------|-------------|
| `packets` | object | Map of `PacketName` → JSON Schema object |
| `events` | object | Map of `EventName` → event schema |
| `policies` | object | Map of `PolicyName` → DeliveryPolicy (reusable delivery templates) |
| `nodes` | object | Map of `NodeName` → Node definition (shared node templates) |

## `components.packets`

Define reusable packet schemas:

```yaml
components:
  packets:
    OrderPayload:
      type: object
      properties:
        orderId: { type: string }
        customerId: { type: string }
        total: { type: number }
        currency:
          type: string
          enum: [USD, EUR, GBP]
      required: [orderId, customerId, total, currency]

    PaymentResult:
      type: object
      properties:
        orderId: { type: string }
        chargeId: { type: string }
        status:
          type: string
          enum: [succeeded, failed]
      required: [orderId, chargeId, status]
```

Reference from edges:

```yaml
edges:
  - from: ValidateOrder
    to: ChargePayment
    delivery:
      mode: durable
      packet: OrderPayload    # References components.packets.OrderPayload
```

Packets use JSON Schema Draft-07 and support `$ref` within the `components.packets` namespace:

```yaml
components:
  packets:
    Address:
      type: object
      properties:
        street: { type: string }
        city: { type: string }
        country: { type: string }

    Customer:
      type: object
      properties:
        id: { type: string }
        address:
          $ref: "#/components/packets/Address"
```

## `components.policies`

Reusable delivery policy templates — define once, reference from multiple edges:

```yaml
components:
  policies:
    StandardDurable:
      mode: durable
      retryPolicy:
        maxAttempts: 3
        backoff: exponential
        initialDelay: PT2S
        maxDelay: PT60S
        jitter: true

    LlmDurable:
      mode: durable
      retryPolicy:
        maxAttempts: 3
        backoff: exponential
        initialDelay: PT5S
        maxDelay: PT120S
        retryOn: [RATE_LIMITED, TIMEOUT]
```

Reference from edges:

```yaml
edges:
  - from: ClassifyEmail
    to: SendSms
    delivery:
      $ref: "#/components/policies/StandardDurable"
      packet: AlertPayload
      idempotencyKey: "{{payload.messageId}}-sms"
```

## `components.events`

Native event definitions (distinct from packets — events are published to the event bus):

```yaml
components:
  events:
    OrderProcessed:
      type: object
      properties:
        orderId: { type: string }
        processedAt: { type: string, format: date-time }
      required: [orderId, processedAt]
```

## `components.nodes`

Reusable node templates for common patterns:

```yaml
components:
  nodes:
    StandardLlmNode:
      kind: llm
      settings:
        model: gpt-4o-mini
        temperature: 0.1
        maxTokens: 500
```

## Naming convention

All component names use `PascalCase`: `OrderPayload`, `StandardDurable`, `LlmEmailClassifier`.

## Next steps

- [Packets reference](/docs/reference/spec/packets) — packet schema format details
- [DeliveryPolicy reference](/docs/reference/spec/delivery-policy) — delivery policy fields
- [FlowDSL Document reference](/docs/reference/spec/flowdsl-document) — top-level document
