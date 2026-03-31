---
title: Go SDK Reference
description: Reference for the flowdsl-go SDK — implementing and running FlowDSL nodes in Go.
weight: 503
---

`github.com/flowdsl/flowdsl-go` is the official Go SDK for implementing FlowDSL node handlers and running the FlowDSL runtime.

## Installation

```bash
go get github.com/flowdsl/flowdsl-go
```

## Core interfaces

### `NodeHandler`

Every node implements this interface:

```go
type NodeHandler interface {
    OperationID() string
    Init(settings Settings) error
    Handle(ctx context.Context, input NodeInput) (NodeOutput, error)
}
```

### `NodeInput`

```go
type NodeInput interface {
    Packet(portName string) (Packet, error)
    Context() ExecutionContext
}
```

### `Packet`

```go
type Packet interface {
    GetString(key string) (string, bool)
    GetStringOr(key, defaultVal string) string
    GetInt(key string) (int64, bool)
    GetFloat(key string) (float64, bool)
    GetBool(key string) (bool, bool)
    GetMap(key string) (map[string]any, bool)
    Data() map[string]any
    Has(key string) bool
}
```

### `NodeOutput`

```go
// Build output by chaining Send calls
output := flowdsl.NodeOutput{}.Send("out", resultPacket)

// Multiple outputs (for router nodes)
output := flowdsl.NodeOutput{}.
    Send("urgent_out", urgentPacket).
    Send("normal_out", normalPacket)
```

### `NodeServer`

```go
server := flowdsl.NewNodeServer(
    flowdsl.WithPort(8080),
    flowdsl.WithLogger(logger),
    flowdsl.WithManifestFile("flowdsl-node.json"),
    flowdsl.WithTLSConfig(tlsConfig),
)
server.Register(&MyNode{})
server.ListenAndServe()
```

## Error types

```go
// Return typed errors for proper runtime handling
return flowdsl.NodeOutput{}, flowdsl.NewNodeError(
    flowdsl.ErrCodeRateLimited,  // or: ErrCodeTimeout, ErrCodeTemporary, ErrCodeValidation, ErrCodePermanent
    "Rate limit exceeded",
    originalErr,
)
```

## ExecutionContext

```go
ctx := input.Context()
ctx.FlowID        // string: the flow ID
ctx.ExecutionID   // string: unique execution context ID
ctx.NodeID        // string: the current node name
ctx.IdempotencyKey // string: the edge's idempotency key (empty if not set)
ctx.TraceHeaders  // map[string]string: distributed tracing headers
```

## Settings

```go
type Settings map[string]any

func (s Settings) GetString(key string) (string, bool)
func (s Settings) GetStringOr(key, defaultVal string) string
func (s Settings) GetInt(key string) (int64, bool)
func (s Settings) GetBool(key string) (bool, bool)
func (s Settings) GetStringSlice(key string) ([]string, bool)
```

## Testing

```go
import "github.com/flowdsl/flowdsl-go/testing"

func TestMyNode(t *testing.T) {
    node := &MyNode{}
    err := node.Init(flowdsl.Settings{"key": "value"})
    require.NoError(t, err)

    input := flowdsltesting.NewMockInput("in", map[string]any{
        "field": "value",
    })

    output, err := node.Handle(context.Background(), input)
    require.NoError(t, err)

    result := output.Packet("out")
    assert.Equal(t, "expected", result.GetStringOr("field", ""))
}
```

## Complete node example

```go
package main

import (
    "context"
    flowdsl "github.com/flowdsl/flowdsl-go"
    "log/slog"
    "os"
)

type FilterNode struct {
    urgentPriorities map[string]bool
}

func (n *FilterNode) OperationID() string { return "filter_by_priority" }

func (n *FilterNode) Init(settings flowdsl.Settings) error {
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

func (n *FilterNode) Handle(ctx context.Context, input flowdsl.NodeInput) (flowdsl.NodeOutput, error) {
    payload, err := input.Packet("in")
    if err != nil {
        return flowdsl.NodeOutput{}, err
    }
    priority := payload.GetStringOr("priority", "P2")
    if n.urgentPriorities[priority] {
        return flowdsl.NodeOutput{}.Send("urgent_out", payload), nil
    }
    return flowdsl.NodeOutput{}.Send("normal_out", payload), nil
}

func main() {
    server := flowdsl.NewNodeServer(flowdsl.WithPort(8080))
    server.Register(&FilterNode{})
    slog.Info("starting", "port", 8080)
    server.ListenAndServe()
}
```

## Next steps

- [Write a Go Node tutorial](/docs/tutorials/writing-a-go-node) — full step-by-step guide
- [Python SDK](/docs/tools/python-sdk) — Python equivalent
