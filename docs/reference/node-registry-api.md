---
title: Node Registry API Reference
description: REST API reference for the repo.flowdsl.com node registry.
weight: 421
---

The node registry at `repo.flowdsl.com` provides a REST API for publishing and discovering FlowDSL nodes. The registry is currently in development — the API design below reflects the planned v1 surface.

::callout{type="info"}
The Node Registry is coming soon. This page documents the planned API for early adopters building tooling.
::

## Base URL

```
https://repo.flowdsl.com/api/v1
```

## Authentication

Authenticated endpoints require a bearer token:

```bash
Authorization: Bearer <your-api-token>
```

Obtain a token at [flowdsl.com/settings/tokens](https://flowdsl.com/settings/tokens).

## Endpoints

### `GET /nodes`

List all published nodes. Supports pagination and filtering.

**Query parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `q` | string | Full-text search query |
| `tag` | string | Filter by tag (repeatable) |
| `runtime` | string | Filter by runtime: `go`, `python`, `javascript` |
| `page` | integer | Page number (default: 1) |
| `perPage` | integer | Results per page (default: 20, max: 100) |

**Example:**

```bash
curl https://repo.flowdsl.com/api/v1/nodes?q=llm+classification&tag=email
```

**Response:**

```json
{
  "nodes": [
    {
      "operationId": "llm_classify_email",
      "name": "LLM Email Classifier",
      "version": "2.3.1",
      "description": "Classifies support emails using a language model",
      "runtime": "python",
      "author": "My Team",
      "tags": ["llm", "email", "classification"],
      "downloads": 1234,
      "publishedAt": "2026-01-15T10:00:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "perPage": 20
}
```

---

### `GET /nodes/{operationId}`

Get details for a specific node.

**Example:**

```bash
curl https://repo.flowdsl.com/api/v1/nodes/llm_classify_email
```

**Response:**

```json
{
  "operationId": "llm_classify_email",
  "name": "LLM Email Classifier",
  "latestVersion": "2.3.1",
  "description": "Classifies support emails as urgent, normal, or spam",
  "runtime": "python",
  "repository": "https://github.com/myorg/flowdsl-nodes",
  "author": "My Team",
  "license": "Apache-2.0",
  "tags": ["llm", "email", "classification"],
  "manifest": { "...": "full flowdsl-node.json content" },
  "downloads": 1234,
  "publishedAt": "2026-01-15T10:00:00Z",
  "updatedAt": "2026-03-01T14:30:00Z"
}
```

---

### `GET /nodes/{operationId}/versions`

List all published versions of a node.

**Response:**

```json
{
  "versions": [
    { "version": "2.3.1", "publishedAt": "2026-03-01T14:30:00Z", "changelog": "Fixed rate limit handling" },
    { "version": "2.3.0", "publishedAt": "2026-02-15T10:00:00Z", "changelog": "Added Claude support" },
    { "version": "2.2.0", "publishedAt": "2026-01-20T09:00:00Z", "changelog": "New optional systemPrompt setting" }
  ]
}
```

---

### `POST /nodes` (authenticated)

Publish a new node version.

**Request:**

```bash
curl -X POST https://repo.flowdsl.com/api/v1/nodes \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d @flowdsl-node.json
```

**Response:**

```json
{
  "operationId": "llm_classify_email",
  "version": "2.3.1",
  "status": "published",
  "publishedAt": "2026-03-28T10:00:00Z"
}
```

---

### `GET /search`

Full-text search across node names, descriptions, and tags.

```bash
curl "https://repo.flowdsl.com/api/v1/search?q=twilio+sms&runtime=go"
```

## CLI usage

```bash
# Authenticate
flowdsl auth login

# Publish current node
flowdsl publish --manifest flowdsl-node.json

# Search the registry
flowdsl search "llm classification"

# Install a node (adds to node-registry.yaml)
flowdsl install llm_classify_email@2.3.1
```

## Next steps

- [Node Manifest reference](/docs/reference/node-manifest) — `flowdsl-node.json` format
- [Node Development guide](/docs/guides/node-development) — how to build and publish nodes
