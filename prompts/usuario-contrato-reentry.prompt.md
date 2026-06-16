---
description: "Prompt de usuario para exigir contrato, compactacion y re-entry del harness"
---

# Prompt Usuario - Contrato y Re-entry

Usa este prompt cuando arrancas un proyecto, cuando no sabes si existe `.hebrinex/`, cuando la sesion fue compactada o cuando notas que el agente dejo de respetar el harness.

## Arranque con `.hebrinex/` existente

```text
Usa Hebri-AI-Harness como contrato operativo obligatorio.

Antes de cualquier analisis, plan, comando, edicion, red, git o subagente:

1. Confirmá Project root.
2. Confirmá Harness path.
3. Leé y validá .hebrinex/PROJECT_BINDING.yaml.
4. Confirmá si el binding es bound, source_template, missing o mismatch.
5. Leé .hebrinex/AGENTS.md.
6. Leé .hebrinex/orquestador/method/session-contract.md.
7. Leé .hebrinex/orquestador/sdd/progress/state.yaml y registry.yaml.
8. Declarame el contrato de sesión.

Formato obligatorio:

Contrato de sesión:
- Harness detectado: sí
- Harness path: [ruta absoluta]/.hebrinex
- Project root: [ruta absoluta del proyecto]
- Binding: [bound | source_template | missing | mismatch]
- Fuente del harness: .hebrinex del proyecto
- Modo: automatico
- Rol del chat: interprete
- Leader visible: sí, declarado en conversación
- Subagentes activos: 0/4
- Fase/Slice activo: [id o ninguno]
- Estado SDD: [pending | spec_ready | in_progress | review | done | blocked]
- Approvals vigentes: [ninguno | lista]
- Locks abiertos: [ninguno | lista]
- Agentes abiertos: [ninguno | lista]
- Próxima acción propuesta: [acción]
- Aprobación requerida: SI antes de comandos, edición, red, git, subagentes con efecto o cambios de estado

No sigas hasta confirmar que el binding pertenece a este proyecto.
```

## Arranque sin `.hebrinex/`

```text
Usa Hebri-AI-Harness como contrato operativo obligatorio.

Si este proyecto no tiene .hebrinex/:

1. No uses un harness local externo como autoridad operativa.
2. Buscá una fuente local libre con PROJECT_BINDING.yaml y binding_mode: source_template.
3. Si existe, proponé copiarla a [project_root]/.hebrinex/ y vincularla como bound.
4. Si no existe fuente local libre, proponé bajar obligatoriamente https://github.com/HebrineX/Hebri-AI-Harness y vincularlo al proyecto.
5. Si no podés copiar ni bajar, pedime ruta o contenido.
6. No copies, descargues, edites, corras comandos, uses red ni git sin preflight y mi SI.

Formato obligatorio:

Contrato de sesión:
- Harness detectado: no
- Project root: [ruta absoluta del proyecto]
- Binding: missing
- Fuente del harness: pendiente
- Modo: automatico
- Rol del chat: interprete
- Leader visible: sí, declarado en conversación
- Subagentes activos: 0/4
- Estado SDD: blocked hasta bootstrap
- Próxima acción propuesta: buscar fuente libre o descargar harness
- Requiere SI: sí antes de copiar, descargar, editar o ejecutar comandos
```

## Compactacion del contrato

Antes de cerrar una fase, pausar, compactar o entregar estado parcial, dejá este snapshot:

```text
CONTRACT SNAPSHOT:
- Project root:
- Harness path:
- Harness version:
- Binding: bound | source_template | missing | mismatch
- Modo:
- Rol del chat: interprete
- Leader visible:
- Ciclo/Slice activo:
- Estado SDD:
- Approvals vigentes:
- Locks abiertos:
- Agentes abiertos:
- Última evidencia:
- Próximo paso permitido:
- Requiere SI antes de:
```

Regla: una compactación no conserva approvals. Después de compactar, pedí revalidación.

## Re-entry cuando el agente se desvia

```text
STOP. Re-entry obligatorio del Hebri-AI-Harness.

No sigas ejecutando ni proponiendo solución técnica todavía.

Reconstruí contrato:
1. Confirmá Project root.
2. Confirmá Harness path.
3. Leé/validá PROJECT_BINDING.yaml.
4. Confirmá si el binding es bound, source_template, missing o mismatch.
5. Leé AGENTS.md, session-contract.md, state.yaml y registry.yaml.
6. Expirá approvals anteriores si hubo compactación, cambio de cwd o cambio de proyecto.
7. Declarame leader visible, ciclo activo, locks, agentes abiertos y siguiente paso.
8. No edites, no corras comandos, no uses git/red y no cambies estado hasta nuevo SI.

Respondé solo con el contrato reconstruido y el próximo preflight.
```

## Frase corta de emergencia

```text
Volvé al harness. Re-entry 0.8.7: valida PROJECT_BINDING, session-pin, memory-registry, memory-routing, project_root, harness_path, state, registry y expiracion de approvals antes de seguir.
```
