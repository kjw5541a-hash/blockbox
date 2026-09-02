extends SceneTree

func _initialize() -> void:
	_test_every_name_makes_a_sound()
	_test_move_is_a_ratchet()
	_test_waveforms_are_cached()
	_test_play_without_a_host_is_quiet()
	await _test_game_actions_make_their_sound()
	print("test_sfx: OK")
	quit()

# 이름을 하나 늘리고 파형 만드는 걸 잊으면 무음이 배포된다.
func _test_every_name_makes_a_sound() -> void:
	for name in Sfx.NAMES:
		var s := Sfx.stream(name)
		assert(s != null, "%s 의 파형이 없다" % name)
		assert(s.mix_rate == Sfx.RATE, "%s 의 샘플레이트가 다르다" % name)
		assert(s.format == AudioStreamWAV.FORMAT_16_BITS, "%s 가 16비트가 아니다" % name)
		# 2바이트 한 샘플. 0.04 초보다 짧으면 사람 귀에 딸깍조차 안 잡힌다.
		var seconds := float(s.data.size()) / 2.0 / Sfx.RATE
		assert(seconds > 0.04, "%s 가 너무 짧다: %f 초" % [name, seconds])
		assert(seconds < 2.0, "%s 가 너무 길다: %f 초" % [name, seconds])
		var peak := 0
		for i in range(0, s.data.size(), 2):
			peak = maxi(peak, absi(s.data.decode_s16(i)))
		# 들리기는 해야 하고, 꽉 차면 웹에서 지직거린다.
		assert(peak > 3000, "%s 가 거의 무음이다: 최대 %d" % [name, peak])
		assert(peak < 32000, "%s 가 포화됐다: 최대 %d" % [name, peak])

# 이동 소리는 그냥 소음이 아니라 딸깍이 촘촘히 이어진 것이어야 "드르르르륵" 으로
# 들린다. 딸깍 하나하나는 앞이 크고 뒤로 잦아든다.
func _test_move_is_a_ratchet() -> void:
	var d := Sfx.stream(Sfx.MOVE).data
	var n := d.size() / 2
	var span := n / Sfx.MOVE_CLICKS
	for c in Sfx.MOVE_CLICKS:
		var head := _loudness(d, c * span, span / 4)
		var tail := _loudness(d, c * span + span * 3 / 4, span / 4)
		assert(head > tail * 1.5,
			"%d 번째 딸깍이 앞뒤로 평평하다: 앞 %f 뒤 %f" % [c, head, tail])

func _loudness(d: PackedByteArray, start: int, count: int) -> float:
	var sum := 0.0
	for i in range(start, start + count):
		sum += absi(d.decode_s16(i * 2))
	return sum / count

# 소음이 섞여 있어 매번 새로 만들면 같은 소리가 매번 달라진다. 그리고 매 조작마다
# 만 번 넘는 계산을 다시 돌게 된다.
func _test_waveforms_are_cached() -> void:
	assert(Sfx.stream(Sfx.ROTATE) == Sfx.stream(Sfx.ROTATE), "파형이 매번 새로 만들어진다")

# Game 은 테스트에서 홀로 만들어져 돈다. 그때 소리 때문에 죽으면 안 된다.
func _test_play_without_a_host_is_quiet() -> void:
	var host: Sfx = Sfx._inst
	Sfx._inst = null
	Sfx.play(Sfx.ROTATE)
	Sfx._inst = host

func _test_game_actions_make_their_sound() -> void:
	var host := Sfx.new()
	root.add_child(host)
	await process_frame

	var g := Game.new()
	root.add_child(g)
	g.start(1234)

	# 좌우 이동만 드르륵거린다. 중력 낙하는 같은 move 를 거치지만 조용해야 한다.
	host.last = &""
	assert(g.move(Vector3i(0, -1, 0)), "아래로 한 칸은 갈 수 있어야 한다")
	assert(host.last == &"", "중력 낙하가 이동 소리를 냈다")
	assert(g.move(Vector3i(1, 0, 0)), "옆으로 한 칸은 갈 수 있어야 한다")
	assert(host.last == Sfx.MOVE, "좌우 이동에 소리가 없다: %s" % host.last)

	host.last = &""
	assert(g.rotate(Piece.AXIS_X, 1), "빈 통 한가운데서는 돌 수 있어야 한다")
	assert(host.last == Sfx.ROTATE, "회전에 소리가 없다: %s" % host.last)

	# 내리기는 훑는 소리와 닿는 소리를 잇달아 낸다. 마지막에 남는 건 착지다.
	host.last = &""
	g.hard_drop()
	assert(host.last == Sfx.LOCK, "착지에 소리가 없다: %s" % host.last)

	g.free()
	host.free()
