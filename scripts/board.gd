class_name Board
extends RefCounted

const WIDTH := 4
const DEPTH := 4
const HEIGHT := 14
const LAYER_CELLS := WIDTH * DEPTH

# 튜닝 손잡이: 층 클리어에 필요한 칸 수. 클리어가 너무 안 나오면 낮춘다.
const LAYER_CLEAR_THRESHOLD := 16

var cells := PackedInt32Array()

func _init() -> void:
	cells.resize(WIDTH * DEPTH * HEIGHT)
	cells.fill(0)

static func index(x: int, y: int, z: int) -> int:
	return y * LAYER_CELLS + z * WIDTH + x

static func in_bounds(c: Vector3i) -> bool:
	return c.x >= 0 and c.x < WIDTH \
		and c.y >= 0 and c.y < HEIGHT \
		and c.z >= 0 and c.z < DEPTH

func get_cell(c: Vector3i) -> int:
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
		cells[index(c.x, c.y, c.z)] = kind

func layer_fill_count(y: int) -> int:
	var n := 0
	var base := y * LAYER_CELLS
	for i in LAYER_CELLS:
		if cells[base + i] != 0:
			n += 1
	return n
