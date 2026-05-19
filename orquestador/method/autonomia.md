# Autonomía y Recuperación

## Niveles de Autonomía
| Nivel | Qué Puede Hacer | Cuándo Aplicarlo |
|---|---|---|
| **0 - Read-only** | Leer repositorio | Exploración |
| **1 - Suggest** | Leer + Proponer cambios en diff | Pair programming |
| **2 - Local-write** | Escribir en disco (NO bash que mude estado externo) | Implementación de slice |
| **3 - Validated-execute** | Correr tests/build locales (NO push) | Cierre y verificación |
| **4 - Full** | Push, deploy | SÓLO supervisión humana |

*Por defecto: N2 para implementer, N0 para explorer, N3 solo al verificar el slice.*

## Recuperación de Errores (Cuándo parar el agente)
Cortar ejecución si:
1. **Loop**: Tres iteraciones idénticas sin converger.
2. **Alucinación**: Editar o citar archivos que no existen (validar con `ls`/`list_dir`).
3. **Cierre sin Evidencia**: Dice "done" sin correr tests ni pasar el comando.
4. **Fuga de Scope**: Modifica un archivo fuera del ownership.

**Cómo salir**: Detener el proceso, descartar cambios no guardados, registrar gap en `PROGRESS.md` y rearmar el contexto más acotado.
