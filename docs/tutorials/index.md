---
title: Tutorials
description: Step-by-step tutorials for building FlowDSL flows and nodes.
weight: 200
---

These tutorials take you from zero to production-ready FlowDSL flows. Each one is self-contained and builds a real use case — not toy examples. By the end you will know how to design flow documents, choose delivery modes, implement custom nodes in Go or Python, and operate FlowDSL locally with Docker Compose.

## What's in this section

| Tutorial | What you build | Time |
|----------|---------------|------|
| [Getting Started](/docs/tutorials/getting-started) | Load and explore the Order Fulfillment example in Studio | 5 min |
| [Your First Flow](/docs/tutorials/your-first-flow) | A webhook-to-Slack routing flow, built incrementally from scratch | 20 min |
| [Email Triage Flow](/docs/tutorials/email-triage-flow) | A stateful LLM-powered email classification workflow | 30 min |
| [Sales Pipeline Flow](/docs/tutorials/sales-pipeline-flow) | CRM lead enrichment, scoring, and routing | 30 min |
| [Connecting AsyncAPI](/docs/tutorials/connecting-asyncapi) | Reference existing AsyncAPI event schemas in FlowDSL | 15 min |
| [Using the Studio](/docs/tutorials/using-the-studio) | Full walkthrough of the FlowDSL visual editor | 15 min |
| [Write a Go Node](/docs/tutorials/writing-a-go-node) | Implement and register a node using the `flowdsl-go` SDK | 25 min |
| [Write a Python Node](/docs/tutorials/writing-a-python-node) | Implement and register a node using `flowdsl-py` | 25 min |
| [Docker Compose Local](/docs/tutorials/docker-compose-local) | Spin up the full FlowDSL infrastructure stack locally | 15 min |

## Prerequisites

Most tutorials assume:
- Basic familiarity with YAML
- Docker Desktop installed (for local infrastructure tutorials)
- A terminal and a code editor

Node implementation tutorials additionally require:
- **Go tutorials:** Go 1.21 or later
- **Python tutorials:** Python 3.10 or later, `pip`

You do not need expertise in Kafka, MongoDB, or Redis. FlowDSL abstracts those behind delivery mode declarations — the runtime handles transport configuration.

---

New to FlowDSL? Start with [Getting Started](/docs/tutorials/getting-started) — it takes five minutes and gives you a complete mental model before you build anything from scratch.
