# Ciclo de Trabajo

El ciclo obliga a pasar por pasos específicos. Prohibido saltear pasos.

1. **Intención**: Resultado deseado en una frase verificable.
2. **Contexto**: Unidad mínima (Objetivo, Estado, Restricciones, Archivos, Riesgos).
3. **Plan**: 3 a 7 pasos concretos y archivos afectados.
4. **Ejecución**: Un cambio a la vez, ownership explícito.
5. **Verificación**: Comando que confirma (test, build).
6. **Registro**: Gaps nuevos a `PROGRESS.md`, o actualización de artifacts.

## Unidad Mínima de Contexto (Campos Obligatorios)

| Tipo de Tarea | Campos Obligatorios |
|---|---|
| Exploración | Objetivo + Archivos + Restricciones (solo lectura) |
| Corrección puntual | Objetivo + Archivos + Verificación |
| Implementación | Todos los campos |
| Documentación | Objetivo + Archivos + Salida esperada |

## Subagentes Básicos (Explorer/Worker)

**Explorer**: Solo lectura. Devuelve hallazgos con evidencia. No edita archivos.
**Worker**: Recibe objetivo acotado, ownership claro (archivos exclusivos) y criterio de verificación. Toca solo los archivos autorizados y valida con comando acordado.
