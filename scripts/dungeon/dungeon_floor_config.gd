# Stores tunable parameters used to generate and build a dungeon floor.
extends Resource
class_name DungeonFloorConfig

# Seed value used by floor layout generation.
@export var generation_seed: int = 1
# Dungeon grid width in generation cells.
@export var width: int = 160
# Dungeon grid height in generation cells.
@export var height: int = 160
# Number of initial room-candidate cells to generate.
@export var cell_count: int = 150
# Radius from origin used for initial room placement sampling.
@export var spawn_radius: float = 52.0
# Iteration count for room separation relaxation.
@export var separation_iterations: int = 200
# Minimum room dimension used by room candidate generation.
@export var min_room_size: float = 12.0
# Minimum room area threshold kept after culling.
@export var room_area_threshold: float = 120.0
# Fraction of top candidate rooms kept for graph building.
@export var room_keep_ratio: float = 0.45
# Chance to add loop edges after minimum spanning tree build.
@export var loop_percent: float = 0.15
# Fraction of room candidates used for chest spawn picks.
@export var chest_candidate_ratio: float = 0.3
# Minimum patrol points generated in each room patrol net.
@export var patrol_nodes_per_room_min: int = 2
# Maximum patrol points generated in each room patrol net.
@export var patrol_nodes_per_room_max: int = 4
# Minimum distance in generation tiles between patrol points and room walls.
@export var patrol_point_padding: float = 1.2
# Angular jitter used when distributing patrol points in room patrol nets.
@export var patrol_point_jitter: float = 0.35
# Size in world units represented by one generation tile.
@export var tile_size: float = 2.0
# Height in world units used for generated walls.
@export var wall_height: float = 3.0
# Thickness in world units used for generated floor meshes.
@export var floor_thickness: float = 0.2
