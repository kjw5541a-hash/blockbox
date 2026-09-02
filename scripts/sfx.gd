class_name Sfx
extends Node

# 효과음을 파일로 두지 않고 켤 때 계산해서 만든다. 짧은 소리 아홉 개라 다 합쳐도
# 100KB 가 안 되고, wav 를 넣으면 임포트 파일과 배포 용량이 따라 붙는다 —
# 웹 빌드가 이미 39MB 다.
#
# 트리에 Sfx 노드가 있어야 소리가 난다. 없으면 play 가 조용히 넘어간다.
# Game 은 테스트에서 홀로 만들어져 돌기 때문에, 소리 때문에 죽으면 안 된다.

const RATE := 22050

const ROTATE := &"rotate"
const MOVE := &"move"
const DROP := &"drop"
const LOCK := &"lock"
const CLEAR := &"clear"
const LEVEL := &"level"
const OVER := &"over"
const TURN := &"turn"
const UI := &"ui"

const NAMES: Array[StringName] = [ROTATE, MOVE, DROP, LOCK, CLEAR, LEVEL, OVER, TURN, UI]

# 동시에 울릴 수 있는 소리 수. 층이 지워질 때 착지·클리어·레벨업이 겹친다.
const VOICES := 6

# 파형은 한 번만 만들어 두고 씬을 오가도 그대로 쓴다.
static var _bank := {}
static var _inst: Sfx = null

# 테스트가 확인용으로 읽는다. 헤드리스의 더미 오디오 드라이버에서는 재생 여부를
# 밖에서 볼 방법이 없다.
var last: StringName = &""

var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	_inst = self
	for _i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func _exit_tree() -> void:
	if _inst == self:
		_inst = null

static func play(name: StringName) -> void:
	if _inst == null or not is_instance_valid(_inst):
		return
	_inst._speak(name)

# 목소리를 돌려 쓴다. 재생 중인 것을 골라도 상관없다 — 겹칠 만한 소리는
# 모두 0.2 초 안쪽이라 여섯 개면 서로 밟지 않는다.
func _speak(name: StringName) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = Sfx.stream(name)
	p.play()
	last = name

# 소리마다 서로 다른 크기로 맞춘다. 파형을 손으로 맞추면 필터 계수 하나만
# 건드려도 크기가 통째로 달라지고, 소음이 섞인 소리는 켤 때마다 달라진다.
# 층 클리어가 제일 크고, 매 칸 울리는 이동과 버튼 딸깍이 제일 작다.
const PEAK := {
	ROTATE: 0.55, MOVE: 0.40, DROP: 0.60, LOCK: 0.75, CLEAR: 0.90,
	LEVEL: 0.70, OVER: 0.70, TURN: 0.45, UI: 0.35,
}

static func stream(name: StringName) -> AudioStreamWAV:
	if not _bank.has(name):
		_bank[name] = _bake(_norm(_render(name), PEAK.get(name, 0.5)))
	return _bank[name]

static func _norm(buf: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var hi := 0.0
	for v in buf:
		hi = maxf(hi, absf(v))
	if hi == 0.0:
		return buf
	var g := peak / hi
	for i in buf.size():
		buf[i] *= g
	return buf

static func _render(name: StringName) -> PackedFloat32Array:
	match name:
		ROTATE:
			return _rotate()
		MOVE:
			return _move()
		DROP:
			return _drop()
		LOCK:
			return _lock()
		CLEAR:
			return _clear()
		LEVEL:
			return _level()
		OVER:
			return _over()
		TURN:
			return _turn()
		UI:
			return _ui()
	# 여기 없는 이름은 길이 0 인 파형이 되고, test_sfx 가 그걸 잡는다.
	# 부르는 쪽은 언제나 Sfx 의 상수를 쓰므로 오타는 파스 단계에서 걸린다.
	return PackedFloat32Array()

static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b

static func _bake(buf: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s

# 쉭 — 소음을 저역통과로 걸러 밝기를 끌어올린다. 음정이 없어야 바람으로 들린다.
static func _rotate() -> PackedFloat32Array:
	var b := _buf(0.14)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		lp = lerpf(lp, randf_range(-1.0, 1.0), lerpf(0.05, 0.85, t * t))
		b[i] = lp * exp(-t * 4.5) * minf(1.0, t * 30.0)
	return b

# 드르르르륵 — 짧은 딸깍을 촘촘히 이어 붙인다. 하나하나는 소음이지만 간격이
# 일정해 굴러가는 소리로 뭉친다.
const MOVE_CLICKS := 9

static func _move() -> PackedFloat32Array:
	var b := _buf(0.16)
	for i in b.size():
		var t := float(i) / b.size()
		var click := fmod(t * MOVE_CLICKS, 1.0)
		var body := sin(TAU * 190.0 * i / RATE) * 0.5 + randf_range(-1.0, 1.0)
		b[i] = body * exp(-click * 20.0) * exp(-t * 1.6)
	return b

# 내리기 — 위에서 아래로 훑고 지나간다. 차단 주파수를 내려 떨어지는 느낌을 준다.
static func _drop() -> PackedFloat32Array:
	var b := _buf(0.2)
	var lp := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		lp = lerpf(lp, randf_range(-1.0, 1.0), lerpf(0.8, 0.05, t))
		ph += TAU * lerpf(700.0, 120.0, t * t) / RATE
		b[i] = (lp * 0.6 + sin(ph) * 0.4) * exp(-t * 2.5)
	return b

# 착지 — 낮은 음이 더 낮게 떨어진다. 앞머리에 딸깍을 얹어 닿는 순간을 세운다.
static func _lock() -> PackedFloat32Array:
	var b := _buf(0.16)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		ph += TAU * lerpf(160.0, 55.0, t) / RATE
		b[i] = sin(ph) * exp(-t * 5.0) * 0.65 + randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.3
	return b

# 층이 지워질 때 — 화음을 한 음씩 쌓아 올린다. 게임에서 제일 좋은 순간이라
# 제일 길고 제일 화려하다. 배음을 살짝 어긋나게 얹으면 종처럼 울린다.
const CLEAR_NOTES := [523.25, 659.25, 783.99, 987.77, 1318.51]
const CLEAR_GAP := 0.07

static func _clear() -> PackedFloat32Array:
	var b := _buf(CLEAR_GAP * CLEAR_NOTES.size() + 0.75)
	for n in CLEAR_NOTES.size():
		var f: float = CLEAR_NOTES[n]
		var start := int(n * CLEAR_GAP * RATE)
		for i in range(start, b.size()):
			var u := float(i - start) / RATE
			var v := sin(TAU * f * u) + 0.5 * sin(TAU * f * 2.0 * u) \
				+ 0.25 * sin(TAU * f * 3.01 * u)
			b[i] += v * exp(-u * 5.0)
	return b

# 레벨업 — 짧게 세 계단 올라간다.
const LEVEL_NOTES := [659.25, 830.61, 987.77]

static func _level() -> PackedFloat32Array:
	var b := _buf(0.36)
	var step := b.size() / LEVEL_NOTES.size()
	for i in b.size():
		var n := mini(i / step, LEVEL_NOTES.size() - 1)
		var u := float(i - n * step) / RATE
		var f: float = LEVEL_NOTES[n]
		b[i] = (sin(TAU * f * u) + 0.3 * sin(TAU * f * 2.0 * u)) * exp(-u * 12.0)
	return b

# 게임 종료 — 음이 끝까지 내려앉는다.
static func _over() -> PackedFloat32Array:
	var b := _buf(0.8)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		ph += TAU * lerpf(392.0, 98.0, t) / RATE
		b[i] = (sin(ph) + 0.35 * sin(ph * 2.0)) * exp(-t * 2.2)
	return b

# 시점 돌리기 — 조각 회전보다 낮고 부드럽다. 도는 건 통이지 조각이 아니다.
static func _turn() -> PackedFloat32Array:
	var b := _buf(0.26)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.04 + 0.12 * sin(PI * t))
		b[i] = lp * sin(PI * t)
	return b

# 버튼 — 아주 짧은 딸깍. 눌린 걸 알려주는 것 말고는 하는 일이 없다.
static func _ui() -> PackedFloat32Array:
	var b := _buf(0.05)
	for i in b.size():
		var t := float(i) / b.size()
		b[i] = sin(TAU * 880.0 * i / RATE) * exp(-t * 9.0)
	return b
