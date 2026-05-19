# Specification-Driven Development (SDD)

El código se escribe en base a specs aprobadas.

## Flujo de Estados
1. `pending`: El `spec_author` escribe requirements, design, tasks.
2. `spec_ready`: Spec lista, bloqueada hasta APROBACIÓN HUMANA.
3. `in_progress`: El `implementer` ejecuta.
4. `done`: El `reviewer` verifica y aprueba contra test/spec.

## Formato EARS (Requirements)
- **Ubicuo**: El sistema DEBE `[acción]`.
- **Evento**: CUANDO `[evento]`, el sistema DEBE `[acción]`.
- **Estado**: MIENTRAS `[condición]`, el sistema DEBE `[acción]`.
- **Opcional**: DONDE `[feature activa]`, el sistema DEBE `[acción]`.
- **No deseado**: SI `[situación no deseada]` ENTONCES el sistema DEBE `[acción]`.

## Checklist de Cierre de Slice
- [ ] Requirement escrito con ID estable.
- [ ] Alcance excluye lo que no entra.
- [ ] Tasks trazables a requirements.
- [ ] Tests pasan (evidencia con comando).
- [ ] Gaps nuevos registrados en `PROGRESS.md`.
