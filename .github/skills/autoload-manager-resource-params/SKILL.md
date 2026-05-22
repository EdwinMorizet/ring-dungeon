---
name: autoload-manager-resource-params
description: 'Create or refactor Godot autoload manager scripts to use resource-backed parameters with documented manager and config fields. Use for autoload setup, manager config resources, default .tres wiring, and parameter comment coverage.'
argument-hint: 'Which autoload manager(s) should be created/refactored and which parameters should be resource-backed?'
user-invocable: true
disable-model-invocation: false
---

# Autoload Manager Resource Parameters

## What This Skill Produces

This skill produces a consistent, typed autoload-manager pattern for Godot where every autoload manager has a dedicated Resource config and all manager parameters are documented in both manager and config scripts.

Expected outputs:
- Autoload manager script(s) wired to config resources.
- Config Resource script(s) with typed exported parameters.
- Default `.tres` config resource(s) in matching domain folders.
- Manager-side `set_config(...)` and `reset_default_config()` helpers.
- Parameter comments in manager scripts and config scripts.
- Verification pass for static errors and runtime smoke coverage.

## When To Use

Use this skill when the user asks to:
- Create a new autoload manager.
- Move autoload manager constants/exports into resource parameters.
- Standardize manager initialization and null-safe config fallback.
- Document all manager/config parameters.
- Ensure autoload setup remains behavior-compatible after refactor.

## Scope Decision Rules

1. Workspace vs personal
- Default to workspace skill execution and workspace file changes.
- Use project paths under `.github/`, `scripts/`, and `resources/`.

2. Manager selection
- If specific managers are named, change only those managers.
- If "all autoload managers" is requested, read `project.godot` `[autoload]` entries and cover each manager.

3. Parameter migration breadth
- Always enforce one dedicated config resource per autoload manager, even for small managers.
- If manager already uses a config resource, keep it and add missing comments/coverage.
- Move manager parameters into the manager config resource and access them through `_config`.
- Any parameter intentionally kept in manager must be documented with an explicit reason.

## Procedure

1. Discover autoload managers
- Read `project.godot` and list all `[autoload]` script paths.
- Open each manager and identify tunable parameters: exported fields, hardcoded balance values, and phase/state constants.

2. Create or reuse config resource scripts
- For every target autoload manager, ensure these files exist:
  - `scripts/<domain>/<manager>_config.gd`
  - `resources/<domain>/default_<manager>_config.tres`
- Use typed exports for each manager parameter intended for runtime behavior/configuration.
- Add concise one-line comments above every exported parameter.

3. Wire manager to default config resource
- In manager script:
  - Preload default config resource constant.
  - Add typed private `_config` variable initialized from default.
  - Add `set_config(config: ConfigType) -> void` with null guard.
  - Add `reset_default_config() -> void`.
- Replace migrated parameter reads with `_config.<field>` access.
- Add manager-side comments for config source and parameter intent.

4. Preserve behavior and compatibility
- Keep previous default values exactly unless the user explicitly requests retuning.
- Preserve public APIs and integration points.
- Keep singleton usage intact and avoid class/singleton naming collisions.

5. Comment all parameter surfaces
- Manager scripts: comment parameter source and any retained fixed constants.
- Config scripts: comment all `@export` parameters.
- Existing related resource scripts touched by the workflow: add missing export comments.

6. Validate
- Run static errors check on all modified files.
- If runtime is available, run smoke checks for:
  - manager initialization,
  - floor progression transitions,
  - spawn/drop behavior,
  - inventory nearby logic,
  - fireball runtime behavior,
  - control-lock behavior.
- If runtime cannot be executed, provide exact manual smoke checklist paths and expected outputs.

## Branching Logic

- If no config resource exists for a manager:
  - Create new config script and default `.tres`, then wire manager.
- If config resource exists but comments are missing:
  - Add comments without changing behavior.
- If manager has both tunables and protocol constants:
  - Prefer moving both into config for consistency.
  - If protocol constants are retained in manager, add explicit comments documenting why they are intentionally not resource-backed.
- If any type or null-safety issue appears after wiring:
  - Fix typed annotations/guards before finishing.

## Completion Criteria

The task is complete when all requested managers satisfy all checks:
1. Every targeted autoload manager has a dedicated typed `_config` resource source.
2. Default config `.tres` exists and is preloaded by manager.
3. `set_config(...)` and `reset_default_config()` are present and null-safe.
4. Every parameter has comments in both manager/config surfaces where applicable.
5. No static errors in modified files.
6. Runtime smoke validation is either executed or clearly handed off with exact checklist references.

## Output Format Guidance

When reporting results:
- List created/updated files.
- State whether defaults were preserved.
- Report static validation result.
- Report runtime smoke result (executed vs blocked and why).
- Suggest next steps only if meaningful (for example, run in-editor smoke pass).
