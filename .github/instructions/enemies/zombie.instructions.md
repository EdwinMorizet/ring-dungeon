---
description: "Use when editing Zombie enemy scripts or scenes."
applyTo: "scripts/enemies/enemy_zombie.gd, scenes/enemies/enemy_zombie.tscn"
---

# Zombie Enemy Guidelines

- Keep Zombie behavior simple and readable.
- Make Zombie feel like a slow, numerous roaming threat with a small field of vision.
- Prefer random roaming before aggro and direct pursuit after aggro.
- Keep attack logic short and easy to tune with exported values such as speed, sight range, attack range, and damage.
- Preserve deterministic movement hooks when roaming depends on floor seed or patrol fallback data.
- Avoid spellcasting, complex retreat logic, or multi-phase state machines unless explicitly requested.