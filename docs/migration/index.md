---
title: Migration
description: Version history, breaking changes, and migration guides for the FlowDSL specification and tooling.
weight: 600
---

This section covers breaking changes between FlowDSL specification versions and how to migrate your flows and node implementations.

## Versioning policy

FlowDSL follows semantic versioning for the specification:

- **Patch** releases (1.0.x) — bug fixes in the schema, documentation corrections. No migration required.
- **Minor** releases (1.x.0) — additive, backward-compatible changes. Existing flows continue to work.
- **Major** releases (x.0.0) — breaking changes. Migration guide published.

SDK packages (`flowdsl-go`, `flowdsl-py`, `@flowdsl/sdk`) are versioned independently but document which spec version they implement.

## Checking your spec version

Every FlowDSL document declares its schema version:

```yaml
flowdsl: "1.0"
$schema: "https://flowdsl.com/schemas/v1/flowdsl.schema.json"
```

Run `flowdsl validate` to check compatibility with the latest schema:

```bash
flowdsl validate my-flow.flowdsl.yaml
```

## Current version: 1.0

The initial stable release. No migration required from pre-1.0 drafts — the draft format was not publicly supported.

### What 1.0 established

- Core node kinds: `trigger`, `transform`, `router`, `enricher`, `validator`, `aggregator`, `emitter`, `delay`, `sink`
- Five delivery modes: `direct`, `ephemeral`, `checkpoint`, `durable`, `stream`
- `components.events`, `components.packets`, `components.policies` as first-class
- Edge-level delivery policy (not node-level)
- `operationId` values in `snake_case`, component names in `PascalCase`
- `x-ui` extension fields for canvas layout
- `.flowdsl.yaml` and `.flowdsl.json` file extensions

## Planned: 1.1

The 1.1 minor release is planned to add:

- **`components.schemas`** — reusable JSON Schema fragments shareable across packets and events
- **`node.timeout`** — per-node timeout declaration (currently only on the retry policy)
- **`edge.priority`** — optional integer priority hint for queue-backed modes
- **Flow-level `metadata`** block — arbitrary key/value metadata attached to the flow document

None of these are breaking changes. Flows written for 1.0 will validate and run unchanged on 1.1.

## SDK migration

### Go SDK

The Go SDK (`github.com/flowdsl/flowdsl-go`) follows its own semver. The `NodeHandler` interface is considered stable. Breaking changes will be announced in the SDK changelog and in the GitHub releases page.

To update:

```bash
go get github.com/flowdsl/flowdsl-go@latest
```

### Python SDK

```bash
pip install --upgrade flowdsl-py
```

Check the changelog at [github.com/flowdsl/flowdsl-py](https://github.com/flowdsl/flowdsl-py/releases).

### JavaScript SDK

```bash
npm update @flowdsl/sdk
```

## CLI migration

When the CLI validates your flow, it reports the schema version mismatch if any:

```
⚠ my-flow.flowdsl.yaml uses flowdsl: "1.0" but CLI targets schema 1.1
  All 1.0 documents are valid under 1.1. No changes required.
```

## Getting help with migration

- Open a [GitHub discussion](https://github.com/flowdsl/spec/discussions) for migration questions
- Check the [spec changelog](https://github.com/flowdsl/spec/blob/main/CHANGELOG.md) for detailed diff between versions
- [Community Discord](https://discord.gg/MUjXSwGbUY) — `#migration` channel

## Next steps

- [Community](/docs/community) — contribute, report issues, ask questions
- [CLI Tools](/docs/tools/cli) — use `flowdsl validate` to check your flows
