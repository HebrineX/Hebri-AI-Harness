# P05 legacy migration fixtures

`baseline-source/` is a minimal deterministic legacy product used by the
no-Git aggregate test. The validator creates bound consumers only below a
temporary directory, rewrites their binding to the temporary project root and
generates the content-addressed baseline before introducing drift.

`decisions-preserve.json` is an explicit human-decision fixture. It is data,
not approval evidence. Real versions are exercised separately from local Git
tags when `validate-legacy-migration.ps1 -UseGitTags` is requested.

No fixture is a supported installed release baseline. P06 owns payload
publication of any accepted baseline.
