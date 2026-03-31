---
title: Getting Started
description: Write your first FlowDSL flow in 5 minutes.
---

FlowDSL describes executable event-driven flow graphs. A flow is a directed graph of **nodes** connected by **edges** with explicit delivery semantics.

## Prerequisites

- An AsyncAPI document describing your event schemas
- The FlowDSL Go or Python SDK installed

## Your first flow

Create a file called `hello.flowdsl.yaml`:

```yaml
flowdsl: "1.0"
info:
  title: Hello FlowDSL
  version: "1.0.0"

asyncapi: "./events.asyncapi.yaml"

nodes:
  Ingest:
    operationId: ingest_event
    description: Receives the incoming event
  Process:
    operationId: process_event
    description: Applies business logic
  Emit:
    operationId: emit_result
    description: Publishes the result

edges:
  - from: Ingest
    to: Process
    delivery:
      mode: direct
      packet: "asyncapi#/components/messages/RawEvent"
  - from: Process
    to: Emit
    delivery:
      mode: durable
      packet: "asyncapi#/components/messages/ProcessedEvent"
```

## Key rules

- Node names use `PascalCase`
- `operationId` values use `snake_case`
- Delivery policy lives on the **edge**, not the node
- AsyncAPI messages are referenced, never duplicated

## Next steps

- [Core Concepts](/docs/concepts)
- [Delivery Modes](/docs/delivery-modes)
- [AsyncAPI Integration](/docs/asyncapi)
