extends SceneTree

# 조작 매핑은 실제 카메라 투영에 달려 있다. 가짜 리그로는 "손가락을 따라가는지"를
# 확인할 수 없으므로 씬을 통째로 띄우고 Camera3D 의 투영을 직접 읽는다.
func _initialize() -> void:
	await _test_piece_follows_finger()
	await _test_view_turns_only_outside_the_box()
	await _test_end_drag_resets_accumulator()
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
# 갔다 — 손가락과 반대 사분면이다. 어떤 시점, 어떤 방향으로 끌어도 조각의 화면
# 이동이 손가락과 같은 쪽이어야 한다.
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
			# 매번 한가운데의 O 조각으로 되돌린다. 2x2 라 어느 쪽으로도 한 칸은 간다.
			game.current = Piece.create(2)
			game.current.origin = game.spawn_origin_for(game.current)
			var before := cam.unproject_position(Vector3(game.current.origin))
			input.begin_drag(input.box_screen_rect().get_center())
			input.feed_drag(d * 200.0)
			var moved := cam.unproject_position(Vector3(game.current.origin)) - before
			assert(moved.length() > 0.0,
				"yaw %d: 손가락 %s 로 200픽셀 끌었는데 조각이 안 움직였다" % [s, d])
			assert(moved.dot(d) > 0.0,
				"yaw %d: 손가락 %s 로 끌었는데 조각이 화면에서 %s 로 갔다" % [s, d, moved])
	main.queue_free()

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
