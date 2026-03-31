---
title: Retry Policies
description: Configure automatic retry behavior for failed edge deliveries in FlowDSL.
weight: 107
---

A retry policy configures what the runtime does when a node handler throws an error or times out. It lives on the edge's delivery policy, not on the node — consistent with the principle that delivery semantics belong to edges, not nodes.

Retry policies only apply to `durable` and `ephemeral` delivery modes. `direct` edges propagate errors immediately. `stream` edges rely on Kafka's consumer group retry mechanisms.

## RetryPolicy structure

```yaml
retryPolicy:
  maxAttempts: 5          # Total attempts including the first (required)
  backoff: exponential    # "fixed" | "linear" | "exponential" (required)
  initialDelay: PT2S      # ISO 8601 duration (required)
  maxDelay: PT60S         # Cap on backoff delay (optional)
  jitter: true            # Add random ±20% jitter to backoff (optional, default: false)
  retryOn:                # Error codes to retry on (optional, default: all)
    - TIMEOUT
    - RATE_LIMITED
    - TEMPORARY_FAILURE
```

### Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `maxAttempts` | integer (1–10) | Yes | — | Total delivery attempts including the first. |
| `backoff` | string | Yes | — | `"fixed"`, `"linear"`, or `"exponential"` |
| `initialDelay` | ISO 8601 duration | Yes | — | Delay before the first retry. |
| `maxDelay` | ISO 8601 duration | No | Unlimited | Maximum delay between retries. |
| `jitter` | boolean | No | `false` | Adds random variance to prevent retry storms. |
| `retryOn` | array of string | No | All errors | Limit retries to specific error codes. |

## Backoff strategies

### Fixed

Every retry waits the same `initialDelay`:

```
Attempt 1 → fail → wait 5s → Attempt 2 → fail → wait 5s → Attempt 3
```

```yaml
retryPolicy:
  maxAttempts: 3
  backoff: fixed
  initialDelay: PT5S
```

**Use for:** Short, deterministic operations where you want predictable retry timing.

### Linear

Each retry adds one `initialDelay` to the previous wait:

```
Attempt 1 → fail → wait 2s → Attempt 2 → fail → wait 4s → Attempt 3 → fail → wait 6s
```

```yaml
retryPolicy:
  maxAttempts: 4
  backoff: linear
  initialDelay: PT2S
  maxDelay: PT30S
```

**Use for:** Operations that may need a bit more time with each retry.

### Exponential

The wait doubles each time, up to `maxDelay`:

```
Attempt 1 → fail → wait 1s → Attempt 2 → fail → wait 2s → Attempt 3 → fail → wait 4s → Attempt 4 → fail → wait 8s
```

```yaml
retryPolicy:
  maxAttempts: 5
  backoff: exponential
  initialDelay: PT1S
  maxDelay: PT60S
  jitter: true
```

**Use for:** External API calls, LLM invocations, network-dependent operations. Exponential backoff with jitter is the standard choice for avoiding retry storms against rate-limited services.

## Complete examples

### SMS alert with exponential backoff

```yaml
edges:
  - from: ClassifyUrgent
    to: SendSmsAlert
    delivery:
      mode: durable
      packet: AlertPayload
      idempotencyKey: "{{payload.alertId}}-sms"
      retryPolicy:
        maxAttempts: 4
        backoff: exponential
        initialDelay: PT2S
        maxDelay: PT30S
        jitter: true
```

### Payment charge with fixed retry

```yaml
edges:
  - from: ValidateOrder
    to: ChargePayment
    delivery:
      mode: durable
      packet: ValidatedOrder
      idempotencyKey: "{{payload.orderId}}-charge"
      retryPolicy:
        maxAttempts: 3
        backoff: fixed
        initialDelay: PT5S
        retryOn: [TIMEOUT, NETWORK_ERROR]
```

### LLM call with long exponential backoff

```yaml
edges:
  - from: PreparePrompt
    to: LlmSummarize
    delivery:
      mode: durable
      packet: PromptPayload
      idempotencyKey: "{{payload.documentId}}-summarize"
      retryPolicy:
        maxAttempts: 3
        backoff: exponential
        initialDelay: PT5S
        maxDelay: PT120S
        retryOn: [RATE_LIMITED, TIMEOUT]
```

## Dead letter behavior

After all retry attempts are exhausted, the packet moves to the **dead letter queue** — a MongoDB collection named `{flowId}.dead_letters`. The dead letter record includes:

- The original packet
- The error from the last attempt
- The number of attempts made
- A timestamp for each attempt

Packets in the dead letter queue can be re-injected via the runtime API after fixing the underlying issue.

::callout{type="warning"}
**Idempotency required with retries.** If a node partially completes before failing (e.g., an email is sent but the handler crashes before returning), retrying will call the node again. Always pair `durable` retry policies with an `idempotencyKey` to prevent duplicate side effects.
::

## Summary

- Retry policies live on edges, not nodes.
- Three strategies: `fixed`, `linear`, `exponential`.
- `exponential` with `jitter: true` is the safe default for external calls.
- Always add `idempotencyKey` when using retry policies on nodes with side effects.

## Next steps

- [Idempotency](/docs/guides/idempotency) — writing safe idempotent node handlers
- [Error Handling](/docs/guides/error-handling) — dead letters and recovery patterns
- [RetryPolicy reference](/docs/reference/spec/retry-policy) — field-by-field reference
