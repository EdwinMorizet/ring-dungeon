# Stores tunable parameters used to generate and build a dungeon floor.
extends Resource
class_name DungeonFloorConfig

# Relation: Consumed by DungeonFloorController and forwarded to DungeonGenerator and DungeonBuilder3D.
# Relation: Default instance is wired through resources/dungeon/default_floor_config.tres.

# Seed value used by floor layout generation.
@export var generation_seed: int = 1
# Randomizes generation seed on manual regenerate in editor/runtime.
@export var auto_randomize_seed_on_regenerate: bool = false
@export_group("Rooms")
# Number of initial room-candidate cells to generate.
@export var cell_count: int = 150
# Fixed number of special-room spawn slots evaluated per floor.
@export var special_room_target_count: int = 8
# Floor-linked weighted special-room pool list used during special-room assignment.
@export var special_room_floor_pool_list: DungeonSpecialRoomFloorPoolList
# Margin in tiles/pixels for separation
@export var separation_margin: int = 4
# Radius from origin used for initial room placement sampling.
@export var spawn_radius: float = 52.0
# Iteration count for room separation relaxation.
@export var separation_iterations: int = 200
# Fraction of top candidate rooms kept for graph building.
@export var room_keep_ratio: float = 0.5
# Chance to add loop edges after minimum spanning tree build.
@export var loop_percent: float = 0.15
# Chance for a discarded standard cell to be restored as a room when a carved corridor crosses it.
@export var room_keep_corridor_overlap_chance: float = 0.35
# Fraction of room candidates used for chest spawn picks.
@export var chest_candidate_ratio: float = 0.3
@export_group("Patrols")
# Minimum patrol points generated in each room patrol net.
@export var patrol_nodes_per_room_min: int = 2
# Maximum patrol points generated in each room patrol net.
@export var patrol_nodes_per_room_max: int = 4
# Minimum distance in generation tiles between patrol points and room walls.
@export var patrol_point_padding: float = 1.2
# Angular jitter used when distributing patrol points in room patrol nets.
@export var patrol_point_jitter: float = 0.35
# Size in world units represented by one generation tile.
@export_group("Mesh")
@export var tile_size: float = 2.0
# Height in world units used for generated walls.
@export var wall_height: float = 3.0
# Scene used to spawn or ensure the player instance.
@export_group("Scenes")
@export var player_scene: PackedScene
# Default enemy scene passed to spawn manager as fallback.
@export var enemy_scene: PackedScene 
# Scene used to instantiate the merchant room controller.
@export var merchant_room_scene: PackedScene
# Scene used to instantiate chest on dungeon floors.
@export var chest_scene: PackedScene 
