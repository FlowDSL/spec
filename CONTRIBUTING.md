# Contributing to FlowDSL

Thank you for your interest in contributing to FlowDSL — the open specification for executable event-driven flow graphs.

## Ways to contribute

- **Spec improvements** — propose changes to `flowdsl.schema.json`
- **New examples** — add real-world `.flowdsl.yaml` examples in `examples/`
- **Documentation** — improve or expand docs in `docs/`
- **Bug reports** — schema issues, validation gaps, unclear definitions
- **Discussions** — propose new delivery modes, node kinds, or spec extensions

---

## Before you start

Check open issues and discussions first — your idea may already be in progress.
For significant changes to the spec, open a **Discussion** before a PR.
The spec follows semantic versioning — breaking changes require a major version bump.

---

## Development setup

No build step required for the spec itself.
To validate examples against the schema locally:

```bash
npm install -g ajv-cli

# validate an example
ajv validate -s schemas/flowdsl.schema.json -d examples/domain-pipeline.flowdsl.json
```

To run all example validations:

```bash
for f in examples/*.json; do
  echo "Validating $f..."
  ajv validate -s schemas/flowdsl.schema.json -d "$f"
done
```

---

## Schema change guidelines

### Backward-compatible changes (minor version bump)
- Adding new optional fields with defaults
- Adding new enum values to `node.kind`
- Adding new delivery mode backends
- Clarifying descriptions

### Breaking changes (major version bump)
- Removing or renaming existing fields
- Changing field types
- Making optional fields required
- Removing enum values

### Extensions
Use `x-*` prefix for experimental or vendor-specific additions.
Do not promote `x-*` fields to first-class spec fields without a Discussion.

---

## Pull request checklist

- [ ] Schema changes validated with `ajv validate`
- [ ] Examples updated if schema changes affect them
- [ ] New examples added for new features
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] Field names use `camelCase`
- [ ] `$ref` used for all cross-references (no inline duplicates)
- [ ] No AsyncAPI message schemas duplicated — use `asyncapi#/...` refs

---

## Naming conventions

- JSON field names: `camelCase`
- Example file names: `kebab-case.flowdsl.json`
- Component names (nodes, packets, policies): `PascalCase`
- Flow IDs and node IDs: `snake_case`
- `operationId` values: `snake_case`

---

## Commit message format

```
type: short description

types: feat, fix, docs, schema, example, chore
```

Examples:
```
feat: add grpc invocation mode to NodeRuntime
fix: make ephemeralQueue backend field required
docs: add delivery mode selection guide
example: add LLM agent flow example
schema: add ordering field to DeliveryPolicy
```

---

## Code of conduct

Be respectful. Focus on the spec, not the person.
Disagreements about design are welcome — hostility is not.

---

## License

By contributing, you agree that your contributions will be licensed under the Apache 2.0 license.
