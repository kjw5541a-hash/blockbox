extends SceneTree

# 조작 매핑은 실제 카메라 투영에 달려 있다. 가짜 리그로는 "손가락을 따라가는지"를
# 확인할 수 없으므로 씬을 통째로 띄우고 Camera3D 의 투영을 직접 읽는다.
func _initialize() -> void:
	await _test_drag_along_an_axis_moves_that_axis()
	await _test_piece_follows_finger()
	await _test_view_turns_only_outside_the_box()
	await _test_end_drag_resets_accumulator()
	await _test_view_tilts_up_and_down()
	await _test_one_drag_does_one_thing()
	print("test_touch_input: OK")
	quit()

func _main() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	return main

func _face_yaw(rig: CameraRig, step: int) -> void:
	rig.yaw_step = step
	# 트윈을 기다리지 않고 목표 각도를 바로 넣는다.
	rig.rotation_degrees = Vector3(
		CameraRig.PITCH_DEG, CameraRig.YAW_BASE_DEG + 90.0 * step, 0.0)

# 회귀 테스트: 예전에는 화면에서 우세한 축 하나만 골랐다. 쿼터뷰에서는 두 수평
# 격자축이 모두 화면 오른쪽을 향하므로, 오른쪽 위로 끌면 조각이 오른쪽 아래로
# 갔다 — 손가락과 반대 사분면이다.
#
# 여기서는 격자축의 화면 방향(axis_screen)만 근거로 삼는다. 그 방향으로 1.5칸만큼
# 끌면 정확히 그 축으로 한 칸이어야 한다. 우세축 방식은 두 축이 모두 오른쪽을
# 향하는 탓에 이 단언을 통과할 수 없다.
func _test_drag_along_an_axis_moves_that_axis() -> void:
	var main: Node = await _main()
	var game: Game = main.game
	var rig: CameraRig = main.rig
	var input: TouchInput = main.touch_input
	for s in 4:
		_face_yaw(rig, s)
		await process_frame
		var away := rig.axis_away()
		var right := rig.axis_right()
		# 대각선까지 포함해 다섯 가지. 4x4 통 한가운데의 O 조각은 어느 쪽으로든
		# 정확히 한 칸 여유가 있으므로 벽에 막혀 흐려지는 일이 없다.
		var cases: Array[Vector3i] = [
			away, -away, right, -right, away + right,
		]
		for want in cases:
			var drag := Vector2.ZERO
			for axis in [away, right]:
				var n: int = _component(want, axis)
				drag += input.axis_screen(axis) * float(n)
			var before := _center_o(game)
			input.begin_drag(input.box_screen_rect().get_center())
			input.feed_drag(drag * 1.5)
			var moved: Vector3i = game.current.origin - before
			assert(moved == want,
				"yaw %d: 화면에서 %s 방향으로 1.5칸 끌었는데 %s 로 갔다" % [s, want, moved])
	main.queue_free()

# 어떤 방향으로 끌어도 조각의 화면 이동이 손가락과 같은 쪽이어야 한다.
func _test_piece_follows_finger() -> void:
	var main: Node = await _main()
	var game: Game = main.game
	var rig: CameraRig = main.rig
	var input: TouchInput = main.touch_input
	var cam: Camera3D = rig.get_node("Camera3D")
	var drags: Array[Vector2] = [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
		Vector2(1, -1).normalized(), Vector2(-1, -1).normalized(),
	]
	for s in 4:
		_face_yaw(rig, s)
		await process_frame
		for d in drags:
			var origin := _center_o(game)
			var before := cam.unproject_position(Vector3(origin))
			input.begin_drag(input.box_screen_rect().get_center())
			input.feed_drag(d * 200.0)
			var moved := cam.unproject_position(Vector3(game.current.origin)) - before
			assert(moved.length() > 0.0,
				"yaw %d: 손가락 %s 로 200픽셀 끌었는데 조각이 안 움직였다" % [s, d])
			assert(moved.dot(d) > 0.0,
				"yaw %d: 손가락 %s 로 끌었는데 조각이 화면에서 %s 로 갔다" % [s, d, moved])
	main.queue_free()

# 통 한가운데의 O 조각으로 되돌리고 그 원점을 준다.
func _center_o(game: Game) -> Vector3i:
	game.current = Piece.create(2)
	game.current.origin = game.spawn_origin_for(game.current)
	return game.current.origin

# 단위 축 벡터 방향의 성분. 축은 ±X 나 ±Z 중 하나다.
func _component(v: Vector3i, axis: Vector3i) -> int:
	return v.x * axis.x + v.z * axis.z

func _test_view_turns_only_outside_the_box() -> void:
	var main: Node = await _main()
	var rig: CameraRig = main.rig
	var input: TouchInput = main.touch_input
	var rect := input.box_screen_rect()
	var before := rig.yaw_step

	input.begin_drag(rect.get_center())
	input.feed_drag(Vector2(TouchInput.TURN_PIXELS * 2.0, 0))
	assert(rig.yaw_step == before, "통 안에서 끌면 시점이 돌면 안 된다")

	var outside := Vector2(rect.position.x * 0.5, rect.get_center().y)
	assert(not rect.has_point(outside), "통 왼쪽에 여백이 있어야 한다: %s" % rect)
	input.begin_drag(outside)
	input.feed_drag(Vector2(TouchInput.TURN_PIXELS, 0))
	assert(rig.yaw_step == wrapi(before + 1, 0, 4),
		"통 바깥에서 오른쪽으로 끌면 시점이 한 칸 돌아야 한다: %d" % rig.yaw_step)

	input.begin_drag(outside)
	input.feed_drag(Vector2(-TouchInput.TURN_PIXELS, 0))
	assert(rig.yaw_step == before, "반대로 끌면 되돌아와야 한다: %d" % rig.yaw_step)
	main.queue_free()

func _test_end_drag_resets_accumulator() -> void:
	var main: Node = await _main()
	var game: Game = main.game
	var rig: CameraRig = main.rig
	var input: TouchInput = main.touch_input
	# 두 축 각각으로 0.8칸에 해당하는 드래그. 두 번 이어 하면 1칸을 넘으므로,
	# 초기화가 안 되면 조각이 움직여 버린다.
	var almost: Vector2 = (input.axis_screen(rig.axis_away())
		+ input.axis_screen(rig.axis_right())) * 0.8

	input.begin_drag(input.box_screen_rect().get_center())
	input.feed_drag(almost)
	var before: Vector3i = game.current.origin
	input.end_drag()
	input.begin_drag(input.box_screen_rect().get_center())
	input.feed_drag(almost)
	assert(game.current.origin == before, "손을 떼면 누적 거리가 초기화되어야 한다")

	# 같은 드래그를 한 번 더 이으면 이번엔 넘어가야 한다 — 위 단언이 빈 단언이 아님을 확인.
	input.feed_drag(almost)
	assert(game.current.origin != before, "이어서 끌면 누적되어 움직여야 한다")
	main.queue_free()


# 상하각까지 손가락으로 움직여야 폰에서 탑뷰를 볼 수 있다. 키보드(W/S)는
# 개발용이라 폰에는 없다.
func _test_view_tilts_up_and_down() -> void:
	var main: Node = await _main()
	var rig: CameraRig = main.rig
	var input: TouchInput = main.touch_input
	var rect := input.box_screen_rect()
	var outside := Vector2(rect.position.x * 0.5, rect.get_center().y)
	var before := rig.pitch_degrees()

	input.begin_drag(rect.get_center())
	input.feed_drag(Vector2(0, 100.0))
	assert(is_equal_approx(rig.pitch_degrees(), before),
		"통 안에서 끌면 상하각이 변하면 안 된다: %f" % rig.pitch_degrees())

	# 손가락을 내리면 위에서 내려다보는 쪽으로 간다.
	input.begin_drag(outside)
	input.feed_drag(Vector2(0, 40.0))
	var down := rig.pitch_degrees()
	assert(down < before - 1.0,
		"아래로 끌면 탑뷰 쪽으로 가야 한다: %f, 시작 %f" % [down, before])
	assert(is_equal_approx(down, before - 40.0 * TouchInput.PITCH_DEG_PER_PIXEL),
		"상하각이 끈 거리에 비례해야 한다: %f" % down)
	assert(is_equal_approx(rig.rotation_degrees.x, down),
		"실제 카메라 각도가 따라오지 않았다: %f" % rig.rotation_degrees.x)

	input.begin_drag(outside)
	input.feed_drag(Vector2(0, -40.0))
	assert(is_equal_approx(rig.pitch_degrees(), before),
		"위로 끌면 되돌아와야 한다: %f" % rig.pitch_degrees())

	# 세로로 끌었다고 시점이 좌우로 돌면 안 된다.
	var step := rig.yaw_step
	input.begin_drag(outside)
	input.feed_drag(Vector2(0, 400.0))
	assert(rig.yaw_step == step, "세로 드래그가 좌우 회전을 건드렸다")
	assert(is_equal_approx(rig.pitch_degrees(), CameraRig.PITCH_MIN),
		"끝까지 끌면 탑뷰에서 멈춰야 한다: %f" % rig.pitch_degrees())
	main.queue_free()


# 손가락으로 긋는 선은 축에 딱 맞지 않는다. 좌우로 끌면 세로로도 조금 미끄러지고,
# 그때마다 통이 누우면 시점을 돌릴 때마다 각도가 밀려 되돌릴 방법이 없다.
func _test_one_drag_does_one_thing() -> void:
	var main: Node = await _main()
	var rig: CameraRig = main.rig
	var input: TouchInput = main.touch_input
	var rect := input.box_screen_rect()
	var outside := Vector2(rect.position.x * 0.5, rect.get_center().y)
	var pitch := rig.pitch_degrees()
	var step := rig.yaw_step

	# 가로로 크게, 세로로 조금씩 같은 쪽으로 미끄러진다.
	input.begin_drag(outside)
	for _i in 6:
		input.feed_drag(Vector2(20.0, 8.0))
	assert(rig.yaw_step == wrapi(step + 1, 0, 4),
		"가로로 120픽셀을 끌었으면 시점이 한 칸 돌아야 한다: %d" % rig.yaw_step)
	assert(is_equal_approx(rig.pitch_degrees(), pitch),
		"좌우로 끄는 중에 미끄러진 48픽셀이 통을 눕혔다: %f" % rig.pitch_degrees())

	# 반대도 마찬가지 - 세로로 끄는 중에 미끄러진 가로 몫이 시점을 돌리면 안 된다.
	step = rig.yaw_step
	input.begin_drag(outside)
	for _i in 12:
		input.feed_drag(Vector2(8.0, -20.0))
	assert(rig.yaw_step == step,
		"상하로 끄는 중에 미끄러진 96픽셀이 시점을 돌렸다: %d" % rig.yaw_step)
	assert(rig.pitch_degrees() > pitch + 1.0,
		"세로로 끌었는데 통이 안 누웠다: %f" % rig.pitch_degrees())
	main.queue_free()
