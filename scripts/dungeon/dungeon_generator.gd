extends RefCounted
class_name DungeonGenerator

const DungeonGraph = preload("res://scripts/dungeon/dungeon_graph.gd")

const TILE_WALL := 0
const TILE_FLOOR := 1

func generate(seed_value: int, params: Dictionary) -> Dictionary:
	var width: int = int(params.get("width", 160))
	var height: int = int(params.get("height", 160))
	var cell_count: int = int(params.get("cell_count", 150))
	var radius: float = float(params.get("spawn_radius", min(width, height) * 0.35))
	var separation_iterations: int = int(params.get("separation_iterations", 200))
	var min_room_size: float = float(params.get("min_room_size", 12.0))
	var room_area_threshold: float = float(params.get("room_area_threshold", 120.0))
	var room_keep_ratio: float = float(params.get("room_keep_ratio", 0.45))
	var loop_percent: float = float(params.get("loop_percent", 0.15))
	var chest_candidate_ratio: float = float(params.get("chest_candidate_ratio", 0.3))

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var cells := generate_cells(cell_count, radius, width, height, rng)
	var separation_info := separate_cells(cells, separation_iterations)
	var room_info := designate_rooms(cells, min_room_size, room_area_threshold, room_keep_ratio)
	var rooms: Array = room_info["rooms"]

	var centers := PackedVector2Array()
	for room in rooms:
		centers.push_back(room["center"])

	var graph := DungeonGraph.new()
	var delaunay_edges := graph.build_delaunay_edges(centers)
	var mst_edges := graph.build_mst(centers, delaunay_edges)
	var corridor_edges := graph.add_loop_edges(delaunay_edges, mst_edges, loop_percent, rng)

	var grid := _create_grid(width, height, TILE_WALL)
	for room in rooms:
		_carve_room(grid, width, height, room["rect"])
	for edge in corridor_edges:
		var a: Vector2 = centers[edge["a"]]
		var b: Vector2 = centers[edge["b"]]
		_carve_l_corridor(grid, width, height, a, b, rng)
	_enforce_border_walls(grid, width, height)

	var exit_index := -1
	var start_index := -1
	if not rooms.is_empty():
		exit_index = _find_farthest_room_index(rooms)
		start_index = _find_farthest_from_room_index(rooms, exit_index)

	var marker_data := _annotate_rooms_with_metadata(rooms, start_index, exit_index, chest_candidate_ratio, rng)

	return {
		"grid": grid,
		"width": width,
		"height": height,
		"rooms": rooms,
		"edges": delaunay_edges,
		"mst_edges": mst_edges,
		"corridor_edges": corridor_edges,
		"start_room_index": start_index,
		"exit_room_index": exit_index,
		"spawn_markers": marker_data,
		"stats": {
			"cells": cells.size(),
			"separation_iterations": separation_info["iterations"],
			"overlaps_remaining": separation_info["overlaps"],
			"rooms": rooms.size(),
			"delaunay_edges": delaunay_edges.size(),
			"mst_edges": mst_edges.size(),
			"loop_edges": maxi(0, corridor_edges.size() - mst_edges.size()),
			"enemy_rooms": marker_data["enemy"].size(),
			"chest_candidate_rooms": marker_data["chest_candidate"].size()
		}
	}

func generate_cells(cell_count: int, radius: float, width: int, height: int, rng: RandomNumberGenerator) -> Array:
	var cells: Array = []
	var center := Vector2(width * 0.5, height * 0.5)
	for _i in cell_count:
		var angle := rng.randf() * TAU
		var dist := radius * sqrt(rng.randf())
		var pos := center + Vector2(cos(angle), sin(angle)) * dist

		var room_w := clampf(rng.randfn(10.0, 3.5), 4.0, 22.0)
		var room_h := clampf(rng.randfn(10.0, 3.5), 4.0, 22.0)
		var max_ratio := 2.3
		if room_w / room_h > max_ratio:
			room_w = room_h * max_ratio
		elif room_h / room_w > max_ratio:
			room_h = room_w * max_ratio

		var rect := Rect2(pos - Vector2(room_w, room_h) * 0.5, Vector2(room_w, room_h))
		cells.append({
			"rect": rect,
			"is_room": false,
		})
	return cells

func separate_cells(cells: Array, max_iterations: int) -> Dictionary:
	var iterations := 0
	var overlaps := 0
	for i in max_iterations:
		iterations = i + 1
		overlaps = 0
		var motions: Array[Vector2] = []
		motions.resize(cells.size())
		for k in motions.size():
			motions[k] = Vector2.ZERO

		for a in cells.size():
			for b in range(a + 1, cells.size()):
				var rect_a: Rect2 = cells[a]["rect"]
				var rect_b: Rect2 = cells[b]["rect"]
				if rect_a.intersects(rect_b):
					overlaps += 1
					var delta := rect_b.get_center() - rect_a.get_center()
					if delta.length_squared() < 0.0001:
						delta = Vector2(1.0, 0.0)
					var push := delta.normalized() * 0.5
					motions[a] -= push
					motions[b] += push

		for c in cells.size():
			if motions[c] != Vector2.ZERO:
				var rect: Rect2 = cells[c]["rect"]
				rect.position += motions[c]
				cells[c]["rect"] = rect

		if overlaps == 0:
			break

	return {"iterations": iterations, "overlaps": overlaps}

func designate_rooms(cells: Array, min_room_size: float, room_area_threshold: float, room_keep_ratio: float) -> Dictionary:
	var candidates: Array = []
	for cell in cells:
		var rect: Rect2 = cell["rect"]
		if rect.size.x >= min_room_size and rect.size.y >= min_room_size and rect.get_area() >= room_area_threshold:
			candidates.append(cell)

	if candidates.is_empty() and not cells.is_empty():
		candidates = cells.duplicate()

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["rect"].get_area() > b["rect"].get_area()
	)

	var keep_count := maxi(2, int(round(float(candidates.size()) * clampf(room_keep_ratio, 0.1, 1.0))))
	keep_count = mini(keep_count, candidates.size())

	var rooms: Array = []
	for i in keep_count:
		var room_rect: Rect2 = _snap_rect_to_grid(candidates[i]["rect"])
		rooms.append({
			"rect": room_rect,
			"center": room_rect.get_center(),
		})

	return {"rooms": rooms}

func _create_grid(width: int, height: int, default_tile: int) -> PackedInt32Array:
	var grid := PackedInt32Array()
	grid.resize(width * height)
	for i in grid.size():
		grid[i] = default_tile
	return grid

func _carve_room(grid: PackedInt32Array, width: int, height: int, rect: Rect2) -> void:
	var start_x := clampi(int(rect.position.x), 1, width - 2)
	var start_y := clampi(int(rect.position.y), 1, height - 2)
	var end_x := clampi(int(rect.position.x + rect.size.x), 1, width - 2)
	var end_y := clampi(int(rect.position.y + rect.size.y), 1, height - 2)
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			_set_tile(grid, width, x, y, TILE_FLOOR)

func _carve_l_corridor(grid: PackedInt32Array, width: int, height: int, a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> void:
	var a_cell := Vector2i(int(round(a.x)), int(round(a.y)))
	var b_cell := Vector2i(int(round(b.x)), int(round(b.y)))
	if rng.randf() < 0.5:
		_carve_hall_segment(grid, width, height, a_cell.x, b_cell.x, a_cell.y)
		_carve_hall_segment_vertical(grid, width, height, a_cell.y, b_cell.y, b_cell.x)
	else:
		_carve_hall_segment_vertical(grid, width, height, a_cell.y, b_cell.y, a_cell.x)
		_carve_hall_segment(grid, width, height, a_cell.x, b_cell.x, b_cell.y)

	for y in range(mini(a_cell.y, b_cell.y) - 1, maxi(a_cell.y, b_cell.y) + 2):
		for x in range(mini(a_cell.x, b_cell.x) - 1, maxi(a_cell.x, b_cell.x) + 2):
			if _count_floor_neighbors(grid, width, height, x, y) >= 3:
				_set_tile(grid, width, x, y, TILE_FLOOR)

func _carve_hall_segment(grid: PackedInt32Array, width: int, height: int, from_x: int, to_x: int, y: int) -> void:
	var step := 1 if to_x >= from_x else -1
	var x := from_x
	while true:
		for t in range(-1, 2):
			_set_tile(grid, width, x, y + t, TILE_FLOOR)
		if x == to_x:
			break
		x += step

func _carve_hall_segment_vertical(grid: PackedInt32Array, width: int, height: int, from_y: int, to_y: int, x: int) -> void:
	var step := 1 if to_y >= from_y else -1
	var y := from_y
	while true:
		for t in range(-1, 2):
			_set_tile(grid, width, x + t, y, TILE_FLOOR)
		if y == to_y:
			break
		y += step

func _count_floor_neighbors(grid: PackedInt32Array, width: int, height: int, x: int, y: int) -> int:
	if x < 1 or y < 1 or x >= width - 1 or y >= height - 1:
		return 0
	var count := 0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			if _get_tile(grid, width, x + ox, y + oy) == TILE_FLOOR:
				count += 1
	return count

func _set_tile(grid: PackedInt32Array, width: int, x: int, y: int, tile: int) -> void:
	if x < 0 or y < 0:
		return
	var height := int(grid.size() / width)
	if x >= width or y >= height:
		return
	# Keep a permanent 1-tile wall border around the map.
	if x == 0 or y == 0 or x == width - 1 or y == height - 1:
		return
	var index := y * width + x
	if index >= 0 and index < grid.size():
		grid[index] = tile

func _get_tile(grid: PackedInt32Array, width: int, x: int, y: int) -> int:
	if x < 0 or y < 0:
		return TILE_WALL
	var height := int(grid.size() / width)
	if x >= width or y >= height:
		return TILE_WALL
	var index := y * width + x
	if index < 0 or index >= grid.size():
		return TILE_WALL
	return grid[index]

func _enforce_border_walls(grid: PackedInt32Array, width: int, height: int) -> void:
	if width < 2 or height < 2:
		return
	for x in range(width):
		grid[x] = TILE_WALL
		grid[(height - 1) * width + x] = TILE_WALL
	for y in range(height):
		grid[y * width] = TILE_WALL
		grid[y * width + (width - 1)] = TILE_WALL

func _snap_rect_to_grid(rect: Rect2) -> Rect2:
	var pos := Vector2(floor(rect.position.x), floor(rect.position.y))
	var size := Vector2(max(4.0, floor(rect.size.x)), max(4.0, floor(rect.size.y)))
	return Rect2(pos, size)

func _find_farthest_room_index(rooms: Array) -> int:
	if rooms.is_empty():
		return -1
	var center := Vector2.ZERO
	for room in rooms:
		center += room["center"]
	center /= float(rooms.size())
	var max_dist := -1.0
	var max_index := 0
	for i in rooms.size():
		var dist := center.distance_squared_to(rooms[i]["center"])
		if dist > max_dist:
			max_dist = dist
			max_index = i
	return max_index

func _find_farthest_from_room_index(rooms: Array, room_index: int) -> int:
	if rooms.is_empty():
		return -1
	if room_index < 0 or room_index >= rooms.size():
		return 0

	var ref_center: Vector2 = rooms[room_index]["center"]
	var max_dist := -1.0
	var max_index := room_index
	for i in rooms.size():
		if i == room_index:
			continue
		var dist := ref_center.distance_squared_to(rooms[i]["center"])
		if dist > max_dist:
			max_dist = dist
			max_index = i
	return max_index

func _annotate_rooms_with_metadata(rooms: Array, start_index: int, exit_index: int, chest_candidate_ratio: float, rng: RandomNumberGenerator) -> Dictionary:
	var marker_data := {
		"player_start": PackedVector2Array(),
		"enemy": PackedVector2Array(),
		"chest_candidate": PackedVector2Array(),
		"floor_exit": PackedVector2Array(),
	}

	var candidate_indices: Array[int] = []
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		var metadata := {
			"index": i,
			"is_player_start": i == start_index,
			"is_floor_exit": i == exit_index,
			"is_enemy_room": i != start_index and i != exit_index,
			"is_chest_candidate": false,
		}
		room["metadata"] = metadata
		rooms[i] = room

		if metadata["is_player_start"]:
			marker_data["player_start"].push_back(room["center"])
		if metadata["is_floor_exit"]:
			marker_data["floor_exit"].push_back(room["center"])
		if metadata["is_enemy_room"]:
			marker_data["enemy"].push_back(room["center"])
			candidate_indices.append(i)

	if not candidate_indices.is_empty():
		for i in range(candidate_indices.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp := candidate_indices[i]
			candidate_indices[i] = candidate_indices[j]
			candidate_indices[j] = tmp

	var chest_count := int(round(float(candidate_indices.size()) * clampf(chest_candidate_ratio, 0.0, 1.0)))
	if not candidate_indices.is_empty():
		chest_count = maxi(1, chest_count)
	chest_count = mini(chest_count, candidate_indices.size())

	for i in range(chest_count):
		var room_index := candidate_indices[i]
		var room: Dictionary = rooms[room_index]
		var metadata: Dictionary = room["metadata"]
		metadata["is_chest_candidate"] = true
		room["metadata"] = metadata
		rooms[room_index] = room
		marker_data["chest_candidate"].push_back(room["center"])

	return marker_data
