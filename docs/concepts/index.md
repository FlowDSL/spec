---
title: Concepts
description: Core concepts behind the FlowDSL specification.
weight: 100
---

This section covers the core vocabulary and mechanics of the FlowDSL specification. If you are new, read [What is FlowDSL?](/docs/concepts/what-is-flowdsl) first, then work through the pages in order. If you know the basics, jump directly to the concept you need.

## Pages in this section

### [What is FlowDSL?](/docs/concepts/what-is-flowdsl)
FlowDSL as a specification — where it sits in the API ecosystem alongside OpenAPI and AsyncAPI, the four layers of a FlowDSL system, and how a document moves from definition to execution.

### [Flows](/docs/concepts/flows)
A flow is a directed acyclic graph of nodes connected by edges. Covers the top-level document structure, flow lifecycle, and how the runtime loads and runs flows.

### [Nodes](/docs/concepts/nodes)
Nodes are the units of business logic. Covers the nine node kinds, node structure, the bilateral contract model, and the node manifest format.

### [Edges](/docs/concepts/edges)
Edges connect nodes and carry delivery policies. Covers edge structure, named port addressing, conditional routing, and failure behavior.

### [Delivery Modes](/docs/concepts/delivery-modes)
The five delivery modes — `direct`, `ephemeral`, `checkpoint`, `durable`, `stream` — are the most important concept in FlowDSL. Each mode has distinct durability, latency, and replay guarantees.

### [Packets](/docs/concepts/packets)
Packets are typed schemas for the data flowing along edges. Can be defined natively in `components.packets` or referenced from an AsyncAPI document.

### [Retry Policies](/docs/concepts/retry-policies)
Configure automatic retry behavior for failed edge deliveries, with fixed, linear, and exponential backoff support.

### [Checkpoints](/docs/concepts/checkpoints)
The `checkpoint` delivery mode snapshots pipeline state to MongoDB so the runtime can resume from the last successful stage after a failure.

### [Node Registry](/docs/concepts/node-registry)
Where node implementations are published and discovered. Covers `repo.flowdsl.com`, local `node-registry.yaml`, and node resolution.

---

> **Core principle:** Nodes define business logic. Edges define delivery semantics. The runtime enforces guarantees.
