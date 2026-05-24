# Orchestrates floor generation, building, and runtime floor state transitions.
@tool
extends Node3D
class_name DungeonFloorController

const DefaultFloorConfig = preload("res://resources/dungeon/default_floor_config.tres")
const PlayerScene = preload("res://scenes/player/player.tscn")
const EnemyScene = preload("res://scenes/enemies/enemy_basic.tscn")
const MerchantRoomScene = preload("res://scenes/merchant/merchant_room.tscn")
const ChestScene = preload("res://scenes/items/chest_interactable.tscn")
const PATROL_DEBUG_VISUAL_NODE_NAME: String = "PatrolDebugVisualizer"

@export var config: DungeonFloorConfig = DefaultFloorConfig
@export var use_multimesh: bool = true
@export var create_floor_collision: bool = true
@export var auto_randomize_seed_on_regenerate: bool = false
@export var player_scene: PackedScene = PlayerScene
@export var player_spawn_fallback: Vector3 = Vector3(0.0, 3.0, 0.0)
@export var player_spawn_height_offset: float = 1.2
@export var enemy_scene: PackedScene = EnemyScene
@export var enemy_spawn_fallback: Vector3 = Vector3(8.0, 2.5, 8.0)
@export var merchant_room_scene: PackedScene = MerchantRoomScene

var _regenerate_toggle: bool = false
var _clear_floor_toggle: bool = false
var _seed_rng: RandomNumberGenerator = RandomNumberGenerator.new()

@export var regenerate: bool:
	get:
		return _regenerate_toggle
	set(value):
		_regenerate_toggle = value
		if value:
			_regenerate_toggle = false
			var floor_config := _get_config()
			if auto_randomize_seed_on_regenerate:
				floor_config.generation_seed = _next_random_seed()
			regenerate_now()

@export var clear_current_floor: bool:
	get:
		return _clear_floor_toggle
	set(value):
		_clear_floor_toggle = value
		if value:
			_clear_floor_toggle = false
			_clear_generated()

var _generated_root: Node3D
var _player_instance: CharacterBody3D
var _merchant_room_instance: MerchantRoomController
var _progression_config_override: DungeonFloorConfig
var _runtime_floor_display: int = -10
var _runtime_progression_index: int = 0
var _enemy_spawn_manager: Node
var _runtime_generation_seed: int = 0
var _runtime_layout: Dictionary = {}
var _patrol_link_debug_visual_enabled: bool = false

func _ready() -> void:
	if not Engine.is_editor_hint():
		if not _has_progression_manager():
			regenerate_now()

func start_progression_floor(display_floor: int, progression_index: int, floor_config: DungeonFloorConfig) -> void:
	_runtime_floor_display = display_floor
	_runtime_progression_index = progression_index
	_progression_config_override = floor_config
	_hide_merchant_room()
	regenerate_now()

func enter_merchant_room() -> void:
	_clear_generated()
	_ensure_player_spawned()
	if merchant_room_scene == null:
		return
	if _merchant_room_instance == null or not is_instance_valid(_merchant_room_instance):
		var room_node: Node = merchant_room_scene.instantiate()
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

func regenerate_now() -> void:
	_clear_generated()
	var floor_config := _get_config()
	var generation_seed: int = floor_config.generation_seed
	if not Engine.is_editor_hint():
		generation_seed = _next_random_seed()
		floor_config.generation_seed = generation_seed
	_runtime_generation_seed = generation_seed
	var generator: DungeonGenerator = DungeonGenerator.new()
	var layout: Dictionary = generator.generate(generation_seed, _build_generation_params())
	_runtime_layout = layout
	var builder: DungeonBuilder3D = DungeonBuilder3D.new()
	var editor_owner: Node = null
	if Engine.is_editor_hint() and get_tree() != null:
		editor_owner = get_tree().edited_scene_root
	_generated_root = builder.build(self, layout, _build_builder_params(), editor_owner)
	if _patrol_link_debug_visual_enabled:
		_rebuild_patrol_link_debug_visual()
	_spawn_chests_for_floor(generation_seed)
	_spawn_or_reposition_player()
	_spawn_enemies_for_floor(generation_seed)
	_connect_floor_exit_trigger()

func get_runtime_progression_index() -> int:
	return _runtime_progression_index

func get_current_floor_seed() -> int:
	return _runtime_generation_seed

func _build_generation_params() -> Dictionary:
	var floor_config := _get_config()
	return {
		"width": floor_config.width,
		"height": floor_config.height,
		"cell_count": floor_config.cell_count,
		"spawn_radius": floor_config.spawn_radius,
		"separation_iterations": floor_config.separation_iterations,
		"min_room_size": floor_config.min_room_size,
		"room_area_threshold": floor_config.room_area_threshold,
		"room_keep_ratio": floor_config.room_keep_ratio,
		"loop_percent": floor_config.loop_percent,
		"chest_candidate_ratio": floor_config.chest_candidate_ratio,
		"patrol_nodes_per_room_min": floor_config.patrol_nodes_per_room_min,
		"patrol_nodes_per_room_max": floor_config.patrol_nodes_per_room_max,
		"patrol_point_padding": floor_config.patrol_point_padding,
		"patrol_point_jitter": floor_config.patrol_point_jitter,
	}

func _build_builder_params() -> Dictionary:
	var floor_config := _get_config()
	return {
		"tile_size": floor_config.tile_size,
		"wall_height": floor_config.wall_height,
		"floor_thickness": floor_config.floor_thickness,
		"use_multimesh": use_multimesh,
		"create_floor_collision": create_floor_collision,
	}

func _get_config() -> DungeonFloorConfig:
	if not Engine.is_editor_hint() and _progression_config_override != null:
		return _progression_config_override
	if config == null:
		config = DungeonFloorConfig.new()
	return config

func _clear_generated() -> void:
	if _generated_root != null and is_instance_valid(_generated_root):
		_generated_root.queue_free()
		_generated_root = null
	_clear_patrol_link_debug_visual()
	_runtime_layout.clear()
	if is_inside_tree() and has_node("/root/InventoryManager"):
		InventoryManager.clear_world_items()
	_ensure_enemy_spawn_manager()
	if _enemy_spawn_manager != null and is_instance_valid(_enemy_spawn_manager) and _enemy_spawn_manager.has_method("clear_spawned_enemies"):
		_enemy_spawn_manager.clear_spawned_enemies()

func _hide_merchant_room() -> void:
	if _merchant_room_instance != null and is_instance_valid(_merchant_room_instance):
		_merchant_room_instance.visible = false
	if has_node("/root/MerchantManager") and MerchantManager != null and MerchantManager.has_method("close_shop"):
		MerchantManager.close_shop()

func _ensure_player_spawned() -> void:
	if player_scene == null:
		return
	if _player_instance != null and is_instance_valid(_player_instance):
		return
	var player_node: Node = player_scene.instantiate()
	if player_node is CharacterBody3D:
		_player_instance = player_node as CharacterBody3D
		add_child(_player_instance)
	else:
		player_node.queue_free()

func _spawn_or_reposition_player() -> void:
	_ensure_player_spawned()
	if _player_instance == null or not is_instance_valid(_player_instance):
		return

	var spawn_position: Vector3 = _find_player_spawn_position()
	_player_instance.global_position = spawn_position
	_player_instance.velocity = Vector3.ZERO

func _find_player_spawn_position() -> Vector3:
	if _generated_root != null and is_instance_valid(_generated_root):
		var marker_node: Node = _generated_root.find_child("PlayerStart_0", true, false)
		if marker_node is Marker3D:
			var marker: Marker3D = marker_node as Marker3D
			return marker.global_position + Vector3.UP * player_spawn_height_offset
	return player_spawn_fallback

func _next_random_seed() -> int:
	if _seed_rng.seed == 0:
		_seed_rng.randomize()
	return _seed_rng.randi_range(1, 2147483646)

func _spawn_enemies_for_floor(generation_seed: int) -> void:
	if Engine.is_editor_hint():
		return
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	if enemy_scene == null:
		return
	if _player_instance == null or not is_instance_valid(_player_instance):
		return
	_ensure_enemy_spawn_manager()
	if _enemy_spawn_manager == null or not is_instance_valid(_enemy_spawn_manager):
		return
	if not _enemy_spawn_manager.has_method("spawn_enemies_for_floor"):
		return
	var player_spawn_position: Vector3 = _find_player_spawn_position()
	_enemy_spawn_manager.call(
		"spawn_enemies_for_floor",
		self,
		_generated_root,
		player_spawn_position,
		enemy_scene,
		_runtime_progression_index,
		generation_seed,
		enemy_spawn_fallback
	)

func _spawn_chests_for_floor(generation_seed: int) -> void:
	if Engine.is_editor_hint():
		return
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	if ChestScene == null:
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

		var chest_node: Node = ChestScene.instantiate()
		if not chest_node is Node3D:
			chest_node.queue_free()
			continue
		var chest: Node3D = chest_node as Node3D
		chest.name = "ChestInteractable_%d" % spawn_index
		_generated_root.add_child(chest)
		chest.global_position = marker.global_position + Vector3.UP * 0.42
		var chest_seed: int = _build_chest_seed(generation_seed, marker.global_position, spawn_index)
		if chest.has_method("configure"):
			chest.call("configure", _runtime_progression_index, generation_seed, chest_seed)

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

func _ensure_enemy_spawn_manager() -> void:
	if _enemy_spawn_manager != null and is_instance_valid(_enemy_spawn_manager):
		return
	if not is_inside_tree() or not has_node("/root/EnemySpawnManager"):
		_enemy_spawn_manager = null
		return
	_enemy_spawn_manager = get_node("/root/EnemySpawnManager")

func _connect_floor_exit_trigger() -> void:
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	var exit_trigger_node: Node = _generated_root.find_child("FloorExitTrigger", true, false)
	if exit_trigger_node is FloorExitTrigger:
		var exit_trigger: FloorExitTrigger = exit_trigger_node as FloorExitTrigger
		var callback: Callable = Callable(self, "_on_floor_exit_reached")
		if not exit_trigger.is_connected("exit_reached", callback):
			exit_trigger.connect("exit_reached", callback)

func _on_floor_exit_reached() -> void:
	var manager: Node = _get_progression_manager_node()
	if manager != null and manager.has_method("complete_floor_exit"):
		manager.call("complete_floor_exit")
		return
	regenerate_now()

func _on_merchant_exit_reached() -> void:
	if has_node("/root/MerchantManager") and MerchantManager != null and MerchantManager.has_method("close_shop"):
		MerchantManager.close_shop()
	var manager: Node = _get_progression_manager_node()
	if manager != null and manager.has_method("complete_merchant_exit"):
		manager.call("complete_merchant_exit")
		return
	_hide_merchant_room()
	regenerate_now()

func _has_progression_manager() -> bool:
	return has_node("/root/GameProgressionManager")

func _get_progression_manager_node() -> Node:
	if not _has_progression_manager():
		return null
	return get_node("/root/GameProgressionManager")

func get_patrol_debug_snapshot() -> Dictionary:
	if _runtime_layout.is_empty():
		return {}

	var rooms: Array = _runtime_layout.get("rooms", [])
	var patrol_graph: Dictionary = _runtime_layout.get("patrol_graph", {})
	var room_links: Array = patrol_graph.get("room_links", [])

	var room_count: int = 0
	var patrol_node_count: int = 0
	var topology_parts: PackedStringArray = PackedStringArray()

	for room_data in rooms:
		var room: Dictionary = room_data
		if not room.has("metadata"):
			continue
		var metadata: Dictionary = room["metadata"]
		var room_index: int = int(metadata.get("index", -1))
		var patrol_points: PackedVector2Array = metadata.get("patrol_points", PackedVector2Array())
		var linked_rooms: PackedInt32Array = metadata.get("patrol_linked_rooms", PackedInt32Array())
		room_count += 1
		patrol_node_count += patrol_points.size()
		topology_parts.push_back("R%d(%d)->[%s]" % [room_index, patrol_points.size(), _packed_int_array_to_csv(linked_rooms)])

	return {
		"room_count": room_count,
		"patrol_node_count": patrol_node_count,
		"patrol_link_count": room_links.size(),
		"topology": " | ".join(topology_parts),
	}

func run_patrol_smoke_check() -> Dictionary:
	var report := {
		"ok": false,
		"error": "",
		"room_groups": 0,
		"patrol_markers": 0,
		"link_markers": 0,
		"expected_links": 0,
		"topology": "",
	}

	if _generated_root == null or not is_instance_valid(_generated_root):
		report["error"] = "Generated root missing"
		return report
	if _runtime_layout.is_empty():
		report["error"] = "Runtime layout missing"
		return report

	var patrol_root: Node = _generated_root.find_child("PatrolNodes", true, false)
	if patrol_root == null:
		report["error"] = "PatrolNodes root missing"
		return report

	var room_groups: Array[Node] = patrol_root.find_children("PatrolNodes_Room_*", "Node3D", false, false)
	var patrol_markers: Array[Node] = patrol_root.find_children("PatrolNode_*", "Marker3D", true, false)
	var links_root: Node = patrol_root.find_child("PatrolLinks", false, false)
	var link_markers: Array[Node] = []
	if links_root != null:
		link_markers = links_root.find_children("PatrolLink_*", "Marker3D", false, false)

	var patrol_graph: Dictionary = _runtime_layout.get("patrol_graph", {})
	var expected_links: Array = patrol_graph.get("room_links", [])
	var snapshot: Dictionary = get_patrol_debug_snapshot()

	report["room_groups"] = room_groups.size()
	report["patrol_markers"] = patrol_markers.size()
	report["link_markers"] = link_markers.size()
	report["expected_links"] = expected_links.size()
	report["topology"] = snapshot.get("topology", "")

	if patrol_markers.is_empty():
		report["error"] = "No patrol markers found"
		return report
	if link_markers.size() != expected_links.size():
		report["error"] = "Patrol link marker count mismatch"
		return report

	for link_node in link_markers:
		if not link_node.has_meta("from_room") or not link_node.has_meta("to_room"):
			report["error"] = "Patrol link missing room metadata"
			return report

	report["ok"] = true
	return report

func set_patrol_link_debug_visual_enabled(enabled: bool) -> void:
	_patrol_link_debug_visual_enabled = enabled
	if not enabled:
		_clear_patrol_link_debug_visual()
		return
	_rebuild_patrol_link_debug_visual()

func is_patrol_link_debug_visual_enabled() -> bool:
	return _patrol_link_debug_visual_enabled

func _rebuild_patrol_link_debug_visual() -> void:
	_clear_patrol_link_debug_visual()
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	if _runtime_layout.is_empty():
		return

	var patrol_root: Node = _generated_root.find_child("PatrolNodes", true, false)
	if patrol_root == null:
		return

	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var line_count: int = 0
	line_count += _append_room_patrol_loop_lines(mesh, patrol_root)
	line_count += _append_cross_room_patrol_lines(mesh, patrol_root)

	mesh.surface_end()
	if line_count <= 0:
		return

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = PATROL_DEBUG_VISUAL_NODE_NAME
	mesh_instance.mesh = mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.95, 1.0, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.1, 0.95, 1.0) * 0.6
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material

	_generated_root.add_child(mesh_instance)

func _append_room_patrol_loop_lines(mesh: ImmediateMesh, patrol_root: Node) -> int:
	var lines_added: int = 0
	var room_groups: Array[Node] = patrol_root.find_children("PatrolNodes_Room_*", "Node3D", false, false)
	for room_group in room_groups:
		var markers: Array[Marker3D] = _collect_sorted_patrol_markers(room_group)
		if markers.size() < 2:
			continue
		for marker_index in range(markers.size() - 1):
			_append_line_vertices(mesh, markers[marker_index].global_position, markers[marker_index + 1].global_position)
			lines_added += 1
		if markers.size() > 2:
			_append_line_vertices(mesh, markers[markers.size() - 1].global_position, markers[0].global_position)
			lines_added += 1
	return lines_added

func _append_cross_room_patrol_lines(mesh: ImmediateMesh, patrol_root: Node) -> int:
	var lines_added: int = 0
	var patrol_graph: Dictionary = _runtime_layout.get("patrol_graph", {})
	var room_links: Array = patrol_graph.get("room_links", [])
	for link_data in room_links:
		var link: Dictionary = link_data
		var from_room: int = int(link.get("a", -1))
		var to_room: int = int(link.get("b", -1))
		if from_room < 0 or to_room < 0 or from_room == to_room:
			continue
		var from_position: Vector3 = _resolve_room_patrol_anchor(patrol_root, from_room)
		var to_position: Vector3 = _resolve_room_patrol_anchor(patrol_root, to_room)
		if from_position == Vector3.INF or to_position == Vector3.INF:
			continue
		_append_line_vertices(mesh, from_position, to_position)
		lines_added += 1
	return lines_added

func _resolve_room_patrol_anchor(patrol_root: Node, room_index: int) -> Vector3:
	var room_group: Node = patrol_root.find_child("PatrolNodes_Room_%d" % room_index, false, false)
	if room_group == null:
		return Vector3.INF
	var markers: Array[Marker3D] = _collect_sorted_patrol_markers(room_group)
	if markers.is_empty():
		return Vector3.INF
	return markers[0].global_position

func _collect_sorted_patrol_markers(room_group: Node) -> Array[Marker3D]:
	var marker_nodes: Array[Node] = room_group.find_children("PatrolNode_*", "Marker3D", false, false)
	var markers: Array[Marker3D] = []
	for marker_node in marker_nodes:
		if marker_node is Marker3D:
			markers.append(marker_node as Marker3D)
	markers.sort_custom(func(a: Marker3D, b: Marker3D) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)
	return markers

func _append_line_vertices(mesh: ImmediateMesh, from_world: Vector3, to_world: Vector3) -> void:
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	mesh.surface_add_vertex(_generated_root.to_local(from_world + Vector3.UP * 0.06))
	mesh.surface_add_vertex(_generated_root.to_local(to_world + Vector3.UP * 0.06))

func _clear_patrol_link_debug_visual() -> void:
	if _generated_root == null or not is_instance_valid(_generated_root):
		return
	var node: Node = _generated_root.find_child(PATROL_DEBUG_VISUAL_NODE_NAME, false, false)
	if node != null and is_instance_valid(node):
		node.queue_free()

func _packed_int_array_to_csv(values: PackedInt32Array) -> String:
	if values.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for value in values:
		parts.push_back(str(value))
	return ",".join(parts)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_clear_generated()
		if _merchant_room_instance != null and is_instance_valid(_merchant_room_instance):
			_merchant_room_instance.queue_free()
			_merchant_room_instance = null
