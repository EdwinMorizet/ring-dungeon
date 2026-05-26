# Defines configurable parameters for the enemy spawn manager autoload.
extends Resource
class_name EnemySpawnManagerConfig

# Base enemies spawned before progression scaling is applied.
@export var base_enemy_count: int = 20
# Number of progression steps required to add one extra enemy.
@export var progression_step_for_extra_enemy: int = 2
# Hard cap for total enemies selected for one floor.
@export var max_enemy_count: int = 100
# Minimum enemies attempted for each selected spawn marker.
@export var min_enemies_per_spawn_point: int = 1
# Maximum enemies attempted for each selected spawn marker.
@export var max_enemies_per_spawn_point: int = 10
# Radius around a spawn marker where random spawn points are sampled.
@export var spawn_circle_radius: float = 10
# Number of spawn-position attempts before giving up for one spawn.
@export var spawn_position_attempts: int = 14
# Physics mask used for floor projection and spawn clearance checks.
@export_flags_3d_physics var spawn_validation_collision_mask: int = 1
# Vertical offset above candidate point for floor raycast start.
@export var floor_probe_height: float = 2.5
# Vertical depth below candidate point for floor raycast end.
@export var floor_probe_depth: float = 4.5
# Radius used for overlap check at a candidate spawn point.
@export var spawn_clearance_radius: float = 0.75
# Height offset used by the spawn clearance overlap sphere.
@export var spawn_clearance_height: float = 1.0
# Minimum distance between player spawn and enemy spawn marker.
@export var min_spawn_distance_from_player: float = 8.0
# Allows spawn near fallback point if no marker-based spawn succeeds.
@export var allow_fallback_spawn: bool = true
