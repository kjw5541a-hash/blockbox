class_name Game
extends Node

signal piece_moved
signal piece_locked
signal layers_cleared(count: int)
signal game_over

var board := Board.new()
var current: Piece = null
var next_kind := 0
var is_over := false

var _bag: Array[int] = []

func start(rng_seed: int = 0) -> void:
	board = Board.new()
	is_over = false
	current = null
	_bag.clear()
	if rng_seed != 0:
		seed(rng_seed)
	next_kind = _draw_kind()
	_spawn()

func _draw_kind() -> int:
	if _bag.is_empty():
		for k in Piece.SHAPES.keys():
			_bag.append(k)
		_bag.shuffle()
	return _bag.pop_back()

# 조각을 가로/세로 중앙에 놓고 맨 위층에 붙인다.
func spawn_origin_for(p: Piece) -> Vector3i:
	var mn := Piece.bbox_min(p.cells)
	var mx := Piece.bbox_max(p.cells)
	var size := mx - mn + Vector3i.ONE
	return Vector3i(
		(Board.WIDTH - size.x) / 2 - mn.x,
		Board.HEIGHT - size.y - mn.y,
		(Board.DEPTH - size.z) / 2 - mn.z
	)

func _spawn() -> void:
	var p := Piece.create(next_kind)
	next_kind = _draw_kind()
	p.origin = spawn_origin_for(p)
	if not board.is_valid(p.world_cells()):
		current = null
		is_over = true
		game_over.emit()
		return
	current = p
	piece_moved.emit()
