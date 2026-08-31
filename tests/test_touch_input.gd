extends SceneTree

func _initialize() -> void:
	_test_short_drag_does_not_move()
	_test_drag_moves_one_cell_per_step()
	_test_long_drag_moves_multiple_cells()
	_test_drag_follows_camera()
	_test_end_drag_resets_accumulator()
	print("test_touch_input: OK")
	quit()

func _setup() -> Array:
	var game := Game.new()
	var rig := CameraRig.new()
	var input := TouchInput.new()
	root.add_child(game)
	root.add_child(rig)
	root.add_child(input)
	game.start(31)
	input.setup(game, rig)
	return [game, rig, input]

func _test_short_drag_does_not_move() -> void:
	var parts := _setup()
	var game: Game = parts[0]
	var input: TouchInput = parts[2]
	var before: Vector3i = game.current.origin
	input.feed_drag(Vector2(TouchInput.STEP_PIXELS - 5.0, 0))
	assert(game.current.origin == before, "임계값 미만 드래그는 움직이면 안 된다")

func _test_drag_moves_one_cell_per_step() -> void:
	var parts := _setup()
	var game: Game = parts[0]
	var rig: CameraRig = parts[1]
	var input: TouchInput = parts[2]
	# 벽에 막히지 않도록 먼저 한쪽 끝으로 붙인 뒤 반대로 끈다.
	while game.move(rig.move_delta(Vector2i(-1, 0))):
		pass
	var before: Vector3i = game.current.origin
	input.feed_drag(Vector2(TouchInput.STEP_PIXELS, 0))
	var expected: Vector3i = before + rig.move_delta(Vector2i(1, 0))
	assert(game.current.origin == expected,
		"임계값만큼 끌면 정확히 한 칸 움직여야 한다: %s vs %s" % [game.current.origin, expected])

func _test_drag_follows_camera() -> void:
	var parts := _setup()
	var game: Game = parts[0]
	var rig: CameraRig = parts[1]
	var input: TouchInput = parts[2]
	rig.yaw_step = 2
	while game.move(rig.move_delta(Vector2i(0, 1))):
		pass
	var before: Vector3i = game.current.origin
	input.feed_drag(Vector2(0, -TouchInput.STEP_PIXELS))
	var expected: Vector3i = before + rig.axis_away()
	assert(game.current.origin == expected,
		"시점을 돌려도 위로 끌기는 화면 안쪽이어야 한다")

func _test_end_drag_resets_accumulator() -> void:
	var parts := _setup()
	var game: Game = parts[0]
	var input: TouchInput = parts[2]
	input.feed_drag(Vector2(TouchInput.STEP_PIXELS - 5.0, 0))
	input.end_drag()
	var before: Vector3i = game.current.origin
	input.feed_drag(Vector2(10.0, 0))
	assert(game.current.origin == before, "손을 떼면 누적 거리가 초기화되어야 한다")

func _test_long_drag_moves_multiple_cells() -> void:
	var parts := _setup()
	var game: Game = parts[0]
	var rig: CameraRig = parts[1]
	var input: TouchInput = parts[2]
	# I 조각은 X 로 길고 Z 로 한 칸이라 안쪽으로 세 칸 여유가 있다.
	game.current = Piece.create(1)
	game.current.origin = game.spawn_origin_for(game.current)
	while game.move(rig.move_delta(Vector2i(0, 1))):
		pass
	var before: Vector3i = game.current.origin
	input.feed_drag(Vector2(0, -TouchInput.STEP_PIXELS * 3.0))
	var expected: Vector3i = before + rig.move_delta(Vector2i(0, -1)) * 3
	assert(game.current.origin == expected,
		"한 번에 세 칸 분량을 끌면 세 칸 움직여야 한다: %s vs %s" % [game.current.origin, expected])
