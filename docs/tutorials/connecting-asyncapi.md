---
title: Reference AsyncAPI Messages in FlowDSL
description: Use existing AsyncAPI event contracts as packet types in your FlowDSL flows without duplicating schemas.
weight: 204
---

FlowDSL is self-contained, but if your team already has AsyncAPI documents describing your event contracts, you can reference those schemas directly in FlowDSL rather than duplicating them. This tutorial shows how.

## Why reference AsyncAPI?

If your team maintains an AsyncAPI document for your event bus, it is the authoritative schema for your events. Duplicating those schemas in FlowDSL creates drift — two definitions that can fall out of sync. Referencing them directly means:

- One source of truth
- FlowDSL validates packets against the actual AsyncAPI-defined schema
- Changes to the AsyncAPI schema automatically apply to the FlowDSL flow
- Studio can show the resolved schema in the NodeContractCard

## Your AsyncAPI document

```yaml
# events.asyncapi.yaml
asyncapi: "2.6.0"
info:
  title: Support Events
  version: "1.0.0"

channels:
  support/email-received:
    subscribe:
      operationId: email_received
      message:
        $ref: "#/components/messages/EmailReceived"

components:
  messages:
    EmailReceived:
      name: EmailReceived
      payload:
        type: object
        properties:
          messageId:
            type: string
          from:
            type: string
            format: email
          subject:
            type: string
          body:
            type: string
          receivedAt:
            type: string
            format: date-time
        required: [messageId, from, subject, body, receivedAt]

    TicketCreated:
      name: TicketCreated
      payload:
        type: object
        properties:
          ticketId:
            type: string
          emailMessageId:
            type: string
          priority:
            type: string
            enum: [urgent, normal, low]
          status:
            type: string
            enum: [open, pending, resolved]
        required: [ticketId, emailMessageId, priority, status]
```

## Reference it in FlowDSL

```yaml
flowdsl: "1.0"
info:
  title: Email Triage
  version: "1.0.0"

# Point to the AsyncAPI document
asyncapi: "./events.asyncapi.yaml"

externalDocs:
  url: ./events.asyncapi.yaml
  description: AsyncAPI event contracts for the support system

nodes:
  EmailReceiver:
    operationId: receive_email
    kind: source
    outputs:
      out:
        # Reference the AsyncAPI message directly
        packet: "asyncapi#/components/messages/EmailReceived"

  ClassifyEmail:
    operationId: classify_email
    kind: llm
    inputs:
      in:
        packet: "asyncapi#/components/messages/EmailReceived"
    outputs:
      out:
        # Native packet for the internal analysis result
        packet: AnalysisResult

  CreateTicket:
    operationId: create_ticket
    kind: action
    inputs:
      in:
        packet: AnalysisResult
    outputs:
      out:
        packet: "asyncapi#/components/messages/TicketCreated"

edges:
  - from: EmailReceiver
    to: ClassifyEmail
    delivery:
      mode: durable
      packet: "asyncapi#/components/messages/EmailReceived"

  - from: ClassifyEmail
    to: CreateTicket
    delivery:
      mode: durable
      packet: AnalysisResult

components:
  packets:
    # Native packet for data that doesn't exist in AsyncAPI
    AnalysisResult:
      type: object
      properties:
        email:
          type: object
        classification:
          type: string
          enum: [urgent, normal, spam]
        confidence:
          type: number
      required: [email, classification, confidence]
```

## The reference syntax

| Syntax | Resolves to |
|--------|------------|
| `asyncapi#/components/messages/EmailReceived` | The payload schema of the `EmailReceived` message in the linked AsyncAPI doc |
| `MyPacket` | A packet defined in `components.packets.MyPacket` in the current FlowDSL document |

The `#` is a JSON Pointer fragment. The path after `#` is resolved within the AsyncAPI document.

## How the runtime resolves references

1. At startup, the runtime reads the `asyncapi` field to locate the AsyncAPI document.
2. For each edge with an `asyncapi#/...` packet reference, the runtime resolves the JSON Pointer in the loaded AsyncAPI document.
3. The resolved JSON Schema is used for packet validation at runtime.
4. If the AsyncAPI document is unavailable, the runtime fails to start.

## Mixed native and AsyncAPI packets

You can freely mix native packets and AsyncAPI references in the same flow:

```yaml
components:
  packets:
    # This packet doesn't exist in AsyncAPI — define it natively
    InternalAnalysis:
      type: object
      properties:
        urgencyScore: { type: number }
        categories: { type: array, items: { type: string } }

edges:
  - from: EmailReceiver
    to: Analyzer
    delivery:
      packet: "asyncapi#/components/messages/EmailReceived"  # from AsyncAPI
  - from: Analyzer
    to: Router
    delivery:
      packet: InternalAnalysis  # native packet
```

## Validation

Both documents validate independently:

```bash
# Validate the AsyncAPI document
asyncapi validate events.asyncapi.yaml

# Validate the FlowDSL document
flowdsl validate email-triage.flowdsl.yaml
```

The FlowDSL validator also resolves and validates all `asyncapi#/...` references — it will fail if the referenced path doesn't exist in the AsyncAPI document.

## What happens when AsyncAPI schemas change

**Non-breaking changes** (adding optional fields): FlowDSL continues to work. Existing packets pass validation. Node handlers that don't read the new field are unaffected.

**Breaking changes** (removing required fields, renaming fields): Packet validation at the edge will fail for packets that no longer conform to the updated schema. The runtime will reject those packets and move them to the dead letter queue.

::callout{type="warning"}
Always version your AsyncAPI documents. Use `events.asyncapi.v2.yaml` instead of overwriting `events.asyncapi.yaml` when making breaking changes. Reference the specific version in your FlowDSL document.
::

## Summary

- Set `asyncapi: "./path/to/asyncapi.yaml"` in the FlowDSL document to link the AsyncAPI file.
- Reference messages with `asyncapi#/components/messages/MessageName` on any packet field.
- Mix native `components.packets` with AsyncAPI references freely.
- Both documents validate independently; FlowDSL also validates the reference paths.

## Next steps

- [AsyncAPI Integration guide](/docs/guides/asyncapi-integration) — full integration guide with schema evolution
- [Packets concept](/docs/concepts/packets) — native packet definitions
- [Email Triage Flow](/docs/tutorials/email-triage-flow) — complete email flow using AsyncAPI references
