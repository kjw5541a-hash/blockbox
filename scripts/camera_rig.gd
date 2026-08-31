class_name CameraRig
extends Node3D

# 화면 방향과 그리드 축의 대응. 이 파일이 단독으로 소유한다.
# 다른 파일이 화면 방향을 그리드 축으로 직접 변환하면, 시점을 돌린 뒤
# 이동 매핑과 회전축 매핑이 어긋난다.
const AWAY: Array[Vector3i] = [
	Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(1, 0, 0),
]
const RIGHT: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1),
]

const YAW_BASE_DEG := 45.0
const PITCH_DEG := -30.0
const TURN_TIME := 0.25

var yaw_step := 0

var _tween: Tween = null

func _ready() -> void:
	rotation_degrees = Vector3(PITCH_DEG, _yaw_degrees(), 0.0)

func _yaw_degrees() -> float:
	return YAW_BASE_DEG + 90.0 * yaw_step

func turn(dir: int) -> void:
	yaw_step = wrapi(yaw_step + dir, 0, 4)
	if not is_inside_tree():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target := rotation_degrees
	target.y += 90.0 * dir
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
