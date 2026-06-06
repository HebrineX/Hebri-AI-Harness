# Adapter Contract

Version: 0.8.2

Todo adapter debe usar esta entrada minima antes de actuar:

1. `PROJECT_BINDING.yaml`
2. `orquestador/memory/local/session-pin.md`
3. `orquestador/memory/memory-registry.yaml`
4. `orquestador/memory/memory-routing.yaml`
5. `orquestador/context-budget.yaml`
6. entrypoint aplicable en `orquestador/entrypoints/`

Requisitos:
- declarar donde se ponen instrucciones persistentes;
- declarar si la herramienta tiene memoria confiable;
- explicar first-message, reentry-light, reentry-full, debug-log-intake y compactation-recovery;
- simular leader/subagentes si la herramienta no los soporta;
- exigir preflight y `SI` antes de efectos;
- prohibir memoria de herramienta como evidencia;
- prohibir `infoHebri.md` como contexto operativo;
- reportar presupuesto antes de cargar contexto amplio.