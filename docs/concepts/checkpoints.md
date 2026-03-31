---
title: Checkpoints
description: How the checkpoint delivery mode enables pipeline resumption after failure in FlowDSL.
weight: 108
---

The `checkpoint` delivery mode snapshots pipeline state to MongoDB after each successful node execution. If the runtime crashes or a node fails mid-pipeline, execution resumes from the last saved checkpoint rather than restarting from the beginning. This is essential for long, multi-stage pipelines where early stages are expensive to re-run.

## How checkpointing works

```mermaid
flowchart LR
  A[ExtractText] -->|"checkpoint\n✓ saved"| B[ChunkDocument]
  B -->|"checkpoint\n✓ saved"| C[EmbedChunks]
  C -->|"checkpoint\n✗ failed"| D[LlmSummarize]
```

In the diagram above:
1. `ExtractText` runs and its output is saved to MongoDB — checkpoint 1 ✓
2. `ChunkDocument` runs and its output is saved — checkpoint 2 ✓
3. `EmbedChunks` runs and its output is saved — checkpoint 3 ✓
4. `LlmSummarize` fails — the runtime retries from checkpoint 3, not from `ExtractText`

Without checkpoints, a failure at step 4 would restart the entire pipeline from step 1, re-extracting and re-chunking an expensive PDF.

## Configuring checkpoint edges

```yaml
edges:
  - from: ExtractText
    to: ChunkDocument
    delivery:
      mode: checkpoint
      packet: ExtractedText
      checkpointInterval: 1   # Save after every packet (default)

  - from: ChunkDocument
    to: EmbedChunks
    delivery:
      mode: checkpoint
      packet: DocumentChunks
      batchSize: 50           # Batch 50 packets before checkpoint

  - from: EmbedChunks
    to: LlmSummarize
    delivery:
      mode: durable      # Switch to durable for the expensive LLM step
      packet: EmbeddedChunks
      idempotencyKey: "{{payload.documentId}}-summarize"
```

### Checkpoint-specific fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `checkpointInterval` | integer | 1 | Save a checkpoint every N packets. |
| `batchSize` | integer | 1 | Process N packets before writing the checkpoint. |

## Complete pipeline example

A document intelligence pipeline using checkpoints throughout:

```yaml
flowdsl: "1.0"
info:
  title: Document Intelligence Pipeline
  version: "1.0.0"

nodes:
  ReceiveDocument:
    operationId: receive_document
    kind: source
    outputs:
      out: { packet: DocumentUpload }

  ExtractText:
    operationId: extract_pdf_text
    kind: transform
    inputs:
      in: { packet: DocumentUpload }
    outputs:
      out: { packet: ExtractedText }

  ChunkDocument:
    operationId: chunk_document
    kind: transform
    inputs:
      in: { packet: ExtractedText }
    outputs:
      out: { packet: DocumentChunks }

  EmbedChunks:
    operationId: embed_chunks
    kind: action
    inputs:
      in: { packet: DocumentChunks }
    outputs:
      out: { packet: EmbeddedChunks }

  LlmSummarize:
    operationId: llm_summarize
    kind: llm
    inputs:
      in: { packet: EmbeddedChunks }
    outputs:
      out: { packet: Summary }

  IndexDocument:
    operationId: index_document
    kind: action
    inputs:
      in: { packet: Summary }

edges:
  - from: ReceiveDocument
    to: ExtractText
    delivery:
      mode: direct
      packet: DocumentUpload

  - from: ExtractText
    to: ChunkDocument
    delivery:
      mode: checkpoint
      packet: ExtractedText

  - from: ChunkDocument
    to: EmbedChunks
    delivery:
      mode: checkpoint
      packet: DocumentChunks
      batchSize: 20

  - from: EmbedChunks
    to: LlmSummarize
    delivery:
      mode: durable
      packet: EmbeddedChunks
      idempotencyKey: "{{payload.documentId}}-summarize"
      retryPolicy:
        maxAttempts: 3
        backoff: exponential
        initialDelay: PT5S

  - from: LlmSummarize
    to: IndexDocument
    delivery:
      mode: durable
      packet: Summary
      idempotencyKey: "{{payload.documentId}}-index"
```

Note the switch from `checkpoint` to `durable` at the LLM step — the LLM call is expensive and non-deterministic, so it gets packet-level durability and idempotency, not just stage-level checkpointing.

## Performance considerations

Each `checkpoint` edge write incurs a MongoDB write. This adds latency — typically 2–10ms per checkpoint — compared to `direct`'s microseconds.

**When to use checkpoints:**
- Multi-stage ETL pipelines where each stage takes seconds
- Pipelines processing large documents or batches
- Any pipeline where restarting from scratch is expensive

**When NOT to use checkpoints:**
- Short pipelines (< 3 stages) — overhead is not worth it
- Real-time streaming where latency matters more than restart safety — use `direct` or `ephemeral`
- Individual stages that are fast and cheap — batch them under a single checkpoint

## Checkpoint IDs

The runtime generates a checkpoint ID from the flow ID, node ID, and packet ID:

```
{flowId}:{nodeId}:{packetId}:{timestamp}
```

These IDs are stored in MongoDB under the `{flowId}.checkpoints` collection and can be inspected via the runtime API.

## Summary

- `checkpoint` edges save pipeline state to MongoDB after each node.
- A failed pipeline resumes from the last checkpoint, not from the beginning.
- Use `checkpoint` for expensive multi-stage pipelines; use `direct` for cheap transforms.
- Switch to `durable` at LLM steps — they need packet-level guarantees, not just stage-level.

## Next steps

- [Delivery Modes](/docs/concepts/delivery-modes) — the full comparison of all five modes
- [LLM Flows](/docs/guides/llm-flows) — checkpoint + durable patterns for AI pipelines
- [High-Throughput Pipelines](/docs/guides/high-throughput-pipelines) — performance tuning
