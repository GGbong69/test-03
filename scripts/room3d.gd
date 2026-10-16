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

const ROOM_PX := Vector2i(320, 180)     # 방은 반 해상도 — 두 배로 붙인다(16:9 일 때의 크기)
const ROOM_FOV := 50.0                    # 16:9 에서의 세로 시야(도)
#  ── 16:9 가 아닌 화면 (2026-10-08) ──────────────────────────
#  방 화판은 화면 비 그대로 굽는다(room_fit) — 16:9 로 구운 것을 온 화면에 늘여 붙이면 21:9 에서
#  술병 · 간판이 옆으로 퍼지고 4:3 에서 위아래로 늘었다. 넓은 화면은 세로 시야를, 높은 화면은
#  가로 시야를 16:9 그대로 지킨다 — 가운데 640x360 은 한 점도 안 바뀌고 남는 쪽에 방이 더 보인다.
#  테이블은 카운터 · 턱 · 난간 · 앞판을 양옆으로 TBL_EXT 씩 더 짓는다 — 화판(table_fit)이 화면 끝까지
#  넓어지면 카운터가 거기까지 이어진다. 벨벳은 넓어진 만큼(wide — 부르는 쪽이 side 를 줄여 넘긴다) 양옆으로
#  넓어지고 저울 · 등록기도 같이 바깥으로 간다(2026-10-14 — 옛 판은 벨벳이 640 그대로였다).
const TBL_EXT := 400.0

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


#  벽에 거는 다트판 — 게임 판과 같은 물건이다(game.gd 칸 C_LIGHT · C_DARK · 띠 C_RED · C_GREEN ·
#  숫자 고리 BOARDART.ring_col · 테 BOARDART.edge). 20 이 흑색 · 흑색 칸에 빨강 띠 — 실물 배색.
#  고리 바깥에 밝은 테(화면 1px 남짓 · 왼쪽 위가 빛을 받는다) — 고리(옛 1a1714)와 받침(15100d)이
#  거의 같아 판 모양 없이 얼룩으로 읽혔다. 옛 그림은 띠도 빨강 · 파랑인 다른 판이었다(점검,
#  2026-10-16). 띠 경계 철선은 안 긋는다 — 화면 판 지름 45px 남짓에서 1텍셀 철선은 성긴 점으로
#  흩어지고 굵히면 띠를 먹는다. 상점 뒷벽과 술집 안 다트 장(door3d)이 이 한 장을 쓴다. 숫자 점은
#  멀리서 시계로 읽혀 안 찍는다. n — 한 변 텍셀(nearest 로 줄어 찍히므로 화면 크기 언저리로).
static func board_img(n: int) -> ImageTexture:
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
				col = Color("1f1719")
				if r > 0.94:
					var lit: float = maxf(d.normalized().dot(Vector2(-0.6, -0.8)), 0.0)
					col = Color("4a4446").lerp(Color("c9bfae"), lit * 0.55)
			if r <= 0.80:
				col = Color("2b2438") if sec % 2 == 0 else Color("e8dfc8")
				if (r > 0.72 and r <= 0.80) or (r > 0.44 and r <= 0.50):
					col = Color("d8483d") if sec % 2 == 0 else Color("479a58")
			if r <= 0.10:
				col = Color("479a58")
			if r <= 0.05:
				col = Color("d8483d")
			im.set_pixel(x, y, col)
	return ImageTexture.create_from_image(im)


# ══ 방 ══════════════════════════════════════════════════════
const BOTTLE_COLS := [Color("b5651d"), Color("2f6b3a"), Color("8fb8d8"), Color("7a1f2b"),
		Color("d4a017"), Color("3b2b6b")]


#  뒤 선반 셋의 술병 — {x, sy(선반 높이), h, r, c(BOTTLE_COLS 번호), s(선반)}. 씨가 고정이라
#  늘 같다 — 방(make_room)과 게임(술병 깨기 · 헤드리스에서도)이 같은 표를 읽는다.
#  뽑는 차례(높이 · 굵기 · 색 · 틈)가 옛 make_room 그대로라 자리가 한 병도 안 바뀌었다.
static func bottle_layout() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261001
	var out := []
	for s in 3:
		var sy: float = 1.15 + float(s) * 0.48
		var x := -2.15
		while x < 2.15:
			var bh: float = rng.randf_range(0.22, 0.34)
			var br: float = rng.randf_range(0.04, 0.065)
			var ci: int = rng.randi() % BOTTLE_COLS.size()
			out.append({"x": x, "sy": sy, "h": bh, "r": br, "c": ci, "s": s})
			x += br * 2.0 + rng.randf_range(0.03, 0.12)
	return out


#  술병 윤곽 셋(반지름 1 · 키 1 — 병마다 늘린다) — 포도주(높은 어깨 · 긴 목 · 입술) · 위스키(각진
#  어깨 · 짧은 목 · 굵은 마개) · 리큐어(둥근 어깨). 라벨 띠 · 목 캡도 같은 셋.
const BTL_PROF := [
	[Vector2(0.0, 0.0), Vector2(0.95, 0.0), Vector2(1.0, 0.04), Vector2(1.0, 0.6), Vector2(0.93, 0.68),
		Vector2(0.7, 0.75), Vector2(0.44, 0.8), Vector2(0.36, 0.85), Vector2(0.36, 0.94),
		Vector2(0.44, 0.95), Vector2(0.44, 0.99), Vector2(0.0, 1.0)],
	[Vector2(0.0, 0.0), Vector2(0.96, 0.0), Vector2(1.0, 0.03), Vector2(1.0, 0.68), Vector2(0.82, 0.74),
		Vector2(0.42, 0.78), Vector2(0.4, 0.88), Vector2(0.0, 0.88)],
	[Vector2(0.0, 0.0), Vector2(0.9, 0.0), Vector2(1.0, 0.06), Vector2(1.0, 0.45), Vector2(0.95, 0.56),
		Vector2(0.78, 0.66), Vector2(0.5, 0.73), Vector2(0.33, 0.78), Vector2(0.33, 0.93),
		Vector2(0.42, 0.95), Vector2(0.4, 1.0), Vector2(0.0, 1.0)]]
const BTL_LABEL := [[Vector2(1.04, 0.24), Vector2(1.04, 0.44)], [Vector2(1.04, 0.22), Vector2(1.04, 0.5)],
		[Vector2(1.04, 0.16), Vector2(1.04, 0.34)]]
const BTL_FOIL := [[Vector2(0.4, 0.84), Vector2(0.47, 0.95), Vector2(0.47, 1.0), Vector2(0.0, 1.01)],
		[Vector2(0.52, 0.86), Vector2(0.52, 1.0), Vector2(0.0, 1.01)],
		[Vector2(0.36, 0.86), Vector2(0.44, 0.95), Vector2(0.44, 1.0), Vector2(0.0, 1.01)]]


#  유리 빛줄 — 병 둘레(회전체 u)의 왼 앞(108~137°)만 밝은 빛 그림. 나머지는 옛 은은한 빛(0.25) 그대로.
static func _btl_stripe() -> ImageTexture:
	var im := Image.create(16, 1, false, Image.FORMAT_RGBA8)
	im.fill(Color(0.33, 0.33, 0.33))
	im.fill_rect(Rect2i(5, 0, 2, 1), Color.WHITE)
	return ImageTexture.create_from_image(im)


#  술병 k 를 보이거나 숨긴다(깬 병).
static func bottle_show(vp: SubViewport, k: int, on: bool) -> void:
	var root := vp.get_node_or_null("Room")
	if root == null:
		return
	var parts: Array = root.get_meta("bottles", [])
	if k < 0 or k >= parts.size():
		return
	for n in parts[k]:
		(n as Node3D).visible = on


#  술병 k 의 몸 한가운데가 방 화판(vp 화소)의 어디에 서는가 — 카메라가 흔들리는 그대로.
static func bottle_px(vp: SubViewport, b: Dictionary) -> Vector2:
	var cam := vp.get_node_or_null("Room/Cam") as Camera3D
	if cam == null:
		return Vector2(-1.0, -1.0)
	var at := Vector3(float(b.x), float(b.sy) + 0.025 + float(b.h) * 0.5, -2.32)
	return cam.unproject_position(at)


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
	cam.fov = ROOM_FOV
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
	#  벽 · 천장 · 바닥 폭 40 — 32:9 에서도 끝이 안 보인다(room_fit 머리말).
	root.add_child(_box(Vector3(40.0, 5.0, 0.2), Vector3(0.0, 2.0, -2.6), wall))
	#  판자 이음 — 세로 줄을 몇 줄 앞에 세운다.
	for k in range(-36, 37):
		root.add_child(_box(Vector3(0.025, 5.0, 0.02), Vector3(float(k) * 0.55, 2.0, -2.49),
				_mat(COL.wall.darkened(0.35))))
	#  허리 몰딩
	root.add_child(_box(Vector3(40.0, 0.08, 0.06), Vector3(0.0, 0.95, -2.46), _mat(COL.trim, 0.5)))
	root.add_child(_box(Vector3(40.0, 0.2, 8.0), Vector3(0.0, 3.4, 0.0), _mat(COL.ceil)))
	# 천장 들보
	for k in range(-12, 13):
		root.add_child(_box(Vector3(0.18, 0.16, 6.0), Vector3(float(k) * 1.6, 3.15, 0.0), _mat(COL.wood_dk)))
	root.add_child(_box(Vector3(40.0, 0.2, 8.0), Vector3(0.0, -0.1, 0.0), _mat(Color("140d0b"))))

	# ── 뒤 선반과 술병 ──
	#  술병 자리는 bottle_layout 이 낸다(씨 고정 — 게임의 술병 깨기가 같은 표를 읽는다).
	#  병마다 몸 · 라벨 · 목 캡 세 조각에 번호(meta "bottle")를 달고 방 뿌리에 그 셋을 적는다(bottle_show).
	#  조각은 예전처럼 방 뿌리에 바로 선다 — 위치로 선반을 찾는 도구가 있다.
	var lay := bottle_layout()
	var parts := []
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
	#  2026-10-16 병 윤곽(BTL_PROF) — 옛 병은 8각 원통 몸에 6각 목 막대라 「색 막대」로 읽혔다(점검
	#  z_back). 몸 · 어깨 · 목 · 입술을 돌린 회전체 셋(포도주 · 위스키 · 리큐어)에 라벨 띠(밝은 종이 ·
	#  검은 종이)와 목 캡(금박 · 붉은 · 검은)을 씌우고, 유리 빛줄 하나(_btl_stripe — 왼 앞 세로 줄)를
	#  빛 그림으로 얹는다. 병마다 한 벌인 윤곽(반지름 1 · 키 1)을 몸 · 목 키(h + 0.09) · 굵기로 늘린다
	#  — 메시는 셋씩만 짓는다. 자리 · 키 · 굵기 · 색은 bottle_layout 그대로다(깨기 판정이 같은 표).
	var gms := {}
	var stripe := _btl_stripe()
	var labs := []
	for lc in [Color("b4a47f"), Color("c9bfa4"), Color("1d1916")]:
		var lm := _mat(lc, 0.8)
		lm.emission_enabled = true
		lm.emission = lc
		lm.emission_energy_multiplier = 0.08
		labs.append(lm)
	var foils := [_mat(Color("b08a3a"), 0.35, 0.8), _mat(Color("6e1520"), 0.5), _mat(Color("15110f"), 0.5)]
	for k in lay.size():
		var b: Dictionary = lay[k]
		var ci: int = int(b.c)
		if not gms.has(ci):
			var bc: Color = BOTTLE_COLS[ci]
			var gm := _mat(bc, 0.15, 0.0)
			gm.emission_enabled = true
			gm.emission = bc.lightened(0.25)
			gm.emission_texture = stripe
			gm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			gm.emission_energy_multiplier = 0.75
			gms[ci] = gm
		var ty: int = (k * 7 + ci) % 3
		var at := Vector3(float(b.x), float(b.sy) + 0.025, -2.32)
		var sc := Vector3(float(b.r), float(b.h) + 0.09, float(b.r))
		var body := _lmi("btl%d" % ty, PackedVector2Array(BTL_PROF[ty]), at, gms[ci], 10)
		var lab := _lmi("btl_lab%d" % ty, PackedVector2Array(BTL_LABEL[ty]), at, labs[k % 3], 10)
		var foil := _lmi("btl_foil%d" % ty, PackedVector2Array(BTL_FOIL[ty]), at, foils[(k * 5) % 3], 8)
		for pt in [body, lab, foil]:
			pt.scale = sc
			pt.set_meta("bottle", k)
			root.add_child(pt)
		parts.append([body, lab, foil])
	root.set_meta("bottles", parts)

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
	bm.albedo_texture = board_img(64)
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
#  side — 가까운 모서리에서 벨벳이 시작하는 x(옆 카운터의 앞 폭 · 2026-10-11 「2 : 6 : 2」).
#  back — 먼 모서리에서 벨벳이 거기서 더 들어오는 몫(옛 창구 빗변). 먼 모서리의 벨벳은
#  side + back 에서 시작한다. flat · tall — 52° 시점.
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
#  중 「C 로 바로」. 둘 다 곱을 두 배 언저리(1.1 · 1.05 → 2.0 · 1.9)로 올리고
#  가운데를 화면 끝 쪽으로 밀어 **화면 틀이 몸 한쪽을 자른다** — 저울은 바깥
#  접시가 왼끝에서, 등록기는 오른 반(옆구리 손잡이까지)이 오른끝에서 잘린다.
#  잘린 큰 몸이 「카메라 앞에 놓인 것」으로 읽히는 앞소품의 어법이다.
#  세로는 벽 띠(HUD 밑)에서 옆 카운터까지 한 판을 쓴다:
#    · 위 — 저울 꼭지 y 62 · 등록기 볏 꼭지 y 64. 자금판(y ≤ 58) · 사탕·사진
#      이름(x 80~159 · y ≤ 61) · 동전/다트 꼬리표 · 정보/설정(y ≤ 48) 밑이다(상점).
#      판 고르기(위 띠가 서며 HUD 가 16px 내려와 y ≤ 64)에서도 볏이 정보/설정 뒤로 안 든다.
#    · 아래 — 받침 · 서랍장 앞끝이 y 159~160. 그 밑 카운터에 game.gd 가 이름과
#      값을 쓴다(CHUTE_TXT) — 소품 몸이 글을 안 덮는다.
#    · 옆 — 물건 자리(u 116~524) 밖. 저울 오른끝 u 97 · 등록기 왼끝 u 575.
#  (화면 끝에 걸쳐 잘리는 어법은 2026-10-11 에 걷었다 — 아래 「2 : 6 : 2」.)
#  ── 받침은 온전히 카운터 위 (2026-10-03) ──
#  「수금기가 테이블 끝에 걸터있는데? 좀 위치 조정 해봐」 — 첫 자리(등록기 u 602 · w 9 ·
#  곱 1.95)는 받침 왼쪽이 빗변 조각 틀에 7~10px 올라앉고 뒤끝이 먼 턱 너머(w −18)까지
#  가서 테이블 모서리에 걸터앉은 것으로 읽혔다(저울도 받침 오른 모서리가 틀 위였다).
#  옆 카운터는 먼 턱 쪽이 넓고 앞으로 갈수록 좁아지는 삼각형이라, 받침을 **먼 턱 바로
#  앞(w ≥ 2)**에 붙이고 화면 끝 쪽으로 밀어 앉혔다. 받침 네 귀(SELL_FOOT · BUY_FOOT)가
#    · 조각 틀 안쪽 끝(빗변에서 수직 FRAME_W 7 — 먼 모서리 놋쇠 갓 자리는 CAP_OUT 8.5)에서
#      3 넘게 카운터 쪽이고
#    · 먼 턱 앞끝(LIP_W 1.5)보다 0.5 넘게 앞이다 — shop_probe 「소품 받침이 카운터 위」가
#      foot_clear 로 잰다(되돌아가면 운다).
#  그러려면 등록기가 얕아야 했다 — 받침 뒤끝을 w 2 에 붙이고 앞끝을 이름 줄(y 163.5) 위에
#  세우면 깊이가 화면 32px 뿐이라 옛 몸(깊이 31)은 곱 1.3 까지 줄어야 했다. 그래서 몸을
#  깊이 21 로 다시 짰다(서랍장 −8.5..12.2 · 몸통 9 · 건반판 61°) — 곱은 1.95 → 1.9 만
#  덜었다. 저울은 받침을 좁혔다(32 → 22.8) — 기둥 · 바깥 접시는 그대로라 바깥 접시가 화면
#  왼끝에 그대로 걸친다.
#  깊이는 상인이 닿는 데서 멈춘다 — 저울 안 접시 · 등록기 건반이 팔 길이(위팔 +
#  팔뚝 ≈ 180) 안이라야 판 소품 몸짓이 선다. 앞으로 더 내리면(시안 B) 팔이 못 간다.
#  등록기가 오른쪽으로 21 물러난 몫은 몸이 더 기울고 돌아 메운다(game.gd PROP.b_body).
#  game.gd 의 판정(prop_rect) · 반응(prop_glow)이 이 표를 그대로 읽는다.
#  ── 2 : 6 : 2 — 판매 · 구매를 화면 안으로 (2026-10-11) ─────────────
#  「상점 화면에서 구매랑 판매가 너무 테두리에 있어서 잘 안보인다는 평을 받았어. 테이블 중앙을
#   좀 줄여도 되니까 판매랑 구매가 확실히 보이도록 만들자」. 앞서 받은 바깥 평이 더 또렷했다 —
#  판매 · 가운데 · 구매가 화면 폭의 0.5 : 9 : 0.5 쯤이라 양 끝이 작게 잘려 안 읽히고 손도 잘 안
#  간다, 적어도 2 : 6 : 2 는 되어야 읽히고 다루기 좋다.
#  옛 판은 벨벳이 가까운 모서리에서 화면 폭(u 0 ~ 640)을 다 쓰고 옆 카운터는 먼 모서리에서만
#  80 인 삼각형이었다 — 깊이마다 잰 카운터 폭의 평균이 40(0.6 : 8.8 : 0.6). 소품은 그 삼각형의
#  먼 귀에 서서 화면 끝에 잘렸다(시안 C — 저울은 화면 0 ~ 97 만 · 등록기는 575 ~ 640 만).
#  이제 벨벳을 양옆에서 들인다(game.gd CHUTE) — 가까운 모서리 side 96 · 먼 모서리 side + back
#  138. 옆 카운터는 먼 쪽 138 에서 앞 96 으로 좁아지는 사다리꼴이라 평균 117(1.8 : 6.3 : 1.8)
#  이고, 소품 받침에서 이름 · 값 줄까지(y 128 ~ 199)는 138 ~ 117 — 거기서 2 : 6 : 2 다.
#  빗변은 80 → 42 로 덜 기운다. 물건 자리(game.gd DROP u 140 ~ 500 · 여섯 칸에도 한 칸 50)가
#  가장 좁은 먼 모서리의 벨벳 안에 들어야 해서 먼 쪽은 138 에서 멈춘다. 기울기 · 단추의 원근
#  (game.gd _tbl_vp)은 이 빗변에서 그대로 셈해 나온다.
#  소품은 화면 안으로 들어와 온 몸이 보인다 — 저울 u 32 → 70(화면 5 ~ 135) · 등록기 u 623 →
#  574(529 ~ 621). 곱 · 깊이(w) · 받침 · 몸은 그대로라 세로 자리(저울 꼭지 y 62 · 등록기 볏
#  y 64 · 받침 · 서랍장 앞끝 y 159 · 160)도 그대로다. 상인 쪽으로 38 · 49 다가와 팔은 덜 뻗는다.
#  받침 네 귀는 넓어진 카운터 한가운데라 틀에서 30 · 18 떨어진다(foot_clear).
#  이름 · 값은 그 소품 밑 카운터 한가운데에 선다(game.gd CHUTE_TXT · _chute_txt_cx).
const TOP_H := 3.0                              # 옆 카운터 윗면 — 벨벳보다 한 단 위
const SELL_AT := Vector3(70.0, TOP_H, 24.0)     # 저울 — 왼 카운터 한가운데(2 : 6 : 2)
const BUY_AT := Vector3(574.0, TOP_H, 19.0)     # 금전등록기 — 오른 카운터 한가운데
#  넓은 화면(2026-10-14 「와일드 그니까 양쪽으로 넓은거는 테이블이 넓으면 좋겠어, 판매와 구매도 넓은 만큼
#  양쪽으로 가면 좋겠고」) — 화면이 16:9 보다 넓으면 펠트가 양옆으로 wide 씩 넓어지고(부르는 쪽이 side 를 그만큼
#  줄여 넘긴다) 저울 · 등록기도 그만큼 바깥으로 간다. 소품 자리는 늘 이 둘로 읽는다(game.gd _tbl_wide 가 앉힌다).
static var wide := 0.0


static func sell_at() -> Vector3:
	return SELL_AT - Vector3(wide, 0.0, 0.0)


static func buy_at() -> Vector3:
	return BUY_AT + Vector3(wide, 0.0, 0.0)
const SELL_K := 2.0
const BUY_K := 1.9
#  받침 네 귀 — 곱하기 전 (u, h, w). 저울은 놋쇠 띠(받침에서 가장 넓은 단), 등록기는
#  서랍장 뒤끝과 앞 모서리 놋쇠 갓. foot_clear 가 이 넷을 기울여 카운터에 대 본다.
const SELL_FOOT := [Vector3(-11.4, 0.0, -8.9), Vector3(11.4, 0.0, -8.9),
		Vector3(-11.4, 0.0, 8.9), Vector3(11.4, 0.0, 8.9)]
const BUY_FOOT := [Vector3(-20.6, 0.0, -8.5), Vector3(20.6, 0.0, -8.5),
		Vector3(-20.6, 0.0, 12.2), Vector3(20.6, 0.0, 12.2)]
#  옆 카운터를 막는 것들 — 빗변 조각 틀의 폭(빗변에서 카운터 쪽 수직 거리), 먼 모서리
#  놋쇠 갓이 내민 폭과 그 갓이 덮는 w(그 앞은 틀 폭만), 먼 턱 앞끝 w. make_table 이 틀을
#  이 폭으로 짓는다.
const FRAME_W := 7.0
const CAP_OUT := 8.5
const CAP_WZ := 6.0
const LIP_W := 1.5
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
		Vector3(-11.4, 0.0, -8.9), Vector3(11.4, 0.0, -8.9),
		Vector3(-11.4, 0.0, 8.9), Vector3(11.4, 0.0, 8.9)]
const BUY_HULL := [Vector3(-20.6, 0.0, -8.5), Vector3(20.6, 0.0, -8.5),
		Vector3(-20.6, 0.0, 12.2), Vector3(20.6, 0.0, 12.2),
		Vector3(-17.5, 1.1, 13.3), Vector3(17.5, 1.1, 13.3),
		Vector3(-20.6, 11.6, -9.1), Vector3(20.6, 11.6, -9.1),
		Vector3(26.0, 9.6, -4.0), Vector3(-10.0, 55.0, -5.5), Vector3(10.0, 55.0, -5.5),
		Vector3(0.0, 58.6, -5.5)]
const LAMP_E := 1.5                             # 소품 스포트 평소 세기
const GLINT_SIDE := 0.35                        # 옆 카운터 앞 니스 반사 세기(먼 턱은 3) — make_table

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


#  소실점으로 모이는 판자(2026-10-14 「무늬의 기울기가 이거 맞아? 이 기울기에 맞추고」 → 「펠트 빗변을 따라」) —
#  옆 카운터 판자가 펠트 빗변처럼 안쪽(상인 쪽)으로 모이며 뻗는다. UV 가 화면 격자 그대로(_face)라 텍스처를 미리
#  휘어 굽는다: 텍셀 (x, s)(화면 x · 펠트 먼 모서리에서 내려온 y)의 판자 가로 자리는 그 점과 소실점 vp 를 잇는 선이
#  가까운 모서리(s = sn)와 만나는 x 다. 곧은 판자 한 장(_plank — 판자가 가로 줄 · 결이 가로)을 「길이 = s ·
#  폭 = 그 x」로 옮겨 찍으므로 이음 · 결 · 못이 다 소실점에서 뻗는 선을 따르고, 판자 폭이 먼 쪽에서 좁아진다.
#  org 는 텍스처 왼쪽 위의 (x, s), 크기 tw x th. nails — 맞댄 이음 · 못(_plank).
static func _plank_vp(tw: int, th: int, org: Vector2, vp: Vector2, sn: float, base: Color,
		seed: int, nails := true) -> Array:
	var k0: float = sn - vp.y
	var xr := func(x: float, sy: float) -> float:
		return vp.x + (x - vp.x) * k0 / maxf(sy - vp.y, 1.0)
	var lo: float = INF
	var hi: float = -INF
	for x in [org.x, org.x + float(tw)]:
		for sy in [org.y, org.y + float(th)]:
			var v: float = xr.call(x, sy)
			lo = minf(lo, v)
			hi = maxf(hi, v)
	var hs: int = int(ceilf(hi - lo)) + 2
	var out := []
	for img in _plank(th, hs, base, seed, 13, 18, nails):
		#  판자가 세로 띠가 되게 돌린다 — T(r, j) = 곧은 판자의 (길이 j · 폭 r). 그러면 출력 한 줄은 T 의
		#  같은 줄을 가로로 늘인 것이다(r 이 i 의 일차식) — 줄마다 잘라 늘여 붙인다(픽셀마다 돌면 1초 걸렸다).
		var t: Image = img
		t.rotate_90(CLOCKWISE)
		t.flip_x()
		var o := Image.create(tw, th, false, Image.FORMAT_RGBA8)
		for j in th:
			var f: float = k0 / maxf(org.y + float(j) + 0.5 - vp.y, 1.0)
			var b: float = vp.x + (org.x - vp.x) * f - lo
			var x0: int = clampi(int(floorf(b)), 0, hs - 1)
			var w: int = clampi(int(ceilf(float(tw) * f)), 1, hs - x0)
			var row: Image = t.get_region(Rect2i(x0, j, w, 1))
			row.resize(tw, 1, Image.INTERPOLATE_NEAREST)
			o.blit_rect(row, Rect2i(0, 0, tw, 1), Vector2i(0, j))
		out.append(o)
	return out


#  니스 칠한 판자 재질 — 반사가 맨나무의 두 배(시안 P 의 상판과 같은 값).
static func _varnish(pair: Array) -> ORMMaterial3D:
	var m := ORMMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(pair[0])
	m.orm_texture = ImageTexture.create_from_image(pair[1])
	m.metallic_specular = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


#  놋쇠 — 소품마다 한 벌. 반응(prop_glow)이 이 재질의 빛을 올린다.
#  2026-10-16 온 쇠(metallic 1 · 거칠기 0.32) — 점검(상점)에서 놋쇠가 반사 없는 노란 플라스틱으로
#  읽혔다(metallic 0.55 에 비출 것이 없었다). 이제 반사 하늘(_rx_sky)을 비춰 윗면 · 둥근 면은
#  빛나고 앞면은 가라앉는다 — 어두운 반사와 밝은 반사가 맞붙어야 닦은 쇠다.
static func _brass() -> StandardMaterial3D:
	var m := _mat(COL.brass, 0.32, 1.0)
	m.emission_enabled = true
	m.emission = COL.lamp
	m.emission_energy_multiplier = 0.0
	return m


#  녹 짙은 놋쇠 — 오목한 곳 · 안쪽(접시 안 · 건반판 · 볏 바탕 · 사슬). 닦은 테(_brass)와 두 톤을
#  이룬다 — 한 빛깔이면 접시가 금빛 원반(뚜껑)으로, 건반판이 노란 판으로 읽힌다.
static func _patina() -> StandardMaterial3D:
	return _mat(COL.brass.darkened(0.55), 0.55, 0.85)


#  반사 하늘 — 쇠가 비출 둘레(2026-10-16 · 테이블 _tbl_env). 128x64 파노라마를 코드로 한 번 굽는다
#  (남의 그림을 안 들인다):
#   · 위 — 따뜻한 어둠. 머리 위 램프(꼭대기) · 상인 뒤 술집 빛 띠(높이 35~65° — 이 시점에서
#     윗면이 비추는 자리) · 램프 반점 둘.
#   · 밑 — 짙은 나무. 높이 −52°(선 기둥이 비추는 고리)에 램프 받은 카운터 · 벨벳 반점 둘, 보는
#     쪽(+z)은 가장 어둡다 — 기둥 한가운데가 짙고 양옆에 빛 띠가 서는 「닦은 원통」이 된다.
#  파노라마 u — 0.5 가 −z(상인 쪽) · 0.25 왼쪽 · 0.75 오른쪽 · 0/1 이 +z(보는 쪽).
static var _sky: Sky = null


static func _rx_sky() -> Sky:
	if _sky != null:
		return _sky
	var w := 128
	var h := 64
	var im := Image.create(w, h, false, Image.FORMAT_RGBF)
	var g := func(a: float, s: float) -> float:
		return exp(-(a * a) / (s * s))
	for y in h:
		var el: float = (0.5 - (float(y) + 0.5) / float(h)) * 180.0     # 높이각(도)
		for x in w:
			var u: float = (float(x) + 0.5) / float(w)
			var du: float = absf(u - 0.5)          # 상인 쪽에서 돈 몫(0 ~ 0.5)
			var c := Color(0.075, 0.048, 0.032)
			if el >= 0.0:
				c += Color(4.2, 3.0, 1.7) * g.call(90.0 - el, 14.0)
				c += Color(0.50, 0.33, 0.18) * g.call(el - 50.0, 14.0) * g.call(du, 0.20)
				c += Color(2.4, 1.7, 0.9) * g.call(el - 46.0, 5.0) * g.call(absf(du - 0.13), 0.03)
				c += Color(0.22, 0.15, 0.09) * g.call(el - 40.0, 16.0) * g.call(0.5 - du, 0.16)
				c += Color(0.10, 0.06, 0.04) * g.call(el, 8.0)
			else:
				c = Color(0.06, 0.036, 0.022)
				c += Color(0.16, 0.10, 0.055) * g.call(el, 9.0)
				c += Color(0.55, 0.32, 0.15) * g.call(el + 50.0, 13.0) * g.call(absf(du - 0.36), 0.05)
				c += Color(0.20, 0.06, 0.06) * g.call(el + 55.0, 14.0) * g.call(du, 0.12)
				c *= lerpf(1.0, 0.45, g.call(0.5 - du, 0.06))
			im.set_pixel(x, y, c)
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = ImageTexture.create_from_image(im)
	_sky = Sky.new()
	_sky.sky_material = pm
	_sky.radiance_size = Sky.RADIANCE_SIZE_128
	return _sky


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
#  벨벳의 가까운 폭은 X − side × 2 · 먼 폭은 거기서 back × 2 를 덜어 낸 것이다.
static func lean(at: Vector3, X: float, W: float, back: float, side: float) -> float:
	var w_vp: float = -W * (X - side * 2.0 - back * 2.0) / (back * 2.0)
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
static func prop_rect(z: int, X: float, fy: float, ny: float, back: float, side: float,
		flat: float, tall: float) -> Rect2:
	var at: Vector3 = buy_at() if z == 1 else sell_at()
	var k: float = BUY_K if z == 1 else SELL_K
	var sh: float = lean(at, X, (ny - fy) / flat, back, side)
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


#  소품 받침이 카운터에 얼마나 들어앉았나 — z 0 저울 · 1 금전등록기. 받침 네 귀(…_FOOT)를
#  기울여 면 좌표로 옮겨 잰다(make_table 과 같은 기울임 · 곱).
#   x — 조각 틀 안쪽 끝에서 카운터 쪽으로 들어온 가장 작은 거리(빗변에 수직). 먼 모서리
#       놋쇠 갓이 덮는 w(CAP_WZ) 앞까지는 갓 끝(CAP_OUT)에서 잰다. 음수면 틀 위에 걸쳤다.
#   y — 먼 턱 앞끝(LIP_W)에서 앞으로 나온 가장 작은 w. 음수면 턱 너머다.
#  shop_probe 「소품 받침이 카운터 위」가 x ≥ 3 · y ≥ 0.5 를 잰다.
static func foot_clear(z: int, X: float, fy: float, ny: float, back: float, side: float,
		flat: float) -> Vector2:
	var at: Vector3 = buy_at() if z == 1 else sell_at()
	var k: float = BUY_K if z == 1 else SELL_K
	var W: float = (ny - fy) / flat
	var sh: float = lean(at, X, W, back, side)
	var ln: float = Vector2(back, W).length()
	var cx := 9999.0
	var cw := 9999.0
	for q in (BUY_FOOT if z == 1 else SELL_FOOT):
		var v: Vector3 = q
		var u: float = at.x + (v.x + sh * v.z) * k
		var w: float = at.z + v.z * k
		#  빗변 u — 먼 모서리 side + back(왼쪽) · X − side − back(오른쪽)에서 앞으로 side · X − side 로
		var e: float = side + back * (1.0 - w / W)
		var d: float = (e - u) if z == 0 else (u - (X - e))
		var perp: float = d * W / ln
		cx = minf(cx, perp - (CAP_OUT if w < CAP_WZ else FRAME_W))
		cw = minf(cw, w - LIP_W)
	return Vector2(cx, cw)


#  빗변 조각 틀의 단면 (d, h) — d 는 벨벳 빗변에서 카운터 쪽 수직 거리(0 ~ FRAME_W), 바깥에서 안으로.
#  바깥 턱(카운터 윗면 TOP_H 에서 올라 모깎은 턱) · 구슬(둥근 돋을새김 — 밝은 나무) · 오목(그늘) ·
#  벨벳 쪽 벽(2026-10-16 — make_table 「몰딩」).
const FR_OUT := [Vector2(7.0, 3.0), Vector2(7.0, 4.6), Vector2(6.4, 5.0), Vector2(5.4, 5.1),
		Vector2(5.0, 5.6)]
const FR_BEAD := [Vector2(5.0, 5.6), Vector2(4.6, 6.6), Vector2(3.9, 7.1), Vector2(3.1, 7.1),
		Vector2(2.5, 6.6), Vector2(2.2, 5.7)]
const FR_IN := [Vector2(2.2, 5.7), Vector2(1.9, 5.3), Vector2(1.6, 4.4), Vector2(1.2, 3.1),
		Vector2(0.6, 2.2), Vector2(0.0, 1.8), Vector2(0.0, 0.0)]
#  먼 모서리 놋쇠 갓 꼭지 — 갓 윗면(h 7.6)에서 반구 꼭지
const CAP_KNOB := [Vector2(2.4, 0.0), Vector2(2.4, 0.4), Vector2(1.9, 0.7), Vector2(2.1, 1.4),
		Vector2(1.6, 2.1), Vector2(0.7, 2.5), Vector2(0.5, 2.8), Vector2(0.0, 3.0)]
#  벨벳 모서리 잎 판 — 두 모서리 사이를 돌며 반지름 몫(끝 둘은 옛 세모 판 다리 13 그대로)
const LEAF_R := [1.0, 0.74, 0.94, 0.70, 0.88, 0.70, 0.94, 0.74, 1.0]


#  벨벳 (2026-10-16) — 화면에서 가장 넓은 면(약 45%)이다. 옛 판은 1px 소금 잡음을 뿌린 단색 판이라
#  천이 아니라 칠로 읽혔다(점검 z_felt). 벨벳은 큰 얼룩(눌린 털 방향)과 결로 천이 된다:
#   · 굵은 얼룩 — 잡음 0.02 · 3 옥타브 · 밝기 0.8~1.0(uv — 면 좌표 / 160). 세면 지저분하다(점검
#     실험 0.72~1.12 는 셌다) — 동전 · 값 글자를 안 가리게 ±10% 안.
#   · 털 결 — 가로로 늘인 잔결(uv2 — 화면 4 x 1px 언저리) 0.8~1.0 을 곱한다. 옛 1px 소금(0.7~1.0)
#     대신 눕힌 털(0.9~1.0 은 짙은 포도주빛에서 안 보였다 — 촬영).
#   · 해짐 — 꼭짓점 빛깔(_velvet_mesh). 물건이 오가는 길(깊이 한가운데 가로 띠 — 판매 ↔ 가운데 ↔
#     구매로 끈다)은 털이 누워 한 단 밝다.
static func _velvet_mat() -> StandardMaterial3D:
	var m := _mat(Color(COL.velvet.r * 1.12, COL.velvet.g * 1.12, COL.velvet.b * 1.12), 1.0)
	var t := _noise_tex(0.02, 0.8, 1.0, 7)
	(t.noise as FastNoiseLite).fractal_octaves = 3
	m.albedo_texture = t
	m.vertex_color_use_as_albedo = true
	m.detail_enabled = true
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_uv_layout = BaseMaterial3D.DETAIL_UV_2
	m.detail_albedo = _noise_tex(0.45, 0.8, 1.0, 8)
	return m


#  벨벳 사다리꼴 — 먼 모서리 fb ~ X − fb · 가까운 모서리 side ~ X − side 를 격자 24 x 12 로 나눠
#  꼭짓점 빛깔에 해짐을 싣는다(가운데 0.9 → 1.0).
static func _velvet_mesh(fb: float, side: float, X: float, W: float) -> ArrayMesh:
	var key := "vel|%s|%s|%s|%s" % [fb, side, X, W]
	if _mc.has(key):
		return _mc[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 24
	var nw := 12
	for j in nw:
		for i in nu:
			var q := []
			for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var t: float = float(c[1]) / float(nw)
				q.append(Vector3(lerpf(lerpf(fb, side, t), lerpf(X - fb, X - side, t),
						float(c[0]) / float(nu)), 0.0, W * t))
			for k in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = q[k]
				var dw: float = (v.z - W * 0.5) / (W * 0.28)
				var e: float = 0.9 + 0.1 * exp(-dw * dw)
				st.set_color(Color(e, e, e))
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v.x / 160.0, v.z / 160.0))
				st.set_uv2(Vector2(v.x / 320.0, v.z / 68.0))
				st.add_vertex(v)
	var m := st.commit()
	_mc[key] = m
	return m


#  잎 판 — e0 에서 두 방향 a(먼 모서리) · b(빗변) 사이를 부채로 돌며 반지름 r × LEAF_R.
static func _leaf_mesh(e0: Vector3, a: Vector3, b: Vector3, r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := []
	for k in LEAF_R.size():
		rim.append(e0 + a.slerp(b, float(k) / float(LEAF_R.size() - 1)) * r * float(LEAF_R[k]))
	var up := Vector3.UP
	for k in rim.size() - 1:
		_tri(st, [e0, rim[k], rim[k + 1]], [up, up, up], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	return st.commit()


#  난간 결 그림 — 둘레 32(화면 1px 언저리) x 길이 256. 둘레마다 결 줄의 톤이 다르고(몇 줄은
#  짙다), 줄마다 제 박자로 길이를 따라 짙어졌다 옅어진다. 씨 고정. (결이 한 칸씩 비켜 흐르는 마디를
#  넣어 봤더니 난간에 덧댄 네모 조각으로 읽혀 걷었다.)
static func _rail_tex() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261016
	var w := 32
	var h := 256
	var tone := PackedFloat32Array()
	for x in w:
		tone.append(rng.randf_range(0.56, 0.68) if rng.randf() < 0.34 else rng.randf_range(0.82, 1.0))
	var ph := PackedFloat32Array()
	for x in w:
		ph.append(rng.randf_range(0.0, TAU))
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var a: float = float(y) * TAU / float(h)
		for x in w:
			var v: float = clampf(tone[x] + 0.09 * sin(a * 2.0 + ph[x]) + rng.randf_range(-0.015, 0.015),
					0.0, 1.0)
			im.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(im)


static func make_table(host: Node, r: Rect2, fy: float, ny: float, back: float, side: float,
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

	#  카메라 — 상인 손(_stage3_make)과 같은 식. 1 월드 단위 = 화면 1px. 자리 · 크기는
	#  table_fit 이 화판과 같이 세운다(화면 비가 바뀌면 다시 부른다).
	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 1.0
	cam.far = 4000.0
	root.add_child(cam)
	table_fit(vp, r, fy, flat, pitch_deg)

	var we := WorldEnvironment.new()
	we.environment = _tbl_env()
	root.add_child(we)

	var W: float = (ny - fy) / flat          # 벨벳 깊이(면 단위)
	#  X 는 논리 화면 640 — 벨벳은 그 안에서 side 만큼 들인 사다리꼴이다. 넓은 화면에서는 부르는 쪽이
	#  side 를 wide 만큼 줄여 넘겨 벨벳이 640 밖으로 넓어진다(창구 판정 _chute_edge 도 같은 side).
	#  낙하 레인(매물 자리)은 640 가운데 그대로다. 남은 자리는 카운터(E)가 채운다.
	var X: float = 640.0
	var E: float = TBL_EXT
	var brass := _brass()

	# ── 나무 그림 — 화면 1px = 1텍셀. 판자(이음 · 못) 하나, 통나무(결만) 둘 ──
	var tw: int = int(X + TEX_U * 2.0)
	var tex := Vector2(tw, 256)
	#  옆 카운터 판자는 카운터 끝(−E · X + E)까지 한 장으로 — 소실점으로 모이는 결은 되풀이하면 끊긴다.
	var ptw: int = int(X + (E + TEX_U) * 2.0)
	var ptex := Vector2(ptw, 256)
	var porg := Vector2(-E - TEX_U, -TEX_V)
	var pvp := Vector2(X * 0.5, (ny - fy) - (X * 0.5 - side) * (ny - fy) / back)   # 펠트 두 빗변이 만나는 점(game.gd _tbl_vp)
	#  못 · 맞댄 이음은 안 박는다(2026-10-16) — 소실점으로 휜 판자에서 이음이 가로 1px 줄, 못(짙은 2px +
	#  밝은 1px)이 그 밑 점이 되어 SellGlint · BuyGlint 반사 한가운데에서 「판매」 밑 「1」 · 「구매」 밑
	#  「⌐」 글자로 읽혔다(점검 z_mark · z_plankR — 이름 · 값 글자 바로 밑이라 UI 찌꺼기였다).
	var plank := _varnish(_plank_vp(ptw, 256, porg, pvp, ny - fy, WOOD.plank, 41, false))
	var ledge := _varnish(_plank(tw, 256, WOOD.ledge, 43, 64, 64, false))
	var ledge_f := _varnish(_plank(tw, 256, WOOD.ledge.darkened(0.30), 47, 64, 64, false))

	# ── 벨벳 — 사다리꼴 한 장. 물건이 눕는 면(h 0) 그대로다 ──
	#  먼 모서리 fb ~ X − fb · 가까운 모서리 side ~ X − side(2 : 6 : 2 — 머리말).
	var fb: float = side + back
	var vm := MeshInstance3D.new()
	vm.mesh = _velvet_mesh(fb, side, X, W)
	vm.material_override = _velvet_mat()
	root.add_child(vm)
	#  감침 — 벨벳 가장자리를 두른 짙은 띠(2.6)와 그 안쪽 금실(1.2). 옛 판은 틀과 1.4 놋쇠 막대 하나로만
	#  만났다(점검 — 천의 테두리 처리가 없었다). 먼 끝은 턱 밑을 따라 같은 짝으로 두른다.
	var bind := _mat(COL.velvet.darkened(0.5), 1.0)
	root.add_child(_quad([Vector3(fb, 0.04, 0.0), Vector3(X - fb, 0.04, 0.0),
			Vector3(X - fb, 0.04, 2.4), Vector3(fb, 0.04, 2.4)], bind))
	root.add_child(_quad([Vector3(fb, 0.06, 2.4), Vector3(X - fb, 0.06, 2.4),
			Vector3(X - fb, 0.06, 3.6), Vector3(fb, 0.06, 3.6)], brass))

	# ── 옆 카운터 — 판매 · 구매 자리. 니스 칠한 밤나무 판자, 벨벳보다 한 단 위 ──
	#  먼 쪽 fb 에서 앞 side 로 좁아지는 사다리꼴 — 옛 창구 삼각형(앞에서 0)을 앞까지 넓혔다.
	root.add_child(_face([Vector3(-E, TOP_H, -2.0), Vector3(fb, TOP_H, -2.0),
			Vector3(side, TOP_H, W), Vector3(-E, TOP_H, W)], plank, Vector3.UP, ptex, porg))
	root.add_child(_face([Vector3(X - fb, TOP_H, -2.0), Vector3(X + E, TOP_H, -2.0),
			Vector3(X + E, TOP_H, W), Vector3(X - side, TOP_H, W)], plank, Vector3.UP, ptex, porg))

	# ── 조각 틀 — 빗변 몰딩(밀어낸 단면) + 벨벳 쪽 감침 · 금실 + 모서리 놋쇠 갓 · 잎 판 ──
	var carve := _mat(WOOD.carve, 0.45)
	carve.albedo_texture = _noise_tex(0.08, 0.7, 1.0, 21)
	var bead := _mat(WOOD.beam, 0.3)
	var ln: float = Vector2(back, W).length()
	for sd in [-1.0, 1.0]:
		var s: float = float(sd)
		#  빗변 방향 d · 바깥(카운터 쪽) 법선 n — 면 (u, w)
		var d := Vector3(s * back, 0.0, W) / ln
		var n := Vector3(s * W, 0.0, -back) / ln
		var m0 := Vector3(side + back * 0.5 if s < 0.0 else X - side - back * 0.5, 0.0, W * 0.5)
		var yaw := Vector3(0.0, atan2(s * back, W), 0.0)
		#  몰딩 — 바깥 턱(카운터) · 구슬 · 오목 · 벨벳 쪽 벽으로 이어지는 단면(FR_*)을 빗변 따라 민다
		#  (2026-10-16). 위에서 오는 빛에 밝음 · 짙음 · 밝음 · 그늘 네 톤이 서야 조각으로 읽힌다 — 옛 판은
		#  상자 셋(나무 몸 · 구슬 · 놋쇠)이라 짙은 민 띠에 계단 톱니뿐이었다(점검 x4_corner). 폭은 FRAME_W 그대로.
		var fl := ln + 10.0
		for part in [["out", FR_OUT, carve], ["bead", FR_BEAD, bead], ["in", FR_IN, carve]]:
			var mi := MeshInstance3D.new()
			mi.mesh = _extrude("fr|%s|%s|%s" % [part[0], s, fl], PackedVector2Array(part[1]),
					-fl * 0.5, fl * 0.5, s)
			mi.material_override = part[2]
			mi.position = m0
			mi.rotation = yaw
			root.add_child(mi)
		#  감침 · 금실 — 빗변 안쪽(벨벳 쪽)으로
		var fa: Vector3 = m0 - d * (fl * 0.5)
		var fz: Vector3 = m0 + d * (fl * 0.5)
		var y4 := Vector3(0.0, 0.04, 0.0)
		var y6 := Vector3(0.0, 0.06, 0.0)
		root.add_child(_quad([fa + y4, fz + y4, fz - n * 2.6 + y4, fa - n * 2.6 + y4], bind))
		root.add_child(_quad([fa - n * 2.6 + y6, fz - n * 2.6 + y6, fz - n * 3.8 + y6, fa - n * 3.8 + y6],
				brass))
		#  먼 모서리 놋쇠 갓 — 몰딩이 먼 턱에 닿는 자리. 모깎은 갓 위에 둥근 꼭지(CAP_KNOB).
		var c0: Vector3 = Vector3(fb if s < 0.0 else X - fb, 0.0, 0.0)
		var cap := _bbox(Vector3(10.0, 7.6, 7.0), 0.6, c0 + n * 3.5 + Vector3(0.0, 3.8, 2.0), brass)
		cap.rotation = yaw
		root.add_child(cap)
		root.add_child(_lmi("cap_knob", PackedVector2Array(CAP_KNOB), c0 + n * 3.5 + Vector3(0.0, 7.6, 2.0),
				brass, 14))
		#  벨벳 모서리 쇠 — 먼 모서리 둘에 놋쇠 잎 판. 옛 세모 판을 가장자리가 다섯 갈래로 물결치는
		#  잎으로(LEAF_R) · 가운데 징 하나.
		var e0: Vector3 = c0 + Vector3(0.0, 0.5, 0.0)
		var lm := MeshInstance3D.new()
		lm.mesh = _leaf_mesh(e0, Vector3(-s, 0.0, 0.0), d, 13.0)
		lm.material_override = brass
		root.add_child(lm)
		root.add_child(_ball(1.0, e0 + (Vector3(-s, 0.0, 0.0) + d).normalized() * 4.5, brass, true))

	# ── 먼 턱 — 상인 앞 카운터 끝. 니스 칠한 통나무 갓 · 이빨 장식 · 놋쇠 줄 ──
	root.add_child(_face([Vector3(-E, 8.0, 0.0), Vector3(X + E, 8.0, 0.0),
			Vector3(X + E, 0.0, 0.0), Vector3(-E, 0.0, 0.0)], ledge_f, Vector3.BACK, tex))
	#  갓 — 앞으로 1.5 내민 윗판(윗면 · 앞면)과 그 앞 놋쇠 줄
	_slab(root, -E, X + E, -14.0, 1.5, 8.0, 10.4, ledge, ledge_f, tex)
	root.add_child(_box(Vector3(X + E * 2.0, 0.9, 1.0), Vector3(X * 0.5, 10.2, 1.0), brass))
	#  이빨 장식(덴틸) — 갓 밑에 토막이 줄지어 선다. 2026-10-16 옛 판(폭 3 · 틈 3 · 같은 짙기)은 필름
	#  구멍 · 자 눈금으로 읽혔다(점검 z_ledge). 이제 틈 뒤를 그늘 띠로 깊게 두고, 토막은 키를 늘리고 갓
	#  앞끝보다 내밀어 모깎은 윗날이 위 빛을 받는다 — 「깎은 이빨」. 격자 5(폭 3.2 · 틈 1.8 — 이빨이
	#  틈보다 넓어야 덴틸이다). 이백 남짓을 한 메시로 붙인다(그리기 한 번).
	root.add_child(_box(Vector3(X + E * 2.0, 5.2, 0.1), Vector3(X * 0.5, 5.4, 0.06),
			_mat(Color("120a06"), 1.0)))
	var dst := SurfaceTool.new()
	dst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dbox := _bevel_box(Vector3(3.2, 4.4, 2.0), 0.45)
	var du := X * 0.5 - ceilf((X * 0.5 + E) / 5.0) * 5.0
	while du < X + E:
		dst.append_from(dbox, 0, Transform3D(Basis(), Vector3(du, 5.6, 0.95)))
		du += 5.0
	var dmi := MeshInstance3D.new()
	dmi.mesh = dst.commit()
	dmi.material_override = _mat(WOOD.beam.lightened(0.06), 0.5)
	root.add_child(dmi)

	# ── 가까운 팔걸이 — 둥근 밤나무 난간 + 밑 구슬 줄 ──
	#  윤은 반만 — 더 매끈하면 머리 위 램프가 쇠막대처럼 흰 줄로 비친다.
	var railm := _mat(WOOD.beam, 0.42)
	railm.metallic_specular = 0.35
	#  결 — 길이로 흐르는 결 줄(_rail_tex · 2026-10-16). 옛 잡음(0.05)은 1440 길이로 늘어나 결이
	#  사라져 매끈한 가로 줄무늬 — PVC 관으로 읽혔다(점검 z_rail). 원통 옆면 uv 는 v 0 ~ 0.5 다.
	railm.albedo_texture = _rail_tex()
	railm.uv1_scale = Vector3(1.0, 8.0, 1.0)
	var rail := _cyl(8.5, 8.5, X + E * 2.0, Vector3(X * 0.5, 4.0, W + 8.0), railm, 20)
	rail.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	root.add_child(rail)
	root.add_child(_box(Vector3(X + E * 2.0, 1.4, 1.4), Vector3(X * 0.5, -5.0, W + 16.0), brass))
	var bu := -8.0 - floorf((E - 8.0) / 7.0) * 7.0
	while bu < X + E:
		var bb := _ball(2.2, Vector3(bu, -8.6, W + 18.6), carve)
		bb.scale = Vector3(1.4, 1.0, 1.0)
		root.add_child(bb)
		bu += 7.0

	# ── 앞판 — 짙은 밤나무 판넬(테 · 돋은 판 · 놋쇠 모서리 갓), 화면 아래 끝까지 ──
	var apron := _mat(WOOD.apron, 0.75)
	apron.albedo_texture = _noise_tex(0.04, 0.55, 1.0, 13)
	apron.uv1_scale = Vector3(2.0, 1.0, 1.0)
	root.add_child(_box(Vector3(X + E * 2.0, 260.0, 4.0), Vector3(X * 0.5, -136.0, W + 16.0), apron))
	var zf: float = W + 18.0
	var frame := _mat(WOOD.ledge, 0.55)
	frame.albedo_texture = _noise_tex(0.05, 0.65, 1.0, 17)
	var field := _mat(WOOD.ledge.darkened(0.15), 0.6)
	field.albedo_texture = _noise_tex(0.04, 0.6, 1.0, 19)
	field.uv1_scale = Vector3(2.0, 1.0, 1.0)
	#  위 띠
	root.add_child(_box(Vector3(X + E * 2.0, 4.0, 2.4), Vector3(X * 0.5, -13.0, zf + 1.2), frame))
	var pw := 128.0
	var k0: int = -int(ceilf(E / pw))
	var k1: int = int(ceilf((X + E) / pw))
	for k in range(k0, k1 + 1):
		var su: float = float(k) * pw
		#  선대(세로 테)
		root.add_child(_box(Vector3(7.0, 200.0, 2.4), Vector3(su, -115.0, zf + 1.2), frame))
		if k == k1:
			break
		var cu: float = su + pw * 0.5
		#  돋은 판 — 테 안쪽에서 한 단 나온다
		root.add_child(_box(Vector3(pw - 22.0, 160.0, 1.4), Vector3(cu, -103.0, zf + 0.7), field))
		#  모서리 놋쇠 갓 — 돋은 판 위 두 모서리를 ㄱ 자로 감싼다(2026-10-16 — 옛 3x3 점은 판과
		#  떨어진 주황 점으로 떴다 · 점검 z_rail).
		for sx in [-1.0, 1.0]:
			var ex: float = cu + float(sx) * (pw * 0.5 - 11.0)
			root.add_child(_box(Vector3(6.0, 1.4, 0.8), Vector3(ex - float(sx) * 2.3, -23.7, zf + 1.8), brass))
			root.add_child(_box(Vector3(1.4, 6.0, 0.8), Vector3(ex - float(sx) * 0.7, -26.0, zf + 1.8), brass))

	# ── 소품 — 저울(판매) · 금전등록기(구매) ──
	_scale_prop(root, lean(sell_at(), X, W, back, side))
	_register_prop(root, lean(buy_at(), X, W, back, side))

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
	#  (2 : 6 : 2 — 옛 판에서 이 두 반사는 화면 x 62 · 578 언저리에 맺혀 벨벳 위(니스 층 밖)라
	#  거의 안 보였다. 카운터가 앞까지 side 96 폭으로 이어져 그 자리가 니스 판자가 되자 이름 밑에
	#  둥근 등불처럼 떠 눈이 그리 갔다(촬영 — 세기 1.2 도, 자리를 바깥으로 48 옮겨도 등불이었다).
	#  세기를 3 → 0.35(GLINT_SIDE)로 깎아 이름 밑에 결 따라 끊기는 윤으로 둔다 — 셋째 값.)
	for gl in [["SellGlint", Vector3(8.0, TOP_H, 125.0), GLINT_SIDE],
			["BuyGlint", Vector3(632.0, TOP_H, 125.0), GLINT_SIDE],
			["LipGlintL", Vector3(132.0, 10.4, -6.0), 3.0],
			["LipGlintR", Vector3(X - 132.0, 10.4, -6.0), 3.0]]:
		var tg: Vector3 = gl[1]
		var og := OmniLight3D.new()
		og.name = String(gl[0])
		og.light_color = COL.lamp
		og.light_energy = 0.8
		og.light_specular = float(gl[2])
		og.light_cull_mask = WOOD_LAYER
		og.omni_range = 420.0
		og.omni_attenuation = 0.5
		og.position = Vector3(tg.x, tg.y + 150.0, tg.z - 150.0 * 0.78)
		root.add_child(og)
	return vp


#  테이블 화판을 화면 사각 r 에 맞춘다 — 화판 크기 · 카메라 크기 · 자리. 1 월드 단위 = 화면 1px
#  이라 r 이 넓어지면 카메라가 그만큼 더 본다(벨벳 자리는 안 움직인다).
static func table_fit(vp: SubViewport, r: Rect2, fy: float, flat: float, pitch_deg: float) -> void:
	var sz := Vector2i(maxi(int(round(r.size.x)), 2), maxi(int(round(r.size.y)), 2))
	if vp.size != sz:
		vp.size = sz
	var cam := vp.get_node_or_null("Table/Cam") as Camera3D
	if cam == null:
		return
	cam.size = r.size.y
	var pit: float = deg_to_rad(pitch_deg)
	cam.rotation = Vector3(pit, 0.0, 0.0)
	var mid := Vector3(r.position.x + r.size.x * 0.5, 0.0,
			(r.position.y + r.size.y * 0.5 - fy) / flat)
	cam.position = mid + Vector3(0.0, -sin(pit), cos(pit)) * 900.0


#  방 화판을 화면 크기(논리 px)에 맞춘다 — 반 해상도. 넓은 화면은 세로 시야, 높은 화면은
#  가로 시야를 16:9 그대로 지켜 가운데가 안 바뀐다(ROOM_FOV 머리말).
static func room_fit(vp: SubViewport, logical: Vector2) -> void:
	var sz := Vector2i(maxi(int(round(logical.x * 0.5)), 2), maxi(int(round(logical.y * 0.5)), 2))
	if vp.size != sz:
		vp.size = sz
	var cam := vp.get_node_or_null("Room/Cam") as Camera3D
	if cam == null:
		return
	var a169: float = 16.0 / 9.0
	if logical.x / maxf(logical.y, 1.0) >= a169 - 0.001:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = ROOM_FOV
	else:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(ROOM_FOV * 0.5)) * a169))


#  진열 스포트 둘(SellLamp · BuyLamp) — 소품마다 왼쪽 위에서 좁게. pool 이면 그 옆에 꺼 둔
#  웅덩이 빛(…Pool)도 단다(테이블만 — 반응 prop_glow 가 켠다). 상인 손 무대도 같은 둘을
#  평소 세기로 단다(game.gd _hand3_open) — 판 소품 몸짓(저울 · 등록기)에서 소품에 닿은
#  손이 소품과 같은 빛을 받는다. 없으면 램프 웅덩이 밖이라 손만 어둠 속 갈색 덩어리였다
#  (촬영). 쉬는 손 · 건네받는 손은 이 원뿔 밖이다.
#  시안 C 에서 소품이 두 배라 원뿔도 넓혔다(반지름 47 → 95 언저리) — 램프를 그만큼
#  높이 · 멀리 걸어 빛이 오는 쪽(왼쪽 위)은 그대로다. 저울 원뿔 오른끝 u 150 · 등록기
#  왼끝 u 495 라 쉬는 손(화면 x 190~450)은 여전히 밖이다. 2 : 6 : 2(2026-10-11)에서 소품이
#  38 · 49 들어와 원뿔도 따라 들어왔다(오른끝 188 · 왼끝 446) — 쉬는 손 바로 바깥이다.
static func prop_lamps(root: Node, pool: bool) -> void:
	for pr in [["SellLamp", sell_at() + Vector3(16.0, 62.0, 0.0), 19.0],
			["BuyLamp", buy_at() + Vector3(-14.0, 56.0, 4.0), 19.0]]:
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


#  테이블의 둘레 — lamp_env 에 반사만 하늘(_rx_sky)에서 받는다(2026-10-16). 바탕은 그대로 화판(투명)이고
#  둘레빛도 그대로 색이라 벨벳 · 나무의 밝기는 안 바뀌고 쇠가 비출 것을 얻는다. 상인 손 무대는 옛
#  lamp_env 그대로 둔다 — 같은 하늘을 걸었더니 비스듬히 선 팔뚝 살갗이 하늘 빛을 비춰 손 말고 밝은
#  덩어리 둘이 생겼다(npc_probe 「밝은 덩어리」 · 「손 ≥ 동전」).
static func _tbl_env() -> Environment:
	var env := lamp_env()
	env.sky = _rx_sky()
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
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


# ══ 깎은 윤곽 (2026-10-16) ═════════════════════════════════
#  「게임의 전체적인 모델링을 다 퀄리티 업을 끝까지 … 진짜 있어보이는 모델링」. 점검(상점)에서
#  저울 · 등록기가 상자 · 원통 · 공 원형 그대로라 「프로그래머 아트」로 읽혔다 — 앤티크 저울 ·
#  등록기가 비싸 보이는 것은 깎은 윤곽(발루스터 기둥 · 몰딩 받침 · 말린 테 접시)과 모서리마다
#  맺히는 빛 날이다. 직교 카메라에서 평평한 면은 한 색이라, 윤곽이 꺾이는 자리마다 법선을 끊어
#  띠 하나가 한 톤이 되게 짓는다. 셋 다 SurfaceTool — 회전체(_lathe) · 모깎은 상자(_bevel_box) ·
#  밀어낸 띠(_extrude). 같은 열쇠는 한 번만 짓는다(_mc — 테이블 · 방을 다시 지어도 메시는 그대로).
#  세부는 소품 좌표 1 언저리(화면 2px) 위로 둔다 — 그보다 잘면 기울기 · 눌림 · 빛 맥박 때 반짝이는
#  잡음이 된다(점검 실험 — 날을 세게 주자 건반이 꽃무늬 잡음이 됐다).
static var _mc := {}


#  삼각형 하나 — 법선 쪽에서 보아 시계 방향(Godot 의 앞면)으로 감는다.
static func _tri(st: SurfaceTool, p: Array, nn: Array, uv: Array) -> void:
	var o := [0, 1, 2]
	if ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).dot(nn[0] + nn[1] + nn[2]) > 0.0:
		o = [0, 2, 1]
	for i in o:
		st.set_normal(nn[i])
		st.set_uv(uv[i])
		st.add_vertex(p[i])


#  윤곽 마디의 법선 둘(시작 · 끝) — 이웃 마디와 30° 안으로 꺾이면 이어 둥글리고, 더 꺾이면 끊어
#  날을 세운다. 윤곽은 면이 왼쪽을 보는 차례로 준다(회전체는 밑에서 위로 · 바깥을 돌아).
static func _prof_n(prof: PackedVector2Array) -> Array:
	var sn: Array[Vector2] = []
	for i in prof.size() - 1:
		var t: Vector2 = prof[i + 1] - prof[i]
		sn.append(Vector2(t.y, -t.x).normalized())
	var out := []
	for i in sn.size():
		var n0: Vector2 = sn[i]
		var n1: Vector2 = sn[i]
		if i > 0 and sn[i - 1].dot(sn[i]) > 0.87:
			n0 = (sn[i - 1] + sn[i]).normalized()
		if i < sn.size() - 1 and sn[i + 1].dot(sn[i]) > 0.87:
			n1 = (sn[i] + sn[i + 1]).normalized()
		out.append([n0, n1])
	return out


#  회전체 — 축 y 에 윤곽 (반지름, 높이)을 돌린다(arc 만큼 — 0 에서 +x · +z 쪽으로). uv — (돈 몫,
#  윤곽을 따라간 몫).
static func _lathe(key: String, prof: PackedVector2Array, seg := 16, arc := TAU) -> ArrayMesh:
	if _mc.has(key):
		return _mc[key]
	var nn := _prof_n(prof)
	var acc := PackedFloat32Array([0.0])
	for i in prof.size() - 1:
		acc.append(acc[i] + prof[i].distance_to(prof[i + 1]))
	var tot: float = maxf(acc[acc.size() - 1], 0.0001)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in prof.size() - 1:
		var p0: Vector2 = prof[i]
		var p1: Vector2 = prof[i + 1]
		if p0.distance_to(p1) < 0.0001:
			continue
		var n0: Vector2 = nn[i][0]
		var n1: Vector2 = nn[i][1]
		for k in seg:
			var ca := Vector2(cos(arc * float(k) / float(seg)), sin(arc * float(k) / float(seg)))
			var cb := Vector2(cos(arc * float(k + 1) / float(seg)), sin(arc * float(k + 1) / float(seg)))
			var p := [Vector3(p0.x * ca.x, p0.y, p0.x * ca.y), Vector3(p0.x * cb.x, p0.y, p0.x * cb.y),
					Vector3(p1.x * cb.x, p1.y, p1.x * cb.y), Vector3(p1.x * ca.x, p1.y, p1.x * ca.y)]
			var n := [Vector3(n0.x * ca.x, n0.y, n0.x * ca.y), Vector3(n0.x * cb.x, n0.y, n0.x * cb.y),
					Vector3(n1.x * cb.x, n1.y, n1.x * cb.y), Vector3(n1.x * ca.x, n1.y, n1.x * ca.y)]
			var u0: float = float(k) / float(seg)
			var u1: float = float(k + 1) / float(seg)
			var uv := [Vector2(u0, acc[i] / tot), Vector2(u1, acc[i] / tot),
					Vector2(u1, acc[i + 1] / tot), Vector2(u0, acc[i + 1] / tot)]
			_tri(st, [p[0], p[1], p[2]], [n[0], n[1], n[2]], [uv[0], uv[1], uv[2]])
			_tri(st, [p[0], p[2], p[3]], [n[0], n[2], n[3]], [uv[0], uv[2], uv[3]])
	var m := st.commit()
	_mc[key] = m
	return m


#  회전체 하나를 세운다 — at 이 윤곽의 원점(높이 0)이다.
static func _lmi(key: String, prof: PackedVector2Array, at: Vector3, m: Material,
		seg := 16, arc := TAU) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _lathe(key, prof, seg, arc)
	mi.material_override = m
	mi.position = at
	return mi


#  밀어낸 띠 — 윤곽 (d, h)를 z0 에서 z1 까지 민다. d 는 sd 쪽 x 로 선다(sd −1 이면 거울). 꺾임은
#  _lathe 와 같다. uv — (z / 16, 윤곽을 따라간 길이 / 16).
static func _extrude(key: String, prof: PackedVector2Array, z0: float, z1: float,
		sd: float) -> ArrayMesh:
	if _mc.has(key):
		return _mc[key]
	var nn := _prof_n(prof)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var acc := 0.0
	for i in prof.size() - 1:
		var p0: Vector2 = prof[i]
		var p1: Vector2 = prof[i + 1]
		var ln: float = p0.distance_to(p1)
		if ln < 0.0001:
			continue
		var n0: Vector2 = nn[i][0]
		var n1: Vector2 = nn[i][1]
		var p := [Vector3(sd * p0.x, p0.y, z0), Vector3(sd * p0.x, p0.y, z1),
				Vector3(sd * p1.x, p1.y, z1), Vector3(sd * p1.x, p1.y, z0)]
		var n := [Vector3(sd * n0.x, n0.y, 0.0), Vector3(sd * n0.x, n0.y, 0.0),
				Vector3(sd * n1.x, n1.y, 0.0), Vector3(sd * n1.x, n1.y, 0.0)]
		var uv := [Vector2(z0, acc) / 16.0, Vector2(z1, acc) / 16.0,
				Vector2(z1, acc + ln) / 16.0, Vector2(z0, acc + ln) / 16.0]
		_tri(st, [p[0], p[1], p[2]], [n[0], n[1], n[2]], [uv[0], uv[1], uv[2]])
		_tri(st, [p[0], p[2], p[3]], [n[0], n[2], n[3]], [uv[0], uv[2], uv[3]])
		acc += ln
	var m := st.commit()
	_mc[key] = m
	return m


#  모깎은 상자 — 크기 sz 의 모서리 열둘을 r 만큼 45° 로 깎는다(구석 여덟은 세모). 깎은 띠가 빛을
#  받아 모서리마다 빛 날이 선다 — 쌓은 상자가 「깎아 맞춘 나무 · 부은 쇠」로 읽히는 한 수다.
#  얇은 쪽은 깎음을 그 반까지만(판이 뒤집히지 않게). uv — 그 면의 두 축 / 16.
static func _bevel_box(sz: Vector3, r: float) -> ArrayMesh:
	var key := "bb|%s|%s" % [sz, r]
	if _mc.has(key):
		return _mc[key]
	var h := sz * 0.5
	var ri := Vector3(minf(r, h.x * 0.5), minf(r, h.y * 0.5), minf(r, h.z * 0.5))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	#  구석 s(±1 셋)에서 ax 축 면 위의 점
	var pt := func(s: Vector3, ax: int) -> Vector3:
		var v := h - ri
		v[ax] = h[ax]
		return v * s
	var uvf := func(q: Vector3, n: Vector3) -> Vector2:
		var a := n.abs()
		if a.x >= a.y and a.x >= a.z:
			return Vector2(q.z, q.y) / 16.0
		if a.y >= a.z:
			return Vector2(q.x, q.z) / 16.0
		return Vector2(q.x, q.y) / 16.0
	var face := func(p: Array, n: Vector3) -> void:
		var uv := []
		for q in p:
			uv.append(uvf.call(q, n))
		_tri(st, [p[0], p[1], p[2]], [n, n, n], [uv[0], uv[1], uv[2]])
		if p.size() == 4:
			_tri(st, [p[0], p[2], p[3]], [n, n, n], [uv[0], uv[2], uv[3]])
	for ax in 3:
		var b: int = (ax + 1) % 3
		var c: int = (ax + 2) % 3
		for sg in [-1.0, 1.0]:
			#  면 — ax 축 쪽
			var n := Vector3.ZERO
			n[ax] = sg
			var p := []
			for q in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				var s := Vector3.ZERO
				s[ax] = sg
				s[b] = q[0]
				s[c] = q[1]
				p.append(pt.call(s, ax))
			face.call(p, n)
		#  모서리 띠 — ax 축을 따라 뻗고 b · c 두 면 사이
		for sb in [-1.0, 1.0]:
			for sc in [-1.0, 1.0]:
				var n := Vector3.ZERO
				n[b] = sb
				n[c] = sc
				var p := []
				for k in [[-1.0, b], [1.0, b], [1.0, c], [-1.0, c]]:
					var s := Vector3.ZERO
					s[ax] = k[0]
					s[b] = sb
					s[c] = sc
					p.append(pt.call(s, int(k[1])))
				face.call(p, n.normalized())
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz2 in [-1.0, 1.0]:
				var s := Vector3(sx, sy, sz2)
				face.call([pt.call(s, 0), pt.call(s, 1), pt.call(s, 2)], s.normalized())
	var m := st.commit()
	_mc[key] = m
	return m


static func _bbox(sz: Vector3, r: float, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _bevel_box(sz, r)
	mi.material_override = m
	mi.position = at
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
#  (2 : 6 : 2 · 2026-10-11 — 저울이 화면 안으로 들어와 바깥 접시도 다 보인다. 동전은 상인에게
#  가까운 안 접시 그대로다.)
const SCALE_PIV := Vector3(0.0, 56.0, 0.0)
const SCALE_HL := 22.0                          # 저울대 반 길이
const SCALE_TILT := [12.0, -16.0]               # 평소(추 쪽 · 바깥) · 팔 것을 댄 때(안 접시)(도)


#  윤곽 — (반지름, 높이), 저울 제 좌표(곱 전). 2026-10-16 깎은 윤곽(머리말 「깎은 윤곽」)으로
#  다시 지었다. 옛 몸(민 원통 기둥에 고리 둘 · 각목 저울대 · 납작한 원반 접시 · 원통 추)은 4배로
#  찍으면 원형 덩어리가 그대로 드러났다(점검 x4_scale). 이제
#   · 기둥 — 발루스터: 받침 오지(필렛 · 오목 · 고리) · 위로 가늘어지는 몸에 허리 고리 둘 · 가는 목이
#     굴대 북(SC_HUB)을 받친다. 꼭지는 가는 침 끝에 알. (목 위에 항아리 머리를 얹었더니 북 · 꼭지와
#     겹쳐 3배로 보아도 혹 덩어리였다 — 걷었다.)
#   · 저울대 — 굴대 쪽이 굵고 끝으로 가늘어지는 둥근 대, 끝마다 고리 혹(사슬이 매달리는 자리).
#   · 접시 — 바닥 굽 · 얕은 배 · 말린 테(닦은 놋쇠)와 오목한 안(녹 짙은 놋쇠). 안 바닥 한가운데가
#     PAN_TOP(−24.1) 그대로라 판 동전이 그 위에 눕는다.
#   · 추 — 층진 원통 + 목 + 꼭지(옛 원통 추는 동전 둘로 읽혔다).
const SC_FOOT := [Vector2(0.0, 0.0), Vector2(0.9, 0.0), Vector2(1.4, 0.35), Vector2(1.6, 0.9),
		Vector2(1.5, 1.5), Vector2(1.2, 2.0), Vector2(0.0, 2.0)]
const SC_COL := [Vector2(7.4, 8.0), Vector2(7.4, 8.7), Vector2(6.9, 9.0), Vector2(5.6, 9.4),
		Vector2(4.9, 10.0), Vector2(4.7, 10.6), Vector2(5.0, 10.9), Vector2(5.0, 11.6),
		Vector2(4.4, 12.0), Vector2(3.0, 12.4), Vector2(2.9, 13.0), Vector2(2.7, 17.0),
		Vector2(2.6, 18.8), Vector2(3.4, 19.2), Vector2(3.4, 20.8), Vector2(2.6, 21.2),
		Vector2(2.45, 26.0), Vector2(2.25, 34.0), Vector2(2.1, 41.8), Vector2(3.0, 42.4),
		Vector2(3.3, 43.2), Vector2(3.3, 44.8), Vector2(3.0, 45.6), Vector2(2.0, 46.2),
		Vector2(1.8, 47.0), Vector2(1.8, 51.0), Vector2(2.4, 51.6), Vector2(2.6, 52.4),
		Vector2(0.0, 52.6)]
#  굴대 통 — 저울대가 꿰는 북(SCALE_PIV 높이 56 이 한가운데)
const SC_HUB := [Vector2(0.0, 53.0), Vector2(1.8, 53.2), Vector2(2.8, 54.0), Vector2(3.2, 55.0),
		Vector2(3.2, 57.0), Vector2(2.8, 58.0), Vector2(1.8, 58.8), Vector2(0.0, 59.0)]
const SC_TIP := [Vector2(1.0, 58.8), Vector2(0.6, 59.6), Vector2(0.6, 62.6), Vector2(1.1, 63.2),
		Vector2(1.6, 64.4), Vector2(1.5, 65.6), Vector2(0.9, 66.8), Vector2(0.4, 67.3),
		Vector2(0.0, 67.6)]
#  저울대 — 축 y 로 지어 x 로 눕힌다(끝 ±24 · 굴대 쪽 반지름 2.2 · 끝 혹 1.8)
const SC_ARM := [Vector2(0.0, -24.0), Vector2(1.0, -23.8), Vector2(1.7, -23.0), Vector2(1.8, -22.0),
		Vector2(1.5, -21.0), Vector2(1.0, -20.4), Vector2(1.1, -19.4), Vector2(1.5, -8.0),
		Vector2(1.9, -3.4), Vector2(2.3, -3.0), Vector2(2.3, 3.0), Vector2(1.9, 3.4),
		Vector2(1.5, 8.0), Vector2(1.1, 19.4), Vector2(1.0, 20.4), Vector2(1.5, 21.0),
		Vector2(1.8, 22.0), Vector2(1.7, 23.0), Vector2(1.0, 23.8), Vector2(0.0, 24.0)]
const SC_NEEDLE := [Vector2(0.0, -12.5), Vector2(0.3, -11.6), Vector2(0.5, -4.0), Vector2(0.8, -0.6),
		Vector2(0.0, 0.0)]
const SC_PAN := [Vector2(0.0, -26.0), Vector2(4.2, -26.0), Vector2(4.6, -25.8), Vector2(4.6, -25.5),
		Vector2(7.0, -25.0), Vector2(9.0, -24.3), Vector2(10.0, -23.7), Vector2(10.4, -23.3),
		Vector2(10.2, -23.0), Vector2(9.7, -22.95), Vector2(9.3, -23.2)]
const SC_BOWL := [Vector2(9.3, -23.2), Vector2(8.0, -23.7), Vector2(5.5, -24.0), Vector2(0.0, -24.1)]
const SC_WEIGHT := [Vector2(0.0, 0.0), Vector2(2.9, 0.0), Vector2(3.0, 0.3), Vector2(3.0, 2.6),
		Vector2(2.7, 3.0), Vector2(1.9, 3.3), Vector2(1.0, 3.5), Vector2(0.8, 3.9), Vector2(1.3, 4.5),
		Vector2(1.2, 5.1), Vector2(0.6, 5.5), Vector2(0.0, 5.6)]


#  저울 glb — 메시 넷(ScaleBody 몸 · ScaleBeam 저울대 · ScalePan 접시 · ScaleWeight 추)을 Blender 로
#  짓는다(scripts/tools/blender/scale_body.py · 2026-10-16 「블렌더 깔았으니까 활용해봐」 — 등록기 다음).
#  좌표는 저울 제 좌표 그대로 · 굴대 · 걸이 · PAN_TOP 도 옛 값 그대로라 움직임 · pan_top 은 안 바뀐다.
const SCALE_BODY := "res://assets/models/scale_body.glb"


static func _scale_prop(root: Node3D, sh: float) -> void:
	var n := _prop_node(root, "Scale", sell_at(), SELL_K, sh)
	var brass := _brass()
	var patina := _patina()
	var wood := _mat(WOOD.carve, 0.4)
	var wood2 := _mat(WOOD.beam, 0.35)
	n.set_meta("glow", brass)
	n.add_child(_blob(Vector2(34.0, 24.0), Vector3(2.0, 0.15, 2.0), 0.75))
	#  glb 가 있으면 메시를 이름으로 집어 같은 노드 짜임(Arm · PanL · PanR)에 앉힌다. 재질은 이름으로
	#  이 함수의 재질을 끼운다 — 놋쇠가 prop_glow 가 미는 그 재질이라 빛 · 반짝임이 그대로 탄다.
	#  청동은 등록기 몸통과 같은 재질 · 같은 결(한 벌로 보인다). 없으면(가져오기 전) 옛 코드 몸이다.
	var gp: Dictionary = _glb_parts(SCALE_BODY)
	var gm := {}
	if gp.has("ScaleBody") and gp.has("ScaleBeam") and gp.has("ScalePan") and gp.has("ScaleWeight"):
		var bronze := _mat(COL.bronze.darkened(0.45), 0.42, 0.9)
		bronze.albedo_texture = _noise_tex(0.35, 0.78, 1.0, 31)
		gm = {"brass": brass, "bronze": bronze, "wood": wood, "wood_lt": wood2, "patina": patina,
				"ink": _mat(Color("1a1210"), 0.6)}
		n.add_child(_glb_mi(gp.ScaleBody, gm))
	if gm.is_empty():
		#  받침 — 놋쇠 번 발 넷 위에 모깎은 나무 두 단(사이 놋쇠 띠). 아래 단 앞에 놋쇠 패 하나(큰 몸에서
		#  받침이 민짜면 나무 토막으로 읽힌다). 폭 22(띠 22.8)는 2026-10-03 에 32 에서 좁혔다 — 받침이
		#  옆 카운터 안에 들어앉아야 해서다(머리말 「받침은 온전히 카운터 위」). 약방 저울처럼
		#  좁은 받침에 높은 기둥이 서는 꼴이라 저울로는 오히려 더 읽힌다.
		for fx in [-8.5, 8.5]:
			for fz in [-6.0, 6.0]:
				n.add_child(_lmi("sc_foot", PackedVector2Array(SC_FOOT), Vector3(fx, 0.0, fz), brass, 12))
		n.add_child(_bbox(Vector3(22.0, 3.0, 17.0), 0.7, Vector3(0.0, 3.2, 0.0), wood))
		n.add_child(_bbox(Vector3(8.0, 1.8, 0.6), 0.25, Vector3(0.0, 3.2, 8.5), brass))
		n.add_child(_bbox(Vector3(22.8, 0.8, 17.8), 0.3, Vector3(0.0, 5.0, 0.0), brass))
		n.add_child(_bbox(Vector3(17.0, 2.6, 14.0), 0.7, Vector3(0.0, 6.7, 0.0), wood2))
		n.add_child(_lmi("sc_col", PackedVector2Array(SC_COL), Vector3.ZERO, brass, 20))
		#  (기둥 앞 둥근 눈금판은 찍어 보니 기둥 위 머리로 읽혀 걷었다 — 바늘만 남긴다.)
		n.add_child(_lmi("sc_hub", PackedVector2Array(SC_HUB), Vector3.ZERO, brass, 18))
		n.add_child(_lmi("sc_tip", PackedVector2Array(SC_TIP), Vector3.ZERO, brass, 14))
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = SCALE_PIV
	n.add_child(arm)
	if not gm.is_empty():
		arm.add_child(_glb_mi(gp.ScaleBeam, gm))
	else:
		var beam := _lmi("sc_arm", PackedVector2Array(SC_ARM), Vector3.ZERO, brass, 14)
		beam.rotation = Vector3(0.0, 0.0, -PI * 0.5)
		arm.add_child(beam)
		arm.add_child(_lmi("sc_needle", PackedVector2Array(SC_NEEDLE), Vector3(0.0, -1.0, 4.0), patina, 8))
	for sd in [-1.0, 1.0]:
		var s: float = float(sd)
		var pan := Node3D.new()
		pan.name = "PanL" if s < 0.0 else "PanR"
		n.add_child(pan)
		if not gm.is_empty():
			pan.add_child(_glb_mi(gp.ScalePan, gm))
			if s < 0.0:
				pan.add_child(_glb_mi(gp.ScaleWeight, gm, Vector3(2.0, PAN_TOP, 0.0)))
				var gw := _glb_mi(gp.ScaleWeight, gm, Vector3(-3.8, PAN_TOP, 0.8))
				gw.scale = Vector3.ONE * 0.7
				pan.add_child(gw)
			continue
		#  사슬 셋 — 고리(저울대 끝 혹)에서 접시 테 세 점으로
		pan.add_child(_ball(0.9, Vector3(0.0, -1.2, 0.0), patina))
		for k in 3:
			var a: float = TAU * float(k) / 3.0 + PI * 0.5
			pan.add_child(_rod(Vector3.ZERO, Vector3(cos(a) * 8.6, -23.6, sin(a) * 6.0), 0.9, patina))
		pan.add_child(_lmi("sc_pan", PackedVector2Array(SC_PAN), Vector3.ZERO, brass, 24))
		pan.add_child(_lmi("sc_bowl", PackedVector2Array(SC_BOWL), Vector3.ZERO, patina, 24))
		if s < 0.0:
			#  추 둘 — 큰 것 하나 · 작은 것 하나(바깥 접시)
			pan.add_child(_lmi("sc_wt", PackedVector2Array(SC_WEIGHT), Vector3(2.0, PAN_TOP, 0.0), brass, 14))
			var w2 := _lmi("sc_wt", PackedVector2Array(SC_WEIGHT), Vector3(-3.8, PAN_TOP, 0.8), brass, 14)
			w2.scale = Vector3.ONE * 0.7
			pan.add_child(w2)
	_scale_set(n, 0.0)


#  glb 한 벌의 메시를 노드 이름으로 — 없거나 못 읽으면 빈 사전. 한 번 불러 둔다(테이블을 다시 지어도).
static var _glb_mc := {}


static func _glb_parts(path: String) -> Dictionary:
	if _glb_mc.has(path):
		return _glb_mc[path]
	var out := {}
	var ps: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if ps != null:
		var sc := ps.instantiate()
		var todo: Array = [sc]
		while not todo.is_empty():
			var nd: Node = todo.pop_back()
			todo.append_array(nd.get_children())
			var mi := nd as MeshInstance3D
			if mi != null and mi.mesh != null:
				out[String(mi.name)] = mi.mesh
		sc.free()
	_glb_mc[path] = out
	return out


#  glb 메시 하나를 세운다 — 겉마다 재질 이름(Blender 재질 이름)으로 mats 의 재질을 끼운다.
static func _glb_mi(mesh: Mesh, mats: Dictionary, at := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	for i in mesh.get_surface_count():
		var sm: Material = mesh.surface_get_material(i)
		var key: String = sm.resource_name if sm != null else ""
		if mats.has(key):
			mi.set_surface_override_material(i, mats[key])
	return mi


#  안 접시 윗면 — 접시 노드에서 그 밑 놋쇠 판(−26 · 높이 3)과 짙은 안판(−24.3 · 0.4)의
#  윗면. 판 동전이 여기 눕는다(pan_top).
const PAN_TOP := -24.1


#  안 접시(PanR) 윗면 한가운데 — 면 좌표 (u, h, w). a 는 저울대 기울기(_scale_set 과 같은 값).
#  game.gd 의 판매 몸짓(_prop_*)이 판 동전과 그것을 집는 손을 여기 세운다 — 접시를 짓는
#  _scale_prop 과 같은 상수 · 같은 기울임(lean)이라 그림과 한 점도 안 갈린다.
#  X 화면 폭 · fy · ny 벨벳 먼/가까운 모서리 · back 빗변 · side 앞 들임 · flat 시점(make_table 과 같다).
static func pan_top(X: float, fy: float, ny: float, back: float, side: float, flat: float,
		a: float) -> Vector3:
	var sh: float = lean(sell_at(), X, (ny - fy) / flat, back, side)
	var t: float = deg_to_rad(lerpf(float(SCALE_TILT[0]), float(SCALE_TILT[1]), a))
	var p: Vector3 = SCALE_PIV + Vector3(SCALE_HL * cos(t), SCALE_HL * sin(t) + PAN_TOP, 0.0)
	return sell_at() + Vector3((p.x + sh * p.z) * SELL_K, p.y * SELL_K, p.z * SELL_K)


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
#  2026-10-03 얕은 몸 — 몸통 앞(w 0.5, h 29)에서 서랍장 위 앞(w 10.5, h 11)까지 61° 로
#  섰다(옛 53°). 카메라 쪽으로 더 서서 알이 화면에서 더 둥글다.
const KEY_B0 := Vector3(-16.2, 11.0, 10.5)
const KEY_B3 := Vector3(-16.2, 29.0, 0.5)
const KEY_N := Vector3(0.0, 10.0, 18.0)
const KEY_CAP := 1.7          # 알 윗면 — 경사면에서 법선으로(테 0.6 · 알 1.4 를 1.0 에 앉힌 끝)
#  내리치는 손바닥 밑 — 뒤 두 줄(row 1 · 2) 왼쪽 세 칸(col 0~2). 이 여섯이 Keys 노드에
#  들어가 같이 눌린다(_reg_set). 손바닥 한가운데는 뒤 줄 왼끝 알(col 0)이다(SLAM_AT) —
#  등록기가 화면 끝으로 물러나(2026-10-03) 상인에게 가장 가까운 알을 친다. 손가락이
#  오른쪽 알들을 덮는다.
const SLAM_KEYS := [[1, 0], [1, 1], [1, 2], [2, 0], [2, 1], [2, 2]]
const SLAM_AT := Vector2(2.0, 0.0)      # (줄 · 칸) — 칸은 사이값일 수 있다


#  건반 알 하나의 바닥 가운데(등록기 제 좌표). row 0 앞(손님 쪽) → 2 뒤 · col 0 왼 → 4 오른.
static func _key_at(row: float, col: float) -> Vector3:
	var p0: Vector3 = KEY_B0.lerp(KEY_B3, 0.2 + row * 0.3)
	return Vector3(-12.0 + col * 6.0, p0.y, p0.z)


#  내리치는 자리 — 손바닥이 닿는 건반 윗면 한가운데, 면 좌표 (u, h, w). game.gd 의 구매
#  몸짓(내리치기)이 상인 손바닥을 여기 세운다. 등록기를 짓는 식(_prop_node 의 기울임 ·
#  BUY_K)과 같다 — pan_top 과 같은 까닭. 눌림(_reg_set 의 몸 눌림)은 안 탄다 — 손이
#  닿는 그 틀에 몸이 눌리기 시작한다.
static func slam_top(X: float, fy: float, ny: float, back: float, side: float,
		flat: float) -> Vector3:
	var sh: float = lean(buy_at(), X, (ny - fy) / flat, back, side)
	var p: Vector3 = _key_at(SLAM_AT.x, SLAM_AT.y) + KEY_N.normalized() * KEY_CAP
	return buy_at() + Vector3((p.x + sh * p.z) * BUY_K, p.y * BUY_K, p.z * BUY_K)


#  서랍 앞끝 — 면 좌표 (u, h, w). open 은 서랍이 나온 몫(prop_glow 의 act), x 는 서랍 폭
#  위 자리(곱 전 · 0 이 한가운데 · 서랍은 ±17). game.gd 의 판 효과(동전 · 조각)가 여기서
#  튄다 — 열린 서랍 안에서 나와야 하므로 앞판보다 조금 안(w −3) · 서랍 윗면 높이다.
#  (시안 C 에서는 서랍 한가운데가 화면 밖(u 646)이라 왼쪽 반만 썼다 — 2 : 6 : 2 에서 등록기가
#  화면 안으로 들어와 서랍 폭 전부가 보인다. 고르는 것은 부르는 쪽이다 · game.gd BURST.drawer_x.)
const DRAWER_FRONT := 12.3     # 닫힌 서랍 앞판 앞면(곱 전 w)


static func drawer_front(X: float, fy: float, ny: float, back: float, side: float, flat: float,
		open: float, x := 0.0) -> Vector3:
	var sh: float = lean(buy_at(), X, (ny - fy) / flat, back, side)
	var p := Vector3(x, 8.4, DRAWER_FRONT - 3.0 + REG_OPEN * maxf(open, 0.0))
	return buy_at() + Vector3((p.x + sh * p.z) * BUY_K, p.y * BUY_K, p.z * BUY_K)


#  금전등록기 — 구매. 나무 서랍장(놋쇠 띠 · 앞 모서리 갓 · 서랍 · 손잡이) 위 청동 몸통
#  (놋쇠 기둥 둘 · 위 띠), 앞으로 기운 건반판(둥근 상아 알 셋 줄 다섯 칸), 위에 값 창(어두운
#  유리 안 상아 깃 셋), 반달 볏과 꼭지, 오른 옆구리 손잡이.
#  ── 시안 C (2026-10-02) ──
#  산 순간 상인이 건반을 내리친다 — 몸이 눌렸다 튀고, 손바닥 밑 건반 여섯이 들어가고,
#  서랍이 화면 20px 튀어나와 칸막이 쟁반의 동전을 보이고, 값 깃이 창 위 반으로 솟는다
#  (prop_glow · _reg_set). 동전 · 나뭇조각 · 놋쇠 부스러기는 game.gd 가 그린다.
#  ── 얕은 몸 (2026-10-03) ──
#  받침이 먼 턱 앞(w ≥ 2)에서 이름 줄(y 163.5) 위까지 화면 32px 안에 들어앉아야 해서
#  (머리말 「받침은 온전히 카운터 위」) 깊이를 31 → 21 로 덜었다 — 서랍장 −8.5..12.2(앞
#  모서리 갓까지) · 몸통 −8.5..0.5 · 값 창과 볏 −5.5 · 건반판 61°. 서랍(깊이 17)은 13 을
#  나와도 뒤끝이 서랍장 안이다. 깊이는 화면 0.788 배 · 키는 0.616 배라, 같은 화면 안에서
#  곱을 지키려면 깊이를 덜어야 한다. 닫힌 서랍장 앞끝이 y 160 · 볏 꼭지가 y 64 다.
#  ── 깎은 윤곽 (2026-10-16) ──
#  점검(상점)에서 등록기가 날 선 상자를 쌓은 것 · 건반은 기운 판 하나에 상아 원판 열다섯을 박은
#  「달걀판 · 계산기」 · 값 깃 셋은 상아 판에 먹 막대 둘이라 「mmm」 · 볏은 반원판에 짙은 원판이
#  뚫려 아치문 · 입으로 읽혔다. 이제
#   · 서랍장 · 몸통 · 위 띠 · 창 틀 · 서랍 앞판을 모깎은 상자로 — 모서리마다 빛 날이 선다. 서랍장
#     밑에 짙은 굽(걸레받이)을 두르고 앞 기둥은 받침 · 머리 고리가 있는 둥근 기둥이다.
#   · 건반 — 녹 짙은 놋쇠 판에 놋쇠 테를 두르고, 알마다 대(짙은 쇠) 위에 둥근 상아 머리를 세운다.
#     머리 윗면이 경사면에서 법선으로 KEY_CAP(1.7) 그대로라 내리치는 자리(slam_top)가 안 바뀐다.
#   · 값 창 — 놋쇠 틀 넷이 짙은 안을 두르고, 그 안에 숫자 깃 셋(REG_DIGIT — 3x5 도트 숫자)이 카메라
#     쪽으로 젖혀 선다(곧추서면 화면 5px 라 숫자가 안 든다). 평소 0 · 0 · 0, 값은 reg_value 가 세운다.
#   · 볏 — 겉 테 · 속 테 두 겹, 녹 짙은 바탕에 놋쇠 햇살 다섯과 가운데 혹. 꼭지는 항아리 침.
const RG_PILLAR := [Vector2(1.7, 0.0), Vector2(1.7, 0.9), Vector2(1.2, 1.3), Vector2(1.0, 1.7),
		Vector2(1.0, 18.5), Vector2(1.2, 18.9), Vector2(1.7, 19.3), Vector2(1.7, 20.2), Vector2(0.0, 20.2)]
#  건반 알 — 축은 경사면 법선. 대 · 둥근 머리(윗면 KEY_CAP)
const RG_KEY := [Vector2(0.55, 0.0), Vector2(0.55, 0.75), Vector2(1.5, 0.8), Vector2(1.75, 1.05),
		Vector2(1.7, 1.35), Vector2(1.25, 1.62), Vector2(0.6, 1.7), Vector2(0.0, 1.7)]
#  볏 — 축 w(앞이 +). 겉 테 · 단 · 속 테까지 놋쇠(RG_CREST) · 바탕은 녹(RG_FIELD) · 가운데 혹(RG_BOSS)
const RG_CREST := [Vector2(0.0, -1.8), Vector2(10.0, -1.8), Vector2(10.0, 1.2), Vector2(9.6, 1.8),
		Vector2(8.8, 1.8), Vector2(8.6, 1.4), Vector2(8.2, 1.4), Vector2(8.0, 1.9), Vector2(7.4, 2.1),
		Vector2(6.8, 1.9), Vector2(6.6, 1.2)]
const RG_FIELD := [Vector2(6.6, 1.2), Vector2(2.8, 1.2)]
const RG_BOSS := [Vector2(2.8, 1.2), Vector2(2.6, 1.7), Vector2(2.0, 2.4), Vector2(1.0, 2.8),
		Vector2(0.0, 2.9)]
const RG_FINIAL := [Vector2(1.4, 54.4), Vector2(1.8, 55.4), Vector2(1.5, 56.4), Vector2(2.2, 57.2),
		Vector2(1.8, 58.0), Vector2(1.0, 58.4), Vector2(0.0, 58.6)]
#  손잡이 알 — 나무 방추(축 = 자루 끝에서 아래)
const RG_KNOB := [Vector2(0.0, 0.0), Vector2(1.4, 0.6), Vector2(2.1, 1.8), Vector2(2.0, 3.0),
		Vector2(1.2, 3.8), Vector2(0.0, 4.0)]
#  값 깃 숫자 — 0~9, 3x5(윗줄부터)
const REG_DIGIT := ["111101101101111", "010110010010111", "111001111100111", "111001111001111",
		"101101111001001", "111100111001111", "111100111101111", "111001001010010",
		"111101111101111", "111101111001111"]
const RG_FLAG := Vector2(12.0 / BUY_K, 8.0 / BUY_K)   # 깃 하나(곱 전) — 카메라를 보면 화면 12 x 8px
static var _dig_tex: ImageTexture = null


#  숫자 깃 그림 — 열 칸(12 x 8 · 상아 바탕 · 먹 숫자 · 밑 한 줄 그늘)을 한 장에. 한 번 굽는다.
#  숫자는 둘째 줄부터 — 솟은 깃 윗머리 한두 줄은 창 위 틀에 가린다.
static func _reg_digits() -> ImageTexture:
	if _dig_tex != null:
		return _dig_tex
	var im := Image.create(120, 8, false, Image.FORMAT_RGBA8)
	im.fill(COL.ivory)
	for d in 10:
		im.fill_rect(Rect2i(d * 12, 7, 12, 1), COL.ivory.darkened(0.35))
		im.fill_rect(Rect2i(d * 12, 0, 1, 8), COL.ivory.darkened(0.2))
		var bits: String = REG_DIGIT[d]
		for i in 15:
			if bits[i] == "1":
				im.set_pixel(d * 12 + 5 + i % 3, 2 + i / 3, Color("1a1210"))
	_dig_tex = ImageTexture.create_from_image(im)
	return _dig_tex


#  값 깃 셋에 값을 세운다 — 세 자리(넘치면 999). 산 순간 game.gd 가 그 매물 값을 넘긴다(깃이 솟을 때
#  보인다). 깃마다 숫자 그림의 칸만 옮긴다(새 재질 · 메시를 안 짓는다).
static func reg_value(vp: SubViewport, v: int) -> void:
	if vp == null or not is_instance_valid(vp):
		return
	var pn: Node3D = vp.get_node_or_null("Table/Register")
	if pn == null:
		return
	var s := "%03d" % clampi(v, 0, 999)
	var ms: Array = pn.get_meta("digits", [])
	for i in mini(ms.size(), 3):
		(ms[i] as StandardMaterial3D).uv1_offset = Vector3(float(s.unicode_at(i) - 48) * 0.1, 0.0, 0.0)


const REG_BODY := "res://assets/models/register_body.glb"


#  등록기 몸체 glb — 메시 겉마다 재질 이름(Blender 재질 이름)으로 mats 의 재질을 끼운다. 없으면 null.
static func _reg_shell(mats: Dictionary) -> Node3D:
	if not ResourceLoader.exists(REG_BODY):
		return null
	var ps := load(REG_BODY) as PackedScene
	if ps == null:
		return null
	var sh := ps.instantiate() as Node3D
	var todo: Array = [sh]
	while not todo.is_empty():
		var nd: Node = todo.pop_back()
		todo.append_array(nd.get_children())
		var mi := nd as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mi.mesh.get_surface_count():
			var sm: Material = mi.mesh.surface_get_material(i)
			var key: String = sm.resource_name if sm != null else ""
			if mats.has(key):
				mi.set_surface_override_material(i, mats[key])
	return sh


static func _register_prop(root: Node3D, sh: float) -> void:
	var n := _prop_node(root, "Register", buy_at(), BUY_K, sh)
	n.set_meta("xf0", n.transform)
	var wood := _mat(WOOD.carve, 0.4)
	var wood2 := _mat(WOOD.beam, 0.35)
	var wood3 := _mat(WOOD.carve.darkened(0.25), 0.6)
	var body := _mat(COL.bronze.darkened(0.45), 0.42, 0.9)
	body.albedo_texture = _noise_tex(0.35, 0.78, 1.0, 31)
	var slope := _mat(COL.bronze.darkened(0.72), 0.5, 0.6)
	var brass := _brass()
	var patina := _patina()
	var ivory := _mat(COL.ivory, 0.45)
	var ink := _mat(Color("1a1210"), 0.6)
	var glass := _mat(COL.glass, 0.15)
	var coin := _mat(COL.brass.lightened(0.18), 0.3, 1.0)
	n.set_meta("glow", brass)
	n.add_child(_blob(Vector2(54.0, 32.0), Vector3(3.0, 0.15, 2.0), 0.75))
	#  몸체(움직이지 않는 주물 · 나무 · 볏)는 Blender 로 지은 glb 다(REG_BODY · scripts/tools/blender/register_body.py ·
	#  2026-10-16 「블렌더 깔았으니까 활용해봐」). 재질은 이름으로 이 함수의 재질을 끼운다 — prop_glow 가 미는 놋쇠가
	#  같은 것이라 빛 · 반짝임이 그대로 탄다. glb 가 없으면(가져오기 전) 옛 코드 몸으로 짓는다.
	var shell: Node3D = _reg_shell({"brass": brass, "bronze": body, "wood": wood, "wood_dk": wood3,
			"patina": patina, "ink": ink, "slope": slope})
	if shell != null:
		n.add_child(shell)
	if shell == null:
		#  서랍장 (u ±20 · h 0..10 · w −8.5..11.5) + 밑 굽 · 윗모서리 놋쇠 띠 · 앞 두 모서리 놋쇠 갓
		n.add_child(_bbox(Vector3(40.0, 10.0, 20.0), 0.7, Vector3(0.0, 5.0, 1.5), wood))
		n.add_child(_bbox(Vector3(41.2, 1.6, 21.2), 0.4, Vector3(0.0, 0.8, 1.5), wood3))
		n.add_child(_bbox(Vector3(41.0, 0.8, 21.0), 0.3, Vector3(0.0, 10.4, 1.5), brass))
		for sx in [-1.0, 1.0]:
			n.add_child(_bbox(Vector3(2.4, 10.0, 1.2), 0.35, Vector3(float(sx) * 19.4, 5.0, 11.6), brass))
	#  서랍 — 서랍장 안에 숨어 있다가 앞으로 미끄러진다(REG_OPEN). 안은 칸막이 쟁반이고
	#  칸마다 동전이 누웠다 — 열리면 보인다. 앞판은 모깎은 판에 한 단 들어간 속판 · 놋쇠 손잡이.
	var dr := Node3D.new()
	dr.name = "Drawer"
	n.add_child(dr)
	dr.add_child(_box(Vector3(34.0, 6.4, 17.0), Vector3(0.0, 4.6, 3.0), wood2))
	dr.add_child(_bbox(Vector3(35.0, 7.0, 0.8), 0.3, Vector3(0.0, 4.6, DRAWER_FRONT - 0.4), wood2))
	dr.add_child(_bbox(Vector3(29.0, 4.0, 0.4), 0.2, Vector3(0.0, 4.4, DRAWER_FRONT - 0.05),
			_mat(WOOD.beam.darkened(0.18), 0.4)))
	dr.add_child(_bbox(Vector3(9.0, 1.6, 1.2), 0.45, Vector3(0.0, 5.6, DRAWER_FRONT + 0.4), brass))
	for sx in [-12.0, 12.0]:
		dr.add_child(_ball(0.8, Vector3(float(sx), 5.0, DRAWER_FRONT + 0.1), brass))
	#  칸막이 — 가로 하나 · 세로 셋. 서랍 윗면(h 7.8) 위로 0.6 솟는다.
	dr.add_child(_box(Vector3(32.0, 1.2, 0.6), Vector3(0.0, 8.0, 5.5), wood3))
	for cx in [-8.0, 0.0, 8.0]:
		dr.add_child(_box(Vector3(0.6, 1.2, 10.0), Vector3(float(cx), 8.0, 6.0), wood3))
	for c in [[-12.5, 3.0, 0], [-12.0, 9.0, 1], [-4.0, 3.5, 1], [-4.5, 9.5, 0],
			[4.0, 3.0, 0], [4.5, 9.5, 1], [12.0, 3.5, 1], [12.5, 9.0, 0]]:
		var cu: float = float(c[0])
		var cw: float = float(c[1])
		dr.add_child(_cyl(2.6, 2.6, 0.8, Vector3(cu, 8.2, cw), coin, 12))
		if int(c[2]) == 1:
			dr.add_child(_cyl(2.6, 2.6, 0.8, Vector3(cu + 0.6, 9.0, cw - 0.4), coin, 12))
	var nrm: Vector3 = KEY_N.normalized()
	if shell == null:
		#  몸통 (u ±18 · h 10.8..31 · w −8.5..0.5)
		n.add_child(_bbox(Vector3(36.0, 20.2, 9.0), 0.9, Vector3(0.0, 20.9, -4.0), body))
		#  앞 기둥 둘 · 위 띠 — 놋쇠 테가 몸통 모서리를 짚는다
		for sx in [-1.0, 1.0]:
			n.add_child(_lmi("rg_pillar", PackedVector2Array(RG_PILLAR), Vector3(float(sx) * 17.4, 10.8, -0.2),
					brass, 12))
		n.add_child(_bbox(Vector3(37.6, 1.6, 10.2), 0.5, Vector3(0.0, 31.6, -4.0), brass))
		#  건반판 — 몸통 앞(w 0.5, h 29)에서 서랍장 위 앞(w 10.5, h 11)까지 기운 면 · 놋쇠 테 넷
		var b0: Vector3 = KEY_B0
		var b1 := Vector3(-KEY_B0.x, KEY_B0.y, KEY_B0.z)
		var b2 := Vector3(-KEY_B3.x, KEY_B3.y, KEY_B3.z)
		var b3: Vector3 = KEY_B3
		n.add_child(_quad([b0, b1, b2, b3], slope))
		var up: Vector3 = (KEY_B3 - KEY_B0).normalized()
		var sl: float = (KEY_B3 - KEY_B0).length()
		var kb := Basis(Vector3.RIGHT, up, nrm)
		for e in [[Vector3(-KEY_B0.x * 2.0 + 2.4, 1.4, 0.7), (b0 + b1) * 0.5 + up * 0.7],
				[Vector3(-KEY_B0.x * 2.0 + 2.4, 1.4, 0.7), (b2 + b3) * 0.5 - up * 0.7],
				[Vector3(1.4, sl, 0.7), (b0 + b3) * 0.5 + Vector3.RIGHT * 0.7],
				[Vector3(1.4, sl, 0.7), (b1 + b2) * 0.5 - Vector3.RIGHT * 0.7]]:
			var bar := _bbox(e[0], 0.3, e[1] + nrm * 0.35, brass)
			bar.basis = kb
			n.add_child(bar)
	#  건반 — 대 위 둥근 상아 머리. 경사면 법선으로 세운다(알마다 먹 점을 찍어 봤더니 두 배 몸에서
	#  도넛 · 눈알로 읽혀 걷었다). 손바닥 밑 여섯(SLAM_KEYS)은 Keys 노드에 들어가 같이 눌린다.
	var kx: float = atan2(nrm.z, nrm.y)
	var keys := Node3D.new()
	keys.name = "Keys"
	n.add_child(keys)
	for row in 3:
		for col in 5:
			var host: Node3D = keys if [row, col] in SLAM_KEYS else n
			var at := _key_at(float(row), float(col))
			var stem := _lmi("rg_stem", PackedVector2Array([Vector2(0.55, 0.0), Vector2(0.55, 0.8),
					Vector2(0.0, 0.8)]), at, ink, 8)
			stem.rotation = Vector3(kx, 0.0, 0.0)
			host.add_child(stem)
			var key := _lmi("rg_key", PackedVector2Array(RG_KEY), at, ivory, 14)
			key.rotation = Vector3(kx, 0.0, 0.0)
			host.add_child(key)
	if shell == null:
		#  값 창 — 놋쇠 틀 넷(u ±15 · h 32.4..45 · w −7.5..−3.5)이 짙은 안을 두른다. 안의 숫자 깃 셋은
		#  평소 창 아래쪽에 앉아 있고 산 순간 REG_POP 만큼 솟는다. 깃은 시점(−52°)만큼 젖혀 카메라를 본다.
		n.add_child(_bbox(Vector3(30.0, 1.7, 4.0), 0.5, Vector3(0.0, 44.15, -5.5), brass))
		n.add_child(_bbox(Vector3(30.0, 1.7, 4.0), 0.5, Vector3(0.0, 33.25, -5.5), brass))
		for sx in [-1.0, 1.0]:
			n.add_child(_bbox(Vector3(3.0, 9.6, 4.0), 0.5, Vector3(float(sx) * 13.5, 38.7, -5.5), brass))
	n.add_child(_box(Vector3(24.0, 9.6, 0.3), Vector3(0.0, 38.7, -7.35), glass))
	var fl := Node3D.new()
	fl.name = "Flags"
	n.add_child(fl)
	var dms := []
	var qm := QuadMesh.new()
	qm.size = RG_FLAG
	for fx in [-7.0, 0.0, 7.0]:
		var dm := _mat(Color.WHITE, 0.45)
		dm.albedo_texture = _reg_digits()
		dm.uv1_scale = Vector3(0.1, 1.0, 1.0)
		dms.append(dm)
		#  소품 뿌리의 깊이 기울임(sh)을 되돌린다 — 젖힌 깃은 깊이가 있어 기울면 숫자 열이 비껴 화소가
		#  빠진다. 깃이 화면에 곧은 12 x 8 이라야 3x5 숫자가 한 텍셀 = 한 화소로 선다.
		var f := MeshInstance3D.new()
		f.mesh = qm
		f.material_override = dm
		f.transform = Transform3D(Basis(Vector3.RIGHT, Vector3.UP, Vector3(-sh, 0.0, 1.0))
				* Basis(Vector3.RIGHT, -deg_to_rad(52.0)),
				Vector3(float(fx), 34.1 + RG_FLAG.y * 0.5 * cos(deg_to_rad(52.0)), -5.3))
		fl.add_child(f)
	n.set_meta("digits", dms)
	if shell == null:
		#  볏 — 축이 w 인 회전체의 윗반(반 바퀴만 돈다). 옛 볏은 온 원통의 아랫반을 통짜 창 틀 속에
		#  묻었다 — 틀이 넷으로 비어 이제 아랫반은 안 짓는다. 제 좌표 y 가 앞(w) · z 가 위다.
		var crest := Node3D.new()
		crest.transform = Transform3D(Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0),
				Vector3(0.0, 1.0, 0.0)), Vector3(0.0, 45.0, -5.5))
		n.add_child(crest)
		crest.add_child(_lmi("rg_crest", PackedVector2Array(RG_CREST), Vector3.ZERO, brass, 16, PI))
		crest.add_child(_lmi("rg_field", PackedVector2Array(RG_FIELD), Vector3.ZERO, patina, 16, PI))
		crest.add_child(_lmi("rg_boss", PackedVector2Array(RG_BOSS), Vector3.ZERO, brass, 8, PI))
		#  햇살 다섯 — 혹에서 속 테로(30° 간격)
		for k in 5:
			var a: float = deg_to_rad(30.0 + 30.0 * float(k))
			var ray := _bbox(Vector3(3.2, 0.6, 1.1), 0.25, Vector3(cos(a) * 4.9, 1.45, sin(a) * 4.9), brass)
			ray.basis = Basis(Vector3.UP, -a)
			crest.add_child(ray)
		n.add_child(_lmi("rg_finial", PackedVector2Array(RG_FINIAL), Vector3(0.0, 0.0, -5.5), brass, 14))
		#  손잡이 — 오른 옆구리 축에서 비스듬히 내려온 자루와 나무 손잡이 알
		n.add_child(_ball(3.0, Vector3(19.2, 21.0, -4.0), brass))
		n.add_child(_rod(Vector3(20.4, 21.0, -4.0), Vector3(23.6, 12.6, -4.0), 1.8, brass))
		var knob := _lmi("rg_knob", PackedVector2Array(RG_KNOB), Vector3(23.4, 13.2, -4.0), wood2, 12)
		knob.rotation = Vector3(0.0, 0.0, atan2(3.2, 8.4) - PI)
		n.add_child(knob)
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
