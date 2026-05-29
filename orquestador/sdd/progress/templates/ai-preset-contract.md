# AI Preset Contract

```yaml
preset_id: PRESET-IA
target_ai: codex # codex | claude | gemini | generic
must_include:
  harness_required: true
  project_root_required: true
  binding_validation_required: true
  chat_role_interpreter: true
  leader_visible_required: true
  max_agents_total: 5
  preflight_before_effects: true
  explicit_si_required: true
  reentry_after_compaction: true
  external_harness_not_authority: true
  evidence_before_history_docs: true
checks:
  no_write_before_contract: false
  no_command_before_si: false
  no_git_before_si: false
  no_network_before_si: false
  role_separation_declared: false
result: pending # pass | blocked | fail
```
