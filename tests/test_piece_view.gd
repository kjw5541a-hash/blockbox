extends SceneTree

# 고스트는 칸마다 큐브를 놓는 대신 겉면만 남긴 껍데기 하나로 그린다.
# 안쪽 면이 남으면 반투명 너머로 칸 경계가 비쳐, 붙어 있는 조각인데도
# 한 칸씩 따로 놀아 보인다. 여기서는 그 면 솎아내기가 맞는지 센다.
func _initialize() -> void:
	_test_hull_drops_shared_faces()
	_test_hull_matches_the_cells_it_was_given()
	await _test_ghost_is_one_mesh_that_follows_the_piece()
	print("test_piece_view: OK")
	quit()

func _script():
	return load("res://scripts/piece_view.gd")

# 정점 여섯 개가 사각면 하나(삼각형 둘)다.
func _quads(cells: Array[Vector3i]) -> int:
	var mesh: ArrayMesh = _script().hull_mesh(cells)
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
	var mesh: ArrayMesh = _script().hull_mesh(cells)
	var aabb := mesh.get_aabb()
	assert(aabb.position.is_equal_approx(Vector3(1.5, 4.5, 0.5)),
		"껍데기가 칸 자리에서 벗어났다: %s" % aabb.position)
	assert(aabb.size.is_equal_approx(Vector3(2, 1, 1)),
		"두 칸을 감싸면 2x1x1 이어야 한다: %s" % aabb.size)

	# 면이 칸 겉면이 아니라 안쪽에 눌러앉아도 겉넓이는 그대로다. 꼭짓점이
	# 전부 칸 모서리에 있는지 직접 본다 — 한 칸이면 여덟 자리뿐이다.
	var one: ArrayMesh = _script().hull_mesh([Vector3i(0, 0, 0)] as Array[Vector3i])
	var corners := {}
	for v in one.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		assert(is_equal_approx(absf(v.x), 0.5) and is_equal_approx(absf(v.y), 0.5)
			and is_equal_approx(absf(v.z), 0.5),
			"꼭짓점이 칸 모서리에 있지 않다: %s" % v)
		corners[v] = true
	assert(corners.size() == 8, "한 칸의 꼭짓점은 여덟 자리: %d" % corners.size())

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
	# 껍데기는 앞뒤 면이 두 겹으로 겹친다. 한쪽을 지우면 감는 방향에 따라
	# 통째로 사라질 수 있어 양면을 다 그려야 한다.
	assert(mat.cull_mode == BaseMaterial3D.CULL_DISABLED, "고스트는 양면을 그려야 한다")

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
