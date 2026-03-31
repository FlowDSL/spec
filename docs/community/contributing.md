---
title: Contributing
description: How to contribute to FlowDSL — spec, SDKs, Studio, and documentation.
weight: 701
---

All FlowDSL repositories are open source (Apache 2.0) and welcome contributions. This guide covers how to set up your environment, write good PRs, and navigate the review process.

## Before you start

- Check existing [issues](https://github.com/flowdsl/spec/issues) and [discussions](https://github.com/flowdsl/spec/discussions) to avoid duplicate work
- For significant changes, open a discussion or issue first to align on direction before writing code
- Read the [Code of Conduct](/docs/community/code-of-conduct) — all contributors are expected to follow it

## Contributing to the specification

The spec lives at [github.com/flowdsl/spec](https://github.com/flowdsl/spec). It consists of:

- `schema/flowdsl.schema.json` — the canonical JSON Schema
- `docs/` — specification prose
- `examples/` — valid example flow documents used in tests

### Setup

```bash
git clone https://github.com/flowdsl/spec
cd spec
npm install
```

### Validate your schema changes

```bash
# Run schema tests (validates all examples/ against the schema)
npm test

# Check a specific example
npx ajv validate -s schema/flowdsl.schema.json -d examples/order-fulfillment.flowdsl.json
```

### PR checklist for spec changes

- [ ] Update `schema/flowdsl.schema.json`
- [ ] Add or update at least one example in `examples/` that exercises the new field
- [ ] Update the relevant prose doc in `docs/`
- [ ] `npm test` passes
- [ ] PR description explains the motivation and links to any relevant RFC discussion

## Contributing to the Go SDK

The Go SDK lives at [github.com/flowdsl/flowdsl-go](https://github.com/flowdsl/flowdsl-go).

### Setup

```bash
git clone https://github.com/flowdsl/flowdsl-go
cd flowdsl-go
go mod download
```

### Run tests

```bash
go test ./...

# With race detector
go test -race ./...

# Integration tests (requires Docker)
make test-integration
```

### Code style

- `gofmt` and `golangci-lint` are enforced in CI
- Run `make lint` before opening a PR
- Keep the `NodeHandler` interface stable — changes require a major version bump

## Contributing to the Python SDK

The Python SDK lives at [github.com/flowdsl/flowdsl-py](https://github.com/flowdsl/flowdsl-py).

### Setup

```bash
git clone https://github.com/flowdsl/flowdsl-py
cd flowdsl-py
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

### Run tests

```bash
pytest
pytest --cov=flowdsl --cov-report=term-missing
```

### Code style

```bash
ruff check .
ruff format .
mypy flowdsl/
```

## Contributing to Studio

Studio lives at [github.com/flowdsl/studio](https://github.com/flowdsl/studio). Built with React 18, TypeScript, React Flow, and Zustand.

### Setup

```bash
git clone https://github.com/flowdsl/studio
cd studio
npm install
npm run dev
# Open http://localhost:5173
```

### Run tests

```bash
npm test          # Vitest unit tests
npm run e2e       # Playwright end-to-end tests
```

### Component conventions

- Components live in `src/components/`
- The `NodeContractCard` component is the signature UI — preserve its bilateral contract layout
- Keep canvas state in Zustand, not local component state
- Do not add runtime communication logic to Studio — it is a document editor only

## Contributing to the website (docs)

The website lives at [github.com/flowdsl/website](https://github.com/flowdsl/website). Built with NuxtJS 4 and @nuxt/content.

### Setup

```bash
git clone https://github.com/flowdsl/website
cd website
npm install
npm run dev
# Open http://localhost:3000
```

### Adding or editing docs

Documentation lives in `spec/docs/` as Markdown files. Each file has frontmatter:

```yaml
---
title: My Page
description: One-line description.
weight: 350
---
```

The `weight` field controls the order in prev/next navigation. Leave gaps between weights (e.g., 300, 310, 320) so new pages can be inserted without renumbering.

### Docs style guide

- Use `##` for top-level sections (the page H1 is the title)
- Code blocks must specify a language: ` ```yaml `, ` ```go `, ` ```bash `
- Use callout syntax for tips and warnings:
  ```
  ::callout{type="tip"}
  Your tip here.
  ::
  ```
- Link to related docs with relative paths: `[Delivery Modes](/docs/concepts/delivery-modes)`
- End every page with a "Next steps" section

## Opening a pull request

1. Fork the repository and create a branch: `git checkout -b my-feature`
2. Make your changes with tests
3. Run the linter and test suite
4. Push and open a PR against `main`
5. Fill in the PR template — describe the change and link the issue

PRs are reviewed by maintainers within a few business days. Small, focused PRs with clear descriptions are reviewed faster.

## Next steps

- [Community](/docs/community) — other ways to get involved
- [Code of Conduct](/docs/community/code-of-conduct) — community standards
