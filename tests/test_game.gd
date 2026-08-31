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
	_test_ghost_matches_hard_drop()
	_test_rotate_keeps_piece_inside()
	_test_rotate_never_overlaps()
	_test_kick_order_prefers_horizontal()
	_test_layer_clear_scores()
	_test_multi_layer_bonus()
	_test_level_rises()
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
		Vector3i(0, -1, 0),
		Vector3i(0, 1, 0),
	]
	assert(Game.KICKS.size() == want.size(), "킥 후보는 7개")
	for i in want.size():
		assert(Game.KICKS[i] == want[i], "킥 순서가 %d 번째에서 다르다" % i)

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
	g.layers_cleared.connect(func(k: int) -> void: got[0] = k)
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

	var got := [0]
	g.layers_cleared.connect(func(k: int) -> void: got[0] = k)
	g.hard_drop()
	assert(got[0] == 2, "두 층이 한 번에 지워져야 한다, 실제 %d" % got[0])
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
