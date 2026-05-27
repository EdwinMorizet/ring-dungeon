# Generates dungeon layout data such as rooms, corridors, and tile maps.
extends RefCounted
class_name DungeonGenerator

# Relation: Driven by DungeonFloorController and delegates graph work to DungeonGraph.

# Margin in tiles/pixels for separation
const SEPARATION_MARGIN: float = 1.0 

# Debug step names recorded for the editor-only generation visualizer.
const DEBUG_STEP_GENERATE_CELLS: StringName = &"generate_cells"
const DEBUG_STEP_SEPARATE_CELLS: StringName = &"separate_cells"
const DEBUG_STEP_DESIGNATE_ROOMS: StringName = &"designate_rooms"
const DEBUG_STEP_DELAUNAY: StringName = &"delaunay"
const DEBUG_STEP_MST: StringName = &"mst"
const DEBUG_STEP_LOOP_EDGES: StringName = &"loop_edges"
const DEBUG_STEP_CORRIDORS: StringName = &"corridors"

# Runs the full generation pipeline and returns layout, markers, patrol graph, and stats.
func generate(
	seed_value: int,
	config: DungeonFloorConfig,
	debug_timeline: DungeonGeneratorDebugTimeline = null,
	progression_index: int = 0
) -> DungeonLayoutData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var cells: Array[DungeonCellData] = generate_cells(config.cell_count, rng, config, progression_index)
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
	_record_debug_step(debug_timeline, DEBUG_STEP_DELAUNAY, cells, rooms, delaunay_edges)

	var mst_edges: Array[DungeonEdgeData] = graph.build_mst(centers, delaunay_edges)
	_record_debug_step(debug_timeline, DEBUG_STEP_MST, cells, rooms, delaunay_edges, mst_edges)

	var corridor_edges: Array[DungeonEdgeData] = graph.add_loop_edges(delaunay_edges, mst_edges, config.loop_percent, rng)
	var loop_edges: Array[DungeonEdgeData] = []
	for edge_index in range(mst_edges.size(), corridor_edges.size()):
		loop_edges.append(corridor_edges[edge_index])
	_record_debug_step(debug_timeline, DEBUG_STEP_LOOP_EDGES, cells, rooms, delaunay_edges, mst_edges, loop_edges)
	_record_debug_step(debug_timeline, DEBUG_STEP_CORRIDORS, cells, rooms, delaunay_edges, mst_edges, loop_edges, corridor_edges)

	var world_rect: Rect2i = _compute_rect_bounds_from_entries(rooms)
	var world_width := int(world_rect.size.x)
	var world_height := int(world_rect.size.y)
	var grid := _create_grid(world_width, world_height, DungeonBuilderConstants.TILE_WALL)
	
	for room in rooms:
		_carve_room_for_data(grid, world_rect, room)

	var door_side_totals: PackedInt32Array = _build_room_side_door_counts(rooms, corridor_edges)
	var door_side_used: PackedInt32Array = PackedInt32Array()
	door_side_used.resize(door_side_totals.size())

	for edge in corridor_edges:
		if edge.a < 0 or edge.b < 0 or edge.a >= rooms.size() or edge.b >= rooms.size() or edge.a == edge.b:
			continue

		var room_a: DungeonRoomData = rooms[edge.a]
		var room_b: DungeonRoomData = rooms[edge.b]
		var side_a: int = _resolve_room_side_for_target(room_a.center, room_b.center)
		var side_b: int = _resolve_room_side_for_target(room_b.center, room_a.center)

		var key_a: int = edge.a * 4 + side_a
		var key_b: int = edge.b * 4 + side_b
		var slot_total_a: int = maxi(1, door_side_totals[key_a])
		var slot_total_b: int = maxi(1, door_side_totals[key_b])
		var slot_index_a: int = mini(door_side_used[key_a], slot_total_a - 1)
		var slot_index_b: int = mini(door_side_used[key_b], slot_total_b - 1)
		door_side_used[key_a] = door_side_used[key_a] + 1
		door_side_used[key_b] = door_side_used[key_b] + 1

		var door_a_world: Vector2i = _resolve_room_door_cell(room_a, side_a, slot_index_a, slot_total_a)
		var door_b_world: Vector2i = _resolve_room_door_cell(room_b, side_b, slot_index_b, slot_total_b)
		var door_a: Vector2i = door_a_world - world_rect.position
		var door_b: Vector2i = door_b_world - world_rect.position

		_set_tile(grid, world_width, world_height, door_a.x, door_a.y, DungeonBuilderConstants.TILE_FLOOR)
		_set_tile(grid, world_width, world_height, door_b.x, door_b.y, DungeonBuilderConstants.TILE_FLOOR)
		_carve_l_corridor_between_doors(grid, world_width, world_height, door_a, door_b, rng)
		
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
		corridor_edges,
		grid,
		world_width,
		world_height,
		world_rect.position,
		rng,
		config.patrol_nodes_per_room_min,
		config.patrol_nodes_per_room_max,
		config.patrol_point_padding,
		config.patrol_point_jitter
	)
	var marker_data: DungeonSpawnMarkersData = annotation_data.spawn_markers
	if start_index >= 0 and start_index < rooms.size() and world_width > 0 and world_height > 0:
		var start_marker: Vector2 = _resolve_accessible_marker_for_room(
			grid,
			world_width,
			world_height,
			world_rect.position,
			rooms[start_index]
		)
		marker_data.player_start = PackedVector2Array([start_marker])
	if exit_index >= 0 and exit_index < rooms.size() and world_width > 0 and world_height > 0:
		var exit_marker: Vector2 = _resolve_accessible_marker_for_room(
			grid,
			world_width,
			world_height,
			world_rect.position,
			rooms[exit_index]
		)
		marker_data.floor_exit = PackedVector2Array([exit_marker])
	var patrol_graph: DungeonPatrolGraphData = annotation_data.patrol_graph
	var patrol_node_total: int = 0
	for room_points in patrol_graph.room_nodes:
		patrol_node_total += room_points.size()
	for corridor_points in patrol_graph.corridor_nodes:
		patrol_node_total += corridor_points.size()

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
	loop_edges: Array[DungeonEdgeData] = [],
	corridor_edges: Array[DungeonEdgeData] = []
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
	for edge in corridor_edges:
		step_data.corridor_edges.append(edge.duplicate_data())
	debug_timeline.record_step(step_data)

# Samples room candidate cells from a radial distribution around map center.
func generate_cells(cell_count: int, rng: RandomNumberGenerator, config: DungeonFloorConfig, progression_index: int = 0) -> Array[DungeonCellData]:
	var cells: Array[DungeonCellData] = []
	var center := Vector2(config.width * 0.5, config.height * 0.5)
	for _i in cell_count:
		var angle := rng.randf() * TAU
		var dist : float = config.spawn_radius * sqrt(rng.randf())
		var pos := center + Vector2(cos(angle), sin(angle)).normalized() * dist
		
		pos = pos.round()
		
		var mean: float = (config.min_room_size + float(config.room_max_size)) * 0.5
		var room_w: float = clampf(rng.randfn(mean, float(config.room_size_deviation)), config.min_room_size, float(config.room_max_size))
		var room_h: float = clampf(rng.randfn(mean, float(config.room_size_deviation)), config.min_room_size, float(config.room_max_size))
		var rect: Rect2i = _build_cell_rect_from_dimensions(pos, room_w, room_h)
		cells.append(DungeonCellData.new(_snap_rect_to_grid(rect), false, false, null))

	_assign_special_room_cells(cells, rng, config, progression_index)
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
				while rect_a.intersects(rect_b):
					overlaps += 1
					var _dir := Vector2(rect_a.position - rect_b.position)
					if _dir.is_zero_approx():
						_dir = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
					var _push_dir := Vector2i(int(round(_dir.x)), int(round(_dir.y)))
					var rect: Rect2i = cells[a].rect
					rect.position += _push_dir
					cells[a].rect = _snap_rect_to_grid(rect)
					rect_a = _grow_rect_i(cells[a].rect, int(SEPARATION_MARGIN))
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

# Selects final rooms from area-qualified standard candidates plus all special rooms.
func designate_rooms(cells: Array[DungeonCellData], config: DungeonFloorConfig) -> Array[DungeonRoomData]:
	var standard_candidates: Array[DungeonRoomData] = []
	var special_rooms: Array[DungeonRoomData] = []
	for cell in cells:
		var room_rect: Rect2i = _snap_rect_to_grid(cell.rect)
		if room_rect.size.x <= 0 or room_rect.size.y <= 0:
			continue
		var area: int = room_rect.size.x * room_rect.size.y
		if not cell.is_special_room and float(area) < config.room_area_threshold:
			continue
		var room_center: Vector2 = Vector2(room_rect.get_center())
		var room_data: DungeonRoomData = DungeonRoomData.new(
			room_rect,
			room_center,
			null,
			cell.is_special_room,
			cell.special_room_script if cell.is_special_room else null
		)
		if cell.is_special_room:
			special_rooms.append(room_data)
		else:
			standard_candidates.append(room_data)

	standard_candidates.sort_custom(
		func(a: DungeonRoomData, b: DungeonRoomData) -> bool:
			var area_a: int = a.rect.size.x * a.rect.size.y
			var area_b: int = b.rect.size.x * b.rect.size.y
			return area_a > area_b
	)

	var clamped_keep_ratio: float = clampf(config.room_keep_ratio, 0.0, 1.0)
	var keep_target: int = int(ceil(float(standard_candidates.size()) * clamped_keep_ratio))
	if clamped_keep_ratio > 0.0:
		keep_target = maxi(keep_target, 1)
	keep_target = mini(keep_target, standard_candidates.size())

	var rooms: Array[DungeonRoomData] = []
	for room_index in range(keep_target):
		rooms.append(standard_candidates[room_index])
	for special_room in special_rooms:
		rooms.append(special_room)
	return rooms

# Allocates and initializes a dense tile grid.
func _create_grid(width: int, height: int, default_tile: int) -> PackedInt32Array:
	var grid := PackedInt32Array()
	grid.resize(width * height)
	for i in grid.size():
		grid[i] = default_tile
	return grid

# Carves one room by dispatching to special-room scripts when available.
func _carve_room_for_data(grid: PackedInt32Array, world_rect: Rect2i, room: DungeonRoomData) -> void:
	if room.is_special_room and room.special_room_script != null:
		var room_carver: DungeonSpecRoomBase = _instantiate_special_room_script(room.special_room_script)
		if room_carver != null:
			room_carver.carve_room(grid, world_rect, room.rect)
			return
	_carve_room(grid, world_rect, room.rect)

# Carves a rectangular room into floor tiles within safe interior bounds.
func _carve_room(grid: PackedInt32Array, world_rect: Rect2i, rect: Rect2i) -> void:
	var start_x: int = rect.position.x - world_rect.position.x
	var start_y: int = rect.position.y - world_rect.position.y
	var end_x: int = rect.end.x - world_rect.position.x
	var end_y: int = rect.end.y - world_rect.position.y
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			_set_tile(grid, int(world_rect.size.x), int(world_rect.size.y), x, y, DungeonBuilderConstants.TILE_FLOOR)

# Carves an L-shaped corridor between two door cells and smooths dense corners.
func _carve_l_corridor_between_doors(grid: PackedInt32Array, width: int, height: int, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var a_cell: Vector2i = a
	var b_cell: Vector2i = b
	if rng.randf() < 0.5:
		_carve_hall_segment(grid, width, height, a_cell.x, b_cell.x, a_cell.y)
		_carve_hall_segment_vertical(grid, width, height, a_cell.y, b_cell.y, b_cell.x)
	else:
		_carve_hall_segment_vertical(grid, width, height, a_cell.y, b_cell.y, a_cell.x)
		_carve_hall_segment(grid, width, height, a_cell.x, b_cell.x, b_cell.y)

	for y in range(mini(a_cell.y, b_cell.y) - 1, maxi(a_cell.y, b_cell.y) + 2):
		for x in range(mini(a_cell.x, b_cell.x) - 1, maxi(a_cell.x, b_cell.x) + 2):
			if _count_floor_neighbors(grid, width, height, x, y) >= 3:
				_set_tile(grid, width, height, x, y, DungeonBuilderConstants.TILE_FLOOR)

# Resolves the cardinal side on source room that faces the target room.
func _resolve_room_side_for_target(source_center: Vector2, target_center: Vector2) -> int:
	var delta: Vector2 = target_center - source_center
	if absf(delta.x) >= absf(delta.y):
		return DungeonSpecRoomBase.SIDE_EAST if delta.x >= 0.0 else DungeonSpecRoomBase.SIDE_WEST
	return DungeonSpecRoomBase.SIDE_SOUTH if delta.y >= 0.0 else DungeonSpecRoomBase.SIDE_NORTH

# Returns opposite cardinal side.
func _opposite_side(side: int) -> int:
	match side:
		DungeonSpecRoomBase.SIDE_NORTH:
			return DungeonSpecRoomBase.SIDE_SOUTH
		DungeonSpecRoomBase.SIDE_SOUTH:
			return DungeonSpecRoomBase.SIDE_NORTH
		DungeonSpecRoomBase.SIDE_EAST:
			return DungeonSpecRoomBase.SIDE_WEST
		DungeonSpecRoomBase.SIDE_WEST:
			return DungeonSpecRoomBase.SIDE_EAST
		_:
			return side

# Counts how many corridor doors each room side needs.
func _build_room_side_door_counts(rooms: Array[DungeonRoomData], edges: Array[DungeonEdgeData]) -> PackedInt32Array:
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(rooms.size() * 4)
	for edge in edges:
		if edge.a < 0 or edge.b < 0 or edge.a >= rooms.size() or edge.b >= rooms.size() or edge.a == edge.b:
			continue
		var side_a: int = _resolve_room_side_for_target(rooms[edge.a].center, rooms[edge.b].center)
		var side_b: int = _opposite_side(side_a)
		var key_a: int = edge.a * 4 + side_a
		var key_b: int = edge.b * 4 + side_b
		counts[key_a] = counts[key_a] + 1
		counts[key_b] = counts[key_b] + 1
	return counts

# Resolves a room boundary cell used as open doorway for one side slot.
func _resolve_room_door_cell(room: DungeonRoomData, side: int, side_slot_index: int, side_slot_total: int) -> Vector2i:
	var rect: Rect2i = room.rect
	var min_x: int = rect.position.x
	var min_y: int = rect.position.y
	var max_x: int = rect.end.x - 1
	var max_y: int = rect.end.y - 1
	var anchor: float = _resolve_room_side_anchor(room, side)

	if side == DungeonSpecRoomBase.SIDE_NORTH or side == DungeonSpecRoomBase.SIDE_SOUTH:
		var door_min_x: int = min_x + 1
		var door_max_x: int = max_x - 1
		if door_min_x > door_max_x:
			door_min_x = min_x
			door_max_x = max_x
		var base_x: int = _resolve_axis_anchor_coordinate(door_min_x, door_max_x, anchor)
		if side_slot_total > 1 and door_max_x > door_min_x:
			var span_x: int = door_max_x - door_min_x
			var slot_step_x: float = maxf(float(span_x) / float(side_slot_total), 1.0)
			var slot_offset_x: float = (float(side_slot_index) - float(side_slot_total - 1) * 0.5) * slot_step_x
			base_x = clampi(int(round(float(base_x) + slot_offset_x)), door_min_x, door_max_x)
		var door_y: int = min_y if side == DungeonSpecRoomBase.SIDE_NORTH else max_y
		return Vector2i(base_x, door_y)

	var door_min_y: int = min_y + 1
	var door_max_y: int = max_y - 1
	if door_min_y > door_max_y:
		door_min_y = min_y
		door_max_y = max_y
	var base_y: int = _resolve_axis_anchor_coordinate(door_min_y, door_max_y, anchor)
	if side_slot_total > 1 and door_max_y > door_min_y:
		var span_y: int = door_max_y - door_min_y
		var slot_step_y: float = maxf(float(span_y) / float(side_slot_total), 1.0)
		var slot_offset_y: float = (float(side_slot_index) - float(side_slot_total - 1) * 0.5) * slot_step_y
		base_y = clampi(int(round(float(base_y) + slot_offset_y)), door_min_y, door_max_y)
	var door_x: int = max_x if side == DungeonSpecRoomBase.SIDE_EAST else min_x
	return Vector2i(door_x, base_y)

# Resolves preferred anchor for one room side, using special-room script when available.
func _resolve_room_side_anchor(room: DungeonRoomData, side: int) -> float:
	if room.is_special_room and room.special_room_script != null:
		var room_carver: DungeonSpecRoomBase = _instantiate_special_room_script(room.special_room_script)
		if room_carver != null:
			return room_carver.get_oriented_preferred_door_anchor(side, room.rect)
	return 0.5

# Converts a normalized side anchor into a clamped integer axis coordinate.
func _resolve_axis_anchor_coordinate(min_value: int, max_value: int, anchor: float) -> int:
	if min_value >= max_value:
		return min_value
	var clamped_anchor: float = clampf(anchor, 0.0, 1.0)
	return clampi(int(round(lerpf(float(min_value), float(max_value), clamped_anchor))), min_value, max_value)

# Carves a horizontal hallway segment with configurable thickness.
func _carve_hall_segment(grid: PackedInt32Array, width: int, _height: int, from_x: int, to_x: int, y: int) -> void:
	var step := 1 if to_x >= from_x else -1
	var x := from_x
	while true:
		for t in range(-1, 2):
			_set_tile(grid, width, _height, x, y + t, DungeonBuilderConstants.TILE_FLOOR)
		if x == to_x:
			break
		x += step

# Carves a vertical hallway segment with configurable thickness.
func _carve_hall_segment_vertical(grid: PackedInt32Array, width: int, _height: int, from_y: int, to_y: int, x: int) -> void:
	var step := 1 if to_y >= from_y else -1
	var y := from_y
	while true:
		for t in range(-1, 2):
			_set_tile(grid, width, _height, x + t, y, DungeonBuilderConstants.TILE_FLOOR)
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
			if _get_tile(grid, width, x + ox, y + oy) == DungeonBuilderConstants.TILE_FLOOR:
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
		return DungeonBuilderConstants.TILE_WALL
	var height := int(float(grid.size()) / float(width))
	if x >= width or y >= height:
		return DungeonBuilderConstants.TILE_WALL
	var index := y * width + x
	if index < 0 or index >= grid.size():
		return DungeonBuilderConstants.TILE_WALL
	return grid[index]

# Force-writes map perimeter cells as wall tiles.
func _enforce_border_walls(grid: PackedInt32Array, width: int, height: int) -> void:
	if width < 2 or height < 2:
		return
	for x in range(width):
		grid[x] = DungeonBuilderConstants.TILE_WALL
		grid[(height - 1) * width + x] = DungeonBuilderConstants.TILE_WALL
	for y in range(height):
		grid[y * width] = DungeonBuilderConstants.TILE_WALL
		grid[y * width + (width - 1)] = DungeonBuilderConstants.TILE_WALL

# Assigns special-room tags and scripts to a fixed number of generated cells.
func _assign_special_room_cells(cells: Array[DungeonCellData], rng: RandomNumberGenerator, config: DungeonFloorConfig, progression_index: int) -> void:
	if cells.is_empty():
		return
	if config.special_room_target_count <= 0:
		return

	var floor_pool_entry: DungeonSpecialRoomFloorPoolEntry = null
	if config.special_room_floor_pool_list != null:
		if config.special_room_floor_pool_list.has_method("resolve_for_progression_index"):
			floor_pool_entry = config.special_room_floor_pool_list.resolve_for_progression_index(progression_index)
	if floor_pool_entry == null or floor_pool_entry.pool == null:
		return

	var eligible_entries: Array[DungeonSpecialRoomWeightedEntry] = floor_pool_entry.pool.get_eligible_entries()
	if eligible_entries.is_empty():
		return

	var target_count: int = mini(config.special_room_target_count, cells.size())
	var spawn_chance: float = clampf(floor_pool_entry.special_spawn_chance, 0.0, 1.0)
	var spawn_count: int = 0
	for _slot in target_count:
		if rng.randf() <= spawn_chance:
			spawn_count += 1
	if spawn_count <= 0 and spawn_chance > 0.0:
		spawn_count = 1
	spawn_count = mini(spawn_count, cells.size())
	if spawn_count <= 0:
		return

	var indices: Array[int] = []
	for cell_index in range(cells.size()):
		indices.append(cell_index)
	for i in range(indices.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, i)
		var tmp_index: int = indices[i]
		indices[i] = indices[swap_index]
		indices[swap_index] = tmp_index

	for i in range(spawn_count):
		var cell_index: int = indices[i]
		var selected_entry: DungeonSpecialRoomWeightedEntry = _pick_weighted_special_room_entry(eligible_entries, rng)
		if selected_entry == null:
			continue
		var special_room: DungeonSpecRoomBase = selected_entry.instantiate_room()
		if special_room == null:
			continue

		var cell: DungeonCellData = cells[cell_index]
		var center: Vector2 = cell.rect.get_center()
		cell.rect = _create_special_room_rect(center, special_room, rng)
		cell.is_special_room = true
		cell.special_room_script = selected_entry.room_script
		cells[cell_index] = cell

# Picks one weighted special-room entry from a list of eligible entries.
func _pick_weighted_special_room_entry(eligible_entries: Array[DungeonSpecialRoomWeightedEntry], rng: RandomNumberGenerator) -> DungeonSpecialRoomWeightedEntry:
	if eligible_entries.is_empty():
		return null
	var total_weight: int = 0
	for entry in eligible_entries:
		total_weight += maxi(entry.weight, 0)
	if total_weight <= 0:
		return null

	var pick: int = rng.randi_range(0, total_weight - 1)
	var cumulative_weight: int = 0
	for entry in eligible_entries:
		cumulative_weight += maxi(entry.weight, 0)
		if pick < cumulative_weight:
			return entry
	return eligible_entries[eligible_entries.size() - 1]

# Builds one rect around a center using room width/height sampled from float dimensions.
func _build_cell_rect_from_dimensions(center: Vector2, room_w: float, room_h: float) -> Rect2i:
	var snapped_width: int = maxi(int(round(room_w)), 2)
	var snapped_height: int = maxi(int(round(room_h)), 2)
	if snapped_width % 2 != 0:
		snapped_width += 1
	if snapped_height % 2 != 0:
		snapped_height += 1
	var rect_position := Vector2i(
		int(round(center.x - float(snapped_width) * 0.5)),
		int(round(center.y - float(snapped_height) * 0.5))
	)
	return Rect2i(rect_position, Vector2i(snapped_width, snapped_height))

# Creates one special-room cell rect using the selected spec-room sizing parameters.
func _create_special_room_rect(center: Vector2, special_room: DungeonSpecRoomBase, rng: RandomNumberGenerator) -> Rect2i:
	var safe_min_size: int = maxi(special_room.min_size, 2)
	var safe_max_size: int = maxi(special_room.max_size, safe_min_size)
	var safe_min_ratio: float = clampf(special_room.min_ratio, 0.1, 1.0)
	var safe_max_ratio: float = clampf(special_room.max_ratio, safe_min_ratio, 1.0)

	var long_size: int = rng.randi_range(safe_min_size, safe_max_size)
	if long_size % 2 != 0:
		long_size += 1
	var ratio: float = rng.randf_range(safe_min_ratio, safe_max_ratio)
	var short_size: int = maxi(int(round(float(long_size) * ratio)), 2)
	if short_size % 2 != 0:
		short_size += 1

	var width: int = long_size
	var height: int = short_size
	if rng.randf() < 0.5:
		width = short_size
		height = long_size

	return _build_cell_rect_from_dimensions(center, float(width), float(height))

# Resolves a marker on a walkable tile within the room, with a global floor fallback.
func _resolve_accessible_marker_for_room(
	grid: PackedInt32Array,
	width: int,
	height: int,
	world_offset: Vector2i,
	room: DungeonRoomData
) -> Vector2:
	var local_min_x: int = clampi(room.rect.position.x - world_offset.x, 0, width - 1)
	var local_min_y: int = clampi(room.rect.position.y - world_offset.y, 0, height - 1)
	var local_max_x: int = clampi(room.rect.end.x - world_offset.x - 1, 0, width - 1)
	var local_max_y: int = clampi(room.rect.end.y - world_offset.y - 1, 0, height - 1)

	var center_local: Vector2i = Vector2i(
		clampi(int(round(room.center.x - world_offset.x)), 0, width - 1),
		clampi(int(round(room.center.y - world_offset.y)), 0, height - 1)
	)

	var found_floor: bool = false
	var best_dist: float = INF
	var best_cell: Vector2i = center_local
	for y in range(local_min_y, local_max_y + 1):
		for x in range(local_min_x, local_max_x + 1):
			if _get_tile(grid, width, x, y) != DungeonBuilderConstants.TILE_FLOOR:
				continue
			var dx: float = float(x - center_local.x)
			var dy: float = float(y - center_local.y)
			var dist: float = dx * dx + dy * dy
			if not found_floor or dist < best_dist:
				found_floor = true
				best_dist = dist
				best_cell = Vector2i(x, y)

	if not found_floor:
		best_cell = _find_nearest_floor_tile(grid, width, height, center_local)

	return Vector2(best_cell.x + world_offset.x, best_cell.y + world_offset.y)

# Finds the nearest walkable floor tile in the whole map to a local-grid origin.
func _find_nearest_floor_tile(grid: PackedInt32Array, width: int, height: int, origin: Vector2i) -> Vector2i:
	var found_floor: bool = false
	var best_dist: float = INF
	var best_cell: Vector2i = origin
	for y in range(height):
		for x in range(width):
			if _get_tile(grid, width, x, y) != DungeonBuilderConstants.TILE_FLOOR:
				continue
			var dx: float = float(x - origin.x)
			var dy: float = float(y - origin.y)
			var dist: float = dx * dx + dy * dy
			if not found_floor or dist < best_dist:
				found_floor = true
				best_dist = dist
				best_cell = Vector2i(x, y)
	return best_cell

# Instantiates a special-room script and validates the expected base type.
func _instantiate_special_room_script(room_script: Script) -> DungeonSpecRoomBase:
	if room_script == null:
		return null
	if not room_script.can_instantiate():
		return null
	if not room_script.has_method("new"):
		return null
	var instance: Variant = room_script.new()
	if instance is DungeonSpecRoomBase:
		return instance as DungeonSpecRoomBase
	return null

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
	corridor_edges: Array[DungeonEdgeData],
	grid: PackedInt32Array,
	grid_width: int,
	grid_height: int,
	world_offset: Vector2i,
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
		var room_carver: DungeonSpecRoomBase = null
		if room.is_special_room and room.special_room_script != null:
			room_carver = _instantiate_special_room_script(room.special_room_script)
		var linked_rooms: PackedInt32Array = PackedInt32Array()
		if i >= 0 and i < room_adjacency.size():
			linked_rooms = room_adjacency[i]
		var custom_patrol_points: PackedVector2Array = PackedVector2Array()
		if room_carver != null:
			custom_patrol_points = room_carver.build_custom_patrol_points(room.rect, patrol_point_padding, rng)
		if custom_patrol_points.is_empty():
			var patrol_point_count: int = _resolve_patrol_point_count(patrol_nodes_per_room_min, patrol_nodes_per_room_max, rng)
			metadata.patrol_points = _build_patrol_points_for_room(
				room.rect,
				patrol_point_count,
				patrol_point_padding,
				patrol_point_jitter,
				rng
			)
		else:
			metadata.patrol_points = custom_patrol_points
		metadata.patrol_linked_rooms = linked_rooms

		if metadata.is_enemy_room:
			var custom_spawn_points: PackedVector2Array = PackedVector2Array()
			if room_carver != null:
				custom_spawn_points = room_carver.build_custom_enemy_spawn_points(room.rect, patrol_point_padding, rng)
			if custom_spawn_points.is_empty():
				marker_data.enemy.push_back(_resolve_accessible_marker_for_room(grid, grid_width, grid_height, world_offset, room))
			else:
				for spawn_point in custom_spawn_points:
					var resolved_point: Vector2 = _resolve_accessible_marker_near_world_point(
						grid,
						grid_width,
						grid_height,
						world_offset,
						spawn_point
					)
					marker_data.enemy.push_back(resolved_point)

	var corridor_nodes: Array[PackedVector2Array] = []
	for corridor_edge in corridor_edges:
		if corridor_edge.a < 0 or corridor_edge.b < 0:
			continue
		if corridor_edge.a >= rooms.size() or corridor_edge.b >= rooms.size() or corridor_edge.a == corridor_edge.b:
			continue
		var corridor_points: PackedVector2Array = _build_patrol_points_for_corridor(
			rooms[corridor_edge.a].center,
			rooms[corridor_edge.b].center,
			patrol_point_jitter,
			rng
		)
		var resolved_corridor_points: PackedVector2Array = PackedVector2Array()
		for corridor_point in corridor_points:
			resolved_corridor_points.push_back(
				_resolve_accessible_marker_near_world_point(
					grid,
					grid_width,
					grid_height,
					world_offset,
					corridor_point
				)
			)
		if resolved_corridor_points.is_empty():
			resolved_corridor_points.push_back(_resolve_accessible_marker_near_world_point(
				grid,
				grid_width,
				grid_height,
				world_offset,
				(rooms[corridor_edge.a].center + rooms[corridor_edge.b].center) * 0.5
			))
		corridor_nodes.append(resolved_corridor_points)
		if rng.randf() <= 0.5:
			var midpoint_index: int = int(floor(float(resolved_corridor_points.size()) * 0.5))
			midpoint_index = clampi(midpoint_index, 0, resolved_corridor_points.size() - 1)
			marker_data.enemy_corridor.push_back(resolved_corridor_points[midpoint_index])

	var annotation_data: DungeonAnnotationData = DungeonAnnotationData.new()
	annotation_data.spawn_markers = marker_data
	annotation_data.patrol_graph = _build_patrol_graph_payload(rooms, room_adjacency, mst_edges, corridor_edges, corridor_nodes)
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

# Generates patrol points along corridor centerline between two rooms.
func _build_patrol_points_for_corridor(from_center: Vector2, to_center: Vector2, jitter: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for t in [0.25, 0.5, 0.75]:
		var centerline: Vector2 = from_center.lerp(to_center, t)
		var offset: Vector2 = Vector2(
			rng.randf_range(-jitter, jitter),
			rng.randf_range(-jitter, jitter)
		)
		points.push_back(centerline + offset)
	return points

# Resolves nearest floor marker to a desired world-grid point.
func _resolve_accessible_marker_near_world_point(
	grid: PackedInt32Array,
	width: int,
	height: int,
	world_offset: Vector2i,
	world_point: Vector2
) -> Vector2:
	if width <= 0 or height <= 0:
		return world_point
	var local_origin: Vector2i = Vector2i(
		clampi(int(round(world_point.x - world_offset.x)), 0, width - 1),
		clampi(int(round(world_point.y - world_offset.y)), 0, height - 1)
	)
	var local_floor: Vector2i = _find_nearest_floor_tile(grid, width, height, local_origin)
	return Vector2(local_floor.x + world_offset.x, local_floor.y + world_offset.y)

# Builds serialized patrol graph payload used by builders and debug consumers.
func _build_patrol_graph_payload(
	rooms: Array[DungeonRoomData],
	room_adjacency: Array[PackedInt32Array],
	mst_edges: Array[DungeonEdgeData],
	corridor_edges: Array[DungeonEdgeData],
	corridor_nodes: Array[PackedVector2Array]
) -> DungeonPatrolGraphData:
	var patrol_graph: DungeonPatrolGraphData = DungeonPatrolGraphData.new()
	for room in rooms:
		patrol_graph.room_nodes.append(room.metadata.patrol_points)
	for corridor_node_points in corridor_nodes:
		patrol_graph.corridor_nodes.append(corridor_node_points)

	for edge in mst_edges:
		if edge.a < 0 or edge.b < 0 or edge.a == edge.b:
			continue
		patrol_graph.room_links.append(DungeonEdgeData.new(edge.a, edge.b, edge.weight))

	for edge in corridor_edges:
		if edge.a < 0 or edge.b < 0 or edge.a == edge.b:
			continue
		patrol_graph.corridor_links.append(DungeonEdgeData.new(edge.a, edge.b, edge.weight))

	for room_links in room_adjacency:
		patrol_graph.room_adjacency.append(room_links)

	return patrol_graph
