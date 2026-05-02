---
title: Using Redelay as the FlowDSL Backend
description: Integrate FlowDSL with Redelay's Go framework — auto-generated OpenAPI + AsyncAPI, flow-driven HTTP endpoints, deployments, and the packet-based schema model.
weight: 308
---

[Redelay](https://redelay.com) is a modular event-driven framework for
Go (Python rebuild in progress) with native FlowDSL integration. Every
flow can become an HTTP endpoint or an event subscriber without
hand-written Go handlers — the framework's `flowexec` module owns the
HTTP↔flow and event↔flow bridges; domain modules contribute typed
nodes and starter templates.

The integration produces an automatically-correct
`/openapi.json` and `/asyncapi.json` from the live runtime: every
deployment's stable variant declares its routes and event channels via
its flow document; the spec generators iterate deployments at request
time and emit the contract.

## What Redelay's Go framework gives you

```go
// 1. Define types as Go structs once. They're reflected into
//    /openapi.json#/components/schemas by the openapi module.
type UserCreateInput struct {
    Email    string `json:"email" validate:"required,email"`
    Password string `json:"password" validate:"required,min=8"`
    FullName string `json:"full_name"`
}

// 2. A FlowDSL template references the type via packet refs:
//
//    {
//      "id": "users-registration-basic",
//      "nodes": [
//        {"id":"http","kind":"start","action_ref":"redelay/http-endpoint",...},
//        {"id":"create","kind":"action","action_ref":"redelay/users-create-user"},
//        {"id":"end","kind":"terminal"}
//      ],
//      "edges": [
//        {"from":"http","to":"create","packet":"#/components/packets/UserCreateInput"},
//        {"from":"create","to":"end","packet":"#/components/packets/UserResponse"}
//      ],
//      "meta": {
//        "packets": {
//          "UserCreateInput": { "$ref": "openapi:default#/components/schemas/UserCreateInput" },
//          "UserResponse":    { "$ref": "openapi:default#/components/schemas/UserResponse" }
//        }
//      }
//    }
//
// 3. Activating the template auto-publishes a flow + creates a
//    deployment + registers the route at the dispatcher.
//    /openapi.json picks the route up from the deployment's
//    contributions on the next request.
```

No code generation step. No manual schema duplication. The Go
struct is the single source of truth for the type; the FlowDSL
template references it; the OpenAPI spec serves the resolved schema;
SDK generators consume the spec.

## Two flow shapes

A FlowDSL template integrates with Redelay in one of two ways,
determined by its source node:

| Source node | Becomes | Auto-created deployment |
|---|---|---|
| `redelay/http-endpoint` | An HTTP route — `(method, path)` mounted via the chi-compatible dispatcher middleware | `route-<method>-<path-slug>` |
| `redelay/event-source` | An event subscriber — listens on the bus channel, optionally filtered | `subscriber-<template-slug>` |

Both auto-publish a stable variant pointing at the freshly-published
flow when the template activates. Operators see the resulting
deployment in `/flows/deployments`; canary / A-B variants can be
added via the deployment editor.

## The packet-based schema model

Every FlowDSL flow that integrates with Redelay declares its
request/response/event shapes as **packets** at the workflow level —
referenced from edges via `packet: "#/components/packets/<Name>"`.

Packets can reference Redelay's three spec sources:

| Type origin | Packet definition |
|---|---|
| HTTP request/response body (Go struct registered via `Body()` / `Response()` or `SchemasProvider`) | `{ "$ref": "openapi:default#/components/schemas/UserCreateInput" }` |
| Domain event payload (Go struct registered via `EventsProvider`) | `{ "$ref": "asyncapi:default#/components/schemas/UserCreatedPayload" }` |
| In-process DTO with no HTTP / event home | `{ "type": "object", "properties": { … } }` (inline, or an explicit Go type registered with `SchemasProvider`) |

The `openapi:default#/...` and `asyncapi:default#/...` namespaces are
Redelay/Studio internal — they tell Studio's schema browser which
loaded spec to resolve against. When the dispatcher emits the
deployment's contribution into `/openapi.json`, it strips the
namespace so the published refs are standards-compliant local refs:

```
flow document (in DB / studio):
  packet: { "$ref": "openapi:default#/components/schemas/UserCreateInput" }

→ /openapi.json (Scalar / Swagger / SDK gen):
  schema: { "$ref":          "#/components/schemas/UserCreateInput" }
```

Without the namespace strip, Scalar / Swagger UI fails with
`Could not resolve reference: Failed to fetch` because they try to
fetch the namespaced ref as a URL. See
[Schema Source of Truth](/docs/guides/schema-source-of-truth) for the
full decision rule.

## The `redelay/http-endpoint` source node

```yaml
- id: signup-source
  kind: source
  ref: redelay/http-endpoint
  config:
    path:           /api/v1/users/signup     # exact-match path
    method:         POST                     # GET|POST|PUT|PATCH|DELETE
    success_status: 201                      # default 200; override per-call via output.status_code
    auth_required:  false                    # gate via the framework's auth middleware
    summary:        Public signup            # → openapi summary
    description:    "..."                    # → openapi description
    tags:           [users, public]          # → openapi tags
```

Routing + spec metadata only — **never** schemas. Schemas attach to
edges via packet refs; the dispatcher derives request body from the
node's outgoing edge packet, response body from the incoming edge to a
`terminal`-kind node.

The node's runtime payload merges every JSON body field at the top
level plus a redacted `_meta` envelope:

```json
{
  "<every body field>": "...",
  "_meta": {
    "method":  "POST",
    "path":    "/api/v1/users/signup",
    "query":   { "ref": "ad" },
    "headers": { "X-Whatever": "..." },     // Authorization + Cookie redacted
    "remote":  "1.2.3.4:5678"
  }
}
```

The terminal node populates `output.body` (or any other key — the
dispatcher writes everything except `status_code`/`headers`/`error` as
the body), with optional `status_code` / `headers` / `error` keys for
fine-grained response control.

## The `redelay/event-source` source node

```yaml
- id: on_token_verified
  kind: source
  ref: redelay/event-source
  config:
    eventName: verification.token_verified
    groupID:   users-email-verify-handler
    filter:    'payload.kind == "email"'    # optional, server-side
```

The `eventName` setting is a JSON Schema enum populated at spec-build
time by walking the live module registry — Studio users pick the
event from a dropdown; new events declared by any module appear
automatically. Output is always the generic `EventMessage` envelope;
project payload fields via `{{.payload.*}}` in edge transforms.

## Deployments — the dispatch unit

Activating a template creates a deployment automatically. Every
published flow lives behind exactly one deployment.

`/flows/deployments` is the canonical "what's running" view. Each
deployment carries:

- `kind` — `route` or `subscriber`
- `disabled` — toggle dispatch without deletion (route unbinds /
  channel announcement stops; spec generators skip disabled
  deployments)
- `tags` — flat list extracted from labels (custom tags via `tag:*`
  prefix; canonical tags from `x-event`, `x-template-id`, etc.)
- `contributes: { routes, events, packets }` — what the deployment
  publishes to `/openapi.json` + `/asyncapi.json`, computed from the
  stable variant's flow document

Route deployments enforce uniqueness — `(method, path)` is owned by
exactly one deployment regardless of `disabled` state. Two
deployments claiming the same route is rejected with **409 Conflict**
at create / update / template-activate time.

Subscriber deployments don't share the constraint — multiple flows
fanning out from the same event channel is legitimate.

See [Redelay Deployments reference](https://redelay.com/docs/reference/deployments)
for the full deployment-layer reference: lifecycle, ID conventions,
admin endpoints, the `meta.publish_with` dependency model, and the
`Disabled`-flag effects on dispatch + spec emission.

## End-to-end example: signup with email verification

The Redelay `users` module ships four registration templates +
two verify-handler templates. The `email-confirm` template declares
its handler dependency:

```json
{
  "id": "users-registration-email-confirm",
  ...
  "meta": {
    "publish_with": ["users/email-verify-handler"]
  }
}
```

Activating the `email-confirm` template:

1. Publishes the registration flow at `POST /api/v1/users/signup`,
   creates `route-post-api-v1-users-signup` deployment.
2. Walks `meta.publish_with` → publishes `email-verify-handler` flow,
   creates `subscriber-users-email-verify-handler` deployment.
3. Returns:
   ```json
   {
     "flow_id":        "flow.…",
     "method":         "POST",
     "path":           "/api/v1/users/signup",
     "published_with": ["users/email-verify-handler"]
   }
   ```

Now the user-flow is live end-to-end:

```
POST /api/v1/users/signup
   → registration flow runs
   → users-create-pending → verification-request-email
   → 202 Accepted
   → user receives email with verification link
   → user clicks link
   → verification module fires verification.token_verified
   → email-verify-handler subscriber deployment receives the event
   → users-activate flips is_active=true
   → user can now log in
```

`/openapi.json` contains the signup route (from the route deployment's
`contributes.routes`); `/asyncapi.json` contains the
`verification.token_verified` channel (from the subscriber
deployment's `contributes.events`). Both auto-generated, both
correct, no hand-maintenance.

## Module package convention

Domain modules that participate in flows split into up to four
sibling packages:

| Subpackage | Contents | Blank-imported by |
|---|---|---|
| `<module>/` | core: Service, model, settings, module-owned Go HTTP handlers (flat-CRUD only) | every binary |
| `<module>/admin/` | admin endpoints, masking, write paths | admin-api binary only |
| `<module>/flowdsl/` | FlowDSL nodes (operators) + handlers calling parent Service | binaries that participate in flows |
| `<module>/flowtemplates/` | starter flow compositions + auto-publish-on-startup bootstrap | binaries that want opinionated defaults |

Each layer is independently optional. The Redelay `users` module
ships all four; a project that only wants core-CRUD can blank-import
just `<module>/`.

## Why this integration

| Concern | How Redelay handles it |
|---|---|
| Schema duplication | Go struct → reflection → `/openapi.json` → packet `$ref` → flow document. One source of truth. |
| Type safety | Validate tags on Go structs; runtime validation by node handlers; spec-time validation of packet refs. |
| Auto-documented | `/openapi.json` + `/asyncapi.json` regenerate per-request from live deployments. |
| Incremental adoption | Modules opt into FlowDSL via the `flowdsl/` subpackage; templates ship via `flowtemplates/`. Both are independently optional. |
| Operational hygiene | Route uniqueness enforced; disable/enable without flow loss; canary variants per deployment; orphan flows visible in `/flows`. |

## Summary

- **Templates** define flows; **deployments** dispatch them. Both
  auto-managed by `flowexec.ActivateTemplate` + `EnsureTemplatePublished`.
- **Packets on edges** (not schemas on source nodes) carry typed
  contracts. Packets reference Go structs via the `openapi:default#`
  / `asyncapi:default#` namespaces; refs are stripped at OpenAPI
  emission time.
- **Two source kinds** — `redelay/http-endpoint` for HTTP routes,
  `redelay/event-source` for bus subscribers — produce two deployment
  shapes (`route` vs `subscriber`).
- **`meta.publish_with`** lets a registration template auto-publish
  its event handlers as side-effects of activation.
- **`Disabled` deployments** are pause buttons — route unbinds, spec
  generators skip, no flow loss. Re-enable with one PATCH.

## Next steps

- [Flow-driven HTTP endpoints (Redelay reference)](https://redelay.com/docs/reference/flow-driven-endpoints) — full HTTP integration reference
- [Deployments (Redelay reference)](https://redelay.com/docs/reference/deployments) — deployment lifecycle, conflict rules, admin endpoints
- [Schema Source of Truth](/docs/guides/schema-source-of-truth) — three-source rule + namespace conventions
- [AsyncAPI Integration](/docs/guides/asyncapi-integration) — connecting external AsyncAPI documents to a FlowDSL flow

## Python (rebuild in progress)

The Python implementation (`py-framework`) is being rebuilt to track
the Go framework's runtime contract — flow-driven endpoints,
deployment layer, packet-based schema model, `SchemasProvider`. The
historical Python-only redelay-events library remains available as
`py-events` while the rewrite lands. Tracking issue + design notes
live in `redelay/spec/docs/4.reference/14.py-framework.md`.
