# AsyncAPI Integration

FlowDSL is a sibling specification to AsyncAPI. AsyncAPI defines external event and message contracts. FlowDSL references those contracts — it never duplicates or re-owns them.

---

## The relationship

```
AsyncAPI document          →   defines external message schemas
FlowDSL document           →   references those schemas via asyncapi#/... $refs
```

This separation means:
- Event producers and consumers stay in sync with their AsyncAPI contract
- FlowDSL flows automatically inherit schema changes from AsyncAPI
- No duplication of Pydantic models, Avro schemas, or JSON Schema definitions

---

## Declaring the AsyncAPI document

Tell FlowDSL where to find the AsyncAPI document using `externalDocs.asyncapi`:

```yaml
externalDocs:
  asyncapi: /asyncapi.json
```

This can be a relative path, an absolute path, or a full URL:

```yaml
externalDocs:
  asyncapi: https://api.mycompany.com/asyncapi.json
```

The runtime uses this URL to resolve `asyncapi#/...` references at load time.

---

## Referencing AsyncAPI messages

Use the `asyncapi#/...` prefix anywhere a `$ref` is accepted in FlowDSL:

### In an entrypoint

```yaml
flows:
  order_pipeline:
    entrypoints:
      - message:
          $ref: "asyncapi#/components/messages/OrderPlaced"
        description: Triggered when an order is placed
```

### In a node input

```yaml
components:
  nodes:
    ValidateOrderNode:
      operationId: validate_order
      inputs:
        - name: OrderPlaced
          message:
            $ref: "asyncapi#/components/messages/OrderPlaced"
```

### In a node output (less common — prefer internal packets for outputs)

```yaml
      outputs:
        - name: OrderConfirmed
          message:
            $ref: "asyncapi#/components/messages/OrderConfirmed"
```

---

## What lives in AsyncAPI vs FlowDSL

| Concern                                      | Where it lives    |
|----------------------------------------------|-------------------|
| External event message schemas               | AsyncAPI          |
| Channel / topic definitions                  | AsyncAPI          |
| Internal typed payloads between nodes        | FlowDSL `components.packets` |
| Delivery semantics (mode, retry, durability) | FlowDSL edge `delivery` |
| Flow graph structure                         | FlowDSL `flows`   |

The rule of thumb: if the schema is consumed or produced by anything outside this FlowDSL document, it belongs in AsyncAPI and is referenced. If it is purely an internal intermediate payload, define it as a FlowDSL packet.

---

## Example AsyncAPI document (minimal)

For reference, here is the AsyncAPI side that a FlowDSL document might reference:

```yaml
asyncapi: "2.6.0"
info:
  title: Order Events
  version: "1.0.0"

components:
  messages:
    OrderPlaced:
      name: OrderPlaced
      payload:
        type: object
        required: [orderId, customerId, total]
        properties:
          orderId:
            type: string
          customerId:
            type: string
          total:
            type: number
            minimum: 0
          placedAt:
            type: string
            format: date-time
```

And the FlowDSL side:

```yaml
flowdsl: "1.0.0"

info:
  title: Order Processing Flow
  version: "1.0.0"

externalDocs:
  asyncapi: /asyncapi.json

flows:
  order_processing:
    entrypoints:
      - message:
          $ref: "asyncapi#/components/messages/OrderPlaced"
    nodes:
      validate_order:
        $ref: "#/components/nodes/ValidateOrderNode"
    edges:
      - from: validate_order
        to: reserve_inventory
        delivery:
          mode: durableQueue
          store: mongo
```

---

## Reference resolution rules

| Prefix        | Resolves to                                      |
|---------------|--------------------------------------------------|
| `asyncapi#/`  | Path within the `externalDocs.asyncapi` document |
| `#/`          | Path within the current FlowDSL document         |
| `openapi#/`   | Path within the `externalDocs.openapi` document  |

The runtime resolves all `asyncapi#/` references at startup. Schema validation tools (e.g. ajv) will treat these as opaque strings — full cross-document resolution requires the FlowDSL runtime or Studio.

---

## redelay integration

If you use redelay (Python/FastAPI), your events are already described in an AsyncAPI document that redelay generates automatically from your Pydantic event classes. See [redelay.md](./redelay.md) for how to connect this to FlowDSL.
