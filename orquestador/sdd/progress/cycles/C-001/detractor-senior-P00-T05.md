# Detractor Senior - C-001 / P00-T05

- Approval ID: `P00-T05-EXEC-015`
- Auditor: `A-P00-A06`
- Execution mode: simulated; no real subagent was available
- Proposed change: one decision evidence file, this review, and approved cycle/state tracking only

## Challenge

- One local x64 machine does not establish a supported Windows edition, clean install, offline operation, MSI lifecycle or ARM64 behavior.
- The registry product label and runtime/build strings are inconsistent enough that normalizing them into a marketing edition would create false precision.
- `pwsh 7.6.5` is observed and locally validated, but selecting it as a candidate does not decide redistribution, servicing or the lowest supported version.
- Windows PowerShell 5.1 is installed, but the aggregate validator cannot preserve expected child diagnostics under its current error handling. Calling 5.1 supported or unsupported from that run alone would overstate the evidence.
- `0.18.0` in the architecture was explicitly illustrative. T05 may adopt it only as the next central-engine candidate, never as an existing compatible release.
- A schema name without a closed field boundary and negative fixtures is not a contract. Creating several speculative schema files in P00 would duplicate later-phase ownership.
- Raising context budgets after a warning would hide growth. Numeric performance, payload and throughput limits without a workload would be invented.
- Node `>=18` in package metadata does not prove the entire range, offline packaging or the undeclared direct `zod` import.

## Verdict

- Verdict: accept with blocking experiments.
- Accept: x64-only initial candidate, exact local `pwsh 7.6.5` candidate, API line `1`, one active engine per line, `hebrinex.binding@1` JSON boundary, optional MCP and existing safety limits.
- Reject as current claims: any supported Windows platform, PowerShell 5.1, ARM64/x86/WSL/Server, Node range compatibility, MSI/offline readiness or benchmark result.
- Required follow-up: clean and offline VM tests, runtime packaging decision, canonical schema fixtures, API compatibility matrix and pre-frozen workload measurements.
- Non-negotiable: no hidden downloads, no Bash requirement for Windows core, no fallback across incompatible contracts, no second authority and no silent budget increase.
