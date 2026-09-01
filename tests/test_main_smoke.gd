extends SceneTree

# 씬을 실제로 띄우고 몇 초 분량을 돌려, 렌더 코드가 게임 로직을 깨거나
# 예외를 던지지 않는지 확인한다. 그림이 예쁜지는 사람이 본다.
func _initialize() -> void:
	# 사람의 실제 최고 기록 파일을 건드리지 않는다.
	SaveData.PATH = "user://test_main_smoke.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))
	var scene: PackedScene = load("res://scenes/main.tscn")
	assert(scene != null, "main.tscn 을 불러올 수 없다")
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame

	var game: Game = main.game
	assert(game != null, "main 이 Game 을 갖고 있어야 한다")
	assert(game.current != null, "시작하면 조각이 있어야 한다")

	# 여기서 step 을 직접 부르지 않는다. 직접 부르면 main 의 _process 배선이
	# 끊겨도 테스트가 통과해 버린다.
	var y_before: int = game.current.origin.y
	var deadline := Time.get_ticks_msec() + 5000
	while game.current != null and game.current.origin.y == y_before:
		if Time.get_ticks_msec() > deadline:
			break
		await process_frame
	assert(game.current != null and game.current.origin.y < y_before,
		"main._process 가 game.step 을 돌려 조각이 스스로 내려가야 한다")

	# 방향키가 카메라 기준 축으로 옮겨지는지 확인한다.
	var rig: CameraRig = main.rig
	var keys := {
		KEY_LEFT: Vector2i(-1, 0),
		KEY_RIGHT: Vector2i(1, 0),
		KEY_UP: Vector2i(0, -1),
		KEY_DOWN: Vector2i(0, 1),
	}
	var key_moved := false
	for k in keys:
		var before: Vector3i = game.current.origin
		var want: Vector3i = before + rig.move_delta(keys[k])
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.pressed = true
		main._unhandled_input(ev)
		var now: Vector3i = game.current.origin
		assert(now == want or now == before,
			"키 %d 가 예상과 다른 축으로 옮겼다: %s, 기대 %s" % [k, now, want])
		if now == want:
			key_moved = true
	assert(key_moved, "방향키 넷 중 최소 하나는 조각을 옮겨야 한다")

	# 조각 뷰의 큐브가 격자 좌표와 같은 자리에 있어야 한다.
	var piece_view: Node3D = main.piece_view
	var world := game.current.world_cells()
	for i in world.size():
		var cube: MeshInstance3D = piece_view.get_child(i)
		assert(cube.visible, "조각 큐브가 보여야 한다")
		assert(cube.position == Vector3(world[i]),
			"큐브 위치 %s 가 격자 좌표 %s 와 어긋난다" % [cube.position, world[i]])

	# 잠긴 조각이 보드 뷰에 반영되어야 한다.
	var board_view: MultiMeshInstance3D = main.board_view
	game.hard_drop()
	assert(board_view.multimesh.visible_instance_count == 4,
		"잠긴 4칸이 보드 뷰에 나와야 한다: %d" % board_view.multimesh.visible_instance_count)

	# HUD 가 게임 상태를 실제로 따라가는지 확인한다.
	var hud: CanvasLayer = main.get_node("HUD")
	assert(hud.get_node("Top/NextSwatch").color == BlockColors.of(game.next_kind),
		"다음 조각 색 견본이 실제 next_kind 와 어긋난다")

	var gauge := hud.get_node("LayerGauge")
	var gauge_bar: ColorRect = gauge._bars[Board.HEIGHT - 1]
	gauge_bar.size.x = 48.0

	var score_label: Label = hud.get_node("Top/Score")
	score_label.text = "낡은 값"
	hud.get_node("GameOver").visible = true
	var restart_key := InputEventKey.new()
	restart_key.keycode = KEY_R
	restart_key.pressed = true
	main._unhandled_input(restart_key)
	assert(score_label.text != "낡은 값", "재시작하면 점수 표시를 새로 그려야 한다")
	assert(not hud.get_node("GameOver").visible, "재시작하면 게임 종료 표시가 사라져야 한다")
	assert(is_equal_approx(gauge_bar.size.x, 0.0),
		"재시작하면 층 게이지도 비워야 한다: %f" % gauge_bar.size.x)

	# 진짜 게임오버까지 몰고 가서, 종료 표시와 기록 저장과 재시작이 이어지는지 본다.
	for _i in 400:
		if game.is_over:
			break
		game.hard_drop()
		await process_frame
	assert(game.is_over, "조각을 400번 떨어뜨리면 판이 끝나야 한다")
	var final_score: int = game.score
	assert(hud.get_node("GameOver").visible, "게임이 끝나면 종료 표시가 떠야 한다")
	assert(SaveData.load_high_score() >= final_score,
		"게임오버 시 점수가 기록에 남아야 한다: 최고 %d, 이번 %d"
		% [SaveData.load_high_score(), final_score])

	main._unhandled_input(restart_key)
	assert(not game.is_over and game.current != null, "게임오버 뒤에도 R 로 다시 시작해야 한다")
	assert(game.score == 0, "재시작하면 점수가 0")
	assert(not hud.get_node("GameOver").visible, "재시작하면 종료 표시가 사라져야 한다")

	assert(game.board.cells.size() == 224, "보드 크기가 유지되어야 한다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveData.PATH))
	print("test_main_smoke: OK")
	quit()
