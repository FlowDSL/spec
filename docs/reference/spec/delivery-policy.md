---
title: DeliveryPolicy Reference
description: Complete field-by-field reference for the FlowDSL DeliveryPolicy object.
weight: 407
---

The delivery policy object appears on every edge in a FlowDSL document. It governs how packets travel from the source node to the destination node.

## All fields

| Field | Type | Required | Applies to | Description |
|-------|------|----------|-----------|-------------|
| `mode` | string | Yes | All | Delivery mode: `direct`, `ephemeral`, `checkpoint`, `durable`, `stream` |
| `packet` | string | No | All | Packet type reference: `"PacketName"` or `"asyncapi#/..."` |
| `retryPolicy` | object | No | `durable`, `ephemeral` | Retry configuration |
| `idempotencyKey` | string | No | `durable` | Template for deduplication key |
| `deadLetterQueue` | string | No | `durable`, `ephemeral` | Named dead letter queue |
| `timeout` | string (ISO 8601) | No | `durable`, `ephemeral` | Delivery timeout |
| `priority` | integer (1–10) | No | `durable`, `ephemeral` | Delivery priority |
| `batchSize` | integer | No | `checkpoint` | Packets to accumulate before checkpoint write |
| `checkpointInterval` | integer | No | `checkpoint` | Checkpoint every N packets |
| `topic` | string | No | `stream` | Kafka topic name |
| `consumerGroup` | string | No | `stream` | Kafka consumer group |
| `partitionKey` | string | No | `stream` | Template for Kafka partition key |
| `stream` | string | No | `ephemeral` | Redis stream name |
| `maxLen` | integer | No | `ephemeral` | Redis stream max length |

## Conditional field requirements

| Field | Required for | Notes |
|-------|------------|-------|
| `mode` | All modes | Always required |
| `topic` | `stream` | Required — Kafka topic |
| `stream` | `ephemeral` | Required — Redis stream name |
| `idempotencyKey` | — | Strongly recommended for `durable` with side effects |
| `batchSize` | — | Default 1 for `checkpoint` |

## `direct` example

```yaml
delivery:
  mode: direct
  packet: ParsedEvent
```

No additional fields are relevant for `direct` mode. Delivery is in-process and synchronous.

## `ephemeral` example

```yaml
delivery:
  mode: ephemeral
  packet: EnrichmentInput
  stream: enrichment-queue
  maxLen: 200000
  retryPolicy:
    maxAttempts: 2
    backoff: fixed
    initialDelay: PT1S
  timeout: PT30S
  priority: 5
```

## `checkpoint` example

```yaml
delivery:
  mode: checkpoint
  packet: DocumentChunks
  batchSize: 50
  checkpointInterval: 1000
```

## `durable` example

```yaml
delivery:
  mode: durable
  packet: OrderPayload
  idempotencyKey: "{{payload.orderId}}-charge"
  deadLetterQueue: payment-failures
  timeout: PT60S
  retryPolicy:
    maxAttempts: 5
    backoff: exponential
    initialDelay: PT2S
    maxDelay: PT120S
    jitter: true
    retryOn: [TIMEOUT, RATE_LIMITED, TEMPORARY]
  priority: 8
```

## `stream` example

```yaml
delivery:
  mode: stream
  packet: OrderProcessed
  topic: orders.processed
  consumerGroup: fulfillment-workers
  partitionKey: "{{payload.customerId}}"
```

The `partitionKey` template ensures all events for the same customer are processed in order by the same Kafka partition.

## Field details

### `idempotencyKey`

A Go template string evaluated against each packet. The result is stored in MongoDB to prevent duplicate processing.

```yaml
idempotencyKey: "{{payload.orderId}}-{{operationId}}"
```

Available template variables:
- `{{payload.*}}` — any field from the packet payload
- `{{operationId}}` — the destination node's operationId
- `{{flowId}}` — the current flow ID

Must be unique per logical operation. Reusing keys across different operations causes incorrect deduplication.

### `timeout`

ISO 8601 duration. If the node does not acknowledge the packet within this duration, the packet is considered failed and the retry policy is applied.

| Duration | Meaning |
|----------|---------|
| `PT30S` | 30 seconds |
| `PT5M` | 5 minutes |
| `PT1H` | 1 hour |

### `priority`

Integer 1–10 (10 = highest). Higher priority packets are delivered first when the queue has backlog. Default: 5.

### `deadLetterQueue`

Name of the dead letter collection in MongoDB. Defaults to `{flowId}.dead_letters`. Use named queues to separate errors by type for different monitoring and recovery workflows.

## Next steps

- [Delivery Modes concept](/docs/concepts/delivery-modes) — behavior and guarantees
- [RetryPolicy reference](/docs/reference/spec/retry-policy) — retry field reference
- [Edge reference](/docs/reference/spec/edge) — the full edge object
