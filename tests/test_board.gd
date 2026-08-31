extends SceneTree

func _initialize() -> void:
	_test_empty_board()
	_test_index_is_unique()
	_test_bounds()
	_test_is_valid_rejects_occupied()
	_test_lock_and_fill_count()
	_test_clear_single_layer()
	_test_clear_two_layers()
	_test_get_cell_all_faces()
	_test_lock_no_cross_write()
	_test_layer_fill_count_faces()
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

func _fill_layer(b: Board, y: int, kind: int) -> void:
	for z in Board.DEPTH:
		for x in Board.WIDTH:
			b.cells[Board.index(x, y, z)] = kind

func _test_clear_single_layer() -> void:
	var b := Board.new()
	_fill_layer(b, 0, 1)
	b.cells[Board.index(2, 1, 2)] = 9  # 1층에 표식 하나
	var cleared := b.clear_layers()
	assert(cleared == 1, "한 층이 지워져야 한다, 실제 %d" % cleared)
	assert(b.layer_fill_count(1) == 0, "1층은 비어야 한다")
	assert(b.get_cell(Vector3i(2, 0, 2)) == 9, "위층 표식이 정확히 한 칸 내려와야 한다")
	assert(b.cells.size() == 224, "클리어 후에도 크기가 유지되어야 한다")

func _test_clear_two_layers() -> void:
	var b := Board.new()
	_fill_layer(b, 0, 1)
	_fill_layer(b, 2, 1)
	b.cells[Board.index(1, 1, 1)] = 8   # 지워지는 두 층 사이
	b.cells[Board.index(3, 3, 3)] = 9   # 지워지는 층들 위
	var cleared := b.clear_layers()
	assert(cleared == 2, "두 층이 지워져야 한다, 실제 %d" % cleared)
	assert(b.get_cell(Vector3i(1, 0, 1)) == 8, "사이 층 표식이 0층으로 내려와야 한다")
	assert(b.get_cell(Vector3i(3, 1, 3)) == 9, "위쪽 표식이 두 칸 내려와야 한다")
	assert(b.layer_fill_count(2) == 0, "비워진 자리는 빈 층이어야 한다")
	assert(b.layer_fill_count(13) == 0, "맨 위층은 비어야 한다")

func _test_get_cell_all_faces() -> void:
	var b := Board.new()
	# 상자의 여섯 면 각각에서 경계 좌표가 정상 동작하는지 확인한다.
	var faces: Array[Vector3i] = [
		Vector3i(0, 5, 2),                     # x = 0 면
		Vector3i(Board.WIDTH - 1, 5, 2),       # x = WIDTH-1 면
		Vector3i(2, 5, 0),                     # z = 0 면
		Vector3i(2, 5, Board.DEPTH - 1),       # z = DEPTH-1 면
		Vector3i(2, 0, 2),                     # y = 0 면
		Vector3i(2, Board.HEIGHT - 1, 2),      # y = HEIGHT-1 면
	]
	for i in faces.size():
		var c: Vector3i = faces[i]
		b.lock([c] as Array[Vector3i], i + 1)
		assert(b.get_cell(c) == i + 1, "경계 좌표 %s 값이 어긋났다" % c)

func _test_lock_no_cross_write() -> void:
	var b := Board.new()
	b.lock([Vector3i(3, 0, 0)] as Array[Vector3i], 5)
	assert(b.get_cell(Vector3i(3, 0, 0)) == 5, "잠근 칸 (3,0,0)에 값이 있어야 한다")
	assert(b.get_cell(Vector3i(0, 0, 1)) == 0, "앨리어싱될 뻔한 칸 (0,0,1)은 비어 있어야 한다")

func _test_layer_fill_count_faces() -> void:
	var b := Board.new()
	assert(b.layer_fill_count(0) == 0, "새 보드의 0층은 비어 있어야 한다")
	assert(b.layer_fill_count(Board.HEIGHT - 1) == 0, "새 보드의 맨 위층은 비어 있어야 한다")
	b.lock([Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0)] as Array[Vector3i], 3)
	b.lock([Vector3i(0, Board.HEIGHT - 1, 0)] as Array[Vector3i], 4)
	assert(b.layer_fill_count(0) == 3, "0층은 3칸 차 있어야 한다")
	assert(b.layer_fill_count(Board.HEIGHT - 1) == 1, "맨 위층은 1칸 차 있어야 한다")
