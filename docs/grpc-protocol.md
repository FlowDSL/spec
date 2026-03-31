# Communication Protocols

FlowDSL supports 9 communication protocols for node-to-node communication.
A node declares the protocols it supports via `runtime.supports` (an array).
The specific protocol used for a connection is selected on the **edge** via
the `protocol` field.

## Supported protocols

| Protocol | Type | Latency | Throughput | Streaming | Broker | Best for |
|----------|------|---------|------------|-----------|--------|----------|
| **proc** | Function call | ~µs | Highest | N/A | No | Same-language transforms |
| **gRPC** | RPC | ~ms | Very high | Bidirectional | No | Cross-language commands, streaming |
| **HTTP** | RPC | ~ms | High | No | No | Legacy nodes only |
| **NATS** | Pub/Sub + RPC | ~ms | Very high | JetStream | Yes | Events, service mesh, request/reply |
| **Kafka** | Streaming | ~10ms | Highest | Continuous | Yes | Data pipelines, audit logs, fan-out |
| **Redis** | Pub/Sub | ~ms | High | Pub/Sub | Yes | Burst smoothing, notifications |
| **ZeroMQ** | Brokerless | ~µs | Very high | Patterns | No | High-perf local messaging, IoT |
| **RabbitMQ** | Message queue | ~ms | High | No | Yes | Workflow routing, dead-letter queues |
| **WebSocket** | Bidirectional | ~ms | High | Full-duplex | No | Browser clients, real-time dashboards |

### How to choose

| Use case | Recommended protocol |
|----------|---------------------|
| Commands (request/response) | gRPC |
| Events (fire-and-forget) | NATS, RabbitMQ |
| Data pipelines (high-throughput) | Kafka |
| Real-time notifications | Redis, WebSocket |
| IoT / embedded | ZeroMQ |
| Browser integration | WebSocket |
| Same-process nodes | proc |

---

## gRPC (default)

gRPC + Protobuf is the **recommended** wire protocol for all
cross-language node invocation. HTTP/JSON is still supported but not
recommended due to higher latency, serialization overhead, and increased
security surface.

### Why gRPC

| Concern | HTTP/JSON | gRPC/Protobuf |
|---|---|---|
| Serialization | JSON text parsing | Binary Protobuf (zero-copy) |
| Protocol | HTTP/1.1 | HTTP/2 multiplexed |
| Streaming | SSE workaround | Native first-class |
| Type safety | Runtime-only validation | Compile-time generated stubs |
| Security surface | REST API endpoints | Internal mesh, no public surface |
| Latency overhead | ~1–5 ms | ~0.1–0.5 ms |

> HTTP is still used for the public-facing FlowDSL API and website.
> gRPC replaces HTTP only for internal node-to-node communication.

## Protocol resolution for `direct` edges

When an edge uses the `direct` delivery mode and no explicit `protocol`
is set, the runtime resolves the wire protocol based on the language
pair of connected nodes:

| Source language | Target language | Resolution |
|---|---|---|
| Go | Go (proc) | Direct function call — zero overhead |
| Go | Python | gRPC to `flowdsl-nodes-py:50052` |
| Go | Node.js | gRPC to `flowdsl-nodes-js:50053` |
| Python | Go | gRPC to `flowdsl-nodes-go:50051` |
| Python | Python | gRPC to `flowdsl-nodes-py:50052` |
| Python | Node.js | gRPC to `flowdsl-nodes-js:50053` |
| Node.js | Go | gRPC to `flowdsl-nodes-go:50051` |
| Node.js | Python | gRPC to `flowdsl-nodes-py:50052` |
| Node.js | Node.js | gRPC to `flowdsl-nodes-js:50053` |

Only Go → Go within the runtime binary qualifies for `proc`.
All other combinations use gRPC.

## NodeService interface

The canonical contract lives in `spec/schemas/node.proto`.
All three SDKs (Go, Python, Node.js) must implement the `NodeService`.

### RPCs

**Invoke** — standard single-response call. Used for all
non-streaming nodes. The runtime sends a `NodeRequest` and receives
a `NodeResponse` containing the output port name and payload.

**InvokeStream** — streaming call for LLM and long-running nodes.
Returns a stream of `NodeStreamChunk` messages with `ChunkType`:
- `DELTA` — partial data (LLM token, progress update)
- `DONE` — stream complete, final `NodeResponse` is populated
- `ERROR` — stream failed, error message is populated

**Health** — the runtime polls this for readiness checks and
load-based routing. Returns a `load` value (0–100) used for
balancing across node replicas.

**Manifest** — the node self-describes its `flowdsl-node.json`.
The runtime calls this on startup for auto-registration. Eliminates
the need for manual `node-registry.yaml` entries.

## Self-registration via Manifest RPC

On startup, the runtime connects to each configured node server and:

1. Calls `Health()` to verify the server is ready.
2. Calls `Manifest("")` (empty operation_id) to retrieve all node
   manifests hosted by that server.
3. Registers each manifest in the internal node registry.
4. The node is now available for flow execution.

This replaces the previous `node-registry.yaml` approach. Node servers
are self-describing.

## Port conventions

| Port | Server | Language |
|---|---|---|
| 50051 | `flowdsl-nodes-go` | Go |
| 50052 | `flowdsl-nodes-py` | Python |
| 50053 | `flowdsl-nodes-js` | Node.js |

These are conventions, not hard requirements. Production deployments
may use service discovery (Consul, Kubernetes DNS) instead.

## Implementing NodeService

### Go

```go
type MyNode struct{}

func (n *MyNode) Invoke(
    ctx context.Context,
    req *nodev1.NodeRequest,
) (*nodev1.NodeResponse, error) {
    var payload MyInputPayload
    json.Unmarshal(req.Payload, &payload)

    result := n.process(payload)

    out, _ := json.Marshal(result)
    return &nodev1.NodeResponse{
        OutputName: "MyOutput",
        Payload:    out,
    }, nil
}
```

### Python

```python
class MyNode(BaseNode):
    operation_id = "my_operation"

    async def handle(
        self,
        request: NodeRequest,
        context: grpc.ServicerContext,
    ) -> NodeResponse:
        payload = json.loads(request.payload)
        result = await self.process(payload)
        return NodeResponse(
            output_name="MyOutput",
            payload=json.dumps(result).encode(),
        )
```

### Node.js

```typescript
const myNode: NodeHandler = {
    operationId: 'my_operation',
    async invoke(request: NodeRequest): Promise<NodeResponse> {
        const payload = JSON.parse(request.payload.toString())
        const result = await process(payload)
        return {
            outputName: 'MyOutput',
            payload: Buffer.from(JSON.stringify(result)),
        }
    },
}
```

## Streaming nodes (LLM)

LLM nodes implement `InvokeStream` instead of (or in addition to) `Invoke`.
The node sends `DELTA` chunks as tokens arrive from the model, then a final
`DONE` chunk with the complete `NodeResponse`.

The FlowDSL Studio live monitor displays streaming progress in real time
by subscribing to the chunk stream.

Set `runtime.grpc.streaming: true` in the node manifest to advertise
streaming support.

---

## HTTP

REST/JSON over HTTP. Supported for legacy integrations but **not recommended**
for new nodes. No streaming support. Higher latency and serialization overhead.

```yaml
runtime:
  supports:
    - http
```

---

## NATS

Lightweight, high-performance pub/sub with request/reply and queue groups.
Ideal for service mesh patterns and event distribution.

```yaml
runtime:
  supports:
    - nats
  nats:
    url: "nats://localhost:4222"
    subject: "flowdsl.nodes.my_node"
    queueGroup: "workers"
```

| Field | Type | Description |
|-------|------|-------------|
| `nats.url` | string (uri) | NATS server URL |
| `nats.subject` | string | NATS subject to subscribe/publish on |
| `nats.queueGroup` | string | Queue group for load balancing |

---

## Kafka

Durable stream processing with consumer groups, partitioning, and
exactly-once semantics. Also used by the `stream` delivery mode.

```yaml
runtime:
  supports:
    - kafka
```

When a node supports `kafka`, it natively consumes from or
produces to Kafka topics. The delivery mode's Kafka usage is configured
separately on edges.

---

## Redis Pub/Sub

Fast publish/subscribe over Redis. No message persistence — subscribers
must be connected to receive messages.

```yaml
runtime:
  supports:
    - redis
  redis:
    url: "redis://localhost:6379"
    channel: "flowdsl.nodes.my_node"
```

| Field | Type | Description |
|-------|------|-------------|
| `redis.url` | string (uri) | Redis server URL |
| `redis.channel` | string | Redis channel or pattern |

---

## ZeroMQ

Brokerless, low-latency messaging. Runs peer-to-peer without a central broker.
Supports multiple messaging patterns.

```yaml
runtime:
  supports:
    - zeromq
  zeromq:
    address: "tcp://localhost:5555"
    pattern: pushPull
```

| Field | Type | Description |
|-------|------|-------------|
| `zeromq.address` | string | ZeroMQ bind/connect address |
| `zeromq.pattern` | enum | `pubSub`, `pushPull`, or `reqRep` |

---

## RabbitMQ

Full-featured message broker with exchanges, routing keys, and dead-letter queues.

```yaml
runtime:
  supports:
    - rabbitmq
  rabbitmq:
    url: "amqp://localhost:5672"
    exchange: "flowdsl.nodes"
    routingKey: "my_node.invoke"
    queue: "my_node_tasks"
```

| Field | Type | Description |
|-------|------|-------------|
| `rabbitmq.url` | string (uri) | AMQP connection URL |
| `rabbitmq.exchange` | string | Exchange name |
| `rabbitmq.routingKey` | string | Routing key |
| `rabbitmq.queue` | string | Queue name |

---

## WebSocket

Full-duplex bidirectional communication over a single TCP connection.

```yaml
runtime:
  supports:
    - websocket
  websocket:
    url: "ws://localhost:8080"
    path: "/nodes/my_node"
```

| Field | Type | Description |
|-------|------|-------------|
| `websocket.url` | string (uri) | WebSocket server URL |
| `websocket.path` | string | WebSocket endpoint path |

---

## Protocol vs Delivery Mode

These are two separate concerns:

- **Protocol** (on an edge) — the wire protocol used for a specific connection between two nodes
- **Delivery mode** (on an edge) — how packets flow between nodes with durability guarantees

A node declares which protocols it supports via `runtime.supports`. The flow
author then picks one of the common protocols on each edge. They compose
independently — an edge using NATS as its protocol can still have `durable`
delivery mode.
