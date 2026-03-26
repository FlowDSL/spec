# Changelog

All notable changes to the FlowDSL specification will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
FlowDSL follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

---

## [1.0.0] — 2025 (initial draft)

### Added

#### Core document structure
- `flowdsl` version field (required, enum: `"1.0.0"`)
- `info` object with `title`, `version`, `description`, `contact`, `license`
- `servers` map for runtime server definitions
- `externalDocs` with `asyncapi` and `openapi` URL references
- `flows` map of named executable flow graphs
- `components` section for reusable definitions
- `x-*` vendor extension support on all top-level objects

#### Flow
- `entrypoints` array with message `$ref` and optional `filter` expression
- `nodes` map of node instances (inline or `$ref`)
- `edges` array of directed connections
- `defaults` for flow-level execution and retry policy defaults
- `summary`, `description`, `tags` metadata fields

#### Node
- `operationId` — unique snake_case operation identifier
- `title`, `summary`, `description` metadata
- `kind` enum: `source`, `transform`, `router`, `llm`, `action`, `checkpoint`, `publish`, `terminal`, `integration`
- `runtime` with `language` (`go`, `python`, `nodejs`), `handler`, `invocation` (`inProcess`, `http`, `kafka`, `grpc`), `image`, `version`
- `inputs` and `outputs` as typed port arrays with `name` and `message.$ref`
- `execution` config: `timeoutMs`, `concurrency`, `maxRetries`
- `idempotency` config: `enabled`, `keyExpression`, `ttlSeconds`, `store`

#### Edge
- `from` and `to` node ID references
- `when` condition expression for conditional routing
- `delivery` policy (required)
- `description` metadata

#### Delivery policy
- Five delivery modes: `direct`, `ephemeralQueue`, `checkpoint`, `durableQueue`, `eventBus`
- `backend` field for `ephemeralQueue` (redis, mongo, kafka, memory)
- `store` field for `durableQueue` and `checkpoint` (mongo, redis)
- `batching` config: `enabled`, `batchSize`, `maxWaitMs`
- `maxInFlight` for flow control
- `retryPolicy` inline or `$ref`
- `recovery` config: `replayFrom`, `strategy`
- `eventBus` config: `bus`, `topic`, `partitionKey`
- `ordering` enum: `none`, `perKey`, `strict`
- `priority` integer 0–10
- Conditional validation: `durableQueue` requires `store`, `eventBus` requires `eventBus` config, `ephemeralQueue` requires `backend`

#### Retry policy
- `maxAttempts`, `initialDelayMs`, `backoff` (`fixed`, `exponential`, `linear`)
- `maxDelayMs`, `deadLetterQueue`

#### Components
- `nodes` — reusable node definitions
- `edges` — reusable edge definitions
- `policies` — reusable retry policies
- `packets` — internal packet JSON schemas
- `schemas` — shared JSON schema definitions
- `runtimeBindings` — named backend configurations (mongo, redis, kafka)

#### Examples
- `domain-pipeline.flowdsl.json` — high-throughput domain drop catch pipeline
- `domain-pipeline.flowdsl.yaml` — same pipeline in YAML
- Demonstrates all five delivery modes in a single document

#### x-ui extension
- `group`, `icon`, `color`, `position` — canvas layout hints for FlowDSL Studio

---

[Unreleased]: https://github.com/flowdsl/spec/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/flowdsl/spec/releases/tag/v1.0.0
