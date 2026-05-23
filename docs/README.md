# Documentation Index

This folder contains implementation notes, setup guides, and validation references for the main gameplay systems in the project.

## Enemy Systems

1. [docs/enemy-spawn-manager.md](enemy-spawn-manager.md)
   Explains how floor enemy placement works, how spawn markers and patrol data are discovered, and how to tune spawn density and validation.
2. [docs/enemy-manager.md](enemy-manager.md)
   Explains enemy type resolution, weighted progression composition, scene-path mapping, and the live-enemy registry APIs.

## Rings and Bands

1. [docs/rarity-probability.md](rarity-probability.md)
   Explains rarity roll weights and how rarity probabilities are tuned.
2. [docs/rings-bands-stat-mechanisms.md](rings-bands-stat-mechanisms.md)
   Explains the full stat pipeline from affix generation through runtime aggregation.
3. [docs/rings-bands-debug-commands.md](rings-bands-debug-commands.md)
   Lists the debug shortcuts and callable helper methods for Rings/Bands validation.
4. [docs/rings-bands-smoke-checklist.md](rings-bands-smoke-checklist.md)
   Provides a fast in-editor checklist for validating Rings/Bands behavior.

## Suggested Reading Order

### If you are working on enemies

1. [docs/enemy-spawn-manager.md](enemy-spawn-manager.md)
2. [docs/enemy-manager.md](enemy-manager.md)

### If you are working on item generation or balance

1. [docs/rarity-probability.md](rarity-probability.md)
2. [docs/rings-bands-stat-mechanisms.md](rings-bands-stat-mechanisms.md)
3. [docs/rings-bands-debug-commands.md](rings-bands-debug-commands.md)
4. [docs/rings-bands-smoke-checklist.md](rings-bands-smoke-checklist.md)

## Notes

1. The enemy docs are designed as a pair:
   - `EnemySpawnManager` covers where enemies appear.
   - `EnemyManager` covers what enemy types appear.
2. The Rings/Bands docs split balance rules, runtime mechanics, and validation steps so each document stays focused.
