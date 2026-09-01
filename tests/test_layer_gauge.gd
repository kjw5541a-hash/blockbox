extends SceneTree

# LayerGauge 는 board.layer_fill_count(y) 의 결과를 막대 너비/색으로 바꾼다.
# 여기서는 그 산술이 맞는지, 그리고 범위 밖 y 로 호출해 assert 를 터뜨리지
# 않는지를 확인한다 (씬이 뜨는지만 보는 건 부족한 테스트라 별도로 둔다).
func _initialize() -> void:
	await _test_bar_width_and_color_track_fill()
	print("test_layer_gauge: OK")
	quit()

func _cells_for(n: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var count := 0
	for z in Board.DEPTH:
		for x in Board.WIDTH:
			if count >= n:
				return out
			out.append(Vector3i(x, 0, z))
			count += 1
	return out

func _test_bar_width_and_color_track_fill() -> void:
	var game := Game.new()
	root.add_child(game)
	game.start(11)

	# class_name 이 없는 스크립트이므로 정적 타입을 주면 정적 분석이 VBoxContainer
	# 기준으로 멤버를 찾다 실패한다. 타입 없이 받아 런타임에 동적으로 접근한다.
	var gauge = load("res://scripts/layer_gauge.gd").new()
	root.add_child(gauge)
	# _ready() 는 트리에 들어간 뒤 다음 프레임에 불린다 — _bars 가 채워질 때까지 기다린다.
	await process_frame

	# 0층을 LAYER_CLEAR_THRESHOLD - 1 칸만 채운다: 아직 꽉 찬 게 아니다.
	var near_full: Array[Vector3i] = _cells_for(Board.LAYER_CLEAR_THRESHOLD - 1)
	game.board.lock(near_full, 1)
	gauge.setup(game)  # setup 이 refresh 를 한 번 부른다

	var bar_index := Board.HEIGHT - 1  # y=0 은 역순 배치라 배열 맨 끝
	var bar: ColorRect = gauge._bars[bar_index]
	var full_width := 48.0
	var expect_near := full_width * float(Board.LAYER_CLEAR_THRESHOLD - 1) / float(Board.LAYER_CELLS)
	assert(is_equal_approx(bar.size.x, expect_near),
		"막대 너비가 채움 비율과 어긋난다: %f, 기대 %f" % [bar.size.x, expect_near])
	assert(bar.size.x < full_width - 0.01, "LAYER_CLEAR_THRESHOLD-1 칸이면 아직 꽉 찬 게 아니다")
	assert(bar.color == gauge.NEAR_COLOR, "한 칸 남으면 경고색이어야 한다")

	# 마지막 한 칸을 채워 완전히 꽉 채운다.
	game.board.lock([Vector3i(3, 0, 3)] as Array[Vector3i], 1)
	gauge.refresh()
	assert(is_equal_approx(bar.size.x, full_width),
		"꽉 찬 층은 막대가 끝까지 차야 한다: %f" % bar.size.x)
	assert(bar.color == gauge.NEAR_COLOR, "꽉 찬 층도 경고색 그대로여야 한다")

	# 막대는 정보 표시일 뿐이라 스와이프를 삼키면 안 된다. 부모에만 IGNORE 를
	# 걸면 자식 ColorRect 가 기본값 STOP 으로 남아 게이지 위 드래그가 죽는다.
	for b in gauge._bars:
		assert(b.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"채움 막대가 입력을 삼키면 안 된다")
		assert(b.get_parent().mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"배경 막대가 입력을 삼키면 안 된다")

	# 다른 모든 층(y=1..HEIGHT-1)은 비어 있으니 폭이 0이어야 하고, HEIGHT 개
	# 층 전부를 refresh 가 범위 밖 y 없이 훑고 지나갔다는 뜻이다.
	for i in Board.HEIGHT - 1:
		var empty_bar: ColorRect = gauge._bars[i]
		assert(is_equal_approx(empty_bar.size.x, 0.0),
			"빈 층의 막대는 폭이 0이어야 한다: 인덱스 %d, 폭 %f" % [i, empty_bar.size.x])
		assert(empty_bar.color == gauge.FILL_COLOR, "빈 층은 경고색이 아니어야 한다")
