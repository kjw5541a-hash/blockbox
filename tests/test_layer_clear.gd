extends SceneTree

# "다 채우지 않았는데 층이 지워진다"는 신고를 확인하는 테스트.
# 층이 정확히 몇 칸에서 지워지는지를 통 크기 3종 × 난이도 3종 전 조합에 대해
# 못박는다. 여기가 통과하면 남은 설명은 하나뿐이다 — 난이도별로 몇 칸을
# 봐주도록 설계되어 있다는 것(GameConfig.THRESHOLD_SLACK).
func _initialize() -> void:
	_test_threshold_matches_difficulty()
	_test_clears_at_threshold_and_not_one_cell_earlier()
	_test_hard_needs_every_cell()
	_test_only_qualifying_layers_go()
	_restore()
	print("test_layer_clear: OK")
	quit()

func _restore() -> void:
	GameConfig.size = 4
	GameConfig.difficulty = GameConfig.HARD
	GameConfig.apply()

# 층 y 의 앞에서부터 n 칸을 채운다.
func _fill(b: Board, y: int, n: int) -> void:
	for i in n:
		b.cells[y * Board.LAYER_CELLS + i] = 1

func _test_threshold_matches_difficulty() -> void:
	for size in GameConfig.SIZES:
		for d in [GameConfig.EASY, GameConfig.NORMAL, GameConfig.HARD]:
			GameConfig.size = size
			GameConfig.difficulty = d
			GameConfig.apply()
			var slack: int = GameConfig.THRESHOLD_SLACK[d]
			assert(Board.LAYER_CELLS == size * size,
				"%dx%d 한 층은 %d칸이어야 한다: %d" % [size, size, size * size, Board.LAYER_CELLS])
			assert(Board.LAYER_CLEAR_THRESHOLD == size * size - slack,
				"%dx%d 난이도 %d: 기준이 %d 여야 하는데 %d" % [
					size, size, d, size * size - slack, Board.LAYER_CLEAR_THRESHOLD])

# 기준보다 한 칸 모자라면 절대 지워지지 않고, 기준에 닿는 순간 지워져야 한다.
func _test_clears_at_threshold_and_not_one_cell_earlier() -> void:
	for size in GameConfig.SIZES:
		for d in [GameConfig.EASY, GameConfig.NORMAL, GameConfig.HARD]:
			GameConfig.size = size
			GameConfig.difficulty = d
			GameConfig.apply()
			var t := Board.LAYER_CLEAR_THRESHOLD

			var below := Board.new()
			_fill(below, 0, t - 1)
			assert(below.layer_fill_count(0) == t - 1,
				"칸 세기가 어긋난다: %d" % below.layer_fill_count(0))
			assert(below.clear_layers() == 0,
				"%dx%d 난이도 %d: %d칸(기준 %d)에서 지워지면 안 된다" % [size, size, d, t - 1, t])
			assert(below.layer_fill_count(0) == t - 1, "안 지워졌으면 칸이 그대로 남아야 한다")

			var at := Board.new()
			_fill(at, 0, t)
			assert(at.clear_layers() == 1,
				"%dx%d 난이도 %d: %d칸이면 지워져야 한다" % [size, size, d, t])
			assert(at.layer_fill_count(0) == 0, "지워진 층은 비어야 한다")

# 어려움은 봐주는 칸이 없다. 한 칸이라도 비면 남아야 한다.
func _test_hard_needs_every_cell() -> void:
	for size in GameConfig.SIZES:
		GameConfig.size = size
		GameConfig.difficulty = GameConfig.HARD
		GameConfig.apply()
		var cells := Board.LAYER_CELLS
		assert(Board.LAYER_CLEAR_THRESHOLD == cells,
			"어려움 기준은 한 층 전체여야 한다: %d / %d" % [Board.LAYER_CLEAR_THRESHOLD, cells])
		# 마지막 한 칸만 빼고 전부 채운다. 어느 칸을 비우든 결과가 같아야 하므로
		# 구멍 위치를 옮겨가며 전부 확인한다.
		for hole in cells:
			var b := Board.new()
			for i in cells:
				if i != hole:
					b.cells[i] = 1
			assert(b.layer_fill_count(0) == cells - 1, "한 칸만 비어 있어야 한다")
			assert(b.clear_layers() == 0,
				"%dx%d 어려움: %d번 칸이 비었는데 지워졌다" % [size, size, hole])
			b.cells[hole] = 1
			assert(b.clear_layers() == 1, "마지막 칸을 채우면 지워져야 한다")

# 기준에 닿은 층만 사라지고, 위층은 그대로 한 칸 내려앉아야 한다.
func _test_only_qualifying_layers_go() -> void:
	GameConfig.size = 4
	GameConfig.difficulty = GameConfig.HARD
	GameConfig.apply()
	var t := Board.LAYER_CLEAR_THRESHOLD
	var b := Board.new()
	_fill(b, 0, t)          # 0층: 기준 충족
	_fill(b, 1, t - 1)      # 1층: 한 칸 모자람
	_fill(b, 2, 1)          # 2층: 한 칸
	assert(b.clear_layers() == 1, "기준에 닿은 층은 하나뿐이다")
	assert(b.layer_fill_count(0) == t - 1, "1층이 0층으로 내려와야 한다: %d" % b.layer_fill_count(0))
	assert(b.layer_fill_count(1) == 1, "2층이 1층으로 내려와야 한다: %d" % b.layer_fill_count(1))
	assert(b.layer_fill_count(2) == 0, "위쪽에는 빈 층이 생겨야 한다")
