---
description: "Use when editing enemy scripts in scripts/enemies. Start with the matching roster-specific enemy instruction file when one exists."
applyTo: "scripts/enemies/**/*.gd, scenes/enemies/*.tscn"
---

# Enemies Folder Guidelines

- Use the matching roster-specific file under `.github/instructions/enemies/` first when the enemy has a dedicated type file.
- Keep this file as the shared umbrella for all enemy scripts and scenes in the folder.
- Keep each enemy script focused on the combat loop:
  - Follow assigned patrol routes while idle or pre-aggro when patrol data exists.
  - Move toward, retreat from, or reposition around the player based on the roster role.
  - Receive damage and emit health-related signals.
  - Die cleanly and free itself.
- Prefer strongly typed GDScript for variables, arguments, and return values.
- Keep gameplay tuning values in exported properties so speed, health, attack range, and cooldowns can be adjusted without code rewrites.
- Use straightforward control flow with early returns; avoid abstraction-heavy AI patterns unless a task explicitly asks for them.
- Keep patrol integration minimal: prefer a single optional API such as `set_patrol_route(waypoints: Array[Vector3]) -> void` and default to current behavior when no route is assigned.
- Preserve current public API and scene integration points unless a task explicitly requests changing them.