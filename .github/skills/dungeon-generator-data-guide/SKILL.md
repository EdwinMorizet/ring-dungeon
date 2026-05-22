---
name: dungeon-generator-data-guide
description: 'Explain how to use and read data from the Godot dungeon generator. Use for architecture walkthroughs, runtime integration, consuming layout dictionaries, and spawn-marker usage in scripts.'
argument-hint: 'What do you need to read or use from dungeon generation output?'
user-invocable: true
disable-model-invocation: false
---

# Dungeon Generator Data Guide

## What This Skill Produces

This skill produces implementation-focused guidance for using dungeon generation output in the current Godot project.

Expected outputs:
- A map of available generation fields and their meaning.
- How `DungeonFloorConfig` resource values feed generator and builder parameters.
- How to read each field in code.
- How to use spawn markers for player/enemy/chest/exit systems.
- Runtime/editor lifecycle notes for safe usage.
- Debug checks for deterministic and structural validation.

## When to Use

Use this skill when the user asks to:
- Explain how dungeon generation works in this project.
- Read data from the generator layout dictionary.
- Integrate player/enemy/chest spawning with generated metadata.
- Understand regenerate behavior in editor vs runtime.

## Procedure

1. Identify the data producer and consumer flow.
- Config source: `DungeonFloorConfig` resource stores selected tuning fields.
- Producer: `DungeonGenerator.generate(config.seed, params)` returns layout dictionary.
- Consumer: `DungeonFloorController.regenerate_now()` passes layout to `DungeonBuilder3D.build(...)`.

2. Enumerate layout dictionary fields and intended use.
- `grid`, `width`, `height`: floor/wall tile topology.
- `rooms`: room list, each with `rect`, `center`, and `metadata`.
- `edges`, `mst_edges`, `corridor_edges`: generation graph artifacts.
- `start_room_index`, `exit_room_index`: primary progression anchors.
- `spawn_markers`: grouped spawn points (`player_start`, `enemy`, `chest_candidate`, `floor_exit`).
- `stats`: generation diagnostics and sanity values.

3. Explain room metadata contract.
- Each room can include boolean flags:
- `is_player_start`
- `is_floor_exit`
- `is_enemy_room`
- `is_chest_candidate`
- Explain how these relate to spawn marker groups and scene marker nodes.

4. Explain scene outputs from builder.
- `GeneratedDungeon` root under floor controller.
- `FloorTiles` and `WallTiles` for geometry.
- `SpawnMarkers` hierarchy with grouped marker nodes:
- `PlayerStartMarkers`
- `EnemySpawnMarkers`
- `ChestCandidateMarkers`
- `FloorExitMarkers`

4.1 Floor exit spawn integration details.
- Marker source: use `spawn_markers.floor_exit` first; fallback path is room metadata with `is_floor_exit=true`.
- Builder path: `DungeonBuilder3D._spawn_floor_exit_visuals(...)` locates `FloorExit_0` (or first `FloorExit_*`) and instances `res://scenes/dungeon/floor_exit_trigger.tscn` at that marker transform.
- Runtime node contract: instantiated node must be named `FloorExitTrigger` so `DungeonFloorController._connect_floor_exit_trigger()` can find it under generated content.
- Signal contract: trigger script emits `exit_reached`; controller listens and forwards progression via `complete_floor_exit` (or regenerates as fallback).
- Ownership/persistence: when regenerating in editor, assign owner recursively to the instanced trigger subtree so scene-authored children remain visible/persistable.
- Visual source of truth: floor-exit visuals should be authored in `scenes/dungeon/floor_exit_trigger.tscn`; avoid rebuilding exit VFX procedurally in builder unless explicitly required.

5. Provide usage snippets when requested.
- Show how to pull marker nodes by group and instantiate gameplay scenes at those transforms.
- Show safe null/empty checks when a marker group has no children.

6. Cover editor/runtime branching.
- Editor trigger path: inspector `regenerate` and `clear_current_floor` toggles.
- Runtime path: generation in `_ready`.
- If auto-random seed is enabled, mention `config.seed` mutation before regenerate.

7. Explain config access pattern.
- Show that the controller uses a null-safe accessor (`_get_config`) and reads all selected tuning fields from the resource.
- Clarify split of responsibility: config resource for generation/build numbers, controller exports for workflow toggles.

8. Validate with checks.
- Same seed should produce same marker positions.
- Border ring should remain wall.
- Exactly one player start marker and one floor exit marker should exist.
- Enemy/chest candidate counts should be coherent with room count and configured ratios.
- Generated scene should contain exactly one node named `FloorExitTrigger` under `GeneratedDungeon` after each regenerate.
- `FloorExitTrigger` should sit at the selected floor-exit marker position (with expected Y offset defined by the trigger scene itself).
- Entering trigger with a player-group body should emit `exit_reached` once per floor instance.

## Decision Rules

- If user asks for high-level understanding: summarize pipeline first, then data contracts.
- If user asks for implementation help: prioritize concrete dictionary keys, node paths, and code snippets.
- If user asks for bugs: start from `stats`, marker counts, and scene hierarchy validation.
- Treat `1 player start` and `1 floor exit` marker as hard invariants unless the user explicitly asks to change generator rules.

## Completion Criteria

A response is complete when it includes:
- Data dictionary field meanings.
- Room metadata interpretation.
- Marker hierarchy and usage guidance.
- Runtime vs editor behavior implications.
- At least one practical verification checklist.
- Explicit invariant check: exactly one player start marker and exactly one floor exit marker.
