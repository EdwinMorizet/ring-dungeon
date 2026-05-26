---
description: "Use when editing player controller scripts in scripts/player. Keep movement and input code simple, typed, and stable."
applyTo: "scripts/player/**/*.gd, scenes/player/*.tscn"
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
- When explicitly requested by design changes, support single-click and long-press detection per mouse button with clear gating for inventory/control lock states.
- Favor readable control flow over abstraction-heavy patterns.
