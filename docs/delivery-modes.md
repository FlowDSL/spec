---
title: Delivery Modes
description: Direct, ephemeral, checkpoint, durable, stream — when to use each.
---

The `delivery.mode` field on an edge controls the transport layer and durability guarantee.

## `direct`

In-process function call. No broker, no serialization. Fastest path.

- **Transport:** in-process
- **Durability:** none
- **Best for:** fast local transforms within the same process

### Protocol resolution

When both nodes share the same language runtime (e.g. Go → Go), `direct` is a
true in-process call. When the source and target run in different languages
(e.g. Go → Python), the runtime transparently upgrades the call to gRPC while
keeping the `direct` delivery semantics (no broker, no durability).

| Source lang | Target lang | Actual transport |
|------------|------------|------------------|
| Same | Same | In-process function call |
| Different | Different | gRPC (transparent upgrade) |

See [Communication Protocols](/docs/reference/grpc-protocol) for all supported protocols.

## `ephemeral`

Redis / NATS / RabbitMQ queue. Survives brief spikes but not process restarts.

- **Transport:** Redis / NATS / RabbitMQ
- **Durability:** low
- **Best for:** burst smoothing, rate-limiting

## `checkpoint`

Mongo / Redis / Postgres backed. Progress is saved at each stage, enabling replay from any point.

- **Transport:** Mongo / Redis / Postgres
- **Durability:** stage-level
- **Best for:** high-throughput pipelines that need replay

## `durable`

Mongo / Postgres backed, packet-level acknowledgement. Every message is persisted before processing begins.

- **Transport:** Mongo / Postgres
- **Durability:** packet-level
- **Best for:** business-critical steps (payments, order fulfilment)

## `stream`

Kafka / Redis / NATS durable stream. Supports fan-out to multiple consumers and external integration.

- **Transport:** Kafka / Redis / NATS
- **Durability:** durable stream
- **Best for:** external integration, fan-out, audit logging

## Choosing a mode

| Scenario | Recommended mode |
|---|---|
| In-process transform | `direct` |
| Queue spikes, low stakes | `ephemeral` |
| Long pipeline, need replay | `checkpoint` |
| Money, orders, legal | `durable` |
| External consumers, fan-out | `stream` |

## Delivery mode vs communication protocol

Delivery mode and communication protocol are two separate concerns:

- **Delivery mode** (on an edge) defines *how packets flow between nodes* — the durability guarantees and buffering strategy.
- **Communication protocol** (on an edge) defines *the wire protocol for a specific connection* — gRPC, NATS, Redis, etc. Nodes declare which protocols they support via `runtime.supports`.

They compose independently. An edge using NATS as its protocol can still have `durable` delivery mode — the runtime handles the translation between the edge's delivery transport and the connection's wire protocol.

See [Communication Protocols](/docs/reference/grpc-protocol) for all 9 supported protocols.
