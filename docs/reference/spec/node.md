---
title: Node Object Reference
description: Complete field reference for the Node object in FlowDSL.
weight: 403
---

Nodes are declared under the top-level `nodes` map, keyed by their PascalCase name.

## Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `operationId` | string | Yes | `snake_case` identifier matching the registered handler. Must be unique across all nodes in the flow. |
| `kind` | string | Yes | Node role: `source`, `transform`, `router`, `llm`, `action`, `checkpoint`, `publish`, `terminal`, `integration` |
| `summary` | string | No | One-line description. Shown in Studio and API responses. |
| `description` | string | No | Longer description. Supports markdown. |
| `inputs` | object | No | Map of port name → Port object. |
| `outputs` | object | No | Map of port name → Port object. |
| `settings` | object | No | Static configuration injected into the node handler at initialization. |
| `x-ui` | object | No | Canvas layout hints for Studio. |

## Port object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `packet` | string | No | Reference to a packet type: `"PacketName"` or `"asyncapi#/..."` |
| `description` | string | No | Description of this port. |

## Node kinds

| Kind | Has inputs | Has outputs | Description |
|------|-----------|------------|-------------|
| `source` | No | Yes | Entry point. No incoming edges. Triggered by external events. |
| `transform` | Yes | Yes | Maps input to output. Pure function, no side effects. |
| `router` | Yes | Yes (multiple) | Routes input to one of several named outputs. |
| `llm` | Yes | Yes | Calls a language model. |
| `action` | Yes | Yes (optional) | Performs side effects in external systems. |
| `checkpoint` | Yes | Yes | Saves state to MongoDB and passes through. |
| `publish` | Yes | No | Publishes to an event bus. Terminal-like. |
| `terminal` | Yes | No | End of path. No outputs. |
| `integration` | Yes | Yes | Bridges to an external FlowDSL flow. |

## `x-ui` fields

| Field | Type | Description |
|-------|------|-------------|
| `position.x` | number | Canvas X coordinate |
| `position.y` | number | Canvas Y coordinate |
| `color` | string | Hex color for the node card |
| `icon` | string | Icon name from Studio's icon library |

## Complete example

```yaml
nodes:
  LlmAnalyzeEmail:
    operationId: llm_analyze_email
    kind: llm
    summary: Classifies email as urgent, normal, or spam
    description: |
      Reads the email subject and body and uses an LLM to classify
      the email into one of three categories. Returns a classification
      with confidence score and reasoning.
    inputs:
      in:
        packet: EmailPayload
        description: The email to classify
    outputs:
      out:
        packet: AnalysisResult
        description: Classification result with confidence and reason
    settings:
      model: gpt-4o-mini
      temperature: 0.1
      maxTokens: 500
      systemPrompt: |
        Classify the email as urgent, normal, or spam.
        Return JSON: {"classification": "...", "confidence": 0.0-1.0, "reason": "..."}
    x-ui:
      position:
        x: 420
        y: 200
      color: "#7c3aed"
      icon: sparkles
```

## Naming rules

| Rule | Correct | Incorrect |
|------|---------|-----------|
| Node names: PascalCase | `OrderReceived`, `ValidatePayment` | `order_received`, `validatePayment` |
| `operationId`: snake_case | `validate_payment_amount` | `validatePaymentAmount`, `ValidatePayment` |
| `operationId` must be unique | — | Same `operationId` in two nodes |

## Next steps

- [Edge reference](/docs/reference/spec/edge) — connecting nodes
- [DeliveryPolicy reference](/docs/reference/spec/delivery-policy) — delivery configuration
- [Nodes concept](/docs/concepts/nodes) — conceptual explanation
