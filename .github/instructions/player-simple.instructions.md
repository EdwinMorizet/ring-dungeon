---
description: "Use when editing player controller scripts in scripts/player. Keep movement and input code simple, typed, and stable."
applyTo: "scripts/player/*.gd"
---

# Player Folder Guidelines

- Keep responsibilities clear in `player_fps_controller.gd`:
  - Input handling
  - Camera look and FOV behavior
  - Movement and gravity
  - Fireball trigger call
- Prefer strongly typed GDScript for variables, arguments, and return values.
- Keep tuning values in exported properties so movement and camera feel can be adjusted without rewriting logic.
- Preserve existing input action names and FireballManager integration unless a task explicitly requests changing them.
- Favor readable control flow over abstraction-heavy patterns.
