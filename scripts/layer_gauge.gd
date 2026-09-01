extends VBoxContainer

const BAR_HEIGHT := 14
const EMPTY_COLOR := Color(1, 1, 1, 0.12)
const FILL_COLOR := Color(0.45, 0.80, 0.50, 0.9)
const NEAR_COLOR := Color(0.95, 0.80, 0.35, 0.95)

var game: Game = null

var _bars: Array[ColorRect] = []

func _ready() -> void:
	# 위층이 위에 오도록 역순으로 만든다.
	for _i in Board.HEIGHT:
		var back := ColorRect.new()
		back.color = EMPTY_COLOR
		back.custom_minimum_size = Vector2(48, BAR_HEIGHT)
		var fill := ColorRect.new()
		fill.color = FILL_COLOR
		# back 은 VBoxContainer 가 배치하지만 fill 은 컨테이너의 자식이 아니므로
		# 크기를 직접 정할 수 있다.
		fill.position = Vector2.ZERO
		back.add_child(fill)
		add_child(back)
		_bars.append(fill)

func setup(g: Game) -> void:
	game = g
	game.piece_locked.connect(refresh)
	game.layers_cleared.connect(func(_n: int) -> void: refresh())
	refresh()

func refresh() -> void:
	if game == null:
		return
	for i in Board.HEIGHT:
		var y := Board.HEIGHT - 1 - i  # 화면 위쪽이 높은 층
		var n := game.board.layer_fill_count(y)
		var bar := _bars[i]
		bar.size = Vector2(48.0 * float(n) / float(Board.LAYER_CELLS), BAR_HEIGHT)
		# 한 칸만 남았으면 색을 바꿔 알려준다.
		bar.color = NEAR_COLOR if n >= Board.LAYER_CLEAR_THRESHOLD - 1 else FILL_COLOR
