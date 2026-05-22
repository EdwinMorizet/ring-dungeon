---
description: "Use when editing enemy scripts in scripts/enemies. Keep enemy behavior simple, typed, and easy to tune."
applyTo: "scripts/enemies/*.gd, scenes/enemies/*.tsn"
---

# Enemies Folder Guidelines

- Keep each enemy script focused on core combat loop behavior:
  - Move toward the player.
  - Receive damage and emit health-related signals.
  - Die cleanly and free itself.
- Prefer strongly typed GDScript for variables, arguments, and return values.
- Keep gameplay tuning values in exported properties so speed, health, and damage can be adjusted without code rewrites.
- Use straightforward control flow with early returns; avoid abstraction-heavy AI patterns unless a task explicitly asks for them.
- Preserve current public API and scene integration points unless a task explicitly requests changing them.