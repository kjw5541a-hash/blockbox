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
	_fit_box_to_the_left()
	# 층이 지워지면 통이 흔들린다. 흔드는 건 카메라 몫이라 여기서 잇는다.
	game.layers_cleared.connect(
		func(_ys: PackedInt32Array, _kind: int) -> void: rig.shake())
	game.start()
	$HUD.setup(game, rig)

# 점수와 버튼이 오른쪽 세로 패널로 모여 있어 통은 왼쪽에 붙는다. 밀 수 있는
# 폭은 통 크기에 따라 다르다 — 6x6 은 화면 폭을 거의 다 쓰므로 밀 자리가 없다.
# 그래서 고정값 대신 통이 화면에서 실제로 차지하는 자리를 재서 정한다.
# 왼쪽 층 게이지와의 간격, 화면 가장자리 여백이 한계다.
const BOX_GAUGE_GAP := 48.0
const BOX_EDGE_MARGIN := 40.0

func _fit_box_to_the_left() -> void:
	var cam := rig.get_node("Camera3D") as Camera3D
	cam.h_offset = 0.0
	var left: float = touch_input.box_screen_rect().position.x
	# 게이지 오른쪽 끝. 앵커가 왼쪽이라 배치 계산 전에도 offset 이 곧 위치다.
	var gauge_right: float = $HUD/LayerGauge.offset_right
	var room := maxf(0.0, left - BOX_EDGE_MARGIN)
	var shift := clampf(left - (gauge_right + BOX_GAUGE_GAP), 0.0, room)
	# 직교 투영이라 화면 픽셀과 월드 단위의 비가 화면 어디서나 같다.
	var per_unit: float = get_viewport().get_visible_rect().size.y / cam.size
	cam.h_offset = shift / per_unit

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
			var a: Array = rig.rot_screen_down()
			game.rotate(a[0], a[1])
		KEY_X:
			var a: Array = rig.rot_screen_right()
			game.rotate(a[0], a[1])
		KEY_C:
			var a: Array = rig.rot_screen_clockwise()
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
			$HUD.quit_to_menu()
		KEY_P:
			$HUD.toggle_pause()
