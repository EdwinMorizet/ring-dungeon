---
description: "Use when creating, moving, or refactoring scripts to keep the domain-first + role-folder layout consistent across autoload managers and RefCounted contracts."
applyTo: "scripts/**/*.gd, project.godot"
---

# Script Folder Structure Conventions

Use a domain-first folder layout under `scripts/`, then split each domain by role.

## Domain Layout

For each domain (for example inventory, spells, enemies, player, merchant, dungeon), prefer:

- `scripts/<domain>/managers/`: autoload-facing managers and orchestrators.
- `scripts/<domain>/contracts/`: typed `RefCounted` runtime payload/data contracts.
- `scripts/<domain>/resources/`: `Resource` scripts and config helper scripts.
- `scripts/<domain>/runtime/`: non-autoload gameplay runtime logic, generators, calculators.
- `scripts/<domain>/debug/`: deterministic samplers and debug-only runners.

Legacy top-level domain scripts remain allowed during migration but new files should use role folders.

## Autoload Rules

- Keep one entrypoint script per autoload singleton.
- If an autoload script path changes, update `project.godot` `[autoload]` paths in the same change.
- Keep autoload scripts thin and delegate logic to runtime/services/contracts where possible.

## RefCounted Contract Rules

- Any runtime cross-system payload should be represented as typed `RefCounted` contract classes under `contracts/`.
- Avoid ad hoc `Dictionary` contracts for gameplay systems.
- Engine-returned dictionaries are allowed only at boundaries and must be converted immediately.

## Move/Refactor Safety

When moving scripts between folders:

1. Update all `preload(...)` and `load(...)` path references.
2. Update any scene script paths that point to moved scripts.
3. Run diagnostics and launch smoke checks before finalizing.
4. Do not silently change gameplay defaults while reorganizing files.
