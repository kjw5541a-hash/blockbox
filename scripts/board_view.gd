extends MultiMeshInstance3D

const CELL_SIZE := 0.92

var game: Game = null

func setup(g: Game) -> void:
	game = g
	game.piece_locked.connect(refresh)
	game.layers_cleared.connect(func(_n: int) -> void: refresh())
	refresh()

func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat

	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = Board.WIDTH * Board.DEPTH * Board.HEIGHT
	multimesh.visible_instance_count = 0

func refresh() -> void:
	if game == null:
		return
	var i := 0
	for y in Board.HEIGHT:
		for z in Board.DEPTH:
			for x in Board.WIDTH:
				var kind := game.board.get_cell(Vector3i(x, y, z))
				if kind == 0:
					continue
				multimesh.set_instance_transform(
					i, Transform3D(Basis(), Vector3(x, y, z)))
				multimesh.set_instance_color(i, BlockColors.of(kind))
				i += 1
	multimesh.visible_instance_count = i
