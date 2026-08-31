extends SceneTree

func _initialize() -> void:
	_test_shape_sanity()
	_test_shapes_connected()
	_test_four_rotations_identity()
	_test_rotation_is_reversible()
	_test_world_cells()
	print("test_piece: OK")
	quit()

func _test_shape_sanity() -> void:
	assert(Piece.SHAPES.size() == 5, "1단계 조각은 5종이어야 한다")
	for kind in Piece.SHAPES:
		var p := Piece.create(kind)
		assert(p.cells.size() == 4, "조각 %d 는 셀이 4개여야 한다" % kind)
		var seen := {}
		for c in p.cells:
			assert(not seen.has(c), "조각 %d 에 중복 셀 %s" % [kind, c])
			seen[c] = true

func _test_shapes_connected() -> void:
	for kind in Piece.SHAPES:
		var cells := Piece.create(kind).cells
		var pool := {}
		for c in cells:
			pool[c] = true
		var stack: Array[Vector3i] = [cells[0]]
		var seen := {cells[0]: true}
		var neighbors := [
			Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
			Vector3i(0, 1, 0), Vector3i(0, -1, 0),
			Vector3i(0, 0, 1), Vector3i(0, 0, -1),
		]
		while not stack.is_empty():
			var cur: Vector3i = stack.pop_back()
			for n in neighbors:
				var nb: Vector3i = cur + n
				if pool.has(nb) and not seen.has(nb):
					seen[nb] = true
					stack.append(nb)
		assert(seen.size() == 4, "조각 %d 의 셀이 서로 붙어있지 않다" % kind)

func _test_four_rotations_identity() -> void:
	for kind in Piece.SHAPES:
		for axis in [Piece.AXIS_X, Piece.AXIS_Y, Piece.AXIS_Z]:
			for dir in [1, -1]:
				var original := Piece.create(kind)
				var r := original
				for _i in 4:
					r = r.rotated(axis, dir)
				assert(_same_cells(original.cells, r.cells),
					"조각 %d 축 %d 방향 %d: 4회 회전 후 원본과 다르다" % [kind, axis, dir])

func _test_rotation_is_reversible() -> void:
	for kind in Piece.SHAPES:
		for axis in [Piece.AXIS_X, Piece.AXIS_Y, Piece.AXIS_Z]:
			var original := Piece.create(kind)
			var there_and_back := original.rotated(axis, 1).rotated(axis, -1)
			assert(_same_cells(original.cells, there_and_back.cells),
				"조각 %d 축 %d: 정회전 후 역회전이 원본과 다르다" % [kind, axis])

func _test_world_cells() -> void:
	var p := Piece.create(Piece.SHAPES.keys()[0])
	p.origin = Vector3i(2, 3, 1)
	var world := p.world_cells()
	for i in p.cells.size():
		assert(world[i] == p.cells[i] + Vector3i(2, 3, 1), "world_cells 가 origin 을 더하지 않았다")

func _same_cells(a: Array[Vector3i], b: Array[Vector3i]) -> bool:
	if a.size() != b.size():
		return false
	var sa := a.duplicate()
	var sb := b.duplicate()
	sa.sort()
	sb.sort()
	return sa == sb
