extends Node3D

# 키 한 번에 움직이는 상하각. 손가락 조작은 다음에 붙인다.
const PITCH_KEY_STEP := 5.0

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
	$LayerBurst.setup(game)
	touch_input.setup(game, rig)
	# 층이 지워지면 통이 흔들린다. 흔드는 건 카메라 몫이라 여기서 잇는다.
	game.layers_cleared.connect(
		func(_ys: PackedInt32Array, _kind: int) -> void: rig.shake())
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
			var a: Array = rig.rot_screen_x()
			game.rotate(a[0], a[1])
		KEY_X:
			var a: Array = rig.rot_screen_y()
			game.rotate(a[0], a[1])
		KEY_C:
			var a: Array = rig.rot_screen_z()
			game.rotate(a[0], a[1])
		KEY_Q:
			rig.turn(-1)
		KEY_E:
			rig.turn(1)
		KEY_W:
			rig.pitch_by(-PITCH_KEY_STEP)
		KEY_S:
			rig.pitch_by(PITCH_KEY_STEP)
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
