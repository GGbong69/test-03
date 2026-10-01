extends RefCounted

# ══════════════════════════════════════════════════════════
#  지하 카지노 바 — 3D 방과 3D 테이블 (2026-10-01 · 맛보기)
#
#  「다 별론데… 배경 화면이 없어서 그런가… 공간감을 줄 수 있으면 좋겠다…
#   약간 3D 게임 같이」. 무늬만 바꾼 시안 셋이 다 평면이었다 — 공간감은
#  무늬가 아니라 **방**에서 난다. 그래서 두 장을 3D 로 굽는다.
#
#   · 방(상인 뒤) — **원근** 카메라. 벽 판자 · 선반의 술병과 밑불 · 네온 ·
#     벽의 다트판 · 늘어뜨린 램프 둘 · 안개. 320×180 으로 거칠게 구워 두
#     배로 붙인다 — 멀수록 거칠고 흐린 것이 곧 깊이다.
#     (빛줄기 원뿔과 양옆 슬롯머신은 찍어 보니 천막 · UI 막대로 읽혀 걷었다.)
#   · 테이블 — **직교** 카메라 −52°. 상인 손(_stage3_make)과 같은 식이라
#     3D 한 칸이 화면 1px 이고, 면 좌표 (u, h, w) 가 _p2s 그대로 화면에
#     떨어진다. 물건(2D)이 그 위에 정확히 앉는다. 골동품 상인의 진열대 —
#     포도주빛 벨벳 · 조각 나무 틀과 놋쇠 모서리 갓 · 양 끝 소품(판매 저울 ·
#     구매 금전등록기와 종) · 둥근 난간 · 판넬 앞판, 램프의 빛 웅덩이와 그림자.
#
#  ⚠ 셰이더 시계를 안 쓴다 — tick() 이 받는 t 는 게임 시간이라 모션
#  끄기에서 멈춘다. 헤드리스에서는 만들지 않는다(부르는 쪽이 막는다).
# ══════════════════════════════════════════════════════════

const ROOM_PX := Vector2i(320, 180)     # 방은 반 해상도 — 두 배로 붙인다

#  색 — 방은 어둡고 따뜻하게, 빛나는 것만 채도를 쓴다.
const COL := {
	"wall": Color("2a1d17"),
	"wall2": Color("33241c"),
	"trim": Color("6b4a2c"),
	"shelf": Color("4a3322"),
	"ceil": Color("120c0b"),
	"felt": Color("1f5a43"),
	"felt_dk": Color("163f30"),
	"leather": Color("5a2422"),
	"wood": Color("4a2f1f"),
	"wood_dk": Color("2c1c13"),
	"brass": Color("c89a4a"),
	"lamp": Color("ffcf8a"),
	"neon": Color("ff5a7a"),
	"neon2": Color("62e0ff"),
	#  진열대(시안 Q) — 포도주빛 벨벳 · 짙은 조각 나무 · 청동 몸통 · 상아 건반
	"velvet": Color("64182b"),
	"carve": Color("26150d"),
	"oak": Color("3b2416"),
	"bronze": Color("8c5e2e"),
	"ivory": Color("e8dcbe"),
	"glass": Color("120e10"),
}


static func _mat(col: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


static func _glow(col: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


#  빛줄기 — 램프 밑 원뿔. 더하기로 얹는 아주 옅은 막이다.
static func _beam(col: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col, a)
	m.no_depth_test = false
	return m


#  결 — 잡음 무늬를 재질에 얹는다(펠트 털 · 나뭇결). 잡음은 비동기로 구워진다.
static func _noise_tex(freq: float, sx: float, sy: float, seed: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	t.color_ramp = Gradient.new()
	t.color_ramp.set_color(0, Color(sx, sx, sx))
	t.color_ramp.set_color(1, Color(sy, sy, sy))
	return t


static func _box(sz: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = sz
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	return mi


static func _cyl(r0: float, r1: float, h: float, at: Vector3, m: Material, seg := 12) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r0
	cm.bottom_radius = r1
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	mi.position = at
	return mi


#  벽에 거는 다트판 — 칸 스물 · 백색·흑색 칸 · 주홍·쪽빛 띠를 작은 그림으로 굽는다.
static func _board_tex() -> ImageTexture:
	var n := 64
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n * 0.5, n * 0.5)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5) - c
			var r := d.length() / (n * 0.5)
			var a := fposmod(atan2(d.x, -d.y) + PI / 20.0, TAU)
			var sec := int(a / (TAU / 20.0))
			var col := Color(0, 0, 0, 0)
			if r <= 1.0:
				col = Color("1a1714")                    # 숫자 고리
			if r <= 0.80:
				col = Color("e9dfc6") if sec % 2 == 0 else Color("1b1918")
				if (r > 0.72 and r <= 0.80) or (r > 0.44 and r <= 0.50):
					col = Color("c8442f") if sec % 2 == 0 else Color("2e5a8c")
			if r <= 0.10:
				col = Color("2e5a8c")
			if r <= 0.05:
				col = Color("c8442f")
			im.set_pixel(x, y, col)
	return ImageTexture.create_from_image(im)


# ══ 방 ══════════════════════════════════════════════════════
static func make_room(host: Node) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = ROOM_PX
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.gui_disable_input = true
	host.add_child(vp)

	var root := Node3D.new()
	root.name = "Room"
	vp.add_child(root)

	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.fov = 50.0
	cam.near = 0.05
	cam.far = 40.0
	#  선반(높이 1.4~2.3)이 화면 위 12~30% — HUD 밑과 테이블 먼 턱 사이의 띠에
	#  오도록 아래로 12° 기울인다. 그 띠가 방이 보이는 유일한 창이다.
	cam.position = Vector3(0.0, 1.5, 3.6)
	cam.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	root.add_child(cam)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07050a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("2a2030")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("1d1420")
	env.fog_density = 0.06
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	we.environment = env
	root.add_child(we)

	# ── 벽 · 천장 · 바닥 ──
	var wall := _mat(COL.wall, 0.9)
	wall.albedo_texture = _noise_tex(0.02, 0.75, 1.0, 11)
	wall.uv1_scale = Vector3(6.0, 1.0, 1.0)
	root.add_child(_box(Vector3(14.0, 5.0, 0.2), Vector3(0.0, 2.0, -2.6), wall))
	#  판자 이음 — 세로 줄을 몇 줄 앞에 세운다.
	for k in range(-12, 13):
		root.add_child(_box(Vector3(0.025, 5.0, 0.02), Vector3(float(k) * 0.55, 2.0, -2.49),
				_mat(COL.wall.darkened(0.35))))
	#  허리 몰딩
	root.add_child(_box(Vector3(14.0, 0.08, 0.06), Vector3(0.0, 0.95, -2.46), _mat(COL.trim, 0.5)))
	root.add_child(_box(Vector3(14.0, 0.2, 8.0), Vector3(0.0, 3.4, 0.0), _mat(COL.ceil)))
	# 천장 들보
	for k in range(-3, 4):
		root.add_child(_box(Vector3(0.18, 0.16, 6.0), Vector3(float(k) * 1.6, 3.15, 0.0), _mat(COL.wood_dk)))
	root.add_child(_box(Vector3(14.0, 0.2, 8.0), Vector3(0.0, -0.1, 0.0), _mat(Color("140d0b"))))

	# ── 뒤 선반과 술병 ──
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261001
	var bottle_cols := [Color("b5651d"), Color("2f6b3a"), Color("8fb8d8"), Color("7a1f2b"),
			Color("d4a017"), Color("3b2b6b")]
	for s in 3:
		var sy: float = 1.15 + float(s) * 0.48
		root.add_child(_box(Vector3(4.6, 0.05, 0.34), Vector3(0.0, sy, -2.3), _mat(COL.shelf, 0.6)))
		#  선반 밑불 — 술병을 밑에서 비춘다
		root.add_child(_box(Vector3(4.4, 0.012, 0.02), Vector3(0.0, sy - 0.03, -2.18), _glow(COL.lamp, 1.6)))
		var ol := OmniLight3D.new()
		ol.light_color = COL.lamp
		ol.light_energy = 1.1
		ol.omni_range = 1.8
		ol.position = Vector3(0.0, sy + 0.15, -2.05)
		root.add_child(ol)
		var x := -2.15
		while x < 2.15:
			var bh: float = rng.randf_range(0.22, 0.34)
			var br: float = rng.randf_range(0.04, 0.065)
			var bc: Color = bottle_cols[rng.randi() % bottle_cols.size()]
			var gm := _mat(bc, 0.15, 0.0)
			gm.emission_enabled = true
			gm.emission = bc
			gm.emission_energy_multiplier = 0.25
			root.add_child(_cyl(br, br, bh, Vector3(x, sy + 0.025 + bh * 0.5, -2.32), gm, 8))
			root.add_child(_cyl(br * 0.35, br * 0.4, 0.09, Vector3(x, sy + 0.025 + bh + 0.045, -2.32), gm, 6))
			x += br * 2.0 + rng.randf_range(0.03, 0.12)

	# ── 네온 · 다트판 ──
	var neon := Label3D.new()
	neon.text = "HIGHTON"
	neon.font_size = 64
	neon.pixel_size = 0.0042
	neon.modulate = Color(2.4, 0.55, 0.85)
	neon.outline_size = 0
	neon.shaded = false
	neon.position = Vector3(-3.1, 1.78, -2.45)
	neon.name = "Neon"
	root.add_child(neon)
	var nl := OmniLight3D.new()
	nl.light_color = COL.neon
	nl.light_energy = 0.9
	nl.omni_range = 2.2
	nl.position = Vector3(-3.1, 1.78, -2.1)
	nl.name = "NeonLight"
	root.add_child(nl)

	var bm := _mat(Color.WHITE, 0.7)
	bm.albedo_texture = _board_tex()
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var qm := QuadMesh.new()
	qm.size = Vector2(0.68, 0.68)
	var board := MeshInstance3D.new()
	board.mesh = qm
	board.material_override = bm
	board.position = Vector3(3.05, 1.74, -2.38)
	root.add_child(board)
	var back := _cyl(0.38, 0.38, 0.05, Vector3(3.05, 1.74, -2.44), _mat(Color("15100d")), 24)
	back.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	root.add_child(back)
	var bsl := SpotLight3D.new()
	bsl.light_color = Color("ffe0b0")
	bsl.light_energy = 2.5
	bsl.spot_range = 3.0
	bsl.spot_angle = 18.0
	bsl.position = Vector3(3.05, 2.7, -1.5)
	bsl.look_at_from_position(bsl.position, Vector3(3.05, 1.74, -2.4), Vector3.UP)
	root.add_child(bsl)

	# ── 늘어뜨린 램프 둘과 빛줄기 ──
	for sx in [-2.45, 2.45]:
		var lx: float = float(sx)
		root.add_child(_cyl(0.008, 0.008, 1.3, Vector3(lx, 2.75, -0.9), _mat(Color("0a0a0a"))))
		root.add_child(_cyl(0.05, 0.26, 0.2, Vector3(lx, 2.02, -0.9), _mat(Color("1e3b2c"), 0.4, 0.3), 16))
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.12
		bulb.mesh = sm
		bulb.material_override = _glow(COL.lamp, 3.0)
		bulb.position = Vector3(lx, 1.91, -0.9)
		root.add_child(bulb)
		var sl := SpotLight3D.new()
		sl.light_color = COL.lamp
		sl.light_energy = 3.0
		sl.spot_range = 5.0
		sl.spot_angle = 34.0
		sl.shadow_enabled = false
		sl.position = Vector3(lx, 1.9, -0.9)
		sl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		root.add_child(sl)

	return vp


#  방의 움직임 — 숨쉬는 카메라 · 깜박이는 네온 · 슬롯 화면 빛. t 는 게임 시간.
static func tick_room(vp: SubViewport, t: float) -> void:
	if vp == null or not is_instance_valid(vp):
		return
	var root := vp.get_node_or_null("Room")
	if root == null:
		return
	var cam: Camera3D = root.get_node_or_null("Cam")
	if cam != null:
		cam.position = Vector3(sin(t * 0.21) * 0.03, 1.5 + sin(t * 0.33) * 0.012, 3.6)
	var flick: float = 1.0
	#  네온은 가끔 한 번 숨을 쉰다 — 늘 떨면 눈이 거기로 간다.
	var ph: float = fposmod(t, 9.0)
	if ph > 8.6 and ph < 8.75:
		flick = 0.35
	var neon: Label3D = root.get_node_or_null("Neon")
	if neon != null:
		neon.modulate = Color(2.4 * flick, 0.55 * flick, 0.85 * flick)
	var nl: OmniLight3D = root.get_node_or_null("NeonLight")
	if nl != null:
		nl.light_energy = 0.9 * flick


# ══ 테이블 — 골동품 상인의 진열대 (2026-10-01 · 시안 Q) ═══════════
#  짙은 조각 나무 틀 안에 포도주빛 벨벳을 깔고(물건이 눕는 면 그대로),
#  양 끝 옛 창구 자리에 소품 둘을 세운다 — 왼쪽은 놋쇠 저울(파는 것을
#  상인이 단다), 오른쪽은 옛 금전등록기와 종(값을 치르는 곳). 틀 모서리는
#  놋쇠 갓. 빛은 머리 위 램프의 웅덩이 + 소품마다 진열 스포트(왼쪽 위).
#
#  r — 화면에서 이 화판이 덮는 사각(논리 px). fy · ny — 벨벳 먼/가까운 모서리.
#  back — 먼 모서리에서 벨벳이 시작하는 x(옛 창구 빗변). flat · tall — 52° 시점.
#
#  소품 자리 — 면 좌표 (u, h, w), 받침 바닥 가운데. game.gd 가 이름표와
#  반응을 여기에 맞춘다. 둘 다 옛 창구 삼각형 안이라 물건(u 116~524)을
#  안 가린다. 키는 먼 턱 위로 솟되 화판 윗끝(fy − 36)을 안 넘는다.
const TOP_H := 3.0                              # 옆 카운터 윗면 — 벨벳보다 한 단 위
const SELL_AT := Vector3(37.0, TOP_H, 30.0)     # 저울
const BUY_AT := Vector3(609.0, TOP_H, 27.0)     # 금전등록기
const BELL_AT := Vector3(580.0, TOP_H, 12.0)    # 종 — 등록기 왼쪽 뒤
const LAMP_E := 1.5                             # 소품 스포트 평소 세기


static func make_table(host: Node, r: Rect2, fy: float, ny: float, back: float,
		flat: float, tall: float, pitch_deg: float) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(r.size.x), int(r.size.y))
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.gui_disable_input = true
	vp.positional_shadow_atlas_size = 2048
	host.add_child(vp)

	var root := Node3D.new()
	root.name = "Table"
	vp.add_child(root)

	#  카메라 — 상인 손(_stage3_make)과 같은 식. 1 월드 단위 = 화면 1px.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = r.size.y
	cam.near = 1.0
	cam.far = 4000.0
	var pit: float = deg_to_rad(pitch_deg)
	cam.rotation = Vector3(pit, 0.0, 0.0)
	var mid := Vector3(r.position.x + r.size.x * 0.5, 0.0,
			(r.position.y + r.size.y * 0.5 - fy) / flat)
	cam.position = mid + Vector3(0.0, -sin(pit), cos(pit)) * 900.0
	root.add_child(cam)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("2c2320")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	root.add_child(we)

	var W: float = (ny - fy) / flat          # 벨벳 깊이(면 단위)
	var X: float = r.size.x
	var brass := _mat(COL.brass, 0.3, 0.55)

	# ── 벨벳 — 사다리꼴 한 장. 물건이 눕는 면(h 0) 그대로다 ──
	var vel := _mat(COL.velvet, 1.0)
	#  보풀 — 1~2px 잔결이 밝기 ±15%. 매끈하면 천이 아니라 칠이다.
	vel.albedo_texture = _noise_tex(0.9, 0.7, 1.0, 7)
	vel.uv1_scale = Vector3(5.0, 5.0, 1.0)
	root.add_child(_quad([Vector3(back, 0.0, 0.0), Vector3(X - back, 0.0, 0.0),
			Vector3(X, 0.0, W), Vector3(0.0, 0.0, W)], vel))

	# ── 옆 카운터 — 옛 창구 자리. 윤 나는 짙은 나무, 벨벳보다 한 단 위 ──
	#  윤은 반만 — 더 매끈하면 진열 스포트가 카운터에 번진 얼룩으로 비친다.
	var top := _mat(COL.oak, 0.6)
	top.albedo_texture = _noise_tex(0.05, 0.6, 1.0, 3)
	top.uv1_scale = Vector3(8.0, 1.0, 1.0)
	root.add_child(_quad([Vector3(-30.0, TOP_H, -2.0), Vector3(back, TOP_H, -2.0),
			Vector3(0.0, TOP_H, W), Vector3(-30.0, TOP_H, W)], top))
	root.add_child(_quad([Vector3(X - back, TOP_H, -2.0), Vector3(X + 30.0, TOP_H, -2.0),
			Vector3(X + 30.0, TOP_H, W), Vector3(X, TOP_H, W)], top))

	# ── 조각 틀 — 빗변 몰딩(나무 두 단) + 벨벳 쪽 금실 + 모서리 놋쇠 갓 ──
	var carve := _mat(COL.carve, 0.5)
	carve.albedo_texture = _noise_tex(0.08, 0.7, 1.0, 21)
	var bead := _mat(COL.wood, 0.35)
	var ln: float = Vector2(back, W).length()
	for sd in [-1.0, 1.0]:
		var s: float = float(sd)
		#  빗변 방향 d · 바깥(카운터 쪽) 법선 n — 면 (u, w)
		var d := Vector3(s * back, 0.0, W) / ln
		var n := Vector3(s * W, 0.0, -back) / ln
		var m0 := Vector3(back * 0.5 if s < 0.0 else X - back * 0.5, 0.0, W * 0.5)
		var yaw := Vector3(0.0, atan2(s * back, W), 0.0)
		var body := _box(Vector3(7.0, 5.5, ln + 10.0), m0 + n * 3.5 + Vector3(0.0, 2.75, 0.0), carve)
		body.rotation = yaw
		root.add_child(body)
		var bd := _box(Vector3(2.6, 1.8, ln + 10.0), m0 + n * 2.2 + Vector3(0.0, 6.2, 0.0), bead)
		bd.rotation = yaw
		root.add_child(bd)
		var pip := _box(Vector3(1.4, 1.4, ln + 10.0), m0 - n * 0.7 + Vector3(0.0, 0.7, 0.0), brass)
		pip.rotation = yaw
		root.add_child(pip)
		#  먼 모서리 놋쇠 갓 — 몰딩이 먼 턱에 닿는 자리
		var c0: Vector3 = Vector3(back if s < 0.0 else X - back, 0.0, 0.0)
		var cap := _box(Vector3(10.0, 7.6, 7.0), c0 + n * 3.5 + Vector3(0.0, 3.8, 2.0), brass)
		cap.rotation = yaw
		root.add_child(cap)
		root.add_child(_ball(1.6, c0 + n * 3.5 + Vector3(0.0, 7.8, 2.0), brass))
		#  벨벳 모서리 쇠 — 먼 모서리 둘에 놋쇠 삼각 판
		var e0: Vector3 = c0 + Vector3(0.0, 0.5, 0.0)
		var e1: Vector3 = e0 + Vector3(-s * 13.0, 0.0, 0.0)
		var e2: Vector3 = e0 + d * 13.0
		root.add_child(_quad([e0, e1, e2], brass))

	# ── 먼 턱 — 상인 앞 카운터 끝. 짙은 조각 나무 · 이빨 장식 · 놋쇠 줄 ──
	var lip := _mat(COL.carve, 0.45)
	lip.albedo_texture = _noise_tex(0.05, 0.7, 1.0, 5)
	lip.uv1_scale = Vector3(1.0, 10.0, 1.0)
	root.add_child(_box(Vector3(X + 40.0, 8.0, 14.0), Vector3(X * 0.5, 4.0, -7.0), lip))
	#  갓 — 앞으로 1.5 내민 윗판과 그 앞 놋쇠 줄
	root.add_child(_box(Vector3(X + 40.0, 2.4, 15.5), Vector3(X * 0.5, 9.2, -6.25), bead))
	root.add_child(_box(Vector3(X + 40.0, 0.9, 1.0), Vector3(X * 0.5, 10.2, 1.0), brass))
	#  이빨 장식(덴틸) — 갓 밑에 작은 토막이 6 간격으로
	var dent := _mat(COL.wood.lightened(0.06), 0.5)
	var du := -14.0
	while du < X + 14.0:
		root.add_child(_box(Vector3(3.0, 3.6, 1.4), Vector3(du, 5.6, 0.5), dent))
		du += 6.0
	#  벨벳 먼 끝 금실
	root.add_child(_box(Vector3(X - back * 2.0, 1.4, 1.4), Vector3(X * 0.5, 0.7, 1.9), brass))

	# ── 가까운 팔걸이 — 둥근 나무 난간 + 밑 구슬 줄 ──
	var railm := _mat(COL.wood, 0.3)
	railm.albedo_texture = _noise_tex(0.05, 0.7, 1.0, 9)
	var rail := _cyl(8.5, 8.5, X + 60.0, Vector3(X * 0.5, 4.0, W + 8.0), railm, 20)
	rail.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	root.add_child(rail)
	root.add_child(_box(Vector3(X + 60.0, 1.4, 1.4), Vector3(X * 0.5, -5.0, W + 16.0), brass))
	var bu := -8.0
	while bu < X + 8.0:
		var bb := _ball(2.2, Vector3(bu, -8.6, W + 18.6), carve)
		bb.scale = Vector3(1.4, 1.0, 1.0)
		root.add_child(bb)
		bu += 7.0

	# ── 앞판 — 짙은 나무 판넬(테 · 돋은 판 · 놋쇠 모서리 갓), 화면 아래 끝까지 ──
	var apron := _mat(COL.wood_dk, 0.75)
	apron.albedo_texture = _noise_tex(0.04, 0.55, 1.0, 13)
	apron.uv1_scale = Vector3(2.0, 1.0, 1.0)
	root.add_child(_box(Vector3(X + 60.0, 260.0, 4.0), Vector3(X * 0.5, -136.0, W + 16.0), apron))
	var zf: float = W + 18.0
	var frame := _mat(COL.wood, 0.55)
	frame.albedo_texture = _noise_tex(0.05, 0.65, 1.0, 17)
	var field := _mat(COL.wood.darkened(0.12), 0.6)
	field.albedo_texture = _noise_tex(0.04, 0.6, 1.0, 19)
	field.uv1_scale = Vector3(2.0, 1.0, 1.0)
	#  위 띠
	root.add_child(_box(Vector3(X + 60.0, 4.0, 2.4), Vector3(X * 0.5, -13.0, zf + 1.2), frame))
	var pw := 128.0
	for k in range(0, 6):
		var su: float = float(k) * pw
		#  선대(세로 테)
		root.add_child(_box(Vector3(7.0, 200.0, 2.4), Vector3(su, -115.0, zf + 1.2), frame))
		if k == 5:
			break
		var cu: float = su + pw * 0.5
		#  돋은 판 — 테 안쪽에서 한 단 나온다
		root.add_child(_box(Vector3(pw - 22.0, 160.0, 1.4), Vector3(cu, -103.0, zf + 0.7), field))
		#  모서리 놋쇠 갓 — 판 위 두 모서리
		for sx in [-1.0, 1.0]:
			root.add_child(_box(Vector3(3.0, 3.0, 1.0), Vector3(cu + float(sx) * (pw * 0.5 - 13.0),
					-25.5, zf + 1.9), brass))

	# ── 소품 — 저울(판매) · 금전등록기와 종(구매) ──
	_scale_prop(root, SELL_AT)
	_register_prop(root, BUY_AT)
	_bell_prop(root, BELL_AT)

	# ── 빛 — 머리 위 램프(빛 웅덩이 · 그림자) + 왼쪽 위 채움빛 + 소품 스포트 ──
	var sl := SpotLight3D.new()
	sl.light_color = COL.lamp
	#  빛 웅덩이 — 벨벳 한가운데가 밝고 가장자리가 가라앉는다.
	sl.light_energy = 7.0
	sl.spot_range = 1200.0
	sl.spot_attenuation = 0.2
	sl.spot_angle = 38.0
	sl.spot_angle_attenuation = 2.2
	sl.shadow_enabled = true
	sl.position = Vector3(X * 0.5, 360.0, W * 0.5)
	sl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	root.add_child(sl)
	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-46.0, -38.0, 0.0)
	dl.light_energy = 0.30
	dl.light_color = Color("ffd8b0")
	root.add_child(dl)
	#  진열 스포트 — 소품마다 왼쪽 위에서 하나. 옆에 꺼 둔 웅덩이 빛 하나.
	#  반응(prop_glow)이 스포트를 밝히고 웅덩이를 켠다 — 소품과 그 둘레
	#  카운터가 같이 달아올라 「여기」를 말한다(옛 창구 삼각형 칠의 자리).
	for pr in [["SellLamp", SELL_AT + Vector3(0.0, 32.0, 0.0), 14.0],
			["BuyLamp", BUY_AT + Vector3(-6.0, 26.0, -4.0), 12.0]]:
		var ps := SpotLight3D.new()
		ps.name = String(pr[0])
		ps.light_color = COL.lamp
		ps.light_energy = LAMP_E
		ps.spot_range = 280.0
		ps.spot_attenuation = 0.0
		ps.spot_angle = float(pr[2])
		ps.spot_angle_attenuation = 1.6
		#  그림자는 끈다 — 저울대 그림자가 벨벳 왼끝에 검은 얼룩으로 떨어진다.
		#  소품을 바닥에 붙이는 그림자는 머리 위 램프가 이미 드리운다.
		ps.shadow_enabled = false
		var tgt: Vector3 = pr[1]
		var at: Vector3 = tgt + Vector3(-45.0, 175.0, -35.0)
		ps.transform = Transform3D(Basis.looking_at(tgt - at, Vector3.UP), at)
		root.add_child(ps)
		var po := OmniLight3D.new()
		po.name = String(pr[0]) + "Pool"
		po.light_color = COL.lamp
		po.light_energy = 0.0
		po.omni_range = 48.0
		po.omni_attenuation = 0.0
		po.position = Vector3(tgt.x, TOP_H + 30.0, tgt.z + 6.0)
		root.add_child(po)
	return vp


#  소품 반응 — 얹힘 · 끌어 댐 · 산 순간에 그 소품의 스포트가 밝아진다.
#  k 0 = 평소 · 1 = 한껏 · 음수 = 눌려 가라앉음. col 쪽으로 빛이 물든다.
#  게임 쪽 그리기(_chute_draw)가 매 틀 부른다 — 시계를 안 쓰니 모션 끄기와 무관하다.
static func prop_glow(vp: SubViewport, z: int, k: float, col: Color) -> void:
	if vp == null or not is_instance_valid(vp):
		return
	var root := vp.get_node_or_null("Table")
	if root == null:
		return
	var nm: String = "BuyLamp" if z == 1 else "SellLamp"
	var tint: Color = COL.lamp.lerp(col, clampf(k, 0.0, 1.0) * 0.6)
	var l: SpotLight3D = root.get_node_or_null(nm)
	if l != null:
		l.light_energy = LAMP_E * maxf(1.0 + 1.2 * k, 0.2)
		l.light_color = tint
	var po: OmniLight3D = root.get_node_or_null(nm + "Pool")
	if po != null:
		po.light_energy = 0.9 * maxf(k, 0.0)
		po.light_color = tint


#  공 하나(반구면 바닥이 원점).
static func _ball(rad: float, at: Vector3, m: Material, hemi := false) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = rad
	sm.height = rad if hemi else rad * 2.0
	sm.is_hemisphere = hemi
	sm.radial_segments = 14
	sm.rings = 7
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = m
	mi.position = at
	return mi


#  막대 하나 — a 에서 b 까지(u-h 평면, w 는 같다). 매단 줄 · 손잡이.
static func _rod(a: Vector3, b: Vector3, t: float, m: Material) -> MeshInstance3D:
	var v: Vector3 = b - a
	var mi := _box(Vector3(t, v.length(), t), (a + b) * 0.5, m)
	mi.rotation = Vector3(0.0, 0.0, atan2(-v.x, v.y))
	return mi


#  저울 — 판매. 나무 받침 · 놋쇠 기둥 · 기운 저울대 · 매단 접시 둘.
#  오른 접시에 추 둘이 얹혀 그쪽이 내려앉았다(상인이 무게를 단다).
#  기둥이 먼 턱 위로 솟는다 — 키가 곧 실루엣이다(옆 카운터는 폭이 모자란다).
static func _scale_prop(root: Node3D, at: Vector3) -> void:
	var brass := _mat(COL.brass, 0.3, 0.55)
	var brass_dk := _mat(COL.brass.darkened(0.45), 0.5, 0.4)
	var wood := _mat(COL.carve, 0.45)
	var wood2 := _mat(COL.wood, 0.4)
	root.add_child(_box(Vector3(32.0, 3.4, 17.0), at + Vector3(0.0, 1.7, 0.0), wood))
	root.add_child(_box(Vector3(26.0, 2.8, 12.0), at + Vector3(0.0, 4.8, 0.0), wood2))
	root.add_child(_cyl(4.6, 7.6, 3.4, at + Vector3(0.0, 7.9, 0.0), brass, 14))
	root.add_child(_cyl(2.0, 2.5, 46.0, at + Vector3(0.0, 32.6, 0.0), brass, 8))
	#  기둥 허리 고리 둘 — 매끈한 막대보다 깎은 놋쇠로 읽힌다
	for ry in [20.0, 44.0]:
		root.add_child(_cyl(3.0, 3.0, 1.6, at + Vector3(0.0, float(ry), 0.0), brass, 12))
	var piv: Vector3 = at + Vector3(0.0, 56.0, 0.0)
	root.add_child(_ball(3.2, piv, brass))
	root.add_child(_cyl(0.4, 1.8, 7.0, piv + Vector3(0.0, 5.5, 0.0), brass, 8))
	root.add_child(_ball(2.0, piv + Vector3(0.0, 9.6, 0.0), brass))
	var tilt: float = deg_to_rad(-8.0)      # 오른쪽이 내려앉는다
	var hl := 24.0
	var beam := _box(Vector3(hl * 2.0, 2.8, 2.8), piv, brass)
	beam.rotation = Vector3(0.0, 0.0, tilt)
	root.add_child(beam)
	for sd in [-1.0, 1.0]:
		var s: float = float(sd)
		var end: Vector3 = piv + Vector3(s * hl * cos(tilt), s * hl * sin(tilt), 0.0)
		root.add_child(_ball(2.0, end, brass))
		var pan: Vector3 = end + Vector3(0.0, -26.0, 0.0)
		for k in [-1.0, 1.0]:
			root.add_child(_rod(end, pan + Vector3(float(k) * 8.0, 1.2, 0.0), 1.4, brass_dk))
		root.add_child(_cyl(10.0, 5.8, 3.0, pan, brass, 18))
		root.add_child(_cyl(7.8, 7.8, 0.4, pan + Vector3(0.0, 1.55, 0.0), brass_dk, 18))
		if s > 0.0:
			root.add_child(_cyl(3.0, 3.0, 3.8, pan + Vector3(-2.0, 3.2, 0.0), brass, 10))
			root.add_child(_cyl(2.1, 2.1, 2.6, pan + Vector3(3.6, 2.6, 0.8), brass, 10))
			root.add_child(_ball(1.1, pan + Vector3(-2.0, 5.6, 0.0), brass))


#  금전등록기 — 구매. 나무 서랍 받침 · 청동 몸통 · 기운 건반(상아 알 셋 줄) ·
#  위 창(숫자 깃) · 반달 볏 · 오른쪽 손잡이. 볏이 먼 턱 위로 솟는다.
static func _register_prop(root: Node3D, at: Vector3) -> void:
	var wood := _mat(COL.carve, 0.45)
	var wood2 := _mat(COL.wood, 0.4)
	var body := _mat(COL.bronze, 0.35, 0.5)
	body.albedo_texture = _noise_tex(0.35, 0.78, 1.0, 31)
	var slope := _mat(COL.bronze.darkened(0.25), 0.4, 0.45)
	var brass := _mat(COL.brass, 0.3, 0.55)
	var ivory := _mat(COL.ivory, 0.5)
	var glass := _mat(COL.glass, 0.15)
	var hw := 19.0
	#  서랍 받침 (w −15 … 18)
	root.add_child(_box(Vector3(hw * 2.0 + 2.0, 9.6, 33.0), at + Vector3(0.0, 4.8, 1.5), wood))
	root.add_child(_box(Vector3(hw * 2.0 - 4.0, 6.0, 1.0), at + Vector3(0.0, 4.8, 18.4), wood2))
	root.add_child(_box(Vector3(9.0, 1.6, 1.2), at + Vector3(0.0, 5.2, 19.2), brass))
	#  몸통 — 뒤쪽 (w −15 … 3), h 9.6 … 31
	root.add_child(_box(Vector3(hw * 2.0, 21.4, 18.0), at + Vector3(0.0, 20.3, -6.0), body))
	#  몸통 허리 놋쇠 띠
	root.add_child(_box(Vector3(hw * 2.0 + 0.8, 1.4, 18.6), at + Vector3(0.0, 30.4, -6.0), brass))
	#  건반 경사면 — 몸통 앞 윗모서리 밑(w 3, h 29)에서 받침 앞(w 16, h 9.6)까지
	var b0: Vector3 = at + Vector3(-hw, 9.6, 16.0)
	var b1: Vector3 = at + Vector3(hw, 9.6, 16.0)
	var b2: Vector3 = at + Vector3(hw, 29.0, 3.0)
	var b3: Vector3 = at + Vector3(-hw, 29.0, 3.0)
	root.add_child(_quad([b0, b1, b2, b3], slope))
	#  건반 — 경사면의 바깥 법선으로 살짝 띄운 상아 알, 셋 줄 여섯 칸
	var nrm := Vector3(0.0, 13.0, 19.4).normalized()
	var kx: float = atan2(nrm.z, nrm.y)
	for row in 3:
		var t: float = 0.2 + float(row) * 0.29
		var p0: Vector3 = b0.lerp(b3, t)
		for col in 6:
			var ku: float = at.x - hw + 4.0 + float(col) * 6.0
			var key := _box(Vector3(3.2, 1.4, 3.2), Vector3(ku, p0.y, p0.z) + nrm * 0.7, ivory)
			key.rotation = Vector3(kx, 0.0, 0.0)
			root.add_child(key)
	#  위 창 — 숫자 깃이 서는 놋쇠 틀, 앞에 어두운 유리와 상아 깃 둘
	root.add_child(_box(Vector3(28.0, 11.0, 5.0), at + Vector3(0.0, 36.5, -12.0), brass))
	root.add_child(_box(Vector3(21.0, 6.0, 0.6), at + Vector3(0.0, 36.5, -9.3), glass))
	for fx in [-3.6, 3.6]:
		root.add_child(_box(Vector3(4.6, 4.2, 0.5), at + Vector3(float(fx), 36.3, -8.9), ivory))
	#  반달 볏 — 축이 w 인 원통의 윗반만 틀 위로 나온다
	var crest := _cyl(10.0, 10.0, 3.6, at + Vector3(0.0, 42.0, -12.0), brass, 20)
	crest.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	root.add_child(crest)
	root.add_child(_ball(2.2, at + Vector3(0.0, 53.4, -12.0), brass))
	#  손잡이 — 오른쪽 옆구리에서 뻗은 자루와 손잡이 알
	var hub := _cyl(3.0, 3.0, 2.4, at + Vector3(hw + 1.2, 20.0, -6.0), brass, 10)
	hub.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	root.add_child(hub)
	root.add_child(_rod(at + Vector3(hw + 2.8, 20.0, -6.0), at + Vector3(hw + 4.6, 10.6, -6.0), 1.8, brass))
	root.add_child(_ball(2.1, at + Vector3(hw + 4.6, 10.0, -6.0), wood2))


#  종 — 계산대 곁 손님 종. 나무 받침 · 놋쇠 반구 · 꼭지.
static func _bell_prop(root: Node3D, at: Vector3) -> void:
	var brass := _mat(COL.brass, 0.28, 0.6)
	root.add_child(_cyl(6.6, 7.2, 2.2, at + Vector3(0.0, 1.1, 0.0), _mat(COL.carve, 0.4), 16))
	root.add_child(_ball(5.6, at + Vector3(0.0, 2.2, 0.0), brass, true))
	root.add_child(_cyl(0.9, 0.9, 2.2, at + Vector3(0.0, 8.8, 0.0), brass, 8))
	root.add_child(_ball(1.4, at + Vector3(0.0, 10.2, 0.0), brass))


#  면 좌표 점 셋·넷으로 판 한 장. 점 순서대로 감는다.
static func _quad(p: Array, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := [[0, 1, 2]]
	if p.size() == 4:
		tris = [[0, 1, 2], [0, 2, 3]]
	#  UV — 면 좌표를 그대로 나눈다(결이 원근 없이 고르게 깔린다).
	for tr in tris:
		for i in tr:
			var v: Vector3 = p[i]
			st.set_uv(Vector2(v.x / 160.0, v.z / 160.0))
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mi
