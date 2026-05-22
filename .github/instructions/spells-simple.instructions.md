---
description: "Use when editing fireball or spell scripts in scripts/spells. Keep gameplay logic simple, typed, and easy to tune."
applyTo: "scripts/spells/*.gd, resources/spells/*.tres, scenes/spells/*.tscn"
---

# Spells Folder Guidelines

- Keep each script focused on one role:
  - `fireball_config.gd`: data only.
  - `fireball_manager.gd`: spawn and orchestration only.
  - `fireball_projectile.gd`: projectile runtime behavior only.
- Prefer strongly typed GDScript for variables, arguments, and return values.
- Keep exported tuning values in config resources or exported properties, not hard-coded in logic paths.
- Use straightforward control flow over clever abstractions.
- Preserve current public method names and scene wiring unless a task explicitly asks to refactor them.
