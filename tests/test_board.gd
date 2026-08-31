extends SceneTree

func _initialize() -> void:
	_test_empty_board()
	_test_index_is_unique()
	_test_bounds()
	_test_is_valid_rejects_occupied()
	_test_lock_and_fill_count()
	print("test_board: OK")
	quit()

func _test_empty_board() -> void:
	var b := Board.new()
	assert(b.cells.size() == 224, "보드는 224칸이어야 한다")
	for v in b.cells:
		assert(v == 0, "새 보드는 전부 비어 있어야 한다")

func _test_index_is_unique() -> void:
	var seen := {}
	for y in Board.HEIGHT:
		for z in Board.DEPTH:
			for x in Board.WIDTH:
				var i := Board.index(x, y, z)
				assert(i >= 0 and i < 224, "인덱스 범위 밖: %d" % i)
				assert(not seen.has(i), "인덱스 충돌: %d" % i)
				seen[i] = true
	assert(seen.size() == 224, "모든 칸이 서로 다른 인덱스를 가져야 한다")

func _test_bounds() -> void:
	assert(Board.in_bounds(Vector3i(0, 0, 0)))
	assert(Board.in_bounds(Vector3i(3, 13, 3)))
	assert(not Board.in_bounds(Vector3i(-1, 0, 0)))
	assert(not Board.in_bounds(Vector3i(4, 0, 0)))
	assert(not Board.in_bounds(Vector3i(0, 14, 0)))
	assert(not Board.in_bounds(Vector3i(0, -1, 0)))
	assert(not Board.in_bounds(Vector3i(0, 0, 4)))

func _test_is_valid_rejects_occupied() -> void:
	var b := Board.new()
	var cells: Array[Vector3i] = [Vector3i(1, 0, 1), Vector3i(2, 0, 1)]
	assert(b.is_valid(cells), "빈 보드에는 놓을 수 있어야 한다")
	b.lock([Vector3i(2, 0, 1)] as Array[Vector3i], 3)
	assert(not b.is_valid(cells), "이미 찬 칸에는 놓을 수 없어야 한다")
	var outside: Array[Vector3i] = [Vector3i(4, 0, 0)]
	assert(not b.is_valid(outside), "범위 밖에는 놓을 수 없어야 한다")

func _test_lock_and_fill_count() -> void:
	var b := Board.new()
	assert(b.layer_fill_count(0) == 0, "빈 층은 0칸")
	var cells: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0)]
	b.lock(cells, 7)
	assert(b.get_cell(Vector3i(0, 0, 0)) == 7, "잠근 칸에 종류 값이 들어가야 한다")
	assert(b.layer_fill_count(0) == 2, "0층은 2칸 차 있어야 한다")
	assert(b.layer_fill_count(1) == 0, "1층은 비어 있어야 한다")
