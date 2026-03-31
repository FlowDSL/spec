---
title: Reference
description: Complete field-by-field reference documentation for the FlowDSL specification.
weight: 400
---

Complete specification reference. Use this section when you need the exact type, constraints, and behavior of a specific field.

## Spec reference

| Page | What it covers |
|------|---------------|
| [FlowDSL Document](/docs/reference/spec/flowdsl-document) | Top-level document fields: `flowdsl`, `info`, `nodes`, `edges`, `components` |
| [Flow object](/docs/reference/spec/flow) | Flow-level fields and lifecycle |
| [Node object](/docs/reference/spec/node) | Node fields: `operationId`, `kind`, `inputs`, `outputs`, `settings`, `x-ui` |
| [Edge object](/docs/reference/spec/edge) | Edge fields: `from`, `to`, `delivery`, `when` |
| [DeliveryPolicy](/docs/reference/spec/delivery-policy) | All delivery policy fields by mode |
| [RetryPolicy](/docs/reference/spec/retry-policy) | Retry policy fields and backoff strategies |
| [Components](/docs/reference/spec/components) | `packets`, `events`, `policies`, `nodes` |
| [Packets](/docs/reference/spec/packets) | Packet schema format and reference syntax |
| [Runtime Bindings](/docs/reference/spec/runtime-bindings) | `x-runtime` extension for infrastructure binding |
| [Extensions (x-*)](/docs/reference/spec/extensions) | All supported extension fields |

## Node infrastructure

| Page | What it covers |
|------|---------------|
| [Node Manifest](/docs/reference/node-manifest) | `flowdsl-node.json` format reference |
| [Communication Protocols](/docs/reference/grpc-protocol) | All 9 communication protocols — gRPC, NATS, Kafka, Redis, ZeroMQ, RabbitMQ, WebSocket |
| [Node Registry API](/docs/reference/node-registry-api) | `repo.flowdsl.com` REST API reference |

## Schema

The canonical FlowDSL JSON Schema is available at:

```
https://flowdsl.com/schemas/v1/flowdsl.schema.json
```

Validate a document:

```bash
npx ajv-cli validate \
  -s https://flowdsl.com/schemas/v1/flowdsl.schema.json \
  -d my-flow.flowdsl.yaml
```
