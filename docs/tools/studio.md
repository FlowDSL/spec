---
title: FlowDSL Studio
description: Feature reference for the FlowDSL visual editor.
weight: 501
---

FlowDSL Studio is the official open-source visual editor for FlowDSL flows. It is built with React and React Flow and available at [flowdsl.com/studio](https://flowdsl.com/studio) or self-hosted locally.

## Running Studio

**Cloud (no setup):**
Navigate to [https://flowdsl.com/studio](https://flowdsl.com/studio)

**Local (with full runtime):**
```bash
git clone https://github.com/flowdsl/examples
cd examples && make up-infra
# Studio available at http://localhost:5173
```

**Docker only:**
```bash
docker run -p 5173:5173 flowdsl/studio:latest
```

## Features

| Feature | Description |
|---------|-------------|
| Visual canvas | Interactive node graph editor using React Flow |
| NodeContractCard | Bilateral contract view showing inputs and outputs per node |
| Delivery mode badges | Color-coded edges showing active delivery mode |
| Schema validation | Real-time validation against the FlowDSL JSON Schema |
| YAML/JSON import/export | Load and save `.flowdsl.yaml` and `.flowdsl.json` files |
| Example flows | Built-in examples: Order Fulfillment, Email Triage, Sales Pipeline |
| Execution monitor | Live view of flow execution (requires local runtime) |
| Dead letter inspector | Browse and re-inject failed packets |
| Node palette | Drag-and-drop node creation by kind |
| Edge editor | Right-click edges to set delivery policies |

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+S` | Save YAML to disk |
| `Ctrl+Shift+V` | Validate |
| `Ctrl+E` | Export to JSON |
| `Ctrl+Z` / `Ctrl+Y` | Undo / Redo |
| `Space + drag` | Pan canvas |
| `Ctrl+scroll` | Zoom |
| `Ctrl+Shift+F` | Fit all nodes in view |
| `Delete` | Delete selected |

## Source

Studio is open source at [github.com/flowdsl/studio](https://github.com/flowdsl/studio). Built with React 18, TypeScript, React Flow, and Zustand.

## Next steps

- [Using the Studio tutorial](/docs/tutorials/using-the-studio) — step-by-step walkthrough
- [Getting Started](/docs/tutorials/getting-started) — run your first flow in Studio
