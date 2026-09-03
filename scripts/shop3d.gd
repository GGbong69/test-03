@tool
extends Node3D

# 상점 — 진짜 3D 로 다시 짠다.
#
# 옛 상점은 손으로 계산한 정사영이었다. 테이블은 52° 로 내려다보고 상인는
# 정면에서 본 것처럼 그리는, 투영 둘을 섞은 그림이다. 카메라 하나로는
# 못 하는 거짓말이라 3D 로 옮기는 순간 어긋난다. 그래서 옮기지 않고 새로 짠다.
#
# 규칙 셋.
#   1. 자리는 월드 좌표다. 화면 px 를 좌표로 쓰지 않는다.
#   2. 집는 판정은 레이캐스트다. 사다리꼴 안쪽 검사가 아니다.
#   3. 화면은 640x360 · nearest 그대로다. 도트는 해상도가 만든다.
#
# **물건은 씬에 노드로 있다.** 코드가 만들지 않는다 — 에디터에서 골라
# 옮기고 돌릴 수 있어야 한다. 이 스크립트가 하는 일은 셋뿐이다:
# 카메라 겨누기, 상인에 도트 재질 입히기, 집기 판정.
#
# 단위는 미터다. 테이블 폭 1.9m, 상인 키 1.7m — 실물 크기라야 카메라
# 화각과 조명이 상식대로 먹는다.

const DOT := "res://scripts/shaders/dot.gdshader"

# 에디터에서 그대로 만진다. 값을 바꾸면 다음 프레임에 카메라가 따라온다.
@export_group("카메라")
@export var aim_camera := true                          # 끄면 Cam 을 손으로 놓는다
@export_range(15.0, 80.0, 0.5) var cam_fov := 42.0
@export_range(2.0, 70.0, 0.5) var cam_elev := 17.0      # 앙각(도)
@export_range(0.4, 6.0, 0.01) var cam_dist := 1.46      # 거리(m)
@export_range(-1.0, 2.0, 0.01) var cam_look_y := 1.02   # 바라보는 높이(m)
@export_range(-1.5, 1.5, 0.01) var cam_look_z := -0.16

@export_group("도트")
@export_range(2, 8, 1) var light_bands := 4
@export_range(2, 32, 1) var color_steps := 12

@onready var cam: Camera3D = $Cam
@onready var slots_root: Node3D = $Slots

var hot := -1


func _ready() -> void:
	_skin("Dealer")
	_skin("Table")      # 원본 glb 라 임포터 재질이 붙어 있다
	_aim()


# 상인는 glb 인스턴스라 임포터가 붙인 재질을 쓴다. 도트 셰이더로 갈아
# 끼우되 텍스처는 그대로 물려준다 — 조끼·장갑 색이 거기 있다.
func _skin(who: String) -> void:
	var npc := get_node_or_null(who)
	if npc == null:
		return
	var mis: Array[MeshInstance3D] = []
	_meshes(npc, mis)
	for mi in mis:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.material_override != null:
			continue
		var tex: Texture2D = null
		var src := mi.get_active_material(0)
		if src is StandardMaterial3D:
			tex = (src as StandardMaterial3D).albedo_texture
		var m := ShaderMaterial.new()
		m.shader = load(DOT)
		if tex != null:
			m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("tint", Color.WHITE)
		m.set_shader_parameter("light_bands", light_bands)
		m.set_shader_parameter("color_steps", color_steps)
		mi.material_override = m


func _meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		_meshes(c, out)


# ── 카메라 ───────────────────────────────────────────
# 옛 2D 상점의 구도다 — 테이블이 화면을 좌우로 넘치고 상인는 상반신만
# 위에 걸린다. 넘치게 하려면 카메라가 가까워야 한다: 화각 42°·16:9 에서
# 가로 시야가 거리의 약 1.4 배라, 1.9m 테이블을 넘기려면 1.5m 안쪽이다.
func _aim() -> void:
	if cam == null or not aim_camera:
		return
	var look := Vector3(0.0, cam_look_y, cam_look_z)
	var e := deg_to_rad(cam_elev)
	cam.fov = cam_fov
	cam.position = look + Vector3(0.0, sin(e), cos(e)) * cam_dist
	cam.look_at(look, Vector3.UP)


func _process(_d: float) -> void:
	if Engine.is_editor_hint():
		_aim()


# ── 집기 ─────────────────────────────────────────────
# 사다리꼴 안쪽 검사가 아니라 레이캐스트다. 자리를 에디터에서 옮겨도
# 판정이 따라온다 — 그림과 몸이 같은 노드에 붙어 있기 때문이다.
func _pick(m: Vector2) -> int:
	if cam == null or slots_root == null:
		return -1
	var from := cam.project_ray_origin(m)
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(m) * 20.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return -1
	var n: Node = hit.get("collider") as Node
	while n != null and n.get_parent() != slots_root:
		n = n.get_parent()
	return slots_root.get_children().find(n) if n != null else -1


func _unhandled_input(ev: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if ev is InputEventMouseMotion:
		var n := _pick((ev as InputEventMouseMotion).position)
		if n != hot:
			hot = n
			_light()
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var n := _pick((ev as InputEventMouseButton).position)
		if n >= 0:
			print("샀다: 자리 ", n)


# 재질은 씬이 공유한다. 한 자리만 밝히려면 그 자리 것을 떼어 내야 한다.
func _light() -> void:
	var kids := slots_root.get_children()
	for i in kids.size():
		var mi := kids[i] as MeshInstance3D
		if mi == null:
			continue
		var m := mi.material_override as ShaderMaterial
		if m == null:
			continue
		if not m.resource_local_to_scene:
			m = m.duplicate() as ShaderMaterial
			m.resource_local_to_scene = true
			mi.material_override = m
		m.set_shader_parameter("tint",
				Color(0.98, 0.90, 0.62) if i == hot else Color(0.62, 0.58, 0.52))
