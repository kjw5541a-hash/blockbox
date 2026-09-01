extends Node3D

const CELL_SIZE := 0.92
const GHOST_ALPHA := 0.28
const FOOTPRINT_ALPHA := 0.45
const FOOTPRINT_Y := -0.48

const _DIRS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

var game: Game = null

var _cubes: Array[MeshInstance3D] = []
var _ghost: MeshInstance3D = null
var _marks: Array[MeshInstance3D] = []

func _ready() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)
	# 발자국은 칸 크기 그대로 깔아 옆 칸과 맞닿게 한다. 사이에 틈을 두면
	# 붙어 있는 조각인데도 칸이 하나씩 따로 놀아 보인다.
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y

	# 4개짜리 큐브를 먼저 전부 만들고 나서 고스트/발자국을 만든다.
	# tests/test_main_smoke.gd 가 get_child(0..3) 이 조각 큐브라고 가정한다 —
	# 여기서 순서를 섞으면 그 테스트가 깨진다.
	for _i in 4:
		_cubes.append(_make(cube, false))
	_ghost = _make(null, true)
	# 겉면만 남긴 껍데기라 앞뒤 면이 정확히 두 겹씩 겹친다. 뒷면을 지우면
	# 감는 방향에 따라 통째로 사라질 수 있어, 양면을 다 그린다.
	(_ghost.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	for _i in 4:
		_marks.append(_make(quad, true))

func _make(mesh: Mesh, transparent: bool) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.visible = false
	add_child(m)
	return m

# 칸 목록을 겉면만 남긴 메시 하나로 만든다. 이웃한 칸이 있는 면은 빼므로
# 안쪽 칸 경계가 비쳐 보이지 않고 조각 전체가 한 덩어리로 보인다.
static func hull_mesh(cells: Array[Vector3i]) -> ArrayMesh:
	var filled := {}
	for c in cells:
		filled[c] = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in filled:
		for d in _DIRS:
			if filled.has(c + d):
				continue
			_add_face(st, Vector3(c), Vector3(d))
	st.generate_normals()
	return st.commit()

static func _add_face(st: SurfaceTool, center: Vector3, n: Vector3) -> void:
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
	for i in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(p[i])

func setup(g: Game) -> void:
	game = g
	game.piece_moved.connect(refresh)
	game.game_over.connect(_hide_all)
	refresh()

func _hide_all() -> void:
	_ghost.visible = false
	for group in [_cubes, _marks]:
		for m in group:
			m.visible = false

func refresh() -> void:
	if game == null or game.current == null:
		_hide_all()
		return
	var color := BlockColors.of(game.current.kind)

	var world := game.current.world_cells()
	for i in _cubes.size():
		_place(_cubes[i], Vector3(world[i]), color, 1.0)

	# 고스트는 칸마다 큐브를 놓지 않고 매번 껍데기를 새로 만든다. 조각은 네
	# 칸뿐이라 다시 만드는 비용이 없다시피 하다.
	_ghost.mesh = hull_mesh(game.ghost_cells())
	_place(_ghost, Vector3.ZERO, color, GHOST_ALPHA)

	var fp := game.footprint_cells()
	for i in _marks.size():
		if i >= fp.size():
			_marks[i].visible = false
			continue
		_place(_marks[i], Vector3(fp[i].x, FOOTPRINT_Y, fp[i].z), color, FOOTPRINT_ALPHA)

func _place(m: MeshInstance3D, pos: Vector3, color: Color, alpha: float) -> void:
	m.visible = true
	m.position = pos
	var mat := m.material_override as StandardMaterial3D
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
