# First Message Entrypoint

Ruta: `first_message`.
Presupuesto: <= 1800 tokens.

Objetivo: arrancar con contrato sin cargar todo el harness.

Leer:
1. `PROJECT_BINDING.yaml`
2. `orquestador/memory/local/session-pin.md`
3. `orquestador/memory/memory-registry.yaml`
4. `orquestador/memory/memory-routing.yaml`
5. `orquestador/context-budget.yaml`

No leer por defecto: README, CHANGELOG, manifest, init, prompts completos, memoria complete ni `infoHebri.md`.

Salida minima:

```text
Contrato detectado:
- Harness: si/no
- Version:
- Binding:
- Memory route: first_message
- Context budget: first_message <= 1800
- Capas cargadas: local
- Rol del chat: interprete
- Leader visible: si/pendiente
- Requiere SI antes de efectos: si
```