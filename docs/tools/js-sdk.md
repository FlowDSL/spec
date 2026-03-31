---
title: JavaScript SDK Reference
description: Reference for the @flowdsl/sdk — implementing FlowDSL nodes in TypeScript and Node.js.
weight: 505
---

`@flowdsl/sdk` is the official TypeScript/JavaScript SDK for implementing FlowDSL node handlers in Node.js.

## Installation

```bash
npm install @flowdsl/sdk
# or
yarn add @flowdsl/sdk
```

## Core types

```typescript
import {
  BaseNode,
  NodeInput,
  NodeOutput,
  NodeError,
  ErrorCode,
  NodeServer,
} from '@flowdsl/sdk'
```

### `BaseNode`

```typescript
abstract class BaseNode {
  abstract operationId: string

  async init(settings: Record<string, unknown>): Promise<void> {}

  abstract handle(input: NodeInput): Promise<NodeOutput>
}
```

### `NodeInput`

```typescript
interface NodeInput {
  packet(portName: string): Promise<Packet>
  context: ExecutionContext
}
```

### `Packet`

```typescript
interface Packet {
  data: Record<string, unknown>
  get(key: string, defaultValue?: unknown): unknown
  getString(key: string, defaultValue?: string): string
  getNumber(key: string, defaultValue?: number): number
  getBoolean(key: string, defaultValue?: boolean): boolean
  has(key: string): boolean
}
```

### `NodeOutput`

```typescript
class NodeOutput {
  send(portName: string, data: Record<string, unknown> | Packet): NodeOutput
}
```

## Complete example

```typescript
import { BaseNode, NodeInput, NodeOutput, NodeError, ErrorCode, NodeServer } from '@flowdsl/sdk'

class FilterNode extends BaseNode {
  operationId = 'filter_by_priority'
  private urgentPriorities = new Set(['P0', 'P1'])

  async init(settings: Record<string, unknown>): Promise<void> {
    const priorities = settings.urgentPriorities as string[] | undefined
    if (priorities) {
      this.urgentPriorities = new Set(priorities)
    }
  }

  async handle(input: NodeInput): Promise<NodeOutput> {
    const payload = await input.packet('in')
    const priority = payload.getString('priority', 'P2')

    if (this.urgentPriorities.has(priority)) {
      return new NodeOutput().send('urgent_out', payload.data)
    }
    return new NodeOutput().send('normal_out', payload.data)
  }
}

const server = new NodeServer({
  port: 8080,
  manifestFile: 'flowdsl-node.json',
})
server.register(new FilterNode())
server.listen()
```

## Next steps

- [Write a Go Node](/docs/tutorials/writing-a-go-node) — same pattern in Go
- [Write a Python Node](/docs/tutorials/writing-a-python-node) — same pattern in Python
