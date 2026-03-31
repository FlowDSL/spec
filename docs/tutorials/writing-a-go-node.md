---
title: Write a FlowDSL Node in Go
description: Implement, register, and test a FlowDSL FilterNode using the flowdsl-go SDK.
weight: 207
---

This tutorial implements the `filter_by_priority` node from the webhook router tutorial using the `flowdsl-go` SDK. By the end you'll have a running node that the FlowDSL runtime can connect to.

## What you'll build

A `FilterNode` that reads the `priority` field from an incoming payload and routes the packet to one of two named outputs: `urgent_out` (P0/P1) or `normal_out` (P2+).

## Prerequisites

- Go 1.21 or later: `go version`
- FlowDSL runtime running locally (see [Docker Compose Local](/docs/tutorials/docker-compose-local))

## Step 1: Initialize the project

```bash
mkdir flowdsl-filter-node
cd flowdsl-filter-node
go mod init github.com/myorg/flowdsl-filter-node
go get github.com/flowdsl/flowdsl-go
```

## Step 2: Project structure

```
flowdsl-filter-node/
├── main.go
├── node.go
├── flowdsl-node.json
└── go.mod
```

## Step 3: Implement the NodeHandler interface

Create `node.go`:

```go
package main

import (
    "context"
    "fmt"

    flowdsl "github.com/flowdsl/flowdsl-go"
)

// FilterNode implements the filter_by_priority operation.
// It reads the "priority" field from the input packet and routes
// P0/P1 events to "urgent_out", P2+ to "normal_out".
type FilterNode struct {
    urgentPriorities map[string]bool
}

// OperationID returns the snake_case identifier that matches the
// operationId in the FlowDSL document.
func (n *FilterNode) OperationID() string {
    return "filter_by_priority"
}

// Init is called once at startup with the node's static settings.
func (n *FilterNode) Init(settings flowdsl.Settings) error {
    urgentList, _ := settings.GetStringSlice("urgentPriorities")
    if len(urgentList) == 0 {
        urgentList = []string{"P0", "P1"}
    }
    n.urgentPriorities = make(map[string]bool, len(urgentList))
    for _, p := range urgentList {
        n.urgentPriorities[p] = true
    }
    return nil
}

// Handle is called once per incoming packet.
func (n *FilterNode) Handle(ctx context.Context, input flowdsl.NodeInput) (flowdsl.NodeOutput, error) {
    // Read the input packet from the "in" port
    payload, err := input.Packet("in")
    if err != nil {
        return flowdsl.NodeOutput{}, fmt.Errorf("filter_by_priority: reading input: %w", err)
    }

    // Extract the priority field
    priority, ok := payload.GetString("priority")
    if !ok {
        // Missing priority — treat as normal
        priority = "P2"
    }

    // Route based on priority
    if n.urgentPriorities[priority] {
        return flowdsl.NodeOutput{}.Send("urgent_out", payload), nil
    }
    return flowdsl.NodeOutput{}.Send("normal_out", payload), nil
}
```

### Key interfaces

**`flowdsl.NodeInput`** — the input wrapper. Methods:
- `Packet(portName string) (flowdsl.Packet, error)` — read a packet from a named input port
- `Context() context.Context` — the execution context with tracing and cancellation

**`flowdsl.Packet`** — the packet wrapper. Methods:
- `GetString(key string) (string, bool)` — read a string field
- `GetInt(key string) (int64, bool)` — read an integer field
- `GetFloat(key string) (float64, bool)` — read a float field
- `GetBool(key string) (bool, bool)` — read a bool field
- `GetMap(key string) (map[string]any, bool)` — read a nested object
- `Data() map[string]any` — get the raw underlying map

**`flowdsl.NodeOutput`** — the output builder. Methods:
- `Send(portName string, packet flowdsl.Packet) NodeOutput` — route a packet to a named output port
- `SendMap(portName string, data map[string]any) NodeOutput` — send from raw map

## Step 4: Create the entry point

Create `main.go`:

```go
package main

import (
    "log/slog"
    "os"

    flowdsl "github.com/flowdsl/flowdsl-go"
)

func main() {
    logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
        Level: slog.LevelInfo,
    }))

    server := flowdsl.NewNodeServer(
        flowdsl.WithLogger(logger),
        flowdsl.WithGRPCPort(50051),
        flowdsl.WithManifestFile("flowdsl-node.json"),
    )

    server.Register(&FilterNode{})

    logger.Info("starting filter-node gRPC server", "port", 50051)
    if err := server.ServeGRPC(); err != nil {
        logger.Error("server failed", "error", err)
        os.Exit(1)
    }
}
```

The node server now starts a gRPC server on port 50051 (the default for Go nodes). The runtime connects to this port to invoke the node via the `NodeService` gRPC contract. See [gRPC Protocol](/docs/reference/grpc-protocol) for details.

## Step 5: Write the manifest

Create `flowdsl-node.json`:

```json
{
  "operationId": "filter_by_priority",
  "name": "Filter by Priority",
  "version": "1.0.0",
  "description": "Routes packets to urgent_out (P0/P1) or normal_out (P2+) based on the priority field",
  "runtime": "go",
  "inputs": [
    {
      "name": "in",
      "packet": "TransformedPayload",
      "description": "Incoming event payload with a priority field"
    }
  ],
  "outputs": [
    {
      "name": "urgent_out",
      "packet": "TransformedPayload",
      "description": "P0 and P1 events"
    },
    {
      "name": "normal_out",
      "packet": "TransformedPayload",
      "description": "P2 and below events"
    }
  ],
  "settings": {
    "type": "object",
    "properties": {
      "urgentPriorities": {
        "type": "array",
        "items": { "type": "string" },
        "default": ["P0", "P1"],
        "description": "Priority codes that route to urgent_out"
      }
    }
  },
  "author": "My Team",
  "license": "Apache-2.0",
  "tags": ["routing", "priority", "filter"]
}
```

## Step 6: Build and run

```bash
go build -o filter-node .
./filter-node
```

```json
{"time":"2026-03-28T10:00:00Z","level":"INFO","msg":"starting filter-node gRPC server","port":50051}
```

## Step 7: Register with the runtime

Add the node to your `node-registry.yaml`:

```yaml
nodes:
  filter_by_priority:
    address: localhost:50051
    transport: grpc
    version: "1.0.0"
    runtime: go
```

## Step 8: Test with a sample flow

Start the runtime with the webhook router flow:

```bash
FLOWDSL_REGISTRY_FILE=./node-registry.yaml \
flowdsl-runtime start webhook-router.flowdsl.yaml
```

Send a test event:

```bash
curl -X POST http://localhost:8081/flows/webhook-router/trigger \
  -H "Content-Type: application/json" \
  -d '{
    "priority": "P0",
    "title": "Production database unreachable",
    "source": "alertmanager",
    "timestamp": "2026-03-28T10:00:00Z"
  }'
```

Check the execution log — you should see the `FilterNode` routing the packet to `urgent_out`.

## Error handling patterns

```go
func (n *FilterNode) Handle(ctx context.Context, input flowdsl.NodeInput) (flowdsl.NodeOutput, error) {
    payload, err := input.Packet("in")
    if err != nil {
        // Return a typed FlowDSL error for proper dead letter categorization
        return flowdsl.NodeOutput{}, flowdsl.NewNodeError(
            flowdsl.ErrCodeInputMissing,
            "missing input packet on port 'in'",
            err,
        )
    }

    priority, ok := payload.GetString("priority")
    if !ok {
        // Return a validation error — this will NOT be retried (it's a data problem)
        return flowdsl.NodeOutput{}, flowdsl.NewNodeError(
            flowdsl.ErrCodeValidation,
            "priority field missing from payload",
            nil,
        )
    }

    // ... routing logic
}
```

FlowDSL error codes:
- `ErrCodeValidation` — data problem, not retriable
- `ErrCodeTimeout` — transient, retriable
- `ErrCodeRateLimited` — transient, retriable
- `ErrCodeTemporary` — transient, retriable
- `ErrCodePermanent` — permanent failure, move to dead letter immediately

## Logging and observability

```go
func (n *FilterNode) Handle(ctx context.Context, input flowdsl.NodeInput) (flowdsl.NodeOutput, error) {
    // Extract FlowDSL trace context for correlated logging
    traceCtx := flowdsl.TraceFromContext(ctx)

    logger := slog.With(
        "flowId", traceCtx.FlowID,
        "executionId", traceCtx.ExecutionID,
        "nodeId", "FilterByPriority",
    )

    payload, err := input.Packet("in")
    if err != nil {
        logger.Error("failed to read input packet", "error", err)
        return flowdsl.NodeOutput{}, err
    }

    priority, _ := payload.GetString("priority")
    logger.Info("routing packet", "priority", priority)

    // ...
}
```

## Summary

| File | Purpose |
|------|---------|
| `node.go` | Node handler implementing `flowdsl.NodeHandler` |
| `main.go` | Node server that registers and serves the handler |
| `flowdsl-node.json` | Manifest describing the node to the registry |

## Next steps

- [Write a Python Node](/docs/tutorials/writing-a-python-node) — the same node in Python
- [Node Development](/docs/guides/node-development) — testing, versioning, publishing
- [Node Manifest reference](/docs/reference/node-manifest) — full manifest field reference
