---
title: Using FlowDSL Studio
description: A complete walkthrough of the FlowDSL visual editor — canvas, nodes, edges, validation, and export.
weight: 205
---

FlowDSL Studio is the official visual editor for FlowDSL flows. It renders a `.flowdsl.yaml` document as an interactive canvas where you can explore, edit, and validate flows. The YAML file is always the source of truth — Studio is a view on top of it.

## What Studio is

Studio is a React application built on [React Flow](https://reactflow.dev). It runs as a web app at `https://flowdsl.com/studio` or locally via Docker Compose at `http://localhost:5173`.

Studio does NOT generate code or manage infrastructure. It edits FlowDSL documents and validates them against the spec schema.

## Opening Studio

**Cloud (no setup required):**
Navigate to [https://flowdsl.com/studio](https://flowdsl.com/studio).

**Local (full infrastructure):**
```bash
cd examples && make up-infra
open http://localhost:5173
```

## The canvas

![Studio canvas overview](/img/docs/studio-canvas-overview.png)

The canvas has four areas:

| Area | Location | What it shows |
|------|----------|--------------|
| **Toolbar** | Top | File menu, Validate, Export, Zoom, Fit view |
| **Canvas** | Center | The flow graph — nodes and edges |
| **Node palette** | Right | Available node kinds to drag onto the canvas |
| **Inspector** | Right (when selected) | Properties of the selected node or edge |

## Creating nodes

**From the palette:**
1. Click a node kind in the right panel (source, transform, router, etc.)
2. Drag it onto the canvas
3. Double-click to open the node editor
4. Fill in `operationId`, `summary`, ports

**From YAML:**
Edit the `.flowdsl.yaml` file directly. Studio reloads automatically if the file is open in a connected editor via the watch mode.

## Connecting nodes (drawing edges)

1. Hover over a node — small circles appear on its output ports
2. Click and drag from an output port to an input port of another node
3. A dialog appears to configure the edge's delivery policy
4. Select the delivery mode and configure optional fields (packet, retry policy, idempotency key)

![Drawing an edge in Studio](/img/docs/studio-draw-edge.png)

## Setting delivery modes on edges

Right-click an edge → **Edge Properties** to open the delivery policy editor:

- **Mode** — dropdown: direct, ephemeral, checkpoint, durable, stream
- **Packet** — autocomplete from `components.packets` and any AsyncAPI references
- **Retry policy** — toggle to add retry settings
- **Idempotency key** — template string for deduplication

Each mode has a distinct color on the canvas:
- `direct` — gray
- `ephemeral` — blue
- `checkpoint` — purple
- `durable` — green
- `stream` — orange

## Validating a flow

Click the **Validate** button in the toolbar (or press `Ctrl+Shift+V`).

The validator runs the FlowDSL JSON Schema check plus semantic rules:
- All node names are unique
- All `operationId` values are unique
- All packet references resolve
- No cycles in the graph (FlowDSL requires a DAG)
- All router outputs are connected to at least one edge

A green **Valid** badge appears on success. Errors appear in the validation panel with line numbers pointing to the YAML.

![Validation panel showing errors](/img/docs/studio-validation-errors.png)

## Exporting

**File → Export → YAML** — exports the canonical `.flowdsl.yaml`
**File → Export → JSON** — exports the canonical `.flowdsl.json`

Both formats are equivalent. JSON is what the runtime loads; YAML is for human authoring.

## Importing flows

**File → Open** — open a local `.flowdsl.yaml` or `.flowdsl.json` file
**File → Open Example** — load one of the built-in example flows
**File → Import from URL** — load a flow from a public URL or GitHub raw link

## The node inspector panel

Click any node to open the inspector on the right:

- **Kind badge** — color-coded kind (source, transform, router, etc.)
- **operationId** — editable snake_case identifier
- **Summary** — short one-line description
- **Input ports** — list of inputs with packet types, expandable to show schema
- **Output ports** — list of outputs with packet types
- **Settings** — static configuration fields

The inspector renders the node as a **NodeContractCard** — the bilateral contract visualization unique to FlowDSL.

## The execution monitor

When the runtime is running locally (requires [Docker Compose Local](/docs/tutorials/docker-compose-local)), Studio shows a live execution monitor:

- Real-time event stream for each flow execution
- Per-node status: waiting, running, completed, failed
- Packet payload inspection (click any node to see its last input/output)
- Dead letter queue inspection
- Retry count per edge

![Execution monitor in Studio](/img/docs/studio-execution-monitor.png)

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+S` | Save (writes YAML to disk) |
| `Ctrl+Shift+V` | Validate |
| `Ctrl+E` | Export to JSON |
| `Ctrl+Z` / `Ctrl+Y` | Undo / Redo |
| `Space + drag` | Pan the canvas |
| `Ctrl+scroll` | Zoom in/out |
| `Ctrl+Shift+F` | Fit all nodes in view |
| `Delete` | Delete selected node or edge |
| `Escape` | Deselect |

## Summary

- Studio edits FlowDSL documents visually — the YAML is always the source of truth
- Draw edges by dragging from output ports to input ports
- Right-click edges to set delivery modes and retry policies
- Validate before deploying — the validator catches schema errors and semantic problems
- The execution monitor shows live flow execution when connected to a local runtime

## Next steps

- [Getting Started](/docs/tutorials/getting-started) — run your first flow
- [Your First Flow](/docs/tutorials/your-first-flow) — build a flow and see it in Studio
- [Docker Compose Local](/docs/tutorials/docker-compose-local) — enable the execution monitor
