@tool
extends RefCounted
class_name DungeonBuilder3D

const floorMat: Material = preload("res://materials/floor_wall.tres")
const wallMat: Material = preload("res://materials/brick_wall.tres")

const FloorExitTriggerScene: PackedScene = preload("res://scenes/dungeon/floor_exit_trigger.tscn")
const TILE_WALL := 0
const TILE_FLOOR := 1
const CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

func build(parent: Node3D, layout: Dictionary, params: Dictionary, editor_owner: Node) -> Node3D:
	var root := Node3D.new()
	root.name = "GeneratedDungeon"
	parent.add_child(root)
	if editor_owner != null:
		root.owner = editor_owner

	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var grid: PackedInt32Array = layout.get("grid", PackedInt32Array())
	if width <= 0 or height <= 0 or grid.is_empty():
		return root

	var tile_size: float = float(params.get("tile_size", 2.0))
	var wall_height: float = float(params.get("wall_height", 3.0))
	var floor_thickness: float = float(params.get("floor_thickness", 0.2))
	var create_floor_collision: bool = bool(params.get("create_floor_collision", false))
	var use_multimesh: bool = bool(params.get("use_multimesh", true))

	var floor_parent := Node3D.new()
	floor_parent.name = "FloorTiles"
	root.add_child(floor_parent)
	_assign_owner(floor_parent, editor_owner)

	var wall_parent := Node3D.new()
	wall_parent.name = "WallTiles"
	root.add_child(wall_parent)
	_assign_owner(wall_parent, editor_owner)

	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(tile_size, floor_thickness, tile_size)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(tile_size, wall_height, tile_size)

	#var floor_material := StandardMaterial3D.new()
	var floor_material := floorMat
	floor_material.albedo_color = Color(0.28, 0.25, 0.2)
	floor_mesh.material = floor_material

	#var wall_material := StandardMaterial3D.new()
	var wall_material := wallMat
	wall_material.albedo_color = Color(0.42, 0.42, 0.45)
	wall_mesh.material = wall_material

	var floor_transforms: Array[Transform3D] = []
	var wall_transforms: Array[Transform3D] = []
	var wall_collision_mask := PackedByteArray()
	wall_collision_mask.resize(width * height)

	for y in height:
		for x in width:
			var idx := y * width + x
			if idx < 0 or idx >= grid.size():
				continue
			if grid[idx] == TILE_FLOOR:
				floor_transforms.append(Transform3D(Basis.IDENTITY, _tile_to_world(x, y, tile_size, floor_thickness * 0.5)))
				# No per-tile floor collider
			else:
				if _has_floor_neighbor(grid, width, height, x, y):
					wall_transforms.append(Transform3D(Basis.IDENTITY, _tile_to_world(x, y, tile_size, wall_height * 0.5)))
					wall_collision_mask[idx] = 1

	_spawn_merged_wall_colliders(wall_parent, wall_collision_mask, width, height, tile_size, wall_height, editor_owner)

	# Add a single floor collider if requested
	if create_floor_collision:
		var min_x := 0
		var min_y := 0
		var max_x := width - 1
		var max_y := height - 1
		# Find bounds of all floor tiles
		var found := false
		for y in height:
			for x in width:
				var idx := y * width + x
				if grid[idx] == TILE_FLOOR:
					if not found:
						min_x = x
						max_x = x
						min_y = y
						max_y = y
						found = true
					else:
						min_x = min(min_x, x)
						max_x = max(max_x, x)
						min_y = min(min_y, y)
						max_y = max(max_y, y)
		if found:
			var size_x = float(max_x - min_x + 1) * tile_size
			var size_z = float(max_y - min_y + 1) * tile_size
			var center_x = float(min_x + max_x) * 0.5 * tile_size
			var center_z = float(min_y + max_y) * 0.5 * tile_size
			var center_y = floor_thickness * 0.5
			_spawn_single_floor_collider(floor_parent, Vector3(size_x, floor_thickness, size_z), Vector3(center_x, center_y, center_z), editor_owner)

	# Spawn tiles and markers
	if use_multimesh:
		_spawn_multimesh_tiles(floor_parent, floor_mesh, floor_transforms, editor_owner, "FloorBatch")
		_spawn_multimesh_tiles(wall_parent, wall_mesh, wall_transforms, editor_owner, "WallBatch")
	else:
		_spawn_mesh_tiles(floor_parent, floor_mesh, floor_transforms, editor_owner)
		_spawn_mesh_tiles(wall_parent, wall_mesh, wall_transforms, editor_owner)

	_spawn_room_markers(root, layout, tile_size, editor_owner)
	_spawn_floor_exit_visuals(root, tile_size, editor_owner)

	return root

func _spawn_single_floor_collider(parent: Node3D, box_size: Vector3, center: Vector3, editor_owner: Node) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	_assign_owner(body, editor_owner)
	_assign_owner(shape, editor_owner)

func _spawn_merged_wall_colliders(parent: Node3D, wall_collision_mask: PackedByteArray, width: int, height: int, tile_size: float, wall_height: float, editor_owner: Node) -> void:
	var visited := PackedByteArray()
	visited.resize(width * height)

	for y in height:
		for x in width:
			var start_idx: int = y * width + x
			if wall_collision_mask[start_idx] == 0 or visited[start_idx] == 1:
				continue

			var run_x: int = 0
			while x + run_x < width:
				var idx_x: int = y * width + (x + run_x)
				if wall_collision_mask[idx_x] == 0 or visited[idx_x] == 1:
					break
				run_x += 1

			var run_z: int = 0
			while y + run_z < height:
				var idx_z: int = (y + run_z) * width + x
				if wall_collision_mask[idx_z] == 0 or visited[idx_z] == 1:
					break
				run_z += 1

			if run_x >= run_z:
				for offset in run_x:
					var mark_idx_x: int = y * width + (x + offset)
					visited[mark_idx_x] = 1
				var size_x: float = float(run_x) * tile_size
				var center_x: float = (float(x) + (float(run_x - 1) * 0.5)) * tile_size
				var center_z: float = float(y) * tile_size
				_spawn_wall_collider_box(parent, Vector3(size_x, wall_height, tile_size), Vector3(center_x, wall_height * 0.5, center_z), editor_owner)
			else:
				for offset in run_z:
					var mark_idx_z: int = (y + offset) * width + x
					visited[mark_idx_z] = 1
				var size_z: float = float(run_z) * tile_size
				var center_x: float = float(x) * tile_size
				var center_z: float = (float(y) + (float(run_z - 1) * 0.5)) * tile_size
				_spawn_wall_collider_box(parent, Vector3(tile_size, wall_height, size_z), Vector3(center_x, wall_height * 0.5, center_z), editor_owner)

func _spawn_wall_collider_box(parent: Node3D, box_size: Vector3, center: Vector3, editor_owner: Node) -> void:
	var body := StaticBody3D.new()
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	_assign_owner(body, editor_owner)
	_assign_owner(shape, editor_owner)

func _spawn_tile(parent: Node3D, mesh: Mesh, tile_size: float, center_y: float, x: int, y: int, editor_owner: Node) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = _tile_to_world(x, y, tile_size, center_y)
	parent.add_child(mi)
	_assign_owner(mi, editor_owner)

func _spawn_multimesh_tiles(parent: Node3D, mesh: Mesh, transforms: Array[Transform3D], editor_owner: Node, name: String) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])

	var instance := MultiMeshInstance3D.new()
	instance.name = name
	instance.multimesh = multimesh
	parent.add_child(instance)
	_assign_owner(instance, editor_owner)

func _spawn_mesh_tiles(parent: Node3D, mesh: Mesh, transforms: Array[Transform3D], editor_owner: Node) -> void:
	for transform in transforms:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.transform = transform
		parent.add_child(mi)
		_assign_owner(mi, editor_owner)

func _spawn_room_markers(root: Node3D, layout: Dictionary, tile_size: float, editor_owner: Node) -> void:
	var markers_root := Node3D.new()
	markers_root.name = "SpawnMarkers"
	root.add_child(markers_root)
	_assign_owner(markers_root, editor_owner)

	var spawn_markers: Dictionary = layout.get("spawn_markers", {})
	if not spawn_markers.is_empty():
		_spawn_marker_group(markers_root, "PlayerStartMarkers", "PlayerStart", spawn_markers.get("player_start", PackedVector2Array()), tile_size, editor_owner)
		_spawn_marker_group(markers_root, "EnemySpawnMarkers", "EnemySpawn", spawn_markers.get("enemy", PackedVector2Array()), tile_size, editor_owner)
		_spawn_marker_group(markers_root, "ChestCandidateMarkers", "ChestCandidate", spawn_markers.get("chest_candidate", PackedVector2Array()), tile_size, editor_owner)
		_spawn_marker_group(markers_root, "FloorExitMarkers", "FloorExit", spawn_markers.get("floor_exit", PackedVector2Array()), tile_size, editor_owner)
		return

	var rooms: Array = layout.get("rooms", [])
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		if not room.has("metadata"):
			continue
		var metadata: Dictionary = room["metadata"]
		var center: Vector2 = room.get("center", Vector2.ZERO)
		if metadata.get("is_player_start", false):
			_spawn_marker(markers_root, "PlayerStart_%d" % i, center, tile_size, editor_owner)
		if metadata.get("is_enemy_room", false):
			_spawn_marker(markers_root, "EnemySpawn_%d" % i, center, tile_size, editor_owner)
		if metadata.get("is_chest_candidate", false):
			_spawn_marker(markers_root, "ChestCandidate_%d" % i, center, tile_size, editor_owner)
		if metadata.get("is_floor_exit", false):
			_spawn_marker(markers_root, "FloorExit_%d" % i, center, tile_size, editor_owner)
	# Call _spawn_room_lights after spawning room markers
	_spawn_room_lights(root, layout, tile_size, editor_owner)

func _spawn_marker_group(root: Node3D, group_name: String, marker_prefix: String, points: PackedVector2Array, tile_size: float, editor_owner: Node) -> void:
	var group_root := Node3D.new()
	group_root.name = group_name
	root.add_child(group_root)
	_assign_owner(group_root, editor_owner)
	for i in range(points.size()):
		_spawn_marker(group_root, "%s_%d" % [marker_prefix, i], points[i], tile_size, editor_owner)

func _spawn_marker(parent: Node3D, marker_name: String, point: Vector2, tile_size: float, editor_owner: Node) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = _tile_to_world(point.x, point.y, tile_size, 0.5)
	parent.add_child(marker)
	_assign_owner(marker, editor_owner)

func _spawn_floor_exit_visuals(root: Node3D, _tile_size: float, editor_owner: Node) -> void:
	var marker_node: Node = root.find_child("FloorExit_0", true, false)
	if not marker_node is Marker3D:
		var fallback_markers: Array[Node] = root.find_children("FloorExit_*", "Marker3D", true, false)
		if not fallback_markers.is_empty():
			marker_node = fallback_markers[0]
	if not marker_node is Marker3D:
		return
	var marker: Marker3D = marker_node as Marker3D

	var trigger_node: Node = FloorExitTriggerScene.instantiate()
	if not trigger_node is FloorExitTrigger:
		return
	var trigger: FloorExitTrigger = trigger_node as FloorExitTrigger
	trigger.name = "FloorExitTrigger"
	trigger.position = marker.position
	root.add_child(trigger)
	_assign_owner_recursive(trigger, editor_owner)

func _spawn_collision_box(parent: Node3D, box_size: Vector3, tile_size: float, center_y: float, x: int, y: int, editor_owner: Node) -> void:
	var body := StaticBody3D.new()
	body.position = _tile_to_world(x, y, tile_size, center_y)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	_assign_owner(body, editor_owner)
	_assign_owner(shape, editor_owner)

func _has_floor_neighbor(grid: PackedInt32Array, width: int, height: int, x: int, y: int) -> bool:
	for offset in CARDINAL_OFFSETS:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if nx < 0 or ny < 0 or nx >= width or ny >= height:
			continue
		var index: int = ny * width + nx
		if index >= 0 and index < grid.size() and grid[index] == TILE_FLOOR:
			return true
	return false

func _tile_to_world(x: float, y: float, tile_size: float, world_y: float) -> Vector3:
	return Vector3(x * tile_size, world_y, y * tile_size)

func _assign_owner(node: Node, editor_owner: Node) -> void:
	if editor_owner != null:
		node.owner = editor_owner

func _assign_owner_recursive(node: Node, editor_owner: Node) -> void:
	if editor_owner == null:
		return
	node.owner = editor_owner
	for child in node.get_children():
		if child is Node:
			_assign_owner_recursive(child as Node, editor_owner)

func _spawn_room_lights(parent: Node3D, layout: Dictionary, tile_size: float, editor_owner: Node) -> void:
	var rooms: Array = layout.get("rooms", [])
	for room in rooms:
		var center: Vector2 = room.get("center", Vector2.ZERO)
		var light := OmniLight3D.new()
		light.name = "RoomLight"
		light.position = _tile_to_world(center.x, center.y, tile_size, 2.0) # Adjust Y for light height
		light.intensity = 500.0 # Adjust intensity as needed
		light.range = 20.0 # Adjust range to fit room size
		parent.add_child(light)
		_assign_owner(light, editor_owner)
