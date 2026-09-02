extends MeshInstance3D

var game: Game = null

func setup(g: Game) -> void:
	game = g
	game.piece_locked.connect(refresh)
	game.layers_cleared.connect(func(_ys: PackedInt32Array, _kind: int) -> void: refresh())
	refresh()

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	# 칸마다 색이 달라 정점 색으로 칠한다. 기본값은 그 값을 이미 선형 공간이라고
	# 보고 변환 없이 쓴다. 반면 떨어지는 조각(PieceView)은 albedo_color 로 색을
	# 넣고 그쪽은 sRGB 로 간주해 변환된다. 그래서 이걸 켜지 않으면 같은 색인데도
	# 조각이 잠기는 순간 밝기가 튄다.
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	material_override = mat

func refresh() -> void:
	if game == null:
		return
	# 쌓인 칸도 조각처럼 껍데기 하나로 그린다. 맞닿은 면이 사라지므로 쌓인
	# 더미가 칸 단위로 쪼개져 보이지 않고 한 덩어리로 보인다.
	var cells: Array[Vector3i] = []
	var colors := PackedColorArray()
	for y in Board.HEIGHT:
		for z in Board.DEPTH:
			for x in Board.WIDTH:
				var kind := game.board.get_cell(Vector3i(x, y, z))
				if kind == 0:
					continue
				cells.append(Vector3i(x, y, z))
				colors.append(BlockColors.of(kind))
	mesh = BlockMesh.hull_mesh(cells, colors)
