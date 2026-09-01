extends SceneTree

const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)
const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)

func _initialize() -> void:
	await _test_axes_match_real_camera()
	_test_up_is_always_away()
	_test_opposite_directions_cancel()
	_test_turn_rotates_mapping_consistently()
	_test_deltas_are_unit_axes()
	_test_tilt_axis()
	_test_mapping_is_pinned_to_axes()
	_test_visual_yaw_tracks_yaw_step()
	print("test_camera_rig: OK")
	quit()

func _rig() -> CameraRig:
	var r := CameraRig.new()
	root.add_child(r)
	return r

func _test_up_is_always_away() -> void:
	var r := _rig()
	for s in 4:
		r.yaw_step = s
		assert(r.move_delta(UP) == r.axis_away(),
			"yaw %d: 위로 끌기는 항상 화면 안쪽이어야 한다" % s)
		assert(r.move_delta(RIGHT) == r.axis_right(),
			"yaw %d: 오른쪽 끌기는 항상 화면 오른쪽이어야 한다" % s)

func _test_opposite_directions_cancel() -> void:
	var r := _rig()
	for s in 4:
		r.yaw_step = s
		assert(r.move_delta(UP) + r.move_delta(DOWN) == Vector3i.ZERO,
			"yaw %d: 위/아래가 서로 반대여야 한다" % s)
		assert(r.move_delta(LEFT) + r.move_delta(RIGHT) == Vector3i.ZERO,
			"yaw %d: 좌/우가 서로 반대여야 한다" % s)

func _test_turn_rotates_mapping_consistently() -> void:
	var r := _rig()
	for s in 4:
		r.yaw_step = s
		var away_before := r.axis_away()
		r.turn(1)
		assert(r.axis_right() == away_before,
			"yaw %d: 시점을 돌리면 이전의 '안쪽'이 새 '오른쪽'이 되어야 한다" % s)
	# 네 번 돌리면 제자리
	r.yaw_step = 0
	for _i in 4:
		r.turn(1)
	assert(r.yaw_step == 0, "네 번 돌리면 원래 시점")

func _test_deltas_are_unit_axes() -> void:
	var r := _rig()
	for s in 4:
		r.yaw_step = s
		for d in [UP, DOWN, LEFT, RIGHT]:
			var v := r.move_delta(d)
			assert(v.y == 0, "수평 이동에 Y 성분이 있으면 안 된다")
			assert(absi(v.x) + absi(v.z) == 1, "이동은 한 축으로 한 칸이어야 한다: %s" % v)

func _test_tilt_axis() -> void:
	var r := _rig()
	assert(r.tilt_axis(Vector3i(1, 0, 0)) == [Piece.AXIS_X, 1])
	assert(r.tilt_axis(Vector3i(-1, 0, 0)) == [Piece.AXIS_X, -1])
	assert(r.tilt_axis(Vector3i(0, 0, 1)) == [Piece.AXIS_Z, 1])
	assert(r.tilt_axis(Vector3i(0, 0, -1)) == [Piece.AXIS_Z, -1])

func _test_mapping_is_pinned_to_axes() -> void:
	# 관계만 확인하면 AWAY 와 RIGHT 를 통째로 맞바꿔도 대부분의 테스트가 통과한다.
	var r := _rig()
	assert(r.axis_away() == Vector3i(0, 0, -1), "기본 시점의 안쪽은 -Z")
	assert(r.axis_right() == Vector3i(1, 0, 0), "기본 시점의 오른쪽은 +X")
	r.yaw_step = 1
	assert(r.axis_away() == Vector3i(-1, 0, 0), "한 번 돌린 시점의 안쪽은 -X")
	assert(r.axis_right() == Vector3i(0, 0, -1), "한 번 돌린 시점의 오른쪽은 -Z")

# 위의 테스트들은 전부 move_delta 나 표끼리의 관계만 본다. 표 전체가 뒤집혀도
# 자기들끼리는 앞뒤가 맞아 통과한다. 여기서만 실제 씬의 Camera3D 변환을 읽어
# "화면 안쪽"과 "화면 오른쪽"이 정말 그 방향인지 확인한다.
func _test_axes_match_real_camera() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame
	var r: CameraRig = main.rig
	var cam: Camera3D = r.get_node("Camera3D")
	for s in 4:
		r.yaw_step = s
		# 트윈을 기다리지 않고 목표 각도를 바로 넣는다.
		r.rotation_degrees = Vector3(
			CameraRig.PITCH_DEG, CameraRig.YAW_BASE_DEG + 90.0 * s, 0.0)
		await process_frame
		var forward := -cam.global_transform.basis.z  # 카메라는 자기 -Z 를 본다
		var screen_right := cam.global_transform.basis.x
		assert(Vector3(r.axis_away()).dot(forward) > 0.0,
			"yaw %d: axis_away %s 가 화면 안쪽 %s 과 반대다" % [s, r.axis_away(), forward])
		assert(Vector3(r.axis_right()).dot(screen_right) > 0.0,
			"yaw %d: axis_right %s 가 화면 오른쪽 %s 과 반대다" % [s, r.axis_right(), screen_right])
	main.queue_free()

func _test_visual_yaw_tracks_yaw_step() -> void:
	var r := _rig()
	# 트윈이 끝나기 전에 연달아 돌려도 목표 각도가 yaw_step 과 어긋나면 안 된다.
	for dir in [1, 1, 1, -1, 1, 1]:
		r.turn(dir)
		var want := wrapf(CameraRig.YAW_BASE_DEG + 90.0 * r.yaw_step, 0.0, 360.0)
		var got := wrapf(r.yaw_degrees(), 0.0, 360.0)
		assert(absf(want - got) < 0.001,
			"yaw_step %d 인데 화면 각도가 %f, 기대 %f" % [r.yaw_step, got, want])
