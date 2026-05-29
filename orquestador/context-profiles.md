# Context Profiles

No cargues todo `.hebrinex` por defecto. Elegi el perfil minimo para la tarea.

## Perfil `leader` (~2k-3k tokens)

Leer:
- `AGENTS.md`
- `PROJECT_BINDING.yaml`
- `PROGRESS.md`
- `orquestador/method/session-contract.md`
- `orquestador/method/harness-resolution.md`
- `orquestador/method/operating-modes.md`
- `orquestador/method/multiagent-protocol.md`
- `orquestador/method/agent-role-taxonomy.md`
- `orquestador/method/global-rules.md`
- `orquestador/sdd/progress/state.yaml`
- `orquestador/sdd/progress/registry.yaml`
- `orquestador/sdd/progress/registry.md`
- `orquestador/sdd/progress/blocked.md`

## Perfil `spec_author` (~1.5k-3k tokens)

Leer:
- `orquestador/method/global-rules.md`
- `orquestador/method/sdd.md`
- `orquestador/context/product.md`
- `orquestador/context/architecture.md`
- `orquestador/sdd/specs/_template/`
- `prompts/spec-author.prompt.md`

## Perfil `implementer` (~2k-4k tokens)

Leer:
- `orquestador/method/global-rules.md`
- `orquestador/policies/permissions.md`
- `orquestador/policies/risk-criteria.md`
- `orquestador/policies/tool-policy.yaml`
- `orquestador/policies/write-set-policy.md`
- `orquestador/sdd/specs/<feature>/requirements.md`
- `orquestador/sdd/specs/<feature>/design.md`
- `orquestador/sdd/specs/<feature>/tasks.md`
- `orquestador/sdd/progress/state.yaml`
- `orquestador/sdd/progress/registry.yaml`
- lock activo en `orquestador/sdd/progress/locks/`
- `prompts/implementer.prompt.md`

## Perfil `reviewer` (~2k-4k tokens)

Leer:
- `orquestador/method/global-rules.md`
- `orquestador/sdd/specs/<feature>/`
- artefacto `impl_*.md`
- `gate-log.yaml` si existe
- `verification-matrix.yaml` si existe
- `final-report.md` si existe
- `prompts/reviewer.prompt.md`

## Perfil `auditor` (~2k-4k tokens)

Leer:
- `orquestador/method/global-rules.md`
- `orquestador/method/agent-role-taxonomy.md`
- `orquestador/method/multiagent-protocol.md`
- `orquestador/sdd/progress/state.yaml`
- `orquestador/sdd/progress/registry.yaml`
- gate logs, audit trails, final reports y agent closures del ciclo auditado
- `agents/auditor.md`

## Perfil `release` (~3k-6k tokens)

Leer cuando se actualiza changelog, release notes, README versionado, deploy docs historicos o roadmap consolidado:
- `AGENTS.md`
- `PROJECT_BINDING.yaml`
- `PROGRESS.md`
- `CHANGELOG.md`
- `orquestador/method/evidence-reconstruction.md`
- `orquestador/method/changelog-policy.md`
- `orquestador/sdd/progress/state.yaml`
- `orquestador/sdd/progress/registry.yaml`
- `orquestador/sdd/progress/registry.md`
- gate logs, final reports y audit trails relevantes
- `orquestador/sdd/progress/templates/changelog-reconstruction-checklist.md`
- `orquestador/sdd/progress/templates/release-history-matrix.yaml`
- `prompts/actualizar-changelog.prompt.md`

Comandos read-only recomendados:
- `git log --oneline --decorate --date=short`
- `git show --stat <sha>`

## Perfil `deploy_migration` (~3k-6k tokens)

Leer:
- `orquestador/method/deploy-migration-policy.md`
- scripts, workflows y docs de deploy/migracion del proyecto
- `CHANGELOG.md`, `PROGRESS.md` y registry si se documenta historia
- `orquestador/sdd/progress/templates/deploy-migration-checklist.md`
- `prompts/reconstruir-deploy-migracion.prompt.md`

## Perfil `version_drift` (~2k-4k tokens)

Leer:
- `HARNESS_VERSION`
- `PROJECT_BINDING.yaml`
- `README.md`
- `CHANGELOG.md`
- `init.sh`
- prompts de migracion/re-entry
- `orquestador/method/reference-drift-policy.md`
- `orquestador/sdd/progress/templates/reference-drift-matrix.yaml`

## Perfil `ci_pipeline` (~3k-6k tokens)

Leer:
- workflows/scripts de CI
- logs o capturas provistas
- commits relevantes
- `orquestador/method/ci-pipeline-policy.md`
- `orquestador/sdd/progress/templates/ci-pipeline-history.yaml`
- `prompts/reconstruir-ci-pipeline.prompt.md`

## Perfil `backlog` (~2k-4k tokens)

Leer:
- `PROGRESS.md`
- `orquestador/sdd/progress/future-p1.md`
- registry y auditorias relevantes
- `orquestador/method/backlog-policy.md`
- `orquestador/sdd/progress/templates/backlog-classification-matrix.yaml`

## Perfil `preset_ai` (~2k-4k tokens)

Leer:
- `orquestador/method/ai-preset-policy.md`
- `orquestador/sdd/progress/templates/ai-preset-contract.md`
- `prompts/preset-codex.prompt.md`
- `prompts/preset-claude.prompt.md`
- `prompts/preset-gemini.prompt.md`

## Perfil `reporter` (~1k-2k tokens)

Leer:
- output de auditor/reviewer/leader
- audiencia objetivo
- `agents/reporter.md`
- evidencia referenciada, no todo el repo

## Perfil `ai_engineering` (~2k-5k tokens)

Leer solo cuando se conectan LLMs, tools o runtime:
- `orquestador/method/ai-engineering.md`
- `orquestador/policies/permissions.md`
- `orquestador/policies/risk-criteria.md`
- `orquestador/policies/tool-policy.yaml`
- `orquestador/policies/write-set-policy.md`
- prompt o workflow especifico

## Perfil `bootstrap` (~4k-8k tokens)

Leer solo para crear o regenerar un harness:
- `PROJECT_BINDING.yaml`
- `orquestador/harness-manifest.txt`
- `prompts/crear-harness.prompt.md`
- `prompts/migrar-harness-0-7.prompt.md` si se migra desde version previa
- `orquestador/method/harness-resolution.md`
- `orquestador/sdd/specs/bootstrap-harness.md`
- `orquestador/method/global-rules.md`
- `orquestador/method/ai-engineering.md` si se agregan runtime/tools

## Presupuesto por defecto

| Perfil | Presupuesto objetivo |
|---|---:|
| leader | 3k tokens |
| spec_author | 3k tokens |
| implementer | 4k tokens |
| reviewer | 4k tokens |
| auditor | 4k tokens |
| release | 6k tokens |
| deploy_migration | 6k tokens |
| version_drift | 4k tokens |
| ci_pipeline | 6k tokens |
| backlog | 4k tokens |
| preset_ai | 4k tokens |
| reporter | 2k tokens |
| ai_engineering | 5k tokens |
| bootstrap | 8k tokens |
