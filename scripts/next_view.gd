extends SubViewport

# 다음 조각 미리보기. 색만 보여주던 견본을 대신해 모양까지 보여준다.
# 본 게임 장면과 섞이지 않도록 자기만의 3D 월드를 하나 들고, 통을 보는 각도와
# 같은 방향에서 조각 껍데기를 그린다 — 미리보기와 실제 모습이 달라 보이면
# 미리보기가 오히려 헷갈리게 만든다.

const CAM_SIZE := 6.0
const CAM_DIST := 8.0
const VIEW_YAW := 45.0
const VIEW_PITCH := -30.0

var game: Game = null

var _mesh: MeshInstance3D = null

func _ready() -> void:
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var basis := Basis.from_euler(Vector3(deg_to_rad(VIEW_PITCH), deg_to_rad(VIEW_YAW), 0.0))
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAM_SIZE
	cam.transform = Transform3D(basis, basis * Vector3(0, 0, CAM_DIST))
	add_child(cam)

	# 면마다 밝기가 달라야 입체로 보인다. 빛은 카메라 쪽에서 비스듬히 준다.
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(
		Basis.from_euler(Vector3(deg_to_rad(-50.0), deg_to_rad(20.0), 0.0)), Vector3.ZERO)
	add_child(sun)

	_mesh = MeshInstance3D.new()
	_mesh.material_override = StandardMaterial3D.new()
	add_child(_mesh)

func setup(g: Game) -> void:
	game = g
	refresh()

func refresh() -> void:
	if game == null:
		return
	var cells := Piece.create(game.next_kind).cells
	_mesh.mesh = BlockMesh.hull_mesh(cells)
	# 조각마다 칸 수와 뻗은 방향이 달라 그대로 두면 화면 한쪽으로 쏠린다.
	# 바운딩 박스 한가운데를 원점에 맞춘다.
	var lo := Vector3(Piece.bbox_min(cells))
	var hi := Vector3(Piece.bbox_max(cells))
	_mesh.position = -(lo + hi) * 0.5
	(_mesh.material_override as StandardMaterial3D).albedo_color = BlockColors.of(game.next_kind)
