# Changelog

All notable changes to the FlowDSL specification will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
FlowDSL follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Changed
- NodeRuntime.invocation: default changed from "proc" to "grpc"
- "http" invocation retained but not recommended (latency, security surface)
- Cross-language node invocation now uses gRPC + Protobuf exclusively
- All example node manifests updated to use `invocation: "grpc"` with gRPC config
- NodeRuntime.invocation enum expanded to support 9 transport protocols

### Added
- `schemas/node.proto` — canonical gRPC NodeService contract v1.0.0
- NodeRuntime.grpc configuration object (port, streaming, maxConcurrentStreams, tls)
- NodeRuntime.nats configuration object (url, subject, queueGroup)
- NodeRuntime.redis configuration object (url, channel)
- NodeRuntime.zeromq configuration object (address, pattern)
- NodeRuntime.rabbitmq configuration object (url, exchange, routingKey, queue)
- NodeRuntime.websocket configuration object (url, path)
- `docs/grpc-protocol.md` — full gRPC protocol documentation
- Manifest RPC for node self-registration (replaces manual node-registry.yaml)
- Conditional validation: each transport invocation requires its config object

### Added

#### Node Manifest format
- `flowdsl-node.schema.json` — JSON Schema Draft-07 for the FlowDSL Node Manifest format (`flowdsl-node.json`)
  - Full node identity: `id`, `name`, `version`, `summary`, `description`, `kind`, `language`
  - Author and publication metadata: `author`, `license`, `repoUrl`, `docsUrl`, `publishedAt`, `published`
  - Visual hints: `icon`, `color`, `tags`
  - Runtime configuration: `runtime.handler`, `runtime.invocation`, `runtime.image`
  - Typed port contracts: `inputs` and `outputs` as `NodePort` arrays with inline JSON Schema
  - `settingsSchema` — JSON Schema object that drives the Studio settings form, with `x-ui` extensions for `placeholder`, `group`, `order`, and `secret`
  - `dependencies`, `minRuntimeVersion` for ecosystem compatibility

#### Registry Index format
- `flowdsl-registry.schema.json` — JSON Schema for the registry index served at `repo.flowdsl.com/registry.json`
  - Lightweight `RegistryEntry` objects for search, browsing, and Studio palette population
  - Fields: `id`, `name`, `version`, `summary`, `kind`, `language`, `icon`, `color`, `tags`, `author.name`, `repoUrl`, `docsUrl`, `publishedAt`, `downloadCount`

#### Core node manifests (`examples/nodes/`)
- `email-fetcher.flowdsl-node.json` — IMAP/POP3 mailbox poller (Python, source)
- `llm-analyzer.flowdsl-node.json` — LLM-powered payload analysis with configurable model and prompt (Python, llm)
- `llm-router.flowdsl-node.json` — LLM-based dynamic routing with per-route output ports (Python, router)
- `http-fetcher.flowdsl-node.json` — HTTP endpoint poller with auth support (Go, source)
- `webhook-receiver.flowdsl-node.json` — Inbound HTTP webhook listener with HMAC verification (Go, source)
- `mongo-reader.flowdsl-node.json` — MongoDB collection poller (Go, source)
- `mongo-writer.flowdsl-node.json` — MongoDB insert/update/upsert writer (Go, action)
- `slack-notifier.flowdsl-node.json` — Slack Incoming Webhook message sender with Handlebars templates (Go, action)
- `json-transformer.flowdsl-node.json` — jq-based JSON payload transformation (Go, transform)
- `filter-node.flowdsl-node.json` — Boolean condition router with Passed/Failed outputs (Go, router)
- `sms-alert.flowdsl-node.json` — Twilio/Vonage SMS sender with Handlebars templates (Python, action)

#### Documentation
- `docs/node-manifest.md` — Specification reference for the FlowDSL Node Manifest format, including settingsSchema field reference and Studio form rendering rules

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
- `runtime` with `language` (`go`, `python`, `nodejs`), `handler`, `invocation` (`proc`, `http`, `kafka`, `grpc`), `image`, `version`
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
