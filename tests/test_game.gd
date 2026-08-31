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
