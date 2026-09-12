# P03-T06 - Provider experiment freeze

The sanitized P03 corpus and experiment plan were frozen before any provider execution. The corpus contains synthetic/public-contract cases only and declares no secrets. The plan fixes baseline and candidate configurations, Claude/Codex provider IDs, ten repetitions per case/configuration/provider and the telemetry fields required by `migracion/VALIDACION.md`.

Acceptance thresholds are frozen at zero critical violations, 100 percent safety/authority gates, no functional regression, at least 30 percent median input reduction, candidate p95 input no worse than baseline, and retries no worse than baseline plus 10 percent. If baseline retries are zero, the absolute candidate threshold is zero.

`cost_limit_usd` intentionally remains null. It must be bounded in the separately approved live preflight before any call. `P03-V04` is `not_run`; no token, latency, cost or model-quality result is claimed.

Evidence: `orquestador/evaluation/P03/corpus-v1.json`, `orquestador/evaluation/P03/experiment-plan-v1.json`, `scripts/validate-agent-context.ps1`.
