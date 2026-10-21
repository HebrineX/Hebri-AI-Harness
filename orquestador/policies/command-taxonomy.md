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

La aprobacion cubre el `cwd`, clase y alcance agrupado declarado, sin repetir `SI`
por cada paso menor. Ampliar alcance o efectos requiere nuevo preflight. El envelope
de Gateway conserva su binding al comando exacto cuando se usa ese ejecutor.

## Gateway vs host (0.17.3)

Las lecturas nativas acotadas al proyecto, sin secretos, incluido kernel/bootstrap,
no requieren preflight, `SI`, envelope ni Gateway obligatorio. Se respetan siempre
el perimetro real del host y las restricciones de secretos.

Gateway es un ejecutor opcional de lectura restringida, no universal. Su gramatica
`safe_patterns`, sus envelopes exactos y controles de `-CheckOnly`/`-Apply` no
se amplian por esta politica.

El hook Claude autoaprueba un subconjunto menor: AST PowerShell con un unico
`Get-Content`, `Get-ChildItem`, `Test-Path` o `Get-Item`, calificado con
`Microsoft.PowerShell.Management\`, un `-LiteralPath`
existente en el proyecto sin reparse ancestors, y solo `Get-Content` permite
`-Raw`. Alias, flags adicionales, recursion, wildcards, providers, pipelines,
redirecciones y codigo no se autoaprueban. Bash/Git quedan en defer inicialmente.
Los patrones peligrosos bloqueados fuerzan ask, incluso como texto citado.
Defer no equivale a prohibir una lectura nativa ni exige usar Gateway.

## Runtime Control

| Clase | Ejemplos | Decision por defecto | Requiere SI |
|---|---|---|---|
| `runtime-control` | `/harness status`, `/harness budget`, `/harness reentry` | read-only salvo cambio de estado | solo si hay efecto |
