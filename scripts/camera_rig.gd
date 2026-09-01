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
const TURN_TIME := 0.25

var yaw_step := 0

var _tween: Tween = null
# 목표 각도를 누적해서 따로 들고 있는다. 진행 중인 트윈의 중간값에서 90도를 더하면
# 빠르게 두 번 돌렸을 때 화면 각도가 yaw_step 과 영구히 어긋난다.
var _yaw_target := YAW_BASE_DEG

func _ready() -> void:
	rotation_degrees = Vector3(PITCH_DEG, _yaw_target, 0.0)

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
	var target := rotation_degrees
	target.y = _yaw_target
	_tween.tween_property(self, "rotation_degrees", target, TURN_TIME)

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
