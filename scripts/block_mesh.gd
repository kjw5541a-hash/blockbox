class_name BlockMesh
extends RefCounted

# 칸 목록을 겉면만 남긴 메시 하나로 만든다. 이웃한 칸이 있는 면은 빼므로
# 칸 경계가 보이지 않고 붙어 있는 칸들이 한 덩어리로 보인다.
# 떨어지는 조각, 쌓인 칸, 고스트가 모두 이 함수 하나로 그려진다.

const _DIRS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

# colors 는 cells 와 같은 순서의 칸 색이다. 비워 두면 흰색으로 칠하므로
# 재질의 albedo_color 가 그대로 색이 된다.
static func hull_mesh(cells: Array[Vector3i],
		colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var filled := {}
	for i in cells.size():
		filled[cells[i]] = colors[i] if i < colors.size() else Color.WHITE
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in filled:
		for d in _DIRS:
			if filled.has(c + d):
				continue
			_add_face(st, Vector3(c), Vector3(d), filled[c])
	return st.commit()

static func _add_face(st: SurfaceTool, center: Vector3, n: Vector3, color: Color) -> void:
	# 축에 나란한 법선이라 성분을 한 칸 돌리면 반드시 법선과 어긋난 축이 나온다.
	var u := Vector3(n.y, n.z, n.x)
	var v := n.cross(u)
	var o := center + n * 0.5
	var p := [
		o - u * 0.5 - v * 0.5,
		o + u * 0.5 - v * 0.5,
		o + u * 0.5 + v * 0.5,
		o - u * 0.5 + v * 0.5,
	]
	# Godot 은 (v1-v0)×(v2-v0) 이 법선의 *반대* 쪽인 삼각형을 앞면으로 친다.
	# u×v 가 곧 n 이므로 0,1,2 순서로 감으면 바깥 면이 뒷면이 되어, 뒷면을
	# 지우는 순간 조각이 통째로 사라진다. 그래서 뒤집어 감는다.
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_color(color)
		st.set_normal(n)
		st.add_vertex(p[i])
