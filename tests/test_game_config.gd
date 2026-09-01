extends SceneTree

func _initialize() -> void:
	_test_apply_sets_board()
	_test_kinds_and_gravity()
	_test_start_scene_rows()
	print("test_game_config: OK")
	quit()

func _restore() -> void:
	GameConfig.size = 4
	GameConfig.difficulty = GameConfig.HARD
	GameConfig.apply()

func _test_apply_sets_board() -> void:
	GameConfig.size = 5
	GameConfig.difficulty = GameConfig.NORMAL
	GameConfig.apply()
	assert(Board.WIDTH == 5 and Board.DEPTH == 5, "5x5 로 설정되어야 한다")
	assert(Board.LAYER_CELLS == 25, "한 층은 25칸: %d" % Board.LAYER_CELLS)
	assert(Board.new().cells.size() == 25 * Board.HEIGHT, "보드 칸 수가 크기를 따라야 한다")
	assert(Board.LAYER_CLEAR_THRESHOLD == 24,
		"보통은 한 칸 봐준다: %d" % Board.LAYER_CLEAR_THRESHOLD)

	GameConfig.difficulty = GameConfig.EASY
	GameConfig.apply()
	assert(Board.LAYER_CLEAR_THRESHOLD == 23,
		"쉬움은 두 칸 봐준다: %d" % Board.LAYER_CLEAR_THRESHOLD)

	GameConfig.size = 6
	GameConfig.difficulty = GameConfig.HARD
	GameConfig.apply()
	assert(Board.LAYER_CLEAR_THRESHOLD == 36, "어려움은 한 층 전체")
	assert(Board.in_bounds(Vector3i(5, 0, 5)), "6x6 에서 (5,0,5) 는 안쪽")
	assert(not Board.in_bounds(Vector3i(6, 0, 0)), "6x6 에서 x=6 은 바깥")

	_restore()
	assert(Board.WIDTH == 4 and Board.LAYER_CLEAR_THRESHOLD == 16, "기본값으로 되돌아와야 한다")

func _test_kinds_and_gravity() -> void:
	for d in [GameConfig.EASY, GameConfig.NORMAL]:
		GameConfig.difficulty = d
		var ks := GameConfig.kinds()
		assert(ks.size() == Piece.PLANAR_MAX,
			"난이도 %d 는 평면 조각 %d 종만: %s" % [d, Piece.PLANAR_MAX, ks])
		for k in ks:
			assert(k <= Piece.PLANAR_MAX, "난이도 %d 에 비평면 조각 %d 가 섞였다" % [d, k])
	GameConfig.difficulty = GameConfig.HARD
	assert(GameConfig.kinds().size() == Piece.SHAPES.size(), "어려움은 전 종류")

	GameConfig.difficulty = GameConfig.EASY
	assert(not GameConfig.gravity(), "쉬움에는 중력이 없다")
	for d in [GameConfig.NORMAL, GameConfig.HARD]:
		GameConfig.difficulty = d
		assert(GameConfig.gravity(), "난이도 %d 에는 중력이 있다" % d)
	_restore()

func _test_start_scene_rows() -> void:
	# class_name 이 없는 스크립트라 정적 타입을 주면 멤버를 못 찾는다.
	var menu = load("res://scenes/start.tscn").instantiate()
	root.add_child(menu)
	var sizes: Container = menu.get_node("Center/Menu/Sizes")
	var diff: Container = menu.get_node("Center/Menu/Difficulty")
	assert(sizes.get_child_count() == GameConfig.SIZES.size(),
		"통 크기 버튼 수가 SIZES 와 어긋난다: %d" % sizes.get_child_count())
	assert(diff.get_child_count() == 3, "난이도 버튼은 3개")
	for row in [sizes, diff]:
		var pressed := 0
		for c in row.get_children():
			assert(c is Button, "선택 줄에는 버튼만 있어야 한다 — 자리 번호가 곧 선택 값이다")
			if (c as Button).button_pressed:
				pressed += 1
		assert(pressed == 1, "각 줄에서 정확히 하나만 눌려 있어야 한다: %d" % pressed)
	# 버튼 그룹이 살아 있어야 자리 번호 읽기가 하나로 좁혀진다.
	(sizes.get_child(2) as Button).button_pressed = true
	assert(menu._selected(sizes) == 2, "눌린 버튼의 자리 번호가 선택 값이다")
	assert(not (sizes.get_child(0) as Button).button_pressed, "같은 줄의 다른 선택은 풀려야 한다")
	menu.queue_free()
