---
title: Error Handling, Dead Letters, and Recovery
description: How FlowDSL handles failures at every level — node errors, delivery failures, dead letters, and manual recovery.
weight: 304
---

FlowDSL has three layers of error handling: node-level errors, delivery-level retries, and dead letter queues. Understanding each layer and how they interact is essential for building flows that degrade gracefully and recover automatically.

## Node-level errors

A node handler signals failure by returning a typed error. The error code determines whether the runtime retries:

| Error code | Meaning | Runtime behavior |
|-----------|---------|-----------------|
| `VALIDATION` | Data problem — wrong schema, missing field | Dead letter immediately (no retry) |
| `TIMEOUT` | Request timed out | Retry if policy configured |
| `RATE_LIMITED` | External API rate limit | Retry with backoff |
| `TEMPORARY` | Transient failure | Retry if policy configured |
| `PERMANENT` | Permanent failure | Dead letter immediately (no retry) |

```go
// Go: return typed errors
if !payload.Has("orderId") {
    return flowdsl.NodeOutput{}, flowdsl.NewNodeError(
        flowdsl.ErrCodeValidation,
        "orderId is required",
        nil,
    )
}
```

```python
# Python: raise NodeError
if not payload.get("orderId"):
    raise NodeError(ErrorCode.VALIDATION, "orderId is required")
```

## Delivery-level retries

Retries are configured on the edge, not the node. When a node returns a retriable error (`TIMEOUT`, `RATE_LIMITED`, `TEMPORARY`), the runtime waits according to the backoff policy and redelivers the packet:

```yaml
edges:
  - from: PrepareOrder
    to: ChargePayment
    delivery:
      mode: durable
      packet: OrderPayload
      retryPolicy:
        maxAttempts: 4
        backoff: exponential
        initialDelay: PT2S
        maxDelay: PT60S
        jitter: true
        retryOn: [TIMEOUT, TEMPORARY, RATE_LIMITED]
```

The runtime tracks retry count per packet. Each attempt is logged with a timestamp and error detail.

## Dead letter queues

When all retry attempts are exhausted (or the error is non-retriable), the packet moves to a dead letter queue:

- **Location:** MongoDB collection `{flowId}.dead_letters`
- **Content:** Original packet, last error, all attempt timestamps, node ID, flow ID
- **Retention:** Configurable (default: 30 days)

```json
{
  "_id": "dlq-ord-001-charge",
  "flowId": "order_fulfillment",
  "nodeId": "ChargePayment",
  "operationId": "charge_payment",
  "packet": {
    "orderId": "ord-001",
    "amount": 99.99,
    "currency": "USD"
  },
  "lastError": {
    "code": "TEMPORARY",
    "message": "Payment processor unavailable",
    "timestamp": "2026-03-28T10:05:00Z"
  },
  "attempts": [
    { "timestamp": "2026-03-28T10:00:00Z", "error": "Connection timeout" },
    { "timestamp": "2026-03-28T10:00:02Z", "error": "Connection timeout" },
    { "timestamp": "2026-03-28T10:00:06Z", "error": "Payment processor unavailable" },
    { "timestamp": "2026-03-28T10:00:14Z", "error": "Payment processor unavailable" }
  ],
  "createdAt": "2026-03-28T10:00:00Z",
  "deadLetteredAt": "2026-03-28T10:05:00Z"
}
```

## Configuring dead letter queues

```yaml
edges:
  - from: ValidateOrder
    to: ChargePayment
    delivery:
      mode: durable
      packet: ValidatedOrder
      retryPolicy:
        maxAttempts: 4
        backoff: exponential
        initialDelay: PT2S
      deadLetterQueue: payment-failures    # Named DLQ (optional, defaults to flowId.dead_letters)
```

Named dead letter queues allow different monitoring and recovery strategies per error type.

## Inspecting dead letters

Via the runtime API:

```bash
# List all dead letters for a flow
curl http://localhost:8081/flows/order_fulfillment/dead-letters

# Get dead letter details
curl http://localhost:8081/flows/order_fulfillment/dead-letters/dlq-ord-001-charge
```

Via Studio:
- Open the flow → click the **Dead Letters** tab
- Inspect the full packet and error chain
- Re-inject selected packets after fixing the underlying issue

## Manual recovery: re-injecting dead letters

After fixing the underlying issue (the payment processor is back up, the schema was corrected), re-inject the packet to restart processing:

```bash
# Re-inject a specific dead letter packet
curl -X POST http://localhost:8081/flows/order_fulfillment/dead-letters/dlq-ord-001-charge/reinject
```

The re-injected packet goes back to the same node with the same idempotency key (if set). If the node handler previously completed before the crash that caused the dead letter, the idempotency key prevents a duplicate action.

## Configuring dead letter alerts

Add alerting via `x-alerts` extension:

```yaml
nodes:
  ChargePayment:
    operationId: charge_payment
    kind: action
    x-alerts:
      onDeadLetter:
        webhook: https://hooks.slack.com/services/...
        message: "Payment failed for order {{packet.orderId}}"
        channels: ["#payments-alerts"]
```

## `direct` delivery and errors

For `direct` edges, errors propagate immediately to the caller (no queue, no retry):

```
WebhookReceiver → [direct] → JsonTransformer
```

If `JsonTransformer` throws an error, the webhook response returns HTTP 500. The client is responsible for retrying. Use `direct` only for steps where immediate error propagation is acceptable.

## Error handling for `stream` edges

For `stream` delivery (Kafka), error handling is managed by the Kafka consumer group:

- Failed messages are retried by the consumer group's retry mechanism
- After max retries, messages go to a Kafka dead letter topic: `{originalTopic}.dead-letter`
- The FlowDSL runtime creates this topic automatically

## Summary

| Layer | Mechanism | Configured on |
|-------|-----------|--------------|
| Node error | Typed error codes | Node handler code |
| Delivery retry | `retryPolicy` | Edge delivery policy |
| Dead letter | Automatic after max retries | Edge `deadLetterQueue` field |
| Alert | `x-alerts` extension | Node definition |
| Recovery | Re-inject via API or Studio | Manual or automated |

## Next steps

- [Retry Policies](/docs/concepts/retry-policies) — backoff strategies in detail
- [Idempotency](/docs/guides/idempotency) — preventing duplicate side effects on retry
- [RetryPolicy reference](/docs/reference/spec/retry-policy) — full field reference
