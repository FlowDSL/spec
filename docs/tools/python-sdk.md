---
title: Python SDK Reference
description: Reference for the flowdsl-py SDK — implementing FlowDSL nodes in async Python.
weight: 504
---

`flowdsl-py` is the official Python SDK for implementing FlowDSL node handlers. It is built on asyncio and integrates with FastAPI and Pydantic v2.

## Installation

```bash
pip install flowdsl-py
```

## Core classes

### `BaseNode`

```python
from flowdsl import BaseNode, NodeInput, NodeOutput

class MyNode(BaseNode):
    operation_id = "my_operation"   # class variable, matches operationId in flow

    async def init(self, settings: dict) -> None:
        """Called once at startup with static settings from the flow document."""
        self.config = settings.get("key", "default")

    async def handle(self, input: NodeInput) -> NodeOutput:
        """Called once per incoming packet."""
        payload = await input.packet("in")
        result = {"processed": True, "value": payload.get("value")}
        return NodeOutput().send("out", result)
```

### `NodeInput`

```python
class NodeInput:
    async def packet(self, port_name: str) -> Packet
    context: ExecutionContext
```

### `Packet`

```python
class Packet:
    data: dict[str, Any]          # Raw underlying dict

    def get(self, key: str, default=None) -> Any
    def get_str(self, key: str, default: str = "") -> str
    def get_int(self, key: str, default: int = 0) -> int
    def get_float(self, key: str, default: float = 0.0) -> float
    def get_bool(self, key: str, default: bool = False) -> bool
    def get_list(self, key: str, default: list = None) -> list
    def has(self, key: str) -> bool
```

### `NodeOutput`

```python
class NodeOutput:
    def send(self, port_name: str, data: dict | Packet) -> NodeOutput
    # Method chaining for multiple outputs:
    # NodeOutput().send("urgent", urgent_data).send("normal", normal_data)
```

### `NodeError`

```python
from flowdsl import NodeError, ErrorCode

raise NodeError(ErrorCode.RATE_LIMITED, "API rate limit", original=original_exc)
raise NodeError(ErrorCode.TIMEOUT, "Request timed out")
raise NodeError(ErrorCode.VALIDATION, "Missing required field: orderId")
raise NodeError(ErrorCode.TEMPORARY, "Transient service error")
raise NodeError(ErrorCode.PERMANENT, "Unsupported region — will never succeed")
```

### `ExecutionContext`

```python
class ExecutionContext:
    flow_id: str
    execution_id: str
    node_id: str
    idempotency_key: str | None
    trace_headers: dict[str, str]
```

### `NodeServer`

```python
from flowdsl import NodeServer

server = NodeServer(
    port=8082,
    manifest_file="flowdsl-node.json",
    logger=logging.getLogger("my-node"),
)
server.register(MyNode())
await server.serve()
```

## Testing utilities

```python
from flowdsl.testing import MockNodeInput

input_ = MockNodeInput({"in": {"field": "value"}})
output = await node.handle(input_)
assert output.packets["out"]["processed"] == True
```

## Complete example

```python
import asyncio
from flowdsl import BaseNode, NodeInput, NodeOutput, NodeError, ErrorCode, NodeServer

class UppercaseNode(BaseNode):
    operation_id = "uppercase_text"

    async def init(self, settings: dict) -> None:
        self.max_length = settings.get("maxLength", 1000)

    async def handle(self, input: NodeInput) -> NodeOutput:
        payload = await input.packet("in")
        text = payload.get_str("text")
        if not text:
            raise NodeError(ErrorCode.VALIDATION, "text field is required")
        if len(text) > self.max_length:
            raise NodeError(ErrorCode.VALIDATION, f"text exceeds maxLength ({self.max_length})")
        return NodeOutput().send("out", {"text": text.upper(), "originalLength": len(text)})

async def main():
    server = NodeServer(port=8082, manifest_file="flowdsl-node.json")
    server.register(UppercaseNode())
    await server.serve()

if __name__ == "__main__":
    asyncio.run(main())
```

## Next steps

- [Write a Python Node tutorial](/docs/tutorials/writing-a-python-node) — full step-by-step guide
- [LLM Flows guide](/docs/guides/llm-flows) — Python LLM node patterns
