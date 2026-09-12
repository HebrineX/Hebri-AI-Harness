# P01-T04 - Normalization, containment and reparse handling

Status: implementation complete; platform matrix has one explicit blocked capability.

## Enforced behavior

- Logical paths reject empty/control segments, `.`/`..`, repeated separators, rooted paths, ADS syntax and provider syntax.
- Root containment compares normalized full paths using a separator boundary and case-insensitive Windows semantics.
- The resolver inspects every existing component between the declared root and destination.
- Junctions and symbolic links use the same `ReparsePoint` rejection path and return `REPARSE_POINT_UNSUPPORTED`.
- Context roots are reconstructed from binding authority before each resource result.

## Matrix

| Test | Result | Evidence |
|---|---|---|
| Parent traversal | PASS | `P01-V03-parent` -> `PATH_OUTSIDE_ROOT` |
| Absolute external path | PASS | `P01-V03-absolute` -> `PATH_OUTSIDE_ROOT` |
| ADS | PASS | `P01-V03-ads` -> `PATH_OUTSIDE_ROOT` |
| Alternate provider | PASS | `P01-V03-provider` -> `PATH_OUTSIDE_ROOT` |
| Similar-prefix root mutation | PASS | `P01-V03-SIMILAR-ROOT` -> `BINDING_CONFLICT` |
| External fixture inventory | PASS | `P01-V03-OUTSIDE-UNCHANGED` |
| Real Windows junction | PASS | `P01-V04-JUNCTION` -> `REPARSE_POINT_UNSUPPORTED` |
| Real Windows symlink | BLOCKED | Host returned administrator privilege required |

The symlink attempt was repeated from the normal sandbox, outside the sandbox, PowerShell 7.6.5 and Windows PowerShell 5.1.26100.9444. This host still cannot create it. It is not reported as PASS. The junction test exercises the same runtime reparse attribute branch, but a clean VM or Developer Mode host must repeat the real symlink oracle before release acceptance.

All generated fixtures were under an owned temp root with a marker and verified containment. Final inventory: zero `hebrinex-root-resolver-*` temp directories.
