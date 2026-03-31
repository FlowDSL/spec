---
title: Write a FlowDSL Node in Python
description: Implement, register, and test an LlmAnalyzer node using the flowdsl-py SDK.
weight: 208
---

This tutorial implements the `llm_analyze_email` node from the email triage tutorial using the `flowdsl-py` SDK. By the end you'll have an async Python node that calls OpenAI to classify emails and returns structured output.

## What you'll build

An `LlmAnalyzerNode` that reads an email payload, sends it to an LLM for classification, and returns a structured `AnalysisResult` with classification, confidence score, and reason.

## Prerequisites

- Python 3.10 or later: `python --version`
- `pip` package manager
- An OpenAI API key (or compatible API)

## Step 1: Install the SDK

```bash
pip install flowdsl-py openai
```

## Step 2: Project structure

```
llm-analyzer-node/
├── main.py
├── node.py
├── flowdsl-node.json
└── requirements.txt
```

`requirements.txt`:
```
flowdsl-py>=1.0.0
openai>=1.0.0
```

## Step 3: Implement the node

Create `node.py`:

```python
import json
import time
from typing import Any

from openai import AsyncOpenAI
from flowdsl import BaseNode, NodeInput, NodeOutput, NodeError, ErrorCode


class LlmAnalyzerNode(BaseNode):
    """
    Classifies an email as urgent, normal, or spam using an LLM.

    operationId: llm_analyze_email
    """

    operation_id = "llm_analyze_email"

    def __init__(self) -> None:
        self._client: AsyncOpenAI | None = None
        self._model: str = "gpt-4o-mini"
        self._temperature: float = 0.1
        self._system_prompt: str = self._default_system_prompt()

    async def init(self, settings: dict[str, Any]) -> None:
        """Called once at startup with the node's static settings."""
        self._model = settings.get("model", "gpt-4o-mini")
        self._temperature = settings.get("temperature", 0.1)
        custom_prompt = settings.get("systemPrompt")
        if custom_prompt:
            self._system_prompt = custom_prompt
        self._client = AsyncOpenAI()  # reads OPENAI_API_KEY from env

    async def handle(self, input: NodeInput) -> NodeOutput:
        """Called once per incoming email packet."""
        # Read the input packet from the "in" port
        payload = await input.packet("in")

        message_id = payload.get("messageId", "unknown")
        subject = payload.get("subject", "")
        body = payload.get("body", "")

        if not body and not subject:
            raise NodeError(
                ErrorCode.VALIDATION,
                "Email payload has neither subject nor body",
            )

        # Call the LLM
        result = await self._classify(subject, body, message_id)

        # Build the output AnalysisResult
        output_data = {
            "email": payload.data,
            "classification": result["classification"],
            "confidence": result["confidence"],
            "reason": result.get("reason", ""),
            "analyzedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }

        return NodeOutput().send("out", output_data)

    async def _classify(
        self, subject: str, body: str, message_id: str
    ) -> dict[str, Any]:
        """Calls the LLM and parses the classification response."""
        if self._client is None:
            raise NodeError(ErrorCode.TEMPORARY, "LLM client not initialized")

        prompt = f"Subject: {subject}\n\nBody:\n{body}"

        try:
            response = await self._client.chat.completions.create(
                model=self._model,
                temperature=self._temperature,
                messages=[
                    {"role": "system", "content": self._system_prompt},
                    {"role": "user", "content": prompt},
                ],
                response_format={"type": "json_object"},
            )
        except Exception as e:
            # Check if this is a rate limit error
            if "rate_limit" in str(e).lower():
                raise NodeError(
                    ErrorCode.RATE_LIMITED,
                    f"OpenAI rate limit hit for message {message_id}",
                    original=e,
                )
            raise NodeError(
                ErrorCode.TEMPORARY,
                f"LLM call failed for message {message_id}",
                original=e,
            )

        raw = response.choices[0].message.content
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError as e:
            raise NodeError(
                ErrorCode.TEMPORARY,
                f"LLM returned invalid JSON for message {message_id}: {raw!r}",
                original=e,
            )

        classification = parsed.get("classification", "").lower()
        if classification not in {"urgent", "normal", "spam"}:
            # Treat unexpected classification as normal (safe default)
            classification = "normal"

        return {
            "classification": classification,
            "confidence": float(parsed.get("confidence", 0.5)),
            "reason": parsed.get("reason", ""),
        }

    @staticmethod
    def _default_system_prompt() -> str:
        return """You are an expert support email classifier.
Classify the email as exactly one of: urgent, normal, or spam.

Urgent: production outages, security incidents, data loss, legal issues.
Normal: feature requests, bug reports, billing questions, general support.
Spam: promotional emails, irrelevant content, automated notifications.

Respond with JSON: {"classification": "urgent|normal|spam", "confidence": 0.0-1.0, "reason": "brief explanation"}"""
```

### Key classes

**`BaseNode`** — base class for all FlowDSL nodes. Override:
- `operation_id: str` — class variable, matches the `operationId` in the flow document
- `async def init(self, settings: dict) -> None` — called once at startup with static settings
- `async def handle(self, input: NodeInput) -> NodeOutput` — called once per packet

**`NodeInput`** — input wrapper. Methods:
- `await input.packet(port_name: str) -> Packet` — read a packet from a named input port
- `input.context` — the execution context (flow_id, execution_id, trace headers)

**`Packet`** — the packet wrapper. Properties:
- `packet.data: dict[str, Any]` — the raw underlying dict
- `packet.get(key, default=None)` — read a field with optional default

**`NodeOutput`** — the output builder. Methods:
- `NodeOutput().send(port_name: str, data: dict | Packet) -> NodeOutput` — route to a named port

**`NodeError`** — typed errors for proper runtime handling. ErrorCodes:
- `ErrorCode.VALIDATION` — data problem, not retriable
- `ErrorCode.RATE_LIMITED` — retriable, rate limit
- `ErrorCode.TIMEOUT` — retriable, timeout
- `ErrorCode.TEMPORARY` — retriable, transient failure
- `ErrorCode.PERMANENT` — permanent, move to dead letter

## Step 4: Create the entry point

Create `main.py`:

```python
import asyncio
import logging
import os

from flowdsl import NodeServer
from node import LlmAnalyzerNode


async def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    logger = logging.getLogger("llm-analyzer-node")

    grpc_port = int(os.getenv("FLOWDSL_GRPC_PORT", "50052"))

    server = NodeServer(
        grpc_port=grpc_port,
        manifest_file="flowdsl-node.json",
        logger=logger,
    )
    server.register(LlmAnalyzerNode())

    logger.info("starting llm-analyzer-node gRPC server on port %d", grpc_port)
    await server.serve_grpc()


if __name__ == "__main__":
    asyncio.run(main())
```

The node server starts a gRPC server on port 50052 (default for Python nodes). The runtime connects via the `NodeService` gRPC contract. See [gRPC Protocol](/docs/reference/grpc-protocol) for details.

## Step 5: Write the manifest

Create `flowdsl-node.json`:

```json
{
  "operationId": "llm_analyze_email",
  "name": "LLM Email Analyzer",
  "version": "1.0.0",
  "description": "Classifies support emails as urgent, normal, or spam using an LLM",
  "runtime": "python",
  "inputs": [
    {
      "name": "in",
      "packet": "EmailPayload",
      "description": "The email to classify"
    }
  ],
  "outputs": [
    {
      "name": "out",
      "packet": "AnalysisResult",
      "description": "Classification result with confidence score"
    }
  ],
  "settings": {
    "type": "object",
    "properties": {
      "model": {
        "type": "string",
        "default": "gpt-4o-mini",
        "description": "OpenAI model to use for classification"
      },
      "temperature": {
        "type": "number",
        "default": 0.1,
        "minimum": 0,
        "maximum": 2
      },
      "systemPrompt": {
        "type": "string",
        "description": "Custom system prompt. Uses default if not provided."
      }
    }
  },
  "author": "My Team",
  "license": "Apache-2.0",
  "tags": ["llm", "email", "classification", "nlp"]
}
```

## Step 6: Run the node

```bash
OPENAI_API_KEY=sk-... python main.py
```

```
2026-03-28 10:00:00 INFO llm-analyzer-node starting llm-analyzer-node gRPC server on port 50052
2026-03-28 10:00:00 INFO flowdsl.server registered operation_id=llm_analyze_email
2026-03-28 10:00:00 INFO flowdsl.server listening grpc_port=50052
```

## Step 7: Register with the runtime

Add to `node-registry.yaml`:

```yaml
nodes:
  llm_analyze_email:
    address: localhost:50052
    transport: grpc
    version: "1.0.0"
    runtime: python
```

## Step 8: Testing with pytest

Create `test_node.py`:

```python
import pytest
from unittest.mock import AsyncMock, patch
from flowdsl.testing import MockNodeInput

from node import LlmAnalyzerNode


@pytest.fixture
def node():
    n = LlmAnalyzerNode()
    return n


@pytest.mark.asyncio
async def test_classifies_urgent_email(node):
    await node.init({"model": "gpt-4o-mini"})

    mock_llm_response = '{"classification": "urgent", "confidence": 0.97, "reason": "Production outage"}'

    email_payload = {
        "messageId": "msg-001",
        "from": "user@example.com",
        "subject": "Database is down",
        "body": "Production database is unreachable. All requests failing.",
        "receivedAt": "2026-03-28T10:00:00Z",
    }

    with patch.object(
        node._client.chat.completions,
        "create",
        return_value=AsyncMock(
            choices=[AsyncMock(message=AsyncMock(content=mock_llm_response))]
        ),
    ):
        input_ = MockNodeInput({"in": email_payload})
        output = await node.handle(input_)

    assert output.packets["out"]["classification"] == "urgent"
    assert output.packets["out"]["confidence"] == 0.97
    assert output.packets["out"]["email"]["messageId"] == "msg-001"


@pytest.mark.asyncio
async def test_handles_rate_limit(node):
    from flowdsl import NodeError, ErrorCode

    await node.init({})

    with patch.object(
        node._client.chat.completions,
        "create",
        side_effect=Exception("rate_limit exceeded"),
    ):
        input_ = MockNodeInput({"in": {"messageId": "msg-002", "subject": "test", "body": "test", "receivedAt": "2026-03-28T10:00:00Z"}})

        with pytest.raises(NodeError) as exc_info:
            await node.handle(input_)

        assert exc_info.value.code == ErrorCode.RATE_LIMITED
```

```bash
pip install pytest pytest-asyncio
pytest test_node.py -v
```

## Idempotency in Python nodes

For nodes with external side effects (email sends, ticket creation), implement idempotency by checking the idempotency key before performing the action:

```python
async def handle(self, input: NodeInput) -> NodeOutput:
    payload = await input.packet("in")

    # The runtime passes the idempotency key from the edge policy
    idempotency_key = input.context.idempotency_key

    if idempotency_key:
        # Check if we already processed this key
        already_done = await self._check_idempotency(idempotency_key)
        if already_done:
            # Return the cached result without calling the external API again
            result = await self._get_cached_result(idempotency_key)
            return NodeOutput().send("out", result)

    # Perform the actual operation
    result = await self._send_sms(payload)

    if idempotency_key:
        await self._store_result(idempotency_key, result)

    return NodeOutput().send("out", result)
```

## Summary

| File | Purpose |
|------|---------|
| `node.py` | `LlmAnalyzerNode` implementing `BaseNode` |
| `main.py` | Node server that registers and serves the node |
| `flowdsl-node.json` | Manifest for the registry |
| `test_node.py` | Unit tests with mocked LLM |

## Next steps

- [LLM Flows](/docs/guides/llm-flows) — patterns for building AI agent pipelines
- [Idempotency](/docs/guides/idempotency) — implementing safe idempotent handlers
- [Python SDK Reference](/docs/tools/python-sdk) — full SDK API reference
