# Context Loading Policy

Version: 0.10.4

## Objetivo

Reducir 70-80% el consumo operativo del harness. La regla por defecto es cargar kernel liviano, no contrato completo.

## Orden Obligatorio

1. `PROJECT_BINDING.yaml`.
2. `orquestador/memory/local/session-pin.md`.
3. `orquestador/memory/memory-registry.yaml`.
4. `orquestador/memory/memory-routing.yaml`.
5. `orquestador/context-budget.yaml`.
6. Entrypoint elegido.
7. Perfil minimo en `orquestador/context-profiles.md`.
8. Evidencia SDD solo si el perfil la exige.

## Enforcement

Antes de cargar contexto, declarar:

```text
Context budget:
- Route:
- Perfil:
- Archivos:
- Tokens estimados:
- Dentro de presupuesto: si | no
```

Si el read-set supera presupuesto, el agente debe parar y pedir un brief mas acotado o aprobacion para `leader_full`/`audit_global`.

## Carga Completa

Leer todo `.hebrinex` es una accion excepcional. Requiere motivo, alcance, presupuesto y `SI` si habilita acciones posteriores.

## Denylist Operativa

No cargar por defecto:

- `infoHebri.md`
- `CHANGELOG.md`
- `README.md`
- `init.sh`
- `orquestador/harness-manifest.txt`
- `orquestador/memory/complete/*`
- todos los prompts
- todos los metodos

Estas fuentes se cargan solo con perfil explicito.