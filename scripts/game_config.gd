class_name GameConfig
extends RefCounted

# 시작 화면에서 고른 설정. 씬을 갈아끼워도 남아야 하므로 정적 변수로 들고 있다.

const SIZES := [4, 5, 6]

const EASY := 0
const NORMAL := 1
const HARD := 2

# 층 클리어에 필요한 칸 수를 난이도별로 깎아준다. 인덱스가 난이도다.
# 통이 커질수록 한 층을 채우는 데 필요한 조각 수가 제곱으로 늘어나므로
# 절대값이 아니라 "한 층 전체에서 몇 칸 빼주는가"로 잡는다.
#
# 보통에서 한 칸을 봐주니 "다 안 찼는데 지워진다"고 읽혔다. 눈에 보이는 것과
# 규칙이 어긋나는 쪽이 난이도 조절보다 손해다. 쉬움만 봐주고 나머지는 꽉 채운다.
const THRESHOLD_SLACK := [2, 0, 0]

# 기본값은 시작 화면을 거치지 않고 main.tscn 을 직접 띄웠을 때(테스트 포함) 쓰인다.
# 원래 구현되어 있던 게임이 그대로 나오도록 4x4 / 어려움으로 둔다.
static var size := 4
static var difficulty := HARD

static func apply() -> void:
	Board.resize(size, size, size * size - THRESHOLD_SLACK[difficulty])

# 쉬움과 보통에는 평면 조각만 나온다. 비평면 3종은 어려움 전용이다.
static func kinds() -> Array:
	if difficulty == HARD:
		return Piece.SHAPES.keys()
	var out: Array = []
	for k in Piece.SHAPES.keys():
		if k <= Piece.PLANAR_MAX:
			out.append(k)
	return out

# 쉬움은 조각이 저절로 내려오지 않는다 — 내리기를 눌러야만 잠긴다.
static func gravity() -> bool:
	return difficulty != EASY
