class_name RotateIcon
extends Control

# 회전 버튼에 얹는 화살표. 글자 대신 도형으로 어느 쪽으로 도는지 보여준다 —
# 부분집합 폰트에 화살표 글리프가 없기도 하고, 축 이름(X/Y/Z)보다 궤적 그림이
# 화면에서 실제로 일어나는 일에 가깝다.
enum { RIGHT, DOWN, CLOCK }

@export var kind: int = RIGHT

const COLOR := Color(0.84, 0.87, 0.94)
const WIDTH := 5.0
const HEAD := 11.0
const STEPS := 24

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.30
	# 납작한 타원은 좌우로, 갸름한 타원은 위아래로 도는 궤적으로 읽힌다.
	var rx := r
	var ry := r
	var a0 := 0.0
	var a1 := 0.0
	match kind:
		RIGHT:
			ry = r * 0.5
			a0 = deg_to_rad(200.0)
			a1 = deg_to_rad(-20.0)
		DOWN:
			rx = r * 0.5
			a0 = deg_to_rad(-110.0)
			a1 = deg_to_rad(110.0)
		CLOCK:
			a0 = deg_to_rad(-120.0)
			a1 = deg_to_rad(150.0)

	var pts := PackedVector2Array()
	for i in STEPS + 1:
		var t := lerpf(a0, a1, float(i) / float(STEPS))
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	draw_polyline(pts, COLOR, WIDTH, true)

	# 촉은 호가 끝나는 자리에 진행 방향으로 세운다.
	var tip: Vector2 = pts[pts.size() - 1]
	var dir := (tip - pts[pts.size() - 2]).normalized()
	var side := Vector2(-dir.y, dir.x) * HEAD * 0.6
	draw_colored_polygon(PackedVector2Array([
		tip + dir * HEAD, tip + side, tip - side]), COLOR)
