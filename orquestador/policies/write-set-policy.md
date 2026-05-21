# Write-set Policy

## Regla

Toda accion con escritura debe declarar `write_set` antes de ejecutarse. Al terminar, el leader o reviewer compara el diff real contra ese `write_set`.

## Bloquear si

- Aparece un archivo modificado fuera del `write_set`.
- El comando genero archivos no declarados.
- Un agente edito fuera de ownership.
- Se modifico un archivo `forbidden` o sensible.
- El `write_set` era abstracto, por ejemplo: "todo el proyecto".

## Evidencia Requerida

```yaml
write_set:
  declared: []
  actual: []
  unexpected: []
  verdict: pass | fail | blocked
```
