extends Node3D

const CELL_SIZE := 0.92

var game: Game = null

var _cubes: Array[MeshInstance3D] = []

func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)
	for _i in 4:
		var m := MeshInstance3D.new()
		m.mesh = mesh
		m.material_override = StandardMaterial3D.new()
		m.visible = false
		add_child(m)
		_cubes.append(m)

func setup(g: Game) -> void:
	game = g
	game.piece_moved.connect(refresh)
	game.game_over.connect(_hide_all)
	refresh()

func _hide_all() -> void:
	for m in _cubes:
		m.visible = false

func refresh() -> void:
	if game == null or game.current == null:
		_hide_all()
		return
	var color := BlockColors.of(game.current.kind)
	var world := game.current.world_cells()
	for i in _cubes.size():
		var m := _cubes[i]
		m.visible = true
		m.position = Vector3(world[i])
		(m.material_override as StandardMaterial3D).albedo_color = color
