---
description: "Use when editing Bones Spider enemy scripts or scenes."
applyTo: "scripts/enemies/enemy_bones_spider.gd, scenes/enemies/enemy_bones_spider.tscn"
---

# Bones Spider Enemy Guidelines

- Keep Bones Spider behavior fast, direct, and easy to read.
- Make Bones Spider feel like a small hitbox swarm unit with hit-and-run pressure.
- Prefer random roaming before aggro and aggressive chase after aggro.
- Keep speed, acceleration, attack range, health, and burst damage in exported tuning values.
- Avoid heavy defensive logic or long windups unless the task explicitly asks for them.
- Preserve simple combat flow so the enemy remains dangerous through speed rather than complexity.