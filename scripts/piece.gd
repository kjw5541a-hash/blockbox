class_name Piece
extends RefCounted

const AXIS_X := 0
const AXIS_Y := 1
const AXIS_Z := 2

# 크기 4 폴리큐브 중 평면 조각 5종. XZ 평면에 눕혀서 정의한다.
# 3D 회전에서는 거울상이 서로 겹치므로 2D의 S/Z와 J/L은 각각 한 종으로 합쳐진다.
const SHAPES := {
	1: [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0)],  # I
	2: [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1)],  # O
	3: [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(1, 0, 1)],  # T
	4: [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 1), Vector3i(2, 0, 1)],  # S
	5: [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(2, 0, 1)],  # L
}

var kind := 0
var cells: Array[Vector3i] = []
var origin := Vector3i.ZERO

static func create(piece_kind: int) -> Piece:
	var p := Piece.new()
	p.kind = piece_kind
	var out: Array[Vector3i] = []
	for c in SHAPES[piece_kind]:
		out.append(c)
	p.cells = out
	return p

func copy() -> Piece:
	var p := Piece.new()
	p.kind = kind
	p.origin = origin
	var out: Array[Vector3i] = []
	for c in cells:
		out.append(c)
	p.cells = out
	return p

func world_cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for c in cells:
		out.append(c + origin)
	return out

static func rotate_cell(cell: Vector3i, axis: int, dir: int) -> Vector3i:
	match axis:
		AXIS_X:
			return Vector3i(cell.x, dir * cell.z, -dir * cell.y)
		AXIS_Y:
			return Vector3i(-dir * cell.z, cell.y, dir * cell.x)
		_:
			return Vector3i(dir * cell.y, -dir * cell.x, cell.z)

# 회전 후 바운딩 박스의 최소점을 회전 전과 같게 맞춘다. 조각별 피벗 테이블 없이
# 조각이 제자리에서 도는 효과를 낸다. 최소점이 매 회전마다 보존되므로
# 같은 축으로 4회 회전하면 원본과 정확히 일치한다.
func rotated(axis: int, dir: int) -> Piece:
	var before_min := bbox_min(cells)
	var turned: Array[Vector3i] = []
	for c in cells:
		turned.append(rotate_cell(c, axis, dir))
	var shift := before_min - bbox_min(turned)
	var out := copy()
	var shifted: Array[Vector3i] = []
	for c in turned:
		shifted.append(c + shift)
	out.cells = shifted
	return out

static func bbox_min(list: Array[Vector3i]) -> Vector3i:
	var m := list[0]
	for c in list:
		m.x = mini(m.x, c.x)
		m.y = mini(m.y, c.y)
		m.z = mini(m.z, c.z)
	return m

static func bbox_max(list: Array[Vector3i]) -> Vector3i:
	var m := list[0]
	for c in list:
		m.x = maxi(m.x, c.x)
		m.y = maxi(m.y, c.y)
		m.z = maxi(m.z, c.z)
	return m
