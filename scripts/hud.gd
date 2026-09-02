extends CanvasLayer

var game: Game = null
var rig: CameraRig = null

func setup(g: Game, r: CameraRig) -> void:
	game = g
	rig = r
	# 버튼은 축 이름이 아니라 화면에서 조각이 도는 방향으로 나뉜다.
	# 좌->우 는 세로축, 상->하 는 화면 가로축, 시계는 시선축 회전이다.
	$Bottom/RotateRight.pressed.connect(_rotate.bind(rig.rot_screen_right))
	$Bottom/RotateDown.pressed.connect(_rotate.bind(rig.rot_screen_down))
	$Bottom/RotateClock.pressed.connect(_rotate.bind(rig.rot_screen_clockwise))
	$Bottom/Drop.pressed.connect(func() -> void: game.hard_drop())
	# 회전과 내리기는 조각이 실제로 움직였을 때 Game 이 소리를 낸다. 막혀서
	# 아무 일도 안 일어났으면 소리도 나면 안 된다. 나머지 버튼만 여기서 딸깍.
	$Side/Pause.pressed.connect(Sfx.play.bind(Sfx.UI))
	$Side/Quit.pressed.connect(Sfx.play.bind(Sfx.UI))
	$Side/Pause.pressed.connect(toggle_pause)
	$Side/Quit.pressed.connect(quit_to_menu)
	game.layers_cleared.connect(_on_cleared)
	# next_kind 은 _spawn 끝에서야 다음 값으로 넘어간다. piece_locked 에 물리면
	# 견본이 한 박자 늦어 "지금 내려오는 조각" 색을 보여준다.
	game.piece_moved.connect(_refresh_next)
	game.game_over.connect(_on_game_over)
	$GameOver.visible = false
	$Paused.visible = false
	$Side/NextBox/NextView.setup(game)
	_refresh_score()
	_refresh_next()
	$LayerGauge.setup(game)

const FLASH_ALPHA := 0.32
const FLASH_TIME := 0.35

func _on_cleared(_ys: PackedInt32Array, _kind: int) -> void:
	_refresh_score()
	# 화면이 한 번 번쩍한다. 불티만으로는 층이 사라진 순간을 놓치기 쉽다.
	$Flash.modulate.a = FLASH_ALPHA
	create_tween().tween_property($Flash, "modulate:a", 0.0, FLASH_TIME)

# 다음 조각 미리보기. 색만으로는 3D 조각 8종을 구분하기 어려워 작은 3D 뷰에
# 모양까지 그린다.
func _refresh_next() -> void:
	$Side/NextBox/NextView.refresh()

# 회전 축은 화면 기준이다. 어떤 격자축이 되는지는 CameraRig 가 지금 시점을
# 보고 정한다 — 버튼은 축을 고르는 함수를 들고 있다가 누를 때마다 새로 묻는다.
func _rotate(pick: Callable) -> void:
	var a: Array = pick.call()
	game.rotate(a[0], a[1])

func _refresh_score() -> void:
	# 오른쪽 세로 패널이라 줄을 나눠 쌓는다. 통 위쪽을 비워 두려고 옮긴 자리다.
	$Side/Score.text = "점수 %d\n레벨 %d\n최고 %d" % [
		game.score, game.level, SaveData.load_high_score()]

# 일시정지는 낙하뿐 아니라 조작까지 멈춘다 — 멈춘 채로 조각을 옮길 수 있으면
# 일시정지가 곧 치트다. 멈춤 여부는 Game 이 들고 있다.
func toggle_pause() -> void:
	if game.is_over:
		return
	game.paused = not game.paused
	$Paused.visible = game.paused
	$Side/Pause.text = "계속" if game.paused else "일시정지"

func quit_to_menu() -> void:
	SaveData.submit(game.score)
	get_tree().change_scene_to_file("res://scenes/start.tscn")

func _on_game_over() -> void:
	var best := SaveData.submit(game.score)
	$GameOver.text = "게임 종료\n점수 %d   최고 %d\nR 다시 시작 · ESC 처음으로" % [game.score, best]
	$GameOver.visible = true
	_refresh_score()  # 방금 갱신된 최고 기록을 상단 표시에도 반영한다

# 재시작할 때 이전 판의 점수와 미리보기가 남지 않도록 전부 새로 그린다.
func restart() -> void:
	$GameOver.visible = false
	$Paused.visible = false
	$Side/Pause.text = "일시정지"
	$Paused.visible = false
	_refresh_score()
	_refresh_next()
	$LayerGauge.refresh()
