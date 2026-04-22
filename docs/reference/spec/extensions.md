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

### `x-profile-kind` / `x-overrides` / `x-manage-profiles-url` (on settings schema properties)

Node settings-schema hints that turn a string property into a **profile picker** — a dropdown whose enum is populated at runtime with named config presets the operator has saved for this kind. When a value is selected, Studio hides the sibling fields listed in `x-overrides` from the Inspector and surfaces a banner linking to `x-manage-profiles-url`:

```yaml
flowdsl_nodes:
  - id: redelay/llm-chat
    settings_schema:
      type: object
      properties:
        profile:
          type: string
          x-profile-kind: llm-chat                # which profile kind to list
          x-overrides:                            # keys hidden while a profile is selected
            - providerID
            - model
            - temperature
            - systemPrompt
          x-manage-profiles-url: /profiles        # banner link target
          enum: []                                # populated at spec-build time
        providerID:
          type: string
          enum: []
        model:
          type: string
        temperature:
          type: number
        stream:
          type: boolean                           # not listed in x-overrides → always visible
```

| Field | Type | On | Description |
|---|---|---|---|
| `x-profile-kind` | string | a `string`-typed property | Identifies the profile kind this selector consumes. The host app populates `enum` with saved profile ids for that kind. |
| `x-overrides` | string[] | the profile-picker property | Keys of sibling properties whose values the profile supplies. Studio hides those rows when a profile is selected. |
| `x-manage-profiles-url` | string | the profile-picker property | URL the Inspector's banner links to. Typically `/profiles` in a Redelay admin. |

Studio renders a single profile picker at the top of the Inspector, shows a *"Profile 'X' supplies N settings for this node"* banner when one is selected, and keeps the non-overridden fields (e.g. `stream`) visible regardless. Runtime merges the profile's config into blank node fields; any explicitly-set field wins over the profile.

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
