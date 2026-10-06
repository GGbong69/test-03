extends RefCounted
#  포스터용 다트 한 자루 — 매끈한 원기둥 · 날개 판으로 다시 짓는다 (2026-10-06).
#  게임의 자루(game.gd _dart3_meshes · Meshy 500 삼각형)는 화면에서 열 몇 px 이라 괜찮지만,
#  포스터 배율(논리 1px = 11~14 인쇄 px)에서는 날개 테두리가 울퉁불퉁하고 면이 각져 보인다.
#  색과 토막 차례는 게임 그대로다 — 강철 촉 · 크림 배럴(fbf6ea) · 어두운 샤프트(4a4160) ·
#  배럴보다 한 단 어두운 크림 날개(_dart3_meshes 의 col.darkened(0.18)).
#  약속도 게임 그대로 — 자루 축이 로컬 +Y, 촉 끝이 정확히 −dl, 꽁지가 +dl(_bd3_pose 가 읽는다).
#  비율만 실물 다트에 맞췄다(촉 0.20 · 배럴 0.30 · 샤프트 0.24 · 날개 반폭 0.10 — 길이 몫).

const STEEL := Color("dde3ec")
const CREAM := Color("fbf6ea")
const SHAFT := Color("4a4160")


static func _mat(c: Color, rough: float, metal := 0.0, two := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if two:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


#  s0 → s1(촉 0 · 꽁지 1) 토막 — 아래(촉 쪽) 반지름 r0 · 위 r1(길이 몫).
static func _seg(root: Node3D, L: float, s0: float, s1: float, r0: float, r1: float,
		m: Material, seg := 48) -> void:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r0 * L
	cm.top_radius = r1 * L
	cm.height = (s1 - s0) * L
	cm.radial_segments = seg
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	mi.position = Vector3(0.0, ((s0 + s1) * 0.5 - 0.5) * L, 0.0)
	root.add_child(mi)


#  날개 한 장 — 로컬 XY 평면, +X 쪽으로 편다. 점은 (반폭 몫, s).
const WING := [Vector2(0.0, 0.650), Vector2(0.080, 0.805), Vector2(0.100, 0.905),
		Vector2(0.097, 0.985), Vector2(0.0, 0.985)]


static func _wing_mesh(L: float) -> ArrayMesh:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	for i in range(1, WING.size() - 1):
		for p in [WING[0], WING[i], WING[i + 1]]:
			v.append(Vector3(p.x * L, (p.y - 0.5) * L, 0.0))
			nrm.append(Vector3(0.0, 0.0, 1.0))
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = nrm
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


static func build(dl: float, col: Color = CREAM) -> Node3D:
	var L := dl * 2.0
	var root := Node3D.new()
	root.name = "DartClean"
	var steel := _mat(STEEL, 0.28, 0.85)
	var barrel := _mat(col, 0.42, 0.25)
	var groove := _mat(col.darkened(0.45), 0.6, 0.2)
	var shaft := _mat(SHAFT, 0.38, 0.1)
	var wing := _mat(col.darkened(0.18), 0.55, 0.0, true)
	#  촉 — 바늘 끝에서 배럴 앞까지 가늘게 벌어진다
	_seg(root, L, 0.000, 0.185, 0.0, 0.0085, steel)
	_seg(root, L, 0.185, 0.205, 0.0085, 0.0100, steel)
	#  배럴 — 앞뒤로 좁아지고 가운데 쥐는 홈 셋
	_seg(root, L, 0.205, 0.245, 0.0120, 0.0200, barrel)
	_seg(root, L, 0.245, 0.465, 0.0200, 0.0200, barrel)
	_seg(root, L, 0.465, 0.505, 0.0200, 0.0110, barrel)
	for gs in [0.300, 0.330, 0.360, 0.390]:
		_seg(root, L, gs, gs + 0.010, 0.0207, 0.0207, groove)
	#  샤프트 — 날개 뿌리까지
	_seg(root, L, 0.505, 0.990, 0.0082, 0.0082, shaft, 24)
	#  날개 넷 — 자루 둘레 90° 마다
	var wm := _wing_mesh(L)
	for q in 4:
		var mi := MeshInstance3D.new()
		mi.mesh = wm
		mi.material_override = wing
		mi.rotation = Vector3(0.0, PI * 0.5 * float(q), 0.0)
		root.add_child(mi)
	return root
