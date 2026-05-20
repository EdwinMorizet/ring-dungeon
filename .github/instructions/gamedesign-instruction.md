---
applyTo: "**/*.gd"
---

# Game Design Instructions

Use these instructions when generating gameplay, systems, and content code for this project.

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

Implement a backpack-less equipment system with exactly 8 finger slots:

- Right hand: 4 offensive `Rings`.
- Left hand: 4 defensive/stat `Bands`.
- Rule: only one item per finger slot.
- Use Godot `Resource` scripts for item definitions.

### Rings (Right Hand, Offensive)

- Affect Fireball behavior and physics.
- Visual language: jagged or bulky materials (iron, brass, obsidian).
- Drop aura colors: warm palette (red, orange, yellow).
- Include meaningful trade-offs (example: more projectiles with higher mana cost and lower damage).
- Allow stacking of identical rings across slots, but tune projectile behavior to stay performant.

### Bands (Left Hand, Defensive/Stats)

- Affect player stats (max health, max mana, displacement speed, shield).
- Visual language: smooth or engraved materials (silver, bone, crystal).
- Drop aura colors: cool palette (blue, green, purple).
- Can be pure buffs or trade-off based.

## Loot Interaction Rules

When the player interacts with a dropped `Ring` or `Band` (`Area3D`), present an immediate choice:

- Equip: place into an empty slot of the matching hand.
- Swap: if all 4 relevant slots are full, select one equipped item to replace.
- On swap, drop the replaced item back to the floor immediately.

## Merchant Room Rules

Treat the Merchant Room as a safe inter-floor hub and support:

- Standard shop: spend gold for healing, mana recovery, and standard Rings/Bands.
- Premium trades: spend diamonds for rare high-tier Rings.
- Blood magic trades: exchange permanent stats for powerful items.
- Barter: trade one currently equipped Ring/Band for a new random item.

## Preferred Godot Architecture

- `Player` (`CharacterBody3D`): manages stats, currencies, and owns `RingManager`.
- `RingManager` (`Node`): stores two arrays (size 4 each) of item resources; recalculates derived stats and Fireball parameters on equip/swap.
- `Fireball` (`RigidBody3D` or `Area3D`): receives injected runtime parameters (speed, size, collision behavior, spawn count).
- `Item` pickups (`Area3D`): include mesh and `Label3D` showing effects and trade-offs.

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

## Enemy Design Requirements

General rules:

- Spawn enemies in rooms.
- Allow pursuit through corridors after aggro.
- On death, support drops from: AP, Gold, MP, Keys, HP.

Enemy roster requirements:

- Skeleton: basic melee grunt.
- Skeleton Archer: basic ranged attacker.
- Cloaked Wizard: advanced caster with `Ghost Form`, `Teleport`, and `Fireball`.
- Bones Spider: fast swarmer with small hitbox.
- Necromancer: summoner that raises Skeletons, Skeleton Archers, and Bones Spiders.
- Bones Golem: slow heavy unit with telegraphed ground slam or forward charge.

## Dungeon Interactables

- Treasure chests: primarily room-based; may require keys; major source of high-tier Rings/Bands, diamonds, and large gold rewards.
- Traps: place in rooms and corridors; must damage both player and enemies to enable tactical baiting.

## Implementation Guidance For Copilot

- Prefer modular scripts with explicit responsibilities.
- Keep data-driven tuning values in resources and exported properties.
- Preserve deterministic or seed-driven generation where feasible.
- Favor clear function naming for generation phases (`generate_cells`, `separate_cells`, `build_mst`, etc.).
- When adding new systems, keep compatibility with the floor -> merchant -> floor progression.