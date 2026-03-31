---
title: Writing Idempotent Nodes
description: How to make FlowDSL nodes safe to retry and replay using idempotency keys and deduplication patterns.
weight: 303
---

FlowDSL's `durable` delivery mode provides at-least-once delivery — a packet may be delivered more than once if the process crashes between execution and acknowledgment. Nodes with side effects (sending emails, charging payments, calling external APIs) must be idempotent to handle this safely.

## What idempotency means

A function is idempotent if calling it multiple times with the same input produces the same observable result as calling it once.

For a FlowDSL node:
- An idempotent SMS sender sends the SMS once, even if the handler is called twice
- An idempotent order creator creates the order once, even if the packet is redelivered
- An idempotent LLM node calls the LLM once per document, even after a crash-retry

## The idempotencyKey field

The primary tool for idempotency in FlowDSL is the `idempotencyKey` field on a delivery policy:

```yaml
edges:
  - from: ClassifyEmail
    to: SendSmsAlert
    delivery:
      mode: durable
      packet: AlertPayload
      idempotencyKey: "{{payload.messageId}}-sms-alert"
```

The template uses `{{payload.field}}` syntax and is evaluated against each packet. The result must be **globally unique** for the intended logical operation.

### How the runtime uses it

1. Before delivering a packet, the runtime computes the idempotency key.
2. It checks MongoDB's `{flowId}.idempotency_keys` collection for an existing record with that key.
3. If found and marked `completed`: the packet is acknowledged without calling the node.
4. If found and marked `in_progress`: the packet is held until the in-progress execution completes.
5. If not found: the packet is delivered to the node. After the node returns successfully, the key is marked `completed`.

This prevents duplicate side effects even when the same packet is delivered multiple times.

## Idempotency key design

Good idempotency keys are:

| Property | Explanation |
|----------|-------------|
| **Unique per operation** | `{entityId}-{operation}`, not just `{entityId}` |
| **Stable across retries** | The same packet always produces the same key |
| **Not reusable** | Never reuse a key for a logically different operation |

```yaml
# GOOD: unique per entity and operation
idempotencyKey: "{{payload.orderId}}-charge-payment"
idempotencyKey: "{{payload.messageId}}-sms-alert"
idempotencyKey: "{{payload.documentId}}-summarize-v2"

# BAD: too generic — collides across different operations
idempotencyKey: "{{payload.orderId}}"
idempotencyKey: "{{payload.id}}"
```

## Implementing idempotency in Go

```go
func (n *SmsAlertNode) Handle(ctx context.Context, input flowdsl.NodeInput) (flowdsl.NodeOutput, error) {
    payload, err := input.Packet("in")
    if err != nil {
        return flowdsl.NodeOutput{}, err
    }

    messageId, _ := payload.GetString("messageId")

    // The runtime has already checked the idempotency key before calling Handle.
    // If we're here, it's safe to proceed — this is the first call for this key.
    // However, external APIs may have their own idempotency mechanisms.

    // Pass the idempotency key to the Twilio SDK
    idempotencyKey := input.Context().IdempotencyKey
    result, err := n.twilio.SendSMS(ctx, &twilio.SMSParams{
        To:             payload.GetStringOr("phoneNumber", ""),
        Body:           payload.GetStringOr("message", ""),
        IdempotencyKey: idempotencyKey,  // Twilio deduplicates on their end too
    })
    if err != nil {
        if isTwilioRateLimit(err) {
            return flowdsl.NodeOutput{}, flowdsl.NewNodeError(flowdsl.ErrCodeRateLimited, "Twilio rate limit", err)
        }
        return flowdsl.NodeOutput{}, flowdsl.NewNodeError(flowdsl.ErrCodeTemporary, "Twilio SMS failed", err)
    }

    return flowdsl.NodeOutput{}.Send("out", map[string]any{
        "sid":    result.SID,
        "status": result.Status,
    }), nil
}
```

## Implementing idempotency in Python

```python
class CreateTicketNode(BaseNode):
    operation_id = "create_support_ticket"

    async def handle(self, input: NodeInput) -> NodeOutput:
        payload = await input.packet("in")
        ticket_id_source = payload.get("email", {}).get("messageId")

        # Use the idempotency key from the edge policy (set by the runtime)
        idempotency_key = input.context.idempotency_key

        # Check our own store first (for external systems that don't support idempotency)
        existing = await self._db.get_ticket_by_idempotency_key(idempotency_key)
        if existing:
            # Already created — return the existing ticket without calling the API
            return NodeOutput().send("out", existing)

        # Create the ticket
        ticket = await self._zendesk.create_ticket(
            subject=payload.get("email", {}).get("subject", ""),
            body=payload.get("email", {}).get("body", ""),
            priority=payload.get("classification"),
        )

        # Store our own record for idempotency
        await self._db.store_idempotency_record(idempotency_key, ticket)

        return NodeOutput().send("out", ticket)
```

## External API idempotency

Many external APIs have their own idempotency mechanisms. Use them in addition to FlowDSL's built-in key tracking:

| API | Idempotency mechanism |
|-----|----------------------|
| Stripe | `Idempotency-Key` header |
| Twilio | `X-Twilio-Idempotency` |
| SendGrid | No native support — track in your database |
| Zendesk | No native support — check for existing tickets |
| OpenAI | No native support — use FlowDSL's built-in dedup |

## Database idempotency patterns

For databases, use upsert operations instead of insert:

```go
// WRONG: Insert fails on duplicate — causes error, triggers retry
_, err = db.Collection("orders").InsertOne(ctx, order)

// CORRECT: Upsert is idempotent — safe to run multiple times
_, err = db.Collection("orders").UpdateOne(ctx,
    bson.M{"orderId": order.OrderID},
    bson.M{"$setOnInsert": order},
    options.Update().SetUpsert(true),
)
```

In Python with MongoDB:

```python
await db.orders.update_one(
    {"orderId": order["orderId"]},
    {"$setOnInsert": order},
    upsert=True,
)
```

## Testing idempotency

```go
func TestSmsAlertIdempotency(t *testing.T) {
    node := &SmsAlertNode{}
    twilio := &MockTwilioClient{}

    payload := flowdsl.NewPacket(map[string]any{
        "messageId": "msg-001",
        "phoneNumber": "+15550100300",
        "message": "Production alert: database unreachable",
    })

    input := flowdsl.MockNodeInput("in", payload,
        flowdsl.WithIdempotencyKey("msg-001-sms"),
    )

    // First call — should send SMS
    _, err := node.Handle(context.Background(), input)
    require.NoError(t, err)
    assert.Equal(t, 1, twilio.SentCount())

    // Second call with same idempotency key — should NOT send SMS
    _, err = node.Handle(context.Background(), input)
    require.NoError(t, err)
    assert.Equal(t, 1, twilio.SentCount())  // still 1, not 2
}
```

## Summary

| Pattern | Where to apply |
|---------|---------------|
| `idempotencyKey` on edge | All `durable` edges with side effects |
| Pass key to external API | When the API supports its own idempotency header |
| Check-before-create | For APIs without native idempotency |
| Upsert instead of insert | For all database writes in node handlers |
| Unique key per operation | `{entityId}-{operation}`, never just `{entityId}` |

## Next steps

- [Retry Policies](/docs/concepts/retry-policies) — configuring retry behavior
- [Error Handling](/docs/guides/error-handling) — dead letters and recovery
- [LLM Flows](/docs/guides/llm-flows) — idempotency for expensive LLM calls
