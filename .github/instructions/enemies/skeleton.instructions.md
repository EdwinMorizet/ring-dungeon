---
description: "Use when editing Skeleton enemy scripts or scenes."
applyTo: "scripts/enemies/enemy_skeleton.gd, scenes/enemies/enemy_skeleton.tscn"
---

# Skeleton Enemy Guidelines

- Keep Skeleton behavior simple, typed, and melee-focused.
- Make Skeleton follow patrol nodes while idle or pre-aggro when route data exists.
- Use a good field of vision and prioritize chase over patrol once aggro starts.
- Keep melee attack range, movement speed, health, and cooldowns in exported tuning values.
- Preserve a straightforward combat loop: patrol, spot player, chase, attack, die cleanly.
- Do not add ranged attacks or summon behavior to Skeleton unless a task explicitly asks for it.