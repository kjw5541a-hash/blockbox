class_name TouchInput
extends Node

# 통 바깥을 이만큼 가로로 끌면 시점이 한 칸 돈다.
const TURN_PIXELS := 90.0

const MODE_NONE := 0
const MODE_PIECE := 1
const MODE_VIEW := 2

var game: Game = null
var rig: CameraRig = null

var _camera: Camera3D = null
var _mode := MODE_NONE
# 격자 축 단위로 누적한 드래그. 1.0 이 한 칸이다.
var _away := 0.0
var _right := 0.0
var _turn := 0.0

func setup(g: Game, r: CameraRig) -> void:
	game = g
	rig = r
	_camera = r.get_node_or_null("Camera3D") as Camera3D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			begin_drag(event.position)
		else:
			end_drag()
	elif event is InputEventScreenDrag:
		# 터치 시작을 놓쳤을 때(창 포커스가 드래그 도중에 들어온 경우)의 안전망.
		if _mode == MODE_NONE:
			begin_drag(event.position)
		feed_drag(event.relative)

# 통 안에서 시작한 드래그는 조각을 옮기고, 바깥에서 시작한 드래그는 시점을 돌린다.
func begin_drag(at: Vector2) -> void:
	_reset()
	_mode = MODE_PIECE if box_screen_rect().has_point(at) else MODE_VIEW

func end_drag() -> void:
	_mode = MODE_NONE
	_reset()

func _reset() -> void:
	_away = 0.0
	_right = 0.0
	_turn = 0.0

# 통의 여덟 꼭짓점을 화면에 투영해 감싸는 사각형. 실루엣보다 네 귀퉁이가 조금
# 넓지만, 시점 회전은 통 좌우의 넓은 여백에서 하므로 실사용에 지장이 없다.
func box_screen_rect() -> Rect2:
	if _camera == null:
		return Rect2()
	var lo := Vector3(-0.5, -0.5, -0.5)
	var hi := Vector3(Board.WIDTH - 0.5, Board.HEIGHT - 0.5, Board.DEPTH - 0.5)
	var rect := Rect2(_camera.unproject_position(lo), Vector2.ZERO)
	for i in range(1, 8):
		rect = rect.expand(_camera.unproject_position(Vector3(
			hi.x if i & 1 else lo.x,
			hi.y if i & 2 else lo.y,
			hi.z if i & 4 else lo.z)))
	return rect

# 격자 축 한 칸이 화면에서 차지하는 픽셀 벡터. 직교 투영이라 기준점과 무관하다.
func axis_screen(axis: Vector3i) -> Vector2:
	var o := rig.global_position
	return _camera.unproject_position(o + Vector3(axis)) - _camera.unproject_position(o)

func feed_drag(relative: Vector2) -> void:
	if _mode == MODE_VIEW:
		_feed_view(relative)
	elif _mode == MODE_PIECE:
		_feed_piece(relative)

func _feed_view(relative: Vector2) -> void:
	if rig == null:
		return
	_turn += relative.x
	while absf(_turn) >= TURN_PIXELS:
		var dir := 1 if _turn > 0.0 else -1
		_turn -= TURN_PIXELS * dir
		rig.turn(dir)

func _feed_piece(relative: Vector2) -> void:
	if game == null or rig == null or _camera == null or game.current == null:
		return
	var u := axis_screen(rig.axis_away())
	var r := axis_screen(rig.axis_right())
	var det := u.x * r.y - u.y * r.x
	# 두 축이 화면에서 겹쳐 보이면 분해가 불가능하다. 쿼터뷰에서는 생기지 않는다.
	if absf(det) < 0.0001:
		return
	# 드래그를 두 격자축의 화면 벡터로 분해한다. 화면에서 우세한 축 하나만 고르는
	# 방식은 쿼터뷰에서 두 축이 모두 오른쪽을 향하기 때문에 손가락과 반대 사분면으로
	# 조각을 보낸다. 분해하면 조각이 손가락을 그대로 따라가고, 성분 1.0 이 정확히
	# 화면상 한 칸이라 감도도 눈에 보이는 칸 크기와 같아진다.
	_away += (relative.x * r.y - relative.y * r.x) / det
	_right += (u.x * relative.y - u.y * relative.x) / det
	_away = _consume(_away, rig.axis_away())
	_right = _consume(_right, rig.axis_right())

func _consume(amount: float, axis: Vector3i) -> float:
	while absf(amount) >= 1.0:
		var dir := 1 if amount > 0.0 else -1
		amount -= float(dir)
		game.move(axis * dir)
	return amount
