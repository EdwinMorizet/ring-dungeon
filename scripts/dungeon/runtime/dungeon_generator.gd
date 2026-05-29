# Generates dungeon layout data such as rooms, corridors, and tile maps.
extends RefCounted
class_name DungeonGenerator

# Relation: Driven by DungeonFloorController and delegates graph work to DungeonGraph.

# Runs the full generation pipeline and returns layout, markers, patrol graph, and stats.
func generate(
	seed_value: int,
	config: DungeonFloorConfig,
	debug_timeline: DungeonGeneratorDebugTimeline = null,
	progression_index: int = 0
) -> DungeonLayoutData:
	# Init random seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	seed(seed_value)

	# Spawn cells
	var cells: Array[DungeonCellData] = _generate_cells(rng, config, progression_index)
	_record_debug_step(debug_timeline, DungeonGeneratorDebugStepConstants.DEBUG_STEP_GENERATE_CELLS, cells)

	# Separate overlapping cells
	_separate_cells(cells, config, rng)
	_record_debug_step(debug_timeline, DungeonGeneratorDebugStepConstants.DEBUG_STEP_SEPARATE_CELLS, cells)

	# Calculate world size
	var world_rect: Rect2i = _compute_world_rect(cells)
	var grid := _create_grid(world_rect)

	# Isolate rooms
	var rooms: Array[DungeonRoomData] = designate_rooms(cells)
	_record_debug_step(debug_timeline, DungeonGeneratorDebugStepConstants.DEBUG_STEP_DESIGNATE_ROOMS, cells, rooms)
	
	# Build Delaunay triangulation
	var graph: DungeonGraph = DungeonGraph.new()
	var delaunay_edges: Array[DungeonEdgeData] = graph.build_delaunay_edges(rooms)
	_record_debug_step(debug_timeline, DungeonGeneratorDebugStepConstants.DEBUG_STEP_DELAUNAY, cells, rooms, delaunay_edges)

	# Calculate Minimum Span Tree
	var mst_edges: Array[DungeonEdgeData] = graph.build_mst()
	_record_debug_step(debug_timeline, DungeonGeneratorDebugStepConstants.DEBUG_STEP_MST, cells, rooms, delaunay_edges, mst_edges)

	# Create path loops
	var corridor_edges: Array[DungeonEdgeData] = graph.add_loop_edges(config.loop_percent, rng)
	var loop_edges: Array[DungeonEdgeData] = graph.added_loop_edges
	_record_debug_step(debug_timeline, DungeonGeneratorDebugStepConstants.DEBUG_STEP_LOOP_EDGES, cells, rooms, delaunay_edges, mst_edges, loop_edges)

	_carve_rooms(grid, world_rect, rooms)

	var corridor_paths: Array[PackedVector2Array] = _carve_corridor_doors_and_paths(grid, world_rect, rooms, corridor_edges)
	_record_debug_step(debug_timeline, DungeonGeneratorDebugStepConstants.DEBUG_STEP_CORRIDORS_01, cells, rooms, delaunay_edges, mst_edges, loop_edges, corridor_edges, corridor_paths)

	_reclaim_discarded_standard_rooms_after_corridors(
		cells,
		rooms,
		corridor_paths,
		config,
		rng
	)
	_record_debug_step(debug_timeline, DungeonGeneratorDebugStepConstants.DEBUG_STEP_CORRIDORS_02, cells, rooms, delaunay_edges, mst_edges, loop_edges, corridor_edges, corridor_paths)

	var exit_index := _find_farthest_room_index(rooms)
	var start_index := _find_farthest_from_room_index(rooms, exit_index)

	var annotation_data: DungeonAnnotationData = _annotate_rooms_with_metadata(
		rooms,
		start_index,
		exit_index,
		mst_edges,
		corridor_edges,
		grid,
		world_rect,
		rng,
		config
	)
	var marker_data: DungeonSpawnMarkersData = annotation_data.spawn_markers
	var start_marker: Vector2 = _resolve_accessible_marker_for_room(
		grid,
		world_rect,
		rooms[start_index]
	)
	marker_data.player_start = PackedVector2Array([start_marker])
	
	var exit_marker: Vector2 = _resolve_accessible_marker_for_room(
		grid,
		world_rect,
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

	var layout: DungeonLayoutData = DungeonLayoutData.new(world_rect)
	layout.grid = grid
	layout.rooms = rooms
	layout.edges = delaunay_edges
	layout.mst_edges = mst_edges
	layout.corridor_edges = corridor_edges
	layout.start_room_index = start_index
	layout.exit_room_index = exit_index
	layout.spawn_markers = marker_data
	layout.patrol_graph = patrol_graph
	layout.stats = stats
	if debug_timeline != null:
		debug_timeline.set_final_layout(layout)
		_record_debug_step(debug_timeline, DungeonGeneratorDebugStepConstants.DEBUG_STEP_FULL_GRID, cells, rooms, delaunay_edges, mst_edges, loop_edges, corridor_edges, corridor_paths, grid, world_rect)
		_record_debug_step(debug_timeline, DungeonGeneratorDebugStepConstants.DEBUG_STEP_FULL_GRID_PATROL, cells, rooms, delaunay_edges, mst_edges, loop_edges, corridor_edges, corridor_paths, grid, world_rect)
		_record_debug_step(debug_timeline, DungeonGeneratorDebugStepConstants.DEBUG_STEP_FULL_GRID_SPAWNS, cells, rooms, delaunay_edges, mst_edges, loop_edges, corridor_edges, corridor_paths, grid, world_rect)
		_record_debug_step(debug_timeline, DungeonGeneratorDebugStepConstants.DEBUG_STEP_FULL_GRID_CHESTS, cells, rooms, delaunay_edges, mst_edges, loop_edges, corridor_edges, corridor_paths, grid, world_rect)
	return layout

# Samples room candidate cells from a radial distribution around map center.
func _generate_cells(rng: RandomNumberGenerator, config: DungeonFloorConfig, progression_index: int = 0) -> Array[DungeonCellData]:
	var floor_pool_entry = config.special_room_floor_pool_list.resolve_for_progression_index(progression_index)
	
	var remaining_specials = config.special_room_target_count
	var cells: Array[DungeonCellData] = []
	for _i in config.cell_count:
		var room: DungeonSpecialRoomWeightedEntry = null
		var is_room: bool = false
		if remaining_specials > 0:
			remaining_specials -= 1
			room = floor_pool_entry.get_random_entrie()
			is_room = true
		else:
			room = floor_pool_entry.get_standard_entrie()
		
		# randomize position and size inside circle radius
		# offset pos by half size and round
		var angle := rng.randf() * TAU
		var dist : float = config.spawn_radius * sqrt(rng.randf())
		var pos := Vector2(cos(angle), sin(angle)).normalized() * dist
		var room_size = room.instantiate_room().get_size(rng)
		pos -= room_size * 0.5
		pos = pos.round()
		var rect: Rect2i = Rect2i(pos, room_size)

		cells.append(DungeonCellData.new((rect), room.room_script, is_room))
	cells.shuffle()
	return cells

# Resolves overlapping room candidates using iterative pairwise push separation.
func _separate_cells(cells: Array[DungeonCellData], config: DungeonFloorConfig, rng: RandomNumberGenerator) -> void:
	# Separate cells
	var overlaps: int = 0
	for i in config.separation_iterations:
		overlaps = 0
		for a in cells.size():
			var _overlaps_dist: float = -1
			var _overlaps_dir: Vector2 = Vector2.ZERO
			for b in cells.size():
				if a == b: continue
				var rect_a: Rect2i = _grow_rect_i(cells[a].rect, config.separation_margin) if cells[a].is_room else cells[a].rect
				var rect_b: Rect2i = _grow_rect_i(cells[b].rect, config.separation_margin) if cells[b].is_room else cells[b].rect
				while rect_a.intersects(rect_b):
					overlaps += 1
					var _dir := Vector2(rect_a.position - rect_b.position).normalized()
					if _dir.is_zero_approx():
						_dir = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
					var _push_dir := Vector2i(roundi(_dir.x), roundi(_dir.y))
					cells[a].rect = Rect2i(cells[a].rect.position + _push_dir, cells[a].rect.size)
					rect_a = _grow_rect_i(cells[a].rect, config.separation_margin)
		if overlaps == 0: break
	# Consolidate to far away cells
	var no_move := true
	for i in config.separation_iterations:
		no_move = true
		for a in cells.size():
			var _dir := Vector2(cells[a].rect.get_center()).normalized()
			if _dir.is_zero_approx(): continue
			var _push_dir := Vector2i(roundi(_dir.x), roundi(_dir.y))
			var rect_a: Rect2i = _grow_rect_i(Rect2i(cells[a].rect.position - _push_dir, cells[a].rect.size), config.separation_margin)  if cells[a].is_room else Rect2i(cells[a].rect.position - _push_dir, cells[a].rect.size)
			var can_move := true
			for b in cells.size():
				if a == b: continue
				var rect_b: Rect2i = _grow_rect_i(cells[b].rect, config.separation_margin) if cells[b].is_room else cells[b].rect
				if rect_a.intersects(rect_b): 
					can_move = false
					break
			if can_move:
				no_move = false
				cells[a].rect = Rect2i(cells[a].rect.position - _push_dir, cells[a].rect.size)
		if no_move: break

# Selects final rooms from area-qualified standard candidates plus all special rooms.
func designate_rooms(cells: Array[DungeonCellData]) -> Array[DungeonRoomData]:
	var rooms: Array[DungeonRoomData] = []
	for cell in cells:
		if not cell.is_room : continue
		var room_rect: Rect2i = cell.rect
		var room_data: DungeonRoomData = DungeonRoomData.new(
			room_rect,
			cell.special_room_script
		)
		rooms.append(room_data)
		
	return rooms

# Computes a merged Rect2i bounds box from typed room entries.
func _compute_world_rect(entries: Array[DungeonCellData]) -> Rect2i:
	var bounds: Rect2i = entries[0].rect
	for entry in entries:
		bounds = bounds.merge(entry.rect)
	
	bounds = bounds.grow(1)
	
	for entry in entries:
		entry.rect = Rect2i(entry.rect.position - bounds.position, entry.rect.size)
		
	var world_bounds: Rect2i = entries[0].rect
	for entry in entries:
		world_bounds = bounds.merge(entry.rect)
	
	return world_bounds

# Allocates and initializes a dense tile grid.
func _create_grid(world_rect:Rect2i) -> PackedInt32Array:
	var grid := PackedInt32Array()
	grid.resize(int(world_rect.size.x) * int(world_rect.size.y))
	grid.fill(0)
	return grid

# Carves rooms by dispatching to special-room scripts.
func _carve_rooms(grid: PackedInt32Array, world_rect: Rect2i, rooms: Array[DungeonRoomData]) -> void:
	for room in rooms:
		var room_carver: DungeonSpecRoomBase = room.special_room_script.new()
		room_carver.carve_room(grid, world_rect, room.rect)

# Carves door endpoints and corridor paths for each valid corridor edge.
func _carve_corridor_doors_and_paths(
	grid: PackedInt32Array,
	world_rect: Rect2i,
	rooms: Array[DungeonRoomData],
	corridor_edges: Array[DungeonEdgeData]
) -> Array[PackedVector2Array]:
	var door_side_totals: PackedInt32Array = _build_room_side_door_counts(rooms, corridor_edges)
	var door_side_used: PackedInt32Array = PackedInt32Array()
	door_side_used.resize(door_side_totals.size())
	var corridor_paths: Array[PackedVector2Array] = []
	var world_width = world_rect.size.x
	var world_height = world_rect.size.y

	for edge in corridor_edges:
		#if edge.a < 0 or edge.b < 0 or edge.a >= rooms.size() or edge.b >= rooms.size() or edge.a == edge.b:
			#continue

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
		var door_a: Vector2i = door_a_world
		var door_b: Vector2i = door_b_world

		_set_tile(grid, world_width, door_a.x, door_a.y, DungeonBuilderConstants.TILE_DOOR)
		_set_tile(grid, world_width, door_b.x, door_b.y, DungeonBuilderConstants.TILE_DOOR)
		var local_corridor_path: Array[Vector2i] = _carve_orthogonal_a_star_corridor_between_doors(grid, world_width, world_height, door_a, door_b)
		var world_corridor_path: PackedVector2Array = PackedVector2Array()
		for local_cell in local_corridor_path:
			world_corridor_path.push_back(Vector2(local_cell))
		corridor_paths.append(world_corridor_path)

	return corridor_paths

# Carves corridors between connected rooms and returns world-space debug corridor paths.
#func _carve_corridors_for_edges(
	#grid: PackedInt32Array,
	#world_width: int,
	#world_height: int,
	#world_rect: Rect2i,
	#rooms: Array[DungeonRoomData],
	#corridor_edges: Array[DungeonEdgeData]
#) -> Array[PackedVector2Array]:
	#var door_side_totals: PackedInt32Array = _build_room_side_door_counts(rooms, corridor_edges)
	#var door_side_used: PackedInt32Array = PackedInt32Array()
	#door_side_used.resize(door_side_totals.size())
	#var corridor_paths: Array[PackedVector2Array] = []
#
	#for edge in corridor_edges:
		##if edge.a < 0 or edge.b < 0 or edge.a >= rooms.size() or edge.b >= rooms.size() or edge.a == edge.b:
			##continue
#
		#var room_a: DungeonRoomData = rooms[edge.a]
		#var room_b: DungeonRoomData = rooms[edge.b]
		#var side_a: int = _resolve_room_side_for_target(room_a.center, room_b.center)
		#var side_b: int = _resolve_room_side_for_target(room_b.center, room_a.center)
#
		#var key_a: int = edge.a * 4 + side_a
		#var key_b: int = edge.b * 4 + side_b
		#var slot_total_a: int = maxi(1, door_side_totals[key_a])
		#var slot_total_b: int = maxi(1, door_side_totals[key_b])
		#var slot_index_a: int = mini(door_side_used[key_a], slot_total_a - 1)
		#var slot_index_b: int = mini(door_side_used[key_b], slot_total_b - 1)
		#door_side_used[key_a] = door_side_used[key_a] + 1
		#door_side_used[key_b] = door_side_used[key_b] + 1
#
		#var door_a_world: Vector2i = _resolve_room_door_cell(room_a, side_a, slot_index_a, slot_total_a)
		#var door_b_world: Vector2i = _resolve_room_door_cell(room_b, side_b, slot_index_b, slot_total_b)
		#var door_a: Vector2i = door_a_world - world_rect.position
		#var door_b: Vector2i = door_b_world - world_rect.position
#
		#_set_tile(grid, world_width, world_height, door_a.x, door_a.y, DungeonBuilderConstants.TILE_DOOR)
		#_set_tile(grid, world_width, world_height, door_b.x, door_b.y, DungeonBuilderConstants.TILE_DOOR)
		#var local_corridor_path: Array[Vector2i] = _carve_orthogonal_a_star_corridor_between_doors(grid, world_width, world_height, door_a, door_b)
		#var world_corridor_path: PackedVector2Array = PackedVector2Array()
		#for local_cell in local_corridor_path:
			#world_corridor_path.push_back(Vector2(local_cell + world_rect.position))
		#corridor_paths.append(world_corridor_path)
#
	#return corridor_paths

# Carves an orthogonal A* corridor that prefers merging into existing corridor tiles.
func _carve_orthogonal_a_star_corridor_between_doors(grid: PackedInt32Array, width: int, height: int, a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = _build_orthogonal_corridor_path(grid, width, height, a, b)
	if path.size() < 2:
		return path
	for i in range(1, path.size() - 1):
		var cell: Vector2i = path[i]
		_set_tile(grid, width, cell.x, cell.y, DungeonBuilderConstants.TILE_CORRIDOR)
	return path

# Re-adds previously discarded standard cells when carved corridors traverse their bounds.
func _reclaim_discarded_standard_rooms_after_corridors(
	cells: Array[DungeonCellData],
	rooms: Array[DungeonRoomData],
	corridor_paths: Array[PackedVector2Array],
	config: DungeonFloorConfig,
	rng: RandomNumberGenerator
) -> void:
	if corridor_paths.is_empty():
		return
	for cell_index in range(cells.size()):
		var cell: DungeonCellData = cells[cell_index]
		if cell.is_room: continue
		var room_rect: Rect2i = cell.rect
		if rng.randf() > config.room_keep_corridor_overlap_chance: continue
		if not _does_any_corridor_path_touch_rect(corridor_paths, room_rect): continue
		rooms.append(DungeonRoomData.new(room_rect, cell.special_room_script))
		cells[cell_index].is_room = true

# Returns true when any carved corridor path includes a cell inside a target rect.
func _does_any_corridor_path_touch_rect(corridor_paths: Array[PackedVector2Array], rect: Rect2i) -> bool:
	for corridor_path in corridor_paths:
		for corridor_cell in corridor_path:
			var tile_x: int = int(round(corridor_cell.x))
			var tile_y: int = int(round(corridor_cell.y))
			if rect.has_point(Vector2i(tile_x, tile_y)):
				return true
	return false

# Builds an orthogonal A* path that prefers existing corridor tiles over fresh wall carving.
func _build_orthogonal_corridor_path(grid: PackedInt32Array, width: int, height: int, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if width <= 0 or height <= 0:
		return path
	if start == goal:
		path.append(start)
		return path

	var total_cells: int = width * height
	var start_index: int = start.y * width + start.x
	var goal_index: int = goal.y * width + goal.x
	if start_index < 0 or start_index >= total_cells or goal_index < 0 or goal_index >= total_cells:
		return path

	var came_from: PackedInt32Array = PackedInt32Array()
	came_from.resize(total_cells)
	for i in range(total_cells):
		came_from[i] = -1

	var g_score: PackedFloat32Array = PackedFloat32Array()
	g_score.resize(total_cells)
	for i in range(total_cells):
		g_score[i] = INF

	var f_score: PackedFloat32Array = PackedFloat32Array()
	f_score.resize(total_cells)
	for i in range(total_cells):
		f_score[i] = INF

	var open_set: Array[int] = [start_index]
	var open_flags: PackedByteArray = PackedByteArray()
	open_flags.resize(total_cells)
	open_flags[start_index] = 1
	var closed_flags: PackedByteArray = PackedByteArray()
	closed_flags.resize(total_cells)

	g_score[start_index] = 0.0
	f_score[start_index] = _resolve_corridor_path_heuristic(start, goal)

	while not open_set.is_empty():
		var best_open_index: int = 0
		var current_index: int = open_set[0]
		var current_f: float = f_score[current_index]
		var current_g: float = g_score[current_index]
		for open_index in range(1, open_set.size()):
			var candidate_index: int = open_set[open_index]
			var candidate_f: float = f_score[candidate_index]
			var candidate_g: float = g_score[candidate_index]
			if candidate_f < current_f or (is_equal_approx(candidate_f, current_f) and candidate_g < current_g):
				best_open_index = open_index
				current_index = candidate_index
				current_f = candidate_f
				current_g = candidate_g

		open_set.remove_at(best_open_index)
		open_flags[current_index] = 0
		if current_index == goal_index:
			return _reconstruct_corridor_path(came_from, start_index, goal_index, width)
		closed_flags[current_index] = 1

		var current_pos: Vector2i = Vector2i(current_index % width, int(current_index / float(width)))
		for offset in DungeonBuilderConstants.CARDINAL_OFFSETS:
			var neighbor_pos: Vector2i = current_pos + offset
			if not _is_corridor_path_walkable(grid, width, height, neighbor_pos, start, goal):
				continue
			var neighbor_index: int = neighbor_pos.y * width + neighbor_pos.x
			if closed_flags[neighbor_index] == 1:
				continue

			var tile_cost: float = _resolve_corridor_path_tile_cost(grid, width, height, neighbor_pos, start, goal)
			if tile_cost >= INF:
				continue

			var tentative_g: float = g_score[current_index] + tile_cost
			if tentative_g >= g_score[neighbor_index]:
				continue

			came_from[neighbor_index] = current_index
			g_score[neighbor_index] = tentative_g
			f_score[neighbor_index] = tentative_g + _resolve_corridor_path_heuristic(neighbor_pos, goal)
			if open_flags[neighbor_index] == 0:
				open_set.append(neighbor_index)
				open_flags[neighbor_index] = 1

	return path

# Reconstructs a path array from the A* parent links.
func _reconstruct_corridor_path(came_from: PackedInt32Array, start_index: int, goal_index: int, width: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current_index: int = goal_index
	while current_index != -1:
		# nocheck
		path.append(Vector2i(current_index % width, int(current_index / float(width))))
		if current_index == start_index:
			path.reverse()
			return path
		current_index = came_from[current_index]
	path.clear()
	return path

# Returns the path heuristic using Manhattan distance so movement stays orthogonal.
func _resolve_corridor_path_heuristic(from_cell: Vector2i, to_cell: Vector2i) -> float:
	return float(abs(from_cell.x - to_cell.x) + abs(from_cell.y - to_cell.y))

# Returns true when a cell can participate in corridor routing.
func _is_corridor_path_walkable(grid: PackedInt32Array, width: int, height: int, cell: Vector2i, start: Vector2i, goal: Vector2i) -> bool:
	if cell == start or cell == goal:
		return true
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return false
	if cell.x == 0 or cell.y == 0 or cell.x == width - 1 or cell.y == height - 1:
		return false
	var tile: int = _get_tile(grid, width, cell.x, cell.y)
	return tile == DungeonBuilderConstants.TILE_WALL or tile == DungeonBuilderConstants.TILE_CORRIDOR or tile == DungeonBuilderConstants.TILE_DOOR

# Returns the weighted traversal cost for a walkable corridor-routing cell.
func _resolve_corridor_path_tile_cost(grid: PackedInt32Array, width: int, _height: int, cell: Vector2i, start: Vector2i, goal: Vector2i) -> float:
	if cell == start or cell == goal:
		return 0.0
	var tile: int = _get_tile(grid, width, cell.x, cell.y)
	if tile == DungeonBuilderConstants.TILE_CORRIDOR:
		return 0.15
	if tile == DungeonBuilderConstants.TILE_DOOR:
		return 0.15
	if tile == DungeonBuilderConstants.TILE_WALL:
		return 1.0
	return INF

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
		#if edge.a < 0 or edge.b < 0 or edge.a >= rooms.size() or edge.b >= rooms.size() or edge.a == edge.b:
			#continue
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
	var room_carver: DungeonSpecRoomBase = room.special_room_script.new()
	return room_carver.get_oriented_preferred_door_anchor(side, room.rect)

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
			_set_tile(grid, width, x, y + t, DungeonBuilderConstants.TILE_CORRIDOR)
		if x == to_x:
			break
		x += step

# Carves a vertical hallway segment with configurable thickness.
func _carve_hall_segment_vertical(grid: PackedInt32Array, width: int, _height: int, from_y: int, to_y: int, x: int) -> void:
	var step := 1 if to_y >= from_y else -1
	var y := from_y
	while true:
		for t in range(-1, 2):
			_set_tile(grid, width, x + t, y, DungeonBuilderConstants.TILE_CORRIDOR)
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
			if _is_floor_like_tile(_get_tile(grid, width, x + ox, y + oy)):
				count += 1
	return count

# Returns true when a tile should behave like walkable floor for room and corridor logic.
func _is_floor_like_tile(tile: int) -> bool:
	return tile == DungeonBuilderConstants.TILE_FLOOR or tile == DungeonBuilderConstants.TILE_CORRIDOR or tile == DungeonBuilderConstants.TILE_DOOR

# Writes a tile value with bounds checks and a permanent one-tile outer wall border.
func _set_tile(grid: PackedInt32Array, width: int, x: int, y: int, tile: int) -> void:
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
	world_rect: Rect2i,
	room: DungeonRoomData
) -> Vector2:
	var world_offset = world_rect.position
	var width = world_rect.size.x
	var height = world_rect.size.y
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
			if not _is_floor_like_tile(_get_tile(grid, width, x, y)):
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
			if not _is_floor_like_tile(_get_tile(grid, width, x, y)):
				continue
			var dx: float = float(x - origin.x)
			var dy: float = float(y - origin.y)
			var dist: float = dx * dx + dy * dy
			if not found_floor or dist < best_dist:
				found_floor = true
				best_dist = dist
				best_cell = Vector2i(x, y)
	return best_cell

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
	mst_edges: Array[DungeonEdgeData],
	corridor_edges: Array[DungeonEdgeData],
	grid: PackedInt32Array,
	world_rect: Rect2i,
	rng: RandomNumberGenerator,
	config: DungeonFloorConfig
	) -> DungeonAnnotationData:
	var world_offset: Vector2i = world_rect.position
	var grid_width: int = world_rect.size.x
	var grid_height: int =  world_rect.size.y
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

	var chest_count := int(round(float(candidate_indices.size()) * clampf(config.chest_candidate_ratio, 0.0, 1.0)))
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
		if room.special_room_script != null:
			room_carver = room.special_room_script.new()
		var linked_rooms: PackedInt32Array = PackedInt32Array()
		if i >= 0 and i < room_adjacency.size():
			linked_rooms = room_adjacency[i]
		var custom_patrol_points: PackedVector2Array = PackedVector2Array()
		if room_carver != null:
			custom_patrol_points = room_carver.build_custom_patrol_points(room.rect,  config.patrol_point_padding, rng)
		if custom_patrol_points.is_empty():
			var patrol_point_count: int = _resolve_patrol_point_count(config.patrol_nodes_per_room_min, config.patrol_nodes_per_room_max, rng)
			metadata.patrol_points = _build_patrol_points_for_room(
				room.rect,
				patrol_point_count,
				 config.patrol_point_padding,
				config.patrol.point.jitter,
				rng
			)
		else:
			metadata.patrol_points = custom_patrol_points
		metadata.patrol_linked_rooms = linked_rooms

		if metadata.is_enemy_room:
			var custom_spawn_points: PackedVector2Array = PackedVector2Array()
			if room_carver != null:
				custom_spawn_points = room_carver.build_custom_enemy_spawn_points(room.rect,  config.patrol_point_padding, rng)
			if custom_spawn_points.is_empty():
				marker_data.enemy.push_back(_resolve_accessible_marker_for_room(grid, world_rect, room))
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
			config.patrol.point.jitter,
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

# Records one generation step into the optional editor-only debug timeline.
func _record_debug_step(
	debug_timeline: DungeonGeneratorDebugTimeline,
	step_name: StringName,
	cells: Array[DungeonCellData] = [],
	rooms: Array[DungeonRoomData] = [],
	delaunay_edges: Array[DungeonEdgeData] = [],
	mst_edges: Array[DungeonEdgeData] = [],
	loop_edges: Array[DungeonEdgeData] = [],
	corridor_edges: Array[DungeonEdgeData] = [],
	corridor_paths: Array[PackedVector2Array] = [],
	grid: PackedInt32Array = PackedInt32Array(),
	world_rect: Rect2i = Rect2i()
) -> void:
	if debug_timeline == null:
		return
	var grid_width: int = world_rect.size.x
	var grid_height: int =  world_rect.size.y
	var grid_offset: Vector2i = world_rect.position
	var step_data: DungeonGeneratorDebugStepData = DungeonGeneratorDebugStepData.new()
	step_data.step_name = step_name
	step_data.cells = cells.duplicate(true)
	#for cell in cells:
		#step_data.cells.append(cell.duplicate_data())
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
	for corridor_path in corridor_paths:
		var path_snapshot: PackedVector2Array = PackedVector2Array()
		for cell in corridor_path:
			path_snapshot.push_back(cell)
		step_data.corridor_paths.append(path_snapshot)
	step_data.grid_width = grid_width
	step_data.grid_height = grid_height
	step_data.grid_offset = grid_offset
	if not grid.is_empty():
		step_data.grid = grid.duplicate()
	debug_timeline.record_step(step_data)
