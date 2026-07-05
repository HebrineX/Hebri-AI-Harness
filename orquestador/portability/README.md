# Agent Portability

Version: 0.14.0

La portabilidad separa el contrato operativo core de las superficies especificas de cada IA.

```text
core portable -> adapter matrix -> adapter por host -> preset/hook/instruccion concreta
```

Reglas:

- `.hebrinex/` sigue siendo autoridad; ningun adapter reemplaza al harness bound.
- Los adapters son delgados: explican como cargar el contrato en cada host.
- La memoria de herramienta no es evidencia.
- Si un host no soporta subagentes reales, los roles se simulan de forma trazable.
- Todo host debe mapear entrypoints y preflight.
- `Generic AI` es fallback obligatorio.

Inspiracion: Ponytail distribuye un core comun y adapters por host. Hebri lo aplica como contrato operativo verificable, no como reglas sueltas.