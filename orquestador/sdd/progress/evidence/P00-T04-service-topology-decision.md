# Evidence - P00-T04 Service Topology Decision

```yaml
evidence_id: E-P00-T04-001
cycle_id: C-001
slice_id: P00-T04
agent_id: A-P00-A05
role: auditor
profile: architecture
execution_mode: simulated
approval_id: P00-T04-EXEC-014
action_type: architecture_decision
summary: "Evaluate on-demand execution versus a resident daemon, database and dependency additions."
result: accepted_with_follow_up_blockers
created_at: "2026-09-08"
```

## Verdict

1. **Core execution: on demand.** The base engine is invoked per explicit operation from the CLI or PowerShell. No resident Windows service, scheduled process, network listener, service account or elevation is accepted.
2. **MCP: optional session-scoped stdio process.** An MCP-capable host may launch `node mcp/server.mjs` and keep it alive for that host connection. This is not an OS daemon and must not be shared across projects while `ROOT` and assumed role remain process-global.
3. **Persistence: files, locks and journal.** Binding, instance state, approvals, locks, evidence and the future catalog remain recoverable persistent artifacts. A process restart must reconstruct from them; in-memory daemon state is not authority.
4. **Database: not accepted for the base design.** No requirement currently needs database queries or a continuously open store. File transactions and a per-user catalog lock are the initial mechanism. An embedded database is reconsidered only after measured contention or query needs that the file design cannot satisfy.
5. **Dependencies: reuse existing platform/runtime only.** Base Windows operation continues with PowerShell and platform JSON/hash/file APIs. MCP remains optional and requires a packaged or preflight-verified Node runtime plus its locked dependencies. No dependency is added by P00-T04.

This verdict matches `migracion/ARQUITECTURA-CONTRATOS.md:96-100,191-201,210-212` and satisfies the P00 rule that a resident service is allowed only when an accepted need cannot be met on demand.

## Observed Runtime Topology

| Component | Launch/lifetime | Durable state | Network/service evidence | Status |
|---|---|---|---|---|
| PowerShell CLI | one process per invocation | files beneath resolved harness/instance roots | no listener or service registration found | observed |
| Command Gateway | child PowerShell process; commands use bounded child processes (`scripts/command-gateway.ps1:157-237`) | approval store, locks and rate state | classifies network/Git but exposes no server | observed |
| MCP server | host launches `node mcp/server.mjs` (`.mcp.json:2-6`); connects with `StdioServerTransport` (`mcp/server.mjs:15,1232-1233`) | delegates writes to CLI/gateway; keeps only session cache/role in memory | no HTTP/TCP/socket listener or service-manager code found in `scripts`, `mcp`, `.github` | observed |
| MCP role backend | spawned per audit/review request with fixed configured command and prompt on stdin (`mcp/agent-backends.mjs:90-137`) | backend result only; no database | optional local CLI process; no resident worker | observed |
| Future catalog | invoked through a logical operation and protected by per-user lock (`migracion/ARQUITECTURA-CONTRATOS.md:158,191-195`) | reconstructible catalog files plus project bindings | no implemented catalog service/database | proposed/not_run |

The product and portability documents use the word `daemon`, but the implemented transport is stdio and host-launched. Operationally it is a session-scoped child process, not a Windows daemon.

## Need Matrix

| Accepted need | On-demand handling | Does it require residency? | Evidence/status |
|---|---|---|---|
| Resolve one explicit project and operation | pass project/context into an invocation | no | required by R02/R03; future request contract at architecture lines 102-126 |
| Preserve state across invocations | read binding, state, journal, approvals and locks | no | R03/R07/R17; file contracts observed |
| Isolate multiple projects | one explicit context per invocation/process | no; sharing current MCP would increase risk | R02/R04; current MCP has global `ROOT` at `mcp/server.mjs:20` |
| Handle concurrent effects | persistent locks, plan hash, journal and revalidation | no | R06/R07; architecture lines 178-195 |
| Reconcile a lost/stale catalog | explicit authorized reconciliation | no | R04; catalog loss must not lose binding authority |
| Provide tools to an AI host | host-managed stdio MCP connection | no OS service | `.mcp.json:2-6`; portability examples use `command=node` |
| Run offline | prepackage/verify required runtime and dependencies | no | R13; architecture line 201; packaging remains not_run |
| Background jobs, notifications or remote API | no accepted requirement | no | no requirement or implementation evidence found |
| Reduce startup latency | no measurement exists | no decision basis | not_run; benchmark required before reconsideration |

## Process-global State Risk

- `ROOT` is fixed once from `HEBRINEX_ROOT` or the server location (`mcp/server.mjs:19-20`).
- PowerShell executable selection is cached (`mcp/server.mjs:28-37`).
- `assumedRole` is mutable process-global connection state (`mcp/server.mjs:296-312,987-988`).
- The current design is acceptable for one host connection bound to one context. It is not evidence that one resident process can safely multiplex projects or independent callers.
- P03/P04 must move project/instance context into each request or isolate connections before any central launcher can reuse this server safely.

## Dependency Inventory

| Layer | Required dependency | Current evidence | Decision |
|---|---|---|---|
| Base CLI | PowerShell; filesystem, JSON and hashing APIs | local `pwsh 7.6.5`; product code also seeks Windows PowerShell where supported | reuse; supported versions fixed in P05/P06 |
| MCP optional | Node `>=18` | `mcp/package.json:12-16`; local Node `v22.16.0` | optional; package or fail early for offline |
| MCP direct package | `@modelcontextprotocol/sdk ^1.29.0` | lock resolves `1.29.0`, MIT | retain; locked payload/licensing proof belongs to P06/P09 |
| MCP transitive tree | 93 non-root lock entries | `package-lock.json` v3 | no hidden download at runtime; package reproducibly if feature ships |
| Schema helper | `zod 4.4.3` | imported directly at `mcp/server.mjs:16`, but supplied transitively by the SDK and absent from direct dependencies | dependency defect to resolve before packaging; no edit in T04 |
| Role backends | `claude` or `codex` CLI | fixed commands in `mcp/agents-backend.yaml:26-32`; local `claude` missing, `codex` present | optional feature; fail clearly or select an available approved backend |
| Database/server stack | none | no SQLite/Postgres/MySQL/Redis/Mongo/LevelDB, listener or service-manager code found | do not add |

The MCP validator may skip smoke when Node or SDK is absent (`scripts/validate-mcp.ps1:145-168`). That behavior is useful for an optional feature but does not prove R13 offline distribution.

## Alternatives Rejected

| Alternative | Reason rejected now | Reconsider only if |
|---|---|---|
| Windows service | adds lifecycle, identity, ACL, upgrade and recovery surfaces without a continuous workload | an accepted background requirement cannot run per invocation |
| Network daemon/port | expands attack surface and needs authentication/version routing | a verified remote/multi-host requirement is added |
| One global MCP process for all projects | current global root and assumed role can mix context | request-scoped context and multi-client isolation tests pass |
| External database | introduces installation, backup, schema migration and offline dependencies | measured workload cannot meet correctness/performance with file transactions |
| Embedded database immediately | central catalog schema and contention are not yet fixed | P04/P08 evidence proves file locking/reconciliation insufficient |
| New YAML/framework dependency | current parsers and JSON target contracts are sufficient for baseline | supported schemas exceed proven parser capability |

## Reconsideration Evidence Required

- Startup and operation latency distributions, including p95, on the supported Windows matrix; no threshold is invented in P00.
- Concurrent operations against the same and different instances, with journal/lock recovery after process termination.
- Catalog size/query profile and contention showing that file transactions fail correctness or an accepted performance target.
- A concrete background or remote-access requirement with threat model, identity, update and offline implications.
- For optional MCP packaging: Node strategy, full dependency/license inventory, hashes, offline smoke and explicit behavior when optional backends are absent.

## Validation Evidence

- Static search: no service registration, scheduler, listener or database implementation in `scripts`, `mcp` or `.github`.
- `npm ls --depth=0`: only `@modelcontextprotocol/sdk@1.29.0` is direct.
- `npm ls zod --all`: `zod@4.4.3` is present through the SDK and `zod-to-json-schema`.
- Initial sandboxed MCP smoke failed only at `gate_check` because its child Git context was restricted; locks cleaned successfully.
- The same `node smoke.mjs` outside that sandbox passed every MCP tool check.
- `scripts/validate-mcp.ps1 -RunNegativeTests` rerun outside the sandbox: `smoke=passed`, `negative_structural=checked`, `MCP validation OK`.
- First aggregate validation attempt exposed a real tracking-budget failure in the bound bootstrap fixture: `runtime_reentry 3477/1600` exceeded hard limit 3200. No product limit was raised.
- The live registry was compacted from 7,886 to 4,640 characters by removing repeated read/ownership detail for closed agents; task graph, audit and evidence retain that history.
- Post-compaction budget: `leader_light 3536/2600` (hard 5200) and `runtime_reentry 2626/1600` (hard 3200).
- Aggregate `scripts/validate-harness.ps1 -RunNegativeTests` rerun: pass with only those two soft warnings; all nested validators passed, including bootstrap/update/restore fixtures.
- Final out-of-sandbox MCP smoke after compaction: pass for all 13 tools; lock cleanup left only `_README.md`.
- Real `claude-cli`/`codex-cli` role execution, MSI/offline packaging and installed central layout remain `not_run`.

## Open Findings for Later Phases

1. `zod` is a direct source import but not a direct package dependency.
2. The versioned backend default is `claude-cli`, unavailable on this host; no automatic fallback is proven.
3. The current MCP process cannot safely serve multiple project contexts because `ROOT` and assumed role are process-global.
4. MCP smoke depends on child Git access and can fail under a restricted sandbox even when product behavior passes outside it.
5. The term `daemon` in existing docs/package metadata can be mistaken for an OS-resident service; future docs should say session-scoped stdio server where precision matters.

## Handoff

P00-T04 accepts on-demand execution and rejects resident service/database additions for the base design. P00-T05 must freeze the supported Windows/architecture/engine decisions, new schema boundary and initial limits, assigning experiments wherever evidence remains absent.
