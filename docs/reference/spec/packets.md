---
title: Packets Reference
description: Packet schema format, reference syntax, and validation in FlowDSL.
weight: 406
---

A packet is a typed schema for data flowing along an edge. Packets use JSON Schema Draft-07 and can be defined natively or referenced from an AsyncAPI document.

## Native packet definition

```yaml
components:
  packets:
    EmailPayload:
      type: object
      title: Email Payload
      description: An incoming email from the support inbox
      properties:
        messageId:
          type: string
          description: Unique email identifier (e.g., IMAP UID)
        from:
          type: string
          format: email
        to:
          type: string
          format: email
        subject:
          type: string
          maxLength: 500
        body:
          type: string
        receivedAt:
          type: string
          format: date-time
        headers:
          type: object
          additionalProperties: true
      required: [messageId, from, subject, body, receivedAt]
      additionalProperties: false
```

## Supported JSON Schema Draft-07 keywords

| Keyword | Supported | Notes |
|---------|-----------|-------|
| `type` | Yes | `string`, `number`, `integer`, `boolean`, `object`, `array`, `null` |
| `properties` | Yes | Object field definitions |
| `required` | Yes | Array of required field names |
| `enum` | Yes | Allowed values |
| `format` | Yes | `email`, `date-time`, `uri`, `uuid` |
| `minimum` / `maximum` | Yes | Number bounds |
| `minLength` / `maxLength` | Yes | String length bounds |
| `pattern` | Yes | Regex pattern |
| `items` | Yes | Array item schema |
| `additionalProperties` | Yes | `true`, `false`, or schema |
| `$ref` | Yes | References within `components.packets` |
| `oneOf` / `anyOf` / `allOf` | Yes | Schema composition |

## `$ref` within components

Reference other packets within the same document:

```yaml
components:
  packets:
    Address:
      type: object
      properties:
        street: { type: string }
        city: { type: string }
        country: { type: string, minLength: 2, maxLength: 2 }
      required: [street, city, country]

    Order:
      type: object
      properties:
        orderId: { type: string }
        shippingAddress:
          $ref: "#/components/packets/Address"
        billingAddress:
          $ref: "#/components/packets/Address"
```

## AsyncAPI packet reference

Reference a message schema from a linked AsyncAPI document:

```yaml
externalDocs:
  asyncapi: "./events.asyncapi.yaml"

components:
  events:
    OrderPlaced:
      payload:
        $ref: "asyncapi#/components/messages/OrderPlaced"
```

The `asyncapi#/...` syntax is a JSON Pointer path into the AsyncAPI document. The runtime resolves it to the message's `payload` schema.

For multiple AsyncAPI documents, use the named form:

```yaml
externalDocs:
  asyncapi:
    default: "./events.asyncapi.yaml"
    payments: "https://payments.example.com/asyncapi.json"

components:
  events:
    PaymentProcessed:
      payload:
        $ref: "asyncapi:payments#/components/messages/PaymentProcessed"
```

## Packet reference on a node port

```yaml
nodes:
  ValidateOrderNode:
    operationId: validate_order
    kind: transform
    runtime:
      language: go
      handler: nodes.ValidateOrderNode
    inputs:
      - message:
          schema:
            $ref: "#/components/packets/OrderPayload"    # Native packet reference
    outputs:
      - name: Validated
        message:
          $ref: "#/components/events/OrderValidated"    # FlowDSL event reference
```

## Naming convention

| Element | Convention |
|---------|-----------|
| Packet names | `PascalCase` |
| Property names | `camelCase` |

## Runtime validation

The runtime validates packets:
1. **At startup:** Verifies all referenced packet names exist.
2. **At runtime:** Validates each packet against its JSON Schema before delivery. Invalid packets are rejected and moved to the dead letter queue with a `VALIDATION` error code.

## Next steps

- [Components reference](/docs/reference/spec/components) — the components section
- [DeliveryPolicy reference](/docs/reference/spec/delivery-policy) — how packets are referenced on edges
- [Packets concept](/docs/concepts/packets) — conceptual explanation
