# C-006 detractor senior - P03 provider evaluation

Role: simulated `auditor(profile: detractor_senior)`; no independent agent process is claimed.

Verdict: `pass_with_stop_conditions`.

## Necessity and minimum design

- P03-T07 and P03-V04 require the already frozen corpus, two configurations and both declared providers.
- Reuse `mcp/agent-backends.mjs`, Node standard library and existing contracts; add no dependency or provider-specific schema.
- A runner is justified only after both CLIs are available and authenticated through existing quota with no additional monetary spend.
- A partial one-provider run cannot support the frozen comparison and must not be promoted as P03 completion.

## Non-negotiable limits

- Maximum incremental cost: USD 0.
- No installation, login, purchase, billing change, Git operation or secret capture under this approval.
- Stop before any provider prompt when a required command or authenticated session is absent.
- Keep provider output untrusted and without instruction authority.

The preflight met a stop condition: `claude` is absent and `codex login status` reports `Not logged in`. Implementation and provider calls therefore remain not started.
