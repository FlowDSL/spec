---
title: Building and Publishing FlowDSL Nodes
description: How to develop, test, version, and publish FlowDSL nodes to the node registry.
weight: 309
---

A FlowDSL node is a small service with two parts: a handler (the business logic) and a manifest (the identity document). This guide covers the full development lifecycle from local implementation to registry publication.

## Node anatomy

```
my-node/
├── main.go (or main.py)     # Node server entry point
├── node.go (or node.py)     # NodeHandler implementation
├── flowdsl-node.json        # Manifest
└── go.mod / requirements.txt
```

## The flowdsl-node.json manifest

The manifest is the node's identity document — it describes the node to the runtime and registry:

```json
{
  "operationId": "send_sms_alert",
  "name": "SMS Alert",
  "version": "2.1.0",
  "description": "Sends an SMS alert via Twilio to a configured phone number",
  "runtime": "go",
  "inputs": [
    {
      "name": "in",
      "packet": "AlertPayload",
      "description": "The alert to send"
    }
  ],
  "outputs": [
    {
      "name": "out",
      "packet": "SmsResult",
      "description": "SMS delivery result"
    }
  ],
  "settings": {
    "type": "object",
    "properties": {
      "fromNumber": { "type": "string", "description": "Twilio sender number" },
      "toNumber": { "type": "string", "description": "Recipient number" }
    },
    "required": ["fromNumber", "toNumber"]
  },
  "repository": "https://github.com/myorg/flowdsl-nodes",
  "author": "My Team",
  "license": "MIT",
  "tags": ["sms", "notifications", "twilio"]
}
```

## Local development workflow

### 1. Write the handler

See [Write a Go Node](/docs/tutorials/writing-a-go-node) or [Write a Python Node](/docs/tutorials/writing-a-python-node) for complete implementation tutorials.

### 2. Register locally

```yaml
# node-registry.yaml
nodes:
  send_sms_alert:
    address: localhost:8083
    version: "2.1.0"
    runtime: go
```

### 3. Test in isolation

```go
func TestSmsAlertNode(t *testing.T) {
    node := &SmsAlertNode{}
    err := node.Init(flowdsl.Settings{"fromNumber": "+15550100200", "toNumber": "+15550100300"})
    require.NoError(t, err)

    input := flowdsl.MockNodeInput("in", map[string]any{
        "message": "Production alert",
        "severity": "high",
    })
    output, err := node.Handle(context.Background(), input)
    require.NoError(t, err)
    assert.Equal(t, "delivered", output.Packet("out").GetStringOr("status", ""))
}
```

### 4. Test with a live flow

```bash
# Start your node
./sms-alert-node

# Start the runtime with your test flow
FLOWDSL_REGISTRY_FILE=./node-registry.yaml \
flowdsl-runtime start test-flow.flowdsl.yaml

# Trigger the flow
curl -X POST http://localhost:8081/flows/test_flow/trigger \
  -d '{"message": "test", "severity": "high"}'
```

## Node versioning

Node versions follow semver (`major.minor.patch`):

- **Patch** (1.0.x) — bug fixes, no contract changes
- **Minor** (1.x.0) — new optional inputs/outputs, backwards compatible
- **Major** (x.0.0) — breaking changes: renamed ports, removed outputs, changed packet types

When you bump the major version, update all FlowDSL flows that reference this `operationId` before deploying.

## Node documentation best practices

Write a clear `description` in the manifest and a `README.md`:

```markdown
# send_sms_alert

Sends an SMS alert via Twilio.

## Inputs

| Port | Packet | Description |
|------|--------|-------------|
| `in` | `AlertPayload` | The alert to send |

## Outputs

| Port | Packet | Description |
|------|--------|-------------|
| `out` | `SmsResult` | Delivery result with Twilio SID |

## Settings

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fromNumber` | string | Yes | Twilio sender number in E.164 format |
| `toNumber` | string | Yes | Recipient number in E.164 format |

## Example

\`\`\`yaml
nodes:
  AlertEngineer:
    operationId: send_sms_alert
    kind: action
    settings:
      fromNumber: "+15550100200"
      toNumber: "+15550100300"
\`\`\`
```

## Publishing to repo.flowdsl.com (coming soon)

The public node registry at `repo.flowdsl.com` is coming in a future release. When available:

```bash
# Authenticate
flowdsl auth login

# Publish
flowdsl publish --manifest flowdsl-node.json --tag latest

# Published nodes are resolvable by operationId
registry: https://repo.flowdsl.com
```

## Summary

| Step | Tool |
|------|------|
| Implement handler | `flowdsl-go` or `flowdsl-py` SDK |
| Write manifest | `flowdsl-node.json` |
| Register locally | `node-registry.yaml` |
| Test | Go test / pytest + MockNodeInput |
| Version | Semver: breaking changes → major bump |
| Publish | `flowdsl publish` (coming soon) |

## Next steps

- [Write a Go Node](/docs/tutorials/writing-a-go-node) — implementation tutorial
- [Write a Python Node](/docs/tutorials/writing-a-python-node) — implementation tutorial
- [Node Manifest reference](/docs/reference/node-manifest) — full manifest field reference
