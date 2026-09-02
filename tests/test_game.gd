extends SceneTree

func _make_game() -> Game:
	var g := Game.new()
	root.add_child(g)
	return g

func _initialize() -> void:
	_test_start_spawns_piece()
	_test_spawn_is_inside_board()
	_test_bag_gives_each_kind_once()
	_test_game_over_when_spawn_blocked()
	_test_move_blocked_by_wall()
	_test_gravity_lowers_piece()
	_test_hard_drop_lands_and_respawns()
	_test_lock_delay_reset_limit()
	_test_lock_reset_survives_reground()
	_test_lock_timer_clears_when_piece_falls_again()
	_test_ghost_matches_hard_drop()
	_test_rotate_keeps_piece_inside()
	_test_new_shapes_rotate_within_board()
	_test_rotate_never_overlaps()
	_test_kick_order_prefers_horizontal()
	_test_every_kind_rotates_anywhere_on_empty_board()
	_test_layer_clear_scores()
	_test_multi_layer_bonus()
	_test_level_rises()
	_test_footprint_is_deduplicated()
	_test_footprint_exact_set_for_flat_t()
	_test_easy_has_no_gravity()
	_test_easy_draws_planar_pieces_only()
	print("test_game: OK")
	quit()

func _test_start_spawns_piece() -> void:
	var g := _make_game()
	g.start(1234)
	assert(g.current != null, "start 후 현재 조각이 있어야 한다")
	assert(g.next_kind in Piece.SHAPES, "다음 조각 종류가 유효해야 한다")
	assert(not g.is_over, "start 직후에는 게임오버가 아니어야 한다")

func _test_spawn_is_inside_board() -> void:
	# 모든 조각이 스폰 위치에서 보드 안에 들어가야 한다. I 조각은 가로 4칸이라
	# 중앙 정렬을 잘못하면 벽을 뚫는다.
	var g := _make_game()
	g.start(1)
	for kind in Piece.SHAPES:
		var p := Piece.create(kind)
		p.origin = g.spawn_origin_for(p)
		for c in p.world_cells():
			assert(Board.in_bounds(c), "조각 %d 스폰 셀 %s 이 보드 밖" % [kind, c])
		var top := Piece.bbox_max(p.world_cells()).y
		assert(top == Board.HEIGHT - 1, "조각 %d 는 맨 위층에 붙어 스폰해야 한다" % kind)

func _test_bag_gives_each_kind_once() -> void:
	var g := _make_game()
	g.start(99)
	var counts := {}
	# start 에서 이미 두 개를 뽑았으므로 주머니 경계와 무관하게
	# 충분히 많이 뽑아 각 종류가 고르게 나오는지 본다.
	for _i in 50:
		var k := g._draw_kind()
		counts[k] = counts.get(k, 0) + 1
	assert(counts.size() == Piece.SHAPES.size(), "모든 조각 종류가 나와야 한다")
	for k in counts:
		assert(counts[k] >= 50 / Piece.SHAPES.size() - 1, "조각 %d 가 너무 적게 나왔다: %d" % [k, counts[k]])

func _test_game_over_when_spawn_blocked() -> void:
	var g := _make_game()
	g.start(7)
	var fired := [false]
	g.game_over.connect(func() -> void: fired[0] = true)
	# 맨 위 두 층을 전부 채워 스폰을 막는다.
	for y in [Board.HEIGHT - 1, Board.HEIGHT - 2]:
		for z in Board.DEPTH:
			for x in Board.WIDTH:
				g.board.cells[Board.index(x, y, z)] = 1
	g.current = null
	g._spawn()
	assert(g.is_over, "스폰이 막히면 게임오버여야 한다")
	assert(fired[0], "game_over 신호가 발생해야 한다")
	assert(g.current == null, "게임오버 후 현재 조각은 없어야 한다")

func _test_move_blocked_by_wall() -> void:
	var g := _make_game()
	g.start(3)
	# 왼쪽으로 계속 밀면 언젠가 벽에 막혀 false 가 나와야 한다.
	var blocked := false
	for _i in 10:
		if not g.move(Vector3i(-1, 0, 0)):
			blocked = true
			break
	assert(blocked, "벽에 닿으면 이동이 실패해야 한다")
	for c in g.current.world_cells():
		assert(Board.in_bounds(c), "실패한 이동이 조각을 밖으로 내보내면 안 된다")

func _test_gravity_lowers_piece() -> void:
	var g := _make_game()
	g.start(4)
	var y_before := g.current.origin.y
	g.step(g.fall_interval() + 0.01)
	assert(g.current.origin.y == y_before - 1, "중력 한 번에 한 칸 내려가야 한다")

func _test_hard_drop_lands_and_respawns() -> void:
	var g := _make_game()
	g.start(5)
	var locked := [0]
	g.piece_locked.connect(func() -> void: locked[0] += 1)
	g.hard_drop()
	assert(locked[0] == 1, "하드드롭은 조각을 즉시 잠가야 한다")
	assert(g.board.layer_fill_count(0) == 4, "바닥층에 조각 4칸이 놓여야 한다")
	assert(g.current != null, "잠금 후 새 조각이 스폰되어야 한다")
	assert(g.current.origin.y > 0, "새 조각은 위에서 스폰되어야 한다")

func _test_lock_delay_reset_limit() -> void:
	var g := _make_game()
	g.start(6)
	# 바닥까지 내린 뒤 잠기기 직전 상태로 만든다.
	while g.move(Vector3i(0, -1, 0)):
		pass
	g.step(0.01)  # 접지 인식
	var locked := [0]
	g.piece_locked.connect(func() -> void: locked[0] += 1)
	# 갱신 상한을 넘겨 흔든다. 상한이 없으면 영원히 잠기지 않는다.
	for _i in 40:
		g.step(0.4)
		g.move(Vector3i(1, 0, 0))
		g.move(Vector3i(-1, 0, 0))
	assert(locked[0] >= 1, "갱신 상한이 있으면 결국 잠겨야 한다")

# 턱에서 미끄러져 내려오는 상황. 예산을 다 쓴 조각의 잠금 타이머가 남아 있으면
# 다시 떨어진 뒤 착지하는 순간 곧바로 잠겨 버린다.
func _test_lock_timer_clears_when_piece_falls_again() -> void:
	var g := _make_game()
	g.start(41)
	var kind: int = g.current.kind
	g._lock_resets = Game.MAX_LOCK_RESETS  # 예산 소진
	g._lock_timer = Game.LOCK_DELAY - 0.01  # 잠기기 직전
	g._grounded = false  # 턱에서 벗어나 다시 떨어지기 시작한 상태
	g.step(g.fall_interval())
	assert(g.current != null and g.current.kind == kind, "떨어지는 중에 잠기면 안 된다")
	while g._can_fall():
		g.step(g.fall_interval())
	g.step(0.02)
	assert(g.current != null and g.current.kind == kind,
		"착지하자마자 잠기면 안 된다 — 다시 떨어진 조각은 잠금 지연을 새로 받아야 한다")

func _test_ghost_matches_hard_drop() -> void:
	var g := _make_game()
	g.start(8)
	var ghost := g.ghost_cells()
	var before := g.current
	g.hard_drop()
	# 잠긴 자리가 고스트가 가리킨 자리와 같아야 한다.
	for c in ghost:
		assert(g.board.get_cell(c) == before.kind,
			"고스트 셀 %s 에 조각이 없다" % c)

func _test_lock_reset_survives_reground() -> void:
	var g := _make_game()
	g.start(9)
	# x 0..1 쪽에만 바닥을 깔아 턱을 만든다. 조각이 x 2..3 위로 나가면 다시 떨어진다.
	for z in Board.DEPTH:
		for x in 2:
			g.board.cells[Board.index(x, 0, z)] = 1
	# O 조각을 턱 위에 직접 올린다. 무작위 조각에 기대지 않으려는 것.
	var p := Piece.create(2)
	p.origin = Vector3i(0, 1, 0)
	g.current = p
	g.step(0.01)  # 접지 인식
	var locked := [0]
	g.piece_locked.connect(func() -> void: locked[0] += 1)
	# 턱 밖으로 나갔다 돌아오기를 반복한다. 재접지가 공짜면 영원히 안 잠긴다.
	for _i in 40:
		g.move(Vector3i(1, 0, 0))
		g.move(Vector3i(1, 0, 0))
		g.move(Vector3i(-1, 0, 0))
		g.move(Vector3i(-1, 0, 0))
		g.step(0.4)
	assert(locked[0] >= 1, "턱을 들락거려도 갱신 상한은 소진되어야 한다")

func _test_rotate_keeps_piece_inside() -> void:
	var g := _make_game()
	g.start(11)
	for _i in 30:
		g.rotate(Piece.AXIS_Y, 1)
		g.rotate(Piece.AXIS_X, 1)
		g.rotate(Piece.AXIS_Z, 1)
		if g.current == null:
			break
		for c in g.current.world_cells():
			assert(Board.in_bounds(c), "회전 결과 셀 %s 이 보드 밖" % c)

func _test_new_shapes_rotate_within_board() -> void:
	# 비평면 조각 3종(6,7,8)을 스폰 위치에서 세 축 모두로 킥 탐색까지 포함해
	# 회전시켜도 결과 셀이 항상 보드 안에 있어야 한다.
	for kind in [6, 7, 8]:
		var g := _make_game()
		g.start(kind)
		var p := Piece.create(kind)
		p.origin = g.spawn_origin_for(p)
		g.current = p
		for axis in [Piece.AXIS_X, Piece.AXIS_Y, Piece.AXIS_Z]:
			for dir in [1, -1]:
				g.rotate(axis, dir)
				assert(g.current != null, "조각 %d 회전 중 사라지면 안 된다" % kind)
				for c in g.current.world_cells():
					assert(Board.in_bounds(c), "조각 %d 회전 결과 셀 %s 이 보드 밖" % [kind, c])

func _test_rotate_never_overlaps() -> void:
	var g := _make_game()
	g.start(12)
	# 바닥 두 층을 채워 회전 공간을 좁힌다.
	for y in [0, 1]:
		for z in Board.DEPTH:
			for x in Board.WIDTH:
				g.board.cells[Board.index(x, y, z)] = 1
	while g.move(Vector3i(0, -1, 0)):
		pass
	# 회전이 한 번도 성공하지 않으면 겹침 검사가 통과해도 아무것도 증명하지 못한다.
	var rotated_any := false
	for _i in 20:
		if g.rotate(Piece.AXIS_X, 1):
			rotated_any = true
		for c in g.current.world_cells():
			assert(g.board.get_cell(c) == 0, "회전한 조각이 쌓인 블럭과 겹쳤다: %s" % c)
	assert(rotated_any, "좁은 자리에서도 회전이 최소 한 번은 성공해야 한다")

func _test_kick_order_prefers_horizontal() -> void:
	# 순서 전체를 고정한다. 인덱스 몇 개만 보면 수평 후보끼리 뒤바뀌어도 못 잡는다.
	var want := [
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
	assert(Game.KICKS.size() == want.size(), "킥 후보는 17개")
	for i in want.size():
		assert(Game.KICKS[i] == want[i], "킥 순서가 %d 번째에서 다르다" % i)

# 빈 보드에서라면 어떤 조각이든, 보드 어느 자리에 있든 세 축 모두로 돌 수 있어야
# 한다. 킥 범위가 좁으면 벽 근처나 바닥 근처에서 조각이 영영 안 돌아간다.
func _test_every_kind_rotates_anywhere_on_empty_board() -> void:
	for kind in Piece.SHAPES.keys():
		for x in Board.WIDTH:
			for z in Board.DEPTH:
				for axis in [Piece.AXIS_X, Piece.AXIS_Y, Piece.AXIS_Z]:
					var g := _make_game()
					g.start(31)
					g.current = Piece.create(kind)
					g.current.origin = g.spawn_origin_for(g.current)
					# 바닥까지 떨어뜨린 뒤 목표 (x, z) 로 최대한 밀어붙인다.
					while g.move(Vector3i(0, -1, 0)):
						pass
					for _i in Board.WIDTH:
						g.move(Vector3i(signi(x - g.current.origin.x), 0, 0))
						g.move(Vector3i(0, 0, signi(z - g.current.origin.z)))
					var at: Vector3i = g.current.origin
					assert(g.rotate(axis, 1),
						"조각 %d 이 %s 에서 축 %d 로 안 돌아간다" % [kind, at, axis])
					g.free()

func _test_layer_clear_scores() -> void:
	var g := _make_game()
	g.start(21)
	# 0층에서 z=0 줄 4칸만 비우고 나머지를 채운다.
	# 한 칸짜리 구멍을 남기면 4칸 조각이 절대 메울 수 없으므로, I 조각이
	# 정확히 들어가는 4칸 줄을 비워 둔다.
	for z in Board.DEPTH:
		if z == 0:
			continue
		for x in Board.WIDTH:
			g.board.cells[Board.index(x, 0, z)] = 1
	var i_piece := Piece.create(1)  # I 조각: x 방향 4칸, z=0
	i_piece.origin = Vector3i(0, Board.HEIGHT - 1, 0)
	assert(g.board.is_valid(i_piece.world_cells()), "I 조각이 놓일 자리가 있어야 한다")
	g.current = i_piece

	var got := [0]
	g.layers_cleared.connect(func(ys: PackedInt32Array, _kind: int) -> void: got[0] = ys.size())
	var score_before := g.score
	g.hard_drop()
	assert(got[0] == 1, "빈 줄을 메우면 층이 지워져야 한다, 실제 %d" % got[0])
	assert(score_before == 0, "시작 점수는 0")
	assert(g.score == Game.SCORE_PER_LAYER * 1 * Game.CLEAR_MULTIPLIER[1],
		"한 층 클리어 점수는 레벨 1 기준 공식대로여야 한다, 실제 %d" % g.score)
	assert(g.total_layers == 1, "누적 층 수가 기록되어야 한다")
	assert(g.board.layer_fill_count(0) == 0, "지워진 자리는 비어야 한다")

func _test_multi_layer_bonus() -> void:
	var g := _make_game()
	g.start(22)
	# 0층과 1층에서 x 0..1, z=0 네 칸만 비우고 나머지를 채운다.
	# X축으로 세운 O 조각이 그 구멍에 정확히 들어가 두 층을 한 번에 지운다.
	for y in [0, 1]:
		for z in Board.DEPTH:
			for x in Board.WIDTH:
				if z == 0 and x < 2:
					continue
				g.board.cells[Board.index(x, y, z)] = 1
	var o_piece := Piece.create(2).rotated(Piece.AXIS_X, 1)
	o_piece.origin = Vector3i(0, Board.HEIGHT - 2, 0)
	assert(g.board.is_valid(o_piece.world_cells()), "세운 O 조각이 놓일 자리가 있어야 한다")
	g.current = o_piece

	var got := [0, 0]
	g.layers_cleared.connect(func(ys: PackedInt32Array, kind: int) -> void:
		got[0] = ys.size()
		got[1] = kind)
	g.hard_drop()
	assert(got[0] == 2, "두 층이 한 번에 지워져야 한다, 실제 %d" % got[0])
	# 불티 색이 여기서 나온다. 아무 값이나 실어 보내면 색이 조각과 어긋난다.
	assert(got[1] == o_piece.kind,
		"층을 채운 조각 종류를 같이 보내야 한다: %d, 기대 %d" % [got[1], o_piece.kind])
	assert(g.total_layers == 2, "누적 층 수가 2여야 한다, 실제 %d" % g.total_layers)
	# 동시 클리어 보너스: 두 층은 한 층의 두 배가 아니라 세 배다.
	assert(g.score == Game.SCORE_PER_LAYER * 1 * Game.CLEAR_MULTIPLIER[2],
		"두 층 클리어 점수가 배율대로여야 한다, 실제 %d" % g.score)
	assert(g.board.layer_fill_count(0) == 0, "지워진 자리는 비어야 한다")

func _test_level_rises() -> void:
	var g := _make_game()
	g.start(23)
	assert(g.level == 1, "시작 레벨은 1")
	var first := g.fall_interval()
	g.total_layers = Game.LEVEL_UP_LAYERS * 3
	g.level = g.total_layers / Game.LEVEL_UP_LAYERS + 1
	assert(g.level == 4, "층 15개면 레벨 4")
	assert(g.fall_interval() < first, "레벨이 오르면 낙하가 빨라져야 한다")
	g.total_layers = 500
	g.level = g.total_layers / Game.LEVEL_UP_LAYERS + 1
	assert(g.fall_interval() == Game.MIN_FALL_INTERVAL, "낙하 간격에 하한이 있어야 한다")

func _test_footprint_is_deduplicated() -> void:
	var g := _make_game()
	g.start(41)
	# 조각을 세워서 같은 XZ 칸에 여러 셀이 겹치게 만든다.
	g.rotate(Piece.AXIS_X, 1)
	var fp := g.footprint_cells()
	var seen := {}
	for c in fp:
		assert(c.y == 0, "발자국은 바닥 평면이어야 한다")
		assert(not seen.has(c), "발자국에 중복 칸 %s" % c)
		seen[c] = true
	assert(fp.size() >= 1 and fp.size() <= 4, "발자국은 1~4칸")
	for c in g.current.world_cells():
		assert(seen.has(Vector3i(c.x, 0, c.z)), "조각이 덮은 칸 %s 이 발자국에 없다" % c)

func _test_footprint_exact_set_for_flat_t() -> void:
	# T 조각(kind 3)은 한 층에 눕혀져 정의되므로 회전 없이도 발자국이
	# world_cells 와 1:1로 대응해야 한다. 정확한 칸 집합을 직접 검증한다 —
	# 크기만 맞고 엉뚱한 칸이 섞여도 위 dedup 테스트는 못 잡는다.
	var g := _make_game()
	g.start(41)
	var p := Piece.create(3)
	p.origin = Vector3i(1, 5, 2)
	g.current = p
	var fp := g.footprint_cells()
	var want: Array[Vector3i] = [
		Vector3i(1, 0, 2), Vector3i(2, 0, 2), Vector3i(3, 0, 2), Vector3i(2, 0, 3),
	]
	assert(fp.size() == want.size(), "발자국 칸 수가 기대와 다르다: %d" % fp.size())
	for w in want:
		assert(fp.has(w), "발자국에 %s 가 없어야 할 칸이 빠졌다" % w)


# 쉬움은 조각이 저절로 내려오지 않는다. 시간이 아무리 흘러도 제자리여야 하고,
# 내리기를 눌렀을 때만 잠긴다.
func _test_easy_has_no_gravity() -> void:
	GameConfig.difficulty = GameConfig.EASY
	var g := _make_game()
	g.start(7)
	var before: Vector3i = g.current.origin
	for _i in 100:
		g.step(1.0)
	assert(g.current.origin == before,
		"쉬움에서는 조각이 저절로 내려오면 안 된다: %s" % g.current.origin)
	assert(g.board.layer_fill_count(0) == 0, "쉬움에서는 시간만으로 잠기면 안 된다")
	g.hard_drop()
	assert(g.board.layer_fill_count(0) > 0, "쉬움에서도 내리기를 누르면 잠겨야 한다")
	GameConfig.difficulty = GameConfig.HARD

func _test_easy_draws_planar_pieces_only() -> void:
	GameConfig.difficulty = GameConfig.EASY
	var g := _make_game()
	g.start(3)
	assert(g.next_kind <= Piece.PLANAR_MAX, "쉬움의 첫 조각부터 평면이어야 한다")
	for _i in 60:
		var k := g._draw_kind()
		assert(k <= Piece.PLANAR_MAX, "쉬움에 비평면 조각 %d 가 나왔다" % k)
	GameConfig.difficulty = GameConfig.HARD
	var h := _make_game()
	h.start(3)
	var seen := {}
	for _i in 200:
		seen[h._draw_kind()] = true
	assert(seen.size() == Piece.SHAPES.size(),
		"어려움에서는 모든 조각이 나와야 한다: %d 종" % seen.size())
