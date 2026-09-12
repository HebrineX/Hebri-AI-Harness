# P01-T07 - Resolver matrix and interface review

Reviewer: `A-P01-R02` (simulated reviewer role; no real subagent available). The reviewer performed read-only inspection and separate-process validation; it did not edit product files.

## Verdict

`pass_with_explicit_deferred_consumers_and_platform_blocker`

No blocking defect remains in the PowerShell P01 interface after these implementation corrections:

1. Context objects are revalidated to reject post-creation root mutation.
2. Central bindings use a strict v1 field allowlist.
3. Layout target paths are validated at load time.
4. The legacy oracle is module-qualified, avoiding caller-scope command shadowing.
5. Windows PowerShell 5.1 junction cleanup uses `System.IO` to avoid its `Remove-Item` junction defect.

## Executed validation

| Command/profile | Result |
|---|---|
| `scripts/validate-root-resolver.ps1 -RunNegativeTests` on pwsh 7.6.5 | PASS, one symlink capability BLOCKED |
| Same resolver validator on Windows PowerShell 5.1.26100.9444 | PASS, one symlink capability BLOCKED |
| `scripts/validate-harness.ps1 -RunNegativeTests` | PASS with existing context-budget warnings and the explicit symlink warning |
| 90 layout rule traversal | PASS, zero classification/root mismatches |
| Product and outside inventories | PASS, unchanged |
| Temp cleanup | PASS, zero owned fixture directories remain |

## Consumer review

- PowerShell has the exported `runtime_api=1` implementation in `scripts/lib/hebri-common.psm1`.
- CLI stable behavior was not changed; `scripts/hebrinex.ps1` still owns its legacy resolver until P04.
- MCP was not changed; `mcp/server.mjs` still owns its legacy resolver until P03/P04.
- Both future consumers receive one layout and language-neutral request/result/context schemas plus conformance fixtures; they must not copy a second map.
- `orquestador/harness-manifest.txt` does not yet package the new central artifacts. P06 owns that structural payload change; bound smoke intentionally skips absent P01-central JSON while retaining all legacy checks.

The review does not claim cross-language runtime equivalence before CLI/MCP integration. It accepts the P01 contract and fixtures as their required handoff.
