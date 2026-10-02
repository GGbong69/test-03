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
#     포도주빛 벨벳 · 조각 틀과 놋쇠 모서리 갓 · 니스 칠한 밤나무 판자 카운터 ·
#     양 끝 소품(판매 저울 · 구매 금전등록기) · 둥근 난간 · 판넬 앞판,
#     램프의 빛 웅덩이와 니스에 비친 반사.
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


# ══ 테이블 — 골동품 상인의 진열대 (2026-10-02) ═══════════════
#  「Q의 오브젝트는 맘에 드는데 조금만 크기랑 위치 그리고 디테일을 챙기면
#   될거 같은데 P의 저 테이블에 빛 반사되는것도 좀 맘에 드네, R의 저 나무
#   재질도 괜찮아 보이고」 — 세 시안을 하나로 꿰맸다.
#
#   · 뼈대(시안 Q) — 포도주빛 벨벳을 조각 틀이 두르고, 옛 창구 삼각형은
#     카운터가 되어 양 끝에 소품이 선다. 왼쪽 놋쇠 저울(판매 — 파는 것을
#     상인이 단다), 오른쪽 금전등록기(구매 — 값을 치르는 곳).
#   · 나무(시안 R) — 밤나무 판자. 이음 · 결 · 못 · 옹이를 화면 1px = 1텍셀로
#     굽는다(_plank). 면마다 화면 y 로 UV 를 잡아(_sv) 이음이 가로줄로 떨어진다.
#   · 니스(시안 P) — 같은 붓으로 거칠기도 칠해(ORM) 밝은 결은 매끈하고 이음 ·
#     짙은 결은 거칠다. 소품 뒤 높이 둔 빛이 카운터에 비쳐 결 따라 끊긴다.
#     반사점 w = 빛 w + 높이 × 0.78 (시점 52°).
#
#  r — 화면에서 이 화판이 덮는 사각(논리 px). fy · ny — 벨벳 먼/가까운 모서리.
#  back — 먼 모서리에서 벨벳이 시작하는 x(옛 창구 빗변). flat · tall — 52° 시점.
#
#  소품 자리 — 면 좌표 (u, h, w), 받침 바닥 가운데. 크기는 곱(K)이다.
#  소품의 깊이 축은 벨벳 빗변이 모이는 소실점으로 기운다(lean) — 직교 그대로
#  세우면 사다리꼴 테이블 구석에서 정면만 보고 서 있어 각이 따로 논다
#  (「저울이랑 서랍의 각도가 이상한데? 게임내 테이블의 기울기랑 좀 다른거 같고」).
#
#  ── 시안 C — 화면 끝에 걸친 큰 소품 (2026-10-02) ──────────────
#  「지금 오른쪽 수금기가 좀 더 이팩트 있으면 좋곘는데? 솔찍히 지금도 작어서 서랍
#   열린건진도 모르겠어 / 저울이랑 수금기? 다 크기 키우고 배치도 진짜 게임 답게」.
#  시안 셋(A 그 자리에서 키움 · B 앞 모서리로 내림 · C 화면 끝에 걸친 큰 앞소품)
#  중 「C 로 바로」. 둘 다 곱을 두 배 언저리(1.1 · 1.05 → 2.0 · 1.95)로 올리고
#  가운데를 화면 끝 쪽으로 밀어 **화면 틀이 몸 한쪽을 자른다** — 저울은 바깥
#  접시가 왼끝에서, 등록기는 옆구리 손잡이와 오른 어깨가 오른끝에서 잘린다.
#  잘린 큰 몸이 「카메라 앞에 놓인 것」으로 읽히는 앞소품의 어법이다.
#  세로는 벽 띠(HUD 밑)에서 옆 카운터까지 한 판을 쓴다:
#    · 위 — 저울 꼭지 y 63 · 등록기 볏 꼭지 y 48. 자금판(y ≤ 58) · 사탕·사진
#      이름(x 80~159 · y ≤ 61) · 동전/다트 꼬리표 · 정보/설정(y ≤ 48) 밑이다(상점).
#      판 고르기에서는 위 띠가 서며 HUD 가 16px 내려와 등록기 볏 윗동이 정보/설정 단추 뒤로
#      든다 — 거기서도 비우려면 등록기를 15% 줄이거나 볏을 걷어야 해서(이름 줄이 밑을
#      막는다) 그쪽은 받아들였다. 판 고르기는 소품을 쓰지 않는 화면이다.
#    · 아래 — 받침 · 서랍 앞끝이 y 159~160. 그 밑 카운터에 game.gd 가 이름과
#      값을 쓴다(CHUTE_TXT) — 소품 몸이 글을 안 덮는다.
#    · 옆 — 물건 자리(u 116~524) 밖. 저울 오른끝 u 102 · 등록기 왼끝 u 548.
#  깊이는 상인이 닿는 데서 멈춘다 — 저울 안 접시 · 등록기 건반이 팔 길이(위팔 +
#  팔뚝 ≈ 180) 안이라야 판 소품 몸짓이 선다. 앞으로 더 내리면(시안 B) 팔이 못 간다.
#  game.gd 의 판정(prop_rect) · 반응(prop_glow)이 이 표를 그대로 읽는다.
const TOP_H := 3.0                              # 옆 카운터 윗면 — 벨벳보다 한 단 위
const SELL_AT := Vector3(37.0, TOP_H, 25.0)     # 저울
const BUY_AT := Vector3(602.0, TOP_H, 9.0)      # 금전등록기
const SELL_K := 2.0
const BUY_K := 1.95
#  소품 윤곽 점 — 받침 바닥 가운데 기준, 곱하기 전 (u, h, w). 화면 사각은
#  이 점들을 기울이고 투영해 감싼다(prop_rect). 저울은 두 접시 테(반지름 10 ·
#  기울기 +12° / −16° 의 위아래 끝) · 저울대 끝 · 꼭지 · 받침 모서리, 등록기는
#  서랍장 · **닫힌** 서랍 앞끝 · 손잡이 알 · 볏 꼭지. 튀어나온 서랍은 안 넣는다 —
#  넣으면 사각이 이름 줄까지 내려와 판정이 글을 먹는다(서랍은 0.5 초만 나온다).
const SELL_HULL := [Vector3(-32.5, 21.0, 0.0), Vector3(32.5, 21.0, 0.0),
		Vector3(-32.5, 34.0, 0.0), Vector3(32.5, 34.0, 0.0),
		Vector3(-22.0, 21.0, -10.0), Vector3(-22.0, 21.0, 10.0),
		Vector3(22.0, 21.0, -10.0), Vector3(22.0, 21.0, 10.0),
		Vector3(-24.0, 63.3, 0.0), Vector3(24.0, 63.3, 0.0), Vector3(0.0, 67.6, 0.0),
		Vector3(-16.4, 0.0, -8.9), Vector3(16.4, 0.0, -8.9),
		Vector3(-16.4, 0.0, 8.9), Vector3(16.4, 0.0, 8.9)]
const BUY_HULL := [Vector3(-20.6, 0.0, -14.0), Vector3(20.6, 0.0, -14.0),
		Vector3(-20.6, 0.0, 16.8), Vector3(20.6, 0.0, 16.8),
		Vector3(-17.5, 1.1, 17.8), Vector3(17.5, 1.1, 17.8),
		Vector3(-20.6, 11.6, -14.0), Vector3(20.6, 11.6, -14.0),
		Vector3(26.0, 9.6, -6.0), Vector3(-10.0, 55.0, -9.5), Vector3(10.0, 55.0, -9.5),
		Vector3(0.0, 58.6, -9.5)]
const LAMP_E := 1.5                             # 소품 스포트 평소 세기

#  나무 — 밤나무(시안 R). 카운터 판자 · 턱 통나무 · 난간 · 앞판 · 조각 틀.
const WOOD := {
	"plank": Color("5a3b26"),
	"ledge": Color("4a301f"),
	"beam": Color("6a4630"),
	"apron": Color("33221a"),
	"carve": Color("2a170d"),
}
const WOOD_LAYER := 4   # 니스 나무의 렌더 층(3) — 반사 램프가 이 층만 비춘다
const TEX_U := 40.0      # 텍스처 u 여백 — 화면 밖 −40 부터 굽는다
const TEX_V := 40.0      # 텍스처 v 여백 — 펠트 먼 모서리 위 40 줄부터
static var _fl := 0.788
static var _tl := 0.616


#  면 좌표 → 화면 텍셀(org 가 텍스처 왼쪽 위). 화면 y 는 w·flat − h·tall.
static func _sv(v: Vector3, org: Vector2) -> Vector2:
	return Vector2(v.x - org.x, v.z * _fl - v.y * _tl - org.y)


#  판 한 장 — 점 셋·넷, 법선을 손으로 준다. UV 는 화면 격자 그대로.
static func _face(p: Array, m: Material, n: Vector3, tex: Vector2,
		org := Vector2(-TEX_U, -TEX_V)) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := [[0, 1, 2]]
	if p.size() == 4:
		tris = [[0, 1, 2], [0, 2, 3]]
	for tr in tris:
		for i in tr:
			var v: Vector3 = p[i]
			var t := _sv(v, org)
			st.set_normal(n)
			st.set_uv(Vector2(t.x / tex.x, t.y / tex.y))
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mi


#  상자 — 이 시점에서 보이는 것은 윗면과 앞면뿐이다(옆면은 시선과 나란해
#  두께가 0 이다). 둘만 깐다.
static func _slab(root: Node, u0: float, u1: float, w0: float, w1: float,
		h0: float, h1: float, top: Material, front: Material, tex: Vector2) -> void:
	root.add_child(_face([Vector3(u0, h1, w0), Vector3(u1, h1, w0),
			Vector3(u1, h1, w1), Vector3(u0, h1, w1)], top, Vector3.UP, tex))
	root.add_child(_face([Vector3(u0, h1, w1), Vector3(u1, h1, w1),
			Vector3(u1, h0, w1), Vector3(u0, h0, w1)], front, Vector3.BACK, tex))


#  판자 — 좌우로 누운 판, 판 사이 이음(짙은 1px)과 그 밑 빛 받은 모서리,
#  맞댄 이음(세로 1px)과 못 둘, 결 줄, 옹이, 이 빠진 모서리(시안 R).
#  붓질마다 니스 거칠기도 같이 칠한다(시안 P) — 밝은 결은 니스가 고루 먹어
#  매끈하고, 이음 · 짙은 결 · 옹이는 덜 먹어 거칠다. 램프 반사가 결 따라
#  끊기는 것이 「윤 낸 나무」 다. [바탕, ORM] 을 돌려준다.
static func _plank(wpx: int, hpx: int, base: Color, seed: int,
		p_lo := 13, p_hi := 18, nails := true) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var im := Image.create(wpx, hpx, false, Image.FORMAT_RGBA8)
	var orm := Image.create(wpx, hpx, false, Image.FORMAT_RGBA8)
	var bl: float = maxf(base.get_luminance(), 0.01)
	var fill := func(r: Rect2i, c: Color) -> void:
		im.fill_rect(r, c)
		var ro: float = clampf(0.16 + (bl - c.get_luminance()) / bl * 0.9, 0.12, 0.85)
		orm.fill_rect(r, Color(1.0, ro, 0.0))
	var seam: Color = base.darkened(0.66)
	var y := 0
	while y < hpx:
		var ph: int = rng.randi_range(p_lo, p_hi)
		var tone: float = rng.randf_range(-0.12, 0.10)
		var pc: Color = base.lightened(tone) if tone > 0.0 else base.darkened(-tone)
		fill.call(Rect2i(0, y, wpx, ph), pc)
		#  결 — 판 길이로 흐르는 1px 줄. 대개 짙고 가끔 밝다.
		for _k in int(float(wpx * ph) / 70.0):
			var gy: int = y + rng.randi_range(2, ph - 1)
			var gx: int = rng.randi_range(-40, wpx - 1)
			var gl: int = rng.randi_range(10, 80)
			var gc: Color = pc.darkened(rng.randf_range(0.07, 0.18)) if rng.randf() < 0.72 \
					else pc.lightened(rng.randf_range(0.05, 0.10))
			var x0: int = maxi(gx, 0)
			var x1: int = mini(gx + gl, wpx)
			if x1 > x0 and gy < hpx:
				fill.call(Rect2i(x0, gy, x1 - x0, 1), gc)
		#  이음 — 짙은 1px, 그 밑은 빛 받은 1px(빛이 위에서 온다)
		fill.call(Rect2i(0, y, wpx, 1), seam)
		if y + 1 < hpx:
			fill.call(Rect2i(0, y + 1, wpx, 1), pc.lightened(0.07))
		#  이 빠진 모서리 — 이음 밑으로 짧게 파인 자국
		for _k in wpx / 60:
			var cx: int = rng.randi_range(0, wpx - 4)
			if y + 1 < hpx:
				fill.call(Rect2i(cx, y + 1, rng.randi_range(2, 5), 1), seam.lightened(0.15))
		#  맞댄 이음과 못
		var x: int = rng.randi_range(-300, 0)
		while nails:
			x += rng.randi_range(170, 330)
			if x >= wpx:
				break
			if x < 0:
				continue
			fill.call(Rect2i(x, y + 1, 1, mini(ph - 1, hpx - y - 1)), seam)
			for nx in [x - 4, x + 3]:
				for ny in [y + 3, y + ph - 4]:
					if nx >= 0 and nx + 1 < wpx and ny + 1 < hpx:
						fill.call(Rect2i(nx, ny, 2, 1), pc.darkened(0.55))
						fill.call(Rect2i(nx, ny, 1, 1), pc.lightened(0.22))
		#  옹이 — 판마다 반쯤
		if rng.randf() < 0.55:
			var kx: int = rng.randi_range(8, wpx - 12)
			var ky: int = y + ph / 2
			if ky + 1 < hpx:
				fill.call(Rect2i(kx - 3, ky, 7, 1), pc.darkened(0.22))
				fill.call(Rect2i(kx - 1, ky - 1, 3, 3), pc.darkened(0.42))
				fill.call(Rect2i(kx, ky, 1, 1), pc.darkened(0.62))
		y += ph
	return [im, orm]


#  니스 칠한 판자 재질 — 반사가 맨나무의 두 배(시안 P 의 상판과 같은 값).
static func _varnish(pair: Array) -> ORMMaterial3D:
	var m := ORMMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(pair[0])
	m.orm_texture = ImageTexture.create_from_image(pair[1])
	m.metallic_specular = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


#  놋쇠 — 소품마다 한 벌. 반응(prop_glow)이 이 재질의 빛을 올린다.
static func _brass() -> StandardMaterial3D:
	var m := _mat(COL.brass, 0.3, 0.55)
	m.emission_enabled = true
	m.emission = COL.lamp
	m.emission_energy_multiplier = 0.0
	return m


#  소품 받침 그늘 — 바닥에 붙인다. 이게 없으면 소품이 떠 보인다(Q 에서 저울
#  받침 밑 그림자가 한 줄 떨어져 섰다). 빛이 왼쪽 위라 오른쪽 앞으로 민다.
static func _blob(sz: Vector2, at: Vector3, a: float) -> MeshInstance3D:
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0, 1.0))
	g.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	g.add_point(0.55, Color(0.0, 0.0, 0.0, 0.8))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 1.0, 1.0, a)
	m.albedo_texture = gt
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var pm := PlaneMesh.new()
	pm.size = sz
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.position = at
	return mi


#  깊이 기울기 — 그 자리에서 w 가 1 늘 때 u 가 얼마 가는가. 벨벳 사다리꼴의
#  두 빗변을 이으면 폭이 0 이 되는 w(먼 쪽 소실점)로 모인다. 왼쪽은 −, 오른쪽은 +.
static func lean(at: Vector3, X: float, W: float, back: float) -> float:
	var w_vp: float = -W * (X - back * 2.0) / (back * 2.0)
	return (at.x - X * 0.5) / (at.z - w_vp)


#  소품 하나의 뿌리 — 받침 바닥 가운데에 서고 K 배로 키운다. 깊이 축(w)은
#  sh 만큼 옆으로 민다(소실점 쪽). 몸은 그 안의 제 좌표로 짓는다.
static func _prop_node(root: Node3D, nm: String, at: Vector3, k: float, sh: float) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.transform = Transform3D(Basis(Vector3(k, 0.0, 0.0), Vector3(0.0, k, 0.0),
			Vector3(sh * k, 0.0, k)), at)
	root.add_child(n)
	return n


#  소품 하나가 화면에서 차지하는 사각(논리 px). z 0 저울 · 1 금전등록기.
#  판정이 쓴다 — 턱 위로 솟은 몸까지 창구다.
#  X — 화면 폭. 나머지는 make_table 과 같다(깊이 기울기를 같은 식으로 낸다).
static func prop_rect(z: int, X: float, fy: float, ny: float, back: float,
		flat: float, tall: float) -> Rect2:
	var at: Vector3 = BUY_AT if z == 1 else SELL_AT
	var k: float = BUY_K if z == 1 else SELL_K
	var sh: float = lean(at, X, (ny - fy) / flat, back)
	var r := Rect2()
	var first := true
	for q in (BUY_HULL if z == 1 else SELL_HULL):
		var v: Vector3 = q
		var s := Vector2(at.x + (v.x + sh * v.z) * k,
				fy + (at.z + v.z * k) * flat - (at.y + v.y * k) * tall)
		if first:
			r = Rect2(s, Vector2.ZERO)
			first = false
		else:
			r = r.expand(s)
	return r


static func make_table(host: Node, r: Rect2, fy: float, ny: float, back: float,
		flat: float, tall: float, pitch_deg: float) -> SubViewport:
	_fl = flat
	_tl = tall
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
	we.environment = lamp_env()
	root.add_child(we)

	var W: float = (ny - fy) / flat          # 벨벳 깊이(면 단위)
	var X: float = r.size.x
	var brass := _mat(COL.brass, 0.3, 0.55)

	# ── 나무 그림 — 화면 1px = 1텍셀. 판자(이음 · 못) 하나, 통나무(결만) 둘 ──
	var tw: int = int(X + TEX_U * 2.0)
	var tex := Vector2(tw, 256)
	var plank := _varnish(_plank(tw, 256, WOOD.plank, 41))
	var ledge := _varnish(_plank(tw, 256, WOOD.ledge, 43, 64, 64, false))
	var ledge_f := _varnish(_plank(tw, 256, WOOD.ledge.darkened(0.30), 47, 64, 64, false))

	# ── 벨벳 — 사다리꼴 한 장. 물건이 눕는 면(h 0) 그대로다 ──
	var vel := _mat(COL.velvet, 1.0)
	#  보풀 — 1~2px 잔결이 밝기 ±15%. 매끈하면 천이 아니라 칠이다.
	vel.albedo_texture = _noise_tex(0.9, 0.7, 1.0, 7)
	vel.uv1_scale = Vector3(5.0, 5.0, 1.0)
	root.add_child(_quad([Vector3(back, 0.0, 0.0), Vector3(X - back, 0.0, 0.0),
			Vector3(X, 0.0, W), Vector3(0.0, 0.0, W)], vel))

	# ── 옆 카운터 — 옛 창구 자리. 니스 칠한 밤나무 판자, 벨벳보다 한 단 위 ──
	root.add_child(_face([Vector3(-TEX_U, TOP_H, -2.0), Vector3(back, TOP_H, -2.0),
			Vector3(0.0, TOP_H, W), Vector3(-TEX_U, TOP_H, W)], plank, Vector3.UP, tex))
	root.add_child(_face([Vector3(X - back, TOP_H, -2.0), Vector3(X + TEX_U, TOP_H, -2.0),
			Vector3(X + TEX_U, TOP_H, W), Vector3(X, TOP_H, W)], plank, Vector3.UP, tex))

	# ── 조각 틀 — 빗변 몰딩(나무 두 단) + 벨벳 쪽 금실 + 모서리 놋쇠 갓 ──
	var carve := _mat(WOOD.carve, 0.45)
	carve.albedo_texture = _noise_tex(0.08, 0.7, 1.0, 21)
	var bead := _mat(WOOD.beam, 0.3)
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

	# ── 먼 턱 — 상인 앞 카운터 끝. 니스 칠한 통나무 갓 · 이빨 장식 · 놋쇠 줄 ──
	root.add_child(_face([Vector3(-TEX_U, 8.0, 0.0), Vector3(X + TEX_U, 8.0, 0.0),
			Vector3(X + TEX_U, 0.0, 0.0), Vector3(-TEX_U, 0.0, 0.0)], ledge_f, Vector3.BACK, tex))
	#  갓 — 앞으로 1.5 내민 윗판(윗면 · 앞면)과 그 앞 놋쇠 줄
	_slab(root, -TEX_U, X + TEX_U, -14.0, 1.5, 8.0, 10.4, ledge, ledge_f, tex)
	root.add_child(_box(Vector3(X + 40.0, 0.9, 1.0), Vector3(X * 0.5, 10.2, 1.0), brass))
	#  이빨 장식(덴틸) — 갓 밑에 작은 토막이 6 간격으로
	var dent := _mat(WOOD.beam.lightened(0.04), 0.5)
	var du := -14.0
	while du < X + 14.0:
		root.add_child(_box(Vector3(3.0, 3.6, 1.4), Vector3(du, 5.6, 0.5), dent))
		du += 6.0
	#  벨벳 먼 끝 금실
	root.add_child(_box(Vector3(X - back * 2.0, 1.4, 1.4), Vector3(X * 0.5, 0.7, 1.9), brass))

	# ── 가까운 팔걸이 — 둥근 밤나무 난간 + 밑 구슬 줄 ──
	#  윤은 반만 — 더 매끈하면 머리 위 램프가 쇠막대처럼 흰 줄로 비친다.
	var railm := _mat(WOOD.beam, 0.42)
	railm.metallic_specular = 0.35
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

	# ── 앞판 — 짙은 밤나무 판넬(테 · 돋은 판 · 놋쇠 모서리 갓), 화면 아래 끝까지 ──
	var apron := _mat(WOOD.apron, 0.75)
	apron.albedo_texture = _noise_tex(0.04, 0.55, 1.0, 13)
	apron.uv1_scale = Vector3(2.0, 1.0, 1.0)
	root.add_child(_box(Vector3(X + 60.0, 260.0, 4.0), Vector3(X * 0.5, -136.0, W + 16.0), apron))
	var zf: float = W + 18.0
	var frame := _mat(WOOD.ledge, 0.55)
	frame.albedo_texture = _noise_tex(0.05, 0.65, 1.0, 17)
	var field := _mat(WOOD.ledge.darkened(0.15), 0.6)
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

	# ── 소품 — 저울(판매) · 금전등록기(구매) ──
	_scale_prop(root, lean(SELL_AT, X, W, back))
	_register_prop(root, lean(BUY_AT, X, W, back))

	# ── 빛 — 머리 위 램프(빛 웅덩이 · 그림자) + 왼쪽 위 채움빛 + 소품 스포트 ──
	lamp_rig(root, X, W, true)
	#  진열 스포트 — 소품마다 왼쪽 위에서 하나. 옆에 꺼 둔 웅덩이 빛 하나.
	#  반응(prop_glow)이 스포트를 밝히고 웅덩이를 켠다 — 소품과 그 둘레
	#  카운터가 같이 달아올라 「여기」를 말한다(옛 창구 삼각형 칠의 자리).
	prop_lamps(root, true)
	#  니스 반사 — 먼 쪽 높이 램프 넷. 반사점이 소품에 안 가리는 자리로 간다:
	#  저울 왼 앞 · 등록기 오른 옆 카운터, 상인 손 바깥의 먼 턱 갓 둘.
	#  빛 w = 반사점 w − 높이 × 0.78. 맨빛은 약하게, 반사만 세게 — 나무가
	#  밝아지는 게 아니라 윤이 난다. 떨어짐을 무르게(0.5) 둬야 150 거리에서 산다.
	#  이 빛은 니스 나무(층 3)에만 닿는다 — 놋쇠에 닿으면 소품이 하얗게 탄다.
	for mi in root.get_children():
		if mi is MeshInstance3D and (mi as MeshInstance3D).material_override in [plank, ledge, ledge_f]:
			(mi as MeshInstance3D).layers = 1 | WOOD_LAYER
	#  (시안 C — 소품이 커져 옛 반사점(저울 왼 앞 w 38 · 등록기 오른 옆 w 30)이 받침 밑으로
	#  들어갔다. 이름 · 값 줄(y 163~197) 밑 카운터 앞 귀퉁이로 내린다 — 글 뒤에서 번쩍이면
	#  글이 묽어진다.)
	for gl in [["SellGlint", Vector3(8.0, TOP_H, 125.0)], ["BuyGlint", Vector3(632.0, TOP_H, 125.0)],
			["LipGlintL", Vector3(132.0, 10.4, -6.0)], ["LipGlintR", Vector3(X - 132.0, 10.4, -6.0)]]:
		var tg: Vector3 = gl[1]
		var og := OmniLight3D.new()
		og.name = String(gl[0])
		og.light_color = COL.lamp
		og.light_energy = 0.8
		og.light_specular = 3.0
		og.light_cull_mask = WOOD_LAYER
		og.omni_range = 420.0
		og.omni_attenuation = 0.5
		og.position = Vector3(tg.x, tg.y + 150.0, tg.z - 150.0 * 0.78)
		root.add_child(og)
	return vp


#  진열 스포트 둘(SellLamp · BuyLamp) — 소품마다 왼쪽 위에서 좁게. pool 이면 그 옆에 꺼 둔
#  웅덩이 빛(…Pool)도 단다(테이블만 — 반응 prop_glow 가 켠다). 상인 손 무대도 같은 둘을
#  평소 세기로 단다(game.gd _hand3_open) — 판 소품 몸짓(저울 · 등록기)에서 소품에 닿은
#  손이 소품과 같은 빛을 받는다. 없으면 램프 웅덩이 밖이라 손만 어둠 속 갈색 덩어리였다
#  (촬영). 쉬는 손 · 건네받는 손은 이 원뿔 밖이다.
#  시안 C 에서 소품이 두 배라 원뿔도 넓혔다(반지름 47 → 95 언저리) — 램프를 그만큼
#  높이 · 멀리 걸어 빛이 오는 쪽(왼쪽 위)은 그대로다. 저울 원뿔 오른끝 u 150 · 등록기
#  왼끝 u 495 라 쉬는 손(화면 x 190~450)은 여전히 밖이다.
static func prop_lamps(root: Node, pool: bool) -> void:
	for pr in [["SellLamp", SELL_AT + Vector3(16.0, 62.0, 0.0), 19.0],
			["BuyLamp", BUY_AT + Vector3(-8.0, 58.0, 8.0), 19.0]]:
		var ps := SpotLight3D.new()
		ps.name = String(pr[0])
		ps.light_color = COL.lamp
		ps.light_energy = LAMP_E
		ps.spot_range = 420.0
		ps.spot_attenuation = 0.0
		ps.spot_angle = float(pr[2])
		ps.spot_angle_attenuation = 1.6
		#  그림자는 끈다 — 저울대 그림자가 벨벳 왼끝에 검은 얼룩으로 떨어진다.
		#  소품을 바닥에 붙이는 것은 받침 그늘(_blob)이 맡는다.
		ps.shadow_enabled = false
		var tgt: Vector3 = pr[1]
		var at: Vector3 = tgt + Vector3(-70.0, 262.0, -52.0)
		ps.transform = Transform3D(Basis.looking_at(tgt - at, Vector3.UP), at)
		root.add_child(ps)
		if not pool:
			continue
		var po := OmniLight3D.new()
		po.name = String(pr[0]) + "Pool"
		po.light_color = COL.lamp
		po.light_energy = 0.0
		po.omni_range = 86.0
		po.omni_attenuation = 0.0
		po.position = Vector3(tgt.x, TOP_H + 44.0, tgt.z + 30.0)
		root.add_child(po)


#  머리 위 램프 + 왼쪽 위 채움빛. 테이블과 상인 무대(game.gd _stage3_make)가
#  **이 한 벌**을 같이 쓴다 — 두 곳에 따로 적으면 빛을 한 번 만지는 날 상인이
#  테이블 옆에 오려 붙인 사람이 된다(2026-10-02, 상인만 납작한 흰 빛이었다).
#  두 무대는 좌표가 같다(1 월드 단위 = 화면 1px, 면 (u, h, w)) — 램프가 같은
#  자리에 선다. X 화면 폭 · W 벨벳 깊이(면 단위). 그림자는 테이블만 켠다 —
#  상인의 손 그림자는 손 사본을 눕힌 것이라(game.gd _hand3_sync) 램프가 또
#  그리면 두 겹이 된다.
static func lamp_rig(root: Node, X: float, W: float, shadow: bool) -> void:
	var sl := SpotLight3D.new()
	sl.light_color = COL.lamp
	#  빛 웅덩이 — 벨벳 한가운데가 밝고 가장자리가 가라앉는다.
	sl.light_energy = 7.0
	sl.spot_range = 1200.0
	sl.spot_attenuation = 0.2
	sl.spot_angle = 38.0
	sl.spot_angle_attenuation = 2.2
	sl.shadow_enabled = shadow
	sl.position = Vector3(X * 0.5, 360.0, W * 0.5)
	sl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	root.add_child(sl)
	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-46.0, -38.0, 0.0)
	dl.light_energy = 0.30
	dl.light_color = Color("ffd8b0")
	root.add_child(dl)


#  따뜻한 어둠 — 램프 밖은 이 값으로 가라앉는다. 테이블과 상인이 같이 쓴다.
static func lamp_env() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("2c2320")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	return env


#  소품 반응 — 매 틀 _chute_draw 가 부른다. z 0 저울 · 1 금전등록기.
#   k   — 스포트 세기. 0 평소 · 1 한껏 · 음수 = 눌려 가라앉음. col 쪽으로 물든다.
#         0 을 넘으면 그 소품의 놋쇠가 col 빛으로 달아오른다.
#   act — 소품의 몸짓. 저울은 저울대 기울기 그 값이다(0 평소 · 1 안 접시가
#         내려앉음 · 그 너머는 출렁임) — game.gd 가 민다(scale_tilt). 접시에 얹힌
#         동전과 그것을 집는 손이 같은 값으로 접시 자리를 셈해야(pan_top) 동전이
#         접시를 따라가므로, 기울기를 여기서 따로 굴리지 않는다.
#         금전등록기는 서랍이 나온 몫이다(0 닫힘 · 1 다 열림 · 그 너머는 튀어나와
#         넘친 몫) — game.gd 가 민다(reg_open). 내리치는 순간 튀어나와 머물다 미끄러져
#         들어간다. 서랍에서 튀는 동전 · 조각(game.gd 의 판 효과)이 이 값으로 서랍
#         앞끝을 셈하므로(drawer_front) 여기서 따로 굴리지 않는다.
#   fx  — 등록기만. x 값 깃이 솟은 몫(0 → 1 · 넘침) · y 몸이 눌린 몫(+ 눌림 · − 튐) ·
#         z 손바닥 밑 건반이 들어간 몫(0 → 1). 셋 다 game.gd 가 민다(reg_fx · _reg_curve).
#  ⚠ 매 틀 부르므로 새 배열 · 사전을 안 짓는다 — 놋쇠 재질은 노드에 박아 둔
#  메타(glow)를 그대로 읽는다.
static func prop_glow(vp: SubViewport, z: int, k: float, col: Color, act := 0.0,
		fx := Vector3.ZERO) -> void:
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
	var pn: Node3D = root.get_node_or_null("Register" if z == 1 else "Scale")
	if pn == null:
		return
	var e: float = 0.2 * clampf(k, 0.0, 2.0)
	var gm: Material = pn.get_meta("glow")
	var bm := gm as StandardMaterial3D
	if bm != null:
		bm.emission = col if k > 0.0 else COL.lamp
		bm.emission_energy_multiplier = e
	if z == 0:
		_scale_set(pn, clampf(act, -0.6, 1.6))
	else:
		_reg_set(pn, act, fx)


#  등록기 자세 — 서랍 · 값 깃 · 몸 눌림 · 건반(prop_glow 머리말의 act · fx).
#  서랍은 REG_OPEN 만큼 나온다(곱 전 13 = 화면 20px — 옛 6 은 화면 5px 라 「서랍 열린건진도
#  모르겠어」였다). 몸은 받침 바닥 가운데를 축으로 눌린다 — 받침이 카운터에서 안 뜬다.
const REG_OPEN := 13.0
const REG_POP := 4.2          # 값 깃이 솟는 높이(곱 전) — 창 아래 반에서 위 반으로
const REG_SQ := [0.05, 0.085]   # 눌림 1 에서 옆 · 위아래 비
const REG_KEY := 1.1          # 손바닥 밑 건반이 들어가는 깊이(곱 전, 경사면 법선)


static func _reg_set(pn: Node3D, open: float, fx: Vector3) -> void:
	var dr: Node3D = pn.get_node_or_null("Drawer")
	if dr != null:
		dr.position.z = REG_OPEN * maxf(open, 0.0)
	var fl: Node3D = pn.get_node_or_null("Flags")
	if fl != null:
		fl.position.y = REG_POP * fx.x
	var ks: Node3D = pn.get_node_or_null("Keys")
	if ks != null:
		ks.position = -KEY_N.normalized() * REG_KEY * clampf(fx.z, 0.0, 1.0)
	var x0: Transform3D = pn.get_meta("xf0")
	var j: float = clampf(fx.y, -1.0, 1.0)
	pn.transform = Transform3D(x0.basis * Basis.from_scale(Vector3(1.0 + float(REG_SQ[0]) * j,
			1.0 - float(REG_SQ[1]) * j, 1.0 + float(REG_SQ[0]) * j)), x0.origin)


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


#  막대 하나 — a 에서 b 까지(어느 방향이든). 매단 사슬 · 손잡이 · 바늘.
static func _rod(a: Vector3, b: Vector3, t: float, m: Material) -> MeshInstance3D:
	var v: Vector3 = b - a
	var mi := _box(Vector3(t, v.length(), t), (a + b) * 0.5, m)
	var y: Vector3 = v.normalized()
	var x: Vector3 = y.cross(Vector3.BACK)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	mi.basis = Basis(x, y, x.cross(y))
	return mi


#  저울 — 판매. 놋쇠 발 넷 위 나무 받침 두 단(놋쇠 띠 · 앞 놋쇠 패) · 놋쇠 기둥(허리
#  고리 둘) · 바늘 · 저울대(Arm) · 사슬 셋에 매단 접시 둘(PanL · PanR). 기둥이 먼 턱
#  위로 솟는다 — 키가 곧 실루엣이다.
#  ── 시안 C — 판 동전은 **안 접시**(PanR)에 얹힌다 (2026-10-02) ──
#  저울이 화면 왼끝에 걸치면서 바깥 접시(PanL)는 반 넘게 화면 밖이다. 동전이 그리로
#  가면 반쯤 잘려 보이고 상인 손도 팔 길이 밖이다. 그래서 추 둘을 바깥 접시로 옮기고
#  동전은 상인 쪽 안 접시에 얹는다 — 평소에는 추 쪽(바깥)이 내려앉아 있고, 팔 것을
#  대면 안 접시가 내려간다(prop_glow). 기울기 폭을 ±8° 에서 +12° / −16° 로 넓혔다 —
#  곱이 두 배여도 옛 각이면 접시 끝이 화면 4px 만 오르내려 「달았다」가 안 보였다.
#  이제 평소 ↔ 얹힘이 안 접시에서 화면 13px 이다.
const SCALE_PIV := Vector3(0.0, 56.0, 0.0)
const SCALE_HL := 22.0                          # 저울대 반 길이
const SCALE_TILT := [12.0, -16.0]               # 평소(추 쪽 · 바깥) · 팔 것을 댄 때(안 접시)(도)


static func _scale_prop(root: Node3D, sh: float) -> void:
	var n := _prop_node(root, "Scale", SELL_AT, SELL_K, sh)
	var brass := _brass()
	var brass_dk := _mat(COL.brass.darkened(0.45), 0.5, 0.4)
	var pan_in := _mat(COL.brass.darkened(0.6), 0.7, 0.3)
	var wood := _mat(WOOD.carve, 0.4)
	var wood2 := _mat(WOOD.beam, 0.35)
	n.set_meta("glow", brass)
	n.add_child(_blob(Vector2(44.0, 26.0), Vector3(3.0, 0.15, 3.0), 0.75))
	#  받침 — 놋쇠 발 넷 위에 두 단. 아래 단 앞에 놋쇠 패 하나(큰 몸에서 받침이 민짜면
	#  나무 토막으로 읽힌다).
	for fx in [-13.0, 13.0]:
		for fz in [-6.0, 6.0]:
			n.add_child(_ball(1.4, Vector3(fx, 1.0, fz), brass))
	n.add_child(_box(Vector3(32.0, 3.0, 17.0), Vector3(0.0, 3.2, 0.0), wood))
	n.add_child(_box(Vector3(10.0, 1.6, 0.3), Vector3(0.0, 3.2, 8.6), brass))
	n.add_child(_box(Vector3(32.8, 0.8, 17.8), Vector3(0.0, 5.0, 0.0), brass))
	n.add_child(_box(Vector3(25.0, 2.6, 12.0), Vector3(0.0, 6.7, 0.0), wood2))
	n.add_child(_cyl(4.6, 7.4, 3.0, Vector3(0.0, 9.5, 0.0), brass, 14))
	n.add_child(_cyl(2.0, 2.5, 45.0, Vector3(0.0, 33.5, 0.0), brass, 10))
	#  기둥 허리 고리 둘 — 매끈한 막대보다 깎은 놋쇠로 읽힌다
	for ry in [20.0, 44.0]:
		n.add_child(_cyl(3.0, 3.0, 1.6, Vector3(0.0, float(ry), 0.0), brass, 12))
	var piv: Vector3 = SCALE_PIV
	#  (기둥 앞 둥근 눈금판은 찍어 보니 기둥 위 머리로 읽혀 걷었다 — 바늘만 남긴다.)
	n.add_child(_ball(3.2, piv, brass))
	n.add_child(_cyl(0.4, 1.8, 7.0, piv + Vector3(0.0, 5.5, 0.0), brass, 8))
	n.add_child(_ball(2.0, piv + Vector3(0.0, 9.6, 0.0), brass))
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = piv
	n.add_child(arm)
	arm.add_child(_box(Vector3(SCALE_HL * 2.0, 2.8, 2.8), Vector3.ZERO, brass))
	#  저울대 윗등 — 가는 짙은 줄. 두 배 몸에서 민 막대는 놋쇠 관이 아니라 각목이다.
	arm.add_child(_box(Vector3(SCALE_HL * 2.0 - 6.0, 0.5, 2.9), Vector3(0.0, 1.0, 0.0), brass_dk))
	arm.add_child(_rod(Vector3(0.0, -1.0, 4.0), Vector3(0.0, -13.0, 4.0), 1.0, brass_dk))   # 바늘
	for sd in [-1.0, 1.0]:
		var s: float = float(sd)
		arm.add_child(_ball(2.0, Vector3(s * SCALE_HL, 0.0, 0.0), brass))
		var pan := Node3D.new()
		pan.name = "PanL" if s < 0.0 else "PanR"
		n.add_child(pan)
		#  사슬 셋 — 고리(저울대 끝)에서 접시 테 세 점으로
		pan.add_child(_ball(0.9, Vector3(0.0, -1.2, 0.0), brass_dk))
		for k in 3:
			var a: float = TAU * float(k) / 3.0 + PI * 0.5
			pan.add_child(_rod(Vector3.ZERO, Vector3(cos(a) * 8.6, -24.6, sin(a) * 6.0), 0.9, brass_dk))
		pan.add_child(_cyl(10.0, 5.8, 3.0, Vector3(0.0, -26.0, 0.0), brass, 20))
		#  안판 — 테 안쪽 짙고 덜 반짝이는 원판. 두 배 접시가 한 빛깔이면 접시가 아니라
		#  금빛 원반(뚜껑)으로 읽힌다 — 밝은 테 띠(10 → 8.2)와 짙은 속이 「오목한 접시」다.
		pan.add_child(_cyl(8.2, 8.2, 0.4, Vector3(0.0, -24.3, 0.0), pan_in, 20))
		if s < 0.0:
			#  추 둘 — 큰 것 하나에 꼭지, 작은 것 하나(바깥 접시)
			pan.add_child(_cyl(3.0, 3.0, 3.8, Vector3(2.0, -22.8, 0.0), brass, 12))
			pan.add_child(_ball(1.1, Vector3(2.0, -20.4, 0.0), brass))
			pan.add_child(_cyl(2.1, 2.1, 2.6, Vector3(-3.6, -23.4, 0.8), brass, 12))
	_scale_set(n, 0.0)


#  안 접시 윗면 — 접시 노드에서 그 밑 놋쇠 판(−26 · 높이 3)과 짙은 안판(−24.3 · 0.4)의
#  윗면. 판 동전이 여기 눕는다(pan_top).
const PAN_TOP := -24.1


#  안 접시(PanR) 윗면 한가운데 — 면 좌표 (u, h, w). a 는 저울대 기울기(_scale_set 과 같은 값).
#  game.gd 의 판매 몸짓(_prop_*)이 판 동전과 그것을 집는 손을 여기 세운다 — 접시를 짓는
#  _scale_prop 과 같은 상수 · 같은 기울임(lean)이라 그림과 한 점도 안 갈린다.
#  X 화면 폭 · fy · ny 벨벳 먼/가까운 모서리 · back 빗변 · flat 시점(make_table 과 같다).
static func pan_top(X: float, fy: float, ny: float, back: float, flat: float, a: float) -> Vector3:
	var sh: float = lean(SELL_AT, X, (ny - fy) / flat, back)
	var t: float = deg_to_rad(lerpf(float(SCALE_TILT[0]), float(SCALE_TILT[1]), a))
	var p: Vector3 = SCALE_PIV + Vector3(SCALE_HL * cos(t), SCALE_HL * sin(t) + PAN_TOP, 0.0)
	return SELL_AT + Vector3((p.x + sh * p.z) * SELL_K, p.y * SELL_K, p.z * SELL_K)


#  저울대 기울기 — a 0 평소(추 쪽 바깥 접시가 내려앉음) · 1 팔 것을 댄 때(안 접시).
#  접시는 저울대 끝에 매달려 늘 수직으로 선다.
static func _scale_set(n: Node3D, a: float) -> void:
	var t: float = deg_to_rad(lerpf(float(SCALE_TILT[0]), float(SCALE_TILT[1]), a))
	var arm: Node3D = n.get_node_or_null("Arm")
	if arm != null:
		arm.rotation = Vector3(0.0, 0.0, t)
	for nm in ["PanL", "PanR"]:
		var p: Node3D = n.get_node_or_null(nm)
		if p != null:
			var s: float = -1.0 if nm == "PanL" else 1.0
			p.position = SCALE_PIV + Vector3(s * SCALE_HL * cos(t), s * SCALE_HL * sin(t), 0.0)


#  건반판 — 왼 앞 · 왼 뒤 모서리(오른쪽은 u 를 뒤집는다)와 경사면 법선(정규화 전).
#  건반 알 하나의 자리(_key_at)를 짓는 자리와 상인이 내리치는 자리(slam_top)가 같이 읽는다.
const KEY_B0 := Vector3(-16.2, 11.0, 15.0)
const KEY_B3 := Vector3(-16.2, 29.0, 1.5)
const KEY_N := Vector3(0.0, 13.5, 18.0)
const KEY_CAP := 1.7          # 알 윗면 — 경사면에서 법선으로(테 0.6 · 알 1.4 를 1.0 에 앉힌 끝)
#  내리치는 손바닥 밑 — 뒤 두 줄(row 1 · 2) 왼쪽 세 칸(col 0~2). 이 여섯이 Keys 노드에
#  들어가 같이 눌린다(_reg_set). 손바닥 한가운데는 뒤 줄 col 0 · 1 사이다(SLAM_AT).
const SLAM_KEYS := [[1, 0], [1, 1], [1, 2], [2, 0], [2, 1], [2, 2]]
const SLAM_AT := Vector2(2.0, 0.5)      # (줄 · 칸) — 칸은 사이값이다


#  건반 알 하나의 바닥 가운데(등록기 제 좌표). row 0 앞(손님 쪽) → 2 뒤 · col 0 왼 → 4 오른.
static func _key_at(row: float, col: float) -> Vector3:
	var p0: Vector3 = KEY_B0.lerp(KEY_B3, 0.2 + row * 0.3)
	return Vector3(-12.0 + col * 6.0, p0.y, p0.z)


#  내리치는 자리 — 손바닥이 닿는 건반 윗면 한가운데, 면 좌표 (u, h, w). game.gd 의 구매
#  몸짓(내리치기)이 상인 손바닥을 여기 세운다. 등록기를 짓는 식(_prop_node 의 기울임 ·
#  BUY_K)과 같다 — pan_top 과 같은 까닭. 눌림(_reg_set 의 몸 눌림)은 안 탄다 — 손이
#  닿는 그 틀에 몸이 눌리기 시작한다.
static func slam_top(X: float, fy: float, ny: float, back: float, flat: float) -> Vector3:
	var sh: float = lean(BUY_AT, X, (ny - fy) / flat, back)
	var p: Vector3 = _key_at(SLAM_AT.x, SLAM_AT.y) + KEY_N.normalized() * KEY_CAP
	return BUY_AT + Vector3((p.x + sh * p.z) * BUY_K, p.y * BUY_K, p.z * BUY_K)


#  서랍 앞끝 한가운데 — 면 좌표 (u, h, w). open 은 서랍이 나온 몫(prop_glow 의 act).
#  game.gd 의 판 효과(동전 · 조각)가 여기서 튄다 — 열린 서랍 안에서 나와야 하므로
#  앞판보다 조금 안(w −3) · 서랍 윗면 높이다.
static func drawer_front(X: float, fy: float, ny: float, back: float, flat: float,
		open: float) -> Vector3:
	var sh: float = lean(BUY_AT, X, (ny - fy) / flat, back)
	var p := Vector3(0.0, 8.4, 16.8 - 3.0 + REG_OPEN * maxf(open, 0.0))
	return BUY_AT + Vector3((p.x + sh * p.z) * BUY_K, p.y * BUY_K, p.z * BUY_K)


#  금전등록기 — 구매. 나무 서랍장(놋쇠 띠 · 앞 모서리 갓 · 서랍 · 손잡이) 위 청동 몸통
#  (놋쇠 기둥 둘 · 위 띠), 앞으로 기운 건반판(둥근 상아 알 셋 줄 다섯 칸 · 알마다 먹 점),
#  위에 값 창(어두운 유리 안 상아 깃 셋), 반달 볏과 꼭지, 오른 옆구리 손잡이.
#  ── 시안 C (2026-10-02) ──
#  산 순간 상인이 건반을 내리친다 — 몸이 눌렸다 튀고, 손바닥 밑 건반 여섯이 들어가고,
#  서랍이 화면 20px 튀어나와 칸막이 쟁반의 동전을 보이고, 값 깃이 창 위 반으로 솟는다
#  (prop_glow · _reg_set). 동전 · 나뭇조각 · 놋쇠 부스러기는 game.gd 가 그린다.
#  깊이를 옛 몸보다 줄였다(서랍장 −16..18 → −14..16 · 창과 볏 −11 → −9.5) — 깊이는
#  화면 0.788 배 · 키는 0.616 배라, 같은 화면 높이 안에서 곱을 더 받으려면 깊이를 덜어야
#  한다. 닫힌 서랍 앞끝이 y 159 · 볏 꼭지가 y 52 다(머리말 「시안 C」).
static func _register_prop(root: Node3D, sh: float) -> void:
	var n := _prop_node(root, "Register", BUY_AT, BUY_K, sh)
	n.set_meta("xf0", n.transform)
	var wood := _mat(WOOD.carve, 0.4)
	var wood2 := _mat(WOOD.beam, 0.35)
	var wood3 := _mat(WOOD.carve.darkened(0.25), 0.6)
	var body := _mat(COL.bronze.darkened(0.55), 0.45, 0.6)
	body.albedo_texture = _noise_tex(0.35, 0.78, 1.0, 31)
	var slope := _mat(COL.bronze.darkened(0.72), 0.5, 0.45)
	var brass := _brass()
	var ivory := _mat(COL.ivory, 0.5)
	var ink := _mat(Color("1a1210"), 0.6)
	var glass := _mat(COL.glass, 0.15)
	var coin := _mat(COL.brass.lightened(0.18), 0.3, 0.6)
	n.set_meta("glow", brass)
	n.add_child(_blob(Vector2(54.0, 40.0), Vector3(3.0, 0.15, 3.0), 0.75))
	#  서랍장 (u ±20 · h 0..10 · w −14..16) + 윗모서리 놋쇠 띠 · 앞 두 모서리 놋쇠 갓
	n.add_child(_box(Vector3(40.0, 10.0, 30.0), Vector3(0.0, 5.0, 1.0), wood))
	n.add_child(_box(Vector3(41.0, 0.8, 31.0), Vector3(0.0, 10.4, 1.0), brass))
	for sx in [-1.0, 1.0]:
		n.add_child(_box(Vector3(2.4, 10.0, 1.2), Vector3(float(sx) * 19.4, 5.0, 16.2), brass))
	#  서랍 — 서랍장 안에 숨어 있다가 앞으로 미끄러진다(REG_OPEN). 안은 칸막이 쟁반이고
	#  칸마다 동전이 누웠다 — 열리면 보인다.
	var dr := Node3D.new()
	dr.name = "Drawer"
	n.add_child(dr)
	dr.add_child(_box(Vector3(34.0, 6.4, 27.0), Vector3(0.0, 4.6, 2.5), wood2))
	dr.add_child(_box(Vector3(35.0, 7.0, 0.8), Vector3(0.0, 4.6, 16.4), wood2))
	dr.add_child(_box(Vector3(9.0, 1.6, 1.2), Vector3(0.0, 5.6, 17.2), brass))
	for sx in [-12.0, 12.0]:
		dr.add_child(_ball(0.8, Vector3(float(sx), 5.0, 16.9), brass))
	#  칸막이 — 가로 하나 · 세로 셋. 서랍 윗면(h 7.8) 위로 0.6 솟는다.
	dr.add_child(_box(Vector3(32.0, 1.2, 0.6), Vector3(0.0, 8.0, 8.5), wood3))
	for cx in [-8.0, 0.0, 8.0]:
		dr.add_child(_box(Vector3(0.6, 1.2, 12.0), Vector3(float(cx), 8.0, 9.5), wood3))
	for c in [[-12.5, 5.5, 0], [-12.0, 12.5, 1], [-4.0, 6.0, 1], [-4.5, 12.0, 0],
			[4.0, 5.5, 0], [4.5, 12.5, 1], [12.0, 6.0, 1], [12.5, 12.0, 0]]:
		var cu: float = float(c[0])
		var cw: float = float(c[1])
		dr.add_child(_cyl(2.6, 2.6, 0.8, Vector3(cu, 8.2, cw), coin, 12))
		if int(c[2]) == 1:
			dr.add_child(_cyl(2.6, 2.6, 0.8, Vector3(cu + 0.6, 9.0, cw - 0.4), coin, 12))
	#  몸통 (u ±18 · h 10.8..31 · w −13.5..1.5)
	n.add_child(_box(Vector3(36.0, 20.2, 15.0), Vector3(0.0, 20.9, -6.0), body))
	#  앞 기둥 둘 · 위 띠 — 놋쇠 테가 몸통 모서리를 짚는다
	for sx in [-1.0, 1.0]:
		n.add_child(_box(Vector3(2.4, 20.2, 2.4), Vector3(float(sx) * 17.4, 20.9, 0.8), brass))
	n.add_child(_box(Vector3(37.6, 1.6, 16.2), Vector3(0.0, 31.6, -6.0), brass))
	#  건반판 — 몸통 앞(w 1.5, h 29)에서 서랍장 위 앞(w 15, h 11)까지 기운 면
	var b0: Vector3 = KEY_B0
	var b1 := Vector3(-KEY_B0.x, KEY_B0.y, KEY_B0.z)
	var b2 := Vector3(-KEY_B3.x, KEY_B3.y, KEY_B3.z)
	var b3: Vector3 = KEY_B3
	n.add_child(_quad([b0, b1, b2, b3], slope))
	#  건반 — 둥근 상아 알을 검은 테에 앉힌다. 경사면 법선으로 세운다(알마다 먹 점을 찍어
	#  봤더니 두 배 몸에서 도넛 · 눈알로 읽혀 걷었다). 손바닥 밑 여섯(SLAM_KEYS)은 Keys
	#  노드에 들어가 같이 눌린다.
	var nrm: Vector3 = KEY_N.normalized()
	var kx: float = atan2(nrm.z, nrm.y)
	var keys := Node3D.new()
	keys.name = "Keys"
	n.add_child(keys)
	for row in 3:
		for col in 5:
			var host: Node3D = keys if [row, col] in SLAM_KEYS else n
			var at := _key_at(float(row), float(col))
			var rim := _cyl(2.2, 2.2, 0.6, at + nrm * 0.3, ink, 12)
			rim.rotation = Vector3(kx, 0.0, 0.0)
			host.add_child(rim)
			var key := _cyl(1.6, 1.6, 1.4, at + nrm * 1.0, ivory, 12)
			key.rotation = Vector3(kx, 0.0, 0.0)
			host.add_child(key)
	#  값 창 — 놋쇠 틀에 어두운 유리, 그 앞에 상아 값 깃 셋(깃마다 숫자 획). 평소 깃은 창
	#  아래 반에 앉아 있고 산 순간 위 반으로 솟는다(REG_POP).
	n.add_child(_box(Vector3(30.0, 12.6, 5.0), Vector3(0.0, 38.7, -9.5), brass))
	n.add_child(_box(Vector3(24.0, 8.4, 0.6), Vector3(0.0, 38.7, -6.8), glass))
	var fl := Node3D.new()
	fl.name = "Flags"
	n.add_child(fl)
	for fx in [-7.0, 0.0, 7.0]:
		fl.add_child(_box(Vector3(5.6, 4.2, 0.5), Vector3(float(fx), 36.6, -6.3), ivory))
		fl.add_child(_box(Vector3(1.0, 2.6, 0.3), Vector3(float(fx) - 0.9, 36.6, -5.95), ink))
		fl.add_child(_box(Vector3(1.0, 2.6, 0.3), Vector3(float(fx) + 1.1, 36.6, -5.95), ink))
	#  반달 볏 — 축이 w 인 원통의 윗반만 틀 위로 나온다. 안에 짙은 메달.
	var crest := _cyl(10.0, 10.0, 3.6, Vector3(0.0, 45.0, -9.5), brass, 24)
	crest.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	n.add_child(crest)
	var med := _cyl(6.0, 6.0, 3.9, Vector3(0.0, 45.0, -9.5), slope, 18)
	med.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	n.add_child(med)
	n.add_child(_ball(2.2, Vector3(0.0, 56.4, -9.5), brass))
	#  손잡이 — 오른 옆구리 축에서 비스듬히 내려온 자루와 나무 손잡이 알
	n.add_child(_ball(3.0, Vector3(19.2, 21.0, -6.0), brass))
	n.add_child(_rod(Vector3(20.4, 21.0, -6.0), Vector3(23.6, 12.6, -6.0), 1.8, brass))
	n.add_child(_ball(2.2, Vector3(23.8, 11.8, -6.0), wood2))
	_reg_set(n, 0.0, Vector3.ZERO)


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
