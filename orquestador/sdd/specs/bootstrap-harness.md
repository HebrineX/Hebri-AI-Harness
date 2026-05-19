# Spec Bootstrap Harness

Esta spec conserva el brief largo original de bootstrap. No se carga en operacion diaria; solo se lee cuando el objetivo es crear o regenerar un harness completo.

## Uso

1. Leer orquestador/context-profiles.md perfil ootstrap.
2. Leer orquestador/method/global-rules.md.
3. Leer esta spec.
4. Ejecutar el bootstrap con aprobacion humana antes de escribir archivos.

---


# Brief operativo — Crear Hebri-AI-Harness

Aplicás la metodología documentada en
https://github.com/Hebrinex/Hebri-AI-Structure (v2.1.0). Antes de
producir nada, leé al menos el `README.md`, `AGENTS.md` y los
archivos `biblia/vol-04-arquitectura-repo.md`, `biblia/vol-07-harness.md`,
`biblia/vol-09-roles-cerrados.md` de ese repo. Si no podés acceder, decilo
y parás — no completes con criterio propio.

---

## Objetivo

Crear el repositorio scaffolding **Hebri-AI-Harness**: una plantilla
ejecutable que implementa la metodología Hebri-AI-Structure. Cualquier
proyecto nuevo arranca clonando este harness, personalizando
`AGENTS.md` con su stack y siguiendo el ciclo del Vol 01.

El harness es la materialización del Gap H-01 registrado en Vol 07.

---

## Contexto

- **Stack del harness:** Markdown + scripts shell + YAML (CI). Sin código de
  runtime propio. Es scaffolding, no aplicación.
- **Audiencia:** desarrolladores que arrancan un proyecto nuevo y quieren
  el flujo SDD + roles cerrados pre-cargado.
- **Decisión arquitectónica:** GitHub-first según Vol 04 (el orquestador
  vive en `.github/orquestador/`). Si en el futuro alguien quiere
  Claude-first, agrega `.claude/` como capa adicional.

---

## Restricciones

- No copies el contenido de la biblia adentro del harness — solo
  **referenciala** desde `AGENTS.md`. La metodología vive en
  Hebri-AI-Structure; el harness solo la implementa.
- No agregues lenguaje específico (Node, .NET, Python) al stack base. El
  stack se decide al personalizar el harness, no acá.
- No agregues herramientas pesadas (Docker, terraform, npm modules) en
  la base. Si hace falta, lo decide el proyecto que use el harness.
- Todos los nombres de archivos y carpetas en ASCII (sin tildes, sin
  espacios, kebab-case).

---

## Archivos a producir

### Raíz

```
Hebri-AI-Harness/
├── README.md
├── AGENTS.md
├── PROGRESS.md
├── CHANGELOG.md
├── .editorconfig
├── .markdownlint.json
├── .gitignore
└── init.sh
```

### `.github/`

```
.github/
├── copilot-instructions.md
├── workflows/
│   └── ci.yml
├── prompts/
│   ├── arrancar-proyecto.prompt.md
│   ├── plan-fase.prompt.md
│   ├── plan-slice.prompt.md
│   ├── cierre-fase.prompt.md
│   ├── explorar.prompt.md
│   ├── worker.prompt.md
│   ├── brief.prompt.md
│   ├── registrar-gap.prompt.md
│   ├── revisar-spec.prompt.md
│   ├── lider.prompt.md
│   ├── spec-author.prompt.md
│   ├── implementer.prompt.md
│   └── reviewer.prompt.md
└── orquestador/
    ├── README.md
    ├── context/
    │   ├── product.md          (template vacío)
    │   └── architecture.md     (template vacío)
    ├── sdd/
    │   ├── specs/
    │   │   └── _template/
    │   │       ├── requirements.md
    │   │       ├── design.md
    │   │       └── tasks.md
    │   └── progress/
    │       └── _README.md      (explica formato de impl_/review_)
    ├── policies/
    │   ├── permissions.md
    │   └── risk-criteria.md
    └── pipelines/
        └── README.md
```

### Roles cerrados (Claude-first opcional)

```
.claude/
└── agents/
    ├── leader.md
    ├── spec_author.md
    ├── implementer.md
    └── reviewer.md
```

Cada archivo describe el rol con su ownership y prompt base, alineado
con Vol 09 de Hebri-AI-Structure.

---

## Contenido de archivos clave

### `AGENTS.md` (base, parametrizable)

```markdown
# AGENTS.md — [NOMBRE-DEL-PROYECTO]

> Este proyecto sigue Hebri-AI-Structure: https://github.com/Hebrinex/Hebri-AI-Structure
> En conflicto, la biblia gana sobre este archivo.

## Stack
- Lenguaje: [completar]
- Framework: [completar]
- Tests: [completar]

## Comandos
- Tests: `[comando]`
- Build: `[comando]`
- Validar todo: `./init.sh`

## Mapa
| Ruta | Contenido | Cuándo leer |
|---|---|---|
| `.github/orquestador/context/` | Producto y arquitectura | Al arrancar una sesión |
| `.github/orquestador/sdd/specs/` | Specs activas | Antes de implementar |
| `.github/orquestador/sdd/progress/` | Handoffs de roles | Para saber qué pasó antes |
| `PROGRESS.md` | Fases, slices y gaps | Siempre al arrancar |

## Roles activos (ver Vol 09 de la biblia)
- leader · spec_author · implementer · reviewer
- Par informal: explorer / worker (para tareas chicas)

## Reglas
- No tocar código antes de spec aprobada.
- No declarar done sin tests verdes y build limpio.
- Si un comando falla, reportar el error exacto antes de continuar.

## Cierre
Archivos modificados + comando ejecutado con resultado + gaps nuevos.
```

### `PROGRESS.md` (template)

Seguí el formato de Vol 06 con tabla de fases, tabla de gaps y sección de
criterios de cierre. Pre-cargá una "Fase 0 — Setup inicial" con tres slices
del propio harness.

### `init.sh`

Script POSIX `#!/usr/bin/env sh` con `set -eu`. Debe:
1. Verificar que existe `AGENTS.md`, `PROGRESS.md` y `.github/orquestador/`.
2. Correr el comando de tests si está definido en `AGENTS.md` (búsqueda
   simple).
3. Salir con código `0` si todo OK, `1` si tests fallan, `2` si falta
   estructura básica.

Sin lógica específica de stack — eso lo agrega cada proyecto que use el
harness.

### `.github/workflows/ci.yml`

Workflow mínimo: markdownlint + lychee link checker. Sin tests de stack
(eso lo agrega cada proyecto).

### Prompts en `.github/prompts/`

Copiar **textualmente** los 13 prompts de Hebri-AI-Structure
v2.1.0. Mismo contenido y nombres ASCII. Esto evita que cada proyecto
tenga que re-escribirlos.

### `.claude/agents/leader.md` (ejemplo)

```markdown
# leader

Rol cerrado según Vol 09 de Hebri-AI-Structure.

NO implementa código. NO escribe specs. NO revisa diffs. Solo orquesta.

## Ownership
Lectura: PROGRESS.md, AGENTS.md, .github/orquestador/sdd/specs/*, .github/orquestador/sdd/progress/*
Escritura: ninguna (solo decisiones por chat).

## Dispatch
Ver tabla de pivoteo en Vol 09 y prompt operativo en
.github/prompts/lider.prompt.md.
```

Equivalentes para `spec_author.md`, `implementer.md`, `reviewer.md` con
sus respectivos ownerships y referencias a los prompts.

---

## Salida esperada

1. Carpeta `Hebri-AI-Harness/` creada con la estructura arriba.
2. Todos los archivos con contenido pre-cargado (no vacíos, salvo los
   templates explícitamente vacíos como `product.md`).
3. Un `README.md` raíz que explique:
   - Qué es el harness y qué NO es.
   - Cómo clonarlo y personalizarlo (3-5 pasos concretos).
   - Link a Hebri-AI-Structure como fuente metodológica.
4. Un `CHANGELOG.md` con `[0.1.0]` registrando el bootstrap.
5. `PROGRESS.md` con "Fase 0 — Setup inicial" cerrada y "Fase 1 —
   Validación con primer proyecto piloto" como pendiente.

---

## Verificación

Al terminar, ejecutá y mostrá el resultado:

```bash
cd Hebri-AI-Harness
chmod +x init.sh
./init.sh
find . -name "*.md" | xargs -I {} wc -l {} | head
ls -la .github/orquestador/sdd/specs/_template/
```

Esperado: `init.sh` retorna 0 con mensaje de estructura OK; al menos 25
archivos `.md` creados; el template de specs tiene los tres archivos.

---

## Riesgos

- **Copiar la biblia adentro del harness.** Lo haría duplicado y se va a
  desincronizar. Solo referenciá.
- **Atar a un stack concreto.** El harness es agnóstico; los stacks viven
  en Vol 04 de la biblia, no acá.
- **Sobre-ingeniar el `init.sh`.** Que sea POSIX puro, sin dependencias.
  Cada proyecto extiende según necesite.
- **Saltearse Vol 09 al definir los roles.** Los 4 archivos en
  `.claude/agents/` deben respetar las restricciones de la tabla de
  permisos (leader no implementa, reviewer no edita, etc.).

---

## Nivel de autonomía

N2 (escritura local) — creás archivos pero no hacés push ni deploys.
Cuando termines, parás y dejás que el operador revise el árbol antes de
hacer `git init` + `git remote add` + `git push`.

---

## Formato de cierre

Reportá:

1. Cantidad total de archivos creados, agrupados por carpeta.
2. Resultado de `./init.sh`.
3. Diff conceptual con Vol 09: qué partes de los 4 roles cerrados están
   materializadas en `.claude/agents/` y qué partes quedaron solo
   referenciadas desde los prompts.
4. Gaps nuevos detectados durante el bootstrap (registralos como `H-02`,
   `H-03`, etc. en `PROGRESS.md` del harness).
5. Próximo paso sugerido: qué hace falta para validar el harness con un
   proyecto piloto real.

No hacés `git commit` ni `git push`. Eso queda para el operador humano.

