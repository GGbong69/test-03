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
	#  벽돌 — 옅은 7d5052 는 빛 밑에서 분홍 · 보라 장으로 튀어 뺐다(촬영, 2026-10-06). 넷이던 것을 여덟로
	#  (2026-10-16 — 붉은 갈색 셋 · 따뜻한 장 · 누런 장 · 탄 장 · 거뭇한 장 · 색상은 다 5~20°). 흔한 장을 둘씩.
	"brick": [Color("6b2a1c"), Color("6b2a1c"), Color("5e2416"), Color("5e2416"), Color("561916"),
			Color("4a1412"), Color("6e3420"), Color("7a3d22"), Color("3a1610"), Color("5a3028")],
	"mortar": Color("2a2628"),
	"door": Color("402e1a"),
	"case": Color("2c1508"),
	"sign": Color("140904"),
	"iron": Color("1f1719"),
	#  쇠붙이 · 놋쇠(2026-10-16) — 쇠는 반사 없는 검은 쇠(망치 자국 · 녹) · 놋쇠는 다섯 단(짙은 끝 · 그늘 ·
	#  몸 · 빛 · 흰 줄 — BRASS_SHADER)
	"iron_lit": Color("252123"),
	"rust": [Color("4a1c14"), Color("6b2a1c"), Color("5c3a1a")],
	"brass_ramp": [Color("2e1a06"), Color("5c3a12"), Color("8c6224"), Color("c0923e"), Color("f0d690")],
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
	#  네온 번짐 반지름 — 1.1 이면 벽 전체가 자홍(색상 338° · 채도 81% — 재 봄, 2026-10-16)으로 물들어 붉은
	#  벽돌이 아니었다. 분홍은 간판 둘레에만 고이고(관의 번짐이 받는다) 나머지는 붉은 갈색이다.
	"neon_e": 0.9, "neon_r": 0.7,
	"street_e": 0.55,
	#  램프 둘레로 번지는 빛(2026-10-16) — 네온 번짐을 간판 둘레로 줄이자 웅덩이 밖 벽돌이 먹으로 꺼졌다.
	#  벽돌은 이 따뜻한 빛으로 붉은 갈색이 겨우 읽힌다(웅덩이 · 네온보다 한참 약하다).
	"spill_e": 0.55, "spill_r": 3.2,
	"inside_e": 2.4,          # 안의 빛 — 문틈 · 열린 문으로 쏟아진다
	"bump": 0.9,              # 결의 높낮이 세기
	#  빛 웅덩이 [반지름 몫, 밝기] — 문 둘레는 고루, 문틀 바깥 한 뼘을 지나면 진다.
	"pool": [[0.0, 1.0], [0.40, 0.95], [0.55, 0.70], [0.68, 0.32], [0.80, 0.08], [0.90, 0.0],
			[1.0, 0.0]],
	#  나무 결 — 결 대비 몫 · 채도 몫(wall3d 의 벽 판자와 같은 처방). 처음 판은 결이 주황 줄로
	#  서서 램프 밑에서 지글거렸다 — 「긁힌 라미네이트」(다트판 벽이 먼저 겪은 그 실패다).
	"grain": 0.35, "sat": 0.55,
	"brick_sat": 0.60,        # 0.72 → 0.60(2026-10-16 — 같은 까닭)
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
	_wall_things(root)
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
#  2026-10-16 다시 굽는다 — 점검(촬영): 장 크기 하나 · 곧은 줄눈 · 모든 세로 줄눈 옆에 같은 1px 밝은 턱이
#  되풀이되어 화면 45% 가 깐 타일 벽지로 읽혔다(장마다 색 차도 작았다). 이제
#   · 장 폭 72 ± 3 · 줄 높이 23~25 · 줄눈 2~4px 를 장 · 줄마다 흔든다 · 줄마다 엇갈림도 ±4.
#   · 장 빛깔 여덟(붉은 갈색 · 탄 장 · 누런 장 · 거뭇한 장 — 색상 5~20°) · 장 안에 위가 조금 밝은 기울기 · 얼룩.
#   · 높이 — 장마다 모서리가 닳은 것 · 날 선 것 · 조금 나온 것 · 들어간 것. 줄눈도 깊이가 제각각이라 빛 받는
#     턱이 장마다 다르다.
#   · 벽의 세월(_brick_age) — 위에서 흘러내린 그을음 · 물 자국(젖어 짙은 띠 · 흘러내린 줄 · 밑의 소금꽃) ·
#     계량 상자 밑 녹물 · 깨진 장. 칠판이 걸린 자리는 옅게 둔다(칠판 글이 묻힌다).
static func _brick_imgs(wpx: int, hpx: int, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var im := Image.create(wpx, hpx, false, Image.FORMAT_RGBA8)
	var hm := Image.create(wpx, hpx, false, Image.FORMAT_RGBA8)
	im.fill(COL.mortar)
	hm.fill(Color(0.3, 0.3, 0.3))
	var pal: Array = COL.brick
	var bricks: Array = []     # [Rect2i] — 깨진 장을 고를 때 쓴다
	var row := 0
	var y := 0
	while y < hpx:
		var rh: int = rng.randi_range(23, 25)
		var my: int = rng.randi_range(2, 4)
		var off: int = (36 if row % 2 == 1 else 0) + rng.randi_range(-4, 4)
		var x: int = -off
		#  가로 줄눈 — 깊이 · 빛깔이 줄마다 조금 다르다
		var mc: Color = COL.mortar.lightened(rng.randf_range(0.0, 0.08))
		im.fill_rect(Rect2i(0, mini(y + rh - my, hpx - 1), wpx, my), mc)
		var mh: float = rng.randf_range(0.22, 0.50)
		hm.fill_rect(Rect2i(0, mini(y + rh - my, hpx - 1), wpx, my), Color(mh, mh, mh))
		while x < wpx:
			var bw: int = 72 + rng.randi_range(-3, 3)
			var mx: int = rng.randi_range(2, 4)
			var c: Color = pal[rng.randi() % pal.size()]
			c = c.lightened(rng.randf_range(0.0, 0.08)) if rng.randf() < 0.5 \
					else c.darkened(rng.randf_range(0.0, 0.16))
			var x0: int = maxi(x, 0)
			var x1: int = mini(x + bw - mx, wpx)
			var y1: int = mini(y + rh - my, hpx)
			if x1 > x0 and y1 > y:
				#  세로 줄눈 — 제 깊이
				var vh: float = rng.randf_range(0.18, 0.55)
				if x1 < wpx:
					hm.fill_rect(Rect2i(x1, y, mini(mx, wpx - x1), y1 - y), Color(vh, vh, vh))
				#  장 — 위가 조금 밝은 기울기
				for yy in range(y, y1):
					var k: float = float(yy - y) / float(maxi(y1 - y - 1, 1))
					im.fill_rect(Rect2i(x0, yy, x1 - x0, 1), c.lightened(0.05 * (1.0 - k)).darkened(0.06 * k))
				#  높이 — 몸(나옴 · 들어감) · 모서리(닳음 · 날 섬)
				var body: float = [1.0, 0.92, 0.85, 0.95][rng.randi() % 4]
				var worn: bool = rng.randf() < 0.55
				hm.fill_rect(Rect2i(x0, y, x1 - x0, y1 - y), Color(body, body, body))
				var eh: float = body * (0.55 if worn else 0.85)
				hm.fill_rect(Rect2i(x0, y, x1 - x0, 1), Color(eh, eh, eh))
				hm.fill_rect(Rect2i(x0, y1 - 1, x1 - x0, 1), Color(eh, eh, eh))
				if rng.randf() < 0.6:
					hm.fill_rect(Rect2i(x0, y, 1, y1 - y), Color(eh, eh, eh))
				if rng.randf() < 0.6:
					hm.fill_rect(Rect2i(x1 - 1, y, 1, y1 - y), Color(eh, eh, eh))
				#  얼룩 — 장 안에 옅고 짙은 점 · 가끔 2px 덩이
				for _k in int(float((x1 - x0) * (y1 - y)) / 30.0):
					var px: int = rng.randi_range(x0, x1 - 1)
					var py: int = rng.randi_range(y, y1 - 1)
					var dc: Color = c.darkened(rng.randf_range(0.10, 0.28)) if rng.randf() < 0.7 \
							else c.lightened(rng.randf_range(0.05, 0.12))
					var sz: int = 2 if rng.randf() < 0.15 else 1
					im.fill_rect(Rect2i(px, py, mini(sz, x1 - px), mini(sz, y1 - py)), dc)
					hm.fill_rect(Rect2i(px, py, mini(sz, x1 - px), mini(sz, y1 - py)),
							Color(body - 0.12, body - 0.12, body - 0.12))
				#  이 빠진 모서리 — 줄눈 색으로 한두 칸
				for _k in rng.randi_range(0, 3):
					var ex: int = rng.randi_range(x0, x1 - 1)
					var ey: int = y if rng.randf() < 0.5 else y1 - 1
					im.set_pixel(ex, ey, mc.lightened(0.05))
					hm.set_pixel(ex, ey, Color(0.3, 0.3, 0.3))
				bricks.append(Rect2i(x0, y, x1 - x0, y1 - y))
			x += bw
		y += rh
		row += 1
	_brick_age(im, hm, bricks, rng)
	return [im, hm]


#  벽의 세월 — 자리는 그림 px(벽 그림은 x −1.8 ~ 1.8 m · y 0.9 ~ −1.2 m 을 1m = S px 로 덮는다).
#  _wall 의 판(제목 화면에 드는 칸은 x 324 ~ 972 · y 112 ~ 472)에 맞춰 둔다.
static func _brick_age(im: Image, hm: Image, bricks: Array, rng: RandomNumberGenerator) -> void:
	var w: int = im.get_width()
	var h: int = im.get_height()
	var px := func(wx: float) -> int:
		return int((wx + 1.8) * S)
	var py := func(wy: float) -> int:
		return int((0.9 - wy) * S)
	#  흘러내린 띠 — 위(y0)에서 길이 len 만큼 · 폭이 흔들리고 밑으로 옅어진다. tint 쪽으로 몫 k 만큼 당긴다.
	var streak := func(cx: int, y0: int, wd: int, ln: int, tint: Color, k: float, drips: bool) -> void:
		var half: float = float(wd) * 0.5
		var wob := 0.0
		for yy in range(maxi(y0, 0), mini(y0 + ln, h)):
			var t: float = float(yy - y0) / float(ln)
			wob = clampf(wob + rng.randf_range(-0.6, 0.6), -half * 0.5, half * 0.5)
			var hw: float = half * (1.0 - 0.45 * t)
			for xx in range(int(float(cx) + wob - hw - 2.0), int(float(cx) + wob + hw + 3.0)):
				if xx < 0 or xx >= w:
					continue
				var dx: float = absf(float(xx) - float(cx) - wob) / maxf(hw, 1.0)
				var a: float = k * pow(1.0 - t, 1.3) * clampf(1.2 - dx, 0.0, 1.0)
				if a <= 0.01:
					continue
				#  가장자리는 2px 바둑으로 끊는다(도트)
				if dx > 0.85 and (xx + yy) % 2 == 0:
					continue
				im.set_pixel(xx, yy, im.get_pixel(xx, yy).lerp(tint, a))
		if drips:
			for _d in rng.randi_range(2, 4):
				var dx2: int = cx + rng.randi_range(-wd / 2, wd / 2)
				var dl: int = rng.randi_range(ln / 3, ln)
				for yy in range(maxi(y0 + ln / 4, 0), mini(y0 + dl, h)):
					if dx2 >= 0 and dx2 < w:
						im.set_pixel(dx2, yy, im.get_pixel(dx2, yy).lerp(tint, k * 0.55))
	var soot := Color("140c0c")
	var damp := Color("1e1a1c")
	#  그을음 — 왼쪽 벽 위(칠판 위로 끝난다) · 오른쪽 벽 위 · 문틀 머리 위
	streak.call(px.call(-0.66), py.call(0.95), 70, 280, soot, 0.55, false)
	streak.call(px.call(0.83), py.call(0.95), 46, 230, soot, 0.50, false)
	streak.call(px.call(0.15), py.call(0.62), 120, 40, soot, 0.45, false)
	#  물 자국 — 홈통 이음에서 샌 물(젖어 짙은 띠 · 흘러내린 줄)
	streak.call(px.call(-0.43), py.call(0.40), 34, 300, damp, 0.42, true)
	#  녹물 — 계량 상자 밑
	streak.call(px.call(0.815), py.call(-0.04), 10, 160, Color("5c2a14"), 0.40, true)
	#  소금꽃 — 젖은 띠 밑자락의 줄눈에 흰 점
	var salt := Color("c9bfae")
	for _k in 140:
		var sx: int = px.call(-0.43) + rng.randi_range(-22, 22)
		var sy: int = py.call(-0.34) + rng.randi_range(0, 30)
		if sx < 0 or sy < 0 or sx >= w or sy >= h:
			continue
		if hm.get_pixel(sx, sy).r < 0.6:      # 줄눈만
			im.set_pixel(sx, sy, im.get_pixel(sx, sy).lerp(salt, rng.randf_range(0.30, 0.60)))
	#  깨진 장 — 제목 칸 안의 장 몇의 한 모서리가 떨어져 나갔다(속이 드러난 밝은 테 1px · 파인 그늘)
	var want := [Vector2(-0.80, 0.42), Vector2(-0.52, -0.38), Vector2(0.80, 0.30), Vector2(0.86, -0.30)]
	for wv in want:
		var p := Vector2i(px.call(wv.x), py.call(wv.y))
		for b in bricks:
			var r: Rect2i = b
			if not r.has_point(p):
				continue
			var cw: int = rng.randi_range(9, 16)
			var chh: int = rng.randi_range(6, 10)
			var right: bool = rng.randf() < 0.5
			for yy in chh:
				var span: int = int(float(cw) * (1.0 - float(yy) / float(chh)))
				for i in span:
					var xx: int = (r.end.x - 1 - i) if right else (r.position.x + i)
					var y2: int = r.position.y + yy
					var edge: bool = i == span - 1
					im.set_pixel(xx, y2, Color("8a4a2e") if edge else Color("241612"))
					hm.set_pixel(xx, y2, Color(0.55, 0.55, 0.55) if edge else Color(0.2, 0.2, 0.2))
			break


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


#  벽 위 물건(2026-10-16) — 점검: 벽돌만 화면 45% 라 깐 그림으로 보였다. 술집 앞벽에 흔한 것 둘을 단다
#  (상표 · 글씨 없이). 문틀 왼쪽 벽돌 띠(칠판과 문틀 사이)에 세로 홈통 · 오른쪽 벽에 전기 계량 상자와 거기서
#  위아래로 뻗는 전선관. 둘 다 램프 빛과 그림자를 받는다(밖 층).
static func _wall_things(root: Node3D) -> void:
	var wz: float = float(DOOR.wall_z)
	#  홈통 — 검게 칠한 쇠관 · 벽에 박은 띠쇠 둘 · 이음 고리 하나
	var pipe := Room3D._mat(Color("2a2729"), 0.55)
	var px := -0.375
	var pz: float = wz + 0.028
	root.add_child(Room3D._cyl(0.02, 0.02, 2.2, Vector3(px, -0.2, pz), pipe, 16))
	var clamp_m := Room3D._mat(Color("1f1b1c"), 0.6)
	for cy in [0.46, -0.02]:
		root.add_child(Room3D._cyl(0.0235, 0.0235, 0.012, Vector3(px, cy, pz), clamp_m, 16))
		root.add_child(Room3D._box(Vector3(0.012, 0.012, 0.03), Vector3(px, cy, wz + 0.008), clamp_m))
	root.add_child(Room3D._cyl(0.0245, 0.0245, 0.03, Vector3(px, 0.24, pz), pipe, 16))
	#  계량 상자 — 칠한 쇠 상자(앞판 그림: 테 · 둥근 유리창 속 눈금판 · 바늘 · 나사 · 경첩) · 전선관
	var bx := 0.815
	var by := 0.06
	var bw := 0.10
	var bh := 0.15
	var bd := 0.055
	var paint := Color("3c4640")
	var im := Image.create(int(bw * S), int(bh * S), false, Image.FORMAT_RGBA8)
	var hm := Image.create(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8)
	var iw: int = im.get_width()
	var ih: int = im.get_height()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6101
	for y in ih:
		for x in iw:
			var c: Color = paint.lightened(rng.randf_range(0.0, 0.05)) if rng.randf() < 0.5 \
					else paint.darkened(rng.randf_range(0.0, 0.08))
			var hv := 0.8
			if x == 0 or y == 0 or x == iw - 1 or y == ih - 1:
				c = paint.darkened(0.45)
				hv = 0.45
			elif x == 2 or y == 2 or x == iw - 3 or y == ih - 3:
				c = paint.darkened(0.25)       # 문짝 금
				hv = 0.6
			#  벗겨진 칠 · 녹 — 아래쪽에 몰린다
			if rng.randf() < (0.06 if y > ih * 2 / 3 else 0.012):
				c = Color("5c2a14") if rng.randf() < 0.6 else Color("6b2a1c")
			im.set_pixel(x, y, c)
			hm.set_pixel(x, y, Color(hv, hv, hv))
	#  둥근 유리창 — 짙은 유리 · 흰 눈금판 · 바늘 · 위 왼쪽 1px 빛
	var wc := Vector2(iw * 0.5, ih * 0.38)
	var wr: float = float(iw) * 0.30
	for y in ih:
		for x in iw:
			var d: float = (Vector2(x + 0.5, y + 0.5) - wc).length()
			if d <= wr + 1.0 and d > wr:
				im.set_pixel(x, y, paint.darkened(0.55))
				hm.set_pixel(x, y, Color(0.95, 0.95, 0.95))
			elif d <= wr:
				var c := Color("1a1c20")
				if d <= wr - 2.0:
					c = Color("c9bfae") if y < int(wc.y) + 2 else Color("1a1c20")
				hm.set_pixel(x, y, Color(0.7, 0.7, 0.7))
				im.set_pixel(x, y, c)
	for i in int(wr) - 2:
		im.set_pixel(int(wc.x) - 1 + i / 2, int(wc.y) - i / 2, Color("8c2233"))
	im.set_pixel(int(wc.x - wr * 0.6), int(wc.y - wr * 0.6), Color("dde3ec"))
	for sp in [Vector2i(4, 4), Vector2i(iw - 5, 4), Vector2i(4, ih - 5), Vector2i(iw - 5, ih - 5)]:
		im.set_pixel(sp.x, sp.y, paint.lightened(0.30))
		hm.set_pixel(sp.x, sp.y, Color(1.0, 1.0, 1.0))
	_panel(root, Vector3(bw, bh, bd), Vector3(bx, by, wz + bd * 0.5), _lit_mat(im, hm, 0.6, 1.0),
			paint.darkened(0.25), "Meter")
	#  전선관 — 상자 위 · 밑으로(벽에 붙인 반달 고리 둘)
	var cond := Room3D._mat(Color("4a4a4c"), 0.5)
	var cz: float = wz + 0.012
	root.add_child(Room3D._cyl(0.008, 0.008, 0.9, Vector3(bx + 0.02, by + bh * 0.5 + 0.45, cz), cond, 8))
	root.add_child(Room3D._cyl(0.008, 0.008, 1.3, Vector3(bx - 0.02, by - bh * 0.5 - 0.65, cz), cond, 8))
	for cy in [by + bh * 0.5 + 0.20, by - bh * 0.5 - 0.22]:
		var cx: float = bx + (0.02 if cy > by else -0.02)
		root.add_child(Room3D._box(Vector3(0.026, 0.008, 0.02), Vector3(cx, cy, cz), clamp_m))


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
	#  처마 — 머리 윗변에 앞으로 한 단씩 더 나온 판 둘(2026-10-16 · 점검: 문틀이 납작한 상자 셋이라 가구
	#  상자로 읽혔다). 윗면이 램프 빛을 받아 1px 빛 · 밑면이 그늘 줄로 선다. 고리 자리(hook_y · 머리 밑변)는
	#  그대로 · 윗변은 1.2cm 만 오른다(문틀 위 벽돌 띠를 덮지 않는다).
	for st in [[0.020, 0.0, 0.012, 0.015], [0.016, 0.012, 0.024, 0.05]]:
		var ch: float = float(st[0])
		var cy0: float = hy - 0.020 + float(st[1])
		var cd: float = dep + 0.01 + float(st[2])
		var cwid: float = x1 - x0 + cw * 2.0 + float(st[3]) * 2.0
		var ci2 := _hplank(int(cwid * S), maxi(int(ch * S), 2), COL.case.lightened(0.06), 7104 + int(ch * 1000.0),
				int(ch * S), int(ch * S) + 1)
		_panel(root, Vector3(cwid, ch, cd), Vector3(mx, cy0 + ch * 0.5, wz + cd * 0.5),
				_lit_mat(ci2, null, 0.75, 3.0, COL.case.lightened(0.06)), COL.case.lightened(0.10), "Cornice")
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


# ── 안 — 술집 안 (2026-10-10 · 도트 2026-10-11) ─────────────
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
#
#  2026-10-11 「지금 시작화면에서 문 열고 들어가면 보이는 화면이 너무 도트 풍이 아니야」. 밖(한 텍셀
#  = 1px · 결 노멀 · 팔레트 색)과 달리 안은 매끈한 로우폴리 렌더로 읽혔다 — 1m 180 텍셀 그림을
#  밉맵으로 줄여 결이 뭉개졌고(안은 반 배쯤으로 보인다), 빛 웅덩이 · 빛무리가 고운 그러데이션이고,
#  술병 · 의자가 매끈한 원기둥 그늘이었다. 밖과 같은 도트로 다시 짓는다.
#   · 그림은 깊이마다 화면 배율에 맞춘다(_den — 카메라가 dz_ref 만큼 들어간 때 1 텍셀 = 논리 1px ·
#     걸어 들어가는 동안 0.9 ~ 1.2 배) · nearest 밉맵 없이. 판자 결은 밖처럼 결에서 노멀을 낸다.
#   · 빛은 단으로 끊는다(IN_SHADER light() — BAR.bands 단 · 단 사이 한 뼘만 4x4 격자 디더). 웅덩이가
#     테 진 도트 띠로 진다. 방을 고루 덮던 약한 빛은 걷고(끊으면 넓은 벽에 큰 고리로 선다) 재질마다
#     같은 몫(fill)을 깐다 — 왼쪽 위 앞에서 오는 셈으로 다섯 단이라 웅덩이 밖에서도 판자 이음 · 상자
#     윗면이 1px 모서리로 선다. 매끈한 반사는 걷고 놋쇠 · 니스 · 쇠만 끊긴 반짝 한 점(거울에도 두었더니
#     밑불마다 큰 베이지 원판이 섰다 — 거울은 짙은 바탕으로 술병을 띄운다).
#   · 원기둥 · 구는 면마다 한 색(flat) · 마디를 줄였다. 술병 · 잔은 도트 그림을 세운다(_bottle_img ·
#     _glass_img — 몸 · 그늘 · 1px 빛 · 딱지 · 거품). 빛무리는 테 진 고리 셋(_halo).
#   · 색은 도트 팔레트(dot_pal.py) 안에서 — 나무 0 ~ 4 · 금 · 초록 · 벨벳 · 강철. 화면 오른쪽 칸(안)의 색 수가
#     만 이천 남짓에서 천백 ~ 천육백으로 줄었다(t 1.00 ~ 1.30).
const LAYER_IN := 2
const BAR := {
	"floor": -1.22, "ceil": 1.30, "back": -5.2, "x0": -2.8, "x1": 3.2,
	"dz_ref": 1.5,                       # 그림 텍셀을 맞추는 카메라 자리(_den)
	"bands": 4.0,                        # 빛 단 수(IN_SHADER)
	"fill": Color(0.30, 0.19, 0.12),     # 웅덩이 밖에 고루 까는 빛(재질 몫 · 선형 배수)
	"rail_y": -0.40,                     # 허리 몰딩 — 위는 판자 벽 · 밑은 짙은 밑판
	#  바 — 카운터 앞면 z · 깊이 · 윗면 y · 오른끝 x / 뒤 선반 높이들 · 좌우 끝
	"cnt_z": -3.50, "cnt_d": 0.55, "cnt_y": -0.14, "cnt_x1": 0.62,
	"shelf_y": [-0.02, 0.32, 0.66], "shelf_x0": -2.5, "shelf_x1": 0.52,
	"stool_x": [-1.70, -0.90, -0.10], "stool_z": -3.12,
	"pend_x": [-1.60, -0.62, 0.36], "pend_z": -3.78, "pend_y": 0.64,
	#  다트 장 — 판 한가운데(뒷벽 위) · 판 반지름 · 장 반 폭
	"board": Vector2(1.58, 0.12), "board_r": 0.22, "cab": 0.34,
	"table": Vector2(0.98, -4.35),       # 술 테이블 한가운데(x · z)
	"table_h": 0.75,
	"deco": Vector2(0.77, 0.50),         # 맥주잔 네온 한가운데(뒷벽 x · y) — 액자는 그 밑                     # 테이블 높이(바닥에서 · 카운터 윗면보다 한 뼘 낮다)
	#  테이블 의자 [x · z · 보는 방향] · 문간 앞 바 의자(앞 켜 · 화면 오른 아래 가장자리)
	"chairs": [[0.74, -3.95, -0.54], [1.40, -4.42, 1.74]],
	"front_stool": [0.95, -2.25, 0.5],
	"lamp": Color("ffcf8a"),
	#  색 — 도트 팔레트
	"wall": Color("402e1a"), "wall_lo": Color("2c1508"), "trim": Color("8a5636"),
	"wood": Color("5e3317"), "wood_dk": Color("2c1508"), "oak": Color("553222"), "cnt_c": Color("6a3a1c"),
	"floor_c": Color("2c1508"), "ceil_c": Color("140904"), "mirror": Color("0d0b16"),
	"brass": Color("a8762a"), "iron": Color("1f1719"), "enamel": Color("2f6340"),
	"leather": Color("561916"), "chalk": Color("1d3326"), "chalk_ink": Color("e8dfc8"),
	"flight": Color("d45a9e"), "steel": Color("687085"),
}
#  술병 빛깔 넷씩(끝 · 그늘 · 몸 · 빛) — Room3D.BOTTLE_COLS 차례(호박 · 초록 · 맑은 · 포도주 · 위스키 · 보라).
const BOTTLE_RAMPS := [
	[Color("6b2a1c"), Color("b0512a"), Color("e8873a"), Color("f7ba70")],
	[Color("1d3326"), Color("2f6340"), Color("479a58"), Color("94d68e")],
	[Color("3a3f52"), Color("687085"), Color("a3abbb"), Color("dde3ec")],
	[Color("4a1426"), Color("8c2233"), Color("b03a32"), Color("f27d63")],
	[Color("5c3a1a"), Color("a8762a"), Color("c2a13d"), Color("f2c94c")],
	[Color("2b1d4f"), Color("523a8f"), Color("8161c9"), Color("bca1ed")],
]

#  안 재질 — 빛을 단으로 끊는다. 한 빛의 몫(N·L × 감쇠)을 bands 단으로 내리고 단 사이 seam 몫만
#  4x4 격자 디더로 섞는다(격자는 화면 px — 논리 1px). 반짝(gloss)은 켜짐 · 꺼짐 둘뿐이다.
#  bump — 그림의 밝기를 높이로 읽어 노멀을 낸다(LIT_SHADER 와 같은 셈 · 높이는 sRGB 값). flat_n — 면마다
#  한 노멀. fill — 웅덩이 밖 바탕 빛(빛 하나로 방을 덮으면 그것도 테 진 고리가 된다). 바탕 빛도 왼쪽 위
#  앞에서 오는 셈으로 다섯 단에 끊어 얹는다(FD) — 판자 이음 · 상자 윗면 · 원기둥 면이 빛 웅덩이 밖에서도
#  1px 모서리로 선다(밖의 벽돌 · 판자가 램프 빛에 서는 그 모양).
const IN_SHADER := """
shader_type spatial;
uniform sampler2D alb : source_color, filter_nearest, repeat_disable;
uniform sampler2D hgt : filter_nearest, repeat_disable;
uniform bool use_tex = false;
uniform vec3 tint : source_color = vec3(1.0);
uniform float cut = 0.0;
uniform float bump = 0.0;
uniform bool flat_n = false;
uniform float gloss = 0.0;
uniform float glow_k = 0.0;
uniform float nup = 0.0;
uniform vec3 fill = vec3(0.0);
uniform float bands = 4.0;
uniform float seam = 0.15;
const vec3 FD = vec3(-0.352, 0.553, 0.755);

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int M[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(M[x + y * 4]) + 0.5) / 16.0;
}

float steps(float v, vec2 fc) {
	float s = v * bands;
	float k = clamp((fract(s) - 0.5) / seam + 0.5, 0.0, 1.0);
	return (floor(s) + step(bayer(fc), k)) / bands;
}

void fragment() {
	vec4 c = vec4(tint, 1.0);
	vec3 fn = NORMAL;
	if (use_tex) {
		c *= texture(alb, UV);
		if (c.a < cut) {
			discard;
		}
		if (bump > 0.0) {
			vec2 ts = 1.0 / vec2(textureSize(hgt, 0));
			vec3 lw = vec3(0.2126, 0.7152, 0.0722);
			float l = dot(texture(hgt, UV - vec2(ts.x, 0.0)).rgb, lw);
			float r = dot(texture(hgt, UV + vec2(ts.x, 0.0)).rgb, lw);
			float u = dot(texture(hgt, UV - vec2(0.0, ts.y)).rgb, lw);
			float d = dot(texture(hgt, UV + vec2(0.0, ts.y)).rgb, lw);
			vec3 tn = normalize(vec3((l - r) * bump, (d - u) * bump, 1.0));
			NORMAL_MAP = tn * 0.5 + 0.5;
			fn = tn;    // 앞을 보는 판(뒷벽 · 카운터 앞판)은 접선 틀이 곧 눈 틀이다(카메라는 안 돈다)
		}
	}
	if (flat_n) {
		vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		NORMAL = dot(n, VIEW) < 0.0 ? -n : n;
		fn = NORMAL;
	}
	if (nup > 0.0) {
		NORMAL = normalize(NORMAL + vec3(0.0, nup, 0.0));    // 세운 그림 — 위에서 오는 빛도 받는다
	}
	float fk = floor(clamp(0.6 + 0.55 * dot(fn, FD), 0.3, 1.2) * 5.0 + 0.5) / 5.0;
	ALBEDO = c.rgb;
	EMISSION = c.rgb * (fill * fk + vec3(glow_k));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float v = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += steps(v, FRAGCOORD.xy) * LIGHT_COLOR / PI;
	if (gloss > 0.0) {
		vec3 h = normalize(VIEW + LIGHT);
		float sp = pow(clamp(dot(NORMAL, h), 0.0, 1.0), gloss) * ATTENUATION;
		SPECULAR_LIGHT += step(0.35, sp) * LIGHT_COLOR / PI * 0.5;
	}
}
"""
static var _in_sh: Shader = null


static func _inside(root: Node3D) -> void:
	var bar := Node3D.new()
	bar.name = "Bar"
	root.add_child(bar)
	_bar_mat = _bar_mats()
	_bar_room(bar)
	_bar_back(bar)
	_bar_counter(bar)
	_bar_darts(bar)
	_bar_lamps(bar)
	_bar_table(bar)
	_bar_deco(bar)
	#  앞 채움 빛 — 눈 뒤(문간 안쪽 벽의 등)에서 오는 옅은 빛. 웅덩이 밖 아래 반(카운터 앞판 · 의자 · 판벽)이
	#  평균 16/255 의 먹으로 꺼져 깊이가 없었다(2026-10-16 · 촬영) — 앞을 보는 면에 한 단을 얹는다.
	var fl := _in_light(OmniLight3D.new(), "Fill", BAR.lamp, 0.8) as OmniLight3D
	fl.omni_range = 5.2
	fl.omni_attenuation = 1.0
	fl.position = Vector3(0.0, 0.25, -1.5)
	bar.add_child(fl)
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


#  깊이 z 의 그림 텍셀(1m 당) — 카메라가 dz_ref 만큼 들어간 때 그 깊이에서 1 텍셀 = 논리 1px.
static func _den(z: float) -> float:
	return S * scale_at(z, float(BAR.dz_ref))


#  안 재질(IN_SHADER) — 맨 색 col 이나 그림 im(nearest · 밉맵 없이). gloss 반짝의 좁기(0 이면 없다) ·
#  bump 결 노멀 세기 · flat 면마다 한 색.
static func _px(col: Color, im: Image = null, gloss := 0.0, bump := 0.0, flat := false) -> ShaderMaterial:
	if _in_sh == null:
		_in_sh = Shader.new()
		_in_sh.code = IN_SHADER
	var m := ShaderMaterial.new()
	m.shader = _in_sh
	m.set_shader_parameter("tint", col)
	if im != null:
		var t := ImageTexture.create_from_image(im)
		m.set_shader_parameter("alb", t)
		m.set_shader_parameter("hgt", t)
		m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("gloss", gloss)
	m.set_shader_parameter("bump", bump)
	m.set_shader_parameter("flat_n", flat)
	m.set_shader_parameter("fill", BAR.fill)
	m.set_shader_parameter("bands", float(BAR.bands))
	return m


static func _in_light(l: Light3D, nm: String, col: Color, e: float) -> Light3D:
	l.name = nm
	l.light_color = col
	l.light_energy = e
	l.shadow_enabled = false
	return l


#  빛무리 — 늘 카메라를 보는 더하기 막(유리알 · 전구 둘레의 번짐). 문 장면은 글로우를 끈다
#  (밖의 빛 받은 결까지 번진다) — 번짐은 이것으로만. 고운 그러데이션 대신 테 진 고리 셋(그림 1 텍셀 =
#  그 깊이의 논리 1px). 바깥 고리를 바둑판으로 두었더니 램프 둘레가 그물 친 원판으로 읽혀 고른 짙기로.
static func _halo(at: Vector3, sz: float, col: Color, a: float) -> MeshInstance3D:
	var n: int = maxi(int(roundf(sz * _den(at.z) * 0.5)) * 2, 8)
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var r: float = (Vector2(x + 0.5, y + 0.5) - c).length() / (float(n) * 0.5)
			var k := 0.0
			if r < 0.26:
				k = 1.0
			elif r < 0.52:
				k = 0.42
			elif r < 0.80:
				k = 0.16
			im.set_pixel(x, y, Color(col, a * k))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_texture = ImageTexture.create_from_image(im)
	return _quad_mesh(Vector2(sz, sz), at, m, "Halo")


#  도트 그림 한 장을 세운다 — 밑변 가운데가 at · 문간 쪽을 본다(왼끝 술병도 열이 안 빠진다).
#  1 텍셀 = 1 / den m. 노멀을 위로 조금 든다 — 펜던트 빛이 곧게 내리꽂혀 카운터 잔이 먹으로 꺼졌다.
static func _sprite(bar: Node3D, im: Image, at: Vector3, den: float, glow := 0.0) -> MeshInstance3D:
	var sz := Vector2(im.get_width(), im.get_height()) / den
	var m := _px(Color.WHITE, im)
	m.set_shader_parameter("cut", 0.5)
	m.set_shader_parameter("glow_k", glow)
	m.set_shader_parameter("nup", 0.6)
	var q := _quad_mesh(sz, at + Vector3(0.0, sz.y * 0.5, 0.0), m, "Sprite")
	q.rotation = Vector3(0.0, atan2(float(DOOR.cx) - at.x, -at.z), 0.0)
	bar.add_child(q)
	return q


#  술병 그림 w × h — 몸 · 어깨 · 목 · 입술 · 마개. 줄마다 왼끝(그늘) · 1px 빛 · 몸 · 오른 그늘 ·
#  오른끝. 딱지는 몸 · 목 띠 · 없음. kind — 꼴(0 둥근 어깨 · 1 각진 병 · 2 낮고 넓은 병 · 3 목 긴 병 —
#  몸 높이 몫 · 목 폭 몫 · 어깨가 좁아드는 빠르기가 다르다).
static func _bottle_img(w: int, h: int, ramp: Array, rng: RandomNumberGenerator, kind := 0) -> Image:
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var nw: int = maxi(3, int(roundf(float(w) * [0.36, 0.46, 0.40, 0.30][kind])))
	if (w - nw) % 2 != 0:
		nw += 1
	var br_: Array = [[0.50, 0.64], [0.72, 0.78], [0.55, 0.62], [0.45, 0.52]][kind]
	var body: int = int(roundf(float(h) * rng.randf_range(float(br_[0]), float(br_[1]))))
	var cap_c: Color = [Color("a8762a"), Color("8c2233"), Color("1f1719"), ramp[0]][rng.randi() % 4]
	for y in h:
		var up: int = h - 1 - y
		var ww: int = w
		if up >= body:
			var k2: int = up - body + 1
			if kind == 1:
				ww = (w - 2) if k2 == 1 else nw
			elif kind == 3:
				ww = maxi(w - 2 * ((k2 + 1) / 2), nw)
			else:
				ww = maxi(w - 2 * k2, nw)
		if y == 2:
			ww = mini(nw + 2, w)
		var x0: int = (w - ww) / 2
		for i in ww:
			var col: Color = ramp[2]
			if i == 0:
				col = ramp[1]
			elif i == 1 and ww > 3:
				col = ramp[3]
			if i >= int(ceilf(float(ww) * 0.64)):
				col = ramp[1]
			if i == ww - 1 and ww > 2:
				col = ramp[0]
			if y < 2:
				col = cap_c.lightened(0.25) if i == 1 else cap_c
			im.set_pixel(x0 + i, y, col)
	#  딱지 — 몸 가운데 · 오른쪽은 그늘 · 가운데 한 줄 글씨 / 목 띠(종이 두 줄)
	var lab: float = rng.randf()
	if lab >= 0.55 and lab < 0.78 and h - body > 6:
		var paper2: Color = [Color("e8dfc8"), Color("f2c94c"), Color("8c2233")][rng.randi() % 3]
		var ny: int = h - body - 4
		for y in range(ny, ny + 2):
			for i in w:
				var c0: Color = im.get_pixel(i, y)
				if c0.a > 0.5:
					im.set_pixel(i, y, paper2 if i < w / 2 + 1 else paper2.darkened(0.30))
	if lab < 0.55 and w >= 6:
		var ly0: int = h - body + 2
		var lh: int = maxi(int(float(body) * rng.randf_range(0.30, 0.45)), 3)
		var paper: Color = [Color("e8dfc8"), Color("c9bfae"), Color("f2c94c")][rng.randi() % 3]
		for y in range(ly0, mini(ly0 + lh, h - 2)):
			for i in range(1, w - 1):
				var pc: Color = paper
				if i >= int(ceilf(float(w) * 0.64)):
					pc = paper.darkened(0.30)
				if y == ly0 + lh / 2 and i > 1 and i < w - 2:
					pc = ramp[0]
				im.set_pixel(i, y, pc)
	return im


#  잔 그림 w × h — 유리 테(왼 밝고 오른 짙다) · 바닥 두 줄. full 이면 맥주(1px 빛 · 오른 그늘) ·
#  위에 거품(울퉁불퉁한 윗줄). 아니면 밑에 남은 술 한 뼘 — 빈 테만 그렸더니 회색 상자로 읽혔다.
static func _glass_img(w: int, h: int, full: bool, seed: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var foam: int = maxi(int(float(h) * 0.20), 2)
	var top: int = 0 if full else int(float(h) * 0.62)
	var sh: int = int(ceilf(float(w) * 0.64))
	for y in h:
		for x in w:
			var col := Color(0, 0, 0, 0)
			if x == 0:
				col = Color("a3abbb")
			elif x == w - 1:
				col = Color("687085")
			elif y >= h - 2:
				col = Color("a3abbb") if x < w - 2 else Color("687085")
			elif y >= top:
				col = Color("c2a13d") if full else Color("e8873a")
				if x == 1:
					col = Color("f2c94c") if full else Color("f7ba70")
				elif x >= sh:
					col = Color("a8762a") if full else Color("b0512a")
				if full and y < foam:
					col = Color("fbf6ea") if x < sh else Color("c9bfae")
					if y == 0 and rng.randf() < 0.35:
						col = Color(0, 0, 0, 0)
			elif x == 1 and y % 3 != 2:
				col = Color("dde3ec")
			im.set_pixel(x, y, col)
	return im


#  소품 모양은 Blender 로 짓는다(2026-10-16 「블렌더 깔았으니까 활용해봐」 — scripts/tools/blender/bar_props.py →
#  BAR_GLB). 의자 · 테이블 · 펜던트 · 카운터 앞 모서리 · 탭 · 다트 장 · 문짝 · 그림등이 한 glb 에 이름으로 든다.
#  자리 · 방향은 그대로 BAR 상수가 쥐고, 재질은 Blender 재질 이름으로 안 재질(_px — 빛 단 · 디더)을 끼운다.
#  glb 가 없거나 못 읽으면(가져오기 전) 옛 코드 모양으로 짓는다. 메시는 한 번 불러 둔다.
#  술병 · 잔은 도트 그림 그대로(_bottle_img · _glass_img) — 회전체 병은 6~9px 폭에서 빛 줄 · 테 그늘이 빠져 밋밋했다.
const BAR_GLB := "res://assets/models/bar_props.glb"
static var _bar_mesh := {}          # 이름 → Mesh(처음 부를 때 채운다)
static var _bar_mat := {}           # 재질 이름 → 안 재질(_inside 가 지을 때마다 새로)


static func _bar_model(nm: String) -> MeshInstance3D:
	if _bar_mesh.is_empty():
		_bar_mesh[""] = null
		var ps: PackedScene = load(BAR_GLB) as PackedScene if ResourceLoader.exists(BAR_GLB) else null
		var sc: Node = ps.instantiate() if ps != null else null
		if sc != null:
			for c in sc.find_children("*", "MeshInstance3D", true, false):
				_bar_mesh[String(c.name)] = (c as MeshInstance3D).mesh
			sc.free()
	var me: Mesh = _bar_mesh.get(nm)
	if me == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = me
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in me.get_surface_count():
		var sm: Material = me.surface_get_material(i)
		var key: String = sm.resource_name if sm != null else ""
		if _bar_mat.has(key):
			mi.set_surface_override_material(i, _bar_mat[key])
	return mi


#  재질 이름 → 안 재질. Blender 메시는 매끈한 노멀을 그대로 쓴다(면마다 한 색이면 방석 · 갓이 동심 고리로 끊겼다 —
#  빛 단이 둥근 면을 몇 단으로 끊는다). 의자 나무는 반짝 없이(곡면에 반짝 칸이 넓게 떠 허연 판으로 읽혔다) ·
#  니스(테이블 윗판 · 카운터 코)만 반짝인다.
static func _bar_mats() -> Dictionary:
	var B: Dictionary = BAR
	return {
		"leather": _px(B.leather), "leather_dk": _px(B.leather.darkened(0.4)),
		"iron": _px(B.iron, null, 8.0), "brass": _px(B.brass, null, 10.0),
		"wood": _px(B.wood), "varnish": _px(B.wood, null, 14.0), "wood_dk": _px(B.wood_dk), "trim": _px(B.trim),
		"oak": _px(B.oak.lightened(0.10)), "enamel": _px(B.enamel, null, 14.0),
		"lamp_in": Room3D._glow(Color("fdeaa0"), 0.9), "bulb": Room3D._glow(Color("fbf6ea"), 4.0),
		"glow": Room3D._glow(B.lamp, 2.5),
		"tap0": _px(Color("1a1424")), "tap1": _px(Color("8c2233")), "tap2": _px(Color("2f6340")),
	}


#  방 — 뒷벽(판자 · 허리 몰딩 · 밑판) · 바닥 판자 · 천장 · 옆벽.
static func _bar_room(bar: Node3D) -> void:
	var B: Dictionary = BAR
	var fy: float = B.floor
	var cy: float = B.ceil
	var bz: float = B.back
	var x0: float = B.x0
	var x1: float = B.x1
	var ry: float = B.rail_y
	var pxm: float = _den(bz)
	var W: float = x1 - x0
	var mx: float = (x0 + x1) * 0.5
	var up := _vplank(int(W * pxm), int((cy - ry) * pxm), B.wall, 8101, 20, 28)
	bar.add_child(_quad_mesh(Vector2(W, cy - ry), Vector3(mx, (cy + ry) * 0.5, bz), _px(Color.WHITE, up, 0.0, 3.0),
			"BackUp"))
	#  허리 밑 — 판넬을 두른 판벽(2026-10-16 · 점검: 세로 판자 밑판이 카운터 앞판과 같은 결 · 같은 짙기라 한
	#  면으로 붙었다)
	var lo := _wainscot_img(int(W * pxm), int((ry - fy) * pxm), B.wall, B.wall_lo, int(0.52 * pxm), 8102)
	bar.add_child(_quad_mesh(Vector2(W, ry - fy), Vector3(mx, (ry + fy) * 0.5, bz), _px(Color.WHITE, lo, 0.0, 3.0),
			"BackLo"))
	#  허리 몰딩 — 윗변이 빛을 받는다
	bar.add_child(Room3D._box(Vector3(W, 0.05, 0.05), Vector3(mx, ry, bz + 0.025), _px(B.trim)))
	#  바닥 — 가로 판자(니스 · 빛 웅덩이에 반짝이 선다)
	var dz0: float = float(DOOR.wall_z) - float(DOOR.reveal)
	var D: float = dz0 - bz
	var fd: float = _den(-4.0)
	var fl := Room3D._plank(int(W * fd), int(D * fd * 0.5), B.floor_c, 8103, 14, 18, false)
	var fq := _quad_mesh(Vector2(W, D), Vector3(mx, fy, (dz0 + bz) * 0.5), _px(Color.WHITE, fl[0], 12.0), "Floor")
	fq.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	bar.add_child(fq)
	bar.add_child(Room3D._box(Vector3(W, 0.1, D), Vector3(mx, cy + 0.05, (dz0 + bz) * 0.5), _px(B.ceil_c)))
	var sm := _px(Color.WHITE, up.duplicate() as Image, 0.0, 3.0)
	for sx in [x0, x1]:
		var q := _quad_mesh(Vector2(D, cy - fy), Vector3(float(sx), (cy + fy) * 0.5, (dz0 + bz) * 0.5), sm,
				"Side")
		q.rotation_degrees = Vector3(0.0, 90.0 if float(sx) < 0.0 else -90.0, 0.0)
		bar.add_child(q)


#  판벽 그림 — 가로 띠(위 · 아래) · 세로 기둥이 판넬을 두른다. 판넬은 한 단 짙고 들어가 있다 — 빛이 왼쪽
#  위에서 오므로 둘레 비탈이 위 · 왼쪽은 그늘 1px · 아래 · 오른쪽은 빛 1px(bump 가 그 밝기로 노멀을 낸다).
#  띠 · 기둥에 가는 결.
static func _wainscot_img(wpx: int, hpx: int, frame: Color, panel: Color, pw: int, seed: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var im := Image.create(wpx, hpx, false, Image.FORMAT_RGBA8)
	im.fill(frame)
	for _k in wpx * hpx / 50:
		var gx: int = rng.randi_range(0, wpx - 1)
		var gy: int = rng.randi_range(0, hpx - 1)
		im.fill_rect(Rect2i(gx, gy, mini(rng.randi_range(6, 30), wpx - gx), 1), frame.darkened(rng.randf_range(0.06, 0.15)))
	var rail: int = maxi(hpx / 6, 4)
	var stile: int = maxi(pw / 6, 4)
	var hi: Color = frame.lightened(0.30)
	var lo: Color = panel.darkened(0.50)
	var x: int = stile
	while x + stile < wpx:
		var r := Rect2i(x, rail, mini(pw - stile, wpx - stile - x), hpx - rail * 2)
		if r.size.x > 4 and r.size.y > 4:
			im.fill_rect(r, panel)
			for _k in r.size.x * r.size.y / 40:
				var gx: int = rng.randi_range(r.position.x + 2, r.end.x - 3)
				var gy: int = rng.randi_range(r.position.y + 2, r.end.y - 3)
				var gl: int = mini(rng.randi_range(4, 16), r.end.y - 2 - gy)
				if gl > 0:
					im.fill_rect(Rect2i(gx, gy, 1, gl), panel.darkened(rng.randf_range(0.08, 0.2)))
			#  비탈 — 바깥 테(위 · 왼쪽 빛 · 아래 · 오른쪽 그늘) · 안 테 한 줄 옅게
			im.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, 1), lo)
			im.fill_rect(Rect2i(r.position.x, r.position.y, 1, r.size.y), lo)
			im.fill_rect(Rect2i(r.position.x, r.end.y - 1, r.size.x, 1), hi)
			im.fill_rect(Rect2i(r.end.x - 1, r.position.y, 1, r.size.y), hi)
			im.fill_rect(Rect2i(r.position.x + 2, r.position.y + 2, r.size.x - 4, 1), panel.lightened(0.10))
			im.fill_rect(Rect2i(r.position.x + 2, r.position.y + 2, 1, r.size.y - 4), panel.lightened(0.10))
		x += pw
	#  띠 윗변 · 밑변 이음
	im.fill_rect(Rect2i(0, 0, wpx, 1), frame.lightened(0.20))
	im.fill_rect(Rect2i(0, hpx - 1, wpx, 1), frame.darkened(0.55))
	return im


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
	var wood := _px(B.wood)
	var wood_dk := _px(B.wood_dk)
	#  거울 판 — 짙다(술병이 앞에 선다 · 반짝을 걷었다 — 밑불마다 큰 베이지 원판이 섰다)
	bar.add_child(Room3D._box(Vector3(sw, y1 - y0, 0.02), Vector3(smx, (y0 + y1) * 0.5, bz + 0.01),
			_px(B.mirror)))
	#  테 — 기둥 넷 · 머리 갓
	for k in 4:
		var px: float = sx0 + sw * float(k) / 3.0
		bar.add_child(Room3D._box(Vector3(0.06, y1 - y0 + 0.04, 0.10),
				Vector3(px, (y0 + y1) * 0.5, bz + 0.05), wood))
	bar.add_child(Room3D._box(Vector3(sw + 0.20, 0.10, 0.16), Vector3(smx, y1 + 0.05, bz + 0.08), wood))
	bar.add_child(Room3D._box(Vector3(sw + 0.24, 0.03, 0.19), Vector3(smx, y1 + 0.115, bz + 0.09), _px(B.trim)))
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
			var ol := _in_light(OmniLight3D.new(), "Shelf", B.lamp, 0.5) as OmniLight3D
			ol.omni_range = 0.85
			ol.omni_attenuation = 1.6
			ol.position = Vector3(sx0 + sw * (0.25 + 0.5 * float(h)), y + 0.14, bz + 0.34)
			bar.add_child(ol)
	#  술병 — 도트 그림(BOTTLE_RAMPS · 상점 방과 같은 빛깔 차례) · 씨 고정. 2026-10-16 점검: 한 틀에서 찍은
	#  듯 칸마다 빈틈 없이 고르게 섰다(자판기 진열) — 꼴 넷(둥근 어깨 · 각진 병 · 낮고 넓은 병 · 목 긴 병) ·
	#  딱지 셋(몸 · 목 띠 · 없음) · 가끔 빈자리. 밑에는 선반에 닿은 그늘, 뒤 거울에는 짙게 비친 뒷모습
	#  (그림 텍셀을 맞춘 눈 자리 dz_ref 에서 거울 면에 맺히는 자리 · 크기 — 병 옆으로 조금 비켜 선다).
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261010
	var eye := Vector3(float(DOOR.cx), CAM_Y, EYE - float(B.dz_ref))
	var zm: float = bz + 0.02
	var ghost := Color(0.30, 0.28, 0.36)
	for s in sy.size():
		var y: float = float(sy[s]) + 0.015
		var x: float = sx0 + 0.07
		while x < sx1 - 0.07:
			var kind: int = rng.randi() % 4
			var bh: float = rng.randf_range(0.15, 0.24) * [1.0, 0.85, 0.70, 1.15][kind]
			var br: float = rng.randf_range(0.032, 0.05) * [1.0, 1.15, 1.30, 0.80][kind]
			var ci: int = rng.randi() % BOTTLE_RAMPS.size()
			var z: float = bz + 0.10 + rng.randf_range(-0.02, 0.03)
			var d: float = _den(z)
			var im := _bottle_img(maxi(int(roundf(br * 2.0 * d)), 5), int(roundf((bh + 0.07) * d)),
					BOTTLE_RAMPS[ci], rng, kind)
			_sprite(bar, im, Vector3(x, y, z), d, 0.12)
			bar.add_child(Room3D._blob(Vector2(br * 2.6, 0.05), Vector3(x, y + 0.001, z), 0.55))
			#  거울에 비친 뒷모습 — 병 밑 가운데 점을 거울 뒤로 접어 눈과 잇는 선이 거울 면을 지나는 자리
			var pz: float = 2.0 * zm - z
			var f: float = (eye.z - zm) / (eye.z - pz)
			var mb := eye + (Vector3(x, y, pz) - eye) * f
			var gq := _sprite(bar, im, Vector3(mb.x, mb.y, zm + 0.001), d / f, 0.0)
			gq.material_override.set_shader_parameter("tint", ghost)
			gq.material_override.set_shader_parameter("nup", 0.0)
			x += br * 2.0 + rng.randf_range(0.02, 0.09)
			if rng.randf() < 0.12:
				x += rng.randf_range(0.06, 0.14)     # 빈자리 — 팔려 나간 병


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
	var pxm: float = _den(cz)
	var dk := _px(B.wood_dk)
	#  앞판 — 세로 판자 · 위아래 몰딩. 2026-10-16 한 단 밝힌다(나무 2 — 뒷벽 밑 판벽과 갈라선다).
	var fh: float = cy - 0.03 - fy
	var fr := _vplank(int(L * pxm), int(fh * pxm), B.cnt_c, 8104, 26, 34)
	bar.add_child(_quad_mesh(Vector2(L, fh), Vector3(mx, fy + fh * 0.5, cz), _px(Color.WHITE, fr, 0.0, 3.0),
			"CntFront"))
	bar.add_child(Room3D._box(Vector3(L, 0.04, cd), Vector3(mx, fy + fh * 0.5, cz - cd * 0.5), dk))
	bar.add_child(Room3D._box(Vector3(L, fh, 0.04), Vector3(mx, fy + fh * 0.5, cz - cd + 0.02), dk))
	bar.add_child(Room3D._box(Vector3(0.04, fh, cd), Vector3(x1 - 0.02, fy + fh * 0.5, cz - cd * 0.5), dk))
	bar.add_child(Room3D._box(Vector3(L, 0.10, 0.03), Vector3(mx, fy + 0.05, cz + 0.015), dk))
	#  윗판 앞 모서리 — Blender 쇠시리(BAR_GLB CntNose · 니스 둥근 코 · 밑 오목 쇠시리 · 앞판 위 구슬). 윗판 앞
	#  10cm 를 이것이 맡아 판자 윗판은 그 뒤에서 끝난다(같은 면이 겹치면 지글거린다).
	var nm := _bar_model("CntNose")
	var tf: float = 0.08 if nm == null else -0.02          # 판자 윗판 앞끝(앞판 면에서)
	#  윗판 — 니스(빛 웅덩이에 반짝이 선다) · 앞으로 조금 나온다
	var tp := Room3D._plank(int((L + 0.06) * pxm), int((cd + tf) * pxm), B.wood, 8105, 16, 22, false)
	bar.add_child(Room3D._box(Vector3(L + 0.06, 0.05, cd + tf), Vector3(mx, cy - 0.025, cz - (cd - tf) * 0.5),
			_px(Color.WHITE, tp[0], 16.0)))
	if nm != null:
		nm.position = Vector3(mx, cy, cz + 0.08)
		nm.scale = Vector3(L + 0.06, 1.0, 1.0)
		bar.add_child(nm)
	else:
		bar.add_child(Room3D._box(Vector3(L, 0.04, 0.04), Vector3(mx, cy - 0.07, cz + 0.01), _px(B.trim)))
		#  윗판 앞 모서리 — 니스 칠한 둥근 끝(면마다 한 색 · 윗면은 빛 1px · 밑면은 그늘 줄)
		var nose := Room3D._cyl(0.027, 0.027, L + 0.06, Vector3(mx, cy - 0.028, cz + 0.08), _px(B.wood, null, 16.0, 0.0, true), 8)
		nose.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		bar.add_child(nose)
	#  놋쇠 발 난간 — 앞판 밑에서 한 뼘 뜬다(받침 몇)
	var brass := _px(B.brass, null, 10.0, 0.0, true)
	var rail := Room3D._cyl(0.022, 0.022, L, Vector3(mx, fy + 0.24, cz + 0.12), brass, 6)
	rail.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	bar.add_child(rail)
	var k := x0 + 0.4
	while k < x1:
		var po := Room3D._cyl(0.012, 0.012, 0.12, Vector3(k, fy + 0.24, cz + 0.06), brass, 6)
		po.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		bar.add_child(po)
		k += 0.9
	#  탭 — 놋쇠 기둥 하나에 손잡이 셋. 2026-10-16 x −0.95 → 0.05 — 거기는 걸어 들어가는 내내 문짝 뒤라 한 번도
	#  안 보였다. 문간 너머 카운터(오른쪽 펜던트 웅덩이 · 빈 잔 왼쪽)로 옮긴다.
	var tx: float = 0.05
	var tz: float = cz - cd * 0.55
	#  Blender 탭(BAR_GLB) — 놋쇠 T 기둥 · 아래로 굽은 꼭지 셋 · 빛깔 손잡이 · 물받이
	var tap := _bar_model("Tap")
	if tap != null:
		tap.position = Vector3(tx, cy, tz)
		bar.add_child(tap)
	else:
		bar.add_child(Room3D._cyl(0.035, 0.04, 0.26, Vector3(tx, cy + 0.13, tz), brass, 8))
		for h in 3:
			var hx: float = tx - 0.09 + 0.09 * float(h)
			bar.add_child(Room3D._cyl(0.012, 0.012, 0.07, Vector3(hx, cy + 0.21, tz + 0.05), brass, 6))
			var hd := Room3D._cyl(0.016, 0.012, 0.11, Vector3(hx, cy + 0.30, tz + 0.06),
					_px([Color("1a1424"), Color("8c2233"), Color("2f6340")][h], null, 0.0, 0.0, true), 6)
			hd.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
			bar.add_child(hd)
	#  잔 — 맥주 둘 · 빈 잔 하나(도트 그림)
	for gx in [-1.95, -0.30, 0.25]:
		var gz: float = cz - 0.18
		var d: float = _den(gz)
		var im := _glass_img(maxi(int(roundf(0.07 * d)), 5), int(roundf(0.15 * d)), float(gx) < 0.0,
				8110 + int(float(gx) * 10.0))
		_sprite(bar, im, Vector3(float(gx), cy, gz), d, 0.40)
		bar.add_child(Room3D._blob(Vector2(0.11, 0.06), Vector3(float(gx), cy + 0.001, gz), 0.55))
	#  의자 — 바 의자 셋(_bar_stool) · 바닥에 진 그늘
	for sx in B.stool_x:
		_bar_stool(bar, Vector3(float(sx), fy, float(B.stool_z)), 0.76, false, 0.4 * float(sx))


#  바 의자 · 술 의자(2026-10-16 · 점검: 의자는 검붉은 원반 한 장이었다) — 가죽 방석(옆면 · 단추 테) · 쇠
#  다리 넷(벌어져 선다) · 놋쇠 발 고리 · 바닥 그늘. back 이면 등받이(기둥 둘 · 윗살 · 가운데 살). at 은 바닥 위
#  한가운데 · yaw 는 앉는 쪽이 보는 방향(라디안 — 0 이면 −z · 등받이는 +z 쪽).
static func _bar_stool(bar: Node3D, at: Vector3, seat: float, back: bool, yaw := 0.0) -> Node3D:
	var B: Dictionary = BAR
	var n := Node3D.new()
	n.position = at
	n.rotation = Vector3(0.0, yaw, 0.0)
	bar.add_child(n)
	var r: float = 0.17 if seat > 0.6 else 0.20
	#  Blender 의자(BAR_GLB) — 바 의자(벌어진 쇠 다리 · 놋쇠 발 고리 · 단추 박은 가죽 방석) · 낮은 등받이 ·
	#  술 의자(깎은 나무 다리 · 가름대 · 살 등받이)
	var mdl := _bar_model(("StoolBack" if back else "Stool") if seat > 0.6 else "Chair")
	if mdl != null:
		n.add_child(mdl)
		n.add_child(Room3D._blob(Vector2(r * 3.0, r * 3.0), Vector3(0.0, 0.002, 0.0), 0.6))
		return n
	var leather := _px(B.leather, null, 0.0, 0.0, true)
	var iron := _px(B.iron, null, 8.0, 0.0, true)
	var ring := _px(B.brass, null, 10.0, 0.0, true)
	n.add_child(Room3D._cyl(r - 0.012, r, 0.06, Vector3(0.0, seat, 0.0), leather, 12))
	n.add_child(Room3D._cyl(r - 0.004, r - 0.004, 0.014, Vector3(0.0, seat - 0.035, 0.0), _px(B.leather.darkened(0.4)), 12))
	n.add_child(Room3D._cyl(r * 0.85, r * 0.85, 0.02, Vector3(0.0, seat - 0.05, 0.0), iron, 10))
	for k in 4:
		var a: float = TAU * (0.125 + 0.25 * float(k))
		var top := Vector3(cos(a), 0.0, sin(a)) * (r * 0.62) + Vector3(0.0, seat - 0.055, 0.0)
		var bot := Vector3(cos(a), 0.0, sin(a)) * (r * 1.05)
		n.add_child(Room3D._rod(top, bot, 0.022, iron))
	if seat > 0.6:
		var tm := TorusMesh.new()
		tm.inner_radius = r * 0.80
		tm.outer_radius = r * 0.80 + 0.018
		tm.rings = 12
		tm.ring_segments = 4
		var tr := MeshInstance3D.new()
		tr.mesh = tm
		tr.material_override = ring
		tr.position = Vector3(0.0, 0.28, 0.0)
		n.add_child(tr)
	if back:
		var wood := _px(B.wood, null, 12.0, 0.0, true)
		var bz: float = r * 0.80
		for sx in [-1.0, 1.0]:
			n.add_child(Room3D._rod(Vector3(sx * r * 0.7, seat, bz), Vector3(sx * r * 0.78, seat + 0.36, bz + 0.05),
					0.026, wood))
		n.add_child(Room3D._box(Vector3(r * 1.75, 0.06, 0.03), Vector3(0.0, seat + 0.34, bz + 0.048), wood))
		n.add_child(Room3D._box(Vector3(r * 1.5, 0.03, 0.02), Vector3(0.0, seat + 0.20, bz + 0.03), wood))
	n.add_child(Room3D._blob(Vector2(r * 3.0, r * 3.0), Vector3(0.0, 0.002, 0.0), 0.6))
	return n


#  펜던트 셋 — 줄 · 녹색 법랑 갓(밑이 트였다 · 안쪽은 전구 빛) · 전구 · 밑으로 빛 · 빛무리.
static func _bar_lamps(bar: Node3D) -> void:
	var B: Dictionary = BAR
	var lamp: Color = B.lamp
	var cy: float = B.ceil
	var pz: float = B.pend_z
	var py: float = B.pend_y
	var en := _px(B.enamel, null, 14.0, 0.0, true)
	var inner := Room3D._glow(Color("fdeaa0"), 0.9)
	var cord := _px(Color("0d0b16"))
	var cap := _px(B.brass, null, 10.0, 0.0, true)
	for lx in B.pend_x:
		var x: float = float(lx)
		#  Blender 펜던트(BAR_GLB) — 법랑 갓(둥근 머리 · 가는 목 · 넓게 벌어진 치마 · 말아 접은 테) · 놋쇠 소켓 ·
		#  전구. 줄은 소켓 머리(갓 밑 테에서 0.25)부터 천장까지
		var lm := _bar_model("Lamp")
		var top: float = 0.25 if lm != null else 0.17
		bar.add_child(Room3D._cyl(0.006, 0.006, cy - py - top, Vector3(x, (cy + py + top) * 0.5, pz), cord, 4))
		if lm != null:
			lm.position = Vector3(x, py, pz)
			bar.add_child(lm)
		else:
			bar.add_child(Room3D._cyl(0.03, 0.03, 0.04, Vector3(x, py + 0.17, pz), cap, 6))
			for side in 2:
				var cm := CylinderMesh.new()
				cm.top_radius = 0.04 if side == 0 else 0.036
				cm.bottom_radius = 0.19 if side == 0 else 0.183
				cm.height = 0.15
				cm.radial_segments = 10
				cm.rings = 1
				cm.cap_bottom = false
				cm.cap_top = side == 0
				cm.flip_faces = side == 1
				var mi := MeshInstance3D.new()
				mi.mesh = cm
				mi.material_override = en if side == 0 else inner
				mi.position = Vector3(x, py + 0.075, pz)
				bar.add_child(mi)
			#  갓 밑 테 — 말아 접은 법랑 테(2026-10-16 · 갓 끝이 종이처럼 얇았다)
			var rim := TorusMesh.new()
			rim.inner_radius = 0.183
			rim.outer_radius = 0.199
			rim.rings = 12
			rim.ring_segments = 4
			var rmi := MeshInstance3D.new()
			rmi.mesh = rim
			rmi.material_override = en
			rmi.position = Vector3(x, py, pz)
			bar.add_child(rmi)
			var bulb := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.04
			sm.height = 0.08
			sm.radial_segments = 8
			sm.rings = 4
			bulb.mesh = sm
			bulb.material_override = Room3D._glow(Color("fbf6ea"), 4.0)
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
		bar.add_child(_halo(Vector3(x, py + 0.0, pz + 0.05), 0.30, lamp, 0.18))


#  둥근 술 테이블 — 바 끝과 다트 장 사이 앞(던지는 길은 비킨다). 받침 하나 · 윗판 · 맥주 둘 ·
#  붉은 유리 촛불(작은 빛 웅덩이). 문간 너머 오른쪽 아래가 빈 벽으로 꺼지던 자리를 채운다.
#  2026-10-16 점검: 윗면(1.04)이 카운터 윗면과 한 선이라 카운터에서 이어 나온 선반으로 읽혔다 — 앉는 술
#  테이블 높이(table_h)로 내리고 의자 둘을 붙인다(하나는 등을 문간 쪽으로 · 하나는 옆으로). 문간 앞쪽(오른
#  아래 가장자리)에 끌어낸 바 의자 하나 — 앞 · 중간(테이블) · 뒤(다트 장) 세 켜. 잔 · 촛불 밑에 닿은 그늘.
static func _bar_table(bar: Node3D) -> void:
	var B: Dictionary = BAR
	var fy: float = B.floor
	var tc: Vector2 = B.table
	var ty: float = fy + float(B.table_h)
	#  Blender 테이블(BAR_GLB) — 둥근 끝 · 밑 구슬 윗판 · 앞치마 고리 · 깎은 주물 기둥 · 휜 발 넷(윗면 0.75 를 table_h 로)
	var tm := _bar_model("Table")
	if tm != null:
		tm.position = Vector3(tc.x, fy, tc.y)
		tm.scale = Vector3(1.0, float(B.table_h) / 0.75, 1.0)
		bar.add_child(tm)
	else:
		var wood := _px(B.wood, null, 14.0, 0.0, true)
		var iron := _px(B.iron, null, 8.0, 0.0, true)
		bar.add_child(Room3D._cyl(0.30, 0.30, 0.04, Vector3(tc.x, ty - 0.02, tc.y), wood, 14))
		bar.add_child(Room3D._cyl(0.27, 0.27, 0.03, Vector3(tc.x, ty - 0.05, tc.y), _px(B.wood_dk, null, 0.0, 0.0, true), 14))
		bar.add_child(Room3D._cyl(0.035, 0.035, ty - fy, Vector3(tc.x, (ty + fy) * 0.5, tc.y), iron, 8))
		bar.add_child(Room3D._cyl(0.22, 0.24, 0.03, Vector3(tc.x, fy + 0.015, tc.y), iron, 10))
	bar.add_child(Room3D._blob(Vector2(0.8, 0.8), Vector3(tc.x, fy + 0.002, tc.y), 0.6))
	for cp in B.chairs:
		_bar_stool(bar, Vector3(float(cp[0]), fy, float(cp[1])), 0.46, true, float(cp[2]))
	var fg: Array = B.front_stool
	_bar_stool(bar, Vector3(float(fg[0]), fy, float(fg[1])), 0.76, true, float(fg[2]))
	for g in [Vector2(-0.14, 0.04), Vector2(0.12, -0.08)]:
		var gz: float = tc.y + g.y
		var d: float = _den(gz)
		var im := _glass_img(maxi(int(roundf(0.07 * d)), 5), int(roundf(0.16 * d)), true, 8120 + int(g.x * 100.0))
		_sprite(bar, im, Vector3(tc.x + g.x, ty, gz), d, 0.30)
		bar.add_child(Room3D._blob(Vector2(0.11, 0.06), Vector3(tc.x + g.x, ty + 0.001, gz), 0.55))
	bar.add_child(Room3D._blob(Vector2(0.10, 0.10), Vector3(tc.x + 0.02, ty + 0.001, tc.y + 0.10), 0.45))
	var cup := Room3D._glow(Color("b03a32"), 1.2)
	bar.add_child(Room3D._cyl(0.035, 0.03, 0.07, Vector3(tc.x + 0.02, ty + 0.035, tc.y + 0.10), cup, 8))
	var flame := Room3D._glow(Color("fdeaa0"), 3.0)
	bar.add_child(Room3D._cyl(0.004, 0.008, 0.025, Vector3(tc.x + 0.02, ty + 0.083, tc.y + 0.10), flame, 4))
	var cl := _in_light(OmniLight3D.new(), "Candle", Color("ff9a50"), 0.9) as OmniLight3D
	cl.omni_range = 0.9
	cl.omni_attenuation = 1.8
	cl.position = Vector3(tc.x + 0.02, ty + 0.12, tc.y + 0.10)
	bar.add_child(cl)
	bar.add_child(_halo(Vector3(tc.x + 0.02, ty + 0.06, tc.y + 0.14), 0.22, Color("ff9a50"), 0.18))


#  다트 장 — 뒷벽의 나무 장 · 판(그림) · 열어 젖힌 두 문짝(안쪽 칠판에 분필 점수) · 꽂힌 다트 셋 ·
#  위에서 판을 비추는 그림등.
static func _bar_darts(bar: Node3D) -> void:
	var B: Dictionary = BAR
	var bz: float = B.back
	var bc: Vector2 = B.board
	var R: float = B.board_r
	var hw: float = B.cab
	var oak := _px(B.oak.lightened(0.10))
	var oak_dk := _px(B.wood_dk)
	var dep := 0.11
	#  장 — Blender(BAR_GLB Cabinet · 반 폭 0.34 로 지었다) · 앞 끝 액자 쇠시리 · 처마 · 받침 · 놋쇠 경첩. 없으면
	#  뒷판 · 테 넷(앞으로 나온 상자)
	var ck: float = hw / 0.34
	var cab := _bar_model("Cabinet")
	if cab != null:
		cab.position = Vector3(bc.x, bc.y, bz)
		cab.scale = Vector3.ONE * ck
		bar.add_child(cab)
	else:
		bar.add_child(Room3D._box(Vector3(hw * 2.0, hw * 2.0, 0.03), Vector3(bc.x, bc.y, bz + 0.015), oak_dk))
		for e in [[0.0, hw - 0.02, hw * 2.0, 0.04], [0.0, -hw + 0.02, hw * 2.0, 0.04],
				[-hw + 0.02, 0.0, 0.04, hw * 2.0], [hw - 0.02, 0.0, 0.04, hw * 2.0]]:
			bar.add_child(Room3D._box(Vector3(float(e[2]), float(e[3]), dep),
					Vector3(bc.x + float(e[0]), bc.y + float(e[1]), bz + dep * 0.5), oak))
	#  판 — 검은 받침 원 · 판 그림(그 깊이의 1 텍셀 = 1px)
	var back := Room3D._cyl(R + 0.02, R + 0.02, 0.04, Vector3(bc.x, bc.y, bz + 0.05), _px(Color("140904")), 16)
	back.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	bar.add_child(back)
	var bn: int = int(roundf(R * _den(bz + 0.07))) * 2
	var bm := _px(Color.WHITE, _board_img(bn))
	bm.set_shader_parameter("cut", 0.5)
	bar.add_child(_quad_mesh(Vector2(R * 2.0, R * 2.0), Vector3(bc.x, bc.y, bz + 0.0705), bm, "Board"))
	#  꽂힌 다트 둘 — 20 위 언저리 · 판에서 비스듬히 나온다(앞에서 보면 깃 끝 십자 · 자루 한 획)
	var steel := _px(B.steel, null, 10.0, 0.0, true)
	var fl := _px(B.flight)
	fl.set_shader_parameter("glow_k", 0.3)
	var shaft := _px(Color("0d0b16"))
	for dd in [Vector2(0.010, 0.135), Vector2(-0.045, 0.040)]:
		var dart := Node3D.new()
		dart.position = Vector3(bc.x + dd.x, bc.y + dd.y, bz + 0.072)
		dart.rotation_degrees = Vector3(-14.0, dd.x * 300.0, 0.0)
		bar.add_child(dart)
		var brl := Room3D._cyl(0.005, 0.005, 0.04, Vector3(0.0, 0.0, 0.025), steel, 4)
		brl.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		dart.add_child(brl)
		var sh := Room3D._cyl(0.0025, 0.0025, 0.04, Vector3(0.0, 0.0, 0.065), shaft, 4)
		sh.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		dart.add_child(sh)
		for fr in [Vector3(0.0, 90.0, 0.0), Vector3(90.0, 0.0, 0.0)]:
			var f := _quad_mesh(Vector2(0.026, 0.03), Vector3(0.0, 0.0, 0.085), fl, "Flight")
			f.rotation_degrees = fr
			dart.add_child(f)
	#  문짝 둘 — 경첩(장 양끝)째 활짝(155°) 열려 안쪽 칠판이 앞을 본다
	var cd: float = _den(bz + dep)
	var cw: int = int(roundf((hw - 0.05) * cd))
	var chh: int = int(roundf((hw * 2.0 - 0.05) * cd))
	var cm := _px(Color.WHITE, _scoreboard_img(cw, chh, 8106))
	var cm2 := _px(Color.WHITE, _scoreboard_img(cw, chh, 8107))
	for sd in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(bc.x + sd * hw, bc.y, bz + dep)
		piv.rotation_degrees = Vector3(0.0, 155.0 * sd, 0.0)
		bar.add_child(piv)
		#  닫힌 자리에서 문짝은 경첩에서 장 한가운데 쪽(-sd)으로 뻗는다 · 안쪽(-z)이 칠판
		var lx: float = -sd * hw * 0.5
		#  문짝 — Blender(CabDoor · 바깥 솟은 판 · 안쪽 칠판 둘레 나무 테)
		var dm := _bar_model("CabDoor")
		if dm != null:
			dm.position = Vector3(lx, 0.0, 0.0)
			dm.scale = Vector3.ONE * ck
			piv.add_child(dm)
		else:
			piv.add_child(Room3D._box(Vector3(hw, hw * 2.0, 0.025), Vector3(lx, 0.0, 0.0125), oak))
		var q := _quad_mesh(Vector2(hw - 0.05, hw * 2.0 - 0.05), Vector3(lx, 0.0, -0.001),
				cm if sd < 0.0 else cm2, "Chalk")
		q.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		piv.add_child(q)
	#  그림등 — 장 위 놋쇠 갓 · 판을 비추는 빛. Blender(CabLamp · 벽 판 · 굽은 팔 · 끝 막은 반 원통 갓 · 빛 줄)
	var cl := _bar_model("CabLamp")
	if cl != null:
		cl.position = Vector3(bc.x, bc.y, bz)
		cl.scale = Vector3.ONE * ck
		bar.add_child(cl)
	else:
		var brass := _px(B.brass, null, 10.0, 0.0, true)
		var lb := Room3D._cyl(0.022, 0.022, 0.30, Vector3(bc.x, bc.y + hw + 0.10, bz + 0.20), brass, 6)
		lb.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		bar.add_child(lb)
		#  팔 — 굵기 1.5cm(2026-10-16 · 0.8cm 는 그 깊이에서 1px 밑이라 사라져 갓이 떠 있었다)
		var arm := Room3D._cyl(0.015, 0.015, 0.18, Vector3(bc.x, bc.y + hw + 0.08, bz + 0.10), brass, 6)
		arm.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		bar.add_child(arm)
		bar.add_child(Room3D._box(Vector3(0.26, 0.006, 0.01), Vector3(bc.x, bc.y + hw + 0.08, bz + 0.21),
				Room3D._glow(B.lamp, 2.5)))
	var at := Vector3(bc.x, bc.y + hw + 0.06, bz + 0.40)
	#  원뿔을 장 안으로 좁힌다 — 26° · 2m 이면 장 밑 벽에 빛 단 이음 디더가 갈색 덩어리로 졌다(2026-10-16)
	var sl := _in_light(SpotLight3D.new(), "Pict", Color("ffe2b8"), 2.6) as SpotLight3D
	sl.spot_range = 0.95
	sl.spot_angle = 22.0
	sl.spot_angle_attenuation = 1.6
	sl.transform = Transform3D(Basis.looking_at(Vector3(bc.x, bc.y - 0.05, bz) - at, Vector3.UP), at)
	bar.add_child(sl)
	bar.add_child(_halo(Vector3(bc.x, bc.y + hw + 0.08, bz + 0.24), 0.22, B.lamp, 0.16))


#  뒷벽 물건(2026-10-16 · 점검: 다트 장 옆이 빈 어둠이었다) — 선반과 다트 장 사이 벽에 액자 하나(풍경 —
#  저녁 하늘 · 산 · 물에 비친 빛)와 그 위에 맥주잔 꼴 네온(이름 · 글씨 없는 관 · 호박빛 잔 · 흰 거품 · 손잡이 ·
#  거품 방울 셋)이 벽에 호박빛을 흘린다.
static func _bar_deco(bar: Node3D) -> void:
	var B: Dictionary = BAR
	var bz: float = B.back
	var dc: Vector2 = B.deco
	var d: float = _den(bz)
	#  액자 — 나무 테(상자 넷) · 그림
	var fw := 0.22
	var fh := 0.28
	var fy: float = dc.y - 0.40
	var frame := _px(B.trim, null, 10.0, 0.0, true)
	for e in [[0.0, fh * 0.5, fw, 0.03], [0.0, -fh * 0.5, fw, 0.03], [-fw * 0.5, 0.0, 0.03, fh], [fw * 0.5, 0.0, 0.03, fh]]:
		bar.add_child(Room3D._box(Vector3(float(e[2]), float(e[3]), 0.025),
				Vector3(dc.x + float(e[0]), fy + float(e[1]), bz + 0.0125), frame))
	var pw: int = int((fw - 0.03) * d)
	var ph: int = int((fh - 0.03) * d)
	var pim := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	for y in ph:
		var k: float = float(y) / float(ph)
		var c: Color = Color("2b2042").lerp(Color("b0512a"), clampf(k * 1.7, 0.0, 1.0))
		pim.fill_rect(Rect2i(0, y, pw, 1), c)
	var hz: int = int(float(ph) * 0.58)
	for x in pw:
		var hy: int = hz - int(4.0 + 3.0 * sin(float(x) * 0.45) + 2.0 * sin(float(x) * 1.3))
		pim.fill_rect(Rect2i(x, hy, 1, hz - hy), Color("1d3326"))
		pim.fill_rect(Rect2i(x, hz, 1, ph - hz), Color("1f1719") if (x + int(hz)) % 5 != 0 else Color("2b2438"))
	pim.fill_rect(Rect2i(pw / 2 - 1, hz + 2, 3, 1), Color("f2c94c"))
	pim.fill_rect(Rect2i(pw / 2, hz + 4, 2, 1), Color("b0512a"))
	bar.add_child(_quad_mesh(Vector2(fw - 0.03, fh - 0.03), Vector3(dc.x, fy, bz + 0.004), _px(Color.WHITE, pim),
			"Picture"))
	#  맥주잔 네온 — 관(가는 상자)을 이어 잔 테 · 손잡이 · 거품 물결 · 방울
	var amber := Room3D._glow(Color("f2b134"), 2.2)
	var foam := Room3D._glow(Color("fbf6ea"), 2.0)
	var t := 0.010
	var zc: float = bz + 0.04
	var tube := func(a: Vector2, b: Vector2, m: Material) -> void:
		var v: Vector2 = b - a
		var mi := Room3D._box(Vector3(v.length() + t, t, t), Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, zc), m)
		mi.rotation = Vector3(0.0, 0.0, v.angle())
		bar.add_child(mi)
	var o := dc
	var mw := 0.15
	var mh := 0.19
	tube.call(o + Vector2(-mw * 0.5, mh * 0.5), o + Vector2(-mw * 0.45, -mh * 0.5), amber)
	tube.call(o + Vector2(-mw * 0.45, -mh * 0.5), o + Vector2(mw * 0.45, -mh * 0.5), amber)
	tube.call(o + Vector2(mw * 0.45, -mh * 0.5), o + Vector2(mw * 0.5, mh * 0.5), amber)
	tube.call(o + Vector2(mw * 0.5, mh * 0.30), o + Vector2(mw * 0.78, mh * 0.24), amber)
	tube.call(o + Vector2(mw * 0.78, mh * 0.24), o + Vector2(mw * 0.78, -mh * 0.22), amber)
	tube.call(o + Vector2(mw * 0.78, -mh * 0.22), o + Vector2(mw * 0.48, -mh * 0.28), amber)
	var fp: Array = []
	for i in 7:
		var u: float = float(i) / 6.0
		fp.append(o + Vector2(lerpf(-mw * 0.58, mw * 0.58, u), mh * 0.5 + 0.02 + (0.022 if i % 2 == 1 else 0.0)))
	for i in fp.size() - 1:
		tube.call(fp[i], fp[i + 1], foam)
	for bp in [Vector2(-0.03, -0.04), Vector2(0.02, 0.02), Vector2(-0.01, 0.06)]:
		bar.add_child(Room3D._box(Vector3(t * 1.4, t * 1.4, t), Vector3(o.x + bp.x, o.y + bp.y, zc), foam))
	var nl := _in_light(OmniLight3D.new(), "BeerNeon", Color("f2a13a"), 0.7) as OmniLight3D
	nl.omni_range = 0.9
	nl.omni_attenuation = 1.4
	nl.position = Vector3(o.x, o.y, bz + 0.22)
	bar.add_child(nl)
	bar.add_child(_halo(Vector3(o.x + 0.01, o.y + 0.01, bz + 0.06), 0.36, Color("f2a13a"), 0.10))


#  판 그림 — 게임 판과 같은 빛깔(game.gd C_LIGHT · C_DARK 칸 · C_RED · C_GREEN 띠 · 숫자 고리 검정).
#  숫자 고리에 점을 찍었더니 멀리서 시계로 읽혀 맨 고리로 둔다. 텍셀은 판이 서는 깊이의 1px 이다.
#  픽셀 셰이더(_px)가 Image 를 받아서 Room3D.board_img(ImageTexture) 와 따로 둔다 — 배색은 같다.
static func _board_img(n: int) -> Image:
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
				col = Color("211d2b")
			if r <= 0.80:
				#  실물 배색 — 20(sec 0)부터 한 칸 걸러 흑색 · 그 띠는 빨강(2026-10-16 · Room3D.board_img 와 같다)
				col = Color("2b2438") if sec % 2 == 0 else Color("e8dfc8")
				if (r > 0.72 and r <= 0.80) or (r > 0.44 and r <= 0.50):
					col = Color("d8483d") if sec % 2 == 0 else Color("479a58")
			if r <= 0.10:
				col = Color("479a58")
			if r <= 0.05:
				col = Color("d8483d")
			im.set_pixel(x, y, col)
	return im


#  3 × 5 숫자(분필 점수판)
const DIG := ["111101101101111", "010110010010111", "111001111100111", "111001111001111",
		"101101111001001", "111100111001111", "111100111101111", "111001010010010",
		"111101111101111", "111101111001111"]


#  문짝 안쪽 칠판 — 두 칸(둘이 겨룬다)에 501 부터 깎아 내린 점수. 지난 값은 그어 지웠다.
#  분필은 다 안 묻는다(점이 빠진다) · 옛 글을 문질러 지운 얼룩이 옅게 남았다. 칸마다 가운데에
#  세 자리(11px)를 앉힌다 — 텍셀이 그 깊이의 1px 이라 칸 폭이 스무 남짓이다.
static func _scoreboard_img(w: int, h: int, seed: int) -> Image:
	var B: Dictionary = BAR
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(B.chalk)
	var ink: Color = B.chalk_ink
	var smear: Color = Color("2f6340")
	for _k in 24:
		im.fill_rect(Rect2i(rng.randi_range(0, w - 6), rng.randi_range(0, h - 2), rng.randi_range(3, 7), 1), smear)
	var dot := func(x: int, y: int) -> void:
		if x >= 0 and y >= 0 and x < w and y < h and rng.randf() > 0.12:
			im.set_pixel(x, y, ink if rng.randf() < 0.7 else Color("c9bfae"))
	var num := func(v: int, x: int, y: int) -> void:
		var t := str(v)
		for i in t.length():
			var g: String = DIG[int(t[i])]
			for gy in 5:
				for gx in 3:
					if g[gy * 3 + gx] == "1":
						dot.call(x + i * 4 + gx, y + gy)
	#  가운데 세로줄 · 머리 밑 가로줄
	for y in range(2, h - 2):
		dot.call(w / 2, y)
	for x in range(2, w - 2):
		dot.call(x, 8)
	for col in 2:
		var cx: int = col * (w / 2) + maxi((w / 2 - 11) / 2, 1)
		num.call(501, cx, 2)
		var v := 501
		var y := 11
		while y < h - 7 and v > 40:
			v -= rng.randi_range(20, 100)
			v = maxi(v, 0)
			num.call(v, cx + 4 * (3 - str(v).length()), y)
			#  지난 값은 그어 지웠다(맨 끝 값만 산다)
			if y + 8 < h - 7 and v > 40:
				for x in range(cx - 1, cx + 12):
					dot.call(x, y + 2)
			y += 7
	return im


#  문 쇠붙이 glb(2026-10-16) — 조각 셋(Pull · Strap · Pintle)을 이름으로 꺼낸다. 한 번 불러 둔다.
const DOOR_IRON := "res://assets/models/door_iron.glb"
#  쇠 UV 상자(m · 조각 안 x · y) — door_iron.py IRON_BOX 와 같다. 이 상자에 1 텍셀 = 논리 1px 로 쇠 그림을 굽는다.
const IRON_BOX := Rect2(-0.08, -1.0 / 24.0, 0.40, 1.0 / 12.0)
static var _door_iron: PackedScene = null


#  조각 하나 — 메시 겉마다 재질 이름(Blender 재질 이름)으로 mats 의 재질을 끼운다. 없거나 못 읽으면 null.
static func _door_piece(nm: String, mats: Dictionary) -> MeshInstance3D:
	if _door_iron == null:
		if not ResourceLoader.exists(DOOR_IRON):
			return null
		_door_iron = load(DOOR_IRON) as PackedScene
		if _door_iron == null:
			return null
	var sc := _door_iron.instantiate()
	var mi := sc.find_child(nm, true, false) as MeshInstance3D
	if mi == null or mi.mesh == null:
		sc.free()
		return null
	mi.get_parent().remove_child(mi)
	mi.owner = null
	sc.free()
	for i in mi.mesh.get_surface_count():
		var sm: Material = mi.mesh.surface_get_material(i)
		var key: String = sm.resource_name if sm != null else ""
		if mats.has(key):
			mi.set_surface_override_material(i, mats[key])
	return mi


#  glb 쇠의 재질 — IRON_BOX 를 통째로 채운 망치 자국 · 녹 그림(_iron_img). 테는 상자 끝이라 쇠 밖이고, 쇠의
#  둥근 테 · 그늘은 모양(Blender 의 둥글린 모서리)이 낸다.
static func _door_iron_mat(seed: int) -> ShaderMaterial:
	var b := IRON_BOX
	var poly := PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), b.end,
			Vector2(b.position.x, b.end.y)])
	var ip := _iron_img(poly, b, seed)
	return _lit_mat(ip[0], ip[1], 0.7, 1.0)


# ── 문짝 — 경첩 축(왼변)에 매단다 ───────────────────────────
#  2026-10-16 「게임의 전체적인 모델링을 다 퀄리티 업 · 진짜 있어보이는 모델링」 — 쇠붙이를 한 벌로 다시
#  짓는다. 점검(촬영): 손잡이가 주황 플라스틱 관 · 쇠 띠가 경첩 없이 붙은 판 · 같은 쇠가 닫힌 문에서
#  연보라 판 · 열린 문에서 크림색 판(금속 반사가 안의 빛을 받아 하얗게 떴다) · 판자 결이 1px 실선.
#   · 판자 — 폭 26~44px 를 섞고 결은 굵기 다른 띠 · 옹이 몇(_door_plank) · 손잡이 둘레 손때 · 띠장 못 머리.
#   · 쇠 띠 — 끝이 창끝으로 벌어지는 밀어낸 판(_extrude) · 검은 쇠에 망치 자국 · 녹(_iron_img) · 금속
#     반사 없이 램프 빛만 받는다(닫힌 문 · 열린 문에서 같은 검은 쇠). 징은 둥근 머리. 경첩 쪽 끝에 통
#     셋(가운데는 문짝 · 위아래는 문틀에 박은 핀 판) — 문틀에 매달린 문이 된다.
#   · 손잡이 — 놋쇠를 다섯 단으로 끊는다(BRASS_SHADER). 받침판 둘 대신 세로로 긴 뒤판 하나(모서리 깎음 ·
#     나사 둘) · 위에 열쇠 구멍 장식판. 막대 치수 · 누름 칸(handle_rect)은 그대로다.
#   · 2026-10-16 「블렌더 깔았으니까 활용해봐」 — 쇠붙이 모양은 Blender 로 짓는다(DOOR_IRON). 활 손잡이 · 잎 끝 뒤판 ·
#     물방울 열쇠 구멍판 · 둥글린 망치 쇠 띠(문 앞면에 눕는다 · 경첩 쪽은 통 높이로 좁아져 말아 감은 눈) · 창 날 등 ·
#     둥근 못 머리 · 문틀 모서리를 감아 든 핀 판. 위 셋은 glb 가 없을 때의 옛 모양이다.
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
	var hx: float = float(DOOR.hx) - x0
	var hz: float = float(DOOR.hz)
	var hy0: float = float(DOOR.hy0)
	var hy1: float = float(DOOR.hy1)
	#  세로 판자 — 손때는 손잡이 왼쪽(손등이 스치는 자리)에 세로로 긴 타원
	var gc := Vector2((hx - 0.035) * S, (y1 - (hy0 + hy1) * 0.5) * S)
	var gs := Vector2(0.09 * S, (hy0 - hy1 + 0.10) * S)
	var dp := _door_plank(int(dw * S), int((y1 - y0) * S), COL.door, 6021, 26, 44, Rect2(gc - gs * 0.5, gs))
	_panel(hinge, Vector3(dw, y1 - y0, th), Vector3(dw * 0.5, (y0 + y1) * 0.5, th * 0.5),
			_lit_mat(dp[0], null, 0.78, 2.0, COL.door), COL.door.darkened(0.3), "Slab")
	var seams: Array = dp[1]
	#  가로 띠장 — 판자를 묶는 앞판. 위아래 변이 램프 빛을 받는다. 판자마다 못 머리 둘(판자 가운데).
	var bh: float = float(DOOR.batten_h)
	for by in DOOR.batten_y:
		var bi := _hplank(int((dw - 0.02) * S), int(bh * S), COL.door.darkened(0.12),
				6022 + int(float(by) * 100.0), int(bh * S), int(bh * S) + 1)
		var bc: Color = COL.door.darkened(0.12)
		for k in seams.size():
			var e0: int = int(seams[k])
			var e1: int = int(seams[k + 1]) if k + 1 < seams.size() else int(dw * S)
			var nx: int = (e0 + e1) / 2 - int(0.01 * S)
			for ny in [3, bi.get_height() - 5]:
				if nx >= 1 and nx + 2 < bi.get_width():
					bi.fill_rect(Rect2i(nx, ny, 2, 2), bc.darkened(0.60))
					bi.set_pixel(nx, ny, bc.lightened(0.25))
		_panel(hinge, Vector3(dw - 0.02, bh, 0.014), Vector3(dw * 0.5, float(by), th + 0.007),
				_lit_mat(bi, null, 0.78, 2.0, bc), COL.door.darkened(0.35), "Batten")
	#  쇠붙이 — glb 조각(_door_piece · scripts/tools/blender/door_iron.py)이면 모양만 그것이고 자리 · 축은 여기 상수,
	#  재질은 이름으로 여기 것(놋쇠 BRASS_SHADER · 쇠 _door_iron_mat)을 끼운다. 없으면 옛 코드 모양.
	var stud := Room3D._mat(COL.iron_lit.lightened(0.12), 0.40)
	var knuck := Room3D._mat(COL.iron_lit, 0.55)
	var rp: Array = COL.brass_ramp
	#  놋쇠 셋 — 손이 닳린 막대 가운데(br · 흰 반짝 줄까지) · 손이 덜 닿는 끝 · 받침 · 판(bt · 흰 줄 없이 —
	#  놋쇠 손때) · 뒤판(pm · 한 단 어둡게 — 막대가 판 위로 떠 보인다)
	var br := _brass_mat()
	var bt := _brass_mat()
	bt.set_shader_parameter("c4", rp[3])
	var pm := _brass_mat()
	for i in 3:
		pm.set_shader_parameter("c%d" % (i + 1), rp[i])
	var hole := Room3D._glow(Color("0d0b10"), 0.0)
	var pull := _door_piece("Pull", {"brass_hi": br, "brass": bt, "brass_dk": pm, "hole": hole})
	#  쇠 띠 — 창끝 판 · 둥근 머리 징 셋 · 경첩 통(문짝 쪽 가운데 하나)
	var L: float = float(DOOR.strap_l)
	var shh: float = float(DOOR.strap_h)
	var xb: float = L - 0.055
	var spear := PackedVector2Array([Vector2(0.0, -shh * 0.5), Vector2(xb, -shh * 0.5),
			Vector2(xb + 0.014, -shh * 0.82), Vector2(L + 0.012, 0.0), Vector2(xb + 0.014, shh * 0.82),
			Vector2(xb, shh * 0.5), Vector2(0.0, shh * 0.5)])
	var kh: float = (shh + 0.016 - 0.006) / 3.0
	for i in DOOR.strap_y.size():
		var sy: float = float(DOOR.strap_y[i])
		var sp := _door_piece("Strap", {"iron": _door_iron_mat(6030 + i), "knuck": knuck, "stud": stud})
		var pn := _door_piece("Pintle", {"iron": _door_iron_mat(6040 + i), "knuck": knuck, "stud": stud})
		if sp != null and pn != null:
			sp.position = Vector3(0.0, sy, th)
			hinge.add_child(sp)
			pn.position = Vector3(x0, sy, 0.0)
			root.add_child(pn)
			continue
		_iron_plate(hinge, spear, 0.006, Vector3(0.0, sy, th + 0.016), 6030 + i, "Strap")
		for k in 3:
			var sd := Room3D._ball(0.0065, Vector3(0.04 + float(k) * 0.10, sy, th + 0.019), stud, true)
			sd.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			hinge.add_child(sd)
		#  경첩 통 — 가운데(문짝 쪽)는 문짝과 같이 돈다 · 위아래(문틀 쪽)는 제자리 · 마디 사이 1px 틈
		hinge.add_child(Room3D._cyl(0.011, 0.011, kh, Vector3(0.002, sy, th + 0.010), knuck, 12))
		for s in [-1.0, 1.0]:
			root.add_child(Room3D._cyl(0.011, 0.011, kh,
					Vector3(x0 + 0.002, sy + s * (kh + 0.003), fz + 0.010), knuck, 12))
		root.add_child(Room3D._ball(0.006, Vector3(x0 + 0.002, sy + kh * 1.5 + 0.003, fz + 0.010), stud, true))
		#  핀 판 — 문틀 앞면에 박은 짧은 쇠 판(징 둘)
		var cw: float = float(DOOR.case_w)
		var pin := PackedVector2Array([Vector2(-cw + 0.012, -shh * 0.42), Vector2(0.0, -shh * 0.42),
				Vector2(0.0, shh * 0.42), Vector2(-cw + 0.012, shh * 0.42)])
		_iron_plate(root, pin, 0.005, Vector3(x0, sy, float(DOOR.case_z) + 0.0025), 6040 + i, "Pin")
		for px in [-cw + 0.024, -0.016]:
			var pd := Room3D._ball(0.0055, Vector3(x0 + float(px), sy, float(DOOR.case_z) + 0.005), stud, true)
			pd.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			root.add_child(pd)
	#  손잡이 — 원점이 문 앞면의 손잡이 한가운데다(곧은 몸이 hy0..hy1 · handle_rect 그대로). 놋쇠 재질은 램프가
	#  떨면 같이 어둡다(door_lights — Hinge 의 meta "brass").
	if pull != null:
		pull.name = "Handle"
		pull.position = Vector3(hx, (hy0 + hy1) * 0.5, th)
		hinge.add_child(pull)
	else:
		#  (옛 코드 모양) 손잡이 — 놋쇠 막대 · 받침 둘 · 세로 뒤판 · 위에 열쇠 구멍 장식판
		var bar := Room3D._cyl(float(DOOR.hr), float(DOOR.hr), hy0 - hy1,
				Vector3(hx, (hy0 + hy1) * 0.5, th + hz), br, 16)
		bar.name = "Handle"
		hinge.add_child(bar)
		for yy in [hy0 - 0.015, hy1 + 0.015]:
			var po := Room3D._cyl(0.008, 0.008, hz, Vector3(hx, float(yy), th + hz * 0.5), br, 12)
			po.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			hinge.add_child(po)
		#  뒤판은 막대보다 한 단 어둡게(손이 닿는 막대가 판 위로 떠 보인다)
		var pl_h: float = hy0 - hy1 + 0.05
		hinge.add_child(_bevel_plate(0.036, pl_h, 0.004, 0.003, pm, Vector3(hx, (hy0 + hy1) * 0.5, th)))
	#  막대가 뒤판에 드리운 그늘 — 빛이 왼쪽 위 앞에서 오므로 오른쪽 아래로 비켜 진다(놋쇠는 그늘을 안 받는
	#  재질이라 판 위에 짙은 끝 색 띠로 얹는다)
	var shd := _brass_mat()
	for i in 4:
		shd.set_shader_parameter("c%d" % (i + 1), rp[0])
	hinge.add_child(Room3D._box(Vector3(0.0055, hy0 - hy1 - 0.02, 0.0004),
			Vector3(hx + 0.0125, (hy0 + hy1) * 0.5 - 0.03, th + 0.0042), shd))
	if pull == null:
		for yy in [hy0 + 0.014, hy1 - 0.014]:
			var sc := Room3D._ball(0.0042, Vector3(hx, float(yy), th + 0.004), br, true)
			sc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			hinge.add_child(sc)
		#  열쇠 구멍 장식판 — 둥근 놋쇠 받침(비탈 테) · 짙은 열쇠 구멍(둥근 머리 · 밑으로 좁은 홈)
		var ky: float = hy0 + 0.065
		var ro := Room3D._cyl(0.012, 0.017, 0.005, Vector3(hx, ky, th + 0.0025), br, 16)
		ro.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		hinge.add_child(ro)
		var kc := Room3D._cyl(0.0034, 0.0034, 0.001, Vector3(hx, ky + 0.002, th + 0.0055), hole, 10)
		kc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		hinge.add_child(kc)
		hinge.add_child(Room3D._box(Vector3(0.0028, 0.008, 0.001), Vector3(hx, ky - 0.003, th + 0.0055), hole))
	hinge.set_meta("brass", [br, bt, pm, shd])
	#  판 걸이 — 판 위 못 하나(판이 그 밑에 걸린다)
	var nr: float = float(DOOR.by) + 0.255
	var nail := Room3D._cyl(0.006, 0.006, 0.02, Vector3(float(DOOR.bx) - x0, nr, th + 0.01), stud, 8)
	nail.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	hinge.add_child(nail)


#  문 판자 그림(세로) — 폭 lo~hi px 를 섞어 세운 판자. 결은 굵기 다른 띠(1~3px)가 판자 길이로 흐르며 조금씩
#  비뚤어진다 · 판자 몇에 옹이 · 이음은 짙은 1px + 빛 받은 1px(램프가 왼쪽 위다). grime 안은 손때 — 한 단
#  밝고 결이 옅다(손이 닿아 닳은 자리). 판자 이음 x 들을 같이 낸다(띠장 못 자리).
static func _door_plank(wpx: int, hpx: int, base: Color, seed: int, lo: int, hi: int,
		grime: Rect2) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var im := Image.create(wpx, hpx, false, Image.FORMAT_RGBA8)
	var seam: Color = base.darkened(0.66)
	var seams: Array = []
	var x := 0
	while x < wpx:
		var pw: int = mini(rng.randi_range(lo, hi), wpx - x)
		var tone: float = rng.randf_range(-0.12, 0.10)
		var pc: Color = base.lightened(tone) if tone > 0.0 else base.darkened(-tone)
		im.fill_rect(Rect2i(x, 0, pw, hpx), pc)
		#  결 — 판자 길이로 흐르는 띠. 대개 짙고 가끔 밝다 · 40px 남짓마다 1px 비뚤어진다.
		for _k in int(float(pw * hpx) / 90.0):
			var gw: int = [1, 1, 1, 2, 2, 3][rng.randi() % 6]
			var gx: int = x + rng.randi_range(2, maxi(pw - gw - 1, 2))
			var gy: int = rng.randi_range(-60, hpx - 1)
			var gl: int = rng.randi_range(30, 220)
			var gc: Color = pc.darkened(rng.randf_range(0.06, 0.16)) if rng.randf() < 0.75 \
					else pc.lightened(rng.randf_range(0.04, 0.08))
			var yy: int = gy
			while yy < gy + gl:
				var sl: int = rng.randi_range(24, 56)
				var a0: int = maxi(yy, 0)
				var a1: int = mini(mini(yy + sl, gy + gl), hpx)
				if a1 > a0 and gx >= x + 1 and gx + gw < x + pw:
					im.fill_rect(Rect2i(gx, a0, gw, a1 - a0), gc)
				yy += sl
				gx += [-1, 0, 0, 1][rng.randi() % 4]
		#  옹이 — 판자 셋에 하나 남짓 · 짙은 속 · 둘레 테
		if rng.randf() < 0.35 and pw > 12:
			var kc := Vector2i(x + rng.randi_range(5, pw - 6), rng.randi_range(20, hpx - 20))
			var rx: int = rng.randi_range(2, 3)
			var ry: int = rng.randi_range(4, 6)
			for ky in range(-ry - 2, ry + 3):
				for kx in range(-rx - 2, rx + 3):
					var q: float = sqrt(pow(float(kx) / float(rx), 2.0) + pow(float(ky) / float(ry), 2.0))
					var px: int = kc.x + kx
					var py: int = kc.y + ky
					if px <= x or px >= x + pw - 1 or py < 0 or py >= hpx:
						continue
					if q <= 0.55:
						im.set_pixel(px, py, pc.darkened(0.55))
					elif q <= 1.0:
						im.set_pixel(px, py, pc.darkened(0.30))
					elif q <= 1.45 and (kx + ky) % 2 == 0:
						im.set_pixel(px, py, pc.darkened(0.14))
		#  이음 — 짙은 1px · 오른쪽에 빛 받은 1px
		im.fill_rect(Rect2i(x, 0, 1, hpx), seam)
		if x + 1 < wpx:
			im.fill_rect(Rect2i(x + 1, 0, 1, hpx), pc.lightened(0.07))
		seams.append(x)
		x += pw
	#  손때 — 타원 안을 밝은 바탕 쪽으로 당긴다(결이 옅어진다)
	if grime.size.x > 0.0:
		var hc: Color = base.lightened(0.10)
		var gc := grime.get_center()
		for y in range(int(grime.position.y), int(grime.end.y)):
			for xx in range(int(grime.position.x), int(grime.end.x)):
				if xx < 0 or y < 0 or xx >= wpx or y >= hpx:
					continue
				var d: float = Vector2((xx - gc.x) / (grime.size.x * 0.5), (y - gc.y) / (grime.size.y * 0.5)).length()
				if d >= 1.0:
					continue
				var c: Color = im.get_pixel(xx, y)
				if c.get_luminance() < seam.lightened(0.05).get_luminance():
					continue          # 이음은 그대로
				im.set_pixel(xx, y, c.lerp(hc, 0.55 * (1.0 - d * d)))
	return [im, seams]


#  밀어낸 다각형(xy · m) — 앞면(z +d/2 · 그림 UV 는 r 안의 자리) + 옆 띠. 뒷면은 안 짓는다(문 · 벽에 붙는다).
#  Godot 은 보는 쪽에서 시계 방향이 앞면이다 — 세 점의 차례를 바라는 법선에 맞춰 고른다.
static func _extrude(poly: PackedVector2Array, d: float, r: Rect2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uv := func(p: Vector2) -> Vector2:
		return Vector2((p.x - r.position.x) / r.size.x, (r.end.y - p.y) / r.size.y)
	var put := func(a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2,
			uc: Vector2) -> void:
		var vs: Array = [[a, ua], [b, ub], [c, uc]]
		if (c - a).cross(b - a).dot(n) < 0.0:
			vs = [[a, ua], [c, uc], [b, ub]]
		for v in vs:
			st.set_normal(n)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var zf: float = d * 0.5
	var tri := Geometry2D.triangulate_polygon(poly)
	for i in range(0, tri.size(), 3):
		var p0: Vector2 = poly[tri[i]]
		var p1: Vector2 = poly[tri[i + 1]]
		var p2: Vector2 = poly[tri[i + 2]]
		put.call(Vector3(p0.x, p0.y, zf), Vector3(p1.x, p1.y, zf), Vector3(p2.x, p2.y, zf), Vector3.BACK,
				uv.call(p0), uv.call(p1), uv.call(p2))
	var area := 0.0
	var n: int = poly.size()
	for i in n:
		area += poly[i].cross(poly[(i + 1) % n])
	for i in n:
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % n]
		var e: Vector2 = (q - p).normalized()
		var o: Vector2 = Vector2(e.y, -e.x) if area > 0.0 else Vector2(-e.y, e.x)
		var nn := Vector3(o.x, o.y, 0.0)
		var a := Vector3(p.x, p.y, zf)
		var b := Vector3(q.x, q.y, zf)
		put.call(a, b, Vector3(q.x, q.y, -zf), nn, uv.call(p), uv.call(q), uv.call(q))
		put.call(a, Vector3(q.x, q.y, -zf), Vector3(p.x, p.y, -zf), nn, uv.call(p), uv.call(q), uv.call(p))
	st.generate_tangents()
	return st.commit()


static func _poly_rect(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


#  검은 쇠 그림 — 다각형 안을 망치 자국(1px 밝고 짙은 얼룩 · 높이도 같이 흔든다) · 녹(아래 변에 몰린다) ·
#  테 1px 은 낮고 짙다(빛 받은 윗변 · 그늘진 밑변이 선다). 1 텍셀 = 판 평면의 논리 1px.
static func _iron_img(poly: PackedVector2Array, r: Rect2, seed: int) -> Array:
	var w: int = maxi(int(ceilf(r.size.x * S)), 2)
	var h: int = maxi(int(ceilf(r.size.y * S)), 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		for x in w:
			var p := Vector2(r.position.x + (float(x) + 0.5) / S, r.end.y - (float(y) + 0.5) / S)
			mask[y * w + x] = 1 if Geometry2D.is_point_in_polygon(p, poly) else 0
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var hm := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(COL.iron_lit.darkened(0.45))
	hm.fill(Color(0.0, 0.0, 0.0))
	var base: Color = COL.iron_lit
	var rust: Array = COL.rust
	for y in h:
		for x in w:
			if mask[y * w + x] == 0:
				continue
			var edge := false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx: int = x + o.x
				var yy: int = y + o.y
				if xx < 0 or yy < 0 or xx >= w or yy >= h or mask[yy * w + xx] == 0:
					edge = true
			var c: Color = base.lightened(rng.randf_range(0.0, 0.05)) if rng.randf() < 0.45 \
					else base.darkened(rng.randf_range(0.0, 0.10))
			var hv: float = 0.80 + rng.randf_range(-0.08, 0.06)
			var low: bool = y >= h - 3 or x >= w - 4
			if rng.randf() < (0.05 if low else 0.008):
				c = rust[rng.randi() % rust.size()]
				hv -= 0.10
			if edge:
				c = base.darkened(0.40)
				hv = 0.45
			im.set_pixel(x, y, c)
			hm.set_pixel(x, y, Color(hv, hv, hv))
	return [im, hm]


#  쇠 판 하나 — 다각형을 d 만큼 밀어 검은 쇠 그림(_iron_img)을 입힌다.
static func _iron_plate(parent: Node, poly: PackedVector2Array, d: float, at: Vector3, seed: int,
		nm: String) -> MeshInstance3D:
	var r := _poly_rect(poly)
	var ip := _iron_img(poly, r, seed)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = _extrude(poly, d, r)
	mi.material_override = _lit_mat(ip[0], ip[1], 0.7, 1.0)
	mi.position = at
	parent.add_child(mi)
	return mi


#  놋쇠 — 빛을 단으로 끊는다(눈 틀의 법선 — 왼쪽 위 앞에서 오는 빛 하나). 짙은 끝(테두리) · 그늘 · 몸 ·
#  빛 · 1px 흰 줄(반사)의 다섯 단. 문 장면은 비칠 것이 없어 금속 반사가 제 색 한 덩이로 섰다(주황
#  플라스틱 관). 도트 놋쇠는 이 다섯 단으로 읽힌다. lk — 램프 몫(불 깜박 · door_lights).
const BRASS_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec3 c0 : source_color = vec3(0.2, 0.1, 0.0);
uniform vec3 c1 : source_color = vec3(0.4, 0.3, 0.1);
uniform vec3 c2 : source_color = vec3(0.6, 0.5, 0.2);
uniform vec3 c3 : source_color = vec3(0.8, 0.7, 0.3);
uniform vec3 c4 : source_color = vec3(1.0, 0.95, 0.8);
uniform float lk = 1.0;
const vec3 L = vec3(-0.5, 0.5, 0.7071);
void fragment() {
	vec3 n = normalize(NORMAL);
	float d = dot(n, L);
	float s = dot(n, normalize(L + vec3(0.0, 0.0, 1.0)));
	vec3 c = c1;
	if (d > 0.30) {
		c = c2;
	}
	if (d > 0.72) {
		c = c3;
	}
	if (s > 0.955) {
		c = c4;
	}
	//  테(짙은 끝)는 눈에서 비껴 선 면 — 눈 쪽 법선(VIEW)으로 잰다. 손잡이는 카메라 축에서 14° 비껴 있어 n.z < 0.5 로
	//  재면 굽 · 받침의 왼옆(눈을 향한 면)까지 짙은 덩이로 섰다(2026-10-16 · glb 활 손잡이). 테는 1px 이면 된다.
	if (dot(n, normalize(VIEW)) < 0.35 && !(n.y > 0.9)) {
		c = c0;
	}
	ALBEDO = c * mix(0.30, 1.0, lk);
}
"""
static var _brass_sh: Shader = null


static func _brass_mat() -> ShaderMaterial:
	if _brass_sh == null:
		_brass_sh = Shader.new()
		_brass_sh.code = BRASS_SHADER
	var m := ShaderMaterial.new()
	m.shader = _brass_sh
	var rp: Array = COL.brass_ramp
	for i in rp.size():
		m.set_shader_parameter("c%d" % i, rp[i])
	return m


#  모서리를 깎은 판 — 앞면 가운데 판 · 네 변의 비탈(bev) · 옆. 비탈이 빛을 받아(위 · 왼쪽) 1px 빛 · 그늘 테가 선다.
static func _bevel_plate(w: float, h: float, t: float, bev: float, m: Material, at: Vector3) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw: float = w * 0.5
	var hh: float = h * 0.5
	var iw: float = hw - bev
	var ih: float = hh - bev
	var put := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		var n: Vector3 = (c - a).cross(b - a).normalized()
		for v in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(v)
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, want: Vector3) -> void:
		if (c - a).cross(b - a).dot(want) < 0.0:
			put.call(a, c, b)
			put.call(a, d, c)
		else:
			put.call(a, b, c)
			put.call(a, c, d)
	var zf: float = t
	var zb := 0.0
	var o := [Vector3(-hw, hh, zf - bev), Vector3(hw, hh, zf - bev), Vector3(hw, -hh, zf - bev),
			Vector3(-hw, -hh, zf - bev)]
	var i_ := [Vector3(-iw, ih, zf), Vector3(iw, ih, zf), Vector3(iw, -ih, zf), Vector3(-iw, -ih, zf)]
	quad.call(i_[0], i_[1], i_[2], i_[3], Vector3.BACK)
	var wants := [Vector3(0, 1, 1), Vector3(1, 0, 1), Vector3(0, -1, 1), Vector3(-1, 0, 1)]
	var sides := [Vector3.UP, Vector3.RIGHT, Vector3.DOWN, Vector3.LEFT]
	for k in 4:
		var k2: int = (k + 1) % 4
		quad.call(o[k], o[k2], i_[k2], i_[k], wants[k])
		quad.call(Vector3(o[k].x, o[k].y, zb), Vector3(o[k2].x, o[k2].y, zb), o[k2], o[k], sides[k])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.position = at
	return mi


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
	#  램프 둘레 번짐 — 그림자 없는 옅은 빛(LOOK.spill_e)
	var sp := OmniLight3D.new()
	sp.name = "Spill"
	sp.light_color = COL.lamp
	sp.light_energy = float(LOOK.spill_e)
	sp.omni_range = float(LOOK.spill_r)
	sp.omni_attenuation = 1.0
	sp.light_cull_mask = 1
	sp.position = LOOK.lamp_at
	root.add_child(sp)
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


#  밖의 빛 둘의 몫(1 이 제 빛) — 제목의 불 깜박(game.gd FLICK)이 사건 동안만 내린다.
static func door_lights(vp: SubViewport, lamp_k: float, neon_k: float) -> void:
	var l := vp.get_node_or_null("Door/Lamp") as Light3D
	if l != null:
		l.light_energy = float(LOOK.lamp_e) * lamp_k
	var sl := vp.get_node_or_null("Door/Spill") as Light3D
	if sl != null:
		sl.light_energy = float(LOOK.spill_e) * lamp_k
	var n := vp.get_node_or_null("Door/Neon") as Light3D
	if n != null:
		n.light_energy = float(LOOK.neon_e) * neon_k
	#  놋쇠는 빛을 단으로 그린 제 색이라(BRASS_SHADER) 램프 몫을 따로 받는다
	var h := vp.get_node_or_null("Door/Hinge")
	if h != null and h.has_meta("brass"):
		for m in h.get_meta("brass"):
			(m as ShaderMaterial).set_shader_parameter("lk", lamp_k)


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
