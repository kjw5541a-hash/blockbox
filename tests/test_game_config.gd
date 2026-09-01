extends SceneTree

func _initialize() -> void:
	_test_apply_sets_board()
	_test_kinds_and_gravity()
	_test_start_scene_rows()
	await _test_main_scene_uses_chosen_size()
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
	assert(Board.LAYER_CLEAR_THRESHOLD == 25,
		"보통은 봐주지 않는다 — 한 층을 꽉 채워야 한다: %d" % Board.LAYER_CLEAR_THRESHOLD)

	GameConfig.difficulty = GameConfig.EASY
	GameConfig.apply()
	assert(Board.LAYER_CLEAR_THRESHOLD == 23,
		"쉬움만 두 칸 봐준다: %d" % Board.LAYER_CLEAR_THRESHOLD)

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


# 통 크기는 뷰 세 곳(BoardView / BoxFrame / LayerGauge)이 각자 Board 를 읽어
# 만들어 쓴다. 크기를 바꾼 뒤 씬을 통째로 띄워, 실제로 6x6 통이 서는지 본다.
func _test_main_scene_uses_chosen_size() -> void:
	GameConfig.size = 6
	GameConfig.difficulty = GameConfig.EASY
	GameConfig.apply()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var game: Game = main.game
	assert(game.board.cells.size() == 6 * 6 * Board.HEIGHT,
		"보드가 6x6 이어야 한다: %d 칸" % game.board.cells.size())
	assert(main.rig.position == Vector3(2.5, (Board.HEIGHT - 1) * 0.5, 2.5),
		"카메라가 통 한가운데를 봐야 한다: %s" % main.rig.position)
	var board_view: MultiMeshInstance3D = main.board_view
	assert(board_view.multimesh.instance_count == 6 * 6 * Board.HEIGHT,
		"보드 뷰가 모든 칸을 그릴 수 있어야 한다: %d" % board_view.multimesh.instance_count)

	# 통이 커져도 화면 안에 들어와야 하고, 좌우에 시점 회전용 여백이 남아야 한다.
	var rect: Rect2 = main.touch_input.box_screen_rect()
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	assert(rect.position.x > 40.0 and rect.end.x < view.x - 40.0,
		"6x6 통 좌우에 시점 회전용 여백이 남아야 한다: %s / 화면 %s" % [rect, view])
	assert(rect.position.y > 0.0 and rect.end.y < view.y,
		"6x6 통이 화면 위아래로 잘리면 안 된다: %s / 화면 %s" % [rect, view])

	# 쉬움이라 저절로 내려오지 않는다. 내리기로 잠근 뒤 뷰에 반영되는지 본다.
	game.hard_drop()
	assert(board_view.multimesh.visible_instance_count == 4,
		"잠긴 4칸이 보드 뷰에 나와야 한다: %d" % board_view.multimesh.visible_instance_count)
	var gauge := main.get_node("HUD/LayerGauge")
	assert(gauge._bars.size() == Board.HEIGHT, "층 게이지 막대는 층마다 하나")

	main.queue_free()
	_restore()
