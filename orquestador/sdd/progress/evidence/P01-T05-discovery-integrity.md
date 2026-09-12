# P01-T05 - Trusted discovery boundary and runtime integrity

Status: implemented for P01 scope.

## Boundary

`Resolve-HebriRuntimeContext` accepts `InstallRoot` only as a trusted launcher input and records `trusted_install_source=launcher_input`. It never reads InstallRoot from a project binding, CWD or directory scan.

`Test-HebriRuntimeInstallation` verifies:

- InstallRoot exists;
- `packaging/runtime-layout.json` is valid and compatible;
- `HARNESS_VERSION` agrees with the layout;
- all layout integrity files exist as regular files;
- required paths remain contained and contain no reparse components;
- the context records the layout SHA-256 and rechecks it before resolution.

Required P01 integrity files are `HARNESS_VERSION`, `SHARED_MANIFEST.yaml`, `scripts/lib/hebri-common.psm1` and `packaging/runtime-layout.json`.

## Evidence

- Layout SHA-256: `2d8521b3124aaf0dacaa6a689f9ce719528cd10b2869f6d9b8d9aba87b1d2418`.
- `P01-V06-CORRUPT-LAYOUT`: PASS with `RUNTIME_INTEGRITY_FAILED`.
- `PRODUCT-FINAL-UNCHANGED`: PASS against the simulated read-only product.
- Aggregate validation: PASS after preserving the legacy bound-copy smoke behavior.

This is not Windows installed-product discovery and is not an MSI/payload hash manifest. Registry selection, signed payload inventory and repair remain P06/P07 responsibilities.
