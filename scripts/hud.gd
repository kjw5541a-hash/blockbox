extends CanvasLayer

var game: Game = null
var rig: CameraRig = null

func setup(g: Game, r: CameraRig) -> void:
	game = g
	rig = r
	$Bottom/RotateX.pressed.connect(_rotate.bind(rig.rot_screen_x))
	$Bottom/RotateY.pressed.connect(_rotate.bind(rig.rot_screen_y))
	$Bottom/RotateZ.pressed.connect(_rotate.bind(rig.rot_screen_z))
	$Bottom/Drop.pressed.connect(func() -> void: game.hard_drop())
	game.layers_cleared.connect(_on_cleared)
	# next_kind 은 _spawn 끝에서야 다음 값으로 넘어간다. piece_locked 에 물리면
	# 견본이 한 박자 늦어 "지금 내려오는 조각" 색을 보여준다.
	game.piece_moved.connect(_refresh_next)
	game.game_over.connect(_on_game_over)
	$GameOver.visible = false
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

# 다음 조각 미리보기. 3D 미니 뷰포트 대신 색 견본 하나로 보여준다.
# 조각 종류는 색으로 구분되므로 이것으로 충분하다.
func _refresh_next() -> void:
	$Top/NextSwatch.color = BlockColors.of(game.next_kind)

# 회전 축은 화면 기준이다. 어떤 격자축이 되는지는 CameraRig 가 지금 시점을
# 보고 정한다 — 버튼은 축을 고르는 함수를 들고 있다가 누를 때마다 새로 묻는다.
func _rotate(pick: Callable) -> void:
	var a: Array = pick.call()
	game.rotate(a[0], a[1])

func _refresh_score() -> void:
	$Top/Score.text = "점수 %d   레벨 %d   최고 %d" % [
		game.score, game.level, SaveData.load_high_score()]

func _on_game_over() -> void:
	var best := SaveData.submit(game.score)
	$GameOver.text = "게임 종료\n점수 %d   최고 %d\nR 다시 시작 · ESC 처음으로" % [game.score, best]
	$GameOver.visible = true
	_refresh_score()  # 방금 갱신된 최고 기록을 상단 표시에도 반영한다

# 재시작할 때 이전 판의 점수와 미리보기가 남지 않도록 전부 새로 그린다.
func restart() -> void:
	$GameOver.visible = false
	_refresh_score()
	_refresh_next()
	$LayerGauge.refresh()
