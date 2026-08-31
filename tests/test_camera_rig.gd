extends SceneTree

const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)
const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)

func _initialize() -> void:
	_test_up_is_always_away()
	_test_opposite_directions_cancel()
	_test_turn_rotates_mapping_consistently()
	_test_deltas_are_unit_axes()
	_test_tilt_axis()
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
