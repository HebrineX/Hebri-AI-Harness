# P03 provider evaluation - blocked handoff

Approval: `P03-PROVIDER-EVAL-023`; envelope: `APR-20260909T203107Z-a08f2e`.

Verdict: `blocked_before_provider_execution`.

## Observed host evidence

- `claude` is not present in `PATH`; no Claude version or authentication state can be obtained.
- `codex` is present at the Codex desktop bundled path and reports version `0.153.4`.
- `codex login status` exits nonzero with `Not logged in`.
- The Codex desktop conversation quota is not exposed to the standalone CLI as an authenticated session on this host.

## Effects and cost

- Provider prompts executed: 0.
- Frozen corpus repetitions executed: 0 of 280 maximum.
- Additional monetary spend: USD 0.
- No installation, login, purchase, billing change, Git operation or credential read was performed.

## Review

The frozen P03-V04 comparison requires both `claude-cli` and `codex-cli`. Running only the available binary would change the experiment after freeze and could not establish comparative quality, context reduction, retries, latency or cost. P03-T07, P03-V04 and P03-T08 therefore remain blocked/not run; P03 is not complete.

## Validation

- JSON syntax and the nine-line C-006 audit JSONL passed.
- `scripts/validate-agent-contracts.ps1` passed.
- `scripts/validate-agent-context.ps1 -RunNegativeTests` passed; P03-V04 remains explicitly `not_run`.
- Full `scripts/validate-harness.ps1 -RunNegativeTests` passed on PowerShell 7.6.5.
- Structural aggregate with nested validators skipped passed on Windows PowerShell 5.1.26100.9444.
- Existing soft-budget and privileged-symlink warnings remain unchanged.

## Next action

Choose one separately approved path: make both CLIs available and authenticated through existing quota with no additional spend, or revise and refreeze the experiment to a provider set that can actually run. Installation and authentication are outside this approval.
