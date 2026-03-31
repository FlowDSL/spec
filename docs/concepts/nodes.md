---
title: Nodes
description: The nine node kinds, node structure, the bilateral contract model, and the node manifest.
weight: 103
---

A node is the unit of business logic in a FlowDSL flow. It has a clearly defined **contract** — named input ports and named output ports, each carrying a specific packet type. The runtime calls the node with the input packet and routes the output packet to the next node according to the edge's delivery policy. Nodes are stateless with respect to transport — they never touch Kafka, Redis, or MongoDB directly.

## Node kinds

FlowDSL defines nine node kinds that describe a node's role in the flow:

| Kind | Role | Typical use |
|------|------|------------|
| `source` | Entry point — no inputs, only outputs | Webhook receiver, event consumer, scheduler |
| `transform` | Maps input to output with the same or different schema | Field extraction, format conversion, computation |
| `router` | Routes packets to one of several named outputs based on content | Priority routing, conditional branching, A/B split |
| `llm` | Calls a language model | Classification, summarization, extraction, generation |
| `action` | Performs a side effect in an external system | Send email, charge payment, create ticket, call API |
| `checkpoint` | Saves pipeline state and passes through | Resumable pipeline stage marker |
| `publish` | Publishes to an event bus or message broker | Emit to Kafka, push to webhook |
| `terminal` | End of a path — no outputs | Archive, discard, log final result |
| `integration` | Bridges to an external FlowDSL flow | Cross-flow composition |

## Node structure

```yaml
nodes:
  FilterByPriority:
    operationId: filter_by_priority    # snake_case, matches the handler function
    kind: router
    summary: Routes events by priority level
    description: |
      Reads the priority field from the incoming payload and routes to
      urgent_out for P0/P1 events, or normal_out for all others.

    inputs:
      in:
        packet: EventPayload
        description: Incoming event to classify

    outputs:
      urgent_out:
        packet: EventPayload
        description: P0 and P1 events
      normal_out:
        packet: EventPayload
        description: P2 and below events

    settings:
      urgentPriorities: [P0, P1]

    x-ui:
      position: { x: 320, y: 180 }
      color: "#7c3aed"
      icon: filter
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `operationId` | string | Yes | Unique `snake_case` identifier. Maps to the handler function registered in the runtime. |
| `kind` | string | Yes | One of the nine node kinds. |
| `summary` | string | No | One-line description for Studio and documentation. |
| `description` | string | No | Longer markdown description. |
| `inputs` | object | No | Map of port name → Port object. |
| `outputs` | object | No | Map of port name → Port object. |
| `settings` | object | No | Static configuration passed to the handler at initialization. |
| `x-ui` | object | No | Canvas layout hints for Studio (position, color, icon). |

### Port object

```yaml
inputs:
  in:
    packet: EmailPayload      # Reference to components.packets or asyncapi#/...
    description: The email to analyze
```

A port has a `packet` (packet type reference) and an optional `description`.

## The bilateral contract

The visual representation of a node in Studio and on the spec page is a **bilateral contract card** — a dark card showing the node's input ports on the left and output ports on the right. This makes the node's contract immediately readable: what goes in, what comes out, and what types are involved.

This is unique to FlowDSL. OpenAPI shows endpoints; AsyncAPI shows channels; FlowDSL shows executable bilateral contracts.

```
┌──────────────────────────────────────────────────────┐
│  [transform]  transform_order_fields                  │
│  TransformOrder — Extracts and normalizes order data  │
├────────────────────────┬─────────────────────────────┤
│  INPUTS                │  OUTPUTS                    │
│                        │                             │
│  in  OrderPayload  ───►│►───  out  NormalizedOrder   │
└────────────────────────┴─────────────────────────────┘
```

## Node examples by kind

### source

```yaml
OrderReceived:
  operationId: receive_order
  kind: source
  summary: Receives new order events
  outputs:
    out:
      packet: OrderPayload
```

### transform

```yaml
NormalizeOrder:
  operationId: normalize_order_fields
  kind: transform
  summary: Normalizes currency and address fields
  inputs:
    in: { packet: RawOrder }
  outputs:
    out: { packet: NormalizedOrder }
```

### router

```yaml
RouteByStatus:
  operationId: route_order_by_status
  kind: router
  summary: Routes orders to the correct processing path
  inputs:
    in: { packet: Order }
  outputs:
    approved: { packet: Order }
    pending_review: { packet: Order }
    rejected: { packet: Order }
```

### llm

```yaml
ClassifyEmail:
  operationId: llm_classify_email
  kind: llm
  summary: Classifies email as urgent, normal, or spam
  inputs:
    in: { packet: EmailPayload }
  outputs:
    out: { packet: ClassifiedEmail }
  settings:
    model: gpt-4o-mini
    systemPrompt: "Classify this email as: urgent, normal, or spam. Return JSON."
    temperature: 0.1
```

### action

```yaml
SendSmsAlert:
  operationId: send_sms_alert
  kind: action
  summary: Sends an SMS alert via Twilio
  inputs:
    in: { packet: AlertPayload }
  outputs:
    out: { packet: SmsResult }
```

### terminal

```yaml
ArchiveSpam:
  operationId: archive_spam_email
  kind: terminal
  summary: Archives the email in the spam folder
  inputs:
    in: { packet: ClassifiedEmail }
```

## Nodes must not own transport semantics

A node handler should never call Kafka, open a MongoDB connection, or write to Redis directly. Those are the runtime's responsibility. The node receives its input packet, does its computation or side-effect, and returns its output packet. This constraint is what makes nodes portable and independently testable.

```go
// CORRECT: node knows nothing about delivery
func (n *FilterNode) Handle(ctx context.Context, input flowdsl.NodeInput) (flowdsl.NodeOutput, error) {
    payload, _ := input.Packet("in")
    if payload.GetString("priority") == "urgent" {
        return flowdsl.NodeOutput{}.Send("urgent_out", payload), nil
    }
    return flowdsl.NodeOutput{}.Send("normal_out", payload), nil
}

// WRONG: node writing directly to Kafka
func (n *FilterNode) Handle(ctx context.Context, input flowdsl.NodeInput) (flowdsl.NodeOutput, error) {
    // DO NOT do this — this is the runtime's job
    producer.Produce("urgent-topic", payload)
}
```

## The flowdsl-node.json manifest

Every node implementation ships a `flowdsl-node.json` manifest that describes it to the registry:

```json
{
  "operationId": "filter_by_priority",
  "name": "Filter by Priority",
  "version": "1.2.0",
  "description": "Routes events to different outputs based on priority level",
  "runtime": "go",
  "inputs": [
    { "name": "in", "packet": "EventPayload", "description": "Incoming event" }
  ],
  "outputs": [
    { "name": "urgent_out", "packet": "EventPayload", "description": "P0/P1 events" },
    { "name": "normal_out", "packet": "EventPayload", "description": "P2+ events" }
  ],
  "settings": {
    "type": "object",
    "properties": {
      "urgentPriorities": { "type": "array", "items": { "type": "string" } }
    }
  },
  "repository": "https://github.com/myorg/flowdsl-nodes",
  "author": "My Team",
  "license": "Apache-2.0",
  "tags": ["routing", "priority"]
}
```

## Summary

- Nodes declare typed input and output ports — the bilateral contract.
- Nine kinds cover every role: source, transform, router, llm, action, checkpoint, publish, terminal, integration.
- Nodes must not own transport semantics — the runtime handles delivery.
- `operationId` is `snake_case`; node names are `PascalCase`.

## Next steps

- [Edges](/docs/concepts/edges) — connecting nodes with delivery policies
- [Write a Go Node](/docs/tutorials/writing-a-go-node) — implement a node using the Go SDK
- [Write a Python Node](/docs/tutorials/writing-a-python-node) — implement a node using the Python SDK
