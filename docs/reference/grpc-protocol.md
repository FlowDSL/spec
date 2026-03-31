---
title: Communication Protocols
description: All communication protocols supported by FlowDSL — gRPC, HTTP, NATS, Kafka, Redis, ZeroMQ, RabbitMQ, and WebSockets.
weight: 430
---

FlowDSL is a language for describing communication between nodes. A node declares the protocols it supports via `runtime.supports` (an array). The specific protocol used for a connection is selected on the **edge** via the `protocol` field.

## Supported protocols

| Protocol | Type | Latency | Throughput | Streaming | Broker required | Best for |
|----------|------|---------|------------|-----------|-----------------|----------|
| **In-Process** | Function call | ~µs | Highest | N/A | No | Same-language transforms |
| **gRPC** | RPC | ~ms | Very high | Bidirectional | No | Cross-language commands, streaming |
| **HTTP** | RPC | ~ms | High | No (polling) | No | Legacy nodes, simple integrations |
| **NATS** | Pub/Sub + RPC | ~ms | Very high | JetStream | Yes (lightweight) | Events, service mesh, request/reply |
| **Kafka** | Streaming | ~10ms | Highest | Continuous | Yes | Data pipelines, audit logs, fan-out |
| **Redis** | Pub/Sub | ~ms | High | Pub/Sub | Yes | Burst smoothing, real-time notifications |
| **ZeroMQ** | Brokerless messaging | ~µs | Very high | Patterns | No | High-perf local messaging, IoT |
| **RabbitMQ** | Message queue | ~ms | High | No | Yes | Workflow routing, dead-letter queues |
| **WebSocket** | Bidirectional stream | ~ms | High | Full-duplex | No | Browser clients, real-time dashboards |

## How to choose

```
Is the node in the same process?
  → proc

Need cross-language RPC?
  → gRPC (default, recommended)

Need pub/sub with request/reply?
  → NATS

Need durable stream processing / event sourcing?
  → Kafka

Need burst smoothing / ephemeral messaging?
  → Redis Pub/Sub

Need high-perf brokerless messaging?
  → ZeroMQ

Need advanced routing / dead-letter queues?
  → RabbitMQ

Need browser-facing real-time updates?
  → WebSocket

Legacy system with HTTP-only API?
  → HTTP (not recommended for new nodes)
```

### Strategic guidance

| Use case | Recommended protocol |
|----------|---------------------|
| Commands (request/response) | gRPC |
| Events (fire-and-forget) | NATS, RabbitMQ |
| Data pipelines (high-throughput) | Kafka |
| Real-time notifications | Redis, WebSocket |
| IoT / embedded | ZeroMQ |
| Browser integration | WebSocket |

---

## In-Process

No network call. The runtime invokes the node as a direct function call within the same process.

```json
{
  "runtime": {
    "supports": ["proc"]
  }
}
```

No configuration needed. This is automatically selected for `direct` delivery mode when source and target share the same language runtime.

---

## gRPC

**Default protocol.** Binary serialization via Protobuf, native bidirectional streaming, automatic code generation.

```json
{
  "runtime": {
    "supports": ["grpc"],
    "grpc": {
      "port": 50051,
      "streaming": true,
      "maxConcurrentStreams": 100,
      "tls": true
    }
  }
}
```

### Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `grpc.port` | integer | `50051` | gRPC listen port |
| `grpc.streaming` | boolean | `false` | Enable `InvokeStream` server-streaming |
| `grpc.maxConcurrentStreams` | integer | — | Max concurrent gRPC streams |
| `grpc.tls` | boolean | — | Require TLS for connections |

### NodeService contract

```protobuf
service NodeService {
  rpc Invoke       (InvokeRequest)  returns (InvokeResponse);
  rpc InvokeStream (InvokeRequest)  returns (stream InvokeResponse);
  rpc Health       (Empty)          returns (HealthResponse);
  rpc Manifest     (Empty)          returns (ManifestResponse);
}
```

| RPC | Description |
|-----|-------------|
| `Invoke` | Unary request/response |
| `InvokeStream` | Server-streaming for LLM and long-running nodes |
| `Health` | Readiness check (`SERVING` / `NOT_SERVING`) |
| `Manifest` | Auto-registration — returns the full node manifest |

### Port conventions

| Language | Default port | Environment variable |
|----------|-------------|---------------------|
| Go | 50051 | `FLOWDSL_GRPC_PORT` |
| Python | 50052 | `FLOWDSL_GRPC_PORT` |
| JavaScript | 50053 | `FLOWDSL_GRPC_PORT` |

### TLS

Enable TLS by setting `grpc.tls: true`. The runtime reads certificate/key from `FLOWDSL_TLS_CERT` and `FLOWDSL_TLS_KEY` environment variables.

---

## HTTP

REST/JSON over HTTP. Supported for legacy integrations but **not recommended** for new nodes.

```json
{
  "runtime": {
    "supports": ["http"]
  }
}
```

HTTP nodes expose a `POST /invoke` endpoint. The runtime sends JSON-serialized packets and expects a JSON response. No streaming support.

---

## NATS

Lightweight, high-performance messaging with pub/sub, request/reply, and queue groups.

```json
{
  "runtime": {
    "supports": ["nats"],
    "nats": {
      "url": "nats://localhost:4222",
      "subject": "flowdsl.nodes.my_node",
      "queueGroup": "workers"
    }
  }
}
```

### Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `nats.url` | string (uri) | — | NATS server URL |
| `nats.subject` | string | — | NATS subject to subscribe/publish on |
| `nats.queueGroup` | string | — | Queue group for load balancing across node instances |

### When to use

- Service mesh communication with request/reply semantics
- Event distribution where message ordering per subject is sufficient
- Lightweight pub/sub without the overhead of Kafka
- Microservice discovery via subjects

---

## Kafka

Durable stream processing with consumer groups, partitioning, and exactly-once semantics.

```json
{
  "runtime": {
    "supports": ["kafka"]
  }
}
```

Kafka transport is also used by the `stream` delivery mode. When a node supports `kafka`, it means the node natively consumes from or produces to Kafka topics. The delivery mode's Kafka usage is configured separately on edges.

### When to use

- High-throughput data pipelines (100K+ msg/sec)
- Event sourcing and audit logging
- Fan-out to multiple consumer groups
- Stream processing with replay capability

---

## Redis Pub/Sub

Fast publish/subscribe over Redis. No message persistence — subscribers must be connected to receive messages.

```json
{
  "runtime": {
    "supports": ["redis"],
    "redis": {
      "url": "redis://localhost:6379",
      "channel": "flowdsl.nodes.my_node"
    }
  }
}
```

### Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `redis.url` | string (uri) | — | Redis server URL |
| `redis.channel` | string | — | Redis channel or pattern to subscribe to |

### When to use

- Real-time notifications where message loss is acceptable
- Cache invalidation events
- Burst smoothing (also used by `ephemeral` delivery mode)
- Simple pub/sub without dedicated message broker infrastructure

---

## ZeroMQ

Brokerless, low-latency messaging library. Runs peer-to-peer without a central broker.

```json
{
  "runtime": {
    "supports": ["zeromq"],
    "zeromq": {
      "address": "tcp://localhost:5555",
      "pattern": "pushPull"
    }
  }
}
```

### Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `zeromq.address` | string | — | ZeroMQ bind/connect address |
| `zeromq.pattern` | string | — | Messaging pattern: `pubSub`, `pushPull`, or `reqRep` |

### Patterns

| Pattern | Description |
|---------|-------------|
| `pubSub` | One-to-many fan-out |
| `pushPull` | Load-balanced work distribution |
| `reqRep` | Synchronous request/reply |

### When to use

- Ultra-low-latency messaging (~µs)
- IoT and embedded systems
- High-frequency data distribution without broker overhead
- In-datacenter node communication

---

## RabbitMQ

Full-featured message broker with exchanges, routing keys, and dead-letter queues.

```json
{
  "runtime": {
    "supports": ["rabbitmq"],
    "rabbitmq": {
      "url": "amqp://localhost:5672",
      "exchange": "flowdsl.nodes",
      "routingKey": "my_node.invoke",
      "queue": "my_node_tasks"
    }
  }
}
```

### Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `rabbitmq.url` | string (uri) | — | AMQP connection URL |
| `rabbitmq.exchange` | string | — | Exchange name |
| `rabbitmq.routingKey` | string | — | Routing key for message routing |
| `rabbitmq.queue` | string | — | Queue name for consuming |

### When to use

- Complex routing logic (topic exchanges, headers routing)
- Dead-letter queues for failed message handling
- Priority queues
- Workflows requiring message acknowledgement and redelivery

---

## WebSocket

Full-duplex bidirectional communication over a single TCP connection.

```json
{
  "runtime": {
    "supports": ["websocket"],
    "websocket": {
      "url": "ws://localhost:8080",
      "path": "/nodes/my_node"
    }
  }
}
```

### Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `websocket.url` | string (uri) | — | WebSocket server URL |
| `websocket.path` | string | — | WebSocket endpoint path |

### When to use

- Browser-facing real-time dashboards
- Live data feeds to frontend clients
- Nodes that need persistent bidirectional connections
- Integration with WebSocket-only external services

---

## Protocol resolution

The runtime resolves the actual transport at deploy time based on the delivery mode and node configuration:

| Delivery mode | Transport resolution |
|---------------|---------------------|
| `direct` (same lang) | In-process function call |
| `direct` (diff lang) | gRPC (transparent upgrade) |
| `ephemeral` | Redis |
| `checkpoint` | MongoDB |
| `durable` | MongoDB |
| `stream` | Kafka |

The `supports` field on a node defines which **communication protocols** the node can use. The flow author selects a specific protocol on each edge via the `protocol` field. The `delivery.mode` on an edge defines the **delivery semantics** — how packets flow between nodes including durability guarantees.

## Next steps

- [Delivery Modes](/docs/delivery-modes) — how delivery modes interact with transport
- [Node Manifest Reference](/docs/reference/node-manifest) — manifest fields including all transport configs
- [Write a Go Node](/docs/tutorials/writing-a-go-node) — full tutorial with gRPC setup
- [Write a Python Node](/docs/tutorials/writing-a-python-node) — Python tutorial
- [Docker Compose Local](/docs/tutorials/docker-compose-local) — running the full stack locally
