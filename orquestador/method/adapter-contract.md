# Adapter Contract

Version: 0.8.0

## Objetivo

Hacer que el harness sea portable entre IAs sin depender de una sola herramienta.

## Requisitos de cualquier adapter

1. Declarar donde se ponen instrucciones persistentes.
2. Declarar si la herramienta tiene memoria confiable o no.
3. Explicar como ejecutar `first-message`, `reentry-light`, `reentry-full` y `debug-log-intake`.
4. Explicar como representar leader/subagentes si no existen subagentes reales.
5. Exigir preflight y SI antes de efectos.
6. Prohibir usar memoria de la herramienta como evidencia.

## Fallback

Si no existe adapter especifico, usar `orquestador/adapters/generic-ai.md`.