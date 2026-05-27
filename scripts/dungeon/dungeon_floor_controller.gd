# Orchestrates floor generation, building, and runtime floor state transitions.
@tool
extends Node3D
class_name DungeonFloorController

signal floor_generated
signal floor_cleared

# Relation: Owns end-to-end flow across DungeonFloorConfig, DungeonGenerator, DungeonBuilder3D, FloorExitTrigger,
# EnemySpawnManager, InventoryManager, MerchantManager, and GameProgressionManager.

# Inspector-configured floor generation/build resource.
@export var config: DungeonFloorConfig = DungeonFloorConfig.new()
# RNG used when generating random seeds from this controller.
var _seed_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Root node created by DungeonBuilder3D for current generated floor.
var _generated_root: Node3D
# Runtime player instance managed by this controller.
var _player_instance: CharacterBody3D
# Runtime merchant room instance managed by this controller.
var _merchant_room_instance: MerchantRoomController
# Runtime floor config override provided by progression flow.
var _progression_config_override: DungeonFloorConfig
# Runtime display floor index used by progression/UI logic.
var _runtime_floor_display: int = -10
# Runtime progression index used for spawn and loot scaling.
var _runtime_progression_index: int = 0
# Cached autoload reference for EnemySpawnManager node.
var _enemy_spawn_manager: Node
# Seed used for current runtime-generated floor.
var _runtime_generation_seed: int = 0
# Last generated layout payload from DungeonGenerator.
var _runtime_layout: DungeonLayoutData = null

# Generates an initial floor in runtime unless progression manager takes ownership.
func _ready() -> void:
	if not Engine.is_editor_hint():
		if not _has_progression_manager():
			regenerate_now()

# Starts a progression-managed floor using provided config and progression metadata.
func start_progression_floor(display_floor: int, progression_index: int, floor_config: DungeonFloorConfig) -> void:
	_runtime_floor_display = display_floor
	_runtime_progression_index = progression_index
	_progression_config_override = floor_config
	_hide_merchant_room()
	regenerate_now()

# Enters merchant room state, repositions player, and configures merchant session.
func enter_merchant_room() -> void:
	_clear_generated()
	_ensure_player_spawned()
	var floor_config: DungeonFloorConfig = _get_config()
	if floor_config.merchant_room_scene == null:
		return
	if _merchant_room_instance == null or not is_instance_valid(_merchant_room_instance):
		var room_node: Node = floor_config.merchant_room_scene.instantiate()
		if room_node is MerchantRoomController:
			_merchant_room_instance = room_node as MerchantRoomController
			add_child(_merchant_room_instance)
			_merchant_room_instance.merchant_exit_reached.connect(_on_merchant_exit_reached)
		else:
			room_node.queue_free()
			return

	_merchant_room_instance.visible = true
	_merchant_room_instance.reset_for_entry()
	_merchant_room_instance.configure_session(_runtime_progression_index, _runtime_generation_seed)
	var merchant_spawn: Vector3 = _merchant_room_instance.get_player_spawn_position()
	_player_instance.global_position = merchant_spawn
	_player_instance.velocity = Vector3.ZERO

# Rebuilds the full floor pipeline: generate layout, build nodes, then spawn systems.
func regenerate_now() -> void:
	_clear_generated()
	var floor_config := _get_config()
	var generation_seed: int = floor_config.generation_seed
	if not Engine.is_editor_hint():
		generation_seed = _next_random_seed()
		floor_config.generation_seed = generation_seed
	_runtime_generation_seed = generation_seed
	var generator: DungeonGenerator = DungeonGenerator.new()
	var layout: DungeonLayoutData = generator.generate(generation_seed, floor_config, null, _runtime_progression_index)
	_runtime_layout = layout
	var builder: DungeonBuilder3D = DungeonBuilder3D.new()
	var editor_owner: Node = null
	if Engine.is_editor_hint() and get_tree() != null:
		editor_owner = get_tree().edited_scene_root
	_generated_root = builder.build(self, layout, _build_builder_params(), editor_owner)
	_spawn_chests_for_floor(generation_seed)
	_spawn_or_reposition_player()
	_spawn_enemies_for_floor(generation_seed)
	_connect_floor_exit_trigger()
	floor_generated.emit()

# Returns the current runtime progression index for external systems.
func get_runtime_progression_index() -> int:
	return _runtime_progression_index

# Returns the generation seed used for the active floor.
func get_current_floor_seed() -> int:
	return _runtime_generation_seed

# Returns the currently active floor config resolved for this controller context.
func get_active_floor_config() -> DungeonFloorConfig:
	return _get_config()

# Returns generated floor root created by the latest build pass.
func get_generated_root() -> Node3D:
	return _generated_root

# Returns the latest dungeon layout payload captured from generation.
func get_runtime_layout() -> DungeonLayoutData:
	return _runtime_layout

# Clears generated floor content through a public orchestration API.
func clear_generated_now() -> void:
	_clear_generated()


# Builds typed parameters consumed by DungeonBuilder3D.build.
func _build_builder_params() -> DungeonBuilderParams:
	var floor_config := _get_config()
	var params: DungeonBuilderParams = DungeonBuilderParams.new()
	params.tile_size = floor_config.tile_size
	params.wall_height = floor_config.wall_height
	params.floor_thickness = floor_config.floor_thickness
	params.use_multimesh = floor_config.use_multimesh
	params.create_floor_collision = floor_config.create_floor_collision
	return params

# Resolves active floor config, preferring runtime progression override when applicable.
func _get_config() -> DungeonFloorConfig:
	if not Engine.is_editor_hint() and _progression_config_override != null:
		return _progression_config_override
	if config == null:
		config = DungeonFloorConfig.new()
	return config

# Removes generated floor content and clears spawned runtime entities/state.
func _clear_generated() -> void:
	if _generated_root != null and is_instance_valid(_generated_root):
		_generated_root.queue_free()
		_generated_root = null
	_runtime_layout = null
	if not Engine.is_editor_hint() and is_inside_tree():
		InventoryManager.clear_world_items()
	_ensure_enemy_spawn_manager()
	if _enemy_spawn_manager != null and is_instance_valid(_enemy_spawn_manager):
		EnemySpawnManager.clear_spawned_enemies()
	floor_cleared.emit()

# Hides merchant room and forces merchant UI/session closure.
func _hide_merchant_room() -> void:
	if _merchant_room_instance != null and is_instance_valid(_merchant_room_instance):
		_merchant_room_instance.visible = false
	MerchantManager.close_shop()

# Ensures a runtime player instance exists under this controller.
func _ensure_player_spawned() -> void:
	var floor_config: DungeonFloorConfig = _get_config()
	if floor_config.player_scene == null:
		return
	if _player_instance != null and is_instance_valid(_player_instance):
		return
	var player_node: Node = floor_config.player_scene.instantiate()
	if player_node is CharacterBody3D:
		_player_instance = player_node as CharacterBody3D
		add_child(_player_instance)
	else:
		player_node.queue_free()

# Spawns player if needed and moves player to current floor start location.
func _spawn_or_reposition_player() -> void:
	_ensure_player_spawned()
	if _player_instance == null or not is_instance_valid(_player_instance):
		return

	var spawn_position: Vector3 = _find_player_spawn_position()
	_player_instance.global_position = spawn_position
	_player_instance.velocity = Vector3.ZERO

# Resolves player start marker position or falls back to configured spawn vector.
func _find_player_spawn_position() -> Vector3:
	var floor_config: DungeonFloorConfig = _get_config()
	if _generated_root != null and is_instance_valid(_generated_root):
		var marker_node: Node = _generated_root.find_child("PlayerStart_0", true, false)
		if marker_node is Marker3D:
			var marker: Marker3D = marker_node as Marker3D
			return marker.global_position + Vector3.UP * floor_config.player_spawn_height_offset
	return floor_config.player_spawn_fallback

# Returns a positive random seed value, initializing RNG state lazily.
func _next_random_seed() -> int:
	if _seed_rng.seed == 0:
		_seed_rng.randomize()
	return _seed_rng.randi_range(1, 2147483646)

# Requests EnemySpawnManager to spawn enemies for the generated floor.
func _spawn_enemies_for_floor(generation_seed: int) -> void:
	if Engine.is_editor_hint():
		return
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	var floor_config: DungeonFloorConfig = _get_config()
	if floor_config.enemy_scene == null:
		return
	if _player_instance == null or not is_instance_valid(_player_instance):
		return
	_ensure_enemy_spawn_manager()
	if _enemy_spawn_manager == null or not is_instance_valid(_enemy_spawn_manager):
		return
	var player_spawn_position: Vector3 = _find_player_spawn_position()
	EnemySpawnManager.spawn_enemies_for_floor(
		self,
		_generated_root,
		player_spawn_position,
		floor_config.enemy_scene,
		_runtime_progression_index,
		generation_seed,
		floor_config.enemy_spawn_fallback
	)

# Spawns deterministic chest interactables at selected chest candidate markers.
func _spawn_chests_for_floor(generation_seed: int) -> void:
	var floor_config: DungeonFloorConfig = _get_config()
	if Engine.is_editor_hint():
		return
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	if floor_config.chest_scene == null:
		return
	var marker_nodes: Array[Node] = _generated_root.find_children("ChestCandidate_*", "Marker3D", true, false)
	if marker_nodes.is_empty():
		return

	var chest_markers: Array[Marker3D] = []
	for marker_node: Node in marker_nodes:
		if marker_node is Marker3D:
			chest_markers.append(marker_node as Marker3D)
	if chest_markers.is_empty():
		return

	var desired_chest_count: int = clampi(1 + int(floor(float(_runtime_progression_index) / 4.0)), 1, 3)
	var spawn_count: int = mini(desired_chest_count, chest_markers.size())
	if spawn_count <= 0:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = max(1, abs(generation_seed ^ (_runtime_progression_index * 193)))
	for spawn_index: int in spawn_count:
		var marker_choice_index: int = rng.randi_range(0, chest_markers.size() - 1)
		var marker: Marker3D = chest_markers[marker_choice_index]
		chest_markers.remove_at(marker_choice_index)

		var chest_node: Node = floor_config.chest_scene.instantiate()
		if not chest_node is Node3D:
			chest_node.queue_free()
			continue
		var chest: ChestInteractable = chest_node as ChestInteractable
		chest.name = "ChestInteractable_%d" % spawn_index
		_generated_root.add_child(chest)
		chest.global_position = marker.global_position + Vector3.UP * 0.42
		var chest_seed: int = _build_chest_seed(generation_seed, marker.global_position, spawn_index)
		chest.configure(_runtime_progression_index, generation_seed, chest_seed)

# Builds a deterministic per-chest seed from floor seed, marker position, and index.
func _build_chest_seed(generation_seed: int, marker_position: Vector3, spawn_index: int) -> int:
	var quantized_x: int = int(roundf(marker_position.x * 100.0))
	var quantized_y: int = int(roundf(marker_position.y * 100.0))
	var quantized_z: int = int(roundf(marker_position.z * 100.0))
	var combined: int = generation_seed
	combined = int(combined ^ (_runtime_progression_index * 239))
	combined = int(combined ^ (spawn_index * 977))
	combined = int(combined ^ quantized_x)
	combined = int(combined ^ (quantized_y << 3))
	combined = int(combined ^ (quantized_z << 5))
	if combined == 0:
		combined = 1
	return abs(combined)

# Resolves and caches EnemySpawnManager autoload reference when available.
func _ensure_enemy_spawn_manager() -> void:
	if _enemy_spawn_manager != null and is_instance_valid(_enemy_spawn_manager):
		return
	if not is_inside_tree() or not has_node("/root/EnemySpawnManager"):
		_enemy_spawn_manager = null
		return
	_enemy_spawn_manager = get_node("/root/EnemySpawnManager")

# Connects generated floor-exit trigger signal to floor completion callback.
func _connect_floor_exit_trigger() -> void:
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	var exit_trigger: Node = _generated_root.find_child("FloorExitTrigger", true, false)
	if exit_trigger and not exit_trigger.is_connected("exit_reached", _on_floor_exit_reached):
		exit_trigger.connect("exit_reached", _on_floor_exit_reached)

# Handles floor exit activation and delegates to progression manager when present.
func _on_floor_exit_reached() -> void:
	if _has_progression_manager():
		GameProgressionManager.complete_floor_exit()
		return
	regenerate_now()

# Handles merchant exit and resumes floor flow via progression or regeneration.
func _on_merchant_exit_reached() -> void:
	MerchantManager.close_shop()
	if _has_progression_manager():
		GameProgressionManager.complete_merchant_exit()
		return
	_hide_merchant_room()
	regenerate_now()

# Returns true when the progression manager autoload exists in the scene tree.
func _has_progression_manager() -> bool:
	return has_node("/root/GameProgressionManager")

# Performs cleanup when this controller is about to be deleted.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_clear_generated()
		if _merchant_room_instance != null and is_instance_valid(_merchant_room_instance):
			_merchant_room_instance.queue_free()
			_merchant_room_instance = null
