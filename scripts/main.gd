extends Node3D

@onready var game: Game = $Game
@onready var rig: CameraRig = $CameraRig
@onready var board_view := $BoardView
@onready var piece_view := $PieceView
@onready var touch_input := $TouchInput

func _ready() -> void:
	# 통 크기는 시작 화면에서 정해진다. 카메라를 통의 한가운데로 옮겨 맞춘다.
	rig.position = Vector3(
		(Board.WIDTH - 1) * 0.5, (Board.HEIGHT - 1) * 0.5, (Board.DEPTH - 1) * 0.5)
	board_view.setup(game)
	piece_view.setup(game)
	touch_input.setup(game, rig)
	game.start()
	$HUD.setup(game, rig)

func _process(delta: float) -> void:
	game.step(delta)

# 개발용 키보드 조작. 터치를 붙인 뒤에도 디버깅용으로 남긴다.
# 회전 키는 HUD 버튼과 같은 화면 기준 축을 쓴다.
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
			var a: Array = rig.tilt_axis(rig.axis_right())
			game.rotate(a[0], a[1])
		KEY_X:
			game.rotate(Piece.AXIS_Y, 1)
		KEY_C:
			var a: Array = rig.tilt_axis(rig.axis_away())
			game.rotate(a[0], a[1])
		KEY_Q:
			rig.turn(-1)
		KEY_E:
			rig.turn(1)
		KEY_R:
			# 게임오버 전에 눌러도 이번 판 점수는 기록에 남긴다.
			SaveData.submit(game.score)
			touch_input.end_drag()
			game.start()
			board_view.refresh()
			piece_view.refresh()
			$HUD.restart()
		KEY_ESCAPE:
			SaveData.submit(game.score)
			get_tree().change_scene_to_file("res://scenes/start.tscn")
