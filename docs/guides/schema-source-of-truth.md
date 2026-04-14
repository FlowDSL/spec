---
title: Schema Source of Truth
description: How to assign each port schema to exactly one authoritative source — OpenAPI, AsyncAPI, or native packets — when your modules already expose both an HTTP API and an event bus.
weight: 309
---

When you integrate FlowDSL with a module framework that already generates both an OpenAPI document and an AsyncAPI document (such as Redelay's Go framework), every port schema has three possible homes:

1. **OpenAPI** — HTTP request and response bodies
2. **AsyncAPI** — domain event payloads
3. **Native packets** — everything else

Picking the right home for each type eliminates duplication and ensures that the FlowDSL port browser always shows live, authoritative field definitions rather than hand-maintained copies.

## The decision rule

For any type that a FlowDSL node port needs to describe, ask in order:

1. **Is this the request body or response body of an HTTP endpoint?** → Use `openapi#/components/schemas/TypeName`
2. **Is this the payload of a module-published domain event?** → Use `asyncapi#/components/schemas/TypeName`
3. **Neither of the above?** → Define it as a `packets:` entry in your module YAML; it will be exported to `asyncapi#/components/schemas/TypeName` by the compile pipeline

The third answer always lands in AsyncAPI too — but via the compile pipeline, not because the type has a corresponding event. The distinction matters because it tells you *who owns the definition*: event payloads are owned by the event bus contract; packets are owned by the module that declares them.

## Why these three sources cover everything

A module that exposes both HTTP routes and events has types that fall into four groups:

| Group | Example | Right home |
|-------|---------|------------|
| HTTP request/response bodies | `UserCreateInput`, `AuthTokenResponse` | `openapi#/...` |
| Domain event payloads | `UserCreatedPayload`, `AuthLoginPayload` | `asyncapi#/...` |
| Standalone DTOs with no HTTP endpoint or event | `UserContext`, `PermissionCheckInput`, `TokenInput` | packet → `asyncapi#/...` |
| HTTP path/query parameters | `UserIDInput`, `UserListQuery` | packet → `asyncapi#/...` |

The first two groups already exist in the generated specs. The last two groups have nowhere to live without packets — the OpenAPI spec records them as parameter objects inside endpoint definitions, not as reusable named schemas; the AsyncAPI spec has no concept of them at all.

## Redelay Go module example

The Redelay Go framework generates both specs automatically. Here is how the auth module's FlowDSL nodes assign sources:

```yaml
# go-framework/modules/auth/flowdsl/module.yaml

flowdsl_nodes:
  # HTTP action — request/response bodies live in OpenAPI
  - id: redelay/auth-login
    kind: action
    inputs:
      - name: Credentials
        schema:
          $ref: "openapi#/components/schemas/AuthLoginInput"
    outputs:
      - name: Tokens
        schema:
          $ref: "openapi#/components/schemas/AuthTokenResponse"
      - name: Error
        schema:
          $ref: "openapi#/components/schemas/RedelayErrorResponse"

  # In-process transform — uses standalone DTOs defined as packets
  - id: redelay/auth-validate-token
    kind: transform
    inputs:
      - name: Token
        schema:
          $ref: "asyncapi#/components/schemas/TokenInput"    # packet
    outputs:
      - name: UserContext
        schema:
          $ref: "asyncapi#/components/schemas/UserContext"   # packet

  # Permission gate — uses packet-backed check types
  - id: redelay/auth-require-permission
    kind: router
    inputs:
      - name: Check
        schema:
          $ref: "asyncapi#/components/schemas/PermissionCheckInput"     # packet
    outputs:
      - name: Allowed
        schema:
          $ref: "asyncapi#/components/schemas/PermissionCheckResult"    # packet
      - name: Denied
        schema:
          $ref: "openapi#/components/schemas/RedelayErrorResponse"

  # Event source — payload lives in AsyncAPI as a domain event schema
  - id: redelay/auth-login-event
    kind: source
    outputs:
      - name: AuthLogin
        schema:
          $ref: "asyncapi#/components/schemas/AuthLoginPayload"         # event payload
```

The corresponding module YAML declares the packet-backed types under `packets:`:

```yaml
# go-framework/modules/auth/module.yaml (excerpt)

packets:
  - id: auth.token_input
    name: TokenInput
    fields:
      - name: token
        type: string
        required: true

  - id: auth.user_context
    name: UserContext
    fields:
      - name: user_id
        type: string
        required: true
      - name: email
        type: string
      - name: permissions
        type: array
        items:
          type: string

  - id: auth.permission_check_input
    name: PermissionCheckInput
    fields:
      - name: user_context
        $ref: "auth.user_context"
      - name: permission
        type: string
        required: true

  - id: auth.permission_check_result
    name: PermissionCheckResult
    fields:
      - name: allowed
        type: boolean
        required: true
      - name: permission
        type: string
        required: true
```

The compile pipeline exports all packets to `asyncapi#/components/schemas/...`, so FlowDSL Studio resolves them from the same AsyncAPI document it uses for event payloads.

## Identifying which group a type belongs to

**Belongs in OpenAPI** when:
- It is a request body (`POST`, `PATCH`, `PUT`) declared on an HTTP route
- It is a response body for a non-204 HTTP response
- It is a shared error envelope returned by multiple endpoints (e.g. `RedelayErrorResponse`)

**Belongs in AsyncAPI event payloads** when:
- It is published by the module as a domain event (e.g. `UserCreatedPayload`)
- It corresponds directly to a message in the AsyncAPI `components.messages` section

**Belongs in packets** when:
- It is only passed between in-process nodes (middleware context enrichment, permission result carry-through)
- It represents path or query parameters that the OpenAPI spec records inline rather than as named components
- The module has no HTTP routes at all — all its public types are internal DTOs
- It is needed for FlowDSL codegen to produce typed classes (when the codegen toolchain is available)

## What NOT to inline

Never define a port schema inline in the `module.yaml` node definition:

```yaml
# Wrong — inline schema duplicates information that is already authoritative elsewhere
- id: redelay/users-create-user
  inputs:
    - name: UserData
      schema:
        type: object
        properties:
          email: { type: string }
          name: { type: string }
```

Inline schemas get out of sync the moment the authoritative source changes. They also suppress Studio's "From OpenAPI / From AsyncAPI" source badge, which tells users where to look for the canonical definition.

## Modules with no HTTP routes

Some modules (e.g. a permission resolver or an in-process enrichment module) have no HTTP endpoints at all. All their types belong in packets, and all FlowDSL port refs will be `asyncapi#/components/schemas/...`:

```yaml
# go-framework/modules/groups/flowdsl/module.yaml

flowdsl_nodes:
  - id: redelay/groups-resolve-permissions
    kind: transform
    inputs:
      - name: GroupIDs
        schema:
          $ref: "asyncapi#/components/schemas/GroupIDsInput"   # packet
    outputs:
      - name: Permissions
        schema:
          $ref: "asyncapi#/components/schemas/PermissionsResult"  # packet
```

The module's `packets:` section is the only place `GroupIDsInput` and `PermissionsResult` live. There is no redundancy.

## Future codegen

When the FlowDSL codegen toolchain generates typed classes for node implementations, it resolves each port schema from its declared source:

- `openapi#/components/schemas/Xxx` → generates from the OpenAPI `$defs` section
- `asyncapi#/components/schemas/Xxx` → generates from the AsyncAPI `components.schemas` section
- `#/components/packets/Xxx` → generates from the FlowDSL document's own packet definition

In module-framework integrations (like Redelay), all three sources are served by the same running application: `/openapi.json`, `/asyncapi.json`, and the module's exported YAML. Codegen tooling fetches all three and resolves each ref to the right document automatically — no manual wiring required.

## Summary

- Assign every port schema to exactly one authoritative source.
- HTTP request/response bodies → `openapi#/components/schemas/...`
- Domain event payloads → `asyncapi#/components/schemas/...`
- Everything else → declare as a `packets:` entry in the module YAML; the compile pipeline exports it to `asyncapi#/components/schemas/...`
- Never inline schemas in node definitions.
- Modules with no HTTP routes use only packets — all refs become `asyncapi#/components/schemas/...`.

## Next steps

- [AsyncAPI Integration](/docs/guides/asyncapi-integration) — linking AsyncAPI documents to FlowDSL
- [Redelay Integration](/docs/guides/redelay-integration) — automatic AsyncAPI generation from the Go/Python framework
- [Packets concept](/docs/concepts/packets) — native packet definitions and AsyncAPI-referenced packets
