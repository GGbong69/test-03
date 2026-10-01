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
#     떨어진다. 물건(2D)이 그 위에 정확히 앉는다. 펠트 · 꺼진 창구 ·
#     먼 턱 · 가죽 팔걸이 · 나무 앞판, 머리 위 램프의 빛 웅덩이와 그림자.
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


# ══ 테이블 ═══════════════════════════════════════════════════
#  r — 화면에서 이 화판이 덮는 사각(논리 px). fy · ny — 펠트 먼/가까운 모서리.
#  back — 먼 모서리에서 펠트가 시작하는 x(창구 빗변). flat · tall — 52° 시점.
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

	var W: float = (ny - fy) / flat          # 펠트 깊이(면 단위)
	var X: float = r.size.x

	# ── 펠트 — 사다리꼴 한 장(빗변이 창구) ──
	var felt_m := _mat(COL.felt, 1.0)
	#  천 결 — 2~3px 짜리 잔털이 밝기 ±12% 로 깔린다. 매끈하면 화면이지 천이 아니다.
	felt_m.albedo_texture = _noise_tex(0.9, 0.76, 1.0, 7)
	felt_m.uv1_scale = Vector3(5.0, 5.0, 1.0)
	root.add_child(_quad([Vector3(back, 0.0, 0.0), Vector3(X - back, 0.0, 0.0),
			Vector3(X, 0.0, W), Vector3(0.0, 0.0, W)], felt_m))

	# ── 창구 — 빗변 바깥의 꺼진 쟁반(나무 살) ──
	var tray := _mat(COL.wood, 0.8)
	tray.albedo_texture = _noise_tex(0.06, 0.6, 1.0, 3)
	tray.uv1_scale = Vector3(1.0, 8.0, 1.0)
	var dip := -7.0
	root.add_child(_quad([Vector3(0.0, dip, 0.0), Vector3(back, dip, 0.0),
			Vector3(0.0, dip, W)], tray))
	root.add_child(_quad([Vector3(X - back, dip, 0.0), Vector3(X, dip, 0.0),
			Vector3(X, dip, W)], tray))
	#  나무 살 — 미끄럼틀 결. 빗변까지 가로로 놓는다(옛 그림의 5px 줄을 3D 로).
	var slat := _mat(COL.trim, 0.5)
	var ww := 4.0
	while ww < W - 2.0:
		var e: float = back * (1.0 - ww / W)
		if e > 4.0:
			root.add_child(_box(Vector3(e - 2.0, 1.6, 1.4), Vector3((e - 2.0) * 0.5, dip + 0.8, ww), slat))
			root.add_child(_box(Vector3(e - 2.0, 1.6, 1.4), Vector3(X - (e - 2.0) * 0.5, dip + 0.8, ww), slat))
		ww += 7.0
	#  빗변 안벽 — 펠트에서 쟁반으로 꺼지는 면
	var wallm := _mat(COL.wood, 0.7)
	root.add_child(_quad([Vector3(back, 0.0, 0.0), Vector3(0.0, 0.0, W),
			Vector3(0.0, dip, W), Vector3(back, dip, 0.0)], wallm))
	root.add_child(_quad([Vector3(X - back, 0.0, 0.0), Vector3(X - back, dip, 0.0),
			Vector3(X, dip, W), Vector3(X, 0.0, W)], wallm))

	# ── 먼 턱 — 상인 앞 카운터 끝(놋쇠 줄 하나) ──
	var lip := _mat(COL.wood, 0.45)
	lip.albedo_texture = _noise_tex(0.05, 0.7, 1.0, 5)
	lip.uv1_scale = Vector3(1.0, 10.0, 1.0)
	root.add_child(_box(Vector3(X + 40.0, 9.0, 12.0), Vector3(X * 0.5, 4.5, -6.0), lip))
	root.add_child(_box(Vector3(X + 40.0, 1.6, 1.6), Vector3(X * 0.5, 9.4, 0.2), _mat(COL.brass, 0.3, 0.8)))

	# ── 가까운 팔걸이 — 가죽 쿠션(둥근 기둥) ──
	var leather := _mat(COL.leather, 0.42)
	leather.albedo_texture = _noise_tex(0.5, 0.85, 1.0, 9)
	var rail := _cyl(9.0, 9.0, X + 60.0, Vector3(X * 0.5, 4.0, W + 8.0), leather, 20)
	rail.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	root.add_child(rail)
	#  팔걸이를 받치는 놋쇠 줄
	root.add_child(_box(Vector3(X + 60.0, 1.4, 1.4), Vector3(X * 0.5, -5.5, W + 15.5), _mat(COL.brass, 0.3, 0.8)))

	# ── 앞판 — 나무 판자, 화면 아래 끝까지 ──
	var apron := _mat(COL.wood, 0.75)
	apron.albedo_texture = _noise_tex(0.04, 0.55, 1.0, 13)
	apron.uv1_scale = Vector3(2.0, 1.0, 1.0)
	root.add_child(_box(Vector3(X + 60.0, 260.0, 4.0), Vector3(X * 0.5, -136.0, W + 16.0), apron))
	#  판자 이음
	for k in range(0, int(X / 96.0) + 2):
		root.add_child(_box(Vector3(1.4, 260.0, 0.6), Vector3(float(k) * 96.0 - 16.0, -136.0, W + 18.2),
				_mat(COL.wood_dk)))

	# ── 빛 — 머리 위 램프(빛 웅덩이 · 그림자) + 왼쪽 위 채움빛 ──
	var sl := SpotLight3D.new()
	sl.light_color = COL.lamp
	#  빛 웅덩이 — 펠트 한가운데가 밝고 가장자리 · 창구가 가라앉는다(인스크립션의 램프).
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
	return vp


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
