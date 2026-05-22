---
name: "Validate Autoload Manager Configs"
description: "Validate Godot autoload managers for dedicated config resources, parameter comments, lifecycle helpers, and static diagnostics."
argument-hint: "Validation scope: all autoload managers or specific manager names"
agent: "agent"
---

Validate autoload managers against the project manager-config standard.

## Validation Steps

1. Read `project.godot` `[autoload]` and enumerate manager scripts in scope.
2. For each manager, verify:
- Dedicated config script exists: `scripts/<domain>/<manager>_config.gd`
- Default config resource exists: `resources/<domain>/default_<manager>_config.tres`
- Manager has typed `_config` bound to default config preload
- Manager includes `set_config(...)` and `reset_default_config()`
- Manager parameters are sourced from `_config`
- Manager-side parameter comments are present
- Config exported fields are commented
3. Run diagnostics for all files in scope.
4. Summarize pass/fail matrix per manager with missing items.

## Output Format

1. Pass/fail table by manager.
2. Missing requirements by file path.
3. Diagnostics summary.
4. Minimal remediation plan ordered by risk.
