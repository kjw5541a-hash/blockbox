extends SceneTree

# 고스트는 칸마다 큐브를 놓는 대신 겉면만 남긴 껍데기 하나로 그린다.
# 안쪽 면이 남으면 반투명 너머로 칸 경계가 비쳐, 붙어 있는 조각인데도
# 한 칸씩 따로 놀아 보인다. 여기서는 그 면 솎아내기가 맞는지 센다.
func _initialize() -> void:
	_test_hull_drops_shared_faces()
	_test_hull_matches_the_cells_it_was_given()
	_test_faces_wind_outward()
	await _test_ghost_is_one_mesh_that_follows_the_piece()
	await _test_piece_is_one_mesh_too()
	print("test_piece_view: OK")
	quit()

func _script():
	return load("res://scripts/piece_view.gd")

# 정점 여섯 개가 사각면 하나(삼각형 둘)다.
func _quads(cells: Array[Vector3i]) -> int:
	var mesh: ArrayMesh = BlockMesh.hull_mesh(cells)
	if mesh.get_surface_count() == 0:
		return 0
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 6

func _test_hull_drops_shared_faces() -> void:
	assert(_quads([Vector3i(0, 0, 0)] as Array[Vector3i]) == 6, "한 칸은 여섯 면")

	# 맞닿은 두 칸은 사이의 면 두 장이 사라진다: 12 - 2 = 10.
	var pair: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0)]
	assert(_quads(pair) == 10, "맞닿은 면은 빠져야 한다: %d" % _quads(pair))

	# 일자 네 칸은 이음매가 셋이라 24 - 6 = 18.
	var bar: Array[Vector3i] = [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0)]
	assert(_quads(bar) == 18, "일자 조각의 겉면은 18: %d" % _quads(bar))

	# 2x2 정사각(O 조각)은 이음매가 넷이라 24 - 8 = 16.
	var square: Array[Vector3i] = [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1)]
	assert(_quads(square) == 16, "2x2 의 겉면은 16: %d" % _quads(square))

	# 떨어져 있는 두 칸은 솎아낼 면이 없다.
	var apart: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(5, 0, 0)]
	assert(_quads(apart) == 12, "떨어진 칸끼리는 면이 줄지 않는다: %d" % _quads(apart))

	# 같은 칸이 두 번 들어와도 겹쳐 그리지 않는다.
	var dup: Array[Vector3i] = [Vector3i(2, 3, 4), Vector3i(2, 3, 4)]
	assert(_quads(dup) == 6, "중복된 칸은 한 번만 그린다: %d" % _quads(dup))

# 껍데기가 실제로 그 칸들을 감싸야 한다. 면 수만 세면 엉뚱한 자리에 그려도
# 통과한다.
func _test_hull_matches_the_cells_it_was_given() -> void:
	var cells: Array[Vector3i] = [Vector3i(2, 5, 1), Vector3i(3, 5, 1)]
	var mesh: ArrayMesh = BlockMesh.hull_mesh(cells)
	var aabb := mesh.get_aabb()
	assert(aabb.position.is_equal_approx(Vector3(1.5, 4.5, 0.5)),
		"껍데기가 칸 자리에서 벗어났다: %s" % aabb.position)
	assert(aabb.size.is_equal_approx(Vector3(2, 1, 1)),
		"두 칸을 감싸면 2x1x1 이어야 한다: %s" % aabb.size)

	# 면이 칸 겉면이 아니라 안쪽에 눌러앉아도 겉넓이는 그대로다. 꼭짓점이
	# 전부 칸 모서리에 있는지 직접 본다 — 한 칸이면 여덟 자리뿐이다.
	var one: ArrayMesh = BlockMesh.hull_mesh([Vector3i(0, 0, 0)] as Array[Vector3i])
	var corners := {}
	for v in one.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		assert(is_equal_approx(absf(v.x), 0.5) and is_equal_approx(absf(v.y), 0.5)
			and is_equal_approx(absf(v.z), 0.5),
			"꼭짓점이 칸 모서리에 있지 않다: %s" % v)
		corners[v] = true
	assert(corners.size() == 8, "한 칸의 꼭짓점은 여덟 자리: %d" % corners.size())

# 뒷면을 지우려면 감는 방향이 맞아야 한다. 틀리면 바깥 면이 뒷면 취급을
# 받아 조각이 통째로 사라진다. Godot 의 규약을 외워 적는 대신 엔진이 만든
# BoxMesh 와 부호를 맞춰 본다.
func _test_faces_wind_outward() -> void:
	var box := BoxMesh.new()
	var arrays := box.get_mesh_arrays()
	var bv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bi: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var want := signf((bv[bi[1]] - bv[bi[0]]).cross(bv[bi[2]] - bv[bi[0]]).dot(bn[bi[0]]))

	var mesh: ArrayMesh = BlockMesh.hull_mesh([Vector3i(0, 0, 0)] as Array[Vector3i])
	var a := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	assert(n.size() == v.size(), "법선이 없으면 빛을 받을 수 없다")
	for t in range(0, v.size(), 3):
		# 법선이 바깥(칸 중심에서 멀어지는 쪽)을 봐야 한다. 한 칸짜리라 중심은 원점.
		assert(n[t].dot(v[t]) > 0.0, "법선이 안쪽을 본다: %s / %s" % [n[t], v[t]])
		var got := signf((v[t + 1] - v[t]).cross(v[t + 2] - v[t]).dot(n[t]))
		assert(got == want,
			"감는 방향이 BoxMesh 와 반대다 — 뒷면을 지우면 조각이 사라진다")

func _test_ghost_is_one_mesh_that_follows_the_piece() -> void:
	var game := Game.new()
	root.add_child(game)
	game.start(7)
	var view = _script().new()
	root.add_child(view)
	await process_frame
	view.setup(game)

	var ghost: MeshInstance3D = view._ghost
	assert(ghost.visible, "고스트가 보여야 한다")
	var mat := ghost.material_override as StandardMaterial3D
	assert(mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "고스트는 반투명")
	assert(is_equal_approx(mat.albedo_color.a, view.GHOST_ALPHA), "고스트 알파가 어긋난다")
	# 양면을 다 그리면 뒤쪽 면까지 겹쳐 비쳐 알파가 두 겹으로 쌓인다. 그러면
	# 면마다 밝기가 뭉개져 안으로 파인 것처럼 보인다. 뒷면은 지우고 빛을
	# 받게 두어야 면마다 밝기가 달라 입체로 읽힌다.
	assert(mat.cull_mode == BaseMaterial3D.CULL_BACK, "고스트는 뒷면을 지워야 한다")
	assert(mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED,
		"빛을 안 받으면 여섯 면이 같은 밝기라 납작해 보인다")

	# 조각을 옮기면 껍데기도 따라와야 한다.
	var before := (ghost.mesh as ArrayMesh).get_aabb()
	assert(game.move(Vector3i(1, 0, 0)), "옆으로 한 칸 옮길 수 있어야 한다")
	var after := (ghost.mesh as ArrayMesh).get_aabb()
	assert(after.position.is_equal_approx(before.position + Vector3(1, 0, 0)),
		"조각을 옮기면 고스트도 같이 옮겨져야 한다: %s -> %s" % [before.position, after.position])

	# 바닥 발자국도 옆 칸과 맞닿아야 한 덩어리로 보인다.
	var mark: MeshInstance3D = view._marks[0]
	assert((mark.mesh as QuadMesh).size.is_equal_approx(Vector2.ONE),
		"발자국 사이에 틈이 있으면 칸이 따로 놀아 보인다: %s" % (mark.mesh as QuadMesh).size)

	game.queue_free()
	view.queue_free()

# 떨어지는 조각도 칸마다 큐브를 놓지 않고 껍데기 하나로 그린다. 큐브를 나란히
# 놓으면 칸 경계마다 그림자 선이 생겨 네 칸이 따로 놀아 보인다.
func _test_piece_is_one_mesh_too() -> void:
	var game := Game.new()
	root.add_child(game)
	game.start(7)
	var view = _script().new()
	root.add_child(view)
	await process_frame
	view.setup(game)

	var cells := game.current.world_cells()
	var solid: MeshInstance3D = view._solid
	assert(solid.visible, "떨어지는 조각이 보여야 한다")
	var mesh := solid.mesh as ArrayMesh
	var faces: int = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 6
	assert(faces < cells.size() * 6,
		"칸끼리 맞닿은 면이 남아 있으면 덩어리로 안 보인다: %d 면" % faces)

	var mn := Piece.bbox_min(cells)
	var mx := Piece.bbox_max(cells)
	var aabb := mesh.get_aabb()
	assert(aabb.position.is_equal_approx(Vector3(mn) - Vector3.ONE * 0.5),
		"조각 껍데기가 칸 자리에서 벗어났다: %s" % aabb.position)
	assert(aabb.size.is_equal_approx(Vector3(mx - mn) + Vector3.ONE),
		"조각 껍데기가 칸을 다 감싸지 못한다: %s" % aabb.size)
	assert(solid.position.is_equal_approx(Vector3.ZERO),
		"껍데기는 격자 좌표 그대로 만든다 — 노드를 또 옮기면 어긋난다")

	game.queue_free()
	view.queue_free()
