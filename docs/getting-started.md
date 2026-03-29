# Getting Started with FlowDSL

This guide walks you through creating a minimal, valid FlowDSL document from scratch.

---

## What you are building

A simple two-node flow that:
1. Receives an incoming webhook payload
2. Validates it
3. Stores it to a database

---

## Step 1 — Document header

Every FlowDSL document starts with a version declaration and metadata:

```yaml
flowdsl: "1.0.0"

info:
  title: Webhook Ingestion Flow
  version: "1.0.0"
  description: Validates and stores incoming webhook payloads.
```

`flowdsl` must be `"1.0.0"`. `info.title` and `info.version` are required.

---

## Step 2 — Define an entrypoint message

Flows are triggered by messages. Reference an AsyncAPI message for externally-defined schemas, or define an inline schema for a self-contained document.

```yaml
externalDocs:
  asyncapi: /asyncapi.json
```

Or skip `externalDocs` entirely and use an inline schema (shown below).

---

## Step 3 — Define your internal packet types

Packets are typed payloads that flow between nodes. Define them in `components.packets`:

```yaml
components:
  packets:
    WebhookValidPacket:
      type: object
      required: [id, payload]
      properties:
        id:
          type: string
        payload:
          type: object
        receivedAt:
          type: string
          format: date-time

    WebhookInvalidPacket:
      type: object
      required: [id, reason]
      properties:
        id:
          type: string
        reason:
          type: string
```

---

## Step 4 — Define your nodes

Define nodes in `components.nodes` and reference them by ID inside the flow.

```yaml
components:
  nodes:
    ValidateWebhookNode:
      operationId: validate_webhook
      kind: transform
      runtime:
        language: python
        handler: app.nodes.ValidateWebhookNode
        supports:
          - http
      inputs:
        - name: WebhookReceived
          message:
            schema:
              type: object
              required: [id, body]
              properties:
                id:
                  type: string
                body:
                  type: object
      outputs:
        - name: WebhookValid
          message:
            $ref: "#/components/packets/WebhookValidPacket"
        - name: WebhookInvalid
          message:
            $ref: "#/components/packets/WebhookInvalidPacket"

    StoreWebhookNode:
      operationId: store_webhook
      kind: action
      runtime:
        language: python
        handler: app.nodes.StoreWebhookNode
        supports:
          - http
      inputs:
        - name: WebhookValid
          message:
            $ref: "#/components/packets/WebhookValidPacket"
      outputs: []
```

---

## Step 5 — Define the flow

Now wire the nodes together inside a flow:

```yaml
flows:
  webhook_ingestion:
    summary: Validate and store incoming webhooks
    entrypoints:
      - message:
          schema:
            type: object
            required: [id, body]
            properties:
              id:
                type: string
              body:
                type: object
        description: Triggered by an incoming webhook POST
    nodes:
      validate_webhook:
        $ref: "#/components/nodes/ValidateWebhookNode"
      store_webhook:
        $ref: "#/components/nodes/StoreWebhookNode"
    edges:
      - from: validate_webhook
        to: store_webhook
        when: "output.name == 'WebhookValid'"
        delivery:
          mode: durableQueue
          store: mongo
```

---

## Step 6 — The complete document

Putting it all together:

```yaml
flowdsl: "1.0.0"

info:
  title: Webhook Ingestion Flow
  version: "1.0.0"

flows:
  webhook_ingestion:
    summary: Validate and store incoming webhooks
    entrypoints:
      - message:
          schema:
            type: object
            required: [id, body]
            properties:
              id:
                type: string
              body:
                type: object
    nodes:
      validate_webhook:
        $ref: "#/components/nodes/ValidateWebhookNode"
      store_webhook:
        $ref: "#/components/nodes/StoreWebhookNode"
    edges:
      - from: validate_webhook
        to: store_webhook
        when: "output.name == 'WebhookValid'"
        delivery:
          mode: durableQueue
          store: mongo

components:
  nodes:
    ValidateWebhookNode:
      operationId: validate_webhook
      kind: transform
      runtime:
        language: python
        handler: app.nodes.ValidateWebhookNode
        supports:
          - http
      inputs:
        - name: WebhookReceived
          message:
            schema:
              type: object
              required: [id, body]
              properties:
                id:
                  type: string
                body:
                  type: object
      outputs:
        - name: WebhookValid
          message:
            $ref: "#/components/packets/WebhookValidPacket"
        - name: WebhookInvalid
          message:
            $ref: "#/components/packets/WebhookInvalidPacket"

    StoreWebhookNode:
      operationId: store_webhook
      kind: action
      runtime:
        language: python
        handler: app.nodes.StoreWebhookNode
        supports:
          - http
      inputs:
        - name: WebhookValid
          message:
            $ref: "#/components/packets/WebhookValidPacket"
      outputs: []

  packets:
    WebhookValidPacket:
      type: object
      required: [id, payload]
      properties:
        id:
          type: string
        payload:
          type: object
        receivedAt:
          type: string
          format: date-time

    WebhookInvalidPacket:
      type: object
      required: [id, reason]
      properties:
        id:
          type: string
        reason:
          type: string
```

---

## Next steps

- Add a `retryPolicy` to the `durableQueue` edge for automatic retries on failure.
- Reference AsyncAPI messages instead of inline schemas — see [integrations/asyncapi.md](./integrations/asyncapi.md).
- Add more delivery modes to different edges — see [delivery-modes.md](./delivery-modes.md).
- Validate your document: `make validate-file FILE=your-flow.flowdsl.yaml`
