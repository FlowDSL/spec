# redelay Integration

[redelay](https://redelay.com) is a Python/FastAPI event framework and the first official FlowDSL integration partner. It connects to FlowDSL via AsyncAPI — redelay auto-generates an AsyncAPI document from your Pydantic event classes, and FlowDSL references that document.

---

## How it connects

```
Python Pydantic events
        ↓
redelay auto-generates AsyncAPI document
        ↓
FlowDSL references asyncapi#/components/messages/...
        ↓
FlowDSL runtime executes the flow graph
```

This means you define your event schemas once — as Pydantic classes in your Python codebase — and both your API documentation (AsyncAPI) and your flow orchestration (FlowDSL) stay in sync automatically.

---

## Step 1 — Define events in redelay

```python
from redelay import event
from pydantic import BaseModel
from datetime import datetime

@event
class OrderPlaced(BaseModel):
    order_id: str
    customer_id: str
    total: float
    placed_at: datetime

@event
class OrderFulfilled(BaseModel):
    order_id: str
    fulfilled_at: datetime
    tracking_number: str
```

redelay registers these events and generates AsyncAPI components automatically.

---

## Step 2 — Export the AsyncAPI document

redelay exposes an AsyncAPI endpoint at `/asyncapi.json` (configurable). You can also export it as a file:

```bash
python -m redelay export-asyncapi --output asyncapi.json
```

The generated document will contain entries like:

```json
{
  "asyncapi": "2.6.0",
  "info": { "title": "Order Service Events", "version": "1.0.0" },
  "components": {
    "messages": {
      "OrderPlaced": {
        "name": "OrderPlaced",
        "payload": {
          "type": "object",
          "properties": {
            "order_id": { "type": "string" },
            "customer_id": { "type": "string" },
            "total": { "type": "number" },
            "placed_at": { "type": "string", "format": "date-time" }
          },
          "required": ["order_id", "customer_id", "total", "placed_at"]
        }
      }
    }
  }
}
```

---

## Step 3 — Reference redelay's AsyncAPI from FlowDSL

Point `externalDocs.asyncapi` at redelay's exported document:

```yaml
flowdsl: "1.0.0"

info:
  title: Order Processing Flow
  version: "1.0.0"

externalDocs:
  asyncapi: /asyncapi.json   # redelay's generated AsyncAPI endpoint
```

Then reference the auto-generated messages in entrypoints and node ports:

```yaml
flows:
  order_fulfillment:
    entrypoints:
      - message:
          $ref: "asyncapi#/components/messages/OrderPlaced"
        description: Triggered when redelay emits an OrderPlaced event
    nodes:
      validate_order:
        $ref: "#/components/nodes/ValidateOrderNode"
      fulfill_order:
        $ref: "#/components/nodes/FulfillOrderNode"
    edges:
      - from: validate_order
        to: fulfill_order
        delivery:
          mode: durableQueue
          store: mongo
```

---

## Step 4 — Implement FlowDSL nodes using redelay

The `flowdsl-python` SDK provides a redelay integration module. Your node handlers are Python classes that redelay can invoke:

```python
from flowdsl.redelay import FlowNode
from pydantic import BaseModel

class OrderValidPacket(BaseModel):
    order_id: str
    total: float
    validated_at: str

class ValidateOrderNode(FlowNode):
    async def handle(self, message: dict) -> OrderValidPacket:
        # message is the deserialized OrderPlaced payload
        return OrderValidPacket(
            order_id=message["order_id"],
            total=message["total"],
            validated_at="2024-01-01T00:00:00Z"
        )
```

The node declares its `operationId` in the FlowDSL document, and the runtime resolves the handler class:

```yaml
components:
  nodes:
    ValidateOrderNode:
      operationId: validate_order
      kind: transform
      runtime:
        language: python
        handler: app.nodes.orders.ValidateOrderNode
        invocation: http
```

---

## go-events: typed Go structs from AsyncAPI

If you have Go services consuming the same events, the `go-events` library reads redelay's AsyncAPI output and generates typed Go structs:

```bash
go-events generate --asyncapi asyncapi.json --out pkg/events/
```

This generates Go structs matching the Pydantic models, closing the type-safety loop across your polyglot stack.

---

## The full integration picture

```
redelay Python service
  └── Pydantic event classes
        └── auto-generates asyncapi.json
              └── referenced by FlowDSL document (asyncapi#/...)
                    └── FlowDSL runtime executes flow nodes
                          └── go-events generates Go structs from the same asyncapi.json
```

One source of truth (Pydantic), three consumers (AsyncAPI docs, FlowDSL flows, Go structs).

---

## Field naming

redelay uses Python `snake_case` for Pydantic fields. The generated AsyncAPI document preserves `snake_case`. FlowDSL payload expressions in `when` conditions and `idempotency.keyExpression` should use the same names:

```yaml
idempotency:
  keyExpression: "input.payload.order_id + ':validate'"
```
