# Command Gateway grammar correction

User approval: GATEWAY-FIX-035, 2026-10-14.

CheckOnly and Apply now validate the same read-only execution plan. Get-Content supports positional path, -LiteralPath path, and -Raw -LiteralPath path. Raw propagates to the child executor without line formatting or trimming. Existing redaction and output limits still apply. Consumer read-root boundaries are unchanged; unsupported Get-ChildItem recursion blocks consistently.

Validation: complete gateway validator passed in isolated Windows PowerShell 5.1 and PowerShell 7 roots. Regression cases cover the supported read commands, unsupported option combinations, traversal, paths containing spaces, CRLF/LF and empty Raw content. Independent static review found no regressions attributable to the patch.

Git publication verification (GATEWAY-GIT-037): exported baseline 53dd672 with only the two changed gateway scripts overlaid. Complete gateway validation passed independently in PS5.1 and PS7, with exit 0. The fix does not depend on pending local migration changes in hebri-common.psm1. Both scripts are already included in the distribution manifest. Product version remains 0.17.1; no MSI or release tag is produced.

Local propagation: 18 independent .hebrinex gateways patched by bounded block changes with original backups, per-copy dual-host smoke tests, installed hash verification and actual CheckOnly postchecks. This does not imply a product release or MSI rebuild. Full-PC discovery was partial due to access restrictions and scan timeouts. Historical/staging snapshots and installations without a gateway were preserved.

Shared-cache candidate passed both hosts but installation was rejected by automatic permission review; explicit shared-destination authorization remains pending. Operational state, approval, gate review, deviations and closure are maintained in the local bound instance at .hebrinex/instance/sdd/progress/evidence/GATEWAY-FIX-035/report.md. Reproducible local inventory, patch preparation scripts, hashes and logs are under artifacts/gateway-fix-035 and artifacts/gateway-fix-035-shared.
