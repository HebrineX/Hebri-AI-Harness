# C-007 detractor senior - P03 Codex-only evaluation

Role: simulated `auditor(profile: detractor_senior)`; no independent agent process is claimed.

Verdict: `pass_with_conditions`.

## Need and scope

- The original two-provider plan cannot run on this host and produced zero provider results.
- A new version may narrow the provider set before any result exists, but must preserve corpus, configurations, repetitions, scoring criteria and thresholds.
- Keep V1 immutable and make V2 explicitly supersede it for host feasibility only.

## Minimum implementation

- Use Node standard library and a fixed `codex exec --json --sandbox read-only -` process with prompt data on stdin.
- Do not modify the MCP server or add dependencies.
- Store normalized JSONL telemetry and hashes, not credentials or local authentication data.
- Count the first valid smoke as one of the 140 maximum attempts; do not retry automatically.

## Stop conditions

- Login requires an API key, payment, purchase or billing change.
- Codex does not expose enough token telemetry to compare baseline and candidate.
- Provider output remains malformed, a rate limit occurs, or the data boundary cannot be preserved.
- Any safety or instruction-authority invariant fails.

The auditor permits writing the V2 freeze and runner only within the approved write-set and USD 0 additional-spend boundary.
