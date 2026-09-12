# Detractor Senior - C-002 / P01-T01

- Operator approval: `P01-T01-LAYOUT-019`
- Runtime envelope: `APR-20260909T052210Z-5eec12`
- Auditor: `A-P01-A01`
- Execution mode: simulated; no real subagent was available
- Scope: canonical path classification and documentary contract only

## Challenge

- P01-T01 does not need a new resolver module, dependency or product schema. Its required output is a complete, non-overlapping classification that later tasks can implement.
- Do not create a second executable map beside `SHARED_MANIFEST.yaml`. This slice may define the normalization rules and deltas that P01-T02 onward must encode, but must not silently make documentation an executable authority.
- The architecture contract owns the canonical classes `product`, `template`, `instance`, `integration`, `catalog` and `denied`. Task terms map to purpose metadata: `shared -> product`, `generated -> integration` or instance-generated, `backup -> instance` and `excluded -> denied`.
- The 21 shared roots and 17 instance mappings are insufficient for full structural coverage. A comparison against `orquestador/harness-manifest.txt` found 36 entries not selected by current shared, instance or exclusion rules. T01 must classify them rather than hiding them behind default denial.
- Mixed ancestor directories such as `orquestador`, `orquestador/memory`, `orquestador/sdd`, `orquestador/migration` and `orquestador/runtime` cannot be broadly readable/writable resources. Direct resolution of the container is denied; a more-specific descendant rule may allow access.
- Existing exceptions must outrank prefixes: shared `mcp` cannot absorb the local backend override or `node_modules`; instance progress/specs cannot absorb product schemas/templates; generated reports cannot absorb the immutable report template.
- `CatalogRoot` is auxiliary and reconstructible. It cannot establish project identity, choose an engine or authorize effects.
- Unknown paths, traversal, ADS, alternate providers and ambiguous equal-precedence rules must fail closed. T01 records this rule; P01-T04 owns runtime enforcement and behavioral tests.
- Do not claim resolver, legacy, security or runtime tests passed. P01-V01 through V06 remain `not_run` until the real resolver exists.

## Verdict

- Verdict: accept the documentary classification with conditions.
- Required evidence: all P00 inventory IDs covered, all 36 current structural gaps classified, deterministic precedence, explicit write policy, zero equal-precedence conflicts and downstream owners for executable enforcement.
- Reject: product/schema edits, consumer changes, MSI work, dependency installation, Git effects or declaring P01 complete from T01 documentation.
