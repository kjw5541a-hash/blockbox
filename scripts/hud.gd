extends CanvasLayer

var game: Game = null
var rig: CameraRig = null

func setup(g: Game, r: CameraRig) -> void:
	game = g
	rig = r
	$Bottom/RotateCCW.pressed.connect(func() -> void: game.rotate(Piece.AXIS_Y, -1))
	$Bottom/RotateCW.pressed.connect(func() -> void: game.rotate(Piece.AXIS_Y, 1))
	$Bottom/TiltRight.pressed.connect(_tilt_right)
	$Bottom/TiltAway.pressed.connect(_tilt_away)
	$Bottom/Drop.pressed.connect(func() -> void: game.hard_drop())
	$Top/TurnLeft.pressed.connect(func() -> void: rig.turn(-1))
	$Top/TurnRight.pressed.connect(func() -> void: rig.turn(1))
	game.layers_cleared.connect(func(_n: int) -> void: _refresh_score())
	game.piece_locked.connect(_refresh_next)
	game.game_over.connect(_on_game_over)
	_refresh_score()
	_refresh_next()

# 다음 조각 미리보기. 3D 미니 뷰포트 대신 색 견본 하나로 보여준다.
# 조각 종류는 색으로 구분되므로 이것으로 충분하다.
func _refresh_next() -> void:
	$Top/NextSwatch.color = BlockColors.of(game.next_kind)

func _tilt_right() -> void:
	var a: Array = rig.tilt_axis(rig.axis_right())
	game.rotate(a[0], a[1])

func _tilt_away() -> void:
	var a: Array = rig.tilt_axis(rig.axis_away())
	game.rotate(a[0], a[1])

func _refresh_score() -> void:
	$Top/Score.text = "점수 %d   레벨 %d" % [game.score, game.level]

func _on_game_over() -> void:
	$GameOver.visible = true
