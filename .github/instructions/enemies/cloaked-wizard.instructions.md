---
description: "Use when editing Cloaked Wizard enemy scripts or scenes."
applyTo: "scripts/enemies/enemy_cloaked_wizard.gd, scenes/enemies/enemy_cloaked_wizard.tscn"
---

# Cloaked Wizard Enemy Guidelines

- Keep Cloaked Wizard behavior explicit and phase-based.
- Treat Ghost Form, Teleport, and Fireball as the core kit and keep their timing easy to tune.
- Prefer clear state transitions over abstract AI behavior trees.
- Keep cast time, cooldown, teleport frequency, fireball range, and survivability as exported tuning values.
- Make the Wizard prioritize survival and tactical repositioning rather than standing still in melee range.
- Preserve a simple combat loop with readable spell windows and clean death handling.