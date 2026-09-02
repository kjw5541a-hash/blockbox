extends Node3D

# 층이 지워질 때 그 자리에서 불티가 터진다. 지워졌다는 사실이 점수 숫자
# 말고 화면에서도 바로 보여야 한 층을 채운 보람이 난다.
#
# GPU 파티클이 아니라 CPU 파티클을 쓴다. 웹 빌드는 호환성 렌더러로 떨어지고,
# 거기서 확실히 도는 쪽이 이쪽이다. 한 번에 몇백 개라 비용도 문제되지 않는다.
const LIFETIME := 0.9
const PER_CELL := 8
const SPARK_SIZE := 0.16
const WHITEN := 0.35

var game: Game = null

func setup(g: Game) -> void:
	game = g
	game.layers_cleared.connect(_on_cleared)

func _on_cleared(ys: PackedInt32Array, kind: int) -> void:
	for y in ys:
		burst(y, BlockColors.of(kind))

func burst(y: int, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.mesh = _spark_mesh()
	p.amount = Board.LAYER_CELLS * PER_CELL
	p.lifetime = LIFETIME
	p.one_shot = true
	# 층 전체가 한꺼번에 사라지므로 불티도 한꺼번에 나가야 한다.
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(Board.WIDTH * 0.5, 0.05, Board.DEPTH * 0.5)
	p.position = Vector3((Board.WIDTH - 1) * 0.5, y, (Board.DEPTH - 1) * 0.5)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 60.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0.0, -9.8, 0.0)
	# 방금 놓은 조각 색으로 튄다. 흰색을 조금 섞어야 불티처럼 밝게 뜬다.
	p.color = color.lerp(Color.WHITE, WHITEN)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	# 다 터진 뒤 스스로 사라진다. 안 그러면 판이 길어질수록 노드가 쌓인다.
	p.finished.connect(p.queue_free)
	# emitting 은 기본이 true 라 트리에 넣는 순간 터진다.
	add_child(p)

# 불티 하나하나가 자기 메시를 들면 층마다 수백 개를 새로 만들게 된다. 하나를
# 만들어 돌려 쓴다.
static var _mesh: BoxMesh = null

static func _spark_mesh() -> BoxMesh:
	if _mesh == null:
		_mesh = BoxMesh.new()
		_mesh.size = Vector3(SPARK_SIZE, SPARK_SIZE, SPARK_SIZE)
		var mat := StandardMaterial3D.new()
		# 빛을 받지 않아야 어두운 배경에서 또렷하게 튄다.
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# 불티 색은 층마다 다르다. 메시는 하나를 돌려 쓰므로 색은 파티클이
		# 정점 색으로 실어 보낸다. 선형으로 읽으면 조각 색보다 밝게 튄다.
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		_mesh.material = mat
	return _mesh
