---
description: "Use these instructions when generating gameplay, systems, and content code for this project."
applyTo: "**/*.gd, **/*.tscn, **/*.tres"
---

# Game Design Instructions

Use these instructions when generating gameplay, systems, and content code for this project.

## GODOT executables paths

Try this paths
- "C:\Users\maste\Documents\DEV\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
- "C:\Users\edwin\Documents\DEV\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"

## Instruction Map And Precedence

Use this file as the broad gameplay umbrella. For Rings/Bands work, defer to specialized instruction files first.

- Primary Rings/Bands gameplay source:
	- `.github/instructions/rings-bands-mechanics.instructions.md`
- Numeric rarity/affix and economy constants:
	- `.github/instructions/rarity-affix-table.instructions.md`
- Deterministic tests, regression checks, and debug hooks:
	- `.github/instructions/rings-bands-testing.instructions.md`
- Tooltip and inventory item presentation:
	- `.github/instructions/rings-bands-tooltip-ui.instructions.md`
- Inventory architecture and slot flow integration:
	- `.github/instructions/inventory-system.instructions.md`
- Chest interaction, loot rolling, and currency pickup behavior:
	- `.github/instructions/chest-system.instructions.md`

When guidance overlaps:

1. Follow the most specific file by scope (`applyTo`) and topic.
2. For Rings/Bands mechanics, prefer the specialized Rings/Bands files over this umbrella file.
3. Use this file for high-level loop, pacing, and world/system intent.

## Project Context

- Project: Untitled Wizard FPS Dungeon Crawler
- Engine: Godot 4.6
- Genre: FPS, Dungeon Crawler, Roguelite
- Graphics : 3D

## Core Loop Requirements

Implement gameplay around strict floor-by-floor ascension:

1. Start each run segment by spawning the player on a newly generated dungeon floor.
2. Require exploration, combat (player uses Fireball), and loot decisions (Rings and Bands).
3. Place exactly one floor exit as the objective.
4. Route the player to a Merchant Room after exiting a floor.
5. Transition from Merchant Room to the next floor until near-surface endgame.
6. Gate final surface exit behind a boss encounter in a dedicated arena room.

## Player Stats And Currencies

Use `CharacterBody3D` as the player root and track at minimum:

- Health (`HP`): death occurs at `0`.
- Mana (`MP`): consumed by Fireball, modified by equipment.
- Displacement speed: base movement speed.
- Armor or Action Points (`AP`): secondary survivability stat.

Track currencies:

- Gold: standard merchant purchases.
- Diamonds: premium or high-tier purchases/upgrades.
- Keys: consumable unlocks for chests or shortcut doors.

## Eight-Rings Equipment System

Maintain the high-level equipment fantasy and progression:

- Exactly 8 finger slots split between offensive rings and defensive bands.
- Items should support meaningful synergies and trade-offs.
- Item generation should be rarity-driven and floor-depth aware.

Do not duplicate low-level mechanics here. For exact slot rules, affix domains, stacking math, rarity constants, and runtime behaviors, use:

- `.github/instructions/rings-bands-mechanics.instructions.md`
- `.github/instructions/rarity-affix-table.instructions.md`

## Loot Interaction Rules

Keep loot interaction immediate and run-flow friendly:

- Equip into a valid empty slot when possible.
- Offer swap when relevant slots are full.
- Keep world-drop behavior consistent so the replaced item remains interactable.

For concrete slot-validation and drop-flow rules, defer to:

- `.github/instructions/inventory-system.instructions.md`
- `.github/instructions/rings-bands-mechanics.instructions.md`

## Merchant Room Rules

Treat the Merchant Room as a safe inter-floor hub and support:

- Standard shop: spend gold for healing, mana recovery, and standard Rings/Bands.
- Premium trades: spend diamonds for rare high-tier Rings.
- Blood magic trades: exchange permanent stats for powerful items.
- Barter: trade one currently equipped Ring/Band for a new random item.

For item-value tuning and rarity economy balance, defer to:

- `.github/instructions/rarity-affix-table.instructions.md`

## Preferred Godot Architecture

- `Player` (`CharacterBody3D`): owns movement/combat input and derived stat refresh triggers.
- `Equipment/Inventory manager` (`Node` or autoload): owns slot state, equip/swap transitions, and compiled modifier aggregation.
- `Fireball` (`RigidBody3D` or `Area3D`): consumes runtime shot parameters built from aggregated equipment effects.
- `Item` pickups (`Area3D`): provide interaction hooks and presentation metadata.

For UI rendering and tooltip rules, defer to:

- `.github/instructions/rings-bands-tooltip-ui.instructions.md`

## Procedural Dungeon Generation (TinyKeep Style)

Use a dedicated `DungeonGenerator` script for 2D generation, then build 3D level geometry (for example via `GridMap` or procedural mesh/CSG).

Required pipeline:

1. Cell generation: create many `Rect2` cells (for example around 150) within a circular radius using normal-distribution-biased sizes and max aspect-ratio limits.
2. Separation: iteratively resolve rectangle overlaps with simple 2D steering until no intersections remain.
3. Room designation: classify sufficiently large cells as rooms; keep smaller cells as corridor candidates.
4. Delaunay graph: triangulate room centers using `Geometry2D.delaunay_2d`.
5. Connectivity: build an MST (for example with `AStar2D`) to guarantee full reachability.
6. Looping: re-add about 15% of non-MST Delaunay edges to reduce linearity.
7. Corridors: carve L-shaped paths between connected rooms and fill micro-gaps where needed.
8. Patrol nets: generate per-room patrol points and connect rooms with patrol links from MST edges only.

## Enemy Design Requirements

Enemy implementation details are split into the enemy instruction family under `.github/instructions/enemies/`.
Use the shared umbrella in `.github/instructions/enemies-simple.instructions.md` for generic rules, then follow the matching roster-specific file for the creature you are editing.

General rules:

- Spawn enemies in rooms.
- Allow pursuit through corridors after aggro.
- Allow follow patrols nodes.
- On death, support drops from: AP, Gold, MP, Keys, HP.
- Keep patrol behavior deterministic from floor seed so repeated runs with the same seed preserve patrol routes.
- Prioritize chase over patrol once aggro is active; patrol is a pre-aggro/default movement mode.

Enemy roster requirements:

- Zombie: random roaming, small fov of vision, slow, numerous.
- Skeleton: basic melee grunt, follow patrols nodes, good fov of vision.
- Skeleton Archer: basic ranged attacker, retreat from player, follow patrols nodes.
- Cloaked Wizard: advanced caster with `Ghost Form`, `Teleport`, and `Fireball`.
- Bones Spider: fast swarmer with small hitbox, random roaming, fast, hit and run.
- Necromancer: summoner that raises already dead Skeletons, Skeleton Archers, zombie, and Bones Spiders, flee from player.
- Bones Golem: slow heavy unit with telegraphed ground slam or forward charge.

## Dungeon Interactables

- Treasure chests: primarily room-based; may require keys; major source of high-tier Rings/Bands, diamonds, and large gold rewards.
- Traps: place in rooms and corridors; must damage both player and enemies to enable tactical baiting.

Current implementation note:

- Chests are rectangle placeholders that open with `interact` (`E`) when player is in range.
- Loot outcomes currently include: gold, diamonds, ring/band items, or empty.
- Gold and diamonds use collision pickups, while ring/band items remain inventory world items.

## Implementation Guidance For Copilot

- Prefer modular scripts with explicit responsibilities.
- Keep data-driven tuning values in resources and exported properties.
- Preserve deterministic or seed-driven generation where feasible.
- Favor clear function naming for generation phases (`generate_cells`, `separate_cells`, `build_mst`, etc.).
- When adding new systems, keep compatibility with the floor -> merchant -> floor progression.