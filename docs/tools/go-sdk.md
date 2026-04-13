---
title: Go SDK Reference
description: Reference for the flowdsl-go SDK — implementing FlowDSL node handlers, parsing documents, and validating flows in Go.
weight: 503
---

`github.com/flowdsl/flowdsl-go` is the official Go SDK for building FlowDSL nodes, parsing FlowDSL documents, and validating flow graphs. It has zero external dependencies — only the Go standard library.

## Installation

```bash
go get github.com/flowdsl/flowdsl-go
```

## Packages

| Package | Import | Purpose |
|---------|--------|---------|
| `pkg/node` | `github.com/flowdsl/flowdsl-go/pkg/node` | Node handler interfaces, Packet, Settings, errors, manifests |
| `pkg/spec` | `github.com/flowdsl/flowdsl-go/pkg/spec` | FlowDSL document types, JSON loader, validator |
| `pkg/runtime` | `github.com/flowdsl/flowdsl-go/pkg/runtime` | Abstract runtime interfaces (Engine, Checkpoint, DeliveryAdapter) |

## Node handler (`pkg/node`)

### `NodeHandler`

Every node implements this interface:

```go
import "github.com/flowdsl/flowdsl-go/pkg/node"

type NodeHandler interface {
    OperationID() string
    Init(settings node.Settings) error
    Handle(ctx context.Context, input node.NodeInput) (node.NodeOutput, error)
}
```

`OperationID()` returns the snake_case identifier that matches the `operationId` in the FlowDSL document. `Init` is called once at startup with static settings. `Handle` is called once per incoming packet.

### `NodeInput`

```go
type NodeInput interface {
    Packet(portName string) (Packet, error)
    Context() ExecutionContext
}
```

`Packet` reads the data arriving on a named input port. If the port doesn't exist, it returns a `NodeError` with code `INPUT_MISSING`.

### `Packet`

```go
type Packet interface {
    GetString(key string) (string, bool)
    GetStringOr(key, defaultVal string) string
    GetInt(key string) (int64, bool)
    GetFloat(key string) (float64, bool)
    GetBool(key string) (bool, bool)
    GetMap(key string) (map[string]any, bool)
    GetSlice(key string) ([]any, bool)
    Data() map[string]any
    Has(key string) bool
}
```

Create packets with `node.NewPacket(map[string]any{...})`. All numeric getters handle JSON number coercion (float64 ↔ int64).

### `NodeOutput`

Build output by chaining `Send` or `SendMap` calls:

```go
// Single output port
output := node.NodeOutput{}.SendMap("out", map[string]any{
    "result": "hello",
})

// Multiple output ports (for router nodes)
output := node.NodeOutput{}.
    SendMap("urgent", map[string]any{"priority": "P0"}).
    SendMap("normal", map[string]any{"priority": "P2"})
```

Methods on `NodeOutput`:

- `Send(port string, pkt Packet) NodeOutput` — send a Packet to a port
- `SendMap(port string, data map[string]any) NodeOutput` — send a map as a Packet
- `Packet(port string) Packet` — retrieve the Packet on a port
- `HasPort(port string) bool` — check if a port has data
- `IsEmpty() bool` — true if no ports have data
- `Packets() map[string]Packet` — all port→Packet pairs

### `ExecutionContext`

```go
type ExecutionContext struct {
    FlowID         string            `json:"flowId"`
    ExecutionID    string            `json:"executionId"`
    NodeID         string            `json:"nodeId"`
    IdempotencyKey string            `json:"idempotencyKey,omitempty"`
    TraceHeaders   map[string]string `json:"traceHeaders,omitempty"`
}
```

Access via `input.Context()`. The context is also embedded in the standard `context.Context` — use `node.TraceFromContext(ctx)` to extract trace headers in downstream calls.

### `Settings`

```go
type Settings map[string]any

func (s Settings) GetString(key string) (string, bool)
func (s Settings) GetStringOr(key, defaultVal string) string
func (s Settings) GetInt(key string) (int64, bool)
func (s Settings) GetFloat(key string) (float64, bool)
func (s Settings) GetBool(key string) (bool, bool)
func (s Settings) GetStringSlice(key string) ([]string, bool)
func (s Settings) Has(key string) bool
```

### Error handling

Return typed errors so the runtime knows how to handle failures:

```go
return node.NodeOutput{}, node.NewNodeError(
    node.ErrCodeRateLimited,
    "Rate limit exceeded",
    originalErr,  // cause (may be nil)
)
```

Error codes:

| Code | Constant | Retriable |
|------|----------|-----------|
| `VALIDATION` | `ErrCodeValidation` | No |
| `INPUT_MISSING` | `ErrCodeInputMissing` | No |
| `PERMANENT` | `ErrCodePermanent` | No |
| `TIMEOUT` | `ErrCodeTimeout` | Yes |
| `RATE_LIMITED` | `ErrCodeRateLimited` | Yes |
| `TEMPORARY` | `ErrCodeTemporary` | Yes |

Use `node.IsRetriable(err)` to check if any error in a chain is retriable (works with wrapped errors). Use `node.AsNodeError(err, &ne)` to extract a `*NodeError` from a chain.

### Node manifests

Load and work with `.flowdsl-node.json` manifest files:

```go
// Load a single manifest
m, err := node.LoadManifest("my-node.flowdsl-node.json")

// Load all manifests from a directory
manifests, err := node.LoadManifestsFromDir("./nodes/")

// Parse from bytes
m, err := node.ParseManifest(jsonBytes)

// Write a manifest
err := node.WriteManifest(m, "output.flowdsl-node.json")
```

The `Manifest` struct matches the [flowdsl-node.schema.json](/schemas/v1/flowdsl-node.schema.json) specification, including node kind, runtime protocols, ports, and settings schema.

## FlowDSL documents (`pkg/spec`)

### Types

The `spec.Document` type maps to the canonical FlowDSL JSON Schema. It includes `Info`, `Server`, `Flow`, `Node`, `Edge`, `DeliveryPolicy`, `Components` (events, packets, reusable nodes, policies), and all related sub-types.

### Loading and parsing

```go
import "github.com/flowdsl/flowdsl-go/pkg/spec"

// Load from file (auto-detects .json / .yaml extension)
doc, err := spec.Load("my-flow.flowdsl.json")

// Parse from a reader
doc, err := spec.ParseJSON(reader)

// Write back to JSON
err := spec.WriteJSON(doc, "output.flowdsl.json")

// Marshal to bytes
data, err := spec.MarshalJSON(doc)
```

YAML parsing requires the `yamlloader` adapter. Without it, YAML files containing JSON content (starting with `{`) are handled automatically; pure YAML returns a descriptive error.

### Validation

```go
result := spec.Validate(doc)

if result.HasErrors() {
    for _, d := range result.Errors() {
        fmt.Println(d)  // [error] flows.main.nodes.x.operationId: operationId is required (FDL020)
    }
}

for _, d := range result.Warnings() {
    fmt.Println(d)
}
```

Validation codes:

| Code | Severity | Checks |
|------|----------|--------|
| FDL001 | error | document is nil |
| FDL002 | error/warn | flowdsl version empty or unsupported |
| FDL003 | error | info.title is empty |
| FDL004 | warning | info.version is empty |
| FDL005 | error | no flows defined |
| FDL010 | error | flow has no entrypoints |
| FDL011 | error | flow has no nodes |
| FDL012 | warning | flow has no edges |
| FDL020 | error | node missing operationId |
| FDL021 | warning | operationId format (must be `^[a-z][a-z0-9_]*$`) |
| FDL022 | warning | node runtime is empty |
| FDL023 | warning | unrecognised node kind |
| FDL030 | error | edge references unknown source node |
| FDL031 | error | edge references unknown target node |
| FDL032 | warning | unrecognised delivery mode |
| FDL040 | warning | unrecognised server protocol |
| FDL050 | warning | $ref does not match a component node |

## Runtime interfaces (`pkg/runtime`)

Abstract interfaces for runtime implementors. These have no concrete implementation in the SDK — implementations live in downstream projects (e.g. redelay/go-flowdsl for MongoDB/Redis/Kafka, or cloud-runtime for managed hosting).

```go
import "github.com/flowdsl/flowdsl-go/pkg/runtime"

type Engine interface {
    Start(ctx context.Context, flow *spec.Flow, input map[string]any) (*ExecutionRecord, error)
    Resume(ctx context.Context, executionID string) (*ExecutionRecord, error)
    Status(ctx context.Context, executionID string) (*ExecutionRecord, error)
}

type Checkpoint interface {
    Save(ctx context.Context, exec *ExecutionRecord) error
    Load(ctx context.Context, executionID string) (*ExecutionRecord, error)
    SaveStep(ctx context.Context, step *StepRecord) error
}

type DeliveryAdapter interface {
    Deliver(ctx context.Context, packet *DeliveryPacket) error
    Mode() DeliveryMode
}

type NodeRegistry interface {
    Lookup(operationID string) any
    Register(operationID string, handler any)
}
```

## CLI: `flowdsl-validate`

A standalone validation tool for FlowDSL documents:

```bash
go install github.com/flowdsl/flowdsl-go/cmd/flowdsl-validate@latest

# Validate a document
flowdsl-validate my-flow.flowdsl.json

# Multiple files
flowdsl-validate flow1.flowdsl.json flow2.flowdsl.json
```

Exit codes: 0 = valid, 1 = has errors, 2 = file read/parse failure.

## Testing nodes

The `pkg/node` package includes mock utilities for testing node handlers without a runtime:

```go
import "github.com/flowdsl/flowdsl-go/pkg/node"

func TestMyNode(t *testing.T) {
    n := &MyNode{}
    _ = n.Init(node.Settings{"threshold": float64(10)})

    // Single-port input
    input := node.NewMockInput("in", map[string]any{
        "value": float64(42),
    })

    out, err := n.Handle(context.Background(), input)
    if err != nil {
        t.Fatal(err)
    }

    p := out.Packet("out")
    if s := p.GetStringOr("result", ""); s != "expected" {
        t.Errorf("result = %q", s)
    }
}

func TestMultiPortNode(t *testing.T) {
    // Multi-port input
    input := node.NewMockInputMulti(map[string]map[string]any{
        "data":   {"value": float64(1)},
        "config": {"mode": "fast"},
    })

    // With execution context
    input = input.WithContext(node.ExecutionContext{
        FlowID:      "my-flow",
        ExecutionID: "exec-001",
        NodeID:      "my-node",
    })
    // ...
}
```

## Complete example

```go
package main

import (
    "context"
    "fmt"
    "github.com/flowdsl/flowdsl-go/pkg/node"
)

// FilterNode routes packets based on priority.
type FilterNode struct {
    urgentPriorities map[string]bool
}

func (n *FilterNode) OperationID() string { return "filter_by_priority" }

func (n *FilterNode) Init(settings node.Settings) error {
    list, _ := settings.GetStringSlice("urgentPriorities")
    if len(list) == 0 {
        list = []string{"P0", "P1"}
    }
    n.urgentPriorities = make(map[string]bool)
    for _, p := range list {
        n.urgentPriorities[p] = true
    }
    return nil
}

func (n *FilterNode) Handle(ctx context.Context, input node.NodeInput) (node.NodeOutput, error) {
    pkt, err := input.Packet("in")
    if err != nil {
        return node.NodeOutput{}, err
    }
    priority := pkt.GetStringOr("priority", "P2")
    data := pkt.Data()

    if n.urgentPriorities[priority] {
        return node.NodeOutput{}.SendMap("urgent_out", data), nil
    }
    return node.NodeOutput{}.SendMap("normal_out", data), nil
}

func main() {
    n := &FilterNode{}
    _ = n.Init(node.Settings{
        "urgentPriorities": []any{"P0", "P1"},
    })

    input := node.NewMockInput("in", map[string]any{
        "priority": "P0",
        "message":  "Server is down",
    })

    out, _ := n.Handle(context.Background(), input)
    if out.HasPort("urgent_out") {
        fmt.Println("Routed to urgent")
    }
}
```

## Architecture note

`flowdsl-go` is a **specification and abstraction layer** with zero external dependencies. It does not include concrete transport or storage implementations (MongoDB, Redis, Kafka, etc.). Concrete runtime implementations belong in downstream projects:

- **redelay/go-flowdsl** — full runtime using the redelay framework (MongoDB checkpoint, Redis locks, Kafka streaming)
- **cloud-runtime** — managed FlowDSL hosting infrastructure

## Next steps

- [Write a Go Node tutorial](/docs/tutorials/writing-a-go-node) — full step-by-step guide
- [Python SDK](/docs/tools/python-sdk) — Python equivalent
- [FlowDSL Specification](/docs/reference/specification) — the canonical spec
