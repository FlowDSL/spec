# FlowDSL Core Concepts

FlowDSL describes executable event-driven flow graphs. A document contains flows, which are graphs of nodes connected by edges. Delivery semantics live on the edges, not the nodes.

---

## Flow

A **Flow** is a named, executable processing pipeline — a directed graph of nodes connected by edges. Every flow has at least one entrypoint that triggers it.

```yaml
flows:
  order_fulfillment:
    summary: Process incoming orders end-to-end
    entrypoints:
      - message:
          $ref: "asyncapi#/components/messages/OrderPlaced"
    nodes: { ... }
    edges: [ ... ]
```

A document can define multiple flows. Flow IDs use `snake_case`.

---

## Node

A **Node** is a single executable processing unit. It receives typed input messages, performs logic, and emits typed output messages. Nodes declare what they do, not how data moves between them — that is the edge's job.

```yaml
components:
  nodes:
    ValidateOrderNode:
      operationId: validate_order
      kind: transform
      runtime:
        language: python
        handler: app.nodes.orders.ValidateOrderNode
        supports:
          - http
      inputs:
        - name: OrderPlaced
          message:
            $ref: "asyncapi#/components/messages/OrderPlaced"
      outputs:
        - name: OrderValid
          message:
            $ref: "#/components/packets/OrderValidPacket"
        - name: OrderInvalid
          message:
            $ref: "#/components/packets/OrderInvalidPacket"
```

Node kinds: `source`, `transform`, `router`, `llm`, `action`, `checkpoint`, `publish`, `terminal`, `integration`.

Node IDs (keys in `flow.nodes`) use `snake_case`. Component names (keys in `components.nodes`) use `PascalCase`.

---

## Edge

An **Edge** connects two nodes and defines the delivery semantics for that connection. Edges carry a `delivery` policy that controls durability, buffering, and retry behavior.

```yaml
edges:
  - from: validate_order
    to: reserve_inventory
    when: "output.name == 'OrderValid'"
    delivery:
      mode: durable
      store: mongo
      retryPolicy:
        maxAttempts: 5
        backoff: exponential
```

The `when` field is an optional condition expression — the edge is only followed when it evaluates to `true`. This enables routing nodes to fan out to multiple downstream nodes based on output type.

---

## DeliveryPolicy

A **DeliveryPolicy** lives on an edge and defines how the runtime hands data from one node to the next. It is the primary knob for trading latency against durability.

```yaml
delivery:
  mode: ephemeral   # one of: direct | ephemeral | checkpoint | durable | stream
  backend: redis
  maxInFlight: 5000
  batching:
    enabled: true
    batchSize: 500
    maxWaitMs: 100
```

See [delivery-modes.md](./delivery-modes.md) for a full breakdown of all five modes and when to choose each.

---

## Packet

A **Packet** is a named, typed message payload defined in `components.packets`. It is referenced with `$ref: "#/components/packets/..."` in node input and output ports.

Defining packets as named components lets you reuse the same schema across multiple nodes without repeating it inline.

```yaml
components:
  packets:
    OrderValidPacket:
      type: object
      description: An order that passed validation.
      required: [orderId, total]
      properties:
        orderId:
          type: string
        total:
          type: number
          minimum: 0
        items:
          type: array
          items:
            type: object
```

Reference a packet in a node port:

```yaml
outputs:
  - name: OrderValid
    message:
      $ref: "#/components/packets/OrderValidPacket"
```

Alternatively, use an inline `schema:` for one-off payloads that are only used in a single port. For schemas owned by external specifications (AsyncAPI, OpenAPI), see [integrations/asyncapi.md](./integrations/asyncapi.md).

---

## Checkpoint

A **Checkpoint** is a durable boundary in a flow — a point from which the runtime can replay processing after a failure. Checkpoints are created by using `checkpoint` delivery mode or by a node with `kind: checkpoint`.

Non-durable edges (e.g. `ephemeral`) can declare a `recovery` block pointing back to the nearest checkpoint:

```yaml
delivery:
  mode: ephemeral
  backend: redis
  recovery:
    replayFrom: "checkpoint:ingest"
    strategy: replayFromCheckpoint
```

When the service restarts, the runtime knows to replay from `checkpoint:ingest` rather than discarding in-flight work.

---

## RetryPolicy

A **RetryPolicy** controls what happens when a node execution or edge delivery fails. It can be defined inline on an edge or in `components.policies` for reuse.

```yaml
components:
  policies:
    standardRetry:
      maxAttempts: 5
      initialDelayMs: 1000
      backoff: exponential
      maxDelayMs: 60000
      deadLetterQueue: true
```

Reference it on an edge:

```yaml
delivery:
  mode: durable
  store: mongo
  retryPolicy:
    $ref: "#/components/policies/standardRetry"
```

Backoff strategies: `fixed`, `linear`, `exponential`.

`deadLetterQueue: true` routes the message to a DLQ after all attempts are exhausted rather than dropping it silently.
