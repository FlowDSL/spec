# Delivery Modes

Delivery mode is set on every edge and controls how data moves from one node to the next. This is the central design principle of FlowDSL: **edges own transport semantics, nodes do not**.

---

## Guarantees at a glance

| Mode            | Transport                   | Durability       | Replay          | Latency  | Best for                              |
|-----------------|-----------------------------|--------------------|-----------------|----------|---------------------------------------|
| `direct`        | In-process                  | None             | No              | Lowest   | Fast, cheap, deterministic transforms |
| `ephemeral`     | Redis / NATS / RabbitMQ  | Low (volatile)   | From checkpoint | Low      | Burst smoothing, backpressure         |
| `checkpoint`    | Mongo / Redis / Postgres    | Stage-level      | From boundary   | Medium   | High-throughput pipelines with replay |
| `durable`       | Mongo / Postgres            | Packet-level     | From any point  | Medium   | Business-critical steps, LLM stages   |
| `stream`        | Kafka / Redis / NATS        | Durable stream   | From offset     | Medium   | External integration, fan-out         |

---

## `direct`

Data is handed off in-process with no persistence, no broker, and no serialization overhead. If the service restarts mid-flight, in-process data is lost — recovery must be defined by a surrounding checkpoint.

**When to use:** CPU-bound transforms, rule filtering, cheap routing steps where throughput matters more than recoverability.

**Required fields:** none beyond `mode`.

```yaml
delivery:
  mode: direct
  maxInFlight: 10000
  batching:
    enabled: true
    batchSize: 1000
    maxWaitMs: 50
```

---

## `ephemeral`

Data is buffered in Redis, NATS, or RabbitMQ. Messages survive brief service restarts within the TTL of the stream, but are not guaranteed across longer outages. Use `recovery` to point back to a durable boundary.

**When to use:** smoothing burst traffic between an inexpensive stage and a slower downstream node; absorbing I/O-bound spikes (e.g. DNS lookups, HTTP calls).

**Required fields:** `backend`

```yaml
delivery:
  mode: ephemeral
  backend: redis
  batching:
    enabled: true
    batchSize: 500
    maxWaitMs: 100
  recovery:
    replayFrom: "checkpoint:ingest"
    strategy: replayFromCheckpoint
```

---

## `checkpoint`

Data is persisted at this boundary and can be replayed from this point. Downstream edges that use `ephemeral` or `direct` can declare this as their `replayFrom` target. Think of checkpoints as durable breadcrumbs.

**When to use:** between logical pipeline stages in high-throughput flows where you want to avoid full replay from the entrypoint on failure.

**Required fields:** `store`

```yaml
delivery:
  mode: checkpoint
  store: mongo   # also: redis, postgres
```

---

## `durable`

Every packet is persisted to a durable store (MongoDB or Postgres) before delivery is acknowledged. The runtime guarantees at-least-once delivery and can resume exactly from the last unacknowledged packet after a restart.

**When to use:** expensive operations (LLM inference, third-party API calls, payment processing) where losing a message has a real cost. Any step where idempotency matters.

**Required fields:** `store`

```yaml
delivery:
  mode: durable
  store: mongo   # also: postgres
  retryPolicy:
    maxAttempts: 5
    initialDelayMs: 2000
    backoff: exponential
    maxDelayMs: 120000
    deadLetterQueue: true
```

---

## `stream`

The message is published to a durable streaming backend (Kafka, Redis Streams, or NATS JetStream). The downstream node is a consumer of that topic — it may live in a different service or be consumed by external systems entirely.

**When to use:** publishing results for external consumers, fan-out to multiple unrelated services, integration with existing Kafka, Redis, or NATS JetStream streams.

**Required fields:** `stream.bus`, `stream.topic`

```yaml
delivery:
  mode: stream
  stream:
    bus: kafka   # also: redis, nats
    topic: orders.completed
    partitionKey: "payload.customerId"
```

---

## Choosing a mode

```
Is the next node in the same process and loss is acceptable?
  → direct

Do you need burst smoothing without full durability?
  → ephemeral (with recovery pointing at a checkpoint)

Is this the boundary after which replay should start?
  → checkpoint

Is this message business-critical — cannot be lost on restart?
  → durable

Does the result need to go to external systems or fan out?
  → stream
```

---

## Combining modes in one flow

A single flow can mix all five modes. Each edge is independently configured. This is the key design advantage of FlowDSL: you pay only for the durability you need, on each individual edge.

```yaml
edges:
  # cheap rule check — direct, fast, no persistence
  - from: rule_filter
    to: dns_check
    delivery:
      mode: direct

  # burst smoothing before slower DNS I/O
  - from: dns_check
    to: scorer
    delivery:
      mode: ephemeral
      backend: redis
      recovery:
        replayFrom: "checkpoint:ingest"
        strategy: replayFromCheckpoint

  # expensive LLM step — must not be lost
  - from: scorer
    to: llm_analysis
    delivery:
      mode: durable
      store: mongo
      retryPolicy:
        maxAttempts: 5
        backoff: exponential

  # publish results externally
  - from: llm_analysis
    to: publisher
    delivery:
      mode: stream
      stream:
        bus: kafka
        topic: results.analyzed
```
