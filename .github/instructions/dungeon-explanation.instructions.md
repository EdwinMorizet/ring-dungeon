---
description: "Use when the user asks how dungeon generation works, requests architecture walkthroughs, or asks for procedural generation details in this Godot project."
name: "Dungeon Generation Explanation Style"
applyTo: "scripts/dungeon/*.gd"
---

# Dungeon Generation Explanation Guidelines

Use this instruction when explaining the dungeon generation system.

## Explanation Goal

- Explain the current implementation clearly enough that a developer can modify or debug it.
- Prefer concrete references to project scripts and data flow over generic procedural generation theory.

## Required Coverage

When asked to explain dungeon generation, cover all of these:

1. TinyKeep-style pipeline stages in order:
- cell generation
- overlap separation
- room designation
- Delaunay triangulation
- MST connectivity
- loop-edge restoration
- corridor carving

2. Data flow between scripts:
- `dungeon_floor_controller.gd` triggers generation
- `dungeon_generator.gd` builds 2D layout + room metadata
- `dungeon_graph.gd` builds graph edges / MST / loops
- `dungeon_builder_3d.gd` converts layout to 3D nodes and spawn markers

3. Runtime vs editor behavior:
- manual regenerate toggle behavior
- clear-current-floor behavior
- auto-randomize-seed behavior
- generation in runtime `_ready`

4. Structural constraints and outcomes:
- one-tile permanent wall border
- deterministic output from seed
- room-role metadata (player start, enemy, chest candidate, floor exit)

5. Practical tuning knobs:
- map size, cell count, spawn radius, room thresholds
- loop ratio and chest candidate ratio
- rendering/collision options (MultiMesh and collision toggles)

## Response Structure

Use this order for explanations:

1. High-level summary (2-4 lines)
2. Pipeline stage-by-stage walkthrough
3. Script responsibilities and key functions
4. Inspector parameters and how they affect generation
5. Common failure/debug checks

## Quality Rules

- Be explicit about what is implemented now vs what is future/optional.
- Use concrete examples from current files and node names.
- If asked for "in detail", include both algorithmic reasoning and in-project implementation details.
- If behavior depends on random seed, call that out explicitly.
- Default tone: English technical, implementation-focused.
