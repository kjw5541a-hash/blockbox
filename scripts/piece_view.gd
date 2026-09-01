extends Node3D

const CELL_SIZE := 0.92
const GHOST_ALPHA := 0.28
const FOOTPRINT_ALPHA := 0.45
const FOOTPRINT_Y := -0.48

var game: Game = null

var _cubes: Array[MeshInstance3D] = []
var _ghosts: Array[MeshInstance3D] = []
var _marks: Array[MeshInstance3D] = []

func _ready() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)
	var quad := QuadMesh.new()
	quad.size = Vector2(CELL_SIZE, CELL_SIZE)
	quad.orientation = PlaneMesh.FACE_Y

	# 4개짜리 큐브를 먼저 전부 만들고 나서 고스트/발자국을 만든다.
	# tests/test_main_smoke.gd 가 get_child(0..3) 이 조각 큐브라고 가정한다 —
	# 여기서 순서를 섞으면 그 테스트가 깨진다.
	for _i in 4:
		_cubes.append(_make(cube, false))
	for _i in 4:
		_ghosts.append(_make(cube, true))
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

func setup(g: Game) -> void:
	game = g
	game.piece_moved.connect(refresh)
	game.game_over.connect(_hide_all)
	refresh()

func _hide_all() -> void:
	for group in [_cubes, _ghosts, _marks]:
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

	var ghost := game.ghost_cells()
	for i in _ghosts.size():
		_place(_ghosts[i], Vector3(ghost[i]), color, GHOST_ALPHA)

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
