---
title: High-Throughput Pipelines
description: Batching, checkpoint tuning, parallelism, and performance targets for high-volume FlowDSL flows.
weight: 305
---

This guide covers performance optimization for FlowDSL flows processing tens of thousands of events per second. It addresses delivery mode throughput limits, checkpoint tuning, batching, and parallelism.

## Throughput targets by delivery mode

| Mode | Approx. throughput | Limiting factor |
|------|-------------------|----------------|
| `direct` | 500k–1M+ events/sec | CPU, memory bandwidth |
| `ephemeral` | 50k–100k events/sec | Redis / NATS / RabbitMQ throughput |
| `checkpoint` | 5k–20k events/sec | Mongo / Redis / Postgres write throughput |
| `durable` | 2k–10k events/sec | Mongo / Postgres write + index |
| `stream` | 100k+ events/sec | Kafka / NATS throughput |

These are rough targets. Actual throughput depends on payload size, node processing time, hardware, and configuration.

## Design for throughput

### Use `direct` for the hot path

The cheapest, fastest stages should use `direct`. Reserve `durable` and `checkpoint` for stages where durability is genuinely needed:

```yaml
edges:
  # Fast path: parse + validate + filter — all direct
  - from: Ingest
    to: Parse
    delivery: { mode: direct }

  - from: Parse
    to: Validate
    delivery: { mode: direct }

  - from: Validate
    to: Filter
    delivery: { mode: direct }

  # Durability only where needed
  - from: Filter
    to: Enrich
    delivery: { mode: ephemeral, stream: enrich-q }

  - from: Enrich
    to: Store
    delivery:
      mode: durable
      packet: EnrichedEvent
```

### Batch with `checkpoint`

The `batchSize` field on checkpoint edges accumulates N packets before writing to MongoDB. This dramatically reduces MongoDB write operations:

```yaml
edges:
  - from: ParseLog
    to: AggregateMetrics
    delivery:
      mode: checkpoint
      packet: ParsedLog
      batchSize: 1000      # Write checkpoint every 1000 packets — not every 1
      checkpointInterval: 5000  # Also checkpoint every 5000 packets regardless
```

At 10k events/sec with batchSize 1000, MongoDB writes drop from 10k/sec to 10/sec.

### Use `ephemeral` for burst absorption

If upstream produces bursts and downstream is slower, `ephemeral` smooths the rate:

```yaml
edges:
  - from: WebhookReceiver   # Bursty ingest: 0–50k/sec spikes
    to: ProcessEvent        # Steady consumer: 5k/sec
    delivery:
      mode: ephemeral
      stream: event-processing-queue
      maxLen: 500000        # Allow up to 500k buffered events
```

`maxLen` prevents Redis memory exhaustion during sustained overload.

## Parallelism

### Multiple node instances

Run multiple instances of the same node to process in parallel. Each instance registers the same `operationId` — the runtime load-balances:

```yaml
# node-registry.yaml
nodes:
  process_event:
    instances:
      - address: localhost:8080
      - address: localhost:8081
      - address: localhost:8082
    version: "1.0.0"
```

For `ephemeral` edges, the runtime uses Redis consumer groups — multiple instances consume from the same stream without duplicating work.

### Kafka partitioning for `stream`

Kafka scales horizontally through partitioning. More partitions → more consumer instances → higher throughput:

```yaml
edges:
  - from: ProcessOrder
    to: PublishOrderEvent
    delivery:
      mode: stream
      topic: orders.processed
      # Kafka will partition by key automatically
      # Add more partitions via Kafka admin when you need more parallelism
```

## Redis tuning for `ephemeral`

```yaml
# docker-compose.yaml or Redis config
redis:
  command: >
    redis-server
    --save ""              # Disable persistence for max throughput (data is ephemeral)
    --maxmemory 2gb
    --maxmemory-policy allkeys-lru
```

For maximum ephemeral throughput, disable Redis persistence (`--save ""`). Since `ephemeral` provides no durability guarantee, there's no point persisting the stream to disk.

## MongoDB tuning for `checkpoint` and `durable`

```
# MongoDB connection string for high throughput
MONGODB_URI=mongodb://localhost:27017/flowdsl?maxPoolSize=50&minPoolSize=10&maxIdleTimeMS=120000
```

Key MongoDB settings:
- `maxPoolSize: 50` — allow up to 50 concurrent connections from the runtime
- Create indexes on `{flowId}.packets`: `{executionId: 1, nodeId: 1}`
- Use a write concern of `{w: 1}` for checkpoint edges (not `{w: majority}`) to reduce write latency

## Profiling FlowDSL flows

The runtime exposes Prometheus metrics at `/metrics`:

```
# Key metrics to watch
flowdsl_node_duration_seconds{node="ProcessEvent"}     # Node processing time
flowdsl_edge_delivery_duration_seconds{mode="checkpoint"}  # Delivery overhead
flowdsl_queue_depth{stream="enrich-q"}                 # Backlog size
flowdsl_dead_letter_count{flow="pipeline_v2"}          # Error rate
```

Add to your Grafana dashboard and alert on:
- `queue_depth > 100000` (backpressure building)
- `dead_letter_count > 0` (errors requiring attention)
- `node_duration_seconds p99 > 5` (slow nodes)

## Summary

| Technique | When to apply |
|-----------|--------------|
| `direct` for hot path | Always, for cheap deterministic transforms |
| `batchSize` on checkpoint | When writing to MongoDB at >1k events/sec |
| `maxLen` on ephemeral | When upstream can burst beyond downstream capacity |
| Multiple node instances | When a single node is CPU-bound |
| Redis persistence off | For `ephemeral` at maximum throughput |
| MongoDB connection pool | When `durable` write latency is high |

## Next steps

- [Delivery Modes](/docs/concepts/delivery-modes) — mode characteristics and guarantees
- [Stateful vs Streaming](/docs/guides/stateful-vs-streaming) — choosing the right workload model
- [Checkpoints](/docs/concepts/checkpoints) — checkpoint mechanics
