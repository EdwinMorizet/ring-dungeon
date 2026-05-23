---
description: "Use when editing Skeleton Archer enemy scripts or scenes."
applyTo: "scripts/enemies/enemy_skeleton_archer.gd, scenes/enemies/enemy_skeleton_archer.tscn"
---

# Skeleton Archer Enemy Guidelines

- Keep Skeleton Archer behavior simple and ranged-focused.
- Make Skeleton Archer use patrol nodes while idle or pre-aggro when route data exists.
- Give it a strong preference for keeping distance from the player once aggro begins.
- Keep projectile cadence, retreat distance, movement speed, health, and accuracy in exported tuning values.
- Preserve a readable loop: patrol, acquire target, reposition, fire, recover, die cleanly.
- Avoid melee-heavy fallback logic unless a task explicitly asks for it.