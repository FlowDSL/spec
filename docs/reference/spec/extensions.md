---
title: Extensions (x-*) Reference
description: Extension fields for tooling hints, metadata, and custom behavior in FlowDSL documents.
weight: 411
---

FlowDSL follows the OpenAPI/AsyncAPI convention of allowing `x-` prefixed extension fields anywhere in the document. Extension fields are optional and ignored by implementations that don't recognize them.

## Supported extensions

### `x-ui` (on nodes)

Canvas layout hints for FlowDSL Studio:

```yaml
nodes:
  FilterByPriority:
    operationId: filter_by_priority
    kind: router
    x-ui:
      position:
        x: 420
        y: 200
      color: "#7c3aed"    # Hex color for the node card
      icon: filter         # Icon name from Studio's icon library
```

| Field | Type | Description |
|-------|------|-------------|
| `position.x` | number | Canvas X coordinate |
| `position.y` | number | Canvas Y coordinate |
| `color` | string | Hex color for node card background tint |
| `icon` | string | Icon name: `filter`, `sparkles`, `mail`, `bell`, `database`, `globe`, `cpu`, `archive` |

### `x-tags` (on nodes)

Categorization tags for Studio filtering:

```yaml
nodes:
  LlmClassifier:
    operationId: llm_classify
    kind: llm
    x-tags: [llm, classification, email]
```

### `x-deprecated` (on nodes)

Marks a node as deprecated. Studio shows a warning on deprecated nodes:

```yaml
nodes:
  OldEmailSender:
    operationId: send_email_v1
    kind: action
    x-deprecated: true
    description: "Deprecated. Use SendEmailV2 instead."
```

### `x-owner` (on nodes)

Team or person responsible for a node:

```yaml
nodes:
  ChargePayment:
    operationId: charge_payment
    kind: action
    x-owner:
      team: payments-platform
      slack: "#payments-platform"
      oncall: payments-oncall@pagerduty.com
```

### `x-runtime` (on edges)

Infrastructure binding overrides. See [Runtime Bindings reference](/docs/reference/spec/runtime-bindings) for details.

### `x-alerts` (on nodes)

Dead letter alerting configuration:

```yaml
nodes:
  ChargePayment:
    operationId: charge_payment
    kind: action
    x-alerts:
      onDeadLetter:
        webhook: https://hooks.slack.com/services/...
        message: "Payment failed for order {{packet.orderId}}"
        minSeverity: error
```

## Custom extensions

You can define your own `x-` extensions for your tooling. The runtime ignores unknown extensions:

```yaml
nodes:
  ProcessOrder:
    operationId: process_order
    kind: action
    x-cost-center: "engineering-platform"
    x-sla-target-ms: 500
    x-compliance: pci-dss
```

## Extension conventions

- Always prefix with `x-`
- Use `kebab-case` for extension names: `x-owner`, not `x-Owner` or `x_owner`
- Document your custom extensions in a companion schema or README

## Next steps

- [Runtime Bindings](/docs/reference/spec/runtime-bindings) — `x-runtime` details
- [FlowDSL Document](/docs/reference/spec/flowdsl-document) — top-level document fields
