# Stores tunable parameters used to generate and build a dungeon floor.
extends Resource
class_name DungeonFloorConfig

# Default player scene spawned for runtime floors.
const PlayerScene: PackedScene = preload("res://scenes/player/player.tscn")
# Default enemy scene fallback used by EnemySpawnManager.
const EnemyScene: PackedScene = preload("res://scenes/enemies/enemy_basic.tscn")
# Merchant room scene used during merchant transitions.
const MerchantRoomScene: PackedScene = preload("res://scenes/merchant/merchant_room.tscn")
# Chest scene spawned at generated chest candidate markers.
const ChestScene: PackedScene = preload("res://scenes/items/chest_interactable.tscn")

# Relation: Consumed by DungeonFloorController and forwarded to DungeonGenerator and DungeonBuilder3D.
# Relation: Default instance is wired through resources/dungeon/default_floor_config.tres.

# Seed value used by floor layout generation.
@export var generation_seed: int = 1
# Dungeon grid width in generation cells.
@export var width: int = 160
# Dungeon grid height in generation cells.
@export var height: int = 160
# Number of initial room-candidate cells to generate.
@export var cell_count: int = 150

@export var room_min_size: int = 10
@export var room_max_size: int = 40
@export var room_size_deviation: int =  6

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
# Enables MultiMesh rendering for generated tiles.
@export var use_multimesh: bool = true
# Enables one merged floor collider for the generated floor bounds.
@export var create_floor_collision: bool = true
# Randomizes generation seed on manual regenerate in editor/runtime.
@export var auto_randomize_seed_on_regenerate: bool = false
# Scene used to spawn or ensure the player instance.
@export var player_scene: PackedScene = PlayerScene
# Fallback spawn position when player start marker is unavailable.
@export var player_spawn_fallback: Vector3 = Vector3(0.0, 3.0, 0.0)
# Vertical offset applied above player marker for spawn safety.
@export var player_spawn_height_offset: float = 1.2
# Default enemy scene passed to spawn manager as fallback.
@export var enemy_scene: PackedScene = EnemyScene
# Fallback enemy spawn position for spawn manager safety cases.
@export var enemy_spawn_fallback: Vector3 = Vector3(8.0, 2.5, 8.0)
# Scene used to instantiate the merchant room controller.
@export var merchant_room_scene: PackedScene = MerchantRoomScene
# Scene used to instantiate chest on dungeon floors.
@export var chest_scene: PackedScene = ChestScene
