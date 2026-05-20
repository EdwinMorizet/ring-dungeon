extends RefCounted
class_name DungeonGraph

func build_delaunay_edges(points: PackedVector2Array) -> Array:
	if points.size() < 2:
		return []
	if points.size() == 2:
		return [_make_edge(0, 1, points)]

	var triangles: PackedInt32Array = Geometry2D.triangulate_delaunay(points)
	if triangles.is_empty():
		return []

	var edge_map := {}
	for i in range(0, triangles.size(), 3):
		var a: int = triangles[i]
		var b: int = triangles[i + 1]
		var c: int = triangles[i + 2]
		_add_edge_if_missing(edge_map, a, b, points)
		_add_edge_if_missing(edge_map, b, c, points)
		_add_edge_if_missing(edge_map, c, a, points)

	return edge_map.values()

func build_mst(points: PackedVector2Array, edges: Array) -> Array:
	if points.is_empty() or edges.is_empty():
		return []

	var sorted_edges := edges.duplicate()
	sorted_edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["weight"] < b["weight"]
	)

	var parent: Array[int] = []
	for i in points.size():
		parent.append(i)

	var mst: Array = []
	for edge in sorted_edges:
		var u: int = edge["a"]
		var v: int = edge["b"]
		if _find(parent, u) != _find(parent, v):
			_union(parent, u, v)
			mst.append(edge)
			if mst.size() >= points.size() - 1:
				break

	return mst

func add_loop_edges(edges: Array, mst_edges: Array, loop_percent: float, rng: RandomNumberGenerator) -> Array:
	if edges.is_empty():
		return []

	var result := mst_edges.duplicate()
	var mst_lookup := {}
	for edge in mst_edges:
		mst_lookup[_edge_key(edge["a"], edge["b"])] = true

	var candidates: Array = []
	for edge in edges:
		if not mst_lookup.has(_edge_key(edge["a"], edge["b"])):
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
		result.append(candidates[i])

	return result

func _add_edge_if_missing(edge_map: Dictionary, a: int, b: int, points: PackedVector2Array) -> void:
	if a == b:
		return
	var key := _edge_key(a, b)
	if edge_map.has(key):
		return
	edge_map[key] = _make_edge(a, b, points)

func _make_edge(a: int, b: int, points: PackedVector2Array) -> Dictionary:
	var ai := mini(a, b)
	var bi := maxi(a, b)
	return {
		"a": ai,
		"b": bi,
		"weight": points[ai].distance_to(points[bi])
	}

func _edge_key(a: int, b: int) -> String:
	var ai := mini(a, b)
	var bi := maxi(a, b)
	return "%s:%s" % [ai, bi]

func _find(parent: Array[int], i: int) -> int:
	if parent[i] != i:
		parent[i] = _find(parent, parent[i])
	return parent[i]

func _union(parent: Array[int], a: int, b: int) -> void:
	var root_a := _find(parent, a)
	var root_b := _find(parent, b)
	if root_a != root_b:
		parent[root_b] = root_a
