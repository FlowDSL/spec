# FlowDSL Node Manifest

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

---

## Node kinds

The `kind` field controls Studio palette grouping, visual styling, and validation rules applied at flow-design time.

| Kind | Description |
|---|---|
| `source` | Produces events from external systems (HTTP, email, databases). Has no inputs. |
| `transform` | Reshapes or maps payload data. Has both inputs and outputs. |
| `router` | Routes payload to one of multiple outputs based on a condition or model decision. |
| `llm` | Invokes a large language model. Has both inputs and outputs. |
| `action` | Performs a side effect (send message, write to database). Typically no outputs. |
| `checkpoint` | Persists state for durability and replay. |
| `publish` | Publishes an event to a bus or queue. |
| `terminal` | Terminates a flow branch. Has no outputs. |
| `integration` | Connects to a third-party platform (CRM, ERP, SaaS). |

---

## Author

```json
"author": {
  "name": "FlowDSL Team",
  "url": "https://flowdsl.com",
  "email": "nodes@flowdsl.com"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Display name of the author or organization. |
| `url` | string (URI) | no | Author's website or profile URL. |
| `email` | string (email) | no | Contact email address. |

---

## Runtime

The `runtime` object tells the FlowDSL runtime how to locate and invoke the node handler.

```json
"runtime": {
  "handler": "flowdsl.nodes.email.EmailFetcherNode",
  "supports": ["proc", "grpc"],
  "image": "ghcr.io/flowdsl/email-fetcher:1.0.0"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `handler` | string | yes | Fully-qualified handler path. Format depends on language (see below). |
| `supports` | string[] | yes | Protocols this node can communicate over: `proc`, `grpc`, `http`, `nats`, `kafka`, `redis`, `zeromq`, `rabbitmq`, `websocket`. |
| `image` | string | no | Container image for isolated node execution. |

**Handler format by language:**

| Language | Format | Example |
|---|---|---|
| Go | Go package import path | `github.com/flowdsl/flowdsl-go/nodes.EmailFetcherNode` |
| Python | `module.ClassName` | `flowdsl.nodes.email.EmailFetcherNode` |
| Node.js | `file/export` path | `nodes/email-fetcher.EmailFetcherNode` |

---

## Ports

`inputs` and `outputs` are arrays of `NodePort` objects that define the message contracts for the node.

```json
"outputs": [
  {
    "name": "EmailReceived",
    "description": "Emitted once for each new email retrieved from the mailbox.",
    "schema": {
      "type": "object",
      "properties": {
        "messageId": { "type": "string" },
        "from":      { "type": "string" },
        "subject":   { "type": "string" }
      }
    }
  }
]
```

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Port name. PascalCase for event-style ports (`EmailReceived`), camelCase for data ports. |
| `description` | string | no | What this port carries or expects. |
| `schema` | object | no | JSON Schema (Draft-07) describing the message shape. Omit for dynamic or untyped ports. |

Port names are referenced in FlowDSL flow documents when connecting edges from this node. A `source` node typically has no inputs; a `terminal` node typically has no outputs.

---

## settingsSchema

`settingsSchema` is a JSON Schema object that FlowDSL Studio reads to render a configuration form when a user places this node in a flow. It follows JSON Schema Draft-07 with additional `x-ui` extension properties for Studio-specific rendering hints.

### Basic structure

```json
"settingsSchema": {
  "type": "object",
  "required": ["host", "username", "password"],
  "properties": {
    "host": {
      "type": "string",
      "title": "IMAP/POP3 Host",
      "description": "Hostname of the mail server.",
      "x-ui": { "placeholder": "mail.example.com", "order": 1, "group": "Connection" }
    },
    "password": {
      "type": "string",
      "title": "Password",
      "format": "password",
      "x-ui": { "order": 2, "group": "Connection", "secret": true }
    }
  }
}
```

### Standard property fields

| Field | Type | Description |
|---|---|---|
| `type` | string | JSON Schema type: `string`, `number`, `integer`, `boolean`, `array`, `object`. |
| `title` | string | Label shown next to the form field. |
| `description` | string | Helper text shown below the field. |
| `default` | any | Default value pre-filled in the form. |
| `enum` | array | Allowed values. Studio renders this field as a dropdown. |
| `minimum` | number | Minimum value for `number` or `integer` fields. |
| `maximum` | number | Maximum value for `number` or `integer` fields. |
| `format` | string | JSON Schema format hint. Use `password` to render a masked input (see below). |
| `items` | object | Schema for `array` item elements. |
| `properties` | object | Schema for nested `object` properties. |

### format: password

When `format` is set to `"password"`, Studio renders the field as a masked input. Combined with `x-ui.secret: true`, the value is stored in the credential store and excluded from exported flow documents.

```json
"bearerToken": {
  "type": "string",
  "title": "Bearer Token",
  "format": "password",
  "x-ui": { "secret": true }
}
```

### x-ui extension

The `x-ui` object on a property provides Studio-specific rendering hints. None of these fields affect JSON Schema validation — they are only used by Studio.

| Field | Type | Description |
|---|---|---|
| `placeholder` | string | Placeholder text shown inside the input before the user types. |
| `group` | string | Group name. Related properties sharing the same group are rendered in a collapsible section. |
| `order` | integer | Display order within the form. Lower numbers appear first. |
| `secret` | boolean | Whether this field holds a secret. Secrets are stored in the credential store and never included in exported flow documents. Default: `false`. |

### Form rendering rules

| Property configuration | Studio renders as |
|---|---|
| `type: string` | Text input |
| `type: string` + `format: password` | Masked password input |
| `type: string` + `enum: [...]` | Dropdown select |
| `type: number` or `type: integer` | Number input |
| `type: boolean` | Toggle switch |
| `type: array` | Repeatable list editor |
| `type: object` | Key-value pair editor |
| `x-ui.group` set | Properties are grouped under a collapsible section header |
| `x-ui.secret: true` | Value sent to credential store; masked in UI and excluded from exports |

---

## Creating a node

### 1. Implement the handler

Follow the SDK guide for your language:

- **Go:** [flowdsl/flowdsl-go — Node SDK](https://github.com/flowdsl/flowdsl-go)
- **Python:** [flowdsl/flowdsl-py — Node SDK](https://github.com/flowdsl/flowdsl-py)
- **Node.js:** [flowdsl/flowdsl-js — Node SDK](https://github.com/flowdsl/flowdsl-js)

### 2. Write the manifest

Create a `.flowdsl-node.json` file at the root of your node's repository. Validate it against the schema:

```bash
npx ajv-cli validate -s https://flowdsl.com/schemas/v1/flowdsl-node.schema.json -d my-node.flowdsl-node.json
```

### 3. Choose an ID

Node IDs follow the pattern `<namespace>/<slug>`:

- `flowdsl/` — reserved for official FlowDSL nodes
- Your GitHub org or username for community nodes: `acme/crm-lookup`
- Slugs use lowercase letters, digits, and hyphens only

### 4. Define ports

Declare all input and output ports with names and schemas. Port names are referenced in flow documents when wiring edges, so choose stable, descriptive names. PascalCase is recommended for event-style ports (`EmailReceived`, `AnalysisResult`).

### 5. Write settingsSchema

Model every user-configurable value as a property in `settingsSchema.properties`. Mark secrets with `format: password` and `x-ui.secret: true`. Use `x-ui.group` to organize complex forms and `x-ui.order` to control field order.

---

## Publishing to repo.flowdsl.com

> Publishing is currently invite-only during the beta period. Join the waitlist at [flowdsl.com/registry](https://flowdsl.com/registry).

Once approved:

1. **Authenticate** with the FlowDSL CLI:
   ```bash
   flowdsl auth login
   ```

2. **Publish** the manifest:
   ```bash
   flowdsl node publish my-node.flowdsl-node.json
   ```

3. The CLI validates the manifest, uploads the package, and adds an entry to `repo.flowdsl.com/registry.json`.

4. Your node appears in Studio's node palette and the registry search within minutes.

### Versioning

- Use semver. Breaking changes to port names or schemas require a major version bump.
- Old versions remain available in the registry for flows that reference them.
- Set `published: false` to hide a version from search without deleting it.

---

## Registry index

The registry index is served at `repo.flowdsl.com/registry.json` and validated against `flowdsl-registry.schema.json`. It contains lightweight `RegistryEntry` objects used for search and Studio palette population.

Full manifests are available at:
```
repo.flowdsl.com/nodes/{namespace}/{slug}/{version}/manifest.json
```

Example:
```
repo.flowdsl.com/nodes/flowdsl/email-fetcher/1.0.0/manifest.json
```

---

## Example manifests

The `examples/nodes/` directory in the `flowdsl/spec` repository contains reference manifests for all official core nodes:

| File | Kind | Language |
|---|---|---|
| `email-fetcher.flowdsl-node.json` | source | Python |
| `llm-analyzer.flowdsl-node.json` | llm | Python |
| `llm-router.flowdsl-node.json` | router | Python |
| `http-fetcher.flowdsl-node.json` | source | Go |
| `webhook-receiver.flowdsl-node.json` | source | Go |
| `mongo-reader.flowdsl-node.json` | source | Go |
| `mongo-writer.flowdsl-node.json` | action | Go |
| `slack-notifier.flowdsl-node.json` | action | Go |
| `json-transformer.flowdsl-node.json` | transform | Go |
| `filter-node.flowdsl-node.json` | router | Go |
| `sms-alert.flowdsl-node.json` | action | Python |
