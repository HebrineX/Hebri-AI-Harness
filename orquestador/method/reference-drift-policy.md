# Reference Drift Policy

Version: 0.7.3

Esta politica detecta drift entre version, README, prompts, binding, init y changelog.

## Cuando Aplica

Aplica antes de cerrar cambios que tocan:

- `HARNESS_VERSION`
- `PROJECT_BINDING.yaml`
- `README.md`
- `CHANGELOG.md`
- `init.sh`
- prompts de migracion o re-entry
- docs que nombran la version actual

## Fuentes Canonicas

- `HARNESS_VERSION`: version operativa actual.
- `PROJECT_BINDING.yaml`: version declarada para el harness fuente o copia bound.
- `CHANGELOG.md`: historia de versiones.
- `README.md`: version visible al operador.
- `init.sh`: validacion ejecutable minima.

## Regla

Si la version cambia, el cierre debe verificar referencias cruzadas. Las menciones historicas pueden quedar; las menciones operativas deben coincidir con `HARNESS_VERSION`.

## Salida Minima

```text
Version canonica:
Referencias operativas encontradas:
Referencias historicas permitidas:
Drift detectado:
Decision:
```

## Bloqueos

Bloquear si:

- `HARNESS_VERSION` y `PROJECT_BINDING.yaml` divergen;
- `init.sh` valida una version distinta;
- README declara otra version actual;
- prompt de migracion apunta a una version vieja como objetivo actual;
- no se puede justificar si una referencia es historica u operativa.

## Instruction Builder 0.9.0

Versiones, targets y denylists de instrucciones se validan con `scripts/validate-drift.ps1`. El builder corre check-only salvo aprobacion explicita de escritura.
