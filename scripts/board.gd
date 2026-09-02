class_name Board
extends RefCounted

# 가로/세로는 시작 화면에서 고른다. 상수가 아니라 정적 변수인 이유는
# 뷰(BoardView, BoxFrame, LayerGauge)가 전부 Board.WIDTH 를 직접 읽기 때문이다.
# 한 번에 한 판만 돌아가므로 전역 하나로 충분하다. 반드시 씬을 띄우기 전에
# GameConfig.apply() 로 맞춰 놓아야 한다.
static var WIDTH := 4
static var DEPTH := 4
const HEIGHT := 14
static var LAYER_CELLS := WIDTH * DEPTH

# 튜닝 손잡이: 층 클리어에 필요한 칸 수. GameConfig 가 난이도에 맞춰 넣는다.
static var LAYER_CLEAR_THRESHOLD := 16

var cells := PackedInt32Array()

func _init() -> void:
	cells.resize(WIDTH * DEPTH * HEIGHT)
	cells.fill(0)

static func resize(w: int, d: int, threshold: int) -> void:
	WIDTH = w
	DEPTH = d
	LAYER_CELLS = w * d
	LAYER_CLEAR_THRESHOLD = threshold

static func index(x: int, y: int, z: int) -> int:
	return y * LAYER_CELLS + z * WIDTH + x

static func in_bounds(c: Vector3i) -> bool:
	return c.x >= 0 and c.x < WIDTH \
		and c.y >= 0 and c.y < HEIGHT \
		and c.z >= 0 and c.z < DEPTH

func get_cell(c: Vector3i) -> int:
	assert(in_bounds(c), "범위 밖 좌표: %s" % c)
	return cells[index(c.x, c.y, c.z)]

func is_valid(world_cells: Array[Vector3i]) -> bool:
	for c in world_cells:
		if not in_bounds(c):
			return false
		if get_cell(c) != 0:
			return false
	return true

func lock(world_cells: Array[Vector3i], kind: int) -> void:
	for c in world_cells:
		assert(in_bounds(c), "범위 밖 좌표: %s" % c)
		cells[index(c.x, c.y, c.z)] = kind

func layer_fill_count(y: int) -> int:
	assert(y >= 0 and y < HEIGHT, "범위 밖 층: %d" % y)
	var n := 0
	var base := y * LAYER_CELLS
	for i in LAYER_CELLS:
		if cells[base + i] != 0:
			n += 1
	return n

# 지워진 층의 번호를 낮은 층부터 돌려준다. 층이 무너져 내리기 전 자리라,
# 지워지는 순간 그 자리에 무언가를 띄우려면 이 번호가 필요하다.
func clear_layers() -> PackedInt32Array:
	var kept := PackedInt32Array()
	var cleared := PackedInt32Array()
	for y in HEIGHT:
		if layer_fill_count(y) >= LAYER_CLEAR_THRESHOLD:
			cleared.append(y)
			continue
		kept.append_array(cells.slice(y * LAYER_CELLS, (y + 1) * LAYER_CELLS))
	# resize 로 늘어난 칸은 0으로 채워지므로 위쪽에 빈 층이 생긴다.
	kept.resize(WIDTH * DEPTH * HEIGHT)
	cells = kept
	return cleared
