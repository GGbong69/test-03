extends RefCounted

# ══════════════════════════════════════════════════════════
#  다트판 벽 — 상점 방의 다트판 앞에 선다 (2026-10-04)
#
#  「상점의 퀄리티가 너무 좋아 그래서 그런지 다트판 인게임 화면이랑 판 선택이
#   비교적으로 빈약한거 같아」. 고른 길:
#  「상점과 같은 3D 바 방을 다트판 정면으로 찍어 배경에 깝니다. 판자 벽, 판 둘레
#   검은 고무 링, 위 램프의 빛 웅덩이와 판 그림자, 양옆에 흐린 술병 선반과 네온이
#   들어갑니다. 왼쪽 다트 줄은 벽에 박은 놋쇠 꽂이에 걸립니다.」
#
#   · 재료는 상점 방(room3d.gd)의 그것이다 — 판자 · 선반과 밑불 · 술병 · 네온 ·
#     HIGHTON 간판 · 안개. 새 색을 안 만든다(Room3D.COL).
#   · 판은 판자 기둥(폭 PILLAR × 2)에 걸려 있고, 기둥 양옆 RECESS 뒤에 바 뒷벽
#     (선반 · 술병 · 네온)이 있다. 초점이 판에 있어 뒷벽은 흐리다(DOF) — 상점 방이
#     「멀수록 거칠고 흐린 것이 곧 깊이다」로 선 그 어법이다. 같은 벽에 붙은 것은
#     흐릴 수가 없어서(초점 거리가 같다) 기둥을 세웠다.
#   · 판은 3D 에 없다. 2D 판(game.gd _draw_board)이 그 자리에 앉는다 — 카메라 축이
#     판 한가운데(BC)를 지나고 판 평면(z 0)에서 1m = S 논리 px 다. 고무 링 안쪽
#     끝이 판 테(ro) 밑으로 1px 물리고, 링 안은 받침판이다 — 판이 없는 틈(판 갈이 ·
#     판 깨짐 · 정산)에는 판을 떼어 낸 받침판이 보인다.
#   · 램프는 판 왼쪽 위 앞, 화면 밖에 있다 — 2D 판이 이미 왼쪽 위에서 빛을 받는다
#     (_board_light). 빛 웅덩이가 판 둘레만 밝히고, 링 · 받침판 그림자가 오른쪽
#     아래로 떨어진다. 위(HUD 띠)와 기둥 가장자리는 가라앉는다.
#   · 움직이는 것이 없다 — 한 번 굽고 멈춘다(game.gd _wall3_tick). 창 여백 · 판
#     크기가 바뀔 때만 다시 굽는다. 그래서 네온도 안 깜박인다(상점 방의 숨은
#     매 틀 굽는 방이라 공짜였다).
#  ⚠ 헤드리스에서는 만들지 않는다(부르는 쪽이 _has_renderer 로 막는다).
# ══════════════════════════════════════════════════════════

const Room3D = preload("res://scripts/room3d.gd")

const S := 360.0          # 판 평면(z 0)에서 1m = 논리 px. 판 테 121.5px ≈ 0.34m — 상점 벽의 판(0.68m)과 같다
const EYE := 2.37         # 눈 — 던지는 줄에서 판까지(m). 실물 다트의 그 거리
const MARGIN := 14.0      # 흔들림 여유(논리 px) — 화면이 흔들려도(봉우리 12px) 가장자리가 안 비친다
const PILLAR := 0.56      # 기둥 반폭(m) — 화면 ±202px
const FACE := -0.04       # 기둥 앞면 z — 받침판 · 링이 4cm 나와 있다
const RECESS := 2.2       # 기둥 앞면에서 바 뒷벽까지(m) — 멀어야 술병이 작고 흐리고 안개에 가라앉는다
const RING := 16.0        # 고무 링 폭(논리 px) — 판 테 바깥으로
const PLANK := Color("3d281c")   # 기둥 판자 — 상점 벽(COL.wall)보다 한 단 밝다. 빛 웅덩이 밖은 그 벽으로 가라앉는다
#  왼쪽 꽂이 벽 — 놋쇠 다트 꽂이(game.gd _wall3_holder · x 1~12)가 박힌 판자 벽. 기둥과 같은
#  면(FACE)이라 초점 안이다. 화판 왼끝에서 이 논리 x 까지 — 넓은 창에서는 여백만큼 넓어진다.
#  「놋쇠 꽂이가 2.2m 뒤 흐린 바 앞 허공에 떠 있다」(검토, 2026-10-04) — 꽂이가 박힐 면이다.
const POST_X := 24.0
const POST_TEX := 256     # 꽂이 벽 판자 그림 폭(텍셀) — 넓은 창에서는 되풀어 깐다
const POST_D := 0.05      # 꽂이 벽 두께(m)
const RUBBER := Color("060607")
const BACKING := Color("1c130e")    # 받침판 — 판자보다 짙어 판이 뜬 자리가 빈자리로 읽힌다
#  빛의 세기 — 판이 화면에서 가장 밝고, 빛 웅덩이는 판 둘레까지, 뒷벽은 흐린 바.
const LOOK := {
	"lamp_e": 3.9,            # 램프 세기 — 판 둘레 판자가 판의 백색 칸보다 한참 어둡게
	"lamp_ang": 36.0,         # 램프 원뿔 반각(도)
	#  가장자리로 지는 굽이 — 엔진 식이 1 − rim^이 값이라 작을수록 한가운데부터 고루
	#  진다(웅덩이가 부드럽다). 1.8 은 안이 평평하다 끝에서 뚝 끊겨 둥근 스포트 판으로 읽혔다.
	"lamp_att": 1.0,
	#  램프 자리(판 기준 m) — 위 앞, 조금 왼쪽. 웅덩이가 판 한가운데보다 조금 위에 서고 아래로
	#  진다(검토 「빛 웅덩이가 안 읽힌다 — 가장 밝은 판자가 HUD 밑 · 안내 줄 뒤다」).
	"lamp_at": Vector3(-0.05, 1.02, 0.66),
	"lamp_to": Vector2(-0.03, 0.10),         # 램프가 겨누는 판 면 자리(m)
	"rub_rough": 0.5, "rub_spec": 0.3,       # 고무 링 재질 — 거칠기 · 반사
	"rub_round": 0.8,                        # 고무 관 단면 납작함(1 = 둥근 관) — 둥글수록 반짝임 줄이 가늘다
	"bottle_e": 0.14,         # 술병 빛(상점 방 0.25)
	"under_e": 1.0,           # 선반 밑불(상점 방 1.6)
	"shelf_l": 0.4,           # 선반 빛(상점 방 1.1)
	"neon": 0.55,             # 네온 짙기 곱(상점 방 1.0)
	"neon2": 1.3,             # 쪽빛 네온 잔
	"neon_l": 0.45,           # 네온이 벽에 뿌리는 빛
	#  네온 잔 자리(뒷벽 m) — 다트 줄(논리 y 120~300) 위, 금화판(y 52) 밑 빈 칸에 선다.
	#  y 0.36 이면 잔 대가 드는 다트 뒤에 걸려 고르는 자리가 어지러웠다(검토, 2026-10-04).
	"glass_at": Vector2(-1.40, 0.58),
	#  HIGHTON 세로 간판 — 뒷벽에서 이만큼 앞(m)에 매단다(선반 앞이라 술병에 안 가린다).
	#  일곱 글자가 HUD 단추 밑(논리 y ≈ 84~296)에 다 든다. 옛 자리는 위 두 글자가
	#  HUD 에 잘려 「G H T ?」 로 읽혔다(검토).
	"sign_at": Vector3(1.28, 0.02, 0.45),
	"sign_px": 0.0024,
	"shadow_blur": 1.0,       # 램프 그림자 번짐
	"shadow_size": 0.03,      # 램프 크기(m) — 그림자 반그늘 폭
	"shadow_a": 0.82,         # 그림자 짙기 — 1 이면 판 밑이 칠흑이다
	"post_l": 0.55,           # 꽂이 벽에 닿는 빛 — 램프 웅덩이 밖이라 그늘이지만 판자 결은 보인다
	#  빛 웅덩이(램프에 비추는 동그란 그러데이션) [반지름 몫, 밝기] — 판 둘레는 고루,
	#  링 바깥 한 뼘부터 기둥 가장자리 · 위로 진다.
	"pool": [[0.0, 1.0], [0.30, 0.95], [0.55, 0.55], [0.80, 0.16], [1.0, 0.0]],
	"holes": 46,              # 링 바깥 판자의 빗나간 촉 구멍 수
}


static func _cam(vp: SubViewport) -> Camera3D:
	return vp.get_node_or_null("Wall/Cam") as Camera3D


# ══ 만들기 ═══════════════════════════════════════════════════
static func make_wall(host: Node) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = "Wall3"
	vp.size = Vector2i(16, 16)          # wall_fit 이 곧장 잡는다
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.gui_disable_input = true
	#  판 그림자 결 — 기본 2048 아틀라스에서는 램프 하나의 그림자 가장자리가 거칠게 씹혔다.
	#  한 번 굽고 멈추는 화판이라 값이 싸다.
	vp.positional_shadow_atlas_size = 4096
	host.add_child(vp)

	var root := Node3D.new()
	root.name = "Wall"
	vp.add_child(root)

	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.near = 0.05
	cam.far = 30.0
	cam.position = Vector3(0.0, 0.0, EYE)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	#  초점은 판 — 뒷벽(선반 · 술병 · 네온)이 흐리다. 기둥 앞면 바로 뒤에서 흐려지기 시작한다.
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_distance = EYE + 0.22
	ca.dof_blur_far_transition = 0.55
	ca.dof_blur_amount = 0.16
	cam.attributes = ca
	root.add_child(cam)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07050a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("2a2030")
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	#  안개 — 뒷벽만 먹는다(깊이 안개는 기둥 앞면 뒤에서 시작한다).
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("140e16")
	env.fog_density = 1.0
	env.fog_depth_begin = EYE + 0.3
	env.fog_depth_end = EYE + 3.2
	env.fog_depth_curve = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	#  번짐(bloom)은 끈다 — 밝은 판자가 고무 링 위로 번져 링이 갈색으로 떴다. 네온 · 밑불만 빛난다.
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	we.environment = env
	root.add_child(we)

	_pillar(root)
	_post(root)
	_back(root)
	_board_mount(root)
	_lamp(root)
	return vp


#  창 여백 · 판 크기에 맞춘다. 화판의 한가운데가 판 한가운데(bc)에 앉고, 화판이
#  여백 + MARGIN 까지 덮는다(아래로는 bc 가 화면 가운데보다 낮은 몫만큼 화면 밖이다).
#  ro — 판 테 반지름(논리 px). 바뀌면 링과 받침판이 따라간다.
#  k — 굽는 배율(논리 1px = 화판 k px). 창 배율 그대로 받는다(비정수 — 1366 창 2.13).
#  화판 한 텍셀이 화면 한 픽셀이라 판자 결 · 링 가장자리가 늘거나 겹치는 줄 없이 선다.
#  옛 판은 배율을 반올림해(2.13 → 2) 열다섯 줄마다 한 줄이 두 번 찍혔고, 흔들림에 결이
#  일렁였다(검토, 2026-10-04). 화판 크기는 짝수로 올린다 — 한가운데가 텍셀 경계에 선다.
#  돌려주는 값은 화판 크기(px). 덮는 논리 크기는 그 / k 다(logical_size 보다 1px 남짓 크다).
static func wall_fit(vp: SubViewport, pad: Vector2, ro: float, bc: Vector2, k: float) -> Vector2i:
	var px := bake_px(pad, bc, k)
	vp.size = px
	var ls := Vector2(px) / k
	var cam := _cam(vp)
	if cam != null:
		cam.fov = rad_to_deg(2.0 * atan(ls.y * 0.5 / S / EYE))
	var root := vp.get_node_or_null("Wall")
	if root == null:
		return px
	_post_fit(root, bc.x - ls.x * 0.5, bc.x)
	var ring: MeshInstance3D = root.get_node_or_null("Ring")
	if ring != null:
		var tm := ring.mesh as TorusMesh
		tm.inner_radius = (ro - 1.0) / S
		tm.outer_radius = (ro + RING) / S
	var bk: MeshInstance3D = root.get_node_or_null("Backing")
	if bk != null:
		var cm := bk.mesh as CylinderMesh
		cm.top_radius = (ro + 3.0) / S
		cm.bottom_radius = (ro + 3.0) / S
	return px


#  화판이 덮어야 하는 논리 크기 — 가운데가 bc 다.
static func logical_size(pad: Vector2, bc: Vector2) -> Vector2:
	return Vector2((bc.x + pad.x + MARGIN) * 2.0, (bc.y + pad.y + MARGIN) * 2.0)


#  그 크기를 배율 k 로 구운 화판 크기(px) — 짝수로 올린다.
static func bake_px(pad: Vector2, bc: Vector2, k: float) -> Vector2i:
	var ls := logical_size(pad, bc)
	return Vector2i(int(ceilf(ls.x * k * 0.5)) * 2, int(ceilf(ls.y * k * 0.5)) * 2)


# ── 기둥 — 세로 판자 · 니스 안 친 거친 결 ─────────────────
static func _pillar(root: Node3D) -> void:
	var w: float = PILLAR * 2.0
	var y0 := -0.9
	var y1 := 1.0
	#  판자는 1 텍셀 = 판 평면 논리 1px 로 굽는다(상점 카운터와 같은 결의 크기).
	#  _plank 는 누운 판을 짓는다 — 90° 돌려 세운다.
	var pair: Array = Room3D._plank(int((y1 - y0) * S), int(w * S), PLANK, 20261004, 40, 52)
	var im: Image = pair[0]
	im.rotate_90(CLOCKWISE)
	#  빗나간 자국 — 링 바깥 판자에 박혔다 뽑힌 촉 구멍. 링 가까이 촘촘하고 멀수록 성기다.
	#  텍셀 (u, v) = 판 평면 논리 px 라 판 한가운데가 (PILLAR · S, y1 · S) 다.
	var hr := RandomNumberGenerator.new()
	hr.seed = 1004
	var c0 := Vector2(PILLAR * S, y1 * S)
	for _k in int(LOOK.holes):
		var a: float = hr.randf_range(0.0, TAU)
		var rr: float = RING + 124.0 + absf(hr.randfn(0.0, 26.0))
		var hp := Vector2i((c0 + Vector2(cos(a), sin(a)) * rr).floor())
		if hp.x < 1 or hp.y < 1 or hp.x >= im.get_width() - 1 or hp.y >= im.get_height() - 1:
			continue
		var base := im.get_pixelv(hp)
		im.set_pixelv(hp, base.darkened(0.7))
		im.set_pixelv(hp + Vector2i(1, 1), base.lightened(0.12))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(im)
	m.roughness = 0.82
	m.metallic_specular = 0.35
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var qm := QuadMesh.new()
	qm.size = Vector2(w, y1 - y0)
	var q := MeshInstance3D.new()
	q.name = "Pillar"
	q.mesh = qm
	q.material_override = m
	q.position = Vector3(0.0, (y0 + y1) * 0.5, FACE)
	root.add_child(q)
	#  몸 — 앞면 뒤를 막아 뒷벽 빛이 새지 않게 하고 그림자를 받는다.
	root.add_child(Room3D._box(Vector3(w, y1 - y0, 0.4), Vector3(0.0, (y0 + y1) * 0.5, FACE - 0.201),
			Room3D._mat(Room3D.COL.wood_dk)))
	#  모서리 — 짙은 테 한 줄(그늘 쪽 오른편이 더 짙다) · 왼편은 빛 받은 한 줄.
	for sx in [-1.0, 1.0]:
		var e: float = float(sx) * (PILLAR - 0.006)
		root.add_child(Room3D._box(Vector3(0.012, y1 - y0, 0.02), Vector3(e, (y0 + y1) * 0.5, FACE + 0.004),
				Room3D._mat(Room3D.COL.wood_dk.darkened(0.3 if sx > 0.0 else 0.0))))
	root.add_child(Room3D._box(Vector3(0.004, y1 - y0, 0.02), Vector3(-PILLAR + 0.014, (y0 + y1) * 0.5, FACE + 0.006),
			Room3D._mat(Room3D.COL.trim, 0.6)))


# ── 꽂이 벽 — 왼쪽 가장자리의 판자 벽 · 놋쇠 다트 꽂이가 박힌 면 ──
#  기둥과 같은 판자 · 같은 면(FACE)이라 초점 안이고, 둘 사이로 흐린 바가 보인다. 자리와
#  폭은 _post_fit 이 화판 왼끝에서 POST_X 까지 잡는다. 판자 그림은 POST_TEX 폭으로 한 장
#  굽고 넓은 창에서는 되풀어 깐다(오른끝 이음 자리는 창 폭과 무관하게 같다).
static func _post(root: Node3D) -> void:
	var y0 := -0.9
	var y1 := 1.0
	var pair: Array = Room3D._plank(int((y1 - y0) * S), POST_TEX, PLANK.darkened(0.12), 20261005, 40, 52)
	var im: Image = pair[0]
	im.rotate_90(CLOCKWISE)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(im)
	m.roughness = 0.85
	m.metallic_specular = 0.3
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.texture_repeat = true
	var qm := QuadMesh.new()
	qm.size = Vector2(0.1, y1 - y0)
	var q := MeshInstance3D.new()
	q.name = "Post"
	q.mesh = qm
	q.material_override = m
	q.position = Vector3(-1.0, (y0 + y1) * 0.5, FACE)
	root.add_child(q)
	#  몸 — 얇은 판벽이다. 카메라 왼쪽에 서서 오른 옆면이 보이는데, 기둥만큼(40cm) 두꺼우면
	#  그 옆면이 꽂이 오른쪽에 검은 띠(논리 24~68px)로 서서 바와 네온 잔을 가렸다.
	var body := Room3D._box(Vector3(0.1, y1 - y0, POST_D), Vector3(-1.0, (y0 + y1) * 0.5, FACE - POST_D * 0.5 - 0.001),
			Room3D._mat(Room3D.COL.wood))
	body.name = "PostBody"
	root.add_child(body)
	#  오른 모서리 — 짙은 테 한 줄과 그 안쪽 빛 받은 한 줄(기둥 모서리와 같은 어법).
	var ed := Room3D._box(Vector3(0.012, y1 - y0, 0.02), Vector3(-1.0, (y0 + y1) * 0.5, FACE + 0.004),
			Room3D._mat(Room3D.COL.wood_dk.darkened(0.3)))
	ed.name = "PostEdge"
	root.add_child(ed)
	var hi := Room3D._box(Vector3(0.004, y1 - y0, 0.02), Vector3(-1.0, (y0 + y1) * 0.5, FACE + 0.006),
			Room3D._mat(Room3D.COL.trim, 0.6))
	hi.name = "PostLit"
	root.add_child(hi)
	#  빛 — 램프 웅덩이 밖이라 그늘이다. 위에서 옅게 스치는 빛 하나로 판자 결만 살린다.
	var ol := OmniLight3D.new()
	ol.name = "PostLamp"
	ol.light_color = Room3D.COL.lamp
	ol.light_energy = float(LOOK.post_l)
	ol.omni_range = 1.1
	ol.omni_attenuation = 1.4
	ol.position = Vector3(-1.0, 0.55, 0.35)
	root.add_child(ol)


#  꽂이 벽을 화판 왼끝(논리 x lx0)에서 POST_X 까지 맞춘다. 기둥 앞면(FACE)에서 논리 1px 이
#  몇 m 인가는 판 평면(z 0)과 조금 다르다 — 원근이라 4cm 뒤가 그만큼 작다.
static func _post_fit(root: Node, lx0: float, bcx: float) -> void:
	var q: MeshInstance3D = root.get_node_or_null("Post")
	if q == null:
		return
	var ppm: float = S * EYE / (EYE - FACE)          # FACE 면에서 1m = 논리 px
	var xa: float = (lx0 - 2.0 - bcx) / ppm
	var xb: float = (POST_X - bcx) / ppm
	var w: float = xb - xa
	var cx: float = (xa + xb) * 0.5
	(q.mesh as QuadMesh).size.x = w
	q.position.x = cx
	var m := q.material_override as StandardMaterial3D
	var k: float = w * ppm / float(POST_TEX)
	m.uv1_scale = Vector3(k, 1.0, 1.0)
	m.uv1_offset = Vector3(1.0 - k, 0.0, 0.0)     # 오른끝이 늘 그림의 오른끝이다
	var body: MeshInstance3D = root.get_node_or_null("PostBody")
	if body != null:
		(body.mesh as BoxMesh).size.x = w
		body.position.x = cx
	var ed: MeshInstance3D = root.get_node_or_null("PostEdge")
	if ed != null:
		ed.position.x = xb - 0.006
	var hi: MeshInstance3D = root.get_node_or_null("PostLit")
	if hi != null:
		hi.position.x = xb - 0.017
	var ol: OmniLight3D = root.get_node_or_null("PostLamp")
	if ol != null:
		ol.position.x = xb + 0.08          # 모서리 바로 오른쪽 앞 — 옆면 · 판자 결을 스친다


# ── 바 뒷벽 — 판자 · 선반 · 술병 · 밑불 · 네온 (상점 방 그대로) ──
#  기둥 너머 RECESS 뒤라 판 평면의 반 남짓으로 작게 서고, 초점 밖이라 흐리고, 깊이
#  안개에 가라앉는다. 빛나는 것(술병 · 밑불 · 네온)은 상점 방보다 한참 낮춘다 — 판이
#  화면에서 가장 밝아야 한다(LOOK).
static func _back(root: Node3D) -> void:
	var zb: float = FACE - RECESS
	var wall := Room3D._mat(Room3D.COL.wall, 0.9)
	root.add_child(Room3D._box(Vector3(12.0, 5.0, 0.2), Vector3(0.0, 0.3, zb - 0.1), wall))
	for k in range(-20, 21):
		root.add_child(Room3D._box(Vector3(0.03, 5.0, 0.02), Vector3(float(k) * 0.32, 0.3, zb + 0.005),
				Room3D._mat(Room3D.COL.wall.darkened(0.35))))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261004
	#  선반 [쪽, 높이, 안쪽 끝 |x|] — 왼쪽 위는 네온 잔, 오른쪽 위는 HIGHTON 간판 자리.
	var rows := [[-1.0, -0.86, 0.9], [-1.0, -0.30, 0.9], [-1.0, 0.82, 0.9],
			[1.0, -0.86, 0.9], [1.0, -0.30, 0.9], [1.0, 0.82, 1.75]]
	for rw in rows:
		_shelf(root, float(rw[0]), float(rw[1]), float(rw[2]), zb, rng)
	#  HIGHTON 간판 — 상점 방의 그 네온(분홍). 기둥 오른편 뒷벽에 세로로 선다.
	var nk: float = float(LOOK.neon)
	var neon := Label3D.new()
	neon.text = "H
I
G
H
T
O
N"
	neon.font_size = 64
	neon.pixel_size = float(LOOK.sign_px)
	neon.line_spacing = -18.0
	neon.modulate = Color(2.4 * nk, 0.55 * nk, 0.85 * nk)
	neon.outline_size = 0
	neon.shaded = false
	var sa: Vector3 = LOOK.sign_at
	neon.position = Vector3(sa.x, sa.y, zb + sa.z)
	root.add_child(neon)
	var nl := OmniLight3D.new()
	nl.light_color = Room3D.COL.neon
	nl.light_energy = float(LOOK.neon_l)
	nl.omni_range = 1.4
	nl.position = Vector3(sa.x, sa.y, zb + sa.z + 0.3)
	root.add_child(nl)
	#  왼편 위 — 쪽빛 네온 잔(술잔 꼴 관). 상점 방의 둘째 네온 색.
	var gm := Room3D._glow(Room3D.COL.neon2, float(LOOK.neon2))
	var ga: Vector2 = LOOK.glass_at
	var gx: float = ga.x
	var gy: float = ga.y
	var gz: float = zb + 0.03
	for sd in [-1.0, 1.0]:
		var bar := Room3D._box(Vector3(0.016, 0.17, 0.016), Vector3(gx + float(sd) * 0.055, gy + 0.09, gz), gm)
		bar.rotation_degrees = Vector3(0.0, 0.0, -float(sd) * 33.0)
		root.add_child(bar)
	root.add_child(Room3D._box(Vector3(0.23, 0.016, 0.016), Vector3(gx, gy + 0.16, gz), gm))
	root.add_child(Room3D._box(Vector3(0.016, 0.12, 0.016), Vector3(gx, gy - 0.04, gz), gm))
	root.add_child(Room3D._box(Vector3(0.11, 0.016, 0.016), Vector3(gx, gy - 0.10, gz), gm))
	var gl := OmniLight3D.new()
	gl.light_color = Room3D.COL.neon2
	gl.light_energy = float(LOOK.neon_l) * 0.7
	gl.omni_range = 1.1
	gl.position = Vector3(gx, gy + 0.05, zb + 0.3)
	root.add_child(gl)


#  선반 한 줄 — 쪽(sd −1 왼 · +1 오른) · 높이 y · 안쪽 끝 |x| = x0 에서 바깥으로.
static func _shelf(root: Node3D, sd: float, y: float, x0: float, zb: float,
		rng: RandomNumberGenerator) -> void:
	var x1 := 3.6
	var cx: float = sd * (x0 + x1) * 0.5
	var ln: float = x1 - x0
	root.add_child(Room3D._box(Vector3(ln, 0.04, 0.3), Vector3(cx, y, zb + 0.15),
			Room3D._mat(Room3D.COL.shelf, 0.6)))
	#  선반 밑불 — 술병을 밑에서 비춘다
	root.add_child(Room3D._box(Vector3(ln - 0.1, 0.01, 0.02), Vector3(cx, y - 0.025, zb + 0.28),
			Room3D._glow(Room3D.COL.lamp, float(LOOK.under_e))))
	for lx in [x0 + 0.5, x0 + 1.6]:
		var ol := OmniLight3D.new()
		ol.light_color = Room3D.COL.lamp
		ol.light_energy = float(LOOK.shelf_l)
		ol.omni_range = 0.9
		ol.position = Vector3(sd * float(lx), y + 0.14, zb + 0.32)
		root.add_child(ol)
	var cols := [Color("b5651d"), Color("2f6b3a"), Color("8fb8d8"), Color("7a1f2b"),
			Color("d4a017"), Color("3b2b6b")]
	var x := x0 + 0.04
	while x < x1 - 0.05:
		var bh: float = rng.randf_range(0.22, 0.34)
		var br: float = rng.randf_range(0.04, 0.065)
		var bc: Color = cols[rng.randi() % cols.size()]
		var gm := Room3D._mat(bc, 0.15, 0.0)
		gm.emission_enabled = true
		gm.emission = bc
		gm.emission_energy_multiplier = float(LOOK.bottle_e)
		var px: float = sd * (x + br)
		root.add_child(Room3D._cyl(br, br, bh, Vector3(px, y + 0.02 + bh * 0.5, zb + 0.14), gm, 10))
		root.add_child(Room3D._cyl(br * 0.35, br * 0.4, 0.09, Vector3(px, y + 0.02 + bh + 0.045, zb + 0.14), gm, 8))
		x += br * 2.0 + rng.randf_range(0.03, 0.12)


# ── 판 자리 — 고무 링 · 받침판 · 걸쇠 ─────────────────────
#  치수는 wall_fit 이 판 테(ro)에서 잡는다. 여기서는 모양과 재질만.
static func _board_mount(root: Node3D) -> void:
	#  받침판 — 판을 떼어 내면 보이는 자리. 짙은 섬유판에 걸쇠 하나 · 나사 셋.
	var bm := Room3D._mat(BACKING, 0.95)
	bm.albedo_texture = Room3D._noise_tex(0.09, 0.55, 1.0, 31)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.34
	cm.bottom_radius = 0.34
	cm.height = 0.04
	cm.radial_segments = 64
	cm.rings = 1
	var bk := MeshInstance3D.new()
	bk.name = "Backing"
	bk.mesh = cm
	bk.material_override = bm
	bk.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	bk.position = Vector3(0.0, 0.0, FACE + 0.02)
	root.add_child(bk)
	var hook := Room3D._cyl(0.034, 0.034, 0.012, Vector3(0.0, 0.0, 0.004),
			Room3D._mat(Room3D.COL.brass.darkened(0.62), 0.6, 0.35), 20)
	hook.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	root.add_child(hook)
	for k in 3:
		var a: float = TAU * float(k) / 3.0 - PI * 0.5
		var sc := Room3D._cyl(0.008, 0.008, 0.006, Vector3(cos(a) * 0.024, -sin(a) * 0.024, 0.011),
				Room3D._mat(Color("1a1410"), 0.5, 0.5), 8)
		sc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		root.add_child(sc)
	#  고무 링 — 판 테를 두르는 검은 고무. 눌러 납작한 관이라 위쪽이 램프를 받는다.
	#  고무는 무채색 검정이다 — 거칠면 램프의 호박빛을 넓게 받아 갈색 테로 떴다(검토).
	#  반들거리게 하면 놋쇠 테로 읽혀(0.42 · 0.6) 그 사이 — 위쪽에 좁은 반짝임 한 줄만 받는다.
	var rm := Room3D._mat(RUBBER, float(LOOK.rub_rough))
	rm.metallic_specular = float(LOOK.rub_spec)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.33
	tm.outer_radius = 0.38
	tm.rings = 96
	tm.ring_segments = 12
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = tm
	ring.material_override = rm
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	ring.scale = Vector3(1.0, float(LOOK.rub_round), 1.0)
	ring.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(ring)


# ── 램프 — 판 왼쪽 위 앞(화면 밖) · 빛 웅덩이와 판 그림자 ──
static func _lamp(root: Node3D) -> void:
	var sl := SpotLight3D.new()
	sl.name = "Lamp"
	sl.light_color = Room3D.COL.lamp
	sl.light_energy = float(LOOK.lamp_e)
	sl.spot_range = 4.0
	sl.spot_attenuation = 0.6
	sl.spot_angle = float(LOOK.lamp_ang)
	sl.spot_angle_attenuation = float(LOOK.lamp_att)
	sl.shadow_enabled = true
	#  그림자 — 가장자리 번짐(blur 2 · 크기 0.06)이 넓으면 PCF 결이 오돌토돌 씹히고 판이
	#  검은 구덩이에 빠진 것처럼 읽혔다(검토). 좁게 번지고 바닥까지 검지 않게.
	sl.shadow_blur = float(LOOK.shadow_blur)
	sl.light_size = float(LOOK.shadow_size)
	sl.shadow_opacity = float(LOOK.shadow_a)
	#  빛 웅덩이의 꼴 — 원뿔 감쇠만으로는 판자 기둥이 끝까지 고루 밝았다(위로 갈수록 빛을
	#  정면으로 받아 감쇠를 되갚는다). 동그란 그러데이션을 램프에 비춰 판 둘레만 밝힌다.
	sl.light_projector = _pool_tex()
	var at: Vector3 = LOOK.lamp_at
	var lt: Vector2 = LOOK.lamp_to
	var tgt := Vector3(lt.x, lt.y, FACE)
	sl.transform = Transform3D(Basis.looking_at(tgt - at, Vector3.UP), at)
	root.add_child(sl)


#  램프가 비추는 그림 — 한가운데 흰빛에서 가장자리 어둠으로. 점은 LOOK.pool [자리, 밝기].
static func _pool_tex() -> GradientTexture2D:
	var g := Gradient.new()
	var pts: Array = LOOK.pool
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for p in pts:
		var v: float = float(p[1])
		g.add_point(float(p[0]), Color(v, v, v))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	return gt
