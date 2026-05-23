---
description: "Use when editing any enemy script or scene. Route roster-specific work to the matching enemy instruction file."
applyTo: "scripts/enemies/*.gd, scenes/enemies/*.tscn"
---

# Enemy Roster Hub

- Start here for any enemy work, then follow the matching roster-specific instruction file when one exists.
- Keep enemy behavior aligned with the game design intent: room spawns, corridor pursuit after aggro, and simple pre-aggro patrol or roam behavior.
- Keep the shared implementation rules consistent across all enemy types:
  - Strong typing for variables, arguments, and return values.
  - Exported tuning values for balance knobs.
  - Simple control flow with early returns.
  - Clean death and cleanup.
- Use the matching type file for role-specific behavior, attack style, movement style, and summon or spell exceptions.
- If a new enemy type is added later, create a new roster-specific file beside the existing ones and link it back to this hub.