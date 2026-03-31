---
title: AsyncAPI ↔ FlowDSL Integration
description: Full guide to referencing AsyncAPI event contracts in FlowDSL, including schema evolution and breaking change handling.
weight: 307
---

FlowDSL is self-contained but provides first-class support for AsyncAPI integration. If your team maintains AsyncAPI documents describing your event bus, you can reference those schemas directly in FlowDSL instead of duplicating them.

## When to use AsyncAPI integration

Use AsyncAPI references when:
- Your team already maintains AsyncAPI documents for your event bus
- The same event schemas are consumed by multiple systems (not just FlowDSL)
- You want AsyncAPI to remain the single source of truth for event contracts

Use native FlowDSL packets when:
- This flow is the only consumer of these packet schemas
- The schemas are internal to the flow and not published to other teams
- You are early in development and want to iterate quickly

## Setting up the integration

### 1. Link the AsyncAPI document

```yaml
flowdsl: "1.0"
info:
  title: Order Processing
  version: "1.0.0"

# Path or URL to the AsyncAPI document
asyncapi: "./events.asyncapi.yaml"

externalDocs:
  url: https://github.com/myorg/event-schemas/blob/main/asyncapi.yaml
  description: AsyncAPI event schema definitions (v2.6)
```

### 2. Reference AsyncAPI messages

```yaml
nodes:
  OrderReceived:
    operationId: receive_order
    kind: source
    outputs:
      out:
        packet: "asyncapi#/components/messages/OrderPlaced"

edges:
  - from: OrderReceived
    to: ValidateOrder
    delivery:
      mode: durable
      packet: "asyncapi#/components/messages/OrderPlaced"
```

### 3. Mix with native packets

```yaml
components:
  packets:
    # Internal intermediate packet — not in AsyncAPI
    ValidationResult:
      type: object
      properties:
        orderId: { type: string }
        isValid: { type: boolean }
        errors: { type: array, items: { type: string } }
      required: [orderId, isValid]

edges:
  - from: ValidateOrder
    to: ChargePayment
    delivery:
      packet: ValidationResult    # Native packet
```

## Runtime resolution

At startup, the runtime:

1. Reads the `asyncapi` field and loads the document (local file or HTTP URL)
2. For each `asyncapi#/...` reference, extracts the `payload` schema from the referenced message
3. Compiles the resolved JSON Schema for packet validation
4. Validates all packets against their compiled schemas at runtime

If the AsyncAPI document is at an HTTP URL, the runtime fetches it once at startup and caches it:

```yaml
asyncapi: https://api.mycompany.com/asyncapi.yaml
```

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
- Changing `required` arrays

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
# old-flow.flowdsl.yaml
packet: "asyncapi#/components/messages/OrderPlacedV1"

# new-flow.flowdsl.yaml
packet: "asyncapi#/components/messages/OrderPlacedV2"
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
- The `asyncapi` file cannot be found or loaded
- An `asyncapi#/...` JSON Pointer doesn't resolve to a valid message
- The resolved message has no `payload` field

## Summary

- Link AsyncAPI with `asyncapi: "./path/or/url"` at the document level
- Reference messages with `asyncapi#/components/messages/MessageName`
- Mix native and AsyncAPI packets freely
- Version AsyncAPI messages to handle breaking schema changes safely
- Both documents validate independently; FlowDSL also validates reference paths

## Next steps

- [Packets concept](/docs/concepts/packets) — native packet definitions
- [Connecting AsyncAPI tutorial](/docs/tutorials/connecting-asyncapi) — step-by-step integration
- [Redelay Integration](/docs/guides/redelay-integration) — AsyncAPI from Python/FastAPI
