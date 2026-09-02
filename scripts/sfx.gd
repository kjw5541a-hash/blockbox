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
	# 미리 다 만들어 둔다. 아홉 개 합쳐 100ms 남짓인데, 게임 중에 처음 울리는
	# 소리마다 그만큼씩 멈추면 그게 눈에 띈다. 시작 화면이 뜨기 전은 안 띈다.
	for name in NAMES:
		Sfx.stream(name)

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

# 소리마다 서로 다른 크기로 맞춘다. 크기를 손으로 맞추면 배음 하나를 더하거나
# 음을 하나 겹치는 것만으로 전체 크기가 달라져 매번 다시 맞춰야 한다.
# 층 클리어가 제일 크고, 매 칸 울리는 이동과 버튼 딸깍이 제일 작다.
const PEAK := {
	ROTATE: 0.50, MOVE: 0.14, DROP: 0.50, LOCK: 0.70, CLEAR: 0.85,
	LEVEL: 0.60, OVER: 0.60, TURN: 0.22, UI: 0.28,
}

static func stream(name: StringName) -> AudioStreamWAV:
	if not _bank.has(name):
		_bank[name] = _bake(_norm(_echo(_render(name)), PEAK.get(name, 0.5)))
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

# 소리는 전부 유리종 하나로 만든다. 배음을 정수배에서 살짝 어긋나게 얹으면
# 금속이 아니라 유리로 들리고, 높은 배음이 먼저 사라지면 맑게 남는다.
# 소음(noise)은 한 군데도 쓰지 않는다 — 소음이 섞이는 순간 상큼함이 죽는다.
const PARTIALS := [1.0, 2.01, 3.03, 4.7]
# 높은 배음을 여리게 눌러야 은은해진다. 밝기는 여기 숫자 셋에서 나온다 —
# 크기를 줄이는 것과는 다르다. 작게 튼 날카로운 소리는 여전히 날카롭다.
const PARTIAL_GAIN := [1.0, 0.34, 0.16, 0.07]
# 사인파를 그냥 시작하면 딸깍 소리가 난다. 12ms 면 소리가 스며들듯 들어온다.
const ATTACK := 0.012

# fade 를 키우면 같은 종이 더 빨리 잦아든다. 또르르 구르는 소리는 알끼리 겹치면
# 한 덩어리로 뭉쳐 들리므로, 짧게 쓸 때만 키운다.
static func _bell(b: PackedFloat32Array, at: float, freq: float, dur: float,
		amp: float, fade := 1.0, attack := ATTACK) -> void:
	var start := int(at * RATE)
	var n := mini(int(dur * RATE), b.size() - start)
	for k in PARTIALS.size():
		var f: float = freq * PARTIALS[k]
		# 나이퀴스트 위는 접혀 내려와 음계에 없는 소리로 들린다.
		if f > RATE * 0.45:
			continue
		var g: float = PARTIAL_GAIN[k] * amp
		# 높은 배음일수록 빨리 사라진다.
		var decay := (4.0 + k * 3.0) * fade
		for i in n:
			var u := float(i) / RATE
			b[start + i] += sin(TAU * f * u) * exp(-u * decay) \
				* minf(1.0, u / attack) * g

# 울림 — 소리마다 따로 걸지 않고 여기서 한 번에 건다. 방은 하나뿐이다.
# 서로 배수가 아닌 지연 넷을 겹친다. 신비로움은 소리 자체보다 소리가
# 사라지는 방식에서 온다. 지연이 서로 배수면 메아리가 겹쳐 통 속 소리가 된다.
const ECHO_DELAYS := [0.037, 0.053, 0.071, 0.089]
const ECHO_FEEDBACK := 0.42

static func _echo(b: PackedFloat32Array) -> PackedFloat32Array:
	for d in ECHO_DELAYS:
		var n := int(d * RATE)
		for i in range(n, b.size()):
			b[i] += b[i - n] * ECHO_FEEDBACK
	return b

# 쿵 — 낮은 음의 높이를 앞머리에서 순식간에 떨어뜨린다. 소음을 안 쓰고 무게를
# 내는 방법은 이것뿐이다. 떨어지는 속도가 "쿵" 과 "웅" 을 가른다.
static func _thump(b: PackedFloat32Array, at: float, hi: float, lo: float,
		dur: float, amp: float) -> void:
	var start := int(at * RATE)
	var n := mini(int(dur * RATE), b.size() - start)
	var bend := dur * 0.18
	var ph := 0.0
	for i in n:
		var u := float(i) / RATE
		ph += TAU * lerpf(hi, lo, minf(1.0, u / bend)) / RATE
		# 1ms 안에 꽉 찬다. 쿵은 스며들면 안 된다 — 닿는 순간이 있어야 한다.
		b[start + i] += sin(ph) * exp(-u * 9.0) * minf(1.0, u / 0.001) * amp

# 5음 음계(도-레-미-솔-라). 어느 둘을 겹쳐도 부딪히지 않아서, 소리들이 서로
# 물려 울려도 지저분해지지 않는다.
const C3 := 130.81
const G3 := 196.0
const C4 := 261.63
const G4 := 392.0
const C5 := 523.25
const D5 := 587.33
const E5 := 659.25
const G5 := 783.99
const A5 := 880.0
const C6 := 1046.5
const E6 := 1318.51
const G6 := 1567.98
const A6 := 1760.0

# 회전 — 아래에서 위로 세 음을 스치듯 훑는다. 제일 자주 듣는 소리라 제일
# 공들였다.
const ROTATE_RUN := [E5, A5, E6]
const ROTATE_GAP := 0.026
# 맨 위 음만 아주 살짝 어긋나게 한 번 더 겹친다. 두 음이 맥놀이로 천천히
# 흔들리며 반짝인다 — 배음을 더 얹는 것보다 조용하면서 더 신비롭다.
const ROTATE_SHIMMER := 1.004

static func _rotate() -> PackedFloat32Array:
	var b := _buf(0.6)
	for i in ROTATE_RUN.size():
		_bell(b, i * ROTATE_GAP, ROTATE_RUN[i], 0.4, 0.55 + i * 0.15)
	var top := (ROTATE_RUN.size() - 1) * ROTATE_GAP
	_bell(b, top, ROTATE_RUN[ROTATE_RUN.size() - 1] * ROTATE_SHIMMER, 0.4, 0.5)
	# 바닥에 낮은 음 하나. 몸이 생겨야 스치는 소리가 가벼워지지 않는다.
	_bell(b, 0.0, ROTATE_RUN[0] * 0.25, 0.45, 0.3)
	return b

# 이동 — 유리알이 또르르 구른다. 매 칸마다 울리므로 거의 들리지 않을 만큼
# 여리다. 있는지 없는지 모를 정도가 맞다 — 조작을 방해하면 안 된다.
const MOVE_TICKS := 3
const MOVE_GAP := 0.045
const MOVE_RUN := [E5, G5, A5]
# 알끼리 이어지지 않으려면 알 하나가 다음 알 전에 다 꺼져야 한다. fade 를
# 크게 줘서 잔향만 남기고 알 자체는 곧바로 사라진다.
const MOVE_ATTACK := 0.004
const MOVE_FADE := 12.0

static func _move() -> PackedFloat32Array:
	var b := _buf(0.3)
	for i in MOVE_TICKS:
		_bell(b, i * MOVE_GAP, MOVE_RUN[i], 0.06, 0.8 - i * 0.15, MOVE_FADE, MOVE_ATTACK)
	return b

# 내리기 — 음계를 타고 아래로 떨어진다.
const DROP_RUN := [A6, G6, E6, C6]

static func _drop() -> PackedFloat32Array:
	var b := _buf(0.6)
	for i in DROP_RUN.size():
		_bell(b, i * 0.035, DROP_RUN[i], 0.4, 0.75)
	return b

# 착지 — 쿵. 낮은 음이 순식간에 내려앉고, 그 아래로 낮은 종이 여운을 남긴다.
# 쿵만 있으면 팍 하고 끝나 다른 소리들과 따로 논다.
static func _lock() -> PackedFloat32Array:
	var b := _buf(0.7)
	_thump(b, 0.0, 190.0, 48.0, 0.5, 1.0)
	_bell(b, 0.0, C3, 0.55, 0.3)
	_bell(b, 0.0, G3, 0.4, 0.15)
	return b

# 층이 지워질 때 — 음계를 타고 끝까지 올라갔다가 맨 위에서 한 번 더 반짝인다.
# 게임에서 제일 좋은 순간이라 제일 길고 제일 화려하다.
const CLEAR_RUN := [C5, D5, E5, G5, A5, C6]
const CLEAR_GAP := 0.075

static func _clear() -> PackedFloat32Array:
	var b := _buf(1.5)
	for i in CLEAR_RUN.size():
		_bell(b, i * CLEAR_GAP, CLEAR_RUN[i], 0.8, 0.8)
	var top := CLEAR_RUN.size() * CLEAR_GAP
	_bell(b, top, E6, 0.8, 0.7)
	_bell(b, top + 0.05, G6, 0.8, 0.5)
	return b

# 레벨업 — 세 음이 차례로 들어와 화음으로 남는다.
const LEVEL_RUN := [C6, E6, G6]

static func _level() -> PackedFloat32Array:
	var b := _buf(0.8)
	for i in LEVEL_RUN.size():
		_bell(b, i * 0.06, LEVEL_RUN[i], 0.55, 0.8)
	return b

# 게임 종료 — 같은 음계를 거꾸로 내려온다. 어둡게가 아니라 멀어지게.
const OVER_RUN := [A5, G5, E5, D5, C5]

static func _over() -> PackedFloat32Array:
	var b := _buf(1.6)
	for i in OVER_RUN.size():
		_bell(b, i * 0.16, OVER_RUN[i], 0.85, 0.8 - i * 0.1)
	return b

# 시점 돌리기 — 낮은 5도가 툭 떨어진다. 조각이 아니라 통이 돌았다는 것만
# 알리면 되므로 낮고, 짧고, 작다.
static func _turn() -> PackedFloat32Array:
	var b := _buf(0.4)
	_bell(b, 0.0, G3, 0.22, 0.8, 2.2)
	_bell(b, 0.05, C3, 0.25, 0.6, 2.0)
	return b

# 버튼 — 유리알 하나. 눌린 걸 알려주는 것 말고는 하는 일이 없다.
static func _ui() -> PackedFloat32Array:
	var b := _buf(0.3)
	_bell(b, 0.0, C6, 0.15, 0.8, 2.0)
	return b
