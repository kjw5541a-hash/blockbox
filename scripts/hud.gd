extends CanvasLayer

var game: Game = null
var rig: CameraRig = null

func setup(g: Game, r: CameraRig) -> void:
	game = g
	rig = r
	$Bottom/RotateX.pressed.connect(_rotate_x)
	$Bottom/RotateY.pressed.connect(func() -> void: game.rotate(Piece.AXIS_Y, 1))
	$Bottom/RotateZ.pressed.connect(_rotate_z)
	$Bottom/Drop.pressed.connect(func() -> void: game.hard_drop())
	game.layers_cleared.connect(func(_n: int) -> void: _refresh_score())
	# next_kind 은 _spawn 끝에서야 다음 값으로 넘어간다. piece_locked 에 물리면
	# 견본이 한 박자 늦어 "지금 내려오는 조각" 색을 보여준다.
	game.piece_moved.connect(_refresh_next)
	game.game_over.connect(_on_game_over)
	$GameOver.visible = false
	_refresh_score()
	_refresh_next()
	$LayerGauge.setup(game)

# 다음 조각 미리보기. 3D 미니 뷰포트 대신 색 견본 하나로 보여준다.
# 조각 종류는 색으로 구분되므로 이것으로 충분하다.
func _refresh_next() -> void:
	$Top/NextSwatch.color = BlockColors.of(game.next_kind)

# 회전 축은 화면 기준이다. X 는 화면 가로축, Y 는 화면 세로축(항상 월드 Y),
# Z 는 화면 안팎축. 시점을 돌리면 X 와 Z 가 가리키는 격자축도 같이 따라간다.
func _rotate_x() -> void:
	var a: Array = rig.tilt_axis(rig.axis_right())
	game.rotate(a[0], a[1])

func _rotate_z() -> void:
	var a: Array = rig.tilt_axis(rig.axis_away())
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
