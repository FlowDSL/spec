---
title: RetryPolicy Reference
description: Complete field reference for the RetryPolicy object in FlowDSL.
weight: 408
---

A retry policy is nested inside a delivery policy and configures what the runtime does when a node handler returns a retriable error.

## Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `maxAttempts` | integer (1–10) | Yes | — | Total delivery attempts including the first. |
| `backoff` | string | Yes | — | Backoff strategy: `"fixed"`, `"linear"`, or `"exponential"` |
| `initialDelay` | ISO 8601 duration | Yes | — | Delay before the first retry. |
| `maxDelay` | ISO 8601 duration | No | No limit | Maximum delay between retries. |
| `jitter` | boolean | No | `false` | Add ±20% random variance to prevent retry storms. |
| `retryOn` | array of string | No | All errors | Error codes to retry on. |

## `retryOn` error codes

| Code | Meaning |
|------|---------|
| `TIMEOUT` | Node handler timed out |
| `RATE_LIMITED` | External API returned rate limit error |
| `TEMPORARY` | Transient failure (e.g., connection refused) |
| `NETWORK_ERROR` | Network connectivity failure |

Non-listed errors (`VALIDATION`, `PERMANENT`) always go to dead letter without retry, regardless of `retryOn`.

## Backoff strategies

### Fixed

```yaml
retryPolicy:
  maxAttempts: 3
  backoff: fixed
  initialDelay: PT5S
```

Retry timing: `wait 5s → wait 5s → dead letter`

### Linear

```yaml
retryPolicy:
  maxAttempts: 4
  backoff: linear
  initialDelay: PT2S
  maxDelay: PT10S
```

Retry timing: `wait 2s → wait 4s → wait 6s (capped 10s) → dead letter`

### Exponential

```yaml
retryPolicy:
  maxAttempts: 5
  backoff: exponential
  initialDelay: PT1S
  maxDelay: PT60S
  jitter: true
  retryOn: [RATE_LIMITED, TIMEOUT, TEMPORARY]
```

Retry timing (with jitter): `wait ~1s → wait ~2s → wait ~4s → wait ~8s → dead letter`

## Complete LLM retry policy example

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
        jitter: true
        retryOn: [RATE_LIMITED, TIMEOUT]
```

## Complete payment retry policy example

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

Fixed retry for payments: predictable, no exponential explosion, stops quickly so the customer doesn't wait too long.

## Next steps

- [DeliveryPolicy reference](/docs/reference/spec/delivery-policy) — the parent object
- [Error Handling guide](/docs/guides/error-handling) — dead letters and recovery
- [Retry Policies concept](/docs/concepts/retry-policies) — conceptual explanation
