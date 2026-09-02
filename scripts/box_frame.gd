extends Node3D

const LINE_COLOR := Color(1, 1, 1, 0.25)
const FLOOR_COLOR := Color(1, 1, 1, 0.22)

func _ready() -> void:
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	# 셀 중심이 정수 좌표이므로 통의 실제 경계는 -0.5 에서 크기-0.5 이다.
	var x0 := -0.5
	var x1 := float(Board.WIDTH) - 0.5
	var z0 := -0.5
	var z1 := float(Board.DEPTH) - 0.5
	var y0 := -0.5
	var y1 := float(Board.HEIGHT) - 0.5

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# 바닥 격자
	for i in Board.WIDTH + 1:
		var x := x0 + float(i)
		_line(mesh, Vector3(x, y0, z0), Vector3(x, y0, z1), FLOOR_COLOR)
	for i in Board.DEPTH + 1:
		var z := z0 + float(i)
		_line(mesh, Vector3(x0, y0, z), Vector3(x1, y0, z), FLOOR_COLOR)

	# 수직 기둥 4개
	for c in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		_line(mesh, Vector3(c.x, y0, c.y), Vector3(c.x, y1, c.y), LINE_COLOR)

	# 천장 테두리
	_line(mesh, Vector3(x0, y1, z0), Vector3(x1, y1, z0), LINE_COLOR)
	_line(mesh, Vector3(x1, y1, z0), Vector3(x1, y1, z1), LINE_COLOR)
	_line(mesh, Vector3(x1, y1, z1), Vector3(x0, y1, z1), LINE_COLOR)
	_line(mesh, Vector3(x0, y1, z1), Vector3(x0, y1, z0), LINE_COLOR)

	mesh.surface_end()

func _line(mesh: ImmediateMesh, a: Vector3, b: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(a)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(b)
