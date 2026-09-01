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
	# MultiMesh 인스턴스 색은 정점 색으로 들어가는데, 기본값은 그 값을 이미
	# 선형 공간이라고 보고 변환 없이 쓴다. 반면 떨어지는 조각(PieceView)은
	# albedo_color 로 색을 넣고 그쪽은 sRGB 로 간주해 변환된다. 그래서 이걸
	# 켜지 않으면 같은 색인데도 조각이 잠기는 순간 밝기가 튄다.
	mat.vertex_color_is_srgb = true
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
