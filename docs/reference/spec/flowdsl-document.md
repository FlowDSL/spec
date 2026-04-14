---
title: FlowDSL Document Reference
description: Top-level fields of a FlowDSL document.
weight: 401
---

A FlowDSL document is a YAML or JSON file that describes an executable flow graph. This page covers every top-level field.

## Top-level fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `flowdsl` | string | Yes | Specification version. Currently `"1.0.0"`. |
| `info` | Info object | Yes | Document metadata. |
| `externalDocs` | ExternalDocs object | No | Links to external AsyncAPI/OpenAPI spec documents. |
| `servers` | object | No | Named runtime server definitions. |
| `flows` | object | Yes | Map of `flow_id` → Flow object. |
| `components` | Components object | No | Reusable events, packets, nodes, policies. |

## `externalDocs` object

Declare external AsyncAPI or OpenAPI documents to enable `asyncapi#/...` and `openapi#/...` `$ref` syntax on node ports and event payloads. FlowDSL documents are fully functional without this field.

| Field | Type | Description |
|-------|------|-------------|
| `asyncapi` | string \| object | Single URL string, or named map of `{ name: url }` pairs. |
| `openapi` | string \| object | Single URL string, or named map of `{ name: url }` pairs. |
| `description` | string | Optional description. |

### Single-document form (string)

```yaml
externalDocs:
  asyncapi: "./events.asyncapi.yaml"
  openapi: "https://api.example.com/openapi.json"
```

Use with plain `asyncapi#/...` and `openapi#/...` `$ref` paths.

### Named multi-document form (object)

```yaml
externalDocs:
  asyncapi:
    default: "./events.asyncapi.yaml"
    payments: "https://payments.example.com/asyncapi.json"
  openapi:
    default: "/openapi.json"
    billing: "https://billing.example.com/openapi.json"
```

| Key | `$ref` prefix used in the flow |
|-----|--------------------------------|
| `default` | `asyncapi#/...` (same as single-string form) |
| `payments` | `asyncapi:payments#/...` |
| `billing` | `openapi:billing#/...` |

The `default` key lets you keep the unqualified `asyncapi#/...` syntax working alongside named specs:

```yaml
# Message from the default AsyncAPI doc
message:
  $ref: "asyncapi#/components/messages/OrderPlaced"

# Message from the named 'payments' doc
message:
  $ref: "asyncapi:payments#/components/messages/PaymentProcessed"
```

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
flowdsl: "1.0.0"
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
  asyncapi: "./events.asyncapi.yaml"
  description: AsyncAPI event schema definitions

flows:
  order_fulfillment:
    summary: Order fulfillment pipeline
    entrypoints:
      - message:
          $ref: "#/components/events/OrderPlaced"
    nodes:
      order_received:
        $ref: "#/components/nodes/OrderReceivedNode"
      validate_order:
        $ref: "#/components/nodes/ValidateOrderNode"
      charge_payment:
        $ref: "#/components/nodes/ChargePaymentNode"
    edges:
      - from: order_received
        to: validate_order
        delivery:
          mode: direct
      - from: validate_order
        to: charge_payment
        delivery:
          mode: durable
          store: mongo

components:
  events:
    OrderPlaced:
      name: OrderPlaced
      version: "1.0.0"
      payload:
        schema:
          type: object
          properties:
            orderId: { type: string }
            customerId: { type: string }
            total: { type: number }
          required: [orderId, customerId, total]
  nodes:
    OrderReceivedNode:
      operationId: receive_order
      kind: source
      runtime:
        language: go
        handler: nodes.OrderReceivedNode
    ValidateOrderNode:
      operationId: validate_order
      kind: transform
      runtime:
        language: go
        handler: nodes.ValidateOrderNode
    ChargePaymentNode:
      operationId: charge_payment
      kind: action
      runtime:
        language: go
        handler: nodes.ChargePaymentNode
```

## JSON equivalent

```json
{
  "flowdsl": "1.0.0",
  "info": {
    "title": "Order Fulfillment",
    "version": "2.1.0"
  },
  "flows": {
    "order_fulfillment": {
      "entrypoints": [{ "message": { "$ref": "#/components/events/OrderPlaced" } }],
      "nodes": {
        "order_received": { "$ref": "#/components/nodes/OrderReceivedNode" }
      },
      "edges": [
        {
          "from": "order_received",
          "to": "validate_order",
          "delivery": { "mode": "direct" }
        }
      ]
    }
  },
  "components": {
    "events": {
      "OrderPlaced": {
        "name": "OrderPlaced",
        "version": "1.0.0",
        "payload": { "schema": { "type": "object" } }
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
