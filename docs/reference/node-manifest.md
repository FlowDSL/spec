---
title: Node Manifest Reference
description: Complete field reference for the flowdsl-node.json node manifest format — identity, runtime, ports, settingsSchema, and publishing.
weight: 420
---

A **Node Manifest** is a `.flowdsl-node.json` file that describes a single installable node in the [repo.flowdsl.com](https://repo.flowdsl.com) registry. It captures the node's identity, runtime requirements, typed port contracts, and the settings schema used to render configuration forms in FlowDSL Studio.

**Schema:** `https://flowdsl.com/schemas/v1/flowdsl-node.schema.json`

---

## File format

Node manifests use the `.flowdsl-node.json` extension and validate against the `flowdsl-node.schema.json` schema (JSON Schema Draft-07).

```json
{
  "id": "flowdsl/email-fetcher",
  "name": "Email Fetcher",
  "version": "1.0.0",
  "summary": "Polls an IMAP or POP3 mailbox and emits one event per received email.",
  "kind": "source",
  "language": "python",
  "author": { "name": "FlowDSL Team", "url": "https://flowdsl.com" },
  "license": "Apache-2.0",
  "runtime": {
    "handler": "flowdsl.nodes.email.EmailFetcherNode",
    "supports": ["proc"]
  },
  "outputs": [ ... ],
  "settingsSchema": { ... },
  "published": true,
  "publishedAt": "2026-01-15T10:00:00Z"
}
```

---

## Top-level fields

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | Unique registry identifier. Format: `<namespace>/<slug>`. e.g. `flowdsl/email-fetcher` |
| `name` | string | yes | Human-readable display name shown in Studio and the marketplace. |
| `version` | string | yes | Semver version of this manifest. |
| `summary` | string | yes | One-line description shown in search results and Studio tooltips. |
| `description` | string | no | Full markdown description rendered on the registry detail page. |
| `kind` | enum | yes | Functional category. See [Node kinds](#node-kinds). |
| `language` | enum | yes | Implementation language: `go`, `python`, or `nodejs`. |
| `author` | object | yes | Node author. See [Author](#author). |
| `license` | string | yes | SPDX license identifier, e.g. `Apache-2.0`. |
| `repoUrl` | string (URI) | no | Source code repository URL. |
| `docsUrl` | string (URI) | no | Documentation page URL. |
| `icon` | string | no | Emoji or icon name displayed in Studio. |
| `color` | string | no | Hex color for the Studio node card, e.g. `#4F46E5`. |
| `tags` | string[] | no | Search and filter tags for the registry. |
| `runtime` | object | yes | Runtime configuration. See [Runtime](#runtime). |
| `inputs` | NodePort[] | no | Named input ports. See [Ports](#ports). |
| `outputs` | NodePort[] | no | Named output ports. See [Ports](#ports). |
| `settingsSchema` | object | no | JSON Schema object driving the Studio settings form. See [settingsSchema](#settingsschema). |
| `dependencies` | string[] | no | Other node IDs required at runtime. |
| `minRuntimeVersion` | string | no | Minimum FlowDSL runtime version required. |
| `published` | boolean | yes | Whether the node is visible in the registry. |
| `publishedAt` | string (date-time) | no | ISO 8601 timestamp when this version was published. |

## Port object

Input and output ports are described as objects in the `inputs` and `outputs` arrays:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Port name (matches port name in the flow document) |
| `packet` | string | No | Packet type reference |
| `description` | string | No | Description of this port |
| `required` | boolean | No | Whether this port must have an incoming packet (default: `true`) |

## Supported protocols

The `runtime` field in a FlowDSL document’s node definition includes a `supports` array listing which communication protocols the node can use. The specific protocol for a connection is selected on the **edge** via the `protocol` field.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `runtime.supports` | string[] | `["grpc"]` | Protocols this node supports: `"proc"`, `"grpc"`, `"http"`, `"nats"`, `"kafka"`, `"redis"`, `"zeromq"`, `"rabbitmq"`, or `"websocket"` |

### gRPC config

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `runtime.grpc.port` | integer | `50051` | gRPC listen port |
| `runtime.grpc.streaming` | boolean | `false` | Whether the node supports `InvokeStream` |
| `runtime.grpc.maxConcurrentStreams` | integer | — | Max concurrent gRPC streams |
| `runtime.grpc.tls` | boolean | — | Whether TLS is required |

### NATS config

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `runtime.nats.url` | string (uri) | — | NATS server URL |
| `runtime.nats.subject` | string | — | NATS subject to subscribe/publish on |
| `runtime.nats.queueGroup` | string | — | Queue group for load balancing |

### Redis config

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `runtime.redis.url` | string (uri) | — | Redis server URL |
| `runtime.redis.channel` | string | — | Redis channel or pattern |

### ZeroMQ config

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `runtime.zeromq.address` | string | — | ZeroMQ bind/connect address |
| `runtime.zeromq.pattern` | string | — | `"pubSub"`, `"pushPull"`, or `"reqRep"` |

### RabbitMQ config

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `runtime.rabbitmq.url` | string (uri) | — | AMQP connection URL |
| `runtime.rabbitmq.exchange` | string | — | Exchange name |
| `runtime.rabbitmq.routingKey` | string | — | Routing key |
| `runtime.rabbitmq.queue` | string | — | Queue name |

### WebSocket config

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `runtime.websocket.url` | string (uri) | — | WebSocket server URL |
| `runtime.websocket.path` | string | — | WebSocket endpoint path |

The top-level `grpcPort` field in a node manifest is a convenient shorthand — equivalent to setting `runtime.grpc.port`.

See [Communication Protocols](/docs/reference/grpc-protocol) for full protocol details and usage guidance.

## Complete example

```json
{
  "operationId": "llm_classify_email",
  "name": "LLM Email Classifier",
  "version": "2.3.1",
  "description": "Classifies support emails as urgent, normal, or spam using a language model. Returns a classification with confidence score and reasoning.",
  "runtime": "python",
  "inputs": [
    {
      "name": "in",
      "packet": "EmailPayload",
      "description": "The email to classify",
      "required": true
    }
  ],
  "outputs": [
    {
      "name": "out",
      "packet": "AnalysisResult",
      "description": "Classification result with confidence score"
    }
  ],
  "settings": {
    "type": "object",
    "properties": {
      "model": {
        "type": "string",
        "default": "gpt-4o-mini",
        "description": "LLM model to use for classification",
        "enum": ["gpt-4o", "gpt-4o-mini", "claude-3-5-sonnet-20241022"]
      },
      "temperature": {
        "type": "number",
        "default": 0.1,
        "minimum": 0,
        "maximum": 2,
        "description": "Model temperature. Lower = more deterministic."
      },
      "systemPrompt": {
        "type": "string",
        "description": "Custom system prompt. Uses a carefully tuned default if omitted."
      },
      "maxTokens": {
        "type": "integer",
        "default": 500,
        "minimum": 100,
        "maximum": 4000
      }
    }
  },
  "repository": "https://github.com/myorg/flowdsl-nodes",
  "author": "My Team",
  "email": "platform@myorg.com",
  "license": "Apache-2.0",
  "tags": ["llm", "email", "classification", "nlp", "support"],
  "minRuntimeVersion": "1.0.0"
}
```

## Versioning

Node versions follow semver:

| Change type | Version bump | Example |
|------------|-------------|---------|
| Bug fix, no contract change | Patch | 2.3.0 → 2.3.1 |
| New optional input/output port | Minor | 2.3.0 → 2.4.0 |
| Renamed port, removed output, changed packet type | Major | 2.3.0 → 3.0.0 |

Before bumping major versions, update all FlowDSL documents that reference this `operationId`.

## settings schema

The `settings` field is a JSON Schema Draft-07 object describing the node's static configuration. The runtime validates the `settings` provided in the FlowDSL node definition against this schema at startup.

Provide defaults for all optional settings so the node works correctly when settings are omitted.

## Next steps

- [Write a Go Node](/docs/tutorials/writing-a-go-node) — implementing a node and writing its manifest
- [Write a Python Node](/docs/tutorials/writing-a-python-node) — same for Python
- [Node Development guide](/docs/guides/node-development) — full development lifecycle
