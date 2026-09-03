extends Node3D

# 상점 — 진짜 3D 로 다시 짠다.
#
# 옛 상점은 손으로 계산한 정사영이었다. 테이블은 52° 로 내려다보고 딜러는
# 정면에서 본 것처럼 그리는, 투영 둘을 섞은 그림이다. 카메라 하나로는
# 못 하는 거짓말이라 3D 로 옮기는 순간 어긋난다. 그래서 옮기지 않고 새로 짠다.
#
# 규칙 셋.
#   1. 자리는 월드 좌표다. 화면 px 를 좌표로 쓰지 않는다.
#   2. 집는 판정은 레이캐스트다. 사다리꼴 안쪽 검사가 아니다.
#   3. 화면은 640x360 · nearest 그대로다. 도트는 해상도가 만든다.
#
# 단위는 미터다. 테이블 폭 1.9m, 딜러 키 1.7m — 실물 크기라야 카메라
# 화각과 조명이 상식대로 먹는다.

const TABLE := "res://assets/table.obj"
const TABLE_TEX := "res://assets/table_albedo.jpg"
const DEALER := "res://assets/dealer.glb"
const DOT := "res://scripts/shaders/dot.gdshader"

const TABLE_W := 1.90          # 테이블 폭(m)
const DEALER_H := 1.70         # 딜러 키(m)
const SLOTS := 4               # 매대 자리
const SLOT_GAP := 0.34         # 자리 간격(m)
const CARD := Vector3(0.24, 0.012, 0.34)   # 매물 판 크기(m)

@onready var cam: Camera3D = $Cam

var top_y := 0.0               # 상판 높이(m). 테이블 상자에서 잰다
var slots: Array[Node3D] = []
var hot := -1                  # 커서 아래 자리


func _ready() -> void:
	_build_table()
	_build_dealer()
	_build_slots()
	_aim_camera()


# ── 재질 ─────────────────────────────────────────────
# 도트 셰이더 하나로 통일한다. 명암을 계단으로 끊어야 640x360 에 찍혔을 때
# 손으로 칠한 화면과 붙는다 — 매끄러운 PBR 은 도트로 줄여도 안 붙는다.
func _dot(tex: Texture2D, tint := Color.WHITE, bands := 4, steps := 12) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(DOT)
	if tex != null:
		m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("light_bands", bands)
	m.set_shader_parameter("color_steps", steps)
	return m


func _meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		_meshes(c, out)


func _box(n: Node) -> AABB:
	var mis: Array[MeshInstance3D] = []
	_meshes(n, mis)
	if mis.is_empty():
		return AABB()
	var ab: AABB = mis[0].get_aabb()
	for i in range(1, mis.size()):
		ab = ab.merge(mis[i].get_aabb())
	return ab


# ── 테이블 ───────────────────────────────────────────
func _build_table() -> void:
	var mesh: Mesh = load(TABLE)
	if mesh == null:
		push_warning("테이블 메시가 없다: " + TABLE)
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _dot(load(TABLE_TEX))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var ab := mesh.get_aabb()
	var k := TABLE_W / maxf(ab.size.x, 0.001)
	mi.scale = Vector3.ONE * k
	# 바닥이 y=0 에 오게 내린다. 상판 높이는 상자 윗면이다.
	mi.position = Vector3(-ab.get_center().x * k, -ab.position.y * k,
			-ab.get_center().z * k)
	top_y = ab.size.y * k
	mi.name = "Table"


# ── 딜러 ─────────────────────────────────────────────
func _build_dealer() -> void:
	var scn: PackedScene = load(DEALER)
	if scn == null:
		push_warning("딜러 씬이 없다: " + DEALER)
		return
	var n: Node3D = scn.instantiate()
	add_child(n)
	n.name = "Dealer"
	var ab := _box(n)
	if ab.size.y <= 0.0:
		return
	var k := DEALER_H / ab.size.y
	n.scale = Vector3.ONE * k
	n.rotation_degrees = Vector3(0.0, 0.0, 0.0)     # 이쪽을 본다(모델 정면이 +Z)
	# 테이블 건너편에 세운다. 발이 바닥(y=0)에 닿는다.
	n.position = Vector3(0.0, -ab.position.y * k, -0.62)
	var mis: Array[MeshInstance3D] = []
	_meshes(n, mis)
	for mi in mis:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tex: Texture2D = null
		var src := mi.get_active_material(0)
		if src is StandardMaterial3D:
			tex = (src as StandardMaterial3D).albedo_texture
		mi.material_override = _dot(tex)


# ── 매물 ─────────────────────────────────────────────
# 자리는 월드 좌표다. 상판 위에 나란히 눕히고, 살짝 세워 얼굴이 보이게 한다.
func _build_slots() -> void:
	var x0 := -SLOT_GAP * (float(SLOTS) - 1.0) * 0.5
	for i in SLOTS:
		var s := Node3D.new()
		s.name = "Slot%d" % i
		s.position = Vector3(x0 + SLOT_GAP * float(i), top_y, 0.10)
		add_child(s)

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = CARD
		mi.mesh = bm
		mi.position = Vector3(0.0, CARD.y * 0.5, 0.0)
		mi.rotation_degrees = Vector3(-14.0, 0.0, 0.0)   # 앞으로 살짝 눕힌다
		mi.material_override = _dot(null, Color(0.62, 0.58, 0.52))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.add_child(mi)

		# 레이캐스트가 집을 몸. 판정이 그림과 같은 상자라야 어긋나지 않는다.
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = CARD
		col.shape = sh
		body.add_child(col)
		body.position = mi.position
		body.rotation = mi.rotation
		body.set_meta("slot", i)
		s.add_child(body)
		slots.append(s)


# ── 카메라 ───────────────────────────────────────────
# 원근이다. 정사영으로 두면 옛 화면과 같은 평평함이 남는다 — 3D 로 바꾸는
# 이유가 깊이라, 그 깊이를 카메라가 만들어야 한다. 화각은 좁게(35°) 잡아
# 가장자리가 안 늘어나게 한다.
func _aim_camera() -> void:
	# 딜러 가슴께를 본다. 상판만 보면 사람이 화면 밖으로 잘린다.
	var look := Vector3(0.0, top_y + 0.30, -0.10)
	var e := deg_to_rad(22.0)
	cam.fov = 38.0
	cam.near = 0.05
	cam.far = 20.0
	cam.position = look + Vector3(0.0, sin(e), cos(e)) * 3.10
	cam.look_at(look, Vector3.UP)


# ── 집기 ─────────────────────────────────────────────
# 사다리꼴 안쪽 검사가 아니라 레이캐스트다. 자리가 옮겨져도 판정이 따라온다.
func _pick(m: Vector2) -> int:
	var from := cam.project_ray_origin(m)
	var to := from + cam.project_ray_normal(m) * 20.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return -1
	var c: Object = hit.get("collider")
	return int(c.get_meta("slot", -1)) if c != null and c.has_meta("slot") else -1


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var n := _pick((ev as InputEventMouseMotion).position)
		if n != hot:
			hot = n
			_light_slots()
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var n := _pick((ev as InputEventMouseButton).position)
		if n >= 0:
			print("샀다: 자리 ", n)


func _light_slots() -> void:
	for i in slots.size():
		var mi := slots[i].get_child(0) as MeshInstance3D
		var m := mi.material_override as ShaderMaterial
		if m != null:
			m.set_shader_parameter("tint",
					Color(0.98, 0.90, 0.62) if i == hot else Color(0.62, 0.58, 0.52))
		slots[i].position.y = top_y + (0.02 if i == hot else 0.0)
