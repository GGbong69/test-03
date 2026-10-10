extends RefCounted

# ══════════════════════════════════════════════════════════
#  술집 문 — 제목 화면 (2026-10-06)
# ──────────────────────────────────────────────────────────
#  「지금 뭔가 게임의 컨셉트가 어찌저찌 좀 술집 들어가서 다트 던지는거 같은데 시작화면을 좀
#   퀄리티 업을 시작화면이 문앞인거야 문에 다트판이 걸려 있고 문 손잡이를 만들자 그리고 문
#   손잡이를 게임 시작 으로 만들면 어떨까?」. 옛 제목은 남색 단색 바탕에 빛 안 받은 판 하나라
#  게임 안(빛 받는 벽 · 벨벳 · 놋쇠)과 다른 게임으로 읽혔다.
#
#   · 다트판 벽(wall3d.gd)과 같은 길로 짓는다 — 3D 세트를 논리 1px = 1텍셀로 한 번 굽고
#     멈춘다(nearest). 판은 3D 에 없다. 2D 판(game.gd _draw_board)이 문 위 그 자리(BC)에
#     앉는다 — 카메라 축이 판 한가운데를 지나고 판 평면(z 0)에서 1m = S 논리 px 다.
#   · 밤의 술집 앞이다. 벽돌 벽에 판자 문 하나 · 문 위 간판 판(네온 「HIGHTON」은 2D 가 그
#     위에 켠다) · 쇠 띠 · 놋쇠 손잡이. 빛은 셋 — 문 위 램프(따뜻한 좁은 빛 · 화면 밖) ·
#     간판 네온의 분홍 번짐 · 오른쪽 거리의 찬 빛. 문틈으로 안의 불빛이 샌다.
#   · 손잡이가 곧 「시작」이다. 누르면 문이 경첩째 안으로 열린다(door_pose — 그동안만 화판을
#     굴린다). 안은 술집이다(_inside — 바 · 술병 선반 · 펜던트 · 다트 장).
#   · 벽돌 · 판자는 결(높이)에서 노멀을 내 램프 빛을 받는다(LIT_SHADER) — 한 텍셀이 한 px 라
#     빛 받은 모서리 · 줄눈 그늘이 곧 도트 그늘이다. 색은 도트 팔레트(dot_pal.py) 안에서 고른다.
#  ⚠ 헤드리스에서는 만들지 않는다(부르는 쪽이 _has_renderer 로 막는다).
# ══════════════════════════════════════════════════════════

const Room3D = preload("res://scripts/room3d.gd")

const S := 360.0          # 판 평면(z 0)에서 1m = 논리 px(wall3d 와 같다)
const EYE := 2.37         # 눈 — 문 앞에서 판까지(m). 던지는 줄과 같은 거리
const MARGIN := 14.0      # 흔들림 여유(논리 px)
#  카메라 높이(m) — 문 장면이 화면에서 CAM_Y × S 만큼 내려선다(2026-10-10 필기 「시작화면 HIGHTON
#  글짜 좀 내리기」 · 「간판이 너무 위」). 간판만 내리면 문 윗머리와 겹치므로 카메라를 올려 문 ·
#  간판 · 판을 통째로 내린다 — 문틀 윗변 위로 벽돌이 보인다. 판 평면의 한 점은 이 높이만큼
#  위에서 보이므로 화면 BC 는 세계 (0, CAM_Y) 다(proj · 2D 의 되짚기가 같은 값을 쓴다).
const CAM_Y := 0.045

#  문 치수(m) — 카메라 축(화면 BC)이 (0, 0)이다. 문은 그보다 오른쪽(cx)에 서고 판은 문 한가운데
#  (bx · by)에 걸린다. 2026-10-06 「프로필을 위에 UI랑 합치고 문이랑 조금 오른쪽으로 오고 문을
#  좀 더 크게 만들자 다트판에 비해 문이 너무 작어」 — 옛 판(문 폭 0.76 · 판이 문 폭의 86%)은
#  판이 문짝을 통째로 덮어 문이 판 받침으로 읽혔다. 문을 0.95m(화면 342px)로 키우고 오른쪽으로
#  0.20m(72px) 옮기고, 제목의 판은 board_k 배로 줄여(game.gd _door_set_xf) 문 폭의 반 남짓이
#  되게 한다 — 실물 문(0.9~1m)에 실물 판(테 지름 0.5m)의 비다. 왼쪽 벽돌 자리(x ~194)에 칠판이 든다.
#  문 윗변 +0.322(화면 y 80) 위로 간판 판(y 27~75)이 서고 그 위가 문틀이다.
#  문 밑은 화면 밖이다 — 카메라가 문 윗몸을 본다. 손잡이는 실물보다 높다(화면 안에 들게).
const DOOR := {
	"cx": 0.20,               # 문 한가운데 x
	"bx": 0.20, "by": -0.025, # 판 한가운데(제목 판이 서는 자리 — 화면 (392, 205))
	"board_k": 0.76,          # 제목 판 배율 — 테 반지름 약 90px(0.25m)
	"x0": -0.275, "x1": 0.675, "y0": -1.20, "y1": 0.322,
	"thick": 0.045,
	"face": -0.03,            # 문 앞면 z
	"open_deg": 72.0,         # 다 열린 각(안쪽으로)
	"case_w": 0.07,           # 문틀 폭
	"case_z": 0.018,          # 문틀 앞면 z(벽보다 나온다)
	"sign_y0": 0.335, "sign_y1": 0.47,   # 간판 자리(문틀 안 · 문 위) — 이제 뒷판(Transom)이다
	#  매단 간판(game.gd SIGNH · 2026-10-10) — 판자 아래 · 위(m) · 좌우를 문 폭에서 들이는 몫 · 고리
	#  높이(문틀 머리 밑변) · 고리가 판자 끝에서 들어선 몫. 판자는 2D 로 그려 흔들린다.
	"hang_y0": 0.322, "hang_y1": 0.437, "hang_in": 0.02, "hook_y": 0.47, "hook_in": 0.07,
	"head_y1": 0.54,          # 문틀 윗변
	"wall_z": -0.065,         # 벽돌 면 z
	"reveal": 0.20,           # 문 자리 안벽 깊이(문이 열리면 보인다)
	#  손잡이 — 세로 놋쇠 막대(문 가장자리에서 7cm 안). 받침 둘이 문에서 띄운다.
	"hx": 0.605, "hy0": -0.06, "hy1": -0.34, "hr": 0.011, "hz": 0.045,
	#  쇠 띠 — 경첩 쪽(왼변)에서 오른쪽으로 뻗는 검은 쇠 띠 둘. 위 띠 끝은 판 뒤로 든다.
	"strap_y": [0.21, -0.32], "strap_l": 0.30, "strap_h": 0.034,
	#  가로 띠장 — 판자를 묶는 앞판. 판 위 하나 · 판 밑 하나.
	"batten_y": [0.27, -0.56], "batten_h": 0.06,
}

const COL := {
	#  벽돌 넷 — 옅은 7d5052 는 빛 밑에서 분홍 · 보라 장으로 튀어 뺐다(촬영, 2026-10-06).
	"brick": [Color("6b2a1c"), Color("561916"), Color("6e3b39"), Color("4a1412")],
	"mortar": Color("2a2628"),
	"door": Color("402e1a"),
	"case": Color("2c1508"),
	"sign": Color("140904"),
	"iron": Color("1f1719"),
	"brass": Color("c89a4a"),
	"inside": Color("f7ba70"),
	"inside_hi": Color("fdeaa0"),
	"inside_lo": Color("c48b5a"),
	"reveal": Color("33100e"),
	"bg": Color("050404"),
	"amb": Color("6a7092"),
	"lamp": Color("ffd9a0"),
	"neon": Color("ff5ca8"),
	"street": Color("5a78c8"),
}

#  처음 판(환경광 0.32 · 램프 9 · 원뿔 34°)은 벽돌 벽이 끝까지 고루 밝아 한낮의 골목이었다
#  (촬영, 2026-10-06). 밤이다 — 빛 밖의 벽돌은 겨우 읽히고, 램프 웅덩이는 문과 문틀에만 고인다.
const LOOK := {
	"lamp_e": 6.5,
	"lamp_ang": 30.0,
	"lamp_att": 1.6,
	"lamp_at": Vector3(0.16, 1.25, 0.95),    # 판 위 앞 · 아주 조금 왼쪽
	"lamp_to": Vector2(0.19, 0.0),
	"amb": 0.10,              # 밤 — 빛 밖의 벽돌이 겨우 읽힌다
	"neon_e": 0.9, "neon_r": 1.1,
	"street_e": 0.55,
	"inside_e": 2.4,          # 안의 빛 — 문틈 · 열린 문으로 쏟아진다
	"bump": 0.9,              # 결의 높낮이 세기
	#  빛 웅덩이 [반지름 몫, 밝기] — 문 둘레는 고루, 문틀 바깥 한 뼘을 지나면 진다.
	"pool": [[0.0, 1.0], [0.40, 0.95], [0.55, 0.70], [0.68, 0.32], [0.80, 0.08], [0.90, 0.0],
			[1.0, 0.0]],
	#  나무 결 — 결 대비 몫 · 채도 몫(wall3d 의 벽 판자와 같은 처방). 처음 판은 결이 주황 줄로
	#  서서 램프 밑에서 지글거렸다 — 「긁힌 라미네이트」(다트판 벽이 먼저 겪은 그 실패다).
	"grain": 0.35, "sat": 0.55,
	"brick_sat": 0.72,
}


static func _cam(vp: SubViewport) -> Camera3D:
	return vp.get_node_or_null("Door/Cam") as Camera3D


#  면 위 한 점(m, z 포함)의 화면 자리(논리 px) — 판 한가운데가 bc. 2D 쪽이 손잡이 사각 ·
#  여닫이의 판 자리를 재는 데 쓴다(카메라와 같은 투영). dz — 카메라가 문 쪽으로 다가간 몫(m).
#  cam — 카메라가 옆으로 옮긴 몫(m · 문 안으로 들어갈 때 문 한가운데로 간다).
static func proj(p: Vector3, bc: Vector2, dz := 0.0, cam := 0.0) -> Vector2:
	return bc + Vector2(p.x - cam, CAM_Y - p.y) * S * scale_at(p.z, dz)


#  깊이 z 의 화면 배율 — 카메라가 dz 만큼 다가가면 커진다(z 0 · dz 0 에서 1).
static func scale_at(z: float, dz := 0.0) -> float:
	return EYE / maxf(EYE - dz - z, 0.05)


#  카메라를 문 쪽으로 민다(2026-10-06 「문 열고 카메라가 문 안으로 들어가는 연출 까지」).
#  화각은 그대로 — 다가가는 만큼 문틀이 벌어지며 지나가고 안의 불빛이 화면을 채운다.
static func cam_dolly(vp: SubViewport, dz: float, cx := 0.0) -> void:
	var cam := _cam(vp)
	if cam != null:
		cam.position = Vector3(cx, CAM_Y, EYE - dz)


#  손잡이 막대가 덮는 화면 사각(논리 px) — 누르는 칸은 부르는 쪽이 넓힌다.
static func handle_rect(bc: Vector2) -> Rect2:
	var z: float = float(DOOR.face) + float(DOOR.hz)
	var a := proj(Vector3(float(DOOR.hx), float(DOOR.hy0), z), bc)
	var b := proj(Vector3(float(DOOR.hx), float(DOOR.hy1), z), bc)
	var r: float = float(DOOR.hr) * S
	return Rect2(Vector2(a.x - r, a.y), Vector2(r * 2.0, b.y - a.y))


# ══ 만들기 ═══════════════════════════════════════════════════
static func make_door(host: Node) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = "Door3"
	vp.size = Vector2i(16, 16)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.gui_disable_input = true
	vp.positional_shadow_atlas_size = 4096
	host.add_child(vp)

	var root := Node3D.new()
	root.name = "Door"
	vp.add_child(root)

	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.near = 0.05
	cam.far = 30.0
	cam.position = Vector3(0.0, CAM_Y, EYE)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	root.add_child(cam)

	var we := WorldEnvironment.new()
	we.name = "Env"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = COL.bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = COL.amb
	env.ambient_light_energy = float(LOOK.amb)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false
	we.environment = env
	root.add_child(we)

	_wall(root)
	_frame(root)
	_inside(root)
	_slab(root)
	_lights(root)
	return vp


#  창 여백에 맞춘다(wall3d.wall_fit 과 같은 셈 — 판 테 링은 없다).
static func door_fit(vp: SubViewport, pad: Vector2, bc: Vector2, k: float) -> Vector2i:
	var ls := Vector2((bc.x + pad.x + MARGIN) * 2.0, (bc.y + pad.y + MARGIN) * 2.0)
	var px := Vector2i(int(ceilf(ls.x * k * 0.5)) * 2, int(ceilf(ls.y * k * 0.5)) * 2)
	vp.size = px
	var cam := _cam(vp)
	if cam != null:
		cam.fov = rad_to_deg(2.0 * atan((Vector2(px) / k).y * 0.5 / S / EYE))
	return px


#  여닫이 0..1 — 문짝이 경첩(왼변)째 안으로 open_deg 까지 돈다. 손잡이 · 띠가 같이 돈다.
static func door_pose(vp: SubViewport, k: float) -> void:
	var hinge: Node3D = vp.get_node_or_null("Door/Hinge") as Node3D
	if hinge != null:
		hinge.rotation_degrees = Vector3(0.0, float(DOOR.open_deg) * clampf(k, 0.0, 1.0), 0.0)


# ── 결 → 노멀 ─────────────────────────────────────────────
#  높이 그림(밝을수록 높다)에서 노멀을 **셰이더가** 낸다 — 이웃 텍셀 넷의 차. 한 텍셀 = 논리
#  1px 이라 빛 받은 모서리 · 그늘진 줄눈이 그대로 도트 그늘이 된다. 높이 그림이 따로 없으면
#  색의 밝기를 높이로 쓴다(판자 — 이음 · 결이 짙은 만큼 낮다).
const LIT_SHADER := """
shader_type spatial;
uniform sampler2D alb : source_color, filter_nearest;
uniform sampler2D hgt : filter_nearest;
uniform float bump = 0.9;
uniform float rough = 0.9;
uniform float spec = 0.25;
uniform float hk = 1.0;
uniform vec3 base : source_color = vec3(0.5);
uniform float grain = 1.0;
uniform float sat = 1.0;
void fragment() {
	vec2 ts = 1.0 / vec2(textureSize(hgt, 0));
	float l = texture(hgt, UV - vec2(ts.x, 0.0)).r * hk;
	float r = texture(hgt, UV + vec2(ts.x, 0.0)).r * hk;
	float u = texture(hgt, UV - vec2(0.0, ts.y)).r * hk;
	float d = texture(hgt, UV + vec2(0.0, ts.y)).r * hk;
	vec3 n = normalize(vec3((l - r) * bump, (d - u) * bump, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	vec3 c = texture(alb, UV).rgb;
	vec3 lw = vec3(0.2126, 0.7152, 0.0722);
	float lb = max(dot(base, lw), 0.0001);
	float dd = dot(c, lw) / lb - 1.0;
	float k = mix(grain, 1.0, smoothstep(0.40, 0.60, -dd));
	c = base + (c - base) * k;
	c = mix(vec3(dot(c, lw)), c, sat);
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
"""


#  hk — 높이를 몇 배로 읽는가(색의 밝기를 높이로 쓰는 판자는 어두워서 키운다).
#  wood — 나무 바탕색(결을 그 몫으로 누른다 · LOOK.grain · sat). 투명이면 안 누른다(벽돌).
static func _lit_mat(alb: Image, height: Image, rough: float, hk := 1.0,
		wood := Color(0, 0, 0, 0), sat := 1.0) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = LIT_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	var at := ImageTexture.create_from_image(alb)
	m.set_shader_parameter("alb", at)
	m.set_shader_parameter("hgt", at if height == null else ImageTexture.create_from_image(height))
	m.set_shader_parameter("bump", float(LOOK.bump))
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("hk", hk)
	m.set_shader_parameter("sat", sat)
	if wood.a > 0.0:
		m.set_shader_parameter("base", wood)
		m.set_shader_parameter("grain", float(LOOK.grain))
		m.set_shader_parameter("sat", float(LOOK.sat))
	return m


#  두께 있는 판 — 옆은 맨 색 상자, 앞은 그림 한 장(상자 메시의 UV 는 여섯 면을 한 그림에
#  나눠 붙여 결이 찌그러진다). at 은 상자 한가운데.
static func _panel(parent: Node, sz: Vector3, at: Vector3, front: Material, side: Color,
		nm: String) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = at
	parent.add_child(n)
	n.add_child(Room3D._box(sz, Vector3.ZERO, Room3D._mat(side, 0.85)))
	var qm := QuadMesh.new()
	qm.size = Vector2(sz.x, sz.y)
	var q := MeshInstance3D.new()
	q.name = "Face"
	q.mesh = qm
	q.material_override = front
	q.position = Vector3(0.0, 0.0, sz.z * 0.5 + 0.0006)
	n.add_child(q)
	return n


#  세로 판자 그림 — 누운 판자(Room3D._plank)를 세운다.
static func _vplank(wpx: int, hpx: int, base: Color, seed: int, lo: int, hi: int) -> Image:
	var pair: Array = Room3D._plank(hpx, wpx, base, seed, lo, hi, false)
	var im: Image = pair[0]
	im.rotate_90(CLOCKWISE)
	return im


#  매단 간판의 판자 그림(2D) — 옛 3D 간판과 같은 결 · 같은 씨.
static func sign_plank() -> Image:
	var w: float = float(DOOR.x1) - float(DOOR.x0) - float(DOOR.hang_in) * 2.0
	var h: float = float(DOOR.hang_y1) - float(DOOR.hang_y0)
	return _hplank(int(w * S), int(h * S), COL.sign, 7203, 18, 22)


static func _hplank(wpx: int, hpx: int, base: Color, seed: int, lo: int, hi: int) -> Image:
	var pair: Array = Room3D._plank(wpx, hpx, base, seed, lo, hi, false)
	return pair[0]


# ── 벽돌 ───────────────────────────────────────────────────
#  벽돌 한 장 72 × 24px(0.20 × 0.067m) · 줄눈 3px. 엇갈려 쌓는다. 장마다 색 · 얼룩이 다르고
#  모서리가 조금씩 이 빠졌다. 높이는 벽돌 1 · 줄눈 0 · 모서리 반 단 — 램프 밑에서 윗변이 빛을
#  받고 밑 줄눈이 그늘진다.
static func _brick_imgs(wpx: int, hpx: int, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var im := Image.create(wpx, hpx, false, Image.FORMAT_RGBA8)
	var hm := Image.create(wpx, hpx, false, Image.FORMAT_RGBA8)
	im.fill(COL.mortar)
	hm.fill(Color(0.0, 0.0, 0.0))
	var bw := 72
	var bh := 24
	var mo := 3
	var row := 0
	var y := 0
	var pal: Array = COL.brick
	while y < hpx:
		var off: int = (bw / 2) if row % 2 == 1 else 0
		var x: int = -off
		while x < wpx:
			var c: Color = pal[rng.randi() % pal.size()]
			c = c.lightened(rng.randf_range(0.0, 0.10)) if rng.randf() < 0.5 \
					else c.darkened(rng.randf_range(0.0, 0.18))
			var x0: int = maxi(x, 0)
			var x1: int = mini(x + bw - mo, wpx)
			var y1: int = mini(y + bh - mo, hpx)
			if x1 > x0 and y1 > y:
				im.fill_rect(Rect2i(x0, y, x1 - x0, y1 - y), c)
				hm.fill_rect(Rect2i(x0, y, x1 - x0, y1 - y), Color(1.0, 1.0, 1.0))
				#  모서리 반 단 — 윗변 · 아랫변 · 옆변 한 줄을 낮춰 둥글린다
				hm.fill_rect(Rect2i(x0, y, x1 - x0, 1), Color(0.55, 0.55, 0.55))
				hm.fill_rect(Rect2i(x0, y1 - 1, x1 - x0, 1), Color(0.55, 0.55, 0.55))
				hm.fill_rect(Rect2i(x0, y, 1, y1 - y), Color(0.7, 0.7, 0.7))
				hm.fill_rect(Rect2i(x1 - 1, y, 1, y1 - y), Color(0.7, 0.7, 0.7))
				#  얼룩 · 그을음 — 장 안에 옅고 짙은 점
				for _k in int(float((x1 - x0) * (y1 - y)) / 28.0):
					var px: int = rng.randi_range(x0, x1 - 1)
					var py: int = rng.randi_range(y, y1 - 1)
					var dc: Color = c.darkened(rng.randf_range(0.10, 0.30)) if rng.randf() < 0.7 \
							else c.lightened(rng.randf_range(0.06, 0.14))
					im.set_pixel(px, py, dc)
					hm.set_pixel(px, py, Color(0.85, 0.85, 0.85))
				#  이 빠진 모서리 — 줄눈 색으로 한두 칸
				for _k in rng.randi_range(0, 3):
					var ex: int = rng.randi_range(x0, x1 - 1)
					var ey: int = y if rng.randf() < 0.5 else y1 - 1
					im.set_pixel(ex, ey, COL.mortar.lightened(0.05))
					hm.set_pixel(ex, ey, Color(0.3, 0.3, 0.3))
			x += bw
		y += bh
		row += 1
	return [im, hm]


static func _quad_mesh(sz: Vector2, at: Vector3, m: Material, nm: String) -> MeshInstance3D:
	var qm := QuadMesh.new()
	qm.size = sz
	var q := MeshInstance3D.new()
	q.name = nm
	q.mesh = qm
	q.material_override = m
	q.position = at
	return q


#  벽돌 벽 — 문 자리를 비우고 셋(왼 · 오 · 위)으로 둔다. 문이 열리면 그 뒤가 안이다.
#  그림 한 장을 잘라 붙여 벽돌 줄이 세 조각에서 이어진다.
static func _wall(root: Node3D) -> void:
	var W := 1.8
	var top := 0.9
	var bot := -1.2
	var ox0: float = float(DOOR.x0) - float(DOOR.case_w)
	var ox1: float = float(DOOR.x1) + float(DOOR.case_w)
	var oy1: float = float(DOOR.head_y1)
	var z: float = float(DOOR.wall_z)
	var pair := _brick_imgs(int(W * 2.0 * S), int((top - bot) * S), 20261006)
	var im: Image = pair[0]
	var hm: Image = pair[1]
	var parts := [
		["WallL", Rect2(-W, bot, ox0 + W, top - bot)],
		["WallR", Rect2(ox1, bot, W - ox1, top - bot)],
		["WallT", Rect2(ox0, oy1, ox1 - ox0, top - oy1)],
	]
	for pt in parts:
		var r: Rect2 = pt[1]
		var px := Rect2i(int(roundf((r.position.x + W) * S)), int(roundf((top - r.end.y) * S)),
				int(roundf(r.size.x * S)), int(roundf(r.size.y * S)))
		#  채도를 한 단 누른다 — 네온 분홍 · 거리의 찬 빛이 얹히자 벽돌이 자홍 · 보라로 떠서
		#  판보다 먼저 눈에 들어왔다(촬영, 2026-10-06).
		var m := _lit_mat(im.get_region(px), hm.get_region(px), 0.95, 1.0, Color(0, 0, 0, 0),
				float(LOOK.brick_sat))
		root.add_child(_quad_mesh(r.size, Vector3(r.get_center().x, r.get_center().y, z), m,
				String(pt[0])))


# ── 문틀 · 간판 판 · 안벽 ───────────────────────────────────
static func _frame(root: Node3D) -> void:
	var cz: float = float(DOOR.case_z)
	var wz: float = float(DOOR.wall_z)
	var dep: float = cz - wz
	var cw: float = float(DOOR.case_w)
	var x0: float = float(DOOR.x0)
	var x1: float = float(DOOR.x1)
	var hy: float = float(DOOR.head_y1)
	var yb := -1.2
	#  옆 둘 · 위 하나 — 벽에서 나온 판자 문틀. 결이 짙어 높이를 두 배로 읽는다.
	for sx in [-1.0, 1.0]:
		var ci := _vplank(int(cw * S), int((hy - yb) * S), COL.case, 7101 + int(sx), 30, 40)
		var cx: float = (x0 - cw * 0.5) if sx < 0.0 else (x1 + cw * 0.5)
		_panel(root, Vector3(cw, hy - yb, dep), Vector3(cx, (hy + yb) * 0.5, wz + dep * 0.5),
				_lit_mat(ci, null, 0.8, 3.0, COL.case), COL.case, "CaseL" if sx < 0.0 else "CaseR")
	var hd: float = hy - float(DOOR.sign_y1)
	var hi := _hplank(int((x1 - x0 + cw * 2.0) * S), int(hd * S), COL.case, 7102,
			int(hd * S), int(hd * S) + 1)
	var mx: float = (x0 + x1) * 0.5
	_panel(root, Vector3(x1 - x0 + cw * 2.0, hd, dep + 0.01),
			Vector3(mx, hy - hd * 0.5, wz + dep * 0.5 + 0.005), _lit_mat(hi, null, 0.8, 3.0, COL.case),
			COL.case, "Head")
	#  간판 자리의 뒷판 — 문틀 안 · 문 위. 간판 판자는 여기 걸려 흔들린다(2D · game.gd SIGNH).
	#  간판보다 한 단 어둡게 두어 흔들릴 때 드러나는 가장자리 · 드리운 그늘이 읽힌다.
	var sh: float = float(DOOR.sign_y1) - float(DOOR.sign_y0)
	var si := _hplank(int((x1 - x0) * S), int(sh * S), COL.sign.darkened(0.35), 7203, 18, 22)
	_panel(root, Vector3(x1 - x0, sh, 0.03),
			Vector3(mx, (float(DOOR.sign_y0) + float(DOOR.sign_y1)) * 0.5,
			float(DOOR.face) - 0.012), _lit_mat(si, null, 0.7, 4.0, COL.sign), COL.sign, "Transom")
	#  문 자리 안벽(벽돌 두께) — 문이 열리면 양옆에 드러난다
	var rv: float = float(DOOR.reveal)
	var rm := Room3D._mat(COL.reveal, 0.95)
	for sx in [-1.0, 1.0]:
		var xx: float = x0 if sx < 0.0 else x1
		root.add_child(Room3D._box(Vector3(0.02, float(DOOR.sign_y0) - yb, rv),
				Vector3(xx + sx * 0.01, (float(DOOR.sign_y0) + yb) * 0.5, wz - rv * 0.5), rm))
	root.add_child(Room3D._box(Vector3(x1 - x0, 0.02, rv),
			Vector3(mx, float(DOOR.sign_y0) + 0.01, wz - rv * 0.5), rm))


# ── 안 — 술집 안 (2026-10-10) ────────────────────────────
#  「게임 시작할때 문이 열리잖아? 문 안 풍경 만들수 있어?」. 옛 안은 둥근 그러데이션 한 장이라 문이
#  열리면 화면이 빛으로만 찼다(그 앞에 세웠던 사람 · 선반 덩어리 셋은 카메라가 다가가자 화면을
#  막아 걷었었다 — 2026-10-06). 이제 HIGHTON 술집 안이다 — 상점 방(room3d)과 같은 어둡고 따뜻한
#  판자 벽 · 밑불 받은 술병 선반 · 녹색 법랑 펜던트 램프.
#   · 문간에서 곧장 보이는 뒷벽 하나에 다 건다. 카메라는 앞만 보고(화각 세로 26°) 눈이 낮아 옆벽 ·
#     바닥 · 천장은 거의 안 든다 — 문이 열리는 동안 문짝이 왼쪽을 가리므로 문간 너머로 보이는 띠는
#     뒷벽의 가운데 ~ 오른쪽이다.
#   · 왼쪽 ~ 가운데 — 바. 뒤 선반 셋(거울 판 · 밑불 · 술병) · 앞에 카운터(니스 윗판 · 세로 판자 앞판 ·
#     놋쇠 발 난간 · 탭 · 잔) · 의자 셋 · 위에 펜던트 셋(빛 웅덩이가 카운터에 진다).
#   · 오른쪽 — 다트 장. 판을 품은 나무 장의 두 문짝을 활짝 열어 안쪽 칠판에 분필로 501 을 깎아 내린
#     점수가 보이고, 위에서 그림등이 판을 비춘다. 걸어 들어가는 눈이 닿는 곳이다. 그 왼쪽 앞에
#     둥근 술 테이블(붉은 유리 촛불 · 맥주 둘) — 문간 너머 오른쪽 아래가 빈 벽으로 꺼지던 자리다.
#   · 안의 것 · 안의 빛은 층 LAYER_IN 에 둔다 — 밖의 빛(램프 · 네온 · 거리)은 안을 안 비추고(cull)
#     안의 빛은 밖을 안 비춘다. 닫힌 문은 그대로 한 장으로 굽는다(안은 문 뒤라 안 보인다).
#   · 안은 4~6m 밖이라 반 배쯤으로 보인다 — 그림은 1m 당 BAR.px 텍셀 · 밉맵(nearest)으로 결이
#     걸어 들어가는 동안 일렁이지 않게 한다.
const LAYER_IN := 2
const BAR := {
	"floor": -1.22, "ceil": 1.30, "back": -5.2, "x0": -2.8, "x1": 3.2,
	"px": 180.0,
	"rail_y": -0.40,                     # 허리 몰딩 — 위는 판자 벽 · 밑은 짙은 밑판
	#  바 — 카운터 앞면 z · 깊이 · 윗면 y · 오른끝 x / 뒤 선반 높이들 · 좌우 끝
	"cnt_z": -3.50, "cnt_d": 0.55, "cnt_y": -0.14, "cnt_x1": 0.62,
	"shelf_y": [-0.02, 0.32, 0.66], "shelf_x0": -2.5, "shelf_x1": 0.52,
	"stool_x": [-1.70, -0.90, -0.10], "stool_z": -3.12,
	"pend_x": [-1.60, -0.62, 0.36], "pend_z": -3.78, "pend_y": 0.64,
	#  다트 장 — 판 한가운데(뒷벽 위) · 판 반지름 · 장 반 폭
	"board": Vector2(1.58, 0.12), "board_r": 0.22, "cab": 0.34,
	"table": Vector2(0.98, -4.35),       # 술 테이블 한가운데(x · z)
	"lamp": Color("ffcf8a"), "enamel": Color("23402f"), "leather": Color("5a2422"),
	"chalk": Color("1d3326"), "chalk_ink": Color("d8d2c0"), "flight": Color("ff5ca8"),
}


static func _inside(root: Node3D) -> void:
	var bar := Node3D.new()
	bar.name = "Bar"
	root.add_child(bar)
	_bar_room(bar)
	_bar_back(bar)
	_bar_counter(bar)
	_bar_darts(bar)
	_bar_lamps(bar)
	_bar_table(bar)
	_layer_in(bar)
	#  문간 빛 — 열리는 문짝 · 안벽을 비춘다(밖 층 — 문짝이 안의 빛을 받아 돈다)
	var il := OmniLight3D.new()
	il.name = "InLamp"
	il.light_color = COL.inside
	il.light_energy = 1.6
	il.omni_range = 1.4
	il.position = Vector3(float(DOOR.cx), 0.2, float(DOOR.wall_z) - 0.35)
	il.light_cull_mask = 1
	root.add_child(il)


#  안의 것은 다 LAYER_IN 층에(빛은 그 층만 비춘다).
static func _layer_in(n: Node) -> void:
	for c in n.get_children():
		if c is VisualInstance3D:
			(c as VisualInstance3D).layers = LAYER_IN
		if c is Light3D:
			(c as Light3D).light_cull_mask = LAYER_IN
		_layer_in(c)


#  안 그림 재질 — nearest 밉맵(멀리서 결이 안 일렁인다).
static func _in_mat(im: Image, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := Room3D._mat(Color.WHITE, rough, metal)
	im.generate_mipmaps()
	m.albedo_texture = ImageTexture.create_from_image(im)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return m


static func _in_light(l: Light3D, nm: String, col: Color, e: float) -> Light3D:
	l.name = nm
	l.light_color = col
	l.light_energy = e
	l.shadow_enabled = false
	return l


#  빛무리 — 늘 카메라를 보는 더하기 막(유리알 · 전구 둘레의 번짐). 문 장면은 글로우를 끈다
#  (밖의 빛 받은 결까지 번진다) — 번짐은 이것으로만.
static func _halo(at: Vector3, sz: float, col: Color, a: float) -> MeshInstance3D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(col, a), Color(col, a * 0.3), Color(col, 0.0)])
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
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = gt
	return _quad_mesh(Vector2(sz, sz), at, m, "Halo")


#  방 — 뒷벽(판자 · 허리 몰딩 · 밑판) · 바닥 판자 · 천장 · 옆벽.
static func _bar_room(bar: Node3D) -> void:
	var B: Dictionary = BAR
	var fy: float = B.floor
	var cy: float = B.ceil
	var bz: float = B.back
	var x0: float = B.x0
	var x1: float = B.x1
	var ry: float = B.rail_y
	var pxm: float = B.px
	var W: float = x1 - x0
	var mx: float = (x0 + x1) * 0.5
	var up := _vplank(int(W * pxm), int((cy - ry) * pxm), Room3D.COL.wall2, 8101, 20, 28)
	bar.add_child(_quad_mesh(Vector2(W, cy - ry), Vector3(mx, (cy + ry) * 0.5, bz), _in_mat(up), "BackUp"))
	var lo := _vplank(int(W * pxm), int((ry - fy) * pxm), Room3D.COL.wall.darkened(0.30), 8102, 44, 60)
	bar.add_child(_quad_mesh(Vector2(W, ry - fy), Vector3(mx, (ry + fy) * 0.5, bz), _in_mat(lo), "BackLo"))
	#  허리 몰딩 — 윗변이 빛을 받는다
	bar.add_child(Room3D._box(Vector3(W, 0.05, 0.05), Vector3(mx, ry, bz + 0.025),
			Room3D._mat(Room3D.COL.trim, 0.5)))
	#  바닥 — 가로 판자(니스 · 빛 웅덩이가 번들거린다)
	var dz0: float = float(DOOR.wall_z) - float(DOOR.reveal)
	var D: float = dz0 - bz
	var fl := Room3D._plank(int(W * pxm * 0.5), int(D * pxm * 0.5), Color("2a1a10"), 8103, 14, 18, false)
	var fm := _in_mat(fl[0], 0.45)
	var fq := _quad_mesh(Vector2(W, D), Vector3(mx, fy, (dz0 + bz) * 0.5), fm, "Floor")
	fq.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	bar.add_child(fq)
	bar.add_child(Room3D._box(Vector3(W, 0.1, D), Vector3(mx, cy + 0.05, (dz0 + bz) * 0.5),
			Room3D._mat(Room3D.COL.ceil)))
	var sm := _in_mat(up.duplicate() as Image)
	for sx in [x0, x1]:
		var q := _quad_mesh(Vector2(D, cy - fy), Vector3(float(sx), (cy + fy) * 0.5, (dz0 + bz) * 0.5), sm,
				"Side")
		q.rotation_degrees = Vector3(0.0, 90.0 if float(sx) < 0.0 else -90.0, 0.0)
		bar.add_child(q)
	#  방을 고루 덮는 약한 따뜻한 빛 — 빛 웅덩이 밖이 먹으로 안 꺼지게
	var fill := _in_light(OmniLight3D.new(), "Fill", Color("ffb070"), 0.55) as OmniLight3D
	fill.omni_range = 5.5
	fill.omni_attenuation = 1.4
	fill.position = Vector3(0.4, 0.9, -2.6)
	bar.add_child(fill)


#  뒤 선반 — 거울 판 · 나무 테 · 선반 셋(밑불) · 술병. 밑에 짙은 밑장.
static func _bar_back(bar: Node3D) -> void:
	var B: Dictionary = BAR
	var bz: float = B.back
	var fy: float = B.floor
	var sx0: float = B.shelf_x0
	var sx1: float = B.shelf_x1
	var sw: float = sx1 - sx0
	var smx: float = (sx0 + sx1) * 0.5
	var sy: Array = B.shelf_y
	var y0: float = float(sy[0]) - 0.05
	var y1: float = float(sy[sy.size() - 1]) + 0.40
	var wood := Room3D._mat(Room3D.COL.wood, 0.6)
	var wood_dk := Room3D._mat(Room3D.COL.wood_dk, 0.7)
	#  거울 판 — 짙고 매끈하다(밑불 · 술병 빛을 받아 번들거린다)
	bar.add_child(Room3D._box(Vector3(sw, y1 - y0, 0.02), Vector3(smx, (y0 + y1) * 0.5, bz + 0.01),
			Room3D._mat(Color("1a1a22"), 0.12, 0.6)))
	#  테 — 기둥 넷 · 머리 갓
	for k in 4:
		var px: float = sx0 + sw * float(k) / 3.0
		bar.add_child(Room3D._box(Vector3(0.06, y1 - y0 + 0.04, 0.10),
				Vector3(px, (y0 + y1) * 0.5, bz + 0.05), wood))
	bar.add_child(Room3D._box(Vector3(sw + 0.20, 0.10, 0.16), Vector3(smx, y1 + 0.05, bz + 0.08), wood))
	bar.add_child(Room3D._box(Vector3(sw + 0.24, 0.03, 0.19), Vector3(smx, y1 + 0.115, bz + 0.09),
			Room3D._mat(Room3D.COL.trim, 0.5)))
	#  밑장 — 선반 밑에서 바닥까지
	bar.add_child(Room3D._box(Vector3(sw + 0.1, y0 - fy, 0.42), Vector3(smx, (y0 + fy) * 0.5, bz + 0.21),
			wood_dk))
	var glow := Room3D._glow(B.lamp, 1.6)
	for s in sy.size():
		var y: float = float(sy[s])
		bar.add_child(Room3D._box(Vector3(sw, 0.03, 0.24), Vector3(smx, y, bz + 0.12), wood))
		#  밑불 — 선반 앞 끝 밑의 빛 줄 · 술병을 밑에서 비추는 빛 둘
		bar.add_child(Room3D._box(Vector3(sw - 0.06, 0.008, 0.012), Vector3(smx, y - 0.02, bz + 0.23), glow))
		for h in 2:
			var ol := _in_light(OmniLight3D.new(), "Shelf", B.lamp, 0.7) as OmniLight3D
			ol.omni_range = 1.1
			ol.omni_attenuation = 1.6
			ol.position = Vector3(sx0 + sw * (0.25 + 0.5 * float(h)), y + 0.14, bz + 0.34)
			bar.add_child(ol)
	#  술병 — 상점 방과 같은 빛깔(BOTTLE_COLS) · 씨 고정
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261010
	for s in sy.size():
		var y: float = float(sy[s]) + 0.015
		var x: float = sx0 + 0.07
		while x < sx1 - 0.07:
			var bh: float = rng.randf_range(0.15, 0.24)
			var br: float = rng.randf_range(0.032, 0.05)
			var bc: Color = Room3D.BOTTLE_COLS[rng.randi() % Room3D.BOTTLE_COLS.size()]
			var gm := Room3D._mat(bc, 0.15, 0.0)
			gm.emission_enabled = true
			gm.emission = bc
			gm.emission_energy_multiplier = 0.18
			var z: float = bz + 0.10 + rng.randf_range(-0.02, 0.03)
			bar.add_child(Room3D._cyl(br, br, bh, Vector3(x, y + bh * 0.5, z), gm, 8))
			bar.add_child(Room3D._cyl(br * 0.35, br * 0.42, 0.07, Vector3(x, y + bh + 0.035, z), gm, 6))
			x += br * 2.0 + rng.randf_range(0.02, 0.09)


#  카운터 — 앞판(세로 판자) · 니스 윗판 · 놋쇠 발 난간 · 탭 · 잔 · 의자.
static func _bar_counter(bar: Node3D) -> void:
	var B: Dictionary = BAR
	var fy: float = B.floor
	var cz: float = B.cnt_z
	var cd: float = B.cnt_d
	var cy: float = B.cnt_y
	var x0: float = B.x0
	var x1: float = B.cnt_x1
	var L: float = x1 - x0
	var mx: float = (x0 + x1) * 0.5
	var pxm: float = B.px
	#  앞판 — 세로 판자 · 위아래 몰딩
	var fh: float = cy - 0.03 - fy
	var fr := _vplank(int(L * pxm), int(fh * pxm), Room3D.COL.wood.darkened(0.12), 8104, 26, 34)
	bar.add_child(_quad_mesh(Vector2(L, fh), Vector3(mx, fy + fh * 0.5, cz), _in_mat(fr, 0.7), "CntFront"))
	bar.add_child(Room3D._box(Vector3(L, 0.04, cd), Vector3(mx, fy + fh * 0.5, cz - cd * 0.5),
			Room3D._mat(Room3D.COL.wood_dk)))
	bar.add_child(Room3D._box(Vector3(L, fh, 0.04), Vector3(mx, fy + fh * 0.5, cz - cd + 0.02),
			Room3D._mat(Room3D.COL.wood_dk)))
	bar.add_child(Room3D._box(Vector3(0.04, fh, cd), Vector3(x1 - 0.02, fy + fh * 0.5, cz - cd * 0.5),
			Room3D._mat(Room3D.COL.wood_dk)))
	bar.add_child(Room3D._box(Vector3(L, 0.04, 0.04), Vector3(mx, cy - 0.07, cz + 0.01),
			Room3D._mat(Room3D.COL.trim, 0.5)))
	bar.add_child(Room3D._box(Vector3(L, 0.10, 0.03), Vector3(mx, fy + 0.05, cz + 0.015),
			Room3D._mat(Room3D.COL.wood_dk)))
	#  윗판 — 니스(빛 웅덩이가 번들거린다) · 앞으로 조금 나온다
	var tp := Room3D._plank(int((L + 0.06) * pxm), int((cd + 0.08) * pxm), Room3D.COL.oak, 8105, 16, 22, false)
	var tm := Room3D._varnish(tp)
	tm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	bar.add_child(Room3D._box(Vector3(L + 0.06, 0.05, cd + 0.08), Vector3(mx, cy - 0.025, cz - cd * 0.5 + 0.04),
			tm))
	#  놋쇠 발 난간 — 앞판 밑에서 한 뼘 뜬다(받침 몇)
	var brass := Room3D._mat(Room3D.COL.brass, 0.3, 0.8)
	var rail := Room3D._cyl(0.022, 0.022, L, Vector3(mx, fy + 0.24, cz + 0.12), brass, 10)
	rail.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	bar.add_child(rail)
	var k := x0 + 0.4
	while k < x1:
		var po := Room3D._cyl(0.012, 0.012, 0.12, Vector3(k, fy + 0.24, cz + 0.06), brass, 8)
		po.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		bar.add_child(po)
		k += 0.9
	#  탭 — 놋쇠 기둥 하나에 손잡이 셋
	var tx: float = -0.95
	var tz: float = cz - cd * 0.55
	bar.add_child(Room3D._cyl(0.035, 0.04, 0.26, Vector3(tx, cy + 0.13, tz), brass, 12))
	for h in 3:
		var hx: float = tx - 0.09 + 0.09 * float(h)
		bar.add_child(Room3D._cyl(0.012, 0.012, 0.07, Vector3(hx, cy + 0.21, tz + 0.05), brass, 8))
		var hd := Room3D._cyl(0.016, 0.012, 0.11, Vector3(hx, cy + 0.30, tz + 0.06),
				Room3D._mat([Color("1a1414"), Color("6b1f22"), Color("1f3b2a")][h], 0.5), 8)
		hd.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
		bar.add_child(hd)
	#  잔 — 맥주 둘 · 빈 잔 하나
	var gl := Room3D._mat(Color(0.75, 0.80, 0.78), 0.08, 0.3)
	var beer := Room3D._mat(Color("c98a2a"), 0.2)
	beer.emission_enabled = true
	beer.emission = Color("c98a2a")
	beer.emission_energy_multiplier = 0.25
	for gx in [-1.95, -0.30, 0.25]:
		var full: bool = float(gx) < 0.0
		var gz: float = cz - 0.18
		bar.add_child(Room3D._cyl(0.035, 0.03, 0.14, Vector3(float(gx), cy + 0.07, gz), beer if full else gl, 10))
		if full:
			bar.add_child(Room3D._cyl(0.036, 0.036, 0.025, Vector3(float(gx), cy + 0.152, gz),
					Room3D._mat(Color("efe6cf"), 0.9), 10))
	#  의자 — 가죽 방석 · 기둥 · 발 받침 고리 · 받침판
	var leather := Room3D._mat(B.leather, 0.55)
	var iron := Room3D._mat(Color("1b1716"), 0.4, 0.6)
	for sx in B.stool_x:
		var px: float = float(sx)
		var pz: float = B.stool_z
		var st: float = fy + 0.76
		bar.add_child(Room3D._cyl(0.17, 0.16, 0.07, Vector3(px, st, pz), leather, 16))
		bar.add_child(Room3D._cyl(0.15, 0.15, 0.02, Vector3(px, st - 0.045, pz), iron, 16))
		bar.add_child(Room3D._cyl(0.025, 0.025, st - fy, Vector3(px, (st + fy) * 0.5, pz), iron, 8))
		bar.add_child(Room3D._cyl(0.13, 0.13, 0.015, Vector3(px, fy + 0.30, pz), brass, 16))
		bar.add_child(Room3D._cyl(0.20, 0.21, 0.02, Vector3(px, fy + 0.01, pz), iron, 16))


#  펜던트 셋 — 줄 · 녹색 법랑 갓(밑이 트였다 · 안쪽은 전구 빛) · 전구 · 밑으로 빛 · 빛무리.
static func _bar_lamps(bar: Node3D) -> void:
	var B: Dictionary = BAR
	var lamp: Color = B.lamp
	var cy: float = B.ceil
	var pz: float = B.pend_z
	var py: float = B.pend_y
	var en := Room3D._mat(B.enamel, 0.35, 0.2)
	var inner := Room3D._glow(lamp.lerp(Color("ffe6b0"), 0.4), 0.9)
	for lx in B.pend_x:
		var x: float = float(lx)
		bar.add_child(Room3D._cyl(0.006, 0.006, cy - py - 0.17, Vector3(x, (cy + py + 0.17) * 0.5, pz),
				Room3D._mat(Color("0c0a0a"))))
		bar.add_child(Room3D._cyl(0.03, 0.03, 0.04, Vector3(x, py + 0.17, pz), Room3D._brass(), 10))
		for side in 2:
			var cm := CylinderMesh.new()
			cm.top_radius = 0.04 if side == 0 else 0.036
			cm.bottom_radius = 0.19 if side == 0 else 0.183
			cm.height = 0.15
			cm.radial_segments = 20
			cm.rings = 1
			cm.cap_bottom = false
			cm.cap_top = side == 0
			cm.flip_faces = side == 1
			var mi := MeshInstance3D.new()
			mi.mesh = cm
			mi.material_override = en if side == 0 else inner
			mi.position = Vector3(x, py + 0.075, pz)
			bar.add_child(mi)
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.04
		sm.height = 0.08
		bulb.mesh = sm
		bulb.material_override = Room3D._glow(Color("fff1cf"), 4.0)
		bulb.position = Vector3(x, py + 0.02, pz)
		bar.add_child(bulb)
		var sl := _in_light(SpotLight3D.new(), "Pend", lamp, 4.5) as SpotLight3D
		sl.spot_range = 2.6
		sl.spot_angle = 40.0
		sl.spot_angle_attenuation = 1.4
		sl.spot_attenuation = 0.8
		sl.position = Vector3(x, py + 0.02, pz)
		sl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		bar.add_child(sl)
		bar.add_child(_halo(Vector3(x, py + 0.0, pz + 0.05), 0.55, lamp, 0.30))


#  둥근 술 테이블 — 바 끝과 다트 장 사이 앞(던지는 길은 비킨다). 받침 하나 · 윗판 · 맥주 둘 ·
#  붉은 유리 촛불(작은 빛 웅덩이). 문간 너머 오른쪽 아래가 빈 벽으로 꺼지던 자리를 채운다.
static func _bar_table(bar: Node3D) -> void:
	var B: Dictionary = BAR
	var fy: float = B.floor
	var tc: Vector2 = B.table
	var ty: float = fy + 1.04
	var wood := Room3D._mat(Room3D.COL.wood_dk.lightened(0.10), 0.45, 0.1)
	var iron := Room3D._mat(Color("1b1716"), 0.4, 0.6)
	bar.add_child(Room3D._cyl(0.30, 0.30, 0.04, Vector3(tc.x, ty - 0.02, tc.y), wood, 24))
	bar.add_child(Room3D._cyl(0.035, 0.035, ty - fy, Vector3(tc.x, (ty + fy) * 0.5, tc.y), iron, 8))
	bar.add_child(Room3D._cyl(0.22, 0.24, 0.03, Vector3(tc.x, fy + 0.015, tc.y), iron, 16))
	var beer := Room3D._mat(Color("c98a2a"), 0.2)
	beer.emission_enabled = true
	beer.emission = Color("c98a2a")
	beer.emission_energy_multiplier = 0.25
	var foam := Room3D._mat(Color("efe6cf"), 0.9)
	for g in [Vector2(-0.14, 0.04), Vector2(0.12, -0.08)]:
		bar.add_child(Room3D._cyl(0.035, 0.03, 0.14, Vector3(tc.x + g.x, ty + 0.07, tc.y + g.y), beer, 10))
		bar.add_child(Room3D._cyl(0.036, 0.036, 0.022, Vector3(tc.x + g.x, ty + 0.15, tc.y + g.y), foam, 10))
	var cup := Room3D._glow(Color("c2402c"), 1.2)
	bar.add_child(Room3D._cyl(0.035, 0.03, 0.07, Vector3(tc.x + 0.02, ty + 0.035, tc.y + 0.10), cup, 12))
	var flame := Room3D._glow(Color("ffd890"), 3.0)
	bar.add_child(Room3D._cyl(0.004, 0.008, 0.025, Vector3(tc.x + 0.02, ty + 0.083, tc.y + 0.10), flame, 6))
	var cl := _in_light(OmniLight3D.new(), "Candle", Color("ff9a50"), 0.9) as OmniLight3D
	cl.omni_range = 0.9
	cl.omni_attenuation = 1.8
	cl.position = Vector3(tc.x + 0.02, ty + 0.12, tc.y + 0.10)
	bar.add_child(cl)
	bar.add_child(_halo(Vector3(tc.x + 0.02, ty + 0.06, tc.y + 0.14), 0.30, Color("ff9a50"), 0.22))


#  다트 장 — 뒷벽의 나무 장 · 판(그림) · 열어 젖힌 두 문짝(안쪽 칠판에 분필 점수) · 꽂힌 다트 셋 ·
#  위에서 판을 비추는 그림등(그늘을 낸다).
static func _bar_darts(bar: Node3D) -> void:
	var B: Dictionary = BAR
	var bz: float = B.back
	var bc: Vector2 = B.board
	var R: float = B.board_r
	var hw: float = B.cab
	var oak := Room3D._mat(Room3D.COL.oak.lightened(0.08), 0.55)
	var oak_dk := Room3D._mat(Room3D.COL.oak.darkened(0.25), 0.7)
	#  장 — 뒷판 · 테 넷(앞으로 나온 상자)
	bar.add_child(Room3D._box(Vector3(hw * 2.0, hw * 2.0, 0.03), Vector3(bc.x, bc.y, bz + 0.015), oak_dk))
	var dep := 0.11
	for e in [[0.0, hw - 0.02, hw * 2.0, 0.04], [0.0, -hw + 0.02, hw * 2.0, 0.04],
			[-hw + 0.02, 0.0, 0.04, hw * 2.0], [hw - 0.02, 0.0, 0.04, hw * 2.0]]:
		bar.add_child(Room3D._box(Vector3(float(e[2]), float(e[3]), dep),
				Vector3(bc.x + float(e[0]), bc.y + float(e[1]), bz + dep * 0.5), oak))
	#  판 — 검은 받침 원 · 판 그림
	var back := Room3D._cyl(R + 0.02, R + 0.02, 0.04, Vector3(bc.x, bc.y, bz + 0.05), Room3D._mat(Color("15100d")), 32)
	back.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	bar.add_child(back)
	var bm := Room3D._mat(Color.WHITE, 0.75)
	bm.albedo_texture = _board_img(96)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	bar.add_child(_quad_mesh(Vector2(R * 2.0, R * 2.0), Vector3(bc.x, bc.y, bz + 0.0705), bm, "Board"))
	#  꽂힌 다트 둘 — 20 위 언저리 · 판에서 비스듬히 나온다(앞에서 보면 깃 끝 십자 · 자루 한 획)
	var steel := Room3D._mat(Color("8c8f96"), 0.3, 0.8)
	var fl := Room3D._mat(B.flight, 0.6)
	fl.cull_mode = BaseMaterial3D.CULL_DISABLED
	for dd in [Vector2(0.010, 0.135), Vector2(-0.045, 0.040)]:
		var dart := Node3D.new()
		dart.position = Vector3(bc.x + dd.x, bc.y + dd.y, bz + 0.072)
		dart.rotation_degrees = Vector3(-14.0, dd.x * 300.0, 0.0)
		bar.add_child(dart)
		var brl := Room3D._cyl(0.005, 0.005, 0.04, Vector3(0.0, 0.0, 0.025), steel, 6)
		brl.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		dart.add_child(brl)
		var sh := Room3D._cyl(0.0025, 0.0025, 0.04, Vector3(0.0, 0.0, 0.065), Room3D._mat(Color("101010")), 6)
		sh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		dart.add_child(sh)
		for fr in [Vector3(0.0, 90.0, 0.0), Vector3(90.0, 0.0, 0.0)]:
			var f := _quad_mesh(Vector2(0.026, 0.03), Vector3(0.0, 0.0, 0.085), fl, "Flight")
			f.rotation_degrees = fr
			dart.add_child(f)
	#  문짝 둘 — 경첩(장 양끝)째 활짝(155°) 열려 안쪽 칠판이 앞을 본다
	var ch := _scoreboard_img(56, 104, 8106)
	var cm := _in_mat(ch, 0.95)
	var ch2 := _scoreboard_img(56, 104, 8107)
	var cm2 := _in_mat(ch2, 0.95)
	for sd in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(bc.x + sd * hw, bc.y, bz + dep)
		piv.rotation_degrees = Vector3(0.0, 155.0 * sd, 0.0)
		bar.add_child(piv)
		#  닫힌 자리에서 문짝은 경첩에서 장 한가운데 쪽(-sd)으로 뻗는다 · 안쪽(-z)이 칠판
		var lx: float = -sd * hw * 0.5
		piv.add_child(Room3D._box(Vector3(hw, hw * 2.0, 0.025), Vector3(lx, 0.0, 0.0125), oak))
		var q := _quad_mesh(Vector2(hw - 0.05, hw * 2.0 - 0.05), Vector3(lx, 0.0, -0.001),
				cm if sd < 0.0 else cm2, "Chalk")
		q.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		piv.add_child(q)
	#  그림등 — 장 위 놋쇠 갓 · 판을 비추는 빛(그늘)
	var lb := Room3D._cyl(0.022, 0.022, 0.30, Vector3(bc.x, bc.y + hw + 0.10, bz + 0.20), Room3D._brass(), 12)
	lb.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	bar.add_child(lb)
	var arm := Room3D._cyl(0.008, 0.008, 0.18, Vector3(bc.x, bc.y + hw + 0.08, bz + 0.10), Room3D._brass(), 6)
	arm.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	bar.add_child(arm)
	bar.add_child(Room3D._box(Vector3(0.26, 0.006, 0.01), Vector3(bc.x, bc.y + hw + 0.08, bz + 0.21),
			Room3D._glow(B.lamp, 2.5)))
	var at := Vector3(bc.x, bc.y + hw + 0.06, bz + 0.40)
	var sl := _in_light(SpotLight3D.new(), "Pict", Color("ffe2b8"), 2.6) as SpotLight3D
	sl.spot_range = 2.0
	sl.spot_angle = 26.0
	sl.spot_angle_attenuation = 1.6
	sl.transform = Transform3D(Basis.looking_at(Vector3(bc.x, bc.y - 0.05, bz) - at, Vector3.UP), at)
	bar.add_child(sl)
	bar.add_child(_halo(Vector3(bc.x, bc.y + hw + 0.08, bz + 0.24), 0.22, B.lamp, 0.16))


#  판 그림 — 게임 판과 같은 빛깔(game.gd C_LIGHT · C_DARK 칸 · C_RED · C_GREEN 띠 · 숫자 고리 검정).
#  숫자 고리에 점을 찍었더니 멀리서 시계로 읽혀 맨 고리로 둔다.
static func _board_img(n: int) -> ImageTexture:
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
				col = Color("16131a")
			if r <= 0.80:
				col = Color("e8dfc8") if sec % 2 == 0 else Color("2b2438")
				if (r > 0.72 and r <= 0.80) or (r > 0.44 and r <= 0.50):
					col = Color("d8483d") if sec % 2 == 0 else Color("479a58")
			if r <= 0.10:
				col = Color("479a58")
			if r <= 0.05:
				col = Color("d8483d")
			im.set_pixel(x, y, col)
	return ImageTexture.create_from_image(im)


#  3 × 5 숫자(분필 점수판)
const DIG := ["111101101101111", "010110010010111", "111001111100111", "111001111001111",
		"101101111001001", "111100111001111", "111100111101111", "111001010010010",
		"111101111101111", "111101111001111"]


#  문짝 안쪽 칠판 — 두 칸(둘이 겨룬다)에 501 부터 깎아 내린 점수. 지난 값은 그어 지웠다.
#  분필은 다 안 묻는다(점이 빠진다) · 옛 글을 문질러 지운 얼룩이 옅게 남았다.
static func _scoreboard_img(w: int, h: int, seed: int) -> Image:
	var B: Dictionary = BAR
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(B.chalk)
	var ink: Color = B.chalk_ink
	var smear: Color = Color(B.chalk).lerp(ink, 0.10)
	for _k in 40:
		im.fill_rect(Rect2i(rng.randi_range(0, w - 6), rng.randi_range(0, h - 2), rng.randi_range(3, 8), 1), smear)
	var dot := func(x: int, y: int) -> void:
		if x >= 0 and y >= 0 and x < w and y < h and rng.randf() > 0.14:
			im.set_pixel(x, y, ink.darkened(rng.randf_range(0.0, 0.18)))
	var num := func(v: int, x: int, y: int) -> void:
		var t := str(v)
		for i in t.length():
			var g: String = DIG[int(t[i])]
			for gy in 5:
				for gx in 3:
					if g[gy * 3 + gx] == "1":
						dot.call(x + i * 4 + gx, y + gy)
	#  가운데 세로줄 · 머리 밑 가로줄
	for y in range(3, h - 3):
		dot.call(w / 2, y)
	for x in range(3, w - 3):
		dot.call(x, 10)
	for col in 2:
		var cx: int = 4 + col * (w / 2)
		num.call(501, cx + 6, 3)
		var v := 501
		var y := 14
		while y < h - 8 and v > 40:
			v -= rng.randi_range(20, 100)
			v = maxi(v, 0)
			num.call(v, cx + 6, y)
			#  지난 값은 그어 지웠다(맨 끝 값만 산다)
			if y + 9 < h - 8 and v > 40:
				for x in range(cx + 4, cx + 20):
					dot.call(x, y + 2)
			y += 8
	return im


# ── 문짝 — 경첩 축(왼변)에 매단다 ───────────────────────────
static func _slab(root: Node3D) -> void:
	var x0: float = float(DOOR.x0)
	var x1: float = float(DOOR.x1)
	var y0: float = float(DOOR.y0)
	var y1: float = float(DOOR.y1)
	var th: float = float(DOOR.thick)
	var fz: float = float(DOOR.face)
	var dw: float = x1 - x0
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(x0, 0.0, fz - th)
	root.add_child(hinge)
	#  세로 판자 — 판자 폭 30~40px(0.08~0.11m).
	var im := _vplank(int(dw * S), int((y1 - y0) * S), COL.door, 6021, 30, 40)
	_panel(hinge, Vector3(dw, y1 - y0, th), Vector3(dw * 0.5, (y0 + y1) * 0.5, th * 0.5),
			_lit_mat(im, null, 0.78, 2.0, COL.door), COL.door.darkened(0.3), "Slab")
	#  가로 띠장 — 판자를 묶는 앞판. 위아래 변이 램프 빛을 받는다.
	var bh: float = float(DOOR.batten_h)
	for by in DOOR.batten_y:
		var bi := _hplank(int((dw - 0.02) * S), int(bh * S), COL.door.darkened(0.12),
				6022 + int(float(by) * 100.0), int(bh * S), int(bh * S) + 1)
		_panel(hinge, Vector3(dw - 0.02, bh, 0.014), Vector3(dw * 0.5, float(by), th + 0.007),
				_lit_mat(bi, null, 0.78, 2.0, COL.door.darkened(0.12)), COL.door.darkened(0.35), "Batten")
	#  쇠 띠 — 검은 쇠 · 징 셋 · 둥근 끝
	var im_iron := Room3D._mat(COL.iron, 0.55, 0.4)
	var rv := Room3D._mat(COL.iron.lightened(0.25), 0.45, 0.6)
	var L: float = float(DOOR.strap_l)
	var shh: float = float(DOOR.strap_h)
	for sy in DOOR.strap_y:
		hinge.add_child(Room3D._box(Vector3(L, shh, 0.006),
				Vector3(L * 0.5 - 0.01, float(sy), th + 0.016), im_iron))
		var tip := Room3D._cyl(shh * 0.75, shh * 0.75, 0.006,
				Vector3(L - 0.01, float(sy), th + 0.016), im_iron, 16)
		tip.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		hinge.add_child(tip)
		for k in 3:
			var st := Room3D._cyl(0.0065, 0.0065, 0.008,
					Vector3(0.04 + float(k) * 0.10, float(sy), th + 0.02), rv, 8)
			st.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			hinge.add_child(st)
	#  손잡이 — 놋쇠 막대 · 받침 둘 · 받침판 둘
	var br := Room3D._mat(COL.brass, 0.28, 0.85)
	var hx: float = float(DOOR.hx) - x0
	var hz: float = float(DOOR.hz)
	var hy0: float = float(DOOR.hy0)
	var hy1: float = float(DOOR.hy1)
	var bar := Room3D._cyl(float(DOOR.hr), float(DOOR.hr), hy0 - hy1,
			Vector3(hx, (hy0 + hy1) * 0.5, th + hz), br, 16)
	bar.name = "Handle"
	hinge.add_child(bar)
	for yy in [hy0 - 0.015, hy1 + 0.015]:
		var po := Room3D._cyl(0.008, 0.008, hz, Vector3(hx, float(yy), th + hz * 0.5), br, 12)
		po.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		hinge.add_child(po)
		var pl := Room3D._cyl(0.022, 0.022, 0.006, Vector3(hx, float(yy), th + 0.003), br, 16)
		pl.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		hinge.add_child(pl)
	#  판 걸이 — 판 위 못 하나(판이 그 밑에 걸린다)
	var nr: float = float(DOOR.by) + 0.255
	var nail := Room3D._cyl(0.006, 0.006, 0.02, Vector3(float(DOOR.bx) - x0, nr, th + 0.01), rv, 8)
	nail.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	hinge.add_child(nail)


# ── 빛 ──────────────────────────────────────────────────────
static func _lights(root: Node3D) -> void:
	var sl := SpotLight3D.new()
	sl.name = "Lamp"
	sl.light_color = COL.lamp
	sl.light_energy = float(LOOK.lamp_e)
	sl.spot_range = 5.0
	sl.spot_attenuation = 0.6
	sl.spot_angle = float(LOOK.lamp_ang)
	sl.spot_angle_attenuation = float(LOOK.lamp_att)
	sl.shadow_enabled = true
	sl.shadow_blur = 1.5
	sl.light_size = 0.05
	sl.shadow_opacity = 0.75
	sl.light_projector = _pool_tex()
	sl.light_cull_mask = 1             # 밖의 빛은 밖만 — 안(LAYER_IN)은 안의 빛이 비춘다
	var at: Vector3 = LOOK.lamp_at
	var lt: Vector2 = LOOK.lamp_to
	sl.transform = Transform3D(Basis.looking_at(Vector3(lt.x, lt.y, float(DOOR.face)) - at,
			Vector3.UP), at)
	root.add_child(sl)
	#  간판 네온의 분홍 번짐 — 간판 판 앞 · 문틀과 문 윗몸을 물들인다
	var nl := OmniLight3D.new()
	nl.name = "Neon"
	nl.light_color = COL.neon
	nl.light_energy = float(LOOK.neon_e)
	nl.omni_range = float(LOOK.neon_r)
	nl.omni_attenuation = 1.6
	nl.light_cull_mask = 1
	nl.position = Vector3(float(DOOR.cx), (float(DOOR.sign_y0) + float(DOOR.sign_y1)) * 0.5, 0.18)
	root.add_child(nl)
	#  거리의 찬 빛 — 오른쪽 멀리서 벽돌 면을 비스듬히 쓴다(따뜻한 문과 맞선다)
	var st := OmniLight3D.new()
	st.name = "Street"
	st.light_color = COL.street
	st.light_energy = float(LOOK.street_e)
	st.omni_range = 3.4
	st.omni_attenuation = 1.2
	st.light_cull_mask = 1
	st.position = Vector3(2.0, 0.6, 0.35)
	root.add_child(st)


static func _pool_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for p in LOOK.pool:
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
