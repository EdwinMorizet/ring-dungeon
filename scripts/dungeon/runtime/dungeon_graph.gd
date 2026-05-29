# Provides graph helpers used by dungeon generation for connectivity and edge selection.
extends RefCounted
class_name DungeonGraph

var points := PackedVector2Array()
var edges : Array[DungeonEdgeData] = []
var mst_edges: Array[DungeonEdgeData] = []
var added_loop_edges: Array[DungeonEdgeData] = []

# Relation: Called by DungeonGenerator to produce Delaunay, MST, and optional loop edges.
# Builds undirected weighted edges from room centers using Delaunay triangulation.
func build_delaunay_edges(rooms: Array[DungeonRoomData]) -> Array[DungeonEdgeData]:
	points.clear()
	edges.clear()
	mst_edges.clear()
	added_loop_edges.clear()

	for room in rooms:
		points.push_back(room.center)
	if points.size() < 2:
		return []
	if points.size() == 2:
		return [_make_edge(0, 1)]

	var triangles: PackedInt32Array = Geometry2D.triangulate_delaunay(points)
	if triangles.is_empty():
		return []

	var edge_hashes: Array[int] = []
	for i in range(0, triangles.size(), 3):
		var a: int = triangles[i]
		var b: int = triangles[i + 1]
		var c: int = triangles[i + 2]
		_add_edge_if_missing(edge_hashes, a, b)
		_add_edge_if_missing(edge_hashes, b, c)
		_add_edge_if_missing(edge_hashes, c, a)

	return edges

# Builds a minimum spanning tree from weighted edges using union-find.
func build_mst() -> Array[DungeonEdgeData]:
	if points.is_empty() or edges.is_empty():
		push_error("Graph : build delaunay edges first")
		return []

	var sorted_edges: Array[DungeonEdgeData] = edges.duplicate()
	sorted_edges.sort_custom(func(a: DungeonEdgeData, b: DungeonEdgeData) -> bool:
		return a.weight < b.weight
	)

	var parent: Array[int] = []
	for i in points.size():
		parent.append(i)

	var mst: Array[DungeonEdgeData] = []
	for edge in sorted_edges:
		var u: int = edge.a
		var v: int = edge.b
		if _find(parent, u) != _find(parent, v):
			_union(parent, u, v)
			mst.append(edge)
			if mst.size() >= points.size() - 1:
				break
	mst_edges = mst
	return mst

# Adds a randomized subset of non-MST edges to create dungeon loops.
func add_loop_edges(loop_percent: float, rng: RandomNumberGenerator) -> Array[DungeonEdgeData]:
	if edges.is_empty() or mst_edges.is_empty():
		push_error("Graph : build delaunay edges and mst first")
		return []

	var result: Array[DungeonEdgeData] = mst_edges.duplicate()
	var mst_hashes: Array[int] = []
	for edge in mst_edges:
		mst_hashes.append(_edge_hash(edge.a, edge.b))

	var candidates: Array[DungeonEdgeData] = []
	for edge in edges:
		if not _contains_edge_hash(mst_hashes, _edge_hash(edge.a, edge.b)):
			candidates.append(edge)

	if candidates.is_empty():
		return result

	var to_add := int(round(float(candidates.size()) * clampf(loop_percent, 0.0, 1.0)))
	to_add = clampi(to_add, 0, candidates.size())

	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	for i in range(to_add):
		added_loop_edges.append(candidates[i])
		result.append(candidates[i])

	return result

# Inserts one undirected edge if that edge has not been registered yet.
func _add_edge_if_missing(edge_hashes: Array[int], a: int, b: int) -> void:
	if a == b:
		return
	var hash_key: int = _edge_hash(a, b)
	if _contains_edge_hash(edge_hashes, hash_key):
		return
	edge_hashes.append(hash_key)
	edges.append(_make_edge(a, b))

# Normalizes endpoint order and computes Euclidean edge weight.
func _make_edge(a: int, b: int) -> DungeonEdgeData:
	var ai := mini(a, b)
	var bi := maxi(a, b)
	return DungeonEdgeData.new(ai, bi, points[ai].distance_to(points[bi]))

# Produces a stable hash key used to deduplicate undirected edges.
func _edge_hash(a: int, b: int) -> int:
	var ai := mini(a, b)
	var bi := maxi(a, b)
	return (ai << 32) ^ bi

# Returns true when an edge hash is already present in the lookup array.
func _contains_edge_hash(edge_hashes: Array[int], hash_key: int) -> bool:
	for existing_hash in edge_hashes:
		if existing_hash == hash_key:
			return true
	return false

# Finds the representative of a union-find set with path compression.
func _find(parent: Array[int], i: int) -> int:
	if parent[i] != i:
		parent[i] = _find(parent, parent[i])
	return parent[i]

# Merges two union-find sets when they are currently disconnected.
func _union(parent: Array[int], a: int, b: int) -> void:
	var root_a := _find(parent, a)
	var root_b := _find(parent, b)
	if root_a != root_b:
		parent[root_b] = root_a
