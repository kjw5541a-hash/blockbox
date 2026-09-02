class_name GameConfig
extends RefCounted

# 시작 화면에서 고른 설정. 씬을 갈아끼워도 남아야 하므로 정적 변수로 들고 있다.

const SIZES := [4, 5, 6]

const EASY := 0
const NORMAL := 1
const HARD := 2
const HELL := 3

# 난이도 버튼 줄의 순서이자 값이다. 난이도를 훑는 쪽이 숫자를 따로 적지 않도록
# 한곳에 모아 둔다.
const ALL := [EASY, NORMAL, HARD, HELL]

# 난이도는 스위치 세 개가 하나씩 켜지는 계단이다.
#   쉬움   기본 조각만, 저절로 안 내려옴, 착지 그림자 있음
#   보통   + 특수(비평면) 조각
#   어려움 + 저절로 내려옴
#   헬     + 착지 그림자 없음

# 층 클리어에 필요한 칸 수를 난이도별로 깎아준다. 인덱스가 난이도다.
# 통이 커질수록 한 층을 채우는 데 필요한 조각 수가 제곱으로 늘어나므로
# 절대값이 아니라 "한 층 전체에서 몇 칸 빼주는가"로 잡는다.
#
# 보통에서 한 칸을 봐주니 "다 안 찼는데 지워진다"고 읽혔다. 눈에 보이는 것과
# 규칙이 어긋나는 쪽이 난이도 조절보다 손해다. 쉬움만 봐주고 나머지는 꽉 채운다.
const THRESHOLD_SLACK := [2, 0, 0, 0]

# 기본값은 시작 화면을 거치지 않고 main.tscn 을 직접 띄웠을 때(테스트 포함) 쓰인다.
# 원래 구현되어 있던 게임이 그대로 나오도록 4x4 / 어려움으로 둔다.
static var size := 4
static var difficulty := HARD

static func apply() -> void:
	Board.resize(size, size, size * size - THRESHOLD_SLACK[difficulty])

# 쉬움에는 평면 조각만 나온다. 비평면 3종은 보통부터다.
static func kinds() -> Array:
	if difficulty != EASY:
		return Piece.SHAPES.keys()
	var out: Array = []
	for k in Piece.SHAPES.keys():
		if k <= Piece.PLANAR_MAX:
			out.append(k)
	return out

# 쉬움과 보통은 조각이 저절로 내려오지 않는다 — 내리기를 눌러야만 잠긴다.
static func gravity() -> bool:
	return difficulty >= HARD

# 헬만 착지 자리를 숨긴다. 어디에 놓일지 눈으로 못 보고 세어야 한다.
static func ghost() -> bool:
	return difficulty != HELL
