extends SceneTree

# 층이 지워질 때 그 자리에 불티가 터지는지, 그리고 그 불티가 스스로
# 치워지는지 본다. 그림이 예쁜지는 사람이 본다 — headless 에서는 확인할 수 없다.
func _initialize() -> void:
	await _test_burst_lands_on_the_cleared_layer()
	await _test_bursts_clean_themselves_up()
	await _test_nothing_happens_without_a_clear()
	_test_sparks_wear_the_piece_color()
	print("test_layer_burst: OK")
	quit()

func _rig() -> Array:
	var game := Game.new()
	root.add_child(game)
	game.start(3)
	var burst = load("res://scripts/layer_burst.gd").new()
	root.add_child(burst)
	burst.setup(game)
	return [game, burst]

func _sparks(burst: Node3D) -> Array[CPUParticles3D]:
	var out: Array[CPUParticles3D] = []
	for c in burst.get_children():
		if c is CPUParticles3D and not c.is_queued_for_deletion():
			out.append(c)
	return out

func _test_burst_lands_on_the_cleared_layer() -> void:
	var r := _rig()
	var game: Game = r[0]
	var burst = r[1]

	game.layers_cleared.emit(PackedInt32Array([0, 2]), 3)
	var sparks := _sparks(burst)
	assert(sparks.size() == 2, "지워진 층마다 하나씩 터져야 한다: %d" % sparks.size())

	var heights: Array[float] = []
	for p in sparks:
		assert(p.emitting, "터지지 않은 파티클은 아무것도 보여주지 않는다")
		assert(p.one_shot, "한 번만 터지고 끝나야 한다")
		assert(p.mesh != null, "메시가 없으면 아무것도 그려지지 않는다")
		assert(is_equal_approx(p.position.x, (Board.WIDTH - 1) * 0.5)
			and is_equal_approx(p.position.z, (Board.DEPTH - 1) * 0.5),
			"불티가 통 한가운데에서 나와야 한다: %s" % p.position)
		heights.append(p.position.y)
	heights.sort()
	assert(is_equal_approx(heights[0], 0.0) and is_equal_approx(heights[1], 2.0),
		"불티가 지워진 층 높이에 있어야 한다: %s" % str(heights))

	# 층 전체를 덮어야 하므로 방출 범위가 통 넓이만큼 넓어야 한다.
	var e: Vector3 = sparks[0].emission_box_extents
	assert(is_equal_approx(e.x, Board.WIDTH * 0.5) and is_equal_approx(e.z, Board.DEPTH * 0.5),
		"방출 범위가 층 넓이와 어긋난다: %s" % e)

	game.queue_free()
	burst.queue_free()

# 한 판에 층이 수십 번 지워진다. 치우지 않으면 노드가 계속 쌓인다.
func _test_bursts_clean_themselves_up() -> void:
	var r := _rig()
	var game: Game = r[0]
	var burst = r[1]

	game.layers_cleared.emit(PackedInt32Array([1]), 1)
	var p := _sparks(burst)[0]
	assert(p.finished.is_connected(p.queue_free), "다 터진 뒤 스스로 사라져야 한다")
	p.finished.emit()
	await process_frame
	await process_frame
	assert(_sparks(burst).is_empty(), "다 터진 불티가 남아 있다")

	game.queue_free()
	burst.queue_free()

func _test_nothing_happens_without_a_clear() -> void:
	var r := _rig()
	var game: Game = r[0]
	var burst = r[1]

	game.layers_cleared.emit(PackedInt32Array(), 1)
	assert(_sparks(burst).is_empty(), "지워진 층이 없으면 터질 것도 없다")

	# 조각을 잠그기만 해서는 터지지 않는다. 층이 지워질 때만이다.
	game.hard_drop()
	await process_frame
	assert(_sparks(burst).is_empty(), "조각이 잠겼을 뿐인데 터졌다")

	game.queue_free()
	burst.queue_free()


# 불티가 흰색 고정이면 "내가 놓은 조각이 터졌다"가 아니라 그냥 이펙트다.
# 색은 메시가 아니라 파티클이 들고 있어야 한다 — 메시는 하나를 돌려 쓰므로
# 거기에 색을 칠하면 모든 층이 같은 색으로 터진다.
func _test_sparks_wear_the_piece_color() -> void:
	var r := _rig()
	var game: Game = r[0]
	var burst = r[1]

	game.layers_cleared.emit(PackedInt32Array([0]), 3)
	game.layers_cleared.emit(PackedInt32Array([1]), 5)
	var sparks := _sparks(burst)
	assert(sparks.size() == 2, "층마다 하나씩")
	assert(sparks[0].color != sparks[1].color,
		"조각 종류가 다른데 불티 색이 같다: %s" % sparks[0].color)
	for i in 2:
		var kind: int = [3, 5][i]
		var want := BlockColors.of(kind).lerp(Color.WHITE, burst.WHITEN)
		assert(sparks[i].color.is_equal_approx(want),
			"%d 번 조각 불티 색이 어긋난다: %s, 기대 %s" % [kind, sparks[i].color, want])

	var mat: StandardMaterial3D = sparks[0].mesh.material
	assert(mat.vertex_color_use_as_albedo,
		"메시가 정점 색을 안 쓰면 파티클 색은 무시되고 전부 같은 색으로 터진다")
	assert(mat.vertex_color_is_srgb,
		"정점 색을 선형으로 읽으면 조각 색보다 밝게 튄다")

	game.queue_free()
	burst.queue_free()
