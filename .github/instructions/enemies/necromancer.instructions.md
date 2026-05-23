---
description: "Use when editing Necromancer enemy scripts or scenes."
applyTo: "scripts/enemies/enemy_necromancer.gd, scenes/enemies/enemy_necromancer.tscn"
---

# Necromancer Enemy Guidelines

- Keep Necromancer behavior focused on summoning and survival.
- Make Necromancer flee from the player instead of trading in melee.
- Prefer summoning already dead Skeletons, Skeleton Archers, Zombies, and Bones Spiders rather than inventing new minions.
- Keep summon cooldowns, minion caps, flee speed, health, and spell range in exported tuning values.
- Preserve a readable loop: detect danger, reposition, summon, retreat, die cleanly.
- Avoid turning the Necromancer into a general-purpose caster unless a task explicitly requests it.