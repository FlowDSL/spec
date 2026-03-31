---
title: FlowDSL Document Reference
description: Top-level fields of a FlowDSL document.
weight: 401
---

A FlowDSL document is a YAML or JSON file that describes an executable flow graph. This page covers every top-level field.

## Top-level fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `flowdsl` | string | Yes | Specification version. Currently `"1.0"`. |
| `info` | Info object | Yes | Document metadata. |
| `externalDocs` | ExternalDocs object | No | Links to related documentation. |
| `asyncapi` | string | No | Path or URL to an AsyncAPI document for message references. |
| `openapi` | string | No | Path or URL to an OpenAPI document for schema references. |
| `nodes` | object | Yes | Map of `NodeName` → Node object. Node names must be `PascalCase`. |
| `edges` | array | Yes | Array of Edge objects. |
| `components` | Components object | No | Reusable packets, events, policies, and node templates. |

## `info` object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Human-readable name for the flow. |
| `version` | string | Yes | Flow document version (semver recommended). |
| `description` | string | No | Longer description. Supports markdown. |
| `contact` | object | No | `name`, `email`, `url` of the owning team. |
| `license` | object | No | `name` and `url` of the flow's license. |

## Complete example

```yaml
flowdsl: "1.0"
info:
  title: Order Fulfillment
  version: "2.1.0"
  description: |
    Processes customer orders from receipt to shipment confirmation.
    Handles payment, inventory reservation, and customer notification.
  contact:
    name: Platform Team
    email: platform@mycompany.com
  license:
    name: Apache-2.0
    url: https://www.apache.org/licenses/LICENSE-2.0

externalDocs:
  url: https://github.com/mycompany/event-schemas/blob/main/asyncapi.yaml
  description: AsyncAPI event schema definitions

asyncapi: "./events.asyncapi.yaml"

nodes:
  OrderReceived:
    operationId: receive_order
    kind: source
    outputs:
      out: { packet: OrderPayload }

  ValidateOrder:
    operationId: validate_order
    kind: transform
    inputs:
      in: { packet: OrderPayload }
    outputs:
      out: { packet: ValidatedOrder }

  ChargePayment:
    operationId: charge_payment
    kind: action
    inputs:
      in: { packet: ValidatedOrder }
    outputs:
      out: { packet: PaymentResult }

edges:
  - from: OrderReceived
    to: ValidateOrder
    delivery:
      mode: direct
      packet: OrderPayload

  - from: ValidateOrder
    to: ChargePayment
    delivery:
      mode: durable
      packet: ValidatedOrder
      idempotencyKey: "{{payload.orderId}}-charge"

components:
  packets:
    OrderPayload:
      type: object
      properties:
        orderId: { type: string }
        customerId: { type: string }
        total: { type: number }
        currency: { type: string }
      required: [orderId, customerId, total, currency]
```

## JSON equivalent

```json
{
  "flowdsl": "1.0",
  "info": {
    "title": "Order Fulfillment",
    "version": "2.1.0"
  },
  "nodes": {
    "OrderReceived": {
      "operationId": "receive_order",
      "kind": "source",
      "outputs": { "out": { "packet": "OrderPayload" } }
    }
  },
  "edges": [
    {
      "from": "OrderReceived",
      "to": "ValidateOrder",
      "delivery": { "mode": "direct", "packet": "OrderPayload" }
    }
  ],
  "components": {
    "packets": {
      "OrderPayload": {
        "type": "object",
        "properties": {
          "orderId": { "type": "string" }
        }
      }
    }
  }
}
```

## Validation

Validate any FlowDSL document against the JSON Schema:

```bash
# Using ajv-cli
npx ajv-cli validate \
  -s https://flowdsl.com/schemas/v1/flowdsl.schema.json \
  -d my-flow.flowdsl.yaml

# Using the FlowDSL CLI
flowdsl validate my-flow.flowdsl.yaml
```

## Next steps

- [Node reference](/docs/reference/spec/node) — the Node object
- [Edge reference](/docs/reference/spec/edge) — the Edge object
- [DeliveryPolicy reference](/docs/reference/spec/delivery-policy) — delivery configuration
