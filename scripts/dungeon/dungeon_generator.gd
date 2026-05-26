# Generates dungeon layout data such as rooms, corridors, and tile maps.
extends RefCounted
class_name DungeonGenerator

# Relation: Driven by DungeonFloorController and delegates graph work to DungeonGraph.
# Grid value used for wall cells.
const TILE_WALL := 0
# Grid value used for walkable floor cells.
const TILE_FLOOR := 1
# Margin in tiles/pixels for separation
const SEPARATION_MARGIN: float = 2.0 

# Debug step names recorded for the editor-only generation visualizer.
const DEBUG_STEP_GENERATE_CELLS: StringName = &"generate_cells"
const DEBUG_STEP_SEPARATE_CELLS: StringName = &"separate_cells"
const DEBUG_STEP_DESIGNATE_ROOMS: StringName = &"designate_rooms"
const DEBUG_STEP_DELAUNAY: StringName = &"delaunay"
const DEBUG_STEP_MST: StringName = &"mst"
const DEBUG_STEP_LOOP_EDGES: StringName = &"loop_edges"

# Runs the full generation pipeline and returns layout, markers, patrol graph, and stats.
func generate(seed_value: int, config: DungeonFloorConfig, debug_timeline: DungeonGeneratorDebugTimeline = null) -> DungeonLayoutData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var cells: Array[DungeonCellData] = generate_cells(config.cell_count, rng, config)
	_record_debug_step(debug_timeline, DEBUG_STEP_GENERATE_CELLS, cells)

	separate_cells(cells, config, rng)
	_record_debug_step(debug_timeline, DEBUG_STEP_SEPARATE_CELLS, cells)

	var rooms: Array[DungeonRoomData] = designate_rooms(cells, config)
	_record_debug_step(debug_timeline, DEBUG_STEP_DESIGNATE_ROOMS, cells, rooms)

	var centers := PackedVector2Array()
	for room in rooms:
		centers.push_back(room.center)
	var graph: DungeonGraph = DungeonGraph.new()
	var delaunay_edges: Array[DungeonEdgeData] = graph.build_delaunay_edges(centers)
	_record_debug_step(debug_timeline, DEBUG_STEP_DELAUNAY, [], rooms, delaunay_edges)

	var mst_edges: Array[DungeonEdgeData] = graph.build_mst(centers, delaunay_edges)
	_record_debug_step(debug_timeline, DEBUG_STEP_MST, [], rooms, delaunay_edges, mst_edges)

	var corridor_edges: Array[DungeonEdgeData] = graph.add_loop_edges(delaunay_edges, mst_edges, config.loop_percent, rng)
	var loop_edges: Array[DungeonEdgeData] = []
	for edge_index in range(mst_edges.size(), corridor_edges.size()):
		loop_edges.append(corridor_edges[edge_index])
	_record_debug_step(debug_timeline, DEBUG_STEP_LOOP_EDGES, [], rooms, delaunay_edges, mst_edges, loop_edges)

	var world_rect: Rect2i = _compute_rect_bounds_from_entries(rooms)
	var world_width := int(world_rect.size.x)
	var world_height := int(world_rect.size.y)
	var grid := _create_grid(world_width, world_height, TILE_WALL)
	
	for room in rooms:
		_carve_room(grid, world_rect, room.rect)

	for edge in corridor_edges:
		var a: Vector2 = centers[edge.a]
		var b: Vector2 = centers[edge.b]
		_carve_l_corridor(grid, world_width, world_height, a, b, rng)
		
	_enforce_border_walls(grid, world_width, world_height)

	var exit_index := -1
	var start_index := -1
	if not rooms.is_empty():
		exit_index = _find_farthest_room_index(rooms)
		start_index = _find_farthest_from_room_index(rooms, exit_index)

	var annotation_data: DungeonAnnotationData = _annotate_rooms_with_metadata(
		rooms,
		start_index,
		exit_index,
		config.chest_candidate_ratio,
		mst_edges,
		rng,
		config.patrol_nodes_per_room_min,
		config.patrol_nodes_per_room_max,
		config.patrol_point_padding,
		config.patrol_point_jitter
	)
	var marker_data: DungeonSpawnMarkersData = annotation_data.spawn_markers
	var patrol_graph: DungeonPatrolGraphData = annotation_data.patrol_graph
	var patrol_node_total: int = 0
	for room_points in patrol_graph.room_nodes:
		patrol_node_total += room_points.size()

	var stats: DungeonGeneratorStatsData = DungeonGeneratorStatsData.new()
	stats.cells = cells.size()
	stats.rooms = rooms.size()
	stats.delaunay_edges = delaunay_edges.size()
	stats.mst_edges = mst_edges.size()
	stats.loop_edges = maxi(0, corridor_edges.size() - mst_edges.size())
	stats.enemy_rooms = marker_data.enemy.size()
	stats.chest_candidate_rooms = marker_data.chest_candidate.size()
	stats.patrol_rooms = patrol_graph.room_nodes.size()
	stats.patrol_nodes = patrol_node_total
	stats.patrol_room_links = patrol_graph.room_links.size()

	var layout: DungeonLayoutData = DungeonLayoutData.new()
	layout.grid = grid
	layout.width = world_width
	layout.height = world_height
	layout.grid_offset = world_rect.position
	layout.rooms = rooms
	layout.edges = delaunay_edges
	layout.mst_edges = mst_edges
	layout.corridor_edges = corridor_edges
	layout.start_room_index = start_index
	layout.exit_room_index = exit_index
	layout.spawn_markers = marker_data
	layout.patrol_graph = patrol_graph
	layout.stats = stats
	return layout

# Records one generation step into the optional editor-only debug timeline.
func _record_debug_step(
	debug_timeline: DungeonGeneratorDebugTimeline,
	step_name: StringName,
	cells: Array[DungeonCellData] = [],
	rooms: Array[DungeonRoomData] = [],
	delaunay_edges: Array[DungeonEdgeData] = [],
	mst_edges: Array[DungeonEdgeData] = [],
	loop_edges: Array[DungeonEdgeData] = []
) -> void:
	if debug_timeline == null:
		return
	var step_data: DungeonGeneratorDebugStepData = DungeonGeneratorDebugStepData.new()
	step_data.step_name = step_name
	for cell in cells:
		step_data.cells.append(cell.duplicate_data())
	for room in rooms:
		step_data.rooms.append(room.duplicate_data())
	for edge in delaunay_edges:
		step_data.delaunay_edges.append(edge.duplicate_data())
	for edge in mst_edges:
		step_data.mst_edges.append(edge.duplicate_data())
	for edge in loop_edges:
		step_data.loop_edges.append(edge.duplicate_data())
	debug_timeline.record_step(step_data)

# Samples room candidate cells from a radial distribution around map center.
func generate_cells(cell_count: int, rng: RandomNumberGenerator, config: DungeonFloorConfig) -> Array[DungeonCellData]:
	var cells: Array[DungeonCellData] = []
	var center := Vector2(config.width * 0.5, config.height * 0.5)
	for _i in cell_count:
		var angle := rng.randf() * TAU
		var dist : float = config.spawn_radius * sqrt(rng.randf())
		var pos := center + Vector2(cos(angle), sin(angle)).normalized() * dist
		
		pos = pos.round()
		
		var mean = (config.min_room_size + config.room_max_size) * 0.5
		var room_w := (clampf(rng.randfn(mean, config.room_size_deviation), config.min_room_size, config.room_max_size))
		var room_h := (clampf(rng.randfn(mean, config.room_size_deviation), config.min_room_size, config.room_max_size))

		if int(room_h) % 2 != 0: 
			room_h += 1
		if int(room_w) % 2 != 0: 
			room_w += 1

		var rect_position := Vector2i(
			int(round(pos.x - room_w * 0.5)),
			int(round(pos.y - room_h * 0.5))
		)
		var rect_size := Vector2i(int(room_w), int(room_h))
		var rect := Rect2i(rect_position, rect_size)
		cells.append(DungeonCellData.new(_snap_rect_to_grid(rect), false))
	return cells

# Resolves overlapping room candidates using iterative pairwise push separation.
func separate_cells(cells: Array[DungeonCellData], config: DungeonFloorConfig, rng: RandomNumberGenerator) -> void:	
	var overlaps: int = 0
	for i in config.separation_iterations:
		overlaps = 0
		for a in cells.size():
			var _overlaps_dist: float = -1
			var _overlaps_dir: Vector2 = Vector2.ZERO
			for b in cells.size():
				if a == b:
					continue
				var rect_a: Rect2i = _grow_rect_i(cells[a].rect, int(SEPARATION_MARGIN))
				var rect_b: Rect2i = _grow_rect_i(cells[b].rect, int(SEPARATION_MARGIN))
				if rect_a.intersects(rect_b):
					var _dir := Vector2(rect_a.position - rect_b.position)
					var _dist: float = _dir.length_squared()
					if _dist < _overlaps_dist or _overlaps_dist == -1:
						overlaps += 1
						_overlaps_dist = _dist
						_overlaps_dir = _dir
			if _overlaps_dist == -1:
				continue
			if _overlaps_dist < 0.05:
				_overlaps_dir = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			if _overlaps_dir.is_zero_approx():
				continue
			_overlaps_dir = _overlaps_dir.normalized()
			var _push_dir := Vector2i(int(round(_overlaps_dir.x)), int(round(_overlaps_dir.y)))
			if _push_dir == Vector2i.ZERO:
				_push_dir = Vector2i(1, 0)
			var rect: Rect2i = cells[a].rect
			rect.position += _push_dir
			cells[a].rect = _snap_rect_to_grid(rect)
		if overlaps == 0:
			break
# Computes a merged Rect2i bounds box from typed room entries.
func _compute_rect_bounds_from_entries(entries: Array[DungeonRoomData]) -> Rect2i:
	var has_bounds: bool = false
	var bounds: Rect2i = Rect2i()
	for entry in entries:
		var rect: Rect2i = entry.rect
		if not has_bounds:
			bounds = rect
			has_bounds = true
		else:
			bounds = bounds.merge(rect)

	if not has_bounds:
		return Rect2i()
	return bounds

# Selects final rooms from candidates based on size, area, and keep ratio.
func designate_rooms(cells: Array[DungeonCellData], config:DungeonFloorConfig) -> Array[DungeonRoomData]:
	var candidates: Array[DungeonCellData] = []
	for cell in cells:
		var rect: Rect2i = _snap_rect_to_grid(cell.rect)
		var ratio: float = min(rect.size.x, rect.size.y) / max(rect.size.x, rect.size.y)
		if ratio >= config.room_keep_ratio:
			candidates.append(cell)

	if candidates.is_empty() and not cells.is_empty():
		candidates = cells.duplicate()

	var rooms: Array[DungeonRoomData] = []
	for i in candidates.size():
		var room_rect: Rect2i = _snap_rect_to_grid(candidates[i].rect)
		var room_center: Vector2 = Vector2(room_rect.get_center())
		rooms.append(DungeonRoomData.new(room_rect, room_center))

	return rooms

# Allocates and initializes a dense tile grid.
func _create_grid(width: int, height: int, default_tile: int) -> PackedInt32Array:
	var grid := PackedInt32Array()
	grid.resize(width * height)
	for i in grid.size():
		grid[i] = default_tile
	return grid

# Carves a rectangular room into floor tiles within safe interior bounds.
func _carve_room(grid: PackedInt32Array, world_rect: Rect2i, rect: Rect2i) -> void:
	var start_x: int = rect.position.x - world_rect.position.x
	var start_y: int = rect.position.y - world_rect.position.y
	var end_x: int = rect.end.x - world_rect.position.x
	var end_y: int = rect.end.y - world_rect.position.y
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			_set_tile(grid, int(world_rect.size.x), int(world_rect.size.y), x, y, TILE_FLOOR)

# Carves an L-shaped corridor between two room centers and smooths dense corners.
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
				_set_tile(grid, width, height, x, y, TILE_FLOOR)

# Carves a horizontal hallway segment with configurable thickness.
func _carve_hall_segment(grid: PackedInt32Array, width: int, _height: int, from_x: int, to_x: int, y: int) -> void:
	var step := 1 if to_x >= from_x else -1
	var x := from_x
	while true:
		for t in range(-1, 2):
			_set_tile(grid, width, _height, x, y + t, TILE_FLOOR)
		if x == to_x:
			break
		x += step

# Carves a vertical hallway segment with configurable thickness.
func _carve_hall_segment_vertical(grid: PackedInt32Array, width: int, _height: int, from_y: int, to_y: int, x: int) -> void:
	var step := 1 if to_y >= from_y else -1
	var y := from_y
	while true:
		for t in range(-1, 2):
			_set_tile(grid, width, _height, x + t, y, TILE_FLOOR)
		if y == to_y:
			break
		y += step

# Counts neighboring floor tiles around a cell in an 8-neighbor window.
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

# Writes a tile value with bounds checks and a permanent one-tile outer wall border.
func _set_tile(grid: PackedInt32Array, width: int, height: int, x: int, y: int, tile: int) -> void:
	if x < 0 or y < 0:
		return
	if x >= width or y >= height:
		return
	# Keep a permanent 1-tile wall border around the map.
	if x == 0 or y == 0 or x == width - 1 or y == height - 1:
		return
	var index := y * width + x
	if index >= 0 and index < grid.size():
		grid[index] = tile

# Reads a tile value with safe wall defaults for out-of-bounds access.
func _get_tile(grid: PackedInt32Array, width: int, x: int, y: int) -> int:
	if x < 0 or y < 0:
		return TILE_WALL
	var height := int(float(grid.size()) / float(width))
	if x >= width or y >= height:
		return TILE_WALL
	var index := y * width + x
	if index < 0 or index >= grid.size():
		return TILE_WALL
	return grid[index]

# Force-writes map perimeter cells as wall tiles.
func _enforce_border_walls(grid: PackedInt32Array, width: int, height: int) -> void:
	if width < 2 or height < 2:
		return
	for x in range(width):
		grid[x] = TILE_WALL
		grid[(height - 1) * width + x] = TILE_WALL
	for y in range(height):
		grid[y * width] = TILE_WALL
		grid[y * width + (width - 1)] = TILE_WALL

# Snaps room rectangles to integer grid coordinates and minimum dimensions.
func _snap_rect_to_grid(rect: Rect2i) -> Rect2i:
	return rect

# Grows an integer-grid rectangle by a margin on all sides.
func _grow_rect_i(rect: Rect2i, margin: int) -> Rect2i:
	return Rect2i(
		rect.position - Vector2i(margin, margin),
		rect.size + Vector2i(margin * 2, margin * 2)
	)

# Finds the room farthest from the average center of all rooms.
func _find_farthest_room_index(rooms: Array[DungeonRoomData]) -> int:
	if rooms.is_empty():
		return -1
	var center := Vector2.ZERO
	for room in rooms:
		center += room.center
	center /= float(rooms.size())
	var max_dist := -1.0
	var max_index := 0
	for i in rooms.size():
		var dist := center.distance_squared_to(rooms[i].center)
		if dist > max_dist:
			max_dist = dist
			max_index = i
	return max_index

# Finds the room farthest from a reference room index.
func _find_farthest_from_room_index(rooms: Array[DungeonRoomData], room_index: int) -> int:
	if rooms.is_empty():
		return -1
	if room_index < 0 or room_index >= rooms.size():
		return 0

	var ref_center: Vector2 = rooms[room_index].center
	var max_dist := -1.0
	var max_index := room_index
	for i in rooms.size():
		if i == room_index:
			continue
		var dist := ref_center.distance_squared_to(rooms[i].center)
		if dist > max_dist:
			max_dist = dist
			max_index = i
	return max_index

# Adds gameplay metadata to rooms and builds spawn marker and patrol graph payloads.
func _annotate_rooms_with_metadata(
	rooms: Array[DungeonRoomData],
	start_index: int,
	exit_index: int,
	chest_candidate_ratio: float,
	mst_edges: Array[DungeonEdgeData],
	rng: RandomNumberGenerator,
	patrol_nodes_per_room_min: int,
	patrol_nodes_per_room_max: int,
	patrol_point_padding: float,
	patrol_point_jitter: float
	) -> DungeonAnnotationData:
	var marker_data: DungeonSpawnMarkersData = DungeonSpawnMarkersData.new()
	var room_adjacency: Array[PackedInt32Array] = _build_mst_room_adjacency(rooms.size(), mst_edges)

	var candidate_indices: Array[int] = []
	for i in rooms.size():
		var room: DungeonRoomData = rooms[i]
		var metadata: DungeonRoomMetadataData = DungeonRoomMetadataData.new(i)
		metadata.is_player_start = i == start_index
		metadata.is_floor_exit = i == exit_index
		metadata.is_enemy_room = i != start_index and i != exit_index
		room.metadata = metadata

		if metadata.is_player_start:
			marker_data.player_start.push_back(room.center)
		if metadata.is_floor_exit:
			marker_data.floor_exit.push_back(room.center)
		if metadata.is_enemy_room:
			marker_data.enemy.push_back(room.center)
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
		var room: DungeonRoomData = rooms[room_index]
		room.metadata.is_chest_candidate = true
		marker_data.chest_candidate.push_back(room.center)

	for i in rooms.size():
		var room: DungeonRoomData = rooms[i]
		var metadata: DungeonRoomMetadataData = room.metadata
		var linked_rooms: PackedInt32Array = PackedInt32Array()
		if i >= 0 and i < room_adjacency.size():
			linked_rooms = room_adjacency[i]
		var patrol_point_count: int = _resolve_patrol_point_count(patrol_nodes_per_room_min, patrol_nodes_per_room_max, rng)
		metadata.patrol_points = _build_patrol_points_for_room(
			room.rect,
			patrol_point_count,
			patrol_point_padding,
			patrol_point_jitter,
			rng
		)
		metadata.patrol_linked_rooms = linked_rooms

	var annotation_data: DungeonAnnotationData = DungeonAnnotationData.new()
	annotation_data.spawn_markers = marker_data
	annotation_data.patrol_graph = _build_patrol_graph_payload(rooms, room_adjacency, mst_edges)
	return annotation_data

# Builds symmetric room adjacency from MST edges.
func _build_mst_room_adjacency(room_count: int, mst_edges: Array[DungeonEdgeData]) -> Array[PackedInt32Array]:
	var room_adjacency: Array[PackedInt32Array] = []
	for room_index in range(room_count):
		room_adjacency.append(PackedInt32Array())

	for edge in mst_edges:
		var a: int = edge.a
		var b: int = edge.b
		if a < 0 or b < 0 or a >= room_count or b >= room_count or a == b:
			continue

		var a_links: PackedInt32Array = room_adjacency[a]
		_push_unique_room_index(a_links, b)
		room_adjacency[a] = a_links

		var b_links: PackedInt32Array = room_adjacency[b]
		_push_unique_room_index(b_links, a)
		room_adjacency[b] = b_links

	return room_adjacency

# Appends a room index only when it is not already present.
func _push_unique_room_index(indices: PackedInt32Array, value: int) -> void:
	for existing in indices:
		if existing == value:
			return
	indices.push_back(value)

# Resolves a valid patrol point count from configured min and max bounds.
func _resolve_patrol_point_count(min_count: int, max_count: int, rng: RandomNumberGenerator) -> int:
	var safe_min: int = max(min_count, 1)
	var safe_max: int = max(max_count, safe_min)
	if safe_min == safe_max:
		return safe_min
	return rng.randi_range(safe_min, safe_max)

# Generates patrol points inside a room rectangle with padding and angular jitter.
func _build_patrol_points_for_room(rect: Rect2i, point_count: int, padding: float, jitter: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array()
	if point_count <= 0:
		return points

	var room_center: Vector2 = rect.get_center()
	var safe_padding: float = maxf(padding, 0.0)
	var min_x: float = rect.position.x + safe_padding
	var min_y: float = rect.position.y + safe_padding
	var max_x: float = rect.position.x + rect.size.x - safe_padding
	var max_y: float = rect.position.y + rect.size.y - safe_padding
	if min_x > max_x:
		min_x = room_center.x
		max_x = room_center.x
	if min_y > max_y:
		min_y = room_center.y
		max_y = room_center.y

	var half_width: float = maxf((max_x - min_x) * 0.5, 0.0)
	var half_height: float = maxf((max_y - min_y) * 0.5, 0.0)
	var center_x: float = (min_x + max_x) * 0.5
	var center_y: float = (min_y + max_y) * 0.5

	for i in point_count:
		var base_angle: float = TAU * (float(i) / float(max(point_count, 1)))
		var angle: float = base_angle + rng.randf_range(-jitter, jitter)
		var radial: float = clampf(0.35 + rng.randf() * 0.55, 0.1, 1.0)
		var patrol_x: float = center_x + cos(angle) * half_width * radial
		var patrol_y: float = center_y + sin(angle) * half_height * radial
		points.push_back(Vector2(clampf(patrol_x, min_x, max_x), clampf(patrol_y, min_y, max_y)))

	if points.is_empty():
		points.push_back(room_center)

	return points

# Builds serialized patrol graph payload used by builders and debug consumers.
func _build_patrol_graph_payload(rooms: Array[DungeonRoomData], room_adjacency: Array[PackedInt32Array], mst_edges: Array[DungeonEdgeData]) -> DungeonPatrolGraphData:
	var patrol_graph: DungeonPatrolGraphData = DungeonPatrolGraphData.new()
	for room in rooms:
		patrol_graph.room_nodes.append(room.metadata.patrol_points)

	for edge in mst_edges:
		if edge.a < 0 or edge.b < 0 or edge.a == edge.b:
			continue
		patrol_graph.room_links.append(DungeonEdgeData.new(edge.a, edge.b, edge.weight))

	for room_links in room_adjacency:
		patrol_graph.room_adjacency.append(room_links)

	return patrol_graph
