class_name Game
extends Node

signal piece_moved
signal piece_locked
signal layers_cleared(count: int)
signal game_over

const BASE_FALL_INTERVAL := 1.0
const MIN_FALL_INTERVAL := 0.15
const FALL_SPEEDUP := 0.85
const LOCK_DELAY := 0.5
const MAX_LOCK_RESETS := 15

var board := Board.new()
var current: Piece = null
var next_kind := 0
var is_over := false
var level := 1

var _bag: Array[int] = []
var _fall_timer := 0.0
var _lock_timer := 0.0
var _lock_resets := 0
var _grounded := false

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
	_fall_timer = 0.0
	_lock_timer = 0.0
	_lock_resets = 0
	_grounded = false
	piece_moved.emit()

func fall_interval() -> float:
	return maxf(MIN_FALL_INTERVAL, BASE_FALL_INTERVAL * pow(FALL_SPEEDUP, level - 1))

func move(delta: Vector3i) -> bool:
	if current == null or is_over:
		return false
	var moved := current.copy()
	moved.origin += delta
	if not board.is_valid(moved.world_cells()):
		return false
	current = moved
	_on_piece_changed()
	return true

func _can_fall() -> bool:
	if current == null:
		return false
	var down := current.copy()
	down.origin += Vector3i(0, -1, 0)
	return board.is_valid(down.world_cells())

func _on_piece_changed() -> void:
	_grounded = not _can_fall()
	# 접지될 때마다 예산을 쓴다. 땅에서 벗어났다 돌아오는 것을 공짜로 쳐주면
	# 조각을 좌우로 흔들어 영원히 잠기지 않게 만들 수 있다.
	if _grounded and _lock_resets < MAX_LOCK_RESETS:
		_lock_timer = 0.0
		_lock_resets += 1
	piece_moved.emit()

func step(delta: float) -> void:
	if is_over or current == null:
		return
	if not _grounded:
		_grounded = not _can_fall()
	if _grounded:
		_lock_timer += delta
		if _lock_timer >= LOCK_DELAY:
			_lock_current()
		return
	_fall_timer += delta
	if _fall_timer >= fall_interval():
		_fall_timer = 0.0
		if not move(Vector3i(0, -1, 0)):
			_grounded = true
			_lock_timer = 0.0

func hard_drop() -> void:
	if current == null or is_over:
		return
	while move(Vector3i(0, -1, 0)):
		pass
	_lock_current()

func ghost_cells() -> Array[Vector3i]:
	if current == null:
		return []
	var g := current.copy()
	while true:
		var down := g.copy()
		down.origin += Vector3i(0, -1, 0)
		if not board.is_valid(down.world_cells()):
			break
		g = down
	return g.world_cells()

func _lock_current() -> void:
	if current == null:
		return
	board.lock(current.world_cells(), current.kind)
	current = null
	piece_locked.emit()
	_spawn()
