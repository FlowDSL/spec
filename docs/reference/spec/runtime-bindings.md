---
title: Runtime Bindings Reference
description: The x-runtime extension for binding FlowDSL delivery modes to specific infrastructure.
weight: 410
---

Runtime bindings allow you to configure delivery mode infrastructure at the edge level — overriding the runtime's defaults for a specific edge. Use them when you need non-default MongoDB collections, Redis streams, or Kafka topics.

## `x-runtime` extension

```yaml
edges:
  - from: ProcessOrder
    to: NotifyFulfillment
    delivery:
      mode: durable
      packet: OrderProcessed
    x-runtime:
      mongodb:
        collection: orders.fulfillment_queue    # Override default collection name
        writeConcern: majority                   # "majority" or "1"
        readPreference: primaryPreferred

  - from: IngestEvent
    to: ProcessEvent
    delivery:
      mode: ephemeral
      stream: high-priority-events
    x-runtime:
      redis:
        keyPrefix: "flowdsl:hp:"   # Custom key prefix
        maxLen: 1000000
        trimStrategy: maxlen        # "maxlen" or "minid"

  - from: PublishResult
    to: ExternalConsumers
    delivery:
      mode: stream
      topic: results.processed
    x-runtime:
      kafka:
        acks: all                   # "0", "1", or "all"
        compression: lz4            # "none", "gzip", "snappy", "lz4", "zstd"
        batchSize: 16384
        lingerMs: 5
```

## MongoDB binding fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `collection` | string | `{flowId}.packets` | MongoDB collection name |
| `writeConcern` | string | `"1"` | `"1"` or `"majority"` |
| `readPreference` | string | `"primary"` | `"primary"`, `"primaryPreferred"`, `"secondary"` |

## Redis binding fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `keyPrefix` | string | `"flowdsl:"` | Prefix for Redis keys |
| `maxLen` | integer | 100000 | Maximum stream length |
| `trimStrategy` | string | `"maxlen"` | `"maxlen"` or `"minid"` |

## Kafka binding fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `acks` | string | `"1"` | Producer acknowledgment: `"0"`, `"1"`, or `"all"` |
| `compression` | string | `"none"` | Compression codec |
| `batchSize` | integer | 16384 | Producer batch size in bytes |
| `lingerMs` | integer | 0 | Producer linger time in milliseconds |

## When to use runtime bindings

Most flows do not need `x-runtime` — the runtime's defaults are appropriate for the vast majority of use cases.

Use `x-runtime` when:
- You need to use a specific MongoDB collection for compliance or monitoring
- You need Kafka `acks: all` for a specific edge that requires stronger durability
- You are tuning Kafka producer settings for high-throughput edges
- You need to share a Redis stream with non-FlowDSL consumers

## Next steps

- [Extensions reference](/docs/reference/spec/extensions) — all supported extension fields
- [DeliveryPolicy reference](/docs/reference/spec/delivery-policy) — delivery policy fields
- [High-Throughput Pipelines](/docs/guides/high-throughput-pipelines) — performance tuning
