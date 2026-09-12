# Detractor Senior - C-003 / P01-T02-T08

- Operator approval: `P01-COMPLETE-020`
- Runtime envelope: `APR-20260909T133916Z-fdf13c`
- Auditor: `A-P01-A02`
- Execution mode: simulated; no real subagent was available
- Scope: implement and close the remaining P01 resolver contract

## Challenge

- Reuse `scripts/lib/hebri-common.psm1`; a second PowerShell framework or dependency is unjustified.
- Preserve existing `Get-HebriInstanceRelativePath`, `Resolve-HarnessPath` and `Read-HarnessText` behavior. The central resolver must be an explicit versioned API so stable0.5 and legacy consumers do not change accidentally.
- One machine-readable layout must govern the central resolver. `SHARED_MANIFEST.yaml` may remain a legacy projection only if a validator proves it agrees with the central layout for shared, instance and denied entries.
- Do not derive ProjectRoot from CWD, InstallRoot from binding, or class from file existence. Context inputs and deployment mode must be explicit and validated.
- Do not write or create directories from resolution calls. A writable destination is a plan result, not an effect.
- Product/template writes must fail before directory creation. Unknown, traversal, ADS, alternate provider, similar-prefix escape and unsupported reparse traversal must fail closed.
- A central binding containing executable/install/script/command paths must be rejected before any witness can execute.
- Trusted install discovery in P01 is an injectable launcher boundary plus integrity checks. Do not write Windows registry or claim installed-product discovery before P06.
- Legacy fallback may exist only in explicit `legacy_bound` or `source_template` mode. `central_instance` cannot fall back when local state is absent.
- Tests must call the real exported functions and compare filesystem inventories. Regex-only fixture checks are insufficient.
- No CLI/MCP integration, consumer migration, installer, network, dependency or Git effect is authorized. Interface review may identify later work without editing those consumers.
- P01 may close only if V01-V03, V05 and V06 pass. V04 must test a real junction and attempt a symlink; unavailable symlink capability is recorded separately rather than converted to PASS.

## Verdict

- Verdict: proceed with conditions.
- Accepted files: approved module, layout, schemas, fixtures, validator, aggregate integration, evidence and tracking.
- Required rollback: remove new central API artifacts and restore the touched existing files if legacy or aggregate validation regresses.
- Required closure: implementation evidence per task, reviewer matrix, interface version, no open agents/locks and explicit remaining consumer/packaging limitations.
