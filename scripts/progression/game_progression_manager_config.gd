# Defines configurable phase names and floor display values for progression.
extends Resource
class_name GameProgressionManagerConfig

# Display value shown for the first dungeon floor at progression index 0.
@export var start_floor_display: int = -10
# Phase name used while the run is in dungeon gameplay.
@export var dungeon_phase: StringName = &"dungeon"
# Phase name used while the run is in merchant-room gameplay.
@export var merchant_phase: StringName = &"merchant"
