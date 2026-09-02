extends SceneTree

func _initialize() -> void:
	_test_apply_sets_board()
	_test_each_difficulty_flips_one_switch()
	await _test_start_scene_rows()
	await _test_main_scene_uses_chosen_size()
	_test_app_icon_is_set()
	print("test_game_config: OK")
	quit()

# 웹 빌드의 파비콘과 iOS "홈 화면에 추가" 아이콘은 Web 프리셋이 이 설정 하나에서
# 만들어 낸다. 경로가 비거나 파일이 사라지면 아이콘 없이 배포되는데, 화면만
# 봐서는 눈치채기 어렵다.
func _test_app_icon_is_set() -> void:
	var path: String = str(ProjectSettings.get_setting("application/config/icon", ""))
	assert(path != "", "앱 아이콘 경로가 비어 있다")
	assert(ResourceLoader.exists(path), "앱 아이콘 파일이 없다: %s" % path)
	var tex: Texture2D = load(path)
	assert(tex.get_width() == tex.get_height() and tex.get_width() >= 180,
		"아이콘은 정사각형이고 180px 이상이어야 한다: %dx%d" % [tex.get_width(), tex.get_height()])

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

# 난이도는 스위치 세 개가 한 단계마다 하나씩 켜지는 계단이다. 표를 그대로
# 적어 두고 대조한다 — 한 칸이라도 어긋나면 고른 난이도와 실제 규칙이 다르다.
func _test_each_difficulty_flips_one_switch() -> void:
	# [특수 조각, 자동 낙하, 착지 그림자]
	var want := {
		GameConfig.EASY: [false, false, true],
		GameConfig.NORMAL: [true, false, true],
		GameConfig.HARD: [true, true, true],
		GameConfig.HELL: [true, true, false],
	}
	assert(want.size() == GameConfig.ALL.size(), "난이도 수와 표가 어긋난다")
	for d in GameConfig.ALL:
		GameConfig.difficulty = d
		var row: Array = want[d]
		var ks := GameConfig.kinds()
		if row[0]:
			assert(ks.size() == Piece.SHAPES.size(), "난이도 %d 는 전 종류: %s" % [d, ks])
		else:
			assert(ks.size() == Piece.PLANAR_MAX,
				"난이도 %d 는 평면 조각 %d 종만: %s" % [d, Piece.PLANAR_MAX, ks])
			for k in ks:
				assert(k <= Piece.PLANAR_MAX, "난이도 %d 에 비평면 조각 %d 가 섞였다" % [d, k])
		assert(GameConfig.gravity() == row[1], "난이도 %d 의 자동 낙하가 표와 다르다" % d)
		assert(GameConfig.ghost() == row[2], "난이도 %d 의 착지 그림자가 표와 다르다" % d)
	_restore()

func _test_start_scene_rows() -> void:
	# class_name 이 없는 스크립트라 정적 타입을 주면 멤버를 못 찾는다.
	var menu = load("res://scenes/start.tscn").instantiate()
	root.add_child(menu)
	# _ready() 는 트리에 들어간 다음 프레임에 불린다. 기다리지 않으면 씬 파일에
	# 박힌 초기값만 보게 되어, 스크립트가 채우는 값은 검사되지 않는다.
	await process_frame
	var sizes: Container = menu.get_node("Center/Menu/Sizes")
	var diff: Container = menu.get_node("Center/Menu/Difficulty")
	assert(sizes.get_child_count() == GameConfig.SIZES.size(),
		"통 크기 버튼 수가 SIZES 와 어긋난다: %d" % sizes.get_child_count())
	assert(diff.get_child_count() == GameConfig.ALL.size(),
		"난이도 버튼 수가 ALL 과 어긋난다: %d" % diff.get_child_count())
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

	# 폰에서 캐시된 옛 빌드를 보고 있는 건 아닌지 구별하려면 버전이 화면에 떠야 한다.
	# 배포 워크플로가 config/version 을 날짜와 커밋 해시로 덮어쓴다.
	var ver: String = str(ProjectSettings.get_setting("application/config/version", ""))
	assert(ver != "", "application/config/version 이 비어 있으면 표시할 것이 없다")
	var label: Label = menu.get_node("Center/Menu/Version")
	assert(label.text.contains(ver), "시작 화면에 버전 %s 가 떠야 한다: '%s'" % [ver, label.text])
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
	var board_view: MeshInstance3D = main.board_view

	# 통이 커져도 화면 안에 들어와야 하고, 좌우에 시점 회전용 여백이 남아야 한다.
	var rect: Rect2 = main.touch_input.box_screen_rect()
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	assert(rect.position.x > 40.0 and rect.end.x < view.x - 40.0,
		"6x6 통 좌우에 시점 회전용 여백이 남아야 한다: %s / 화면 %s" % [rect, view])
	assert(rect.position.y > 0.0 and rect.end.y < view.y,
		"6x6 통이 화면 위아래로 잘리면 안 된다: %s / 화면 %s" % [rect, view])

	# 쉬움이라 저절로 내려오지 않는다. 내리기로 잠근 뒤 뷰에 반영되는지 본다.
	game.hard_drop()
	assert(board_view.mesh != null and board_view.mesh.get_surface_count() == 1,
		"6x6 통에서도 잠긴 칸이 보드 뷰에 나와야 한다")
	var gauge := main.get_node("HUD/LayerGauge")
	assert(gauge._bars.size() == Board.HEIGHT, "층 게이지 막대는 층마다 하나")

	main.queue_free()
	_restore()
