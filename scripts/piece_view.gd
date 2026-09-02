extends Node3D

const GHOST_ALPHA := 0.28
const FOOTPRINT_ALPHA := 0.45
const FOOTPRINT_Y := -0.48

var game: Game = null

var _solid: MeshInstance3D = null
var _ghost: MeshInstance3D = null
var _marks: Array[MeshInstance3D] = []

func _ready() -> void:
	# 발자국은 칸 크기 그대로 깔아 옆 칸과 맞닿게 한다. 사이에 틈을 두면
	# 붙어 있는 조각인데도 칸이 하나씩 따로 놀아 보인다.
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y

	# 떨어지는 조각도 고스트처럼 껍데기 하나다. 칸마다 큐브를 놓으면 칸 경계에
	# 그림자 선이 생겨 네 조각이 따로 놀아 보인다.
	_solid = _make(false)
	_ghost = _make(true)
	for _i in 4:
		var m := _make(true)
		m.mesh = quad
		_marks.append(m)

func _make(transparent: bool) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
	_solid.visible = false
	_ghost.visible = false
	for m in _marks:
		m.visible = false

func refresh() -> void:
	if game == null or game.current == null:
		_hide_all()
		return
	var color := BlockColors.of(game.current.kind)

	# 조각은 네 칸뿐이라 움직일 때마다 껍데기를 다시 만들어도 비용이 없다시피 하다.
	_solid.mesh = BlockMesh.hull_mesh(game.current.world_cells())
	_show(_solid, Vector3.ZERO, color, 1.0)

	_ghost.mesh = BlockMesh.hull_mesh(game.ghost_cells())
	_show(_ghost, Vector3.ZERO, color, GHOST_ALPHA)

	var fp := game.footprint_cells()
	for i in _marks.size():
		if i >= fp.size():
			_marks[i].visible = false
			continue
		_show(_marks[i], Vector3(fp[i].x, FOOTPRINT_Y, fp[i].z), color, FOOTPRINT_ALPHA)

func _show(m: MeshInstance3D, pos: Vector3, color: Color, alpha: float) -> void:
	m.visible = true
	m.position = pos
	var mat := m.material_override as StandardMaterial3D
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
