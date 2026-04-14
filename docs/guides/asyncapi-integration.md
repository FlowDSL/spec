---
title: AsyncAPI ↔ FlowDSL Integration
description: Full guide to referencing AsyncAPI event contracts in FlowDSL, including multi-document support, schema evolution, and breaking change handling.
weight: 307
---

FlowDSL is self-contained but provides first-class support for AsyncAPI integration. If your team maintains AsyncAPI documents describing your event bus, you can reference those schemas directly in FlowDSL instead of duplicating them.

## When to use AsyncAPI integration

Use AsyncAPI references when:
- Your team already maintains AsyncAPI documents for your event bus
- The same event schemas are consumed by multiple systems (not just FlowDSL)
- You want AsyncAPI to remain the single source of truth for event contracts

Use native FlowDSL events/packets when:
- This flow is the only consumer of these schemas
- The schemas are internal to the flow and not published to other teams
- You are early in development and want to iterate quickly

## Setting up the integration

### 1. Link the AsyncAPI document

Declare the AsyncAPI document under `externalDocs`:

```yaml
flowdsl: "1.0.0"
info:
  title: Order Processing
  version: "1.0.0"

externalDocs:
  asyncapi: "./events.asyncapi.yaml"
  description: AsyncAPI event schema definitions (v2.6)
```

The `externalDocs.asyncapi` value is either a URL/path string (single document) or a named map for multiple documents (see [Multiple AsyncAPI documents](#multiple-asyncapi-documents) below).

### 2. Reference AsyncAPI messages in events

The recommended pattern is to wrap AsyncAPI message references in a FlowDSL `components.events` definition. This keeps all node ports using stable `#/components/events/...` refs:

```yaml
components:
  events:
    OrderPlaced:
      name: OrderPlaced
      version: "1.0.0"
      entityType: order
      action: placed
      payload:
        $ref: "asyncapi#/components/messages/OrderPlaced"
```

Then reference the event on node ports:

```yaml
flows:
  order_pipeline:
    entrypoints:
      - message:
          $ref: "#/components/events/OrderPlaced"
    nodes:
      validate_order:
        $ref: "#/components/nodes/ValidateOrderNode"
```

### 3. Mix with native events and packets

```yaml
components:
  events:
    # Boundary event — payload owned by AsyncAPI
    OrderPlaced:
      payload:
        $ref: "asyncapi#/components/messages/OrderPlaced"

  packets:
    # Internal packet — not in AsyncAPI
    ValidationResult:
      type: object
      properties:
        orderId: { type: string }
        isValid: { type: boolean }
        errors: { type: array, items: { type: string } }
      required: [orderId, isValid]
```

## Multiple AsyncAPI documents

When your architecture spans multiple services, each with its own AsyncAPI document, use the named map form:

```yaml
externalDocs:
  asyncapi:
    default: "./events.asyncapi.yaml"
    payments: "https://payments.example.com/asyncapi.json"
    inventory: "https://inventory.example.com/asyncapi.json"
```

Reference messages from named documents using the `asyncapi:name#/...` syntax:

```yaml
components:
  events:
    # From the default doc — asyncapi#/...
    OrderPlaced:
      payload:
        $ref: "asyncapi#/components/messages/OrderPlaced"

    # From the 'payments' doc — asyncapi:payments#/...
    PaymentProcessed:
      payload:
        $ref: "asyncapi:payments#/components/messages/PaymentProcessed"

    # From the 'inventory' doc — asyncapi:inventory#/...
    StockReserved:
      payload:
        $ref: "asyncapi:inventory#/components/messages/StockReserved"
```

| `externalDocs.asyncapi` key | `$ref` prefix |
|----------------------------|---------------|
| `default` | `asyncapi#/...` |
| `payments` | `asyncapi:payments#/...` |
| `inventory` | `asyncapi:inventory#/...` |

## Runtime resolution

At startup, the runtime:

1. Reads `externalDocs.asyncapi` and loads the document(s) — local file or HTTP URL
2. For each `asyncapi#/...` or `asyncapi:name#/...` reference, resolves the JSON Pointer in the appropriate document
3. Extracts the `payload` schema from the referenced message
4. Compiles the resolved JSON Schema for type validation

If a document is at an HTTP URL, the runtime fetches it once at startup and caches it.

## Handling schema evolution

### Non-breaking changes (safe)

These AsyncAPI schema changes do not break existing FlowDSL flows:
- Adding optional fields to a message payload
- Adding new messages (that the flow doesn't reference)
- Changing field descriptions or metadata

### Breaking changes (require coordination)

These changes will cause packet validation failures:
- Removing required fields
- Renaming fields
- Changing field types

**Recommended approach:**

1. **Version your AsyncAPI messages.** Add `v2` variants rather than modifying existing ones:

```yaml
components:
  messages:
    OrderPlacedV1:        # Keep existing
      payload: ...
    OrderPlacedV2:        # New version with breaking changes
      payload: ...
```

2. **Version the reference in FlowDSL:**

```yaml
# old event definition
OrderPlaced:
  payload:
    $ref: "asyncapi#/components/messages/OrderPlacedV1"

# new event definition
OrderPlaced:
  payload:
    $ref: "asyncapi#/components/messages/OrderPlacedV2"
```

3. Deploy the new FlowDSL flow before stopping the old one to avoid gaps.

## Validation

Both documents validate independently:

```bash
# Validate the AsyncAPI document
asyncapi validate events.asyncapi.yaml

# Validate the FlowDSL document (also resolves asyncapi# references)
flowdsl validate order-processing.flowdsl.yaml
```

The FlowDSL validator fails if:
- The referenced AsyncAPI file cannot be found or loaded
- An `asyncapi#/...` JSON Pointer doesn't resolve to a valid message
- The resolved message has no `payload` field

## Summary

- Link AsyncAPI with `externalDocs.asyncapi: "./path/or/url"` (single doc) or a named map (multiple docs)
- Reference messages with `asyncapi#/components/messages/MessageName` (default doc) or `asyncapi:name#/...` (named doc)
- Wrap AsyncAPI refs in `components.events` to keep node ports stable
- Mix native and AsyncAPI schemas freely
- Version AsyncAPI messages to handle breaking schema changes safely

## Next steps

- [Packets concept](/docs/concepts/packets) — native packet definitions
- [Connecting AsyncAPI tutorial](/docs/tutorials/connecting-asyncapi) — step-by-step integration
- [Redelay Integration](/docs/guides/redelay-integration) — AsyncAPI from Python/FastAPI
