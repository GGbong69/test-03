extends RefCounted

# ══════════════════════════════════════════════════════════
#  다트판 벽 — 불 꺼진 방, 판 하나에만 떨어지는 빛 (2026-10-04)
#
#  처음 길 「상점과 같은 3D 바 방을 다트판 정면으로 찍어 배경에 깝니다」(2026-10-04)는
#  판자 기둥 양옆에 흐린 술병 선반 · 세로 HIGHTON 네온 · 쪽빛 마티니 잔을 세웠다. 그 판결:
#  「아... 좀 촌스러운데..? 좀 세련된 디자인 없어?」(사용자, 2026-10-04). 고른 길 「한 줄기 빛」:
#  「방 불을 끄고 다트판 하나에만 위에서 좁은 빛을 떨어뜨립니다. 네온과 술병, 금빛 명판을 걷어
#   내고, 고른 판만 빛 안에 두고 나머지는 그늘로 물러나게 합니다.」
#
#   · 왜 촌스러웠나 — 벽만 창 해상도로 굽고 가우스 DOF 를 걸어 픽셀 게임 뒤에 HD 사진을 깐
#     꼴이었고, 판보다 채도 높은 네온 둘 · 빛망울로 번진 컬러 병이 판에서 눈을 뺏었다.
#     세로로 쌓은 분홍 간판은 모텔 간판으로 읽혔다.
#   · 그래서 — 상점과 같은 밀도로 굽는다(논리 1px = 1텍셀, nearest — Room3D.make_table 과
#     같다 · game.gd _wall3_k). 깊이는 흐림이 아니라 어둠으로 낸다. 빛은 판 위 램프 하나뿐이고
#     링 바깥 한 뼘을 지나면 판자가 어둠에 잠긴다. 판 밖에는 채도 높은 색이 없다.
#   · 벽은 이음 없는 어두운 판자 한 장이다(폭 PILLAR × 2 — 21:9 창까지 덮는다). 판자 결과
#     이음은 상점 방의 그것(Room3D._plank)이라 같은 집의 벽이다.
#   · 판은 3D 에 없다. 2D 판(game.gd _draw_board)이 그 자리에 앉는다 — 카메라 축이 판
#     한가운데(BC)를 지나고 판 평면(z 0)에서 1m = S 논리 px 다. 고무 링 안쪽 끝이 판 테(ro)
#     밑으로 2px 물린다 — 1:1 로 구운 링 안쪽 계단이 2D 판 테 밑에 숨는다. 링 안은 받침판이다
#     (판 갈이 · 판 깨짐에 판을 떼어 낸 자리).
#   · 램프는 판 위 앞, 화면 밖이다 — 2D 판이 왼쪽 위에서 빛을 받으므로(_board_light) 아주
#     조금 왼쪽이다. 링 밑에 부드러운 초승달 그림자 하나가 진다.
#   · 움직이는 것이 없다 — 한 번 굽고 멈춘다(game.gd _wall3_tick). 창 여백 · 판 크기가
#     바뀔 때만 다시 굽는다.
#  ⚠ 헤드리스에서는 만들지 않는다(부르는 쪽이 _has_renderer 로 막는다).
# ══════════════════════════════════════════════════════════

const Room3D = preload("res://scripts/room3d.gd")

const S := 360.0          # 판 평면(z 0)에서 1m = 논리 px. 판 테 121.5px ≈ 0.34m — 상점 벽의 판(0.68m)과 같다
const EYE := 2.37         # 눈 — 던지는 줄에서 판까지(m). 실물 다트의 그 거리
const MARGIN := 14.0      # 흔들림 여유(논리 px) — 화면이 흔들려도(봉우리 12px) 가장자리가 안 비친다
#  벽 반폭(m) — 화면 ±936px. 21:9(논리 843 폭)까지 한 장이 덮는다. 옛 기둥(0.56)은 양옆에 흐린
#  바를 두고 기둥 모서리 두 줄이 화면을 세 토막 냈다(「아... 좀 촌스러운데..?」, 2026-10-04).
const PILLAR := 2.6
const FACE := -0.04       # 벽 앞면 z — 받침판 · 링이 4cm 나와 있다
#  고무 링 폭(논리 px) — 판 테 바깥으로. 16 의 반들 원환은 타이어 · 변기 시트로 읽혔다 —
#  실물 LED 서라운드처럼 얇고 무광으로 간다(2026-10-04).
const RING := 10.0
const PLANK := Color("2c1508")   # 벽 판자 — 도트 팔레트 「나무 1」. 빛 밖에서는 140904 → 어둠으로 진다
const RUBBER := Color("080707")
const BACKING := Color("040303")    # 받침판 — 판이 뜬 자리가 빈자리로 읽힌다
const HOOK := Color("0d0b0b")       # 걸쇠 — 무광 검은 쇠(놋쇠는 램프 밑에서 금빛 단추로 튀었다)
#  빛 — 램프 하나. 판이 화면에서 가장 밝고, 링 바깥 한 뼘까지만 판자 결이 보이고, 링 반지름
#  1.6 배쯤에서 거의 검다. 판 밖에 채도 높은 색은 없다(「아... 좀 촌스러운데..? 좀 세련된
#  디자인 없어?」, 2026-10-04 — 네온 · 발광 술병 · DOF 빛망울을 걷었다).
const LOOK := {
	"lamp_e": 10.0,           # 램프 세기
	"lamp_c": Color("ffd9a0"),   # 램프 빛 — 상점 램프(COL.lamp)보다 한 단 희다(판의 백색 칸이 누렇게 안 뜬다)
	"lamp_ang": 30.0,         # 램프 원뿔 반각(도) — 좁게
	#  가장자리로 지는 굽이 — 엔진 식이 1 − rim^이 값이라 클수록 안이 평평하고 끝에서 진다.
	"lamp_att": 1.4,
	#  램프 자리(판 기준 m) — 판 위 앞, 아주 조금 왼쪽. 빛이 거의 위에서 떨어진다.
	"lamp_at": Vector3(-0.05, 1.10, 0.80),
	"lamp_to": Vector2(-0.02, 0.04),         # 램프가 겨누는 판 면 자리(m)
	"rub_rough": 0.8, "rub_spec": 0.06,      # 고무 링 재질 — 무광. 반짝임 줄이 안 선다(0.12 는 램프 밑에서 갈색 테로 떴다)
	"rub_round": 0.5,                        # 고무 관 단면 납작함(1 = 둥근 관) — 낮은 서라운드
	"shadow_blur": 1.5,       # 램프 그림자 번짐
	"shadow_size": 0.05,      # 램프 크기(m) — 그림자 반그늘 폭
	"shadow_a": 0.70,         # 그림자 짙기 — 링 밑 초승달 하나
	#  방 빛(환경광) — 빛 밖의 판자가 어둠으로 지되 이음이 겨우 읽힌다(기본 필터에서 L* 8~12 ·
	#  140904 ~ 2c1508 언저리). 0.06 은 양옆이 칠흑이라 「덜 만든 화면」 · 무대 허공으로 읽혔다
	#  (검토, 2026-10-05). 판보다 밝아지거나 무늬가 생기면 안 된다.
	"amb": 0.65,
	#  램프 끈 벽(lamp_on false — 판 갈이)의 방 빛. 상점 불이 아직 다 안 꺼진 방이라 램프 켠 벽의
	#  빛 밖보다 한 단 밝다 — 0.65 그대로면 상점(가운데 밝기 40 남짓)에서 17 로 떨어져 판 갈이가
	#  깜빡임으로 읽혔다(촬영, 2026-10-05). 램프가 켜지는 만큼 이 빛이 빠진다.
	"amb_off": 1.15,
	#  벽 재질(_wall_mat) — 옅은 결 · 판 톤의 대비 몫 · 채도 몫. 0.4 · 0.55 로도 웅덩이 속 판자가
	#  주황 라미네이트였다(기본 필터 채도 0.56~0.60 · 끄면 0.62~0.72, 검토 2026-10-05) — 한 단 더
	#  눌러 따뜻하되 무채색에 가까운 나무로 간다. 이음 · 못 · 옹이와 빛 밖 판자는 그대로다.
	"grain": 0.25, "sat": 0.38,
	"bg": Color("050404"),    # 아무것도 없는 자리 · 안개
	#  빛 웅덩이(램프에 비추는 동그란 그러데이션) [반지름 몫, 밝기] — 판 둘레는 고루,
	#  링 바깥 한 뼘을 지나면 빠르게 진다.
	"pool": [[0.0, 1.0], [0.45, 0.95], [0.55, 0.70], [0.66, 0.32], [0.76, 0.07], [0.88, 0.0], [1.0, 0.0]],
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
	#  링 그림자 결 — 기본 2048 아틀라스에서는 램프 하나의 그림자 가장자리가 거칠게 씹혔다.
	#  한 번 굽고 멈추는 화판이라 값이 싸다.
	vp.positional_shadow_atlas_size = 4096
	host.add_child(vp)

	var root := Node3D.new()
	root.name = "Wall"
	vp.add_child(root)

	#  초점 흐림(DOF)은 없다 — 깊이는 어둠으로 낸다. 흐린 벽은 픽셀 게임 뒤의 HD 사진으로 읽혔다.
	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.near = 0.05
	cam.far = 30.0
	cam.position = Vector3(0.0, 0.0, EYE)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	root.add_child(cam)

	var we := WorldEnvironment.new()
	we.name = "Env"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = LOOK.bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(LOOK.lamp_c)
	env.ambient_light_energy = float(LOOK.amb)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = LOOK.bg
	env.fog_density = 1.0
	env.fog_depth_begin = EYE + 0.3
	env.fog_depth_end = EYE + 3.2
	env.fog_depth_curve = 1.0
	#  번짐(글로우)도 없다 — 빛나는 것이 없다.
	env.glow_enabled = false
	we.environment = env
	root.add_child(we)

	_wall(root)
	_board_mount(root)
	_lamp(root)
	return vp


#  창 여백 · 판 크기에 맞춘다. 화판의 한가운데가 판 한가운데(bc)에 앉고, 화판이
#  여백 + MARGIN 까지 덮는다(아래로는 bc 가 화면 가운데보다 낮은 몫만큼 화면 밖이다).
#  ro — 판 테 반지름(논리 px). 바뀌면 링과 받침판이 따라간다.
#  k — 굽는 배율(논리 1px = 화판 k px). game.gd _wall3_k 가 1 을 준다 — 상점 테이블과 같은 밀도.
#  화판 크기는 짝수로 올린다 — 한가운데가 텍셀 경계에 선다.
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
	var ring: MeshInstance3D = root.get_node_or_null("Ring")
	if ring != null:
		var tm := ring.mesh as TorusMesh
		#  안쪽 끝이 판 테 밑 2px — 1:1 로 구운 링 안쪽 계단이 2D 판 테에 덮인다.
		tm.inner_radius = (ro - 2.0) / S
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


# ── 벽 — 세로 판자 한 장 · 니스 안 친 거친 결 ─────────────
#  기둥 · 꽂이 벽 · 그 사이 흐린 바로 갈렸던 세 면을 한 장으로 걷었다 — 기둥 모서리의 짙은
#  세로 띠 두 줄이 화면을 세 토막 냈고, 흐린 바 한가운데 판자 기둥은 말이 안 됐다(검토).
static func _wall(root: Node3D) -> void:
	var w: float = PILLAR * 2.0
	var y0 := -0.9
	var y1 := 1.0
	#  판자는 1 텍셀 = 판 평면 논리 1px 로 굽는다(상점 카운터와 같은 결의 크기).
	#  _plank 는 누운 판을 짓는다 — 90° 돌려 세운다. 결은 이 벽 재질(_wall_mat)에서만 누른다 —
	#  상점 방 · 카운터의 판자(Room3D._plank)는 그대로다.
	var pair: Array = Room3D._plank(int((y1 - y0) * S), int(w * S), PLANK, 20261004, 40, 52)
	var im: Image = pair[0]
	im.rotate_90(CLOCKWISE)
	var m := _wall_mat(ImageTexture.create_from_image(im))
	var qm := QuadMesh.new()
	qm.size = Vector2(w, y1 - y0)
	var q := MeshInstance3D.new()
	q.name = "Pillar"
	q.mesh = qm
	q.material_override = m
	q.position = Vector3(0.0, (y0 + y1) * 0.5, FACE)
	root.add_child(q)


#  벽 판자 재질 — 결 대비 · 채도만 누른다. 램프 웅덩이 속에서 판자 세로 결이 채도 높은 주황
#  줄로 서서 필터를 켜면 긁힌 라미네이트처럼 지글거렸다(검토, 2026-10-05 「① 던지기 + ② 판
#  고르기」). 판 바탕 색에서 벗어난 몫이 작은 결(옅은 결 · 판마다 톤)만 grain 몫으로 줄이고,
#  크게 짙은 이음 · 못 · 옹이(바탕의 반 밑)는 그대로 둔다 — 빛 밖 어둠에서도 판자 이음이 읽혀야
#  「불 꺼진 방의 판자 벽」이다. 그 뒤 채도를 sat 몫으로 — 따뜻하되 무채색에 가까운 나무.
const WALL_SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_nearest;
uniform vec3 base : source_color;
uniform float grain = 0.4;
uniform float sat = 0.55;
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	vec3 lw = vec3(0.2126, 0.7152, 0.0722);
	float lb = max(dot(base, lw), 0.0001);
	float d = dot(c, lw) / lb - 1.0;
	float k = mix(grain, 1.0, smoothstep(0.40, 0.60, -d));
	c = base + (c - base) * k;
	c = mix(vec3(dot(c, lw)), c, sat);
	ALBEDO = c;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
"""


static func _wall_mat(tex: Texture2D) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = WALL_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("base", PLANK)
	m.set_shader_parameter("grain", float(LOOK.grain))
	m.set_shader_parameter("sat", float(LOOK.sat))
	return m


#  꽂이 곁 빛(PostLamp · 0.05)은 걷었다 — 환경광 0.65 밑에서는 아무 일도 안 했다(검토, 2026-10-05).
#  레일은 제 빛 받는 변(game.gd WALL3.rail_*)으로 선다.


# ── 판 자리 — 고무 링 · 받침판 · 걸쇠 ─────────────────────
#  치수는 wall_fit 이 판 테(ro)에서 잡는다. 여기서는 모양과 재질만.
static func _board_mount(root: Node3D) -> void:
	#  받침판 — 판을 떼어 내면 보이는 자리. 짙은 섬유판에 걸쇠 하나 · 나사 셋.
	#  판 갈이 · 판 깨짐에 판이 벽에서 떠 있는 동안 램프 한가운데에 드러난다 — 얼룩진 섬유
	#  (잡음 0.55~1)와 놋쇠 걸쇠가 램프 밑에서 베이지 원판 · 금빛 단추로 튀어, 일어서는 판 곁에
	#  판이 하나 더 있는 것으로 읽혔다(검토, 2026-10-05). 결은 겨우 · 걸쇠는 무광 검은 쇠다.
	var bm := Room3D._mat(BACKING, 0.95)
	bm.albedo_texture = Room3D._noise_tex(0.09, 0.88, 1.0, 31)
	#  반사는 끈다 — 기본 반사(0.5)로는 램프 한가운데에서 거친 반짝임이 넓게 얹혀 검은 받침판이
	#  베이지 코르크판으로 떴다(실험 — 받침판을 초록으로 칠해도 붉음 · 푸름이 0.38 · 0.21 남았다).
	bm.metallic_specular = 0.0
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
	#  걸쇠 · 나사는 반사를 끈다 — 기본 반사로는 램프 한가운데에서 반짝임이 얹혀 짙은 쇠가
	#  금빛 단추로 떴다(촬영, 2026-10-05).
	var hm := Room3D._mat(HOOK, 1.0, 0.0)
	hm.metallic_specular = 0.0
	var hook := Room3D._cyl(0.034, 0.034, 0.012, Vector3(0.0, 0.0, 0.004), hm, 20)
	hook.name = "Hook"
	hook.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	root.add_child(hook)
	for k in 3:
		var a: float = TAU * float(k) / 3.0 - PI * 0.5
		var sc := Room3D._cyl(0.008, 0.008, 0.006, Vector3(cos(a) * 0.024, -sin(a) * 0.024, 0.011),
				hm, 8)
		sc.name = "Screw%d" % k
		sc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		root.add_child(sc)
	#  고무 링 — 판 테를 두르는 낮은 무광 검은 서라운드. 반들거리면 위쪽에 반짝임 줄이 서서
	#  타이어로 읽혔다 — 거칠고 납작하게, 빛은 넓고 흐리게만 받는다.
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


# ── 램프 — 판 위 앞(화면 밖) · 좁은 빛 하나와 링 그림자 ──
static func _lamp(root: Node3D) -> void:
	var sl := SpotLight3D.new()
	sl.name = "Lamp"
	sl.light_color = LOOK.lamp_c
	sl.light_energy = float(LOOK.lamp_e)
	sl.spot_range = 4.0
	sl.spot_attenuation = 0.6
	sl.spot_angle = float(LOOK.lamp_ang)
	sl.spot_angle_attenuation = float(LOOK.lamp_att)
	sl.shadow_enabled = true
	sl.shadow_blur = float(LOOK.shadow_blur)
	sl.light_size = float(LOOK.shadow_size)
	sl.shadow_opacity = float(LOOK.shadow_a)
	#  빛 웅덩이의 꼴 — 원뿔 감쇠만으로는 판자가 끝까지 고루 밝았다(위로 갈수록 빛을 정면으로
	#  받아 감쇠를 되갚는다). 동그란 그러데이션을 램프에 비춰 판 둘레만 밝힌다.
	sl.light_projector = _pool_tex()
	var at: Vector3 = LOOK.lamp_at
	var lt: Vector2 = LOOK.lamp_to
	var tgt := Vector3(lt.x, lt.y, FACE)
	sl.transform = Transform3D(Basis.looking_at(tgt - at, Vector3.UP), at)
	root.add_child(sl)


#  램프를 켜고 끈다 — game.gd _wall3_tick 이 램프 켠 벽을 구운 뒤 끄고 한 장 더 굽는다(판 갈이에서
#  램프가 꺼진 벽 · 환경광만). 굽기가 끝나면 다시 켠다. 끈 장에는 판 자리(받침판 · 고무 링 ·
#  걸쇠 · 나사)도 없다 — 어둠 속 검은 받침판이 판보다 큰 검은 원반으로 남아, 누운 판이 일어서는
#  동안 판이 둘로 읽혔다(촬영, 2026-10-05). 불 꺼진 방에서 검은 고무 링은 판자와 안 갈린다 —
#  램프가 켜지는 만큼 판 자리가 드러나고 그 앞을 판이 덮는다.
static func lamp_on(vp: SubViewport, on: bool) -> void:
	for nm in ["Lamp", "Backing", "Ring", "Hook", "Screw0", "Screw1", "Screw2"]:
		var n: Node3D = vp.get_node_or_null("Wall/" + nm) as Node3D
		if n != null:
			n.visible = on
	var we: WorldEnvironment = vp.get_node_or_null("Wall/Env") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.ambient_light_energy = float(LOOK.amb if on else LOOK.amb_off)


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
