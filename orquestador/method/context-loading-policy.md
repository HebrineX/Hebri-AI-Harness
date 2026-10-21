# Context Loading Policy

Version: 0.17.3

## Objetivo

Minimizar el consumo operativo del harness: el kernel liviano ahorra un 90% medido frente a la documentacion operativa completa (`hebrinex usage`, marker `savings_docs_pct`). La regla por defecto es cargar kernel liviano, no contrato completo.

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

El presupuesto aplica solo a archivos del kernel (`scope: kernel_files_only`),
no al read-set de implementacion, tests o documentos de trabajo. Aplicar a ese
kernel los umbrales y acciones de `context-budget.yaml`.

Leer kernel/bootstrap con herramientas nativas, dentro del proyecto y sin secretos,
no requiere `SI`, preflight, envelope ni Gateway obligatorio. Gateway es opcional
y restringido; esta regla no elimina restricciones del host ni de secretos.

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
