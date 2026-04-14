---
title: Guides
description: Practical guides for common FlowDSL patterns, decisions, and integrations.
weight: 300
---

Guides cover specific decisions and patterns that don't fit neatly into a tutorial or reference page. They answer "how do I approach X?" rather than "what does X mean?" or "how do I build X step by step?"

## Pages in this section

### [Choosing Delivery Modes](/docs/guides/choosing-delivery-modes)
A decision tree for selecting the right delivery mode for each edge in your flow. Covers the key questions: is data loss acceptable? is this an expensive external call? do you need fan-out?

### [Stateful Workflows vs Streaming Pipelines](/docs/guides/stateful-vs-streaming)
Two fundamentally different workload classes in FlowDSL. Understand which you're building and how it affects your node design, delivery mode choices, and operational patterns.

### [Idempotency](/docs/guides/idempotency)
How to make node handlers safe to retry and replay. Covers `idempotencyKey` configuration, deduplication patterns in Go and Python, and external API idempotency.

### [Error Handling](/docs/guides/error-handling)
Dead letters, retry behavior, circuit breakers, and recovery patterns. How to build flows that degrade gracefully and recover automatically.

### [High-Throughput Pipelines](/docs/guides/high-throughput-pipelines)
Batching, checkpoint interval tuning, parallelism, and performance targets for each delivery mode. For teams moving beyond prototype scale.

### [LLM Flows](/docs/guides/llm-flows)
Building AI agent pipelines with FlowDSL — the right delivery modes, idempotency patterns, cost management, and complete example flows for document intelligence and support automation.

### [AsyncAPI Integration](/docs/guides/asyncapi-integration)
Full guide to the AsyncAPI ↔ FlowDSL integration. Schema referencing, runtime resolution, validation, schema evolution, and breaking change handling.

### [Redelay Integration](/docs/guides/redelay-integration)
How to use [redelay](https://redelay.com) (Python/FastAPI event framework) as a FlowDSL backend, including automatic AsyncAPI generation from Pydantic events.

### [Schema Source of Truth](/docs/guides/schema-source-of-truth)
How to assign each port schema to exactly one authoritative source — OpenAPI, AsyncAPI, or native packets — when your modules already expose both an HTTP API and an event bus. Includes a decision tree and Redelay Go examples.

### [Node Development](/docs/guides/node-development)
How to develop, test, version, and publish FlowDSL nodes. Covers the manifest format, local development workflow, and the node registry.
