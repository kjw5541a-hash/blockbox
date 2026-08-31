extends Node3D

@onready var game: Game = $Game
@onready var rig: CameraRig = $CameraRig
@onready var board_view := $BoardView
@onready var piece_view := $PieceView
@onready var touch_input := $TouchInput

func _ready() -> void:
	board_view.setup(game)
	piece_view.setup(game)
	touch_input.setup(game, rig)
	game.start()

func _process(delta: float) -> void:
	game.step(delta)

# 개발용 키보드 조작. 터치를 붙인 뒤에도 디버깅용으로 남긴다.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT:
			game.move(rig.move_delta(Vector2i(-1, 0)))
		KEY_RIGHT:
			game.move(rig.move_delta(Vector2i(1, 0)))
		KEY_UP:
			game.move(rig.move_delta(Vector2i(0, -1)))
		KEY_DOWN:
			game.move(rig.move_delta(Vector2i(0, 1)))
		KEY_SPACE:
			game.hard_drop()
		KEY_Z:
			game.rotate(Piece.AXIS_Y, -1)
		KEY_X:
			game.rotate(Piece.AXIS_Y, 1)
		KEY_C:
			var a: Array = rig.tilt_axis(rig.axis_right())
			game.rotate(a[0], a[1])
		KEY_V:
			var a: Array = rig.tilt_axis(rig.axis_away())
			game.rotate(a[0], a[1])
		KEY_Q:
			rig.turn(-1)
		KEY_E:
			rig.turn(1)
		KEY_R:
			game.start()
			board_view.refresh()
			piece_view.refresh()
