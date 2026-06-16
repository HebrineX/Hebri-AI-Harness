# Command Taxonomy

Todo comando debe clasificarse antes de ejecutarse. Si no encaja, usar `unknown` y pedir aprobacion explicita.

| Clase | Ejemplos | Decision por defecto | Requiere SI |
|---|---|---|---|
| `safe-read` | `rg`, `Get-Content`, `git status`, `git diff` | allow en scope aprobado | no |
| `local-verify` | `dotnet test`, `npm test`, `pytest` | ask | si |
| `local-write` | formatters, generators, build con outputs | ask | si |
| `network` | `git fetch`, descargas, APIs, web | ask | si |
| `git-local` | `git add`, `git commit`, branch local | ask | si |
| `git-remote` | `git push`, tags, releases, merge remoto | ask alto riesgo | si |
| `destructive` | borrar, reset, clean, drop DB | deny salvo instruccion explicita | si |
| `secret-touch` | leer `.env`, keys, tokens | deny salvo instruccion explicita | si |
| `unknown` | no clasificado | ask | si |

## Regla

La aprobacion cubre solo el comando declarado, el `cwd`, la clase y el alcance. Cualquier cambio requiere nuevo preflight.

## Runtime Control

| Clase | Ejemplos | Decision por defecto | Requiere SI |
|---|---|---|---|
| `runtime-control` | `/harness status`, `/harness budget`, `/harness reentry` | read-only salvo cambio de estado | solo si hay efecto |
