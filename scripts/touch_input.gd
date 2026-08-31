class_name TouchInput
extends Node

# 손가락이 이만큼 움직일 때마다 한 칸 이동한다.
const STEP_PIXELS := 40.0

var game: Game = null
var rig: CameraRig = null

var _accum := Vector2.ZERO

func setup(g: Game, r: CameraRig) -> void:
	game = g
	rig = r

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		feed_drag(event.relative)
	elif event is InputEventScreenTouch and not event.pressed:
		end_drag()

func end_drag() -> void:
	_accum = Vector2.ZERO

func feed_drag(relative: Vector2) -> void:
	if game == null or rig == null or game.current == null:
		return
	_accum += relative
	# 두 축을 동시에 소비하면 대각선 이동이 되어 조준이 흐트러진다.
	# 더 많이 끈 축 하나만 처리한다.
	while absf(_accum.x) >= STEP_PIXELS or absf(_accum.y) >= STEP_PIXELS:
		var dir: Vector2i
		if absf(_accum.x) >= absf(_accum.y):
			dir = Vector2i(signi(int(_accum.x)), 0)
			_accum.x -= STEP_PIXELS * dir.x
		else:
			dir = Vector2i(0, signi(int(_accum.y)))
			_accum.y -= STEP_PIXELS * dir.y
		game.move(rig.move_delta(dir))
