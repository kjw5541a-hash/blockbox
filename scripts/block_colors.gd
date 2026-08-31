class_name BlockColors
extends RefCounted

# 원작 테트리스의 색 배합을 그대로 쓰지 않는다 (상표/트레이드드레스 회피).
const TABLE := {
	1: Color(0.30, 0.72, 0.85),
	2: Color(0.90, 0.76, 0.30),
	3: Color(0.72, 0.45, 0.85),
	4: Color(0.45, 0.80, 0.50),
	5: Color(0.90, 0.52, 0.38),
	6: Color(0.55, 0.60, 0.90),
	7: Color(0.85, 0.45, 0.60),
	8: Color(0.60, 0.80, 0.75),
}

static func of(kind: int) -> Color:
	return TABLE.get(kind, Color.WHITE)
