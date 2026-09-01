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

# 동시 클리어 배율. 3D에서는 여러 층을 한 번에 지우는 것이 유일한 고득점 수단이라
# 보상을 크게 잡는다. 인덱스가 지운 층 수다.
const CLEAR_MULTIPLIER := [0, 1, 3, 6, 12]
const SCORE_PER_LAYER := 100
const LEVEL_UP_LAYERS := 5

# 회전이 막혔을 때 조각을 밀어보는 순서. 위로 미는 것을 마지막에 두는 이유는
# 조각이 위로 밀리면 예상 착지 지점이 크게 달라져 플레이어의 예측이 깨지기 때문이다.
# 보드가 4칸 폭이라 한 칸 밀기로는 부족하다. 가로 4칸짜리 I 조각을 세로로 돌리면
# 중심이 최대 세 칸까지 밀려나고(보드 폭 전체), 바닥 근처에서 세우려면 세 칸
# 내려야 한다. 이보다 좁으면 벽에 붙은 I 조각이 영영 안 돌아간다.
const KICKS: Array[Vector3i] = [
	Vector3i.ZERO,
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	Vector3i(2, 0, 0), Vector3i(-2, 0, 0),
	Vector3i(0, 0, 2), Vector3i(0, 0, -2),
	Vector3i(3, 0, 0), Vector3i(-3, 0, 0),
	Vector3i(0, 0, 3), Vector3i(0, 0, -3),
	Vector3i(0, -1, 0), Vector3i(0, -2, 0), Vector3i(0, -3, 0),
	Vector3i(0, 1, 0),
]

var board := Board.new()
var current: Piece = null
var next_kind := 0
var is_over := false
var level := 1
var score := 0
var total_layers := 0

var _bag: Array[int] = []
var _fall_timer := 0.0
var _lock_timer := 0.0
var _lock_resets := 0
var _grounded := false

func start(rng_seed: int = 0) -> void:
	board = Board.new()
	is_over = false
	score = 0
	level = 1
	total_layers = 0
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
		if move(Vector3i(0, -1, 0)):
			# 한 칸 내려갔으면 이전 접지에서 쌓인 시간과 예산은 무효다. 이걸 안 지우면
			# 예산을 다 쓴 조각이 턱에서 미끄러져 내려온 순간 바로 잠긴다.
			_lock_timer = 0.0
			_lock_resets = 0
		else:
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
	var n := board.clear_layers()
	if n > 0:
		total_layers += n
		score += SCORE_PER_LAYER * level * CLEAR_MULTIPLIER[mini(n, 4)]
		level = total_layers / LEVEL_UP_LAYERS + 1
		layers_cleared.emit(n)
	_spawn()

func footprint_cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if current == null:
		return out
	var seen := {}
	for c in current.world_cells():
		var flat := Vector3i(c.x, 0, c.z)
		if seen.has(flat):
			continue
		seen[flat] = true
		out.append(flat)
	return out

func rotate(axis: int, dir: int) -> bool:
	if current == null or is_over:
		return false
	var turned := current.rotated(axis, dir)
	for k in KICKS:
		var candidate := turned.copy()
		candidate.origin = current.origin + k
		if board.is_valid(candidate.world_cells()):
			current = candidate
			_on_piece_changed()
			return true
	return false
