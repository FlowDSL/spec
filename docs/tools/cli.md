---
title: CLI Tools
description: Command-line tools for validating, formatting, and working with FlowDSL documents.
weight: 502
---

The FlowDSL CLI provides command-line tools for validating, formatting, converting, and deploying FlowDSL documents.

## Installation

```bash
npm install -g @flowdsl/cli
# or
brew install flowdsl/tap/flowdsl
```

Verify:
```bash
flowdsl --version
# flowdsl/1.0.0 darwin-arm64 node-v20.0.0
```

## Commands

### `flowdsl validate`

Validates a FlowDSL document against the JSON Schema and semantic rules.

```bash
flowdsl validate my-flow.flowdsl.yaml
flowdsl validate my-flow.flowdsl.json

# Validate all flows in a directory
flowdsl validate flows/

# Exit code: 0 = valid, 1 = invalid
```

**Output:**
```
✓ my-flow.flowdsl.yaml is valid

# or on error:
✗ my-flow.flowdsl.yaml has 2 errors

  Error 1: /nodes/OrderReceived/operationId
    operationId "receiveOrder" must be snake_case. Try "receive_order".

  Error 2: /edges/1/delivery/packet
    Packet "InvalidPacketName" is not defined in components.packets
```

### `flowdsl convert`

Convert between YAML and JSON formats.

```bash
# YAML → JSON
flowdsl convert my-flow.flowdsl.yaml --output my-flow.flowdsl.json

# JSON → YAML
flowdsl convert my-flow.flowdsl.json --output my-flow.flowdsl.yaml

# Output to stdout
flowdsl convert my-flow.flowdsl.yaml --format json
```

### `flowdsl format`

Format a FlowDSL YAML document with consistent indentation and field ordering.

```bash
flowdsl format my-flow.flowdsl.yaml           # Format in place
flowdsl format my-flow.flowdsl.yaml --check   # Check without modifying (CI use)
```

### `flowdsl generate`

Generate code or documentation from a FlowDSL document.

```bash
# Generate Go node stubs
flowdsl generate go --output ./nodes/ my-flow.flowdsl.yaml

# Generate Python node stubs
flowdsl generate python --output ./nodes/ my-flow.flowdsl.yaml

# Generate markdown documentation
flowdsl generate docs --output ./docs/ my-flow.flowdsl.yaml
```

### `flowdsl auth`

Authenticate with repo.flowdsl.com.

```bash
flowdsl auth login
flowdsl auth status
flowdsl auth logout
```

### `flowdsl publish`

Publish a node to the registry (requires authentication).

```bash
flowdsl publish --manifest flowdsl-node.json
flowdsl publish --manifest flowdsl-node.json --tag beta
```

## Configuration

Create a `.flowdslrc` file in your project root:

```yaml
schemaUrl: https://flowdsl.com/schemas/v1/flowdsl.schema.json
registryUrl: https://repo.flowdsl.com
validateOnSave: true
format:
  indent: 2
  sortKeys: true
```

## CI integration

```yaml
# GitHub Actions
- name: Validate FlowDSL flows
  run: |
    npm install -g @flowdsl/cli
    flowdsl validate flows/
```

## Next steps

- [Studio](/docs/tools/studio) — visual editor for FlowDSL
- [Go SDK](/docs/tools/go-sdk) — implement nodes in Go
