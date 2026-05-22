---
name: "Refactor Autoload Manager"
description: "Refactor one or more Godot autoload managers to dedicated resource-backed configs with full parameter comments and safe config lifecycle methods."
argument-hint: "Manager name(s) and scope (single manager or all autoload managers)"
agent: "agent"
---

Refactor autoload manager scripts to the project autoload-manager config standard.

## Inputs

- Target: user-provided manager name(s), or all managers in `project.godot` `[autoload]`.
- Constraint: preserve current gameplay defaults unless user explicitly asks to retune.

## Required Actions

1. Discover target manager scripts from `project.godot` and/or provided names.
2. Ensure each target manager has:
- `scripts/<domain>/<manager>_config.gd`
- `resources/<domain>/default_<manager>_config.tres`
3. Migrate manager parameters to config exports.
4. Wire manager with:
- `Default...Config` preload
- typed `_config`
- `set_config(...)` and `reset_default_config()`
5. Add comments:
- above each config export
- on manager config source and retained fixed constants
6. Run static diagnostics on changed files and fix introduced issues.

## Output Requirements

- List files created/updated.
- Confirm defaults preserved.
- Report diagnostics status.
- If runtime is unavailable, provide manual smoke checks and expected outcomes.
