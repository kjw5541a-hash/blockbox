class_name CameraRig
extends Node3D

# 화면 방향과 그리드 축의 대응. 이 파일이 단독으로 소유한다.
# 다른 파일이 화면 방향을 그리드 축으로 직접 변환하면, 시점을 돌린 뒤
# 이동 매핑과 회전축 매핑이 어긋난다.
# 값은 실제 카메라 기저에서 나온 것이다. 리그가 (PITCH_DEG, YAW_BASE_DEG + 90*step)
# 으로 놓이면 yaw_step 0 에서 카메라는 -X/-Z 쪽을 바라본다 — 즉 화면 안쪽은 -Z 다.
# tests/test_camera_rig.gd 의 _test_axes_match_real_camera 가 이 표를 카메라
# 기저와 직접 대조한다. 관계만 보는 테스트는 표 전체가 뒤집혀도 통과한다.
const AWAY: Array[Vector3i] = [
	Vector3i(0, 0, -1), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0),
]
const RIGHT: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(0, 0, -1), Vector3i(-1, 0, 0), Vector3i(0, 0, 1),
]

const YAW_BASE_DEG := 45.0
# -30 도에서는 두 수평 격자축이 화면에서 ±27 도로만 벌어져 위/옆 구분이 안 된다.
# -45 도면 ±35 도로 벌어지고, 통 위아래 여백도 늘어 통 바깥 스와이프가 편해진다.
const PITCH_DEG := -45.0
# 상하각을 움직일 수 있는 범위. -90 은 바로 위에서 내려다보는 탑뷰다.
# 아래쪽 한계가 -35 인 이유는 위 주석과 같다 — 더 눕히면 두 수평 격자축이
# 화면에서 겹쳐, 드래그를 축별로 분해하는 TouchInput._feed_piece 가 무너진다.
const PITCH_MIN := -90.0
const PITCH_MAX := -35.0
const TURN_TIME := 0.25
# 층이 지워질 때의 짧은 흔들림.
const SHAKE_TIME := 0.24
const SHAKE_DIST := 0.14

var yaw_step := 0

var _tween: Tween = null
# 목표 각도를 누적해서 따로 들고 있는다. 진행 중인 트윈의 중간값에서 90도를 더하면
# 빠르게 두 번 돌렸을 때 화면 각도가 yaw_step 과 영구히 어긋난다.
var _yaw_target := YAW_BASE_DEG
var _pitch := PITCH_DEG
var _shake_tween: Tween = null
var _cam_home := Vector3.ZERO

func _ready() -> void:
	rotation_degrees = Vector3(_pitch, _yaw_target, 0.0)
	var cam := _camera()
	if cam != null:
		_cam_home = cam.position

func _camera() -> Camera3D:
	return get_node_or_null("Camera3D") as Camera3D

# 층이 지워질 때 통을 짧게 흔든다. 리그가 아니라 그 아래 카메라만 흔든다 —
# 리그 위치는 통 한가운데를 가리키는 기준점이라 건드리면 시점이 어긋난다.
func shake() -> void:
	var cam := _camera()
	if cam == null or not is_inside_tree():
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	cam.position = _cam_home
	_shake_tween = create_tween()
	var step := SHAKE_TIME / 4.0
	for i in 3:
		# 갈수록 잦아든다. 끝까지 같은 폭이면 흔들림이 안 끝난 것처럼 보인다.
		var fade := 1.0 - float(i) / 3.0
		var off := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0).normalized()
		_shake_tween.tween_property(cam, "position", _cam_home + off * SHAKE_DIST * fade, step)
	_shake_tween.tween_property(cam, "position", _cam_home, step)

# 현재 목표 각도. 감기지 않은 절대값이라 네 번 돌리면 360 이 된다.
func yaw_degrees() -> float:
	return _yaw_target

func turn(dir: int) -> void:
	yaw_step = wrapi(yaw_step + dir, 0, 4)
	_yaw_target += 90.0 * dir
	if not is_inside_tree():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# y 성분만 트윈한다. 벡터 전체를 트윈하면 시작할 때 찍어둔 상하각으로
	# 매 프레임 덮어써서, 도는 중에 기울인 각도가 도로 튕겨 나간다.
	_tween.tween_property(self, "rotation_degrees:y", _yaw_target, TURN_TIME)

# 현재 상하각. -90 이 탑뷰다.
func pitch_degrees() -> float:
	return _pitch

# 상하로 delta 도만큼 기울인다. 좌우 회전과 달리 격자축 대응(AWAY/RIGHT)에
# 쓰이지 않으므로 90도 단위로 끊지 않고 연속으로 움직인다. 트윈도 걸지 않는다 —
# 손가락이나 키를 따라 그 자리에서 바뀌어야 따라오는 느낌이 난다.
func pitch_by(delta: float) -> void:
	_pitch = clampf(_pitch + delta, PITCH_MIN, PITCH_MAX)
	rotation_degrees.x = _pitch

func axis_away() -> Vector3i:
	return AWAY[yaw_step]

func axis_right() -> Vector3i:
	return RIGHT[yaw_step]

# screen_dir 은 화면 좌표 기준이다. y 는 아래쪽이 +1.
func move_delta(screen_dir: Vector2i) -> Vector3i:
	return axis_right() * screen_dir.x + axis_away() * -screen_dir.y

# 눕히기 회전에 쓸 축을 [axis, dir] 로 돌려준다.
func tilt_axis(v: Vector3i) -> Array:
	if v.x != 0:
		return [Piece.AXIS_X, signi(v.x)]
	return [Piece.AXIS_Z, signi(v.z)]

# 화면 축을 기준으로 한 회전축을 [axis, dir] 로 돌려준다. 회전 버튼은 전부
# 이 셋을 거친다 — 시점을 돌리거나 눕히면 같은 버튼이 새 화면 기준으로 돈다.
#
# 화면 가로축은 상하각과 무관하게 axis_right 다. 세로축과 안팎축만 갈린다:
# 눕히기 전에는 월드 Y 가 화면 세로축, axis_away 가 안팎축이고, 탑뷰에서는
# 둘이 맞바뀐다. 갈아타는 지점은 -45 도다 — 셋을 겹치지 않게 붙일 때 화면과
# 가장 잘 맞는 배치가 그 각도에서 뒤집힌다. 경계값(기본 시점)은 눕히기 전 쪽.
const SCREEN_AXIS_CROSS := -45.0

# 앞면이 화면에서 어느 쪽으로 흐르는지가 이름이다. 버튼에 그려진 화살표가
# 곧 이 이름이다 — 축 이름으로 부르면 시점을 돌린 뒤 그림과 어긋난다.
# Piece.rotate_cell 의 dir 은 오른손 법칙과 반대로 돌므로 부호를 뒤집는다.
func _screen_turn(v: Vector3i) -> Array:
	var a := tilt_axis(v)
	return [a[0], -a[1]]

# 앞면이 위에서 아래로 넘어간다.
func rot_screen_down() -> Array:
	return _screen_turn(axis_right())

# 앞면이 왼쪽에서 오른쪽으로 흐른다.
func rot_screen_right() -> Array:
	if _pitch < SCREEN_AXIS_CROSS:
		return _screen_turn(axis_away())
	return [Piece.AXIS_Y, -1]

# 화면에서 시계 방향으로 돈다.
func rot_screen_clockwise() -> Array:
	if _pitch < SCREEN_AXIS_CROSS:
		# 탑뷰에서 화면 안쪽은 곧장 아래다.
		return [Piece.AXIS_Y, 1]
	return _screen_turn(axis_away())
