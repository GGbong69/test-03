extends RefCounted
# ══════════════════════════════════════════════════════════
#  프롤로그 — 전파상 창고의 주인공 TV · 3D 를 도트로 (2026-10-18)
# ──────────────────────────────────────────────────────────
#  「게임 시작 할 때 프롤로그 … tv화면이 전체 화면이 되고 그 때 부터 우리가 만든 tv 켜짐 부터」 · 장소
#  「어두운 전파상 창고」 · 「그냥 제작자만 보여주자」(김건의) · 「그냥 3d로 하고 도트같이 필터를 씌우자」 ·
#  「카메라 무빙 넣지말고 … 불이 깜박깜박 됐다가 게임 tv로 클로즈업」 · 「다른 tv들 그냥 아무 장면이나 보여줘도
#  되 노이즈가 걸린 tv가 있어도 괜찮고」 · 「중요하지 않은 tv랑 중요한 tv는 나누고 중요한 tv는 좀 퀄리티
#  엄청엄청 높게 하고 안 중요한 tv는 좀 엑스트라? 명도나 밝기도 조금 어둡게」 · 「메인 tv가 가운데 크게 보이도록
#  사질 나머지는 거의 안보여도 괜찮잖아」(젠레스 존 제로 런처 그림)(사용자).
#  주인공 TV(TvHero · 비디오 데크 위) 하나가 화면 가운데를 크게 차지하고, 둘레의 TV 더미는 엑스트라 — 몸은
#  어둡고(EXTRA) 화면은 흐리고 덜 붉고 굵은 도트다. 주인공은 빛 단을 잘게(HERO.bands) · 위 등(깜박이는 그 등)이
#  주인공만 좁게 비춘다. 「제작 김건의」는 주인공 화면에 뜬다(지지직 → 그림).
#  TV 는 scripts/tools/blender/tvs.py 가 짓는다(assets/models/tvs.glb). 무대는 논리 화면 크기의 SubViewport
#  — 게임 도트와 같은 격자에 그려 가장 가까운 점으로 붙인다. 몸 재질은 방과 같은 Door3D._px(빛 단 + 바둑
#  디더) · 화면은 SCR_SHADER(화면 도트 칸 · 주사선 · 단 나눈 색). 켜진 화면마다 제 빛깔의 점 빛을 앞에 둔다.
#  흐름 — 어둠(구석 지지직 한 대) → 위 등이 깜박이다 선다 → 둘레 TV 가 흐리게 켜진다 → 주인공이 켜진다
#  (지지직 → 제작자) → 카메라가 주인공 화면으로 곧게 다가간다 → 유리가 화면을 채울 즈음 주인공이 꺼진다
#  (줄로 접혀 점으로) → game.gd 가 브라운관을 켠다(_plg_end).
#  API — make(host) · tick(h, t) · draw(h, ci, dest) · length() · ON(소리 때 — off 는 꺼지는 소리).

const Door3D = preload("res://scripts/door3d.gd")
const Room3D = preload("res://scripts/room3d.gd")
const TVS_GLB := "res://assets/models/tvs.glb"
const LEN := 6.15
const ON := {"tvs": 1.0, "hero": 1.75, "off": 5.35}
#  lamp 위 등이 깜박이기 시작하는 때 · LAMP_SW 그 뒤 켜짐/꺼짐이 바뀌는 때(마지막에 켜진 채 선다) ·
#  stag 둘레 TV 가 차례로 켜지는 사이 · snow 주인공이 켜진 뒤 지지직 동안 · push0~push1 다가가는 동안 ·
#  off 주인공이 꺼지는 동안(ON.off 부터)
const T := {"lamp": 0.55, "stag": 0.05, "snow": 0.5, "push0": 3.7, "push1": 5.6, "off": 0.4}
const LAMP_SW := [0.0, 0.06, 0.18, 0.24, 0.50, 0.55, 0.62]
const FONT_BIG := "res://fonts/Paperlogy-7Bold.ttf"
const FONT_SM := "res://fonts/Galmuri9.ttf"
#  제작자 그림 — 주인공 유리가 첫 장면에서 차지하는 논리 px 언저리(1 칸 = 1 px)
const CARD := Vector2i(220, 204)
#  카메라 — 서 있는 자리 · 보는 점 · 세로 화각(주인공 폭이 화면 폭의 여섯 몫 언저리)
const CAM := {"at": Vector3(0.0, 0.98, 1.30), "look": Vector3(0.0, 1.0, 0.0), "fov": 34.0}
#  주인공 · 엑스트라 — 몸 바탕 빛(fill) · 빛 단 수 · 점 빛 세기 · (엑스트라) 몸 빛깔 배수 · 화면 밝기 · 채도 ·
#  화면 도트(1m 당 칸)
const HERO := {"fill": Color(0.07, 0.08, 0.11), "bands": 6.0, "light": 0.3}
const EXTRA := {"fill": Color(0.018, 0.018, 0.03), "bands": 3.0, "light": 0.12, "tone": 0.4, "dim": 0.22,
		"sat": 0.5, "cells": 50.0}
#  화면 장면 — 번호(SCR_SHADER mode) · 앞에 둔 점 빛 빛깔. game 은 주인공(지지직 1 → 제작자 그림 4).
const JOB := {
	"game": [4, Color(1.0, 0.62, 0.28)], "snow": [1, Color(0.62, 0.68, 0.80)], "bars": [2, Color(0.72, 0.70, 0.60)],
	"blue": [3, Color(0.25, 0.40, 1.0)], "wave": [5, Color(0.35, 1.0, 0.50)],
	"ball": [6, Color(0.60, 0.62, 0.70)], "sunset": [7, Color(1.0, 0.50, 0.38)], "board": [8, Color(0.85, 0.72, 0.60)],
}
const PLASTIC := {"red": Color("a83c30"), "teal": Color("2f8a84"), "graph": Color("2b2f3c"), "slate": Color("3d4456"),
		"": Color("8c2924")}
#  더미 — [꼴, x, 앞뒤 z, 돌림(도), 기울기(도), 플라스틱 빛깔, 장면]. 밑에서 위로 — 그 폭 밑의 가장 높은 윗면에
#  얹는다. 기울면 낮은 귀가 윗면에 닿게 든다. 주인공(TvHero · 장면 game)과 데크는 앞으로 · 엑스트라는 뒤로
#  물린다. snow0 은 처음부터 켜진 구석 지지직(어둠 속 첫 빛).
const PILE := [
	["TvConsole", -1.02, -0.10, 5.0, 0.0, "", "bars"],
	["TvConsole", 0.0, -0.02, 0.0, 0.0, "", "sunset"],
	["TvWood", 0.98, -0.10, -6.0, 0.0, "", "snow"],
	["Speaker", 1.50, -0.12, -8.0, 0.0, "", ""],
	["Speaker", -1.55, -0.12, 8.0, 0.0, "", ""],
	["Deck", 0.0, 0.04, 0.0, 0.0, "", ""],
	["TvHero", 0.0, 0.04, 0.0, 0.0, "", "game"],
	["TvMon", -0.78, -0.12, 8.0, -3.0, "graph", "snow0"],
	["Speaker", 0.62, -0.10, -6.0, 0.0, "", ""],
	["TvBox", -0.84, -0.14, 10.0, 5.0, "", "blue"],
	["TvPort", 0.66, -0.14, -7.0, -4.0, "red", "ball"],
	["TvBox", -0.28, -0.16, 6.0, -4.0, "", "wave"],
	["TvMon", 0.24, -0.18, -5.0, 3.0, "slate", "board"],
	["TvPort", -1.28, -0.16, 9.0, 3.0, "teal", "snow"],
	["TvMon", 1.20, -0.16, -9.0, -4.0, "graph", "bars"],
]
const HERO_KINDS := ["TvHero", "Deck"]

#  화면 — UV(0,0 왼 위) 를 res 칸으로 끊는다. pw 켜짐(0~1 · 가운데 줄이 위아래로 벌어지고 처음엔 하얗다) ·
#  cl 꺼짐(0~1 · 하얘지며 가로 줄로 접히고 → 점으로 줄어 사라진다) · dim · sat 엑스트라의 밝기 · 채도.
#  꺼진 유리는 짙은 회색에 왼 위 비스듬한 반짝 띠. 색은 여섯 단으로 끊고 바둑 디더를 얹는다.
const SCR_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform int mode = 0;
uniform float pw = 0.0;
uniform float cl = 0.0;
uniform float tm = 0.0;
uniform float seed = 0.0;
uniform float dim = 1.0;
uniform float sat = 1.0;
uniform vec2 res = vec2(40.0, 30.0);
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;

float hs(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed * 17.0) * 43758.5453);
}

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int M[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(M[x + y * 4]) + 0.5) / 16.0;
}

vec3 scene(vec2 q) {
	float ar = res.x / res.y;
	if (mode == 1) {
		float n = hs(floor(q * res) + floor(tm * 15.0) * vec2(7.0, 13.0));
		float v = n < 0.45 ? 0.08 : (n < 0.8 ? 0.42 : 0.78);
		return vec3(v, v, v * 1.06) * (0.72 + 0.28 * step(0.18, fract(q.y - tm * 0.45)));
	}
	if (mode == 2) {
		vec3 C[7] = vec3[](vec3(0.75), vec3(0.75, 0.75, 0.0), vec3(0.0, 0.75, 0.75), vec3(0.0, 0.75, 0.0),
				vec3(0.75, 0.0, 0.75), vec3(0.75, 0.0, 0.0), vec3(0.0, 0.0, 0.75));
		if (q.y > 0.74) {
			return q.x < 0.3 ? vec3(0.02, 0.12, 0.35) : (q.x < 0.55 ? vec3(0.95) : vec3(0.03));
		}
		return C[int(clamp(q.x * 7.0, 0.0, 6.0))];
	}
	if (mode == 3) {
		vec3 c = vec3(0.08, 0.18, 0.72);
		if (abs(q.y - 0.5) < 0.09 && abs(q.x - 0.5) < 0.3 && fract(tm * 0.9) < 0.6) {
			c = vec3(0.92);
		}
		return c;
	}
	if (mode == 4) {
		return texture(tex, q).rgb;
	}
	if (mode == 5) {
		vec3 c = vec3(0.02, 0.09, 0.05);
		if (fract(q.x * 6.0) < 1.0 / res.x * 6.0 || fract(q.y * 4.0) < 1.0 / res.y * 4.0) {
			c = vec3(0.04, 0.22, 0.10);
		}
		float y = 0.5 + 0.3 * sin(q.x * 11.0 + tm * 5.0) * cos(q.x * 3.0 - tm * 1.3);
		if (abs(q.y - y) < 1.2 / res.y) {
			c = vec3(0.50, 1.0, 0.58);
		}
		return c;
	}
	if (mode == 6) {
		vec2 b = abs(fract(vec2(tm * 0.41, tm * 0.57) + seed) * 2.0 - 1.0);
		b = 0.14 + b * 0.72;
		vec3 c = vec3(0.04, 0.04, 0.07);
		if (abs(q.x - 0.5) < 0.6 / res.x && fract(q.y * 7.0) < 0.5) {
			c = vec3(0.45);
		}
		if (length((q - b) * vec2(ar, 1.0)) < 0.1) {
			c = vec3(0.95, 0.92, 0.75);
		}
		return c;
	}
	if (mode == 7) {
		float hz = 0.62;
		vec3 c = mix(vec3(0.30, 0.10, 0.40), vec3(0.98, 0.52, 0.26), clamp(q.y / hz, 0.0, 1.0));
		vec2 s = (q - vec2(0.5, 0.56)) * vec2(ar, 1.0);
		if (length(s) < 0.24 && q.y < hz && !(q.y > 0.46 && fract(q.y * 16.0) < 0.3)) {
			c = vec3(1.0, 0.86, 0.42);
		}
		if (q.y >= hz) {
			c = vec3(0.14, 0.08, 0.28);
			float w = 0.26 * (1.0 - (q.y - hz) * 1.6);
			if (abs(q.x - 0.5) < w && fract(q.y * 11.0 + tm * 0.6) < 0.35) {
				c = vec3(0.95, 0.58, 0.30);
			}
		}
		return c;
	}
	if (mode == 8) {
		vec2 d = (q - 0.5) * vec2(ar, 1.0);
		float r = length(d) / 0.42;
		float sec = floor((atan(d.y, d.x) + tm * 0.7) / 6.2831853 * 20.0);
		bool alt = mod(sec, 2.0) < 1.0;
		vec3 c = vec3(0.10, 0.06, 0.05);
		if (r < 1.0) {
			c = alt ? vec3(0.07) : vec3(0.92, 0.88, 0.78);
		}
		if ((r < 1.0 && r > 0.88) || (r < 0.6 && r > 0.5)) {
			c = alt ? vec3(0.78, 0.12, 0.12) : vec3(0.10, 0.50, 0.26);
		}
		if (r < 0.12) {
			c = vec3(0.10, 0.50, 0.26);
		}
		if (r < 0.05) {
			c = vec3(0.80, 0.10, 0.10);
		}
		return c;
	}
	return vec3(0.0);
}

void fragment() {
	vec2 cell = floor(UV * res);
	vec2 q = (cell + 0.5) / res;
	vec3 off = vec3(0.035, 0.042, 0.05);
	if (abs(UV.x + UV.y - 0.42) < 0.05 && UV.x < 0.45) {
		off += vec3(0.05);
	}
	vec3 c = off;
	if (pw > 0.0 && mode > 0) {
		vec3 s = scene(q);
		if (mod(cell.y, 2.0) > 0.5) {
			s *= 0.78;
		}
		s = mix(s, vec3(0.9, 0.95, 1.0), (1.0 - smoothstep(0.0, 0.35, pw)) * 0.85);
		s *= 1.0 - 1.2 * dot(UV - 0.5, UV - 0.5);
		s = mix(vec3(dot(s, vec3(0.299, 0.587, 0.114))), s, sat) * dim;
		float vh = max(smoothstep(0.0, 0.55, pw), 1.5 / res.y);
		float hw = 1.0;
		float fade = 1.0;
		if (cl > 0.0) {
			s = mix(s, vec3(0.95, 0.97, 1.0), smoothstep(0.1, 0.45, cl));
			vh = min(vh, max(1.0 - smoothstep(0.0, 0.45, cl), 1.5 / res.y));
			hw = max(1.0 - smoothstep(0.45, 0.85, cl), 1.5 / res.x);
			fade = 1.0 - smoothstep(0.85, 1.0, cl);
		}
		if (abs(q.y - 0.5) * 2.0 < vh && abs(q.x - 0.5) * 2.0 < hw) {
			c = mix(off, s, fade);
		}
	}
	c = floor(c * 6.0 + bayer(FRAGCOORD.xy)) / 6.0;
	ALBEDO = c;
}
"""
static var _scr_sh: Shader = null


#  제작자 그림 — 다섯 띠 바탕(호박빛 → 짙은 주황) · 「제작」 · 굵은 「김건의」(테 진 글).
class Card extends Node2D:
	var big: Font
	var sm: Font

	func _draw() -> void:
		var s := Vector2(CARD)
		var bands := [Color("f6b14a"), Color("f2a33a"), Color("e88f30"), Color("dc7c28"), Color("c46420")]
		for b in bands.size():
			var y0: float = floorf(s.y * b / bands.size())
			draw_rect(Rect2(0.0, y0, s.x, ceilf(s.y / bands.size()) + 1.0), bands[b])
		_txt(sm, 74.0, "제작", 18, Color(1.0, 0.95, 0.85), 1)
		_txt(big, 140.0, "김건의", 54, Color.WHITE, 2)

	func _txt(f: Font, y: float, s: String, sz: int, col: Color, k: int) -> void:
		if f == null:
			return
		var edge := Color(0.35, 0.12, 0.02)
		for dx in range(-k, k + 1):
			for dy in range(-k, k + 2):
				if dx != 0 or dy != 0:
					draw_string(f, Vector2(dx, y + dy), s, HORIZONTAL_ALIGNMENT_CENTER, float(CARD.x), sz, edge)
		draw_string(f, Vector2(0.0, y), s, HORIZONTAL_ALIGNMENT_CENTER, float(CARD.x), sz, col)


static func _hard(path: String) -> Font:
	var f := load(path) as FontFile
	if f == null:
		return null
	var h := f.duplicate() as FontFile
	h.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	h.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return h


static func length() -> float:
	return LEN


static func make(host: Node) -> Node:
	var hn := Node.new()
	hn.name = "Prologue"
	host.add_child(hn)
	var sz: Vector2 = host.call("_full").size if host.has_method("_full") else host.get_viewport_rect().size
	var vp := SubViewport.new()
	vp.name = "Stage"
	vp.size = Vector2i(maxi(int(sz.x), 2), maxi(int(sz.y), 2))
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.gui_disable_input = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	hn.add_child(vp)
	var cv := SubViewport.new()
	cv.name = "Card"
	cv.size = CARD
	cv.disable_3d = true
	cv.gui_disable_input = true
	cv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var card := Card.new()
	card.big = _hard(FONT_BIG)
	card.sm = _hard(FONT_SM)
	cv.add_child(card)
	hn.add_child(cv)

	var w := Node3D.new()
	vp.add_child(w)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("06060a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	we.environment = env
	w.add_child(we)
	var cam := Camera3D.new()
	cam.fov = float(CAM.fov)
	w.add_child(cam)
	cam.look_at_from_position(CAM.at, CAM.look)
	#  위 등 — 주인공만 좁게 내리비춘다(등 몸은 화면 밖)
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(0.85, 0.92, 1.0)
	lamp.spot_range = 5.0
	lamp.spot_angle = 19.0
	lamp.spot_attenuation = 0.8
	lamp.light_energy = 0.0
	w.add_child(lamp)
	lamp.look_at_from_position(Vector3(0.0, 2.7, 1.2), Vector3(0.0, 0.95, 0.0))

	var hm := _mats(HERO)
	var xm := _mats(EXTRA)
	_room(w, xm)
	var tvs := []
	var tops := []      # [x0, x1, 윗면] — 얹힌 것들
	var cam_end := {}
	for i in PILE.size():
		var e: Array = PILE[i]
		var me: Mesh = _mesh(String(e[0]))
		if me == null:
			continue
		var hero: bool = String(e[0]) in HERO_KINDS
		var bb: AABB = me.get_aabb()
		var x: float = float(e[1])
		var x0: float = x + bb.position.x
		var x1: float = x + bb.end.x
		var y := 0.0
		for tp in tops:
			if minf(x1, float(tp[1])) - maxf(x0, float(tp[0])) > 0.06:
				y = maxf(y, float(tp[2]))
		var lift: float = bb.size.x * 0.5 * absf(sin(deg_to_rad(float(e[4]))))
		tops.append([x0, x1, y + bb.end.y + lift])
		var mi := MeshInstance3D.new()
		mi.mesh = me
		mi.position = Vector3(x, y + lift, float(e[2]))
		mi.rotation_degrees = Vector3(0.0, float(e[3]), float(e[4]))
		w.add_child(mi)
		var job: String = e[6]
		var ms: Dictionary = hm if hero else xm
		var gm: ShaderMaterial = null
		var gb := AABB()
		for k in me.get_surface_count():
			var sm: Material = me.surface_get_material(k)
			var key: String = sm.resource_name if sm != null else ""
			if key == "glass":
				gb = _surf_aabb(me, k)
				gm = _scr_mat(job, gb, i, cv, hero)
				mi.set_surface_override_material(k, gm)
			elif key == "plastic":
				mi.set_surface_override_material(k, _body(PLASTIC.get(String(e[5]), PLASTIC[""]), EXTRA))
			elif ms.has(key):
				mi.set_surface_override_material(k, ms[key])
		if gm == null:
			continue
		var g: Vector3 = mi.transform * gb.get_center()
		var n: Vector3 = mi.transform.basis * Vector3(0.0, 0.0, 1.0)
		if hero:
			var ar: float = sz.x / maxf(sz.y, 1.0)
			var half: float = minf(gb.size.y * 0.5, gb.size.x * 0.5 / ar)
			cam_end = {"look": g, "at": g + n * (half * 0.86 / tan(deg_to_rad(float(CAM.fov)) * 0.5))}
		else:
			#  빨간 대기등 — 화면 오른쪽 아래 테 밖
			var led := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.014, 0.014, 0.01)
			led.mesh = lm
			led.material_override = Room3D._glow(Color("ff3b2e"), 1.2)
			led.position = Vector3(gb.end.x - 0.02, gb.position.y - 0.012, 0.004)
			mi.add_child(led)
		var ton: float = 0.0 if job == "snow0" else (float(ON.hero) if hero else
				float(ON.tvs) + float(T.stag) * float(tvs.size()))
		var lt := OmniLight3D.new()
		lt.light_color = JOB[job.trim_suffix("0")][1]
		lt.omni_range = 1.3 if hero else 0.8
		lt.omni_attenuation = 1.4
		lt.light_energy = 0.0
		lt.position = g + n * (0.7 if hero else 0.25)
		w.add_child(lt)
		tvs.append({"m": gm, "l": lt, "on": ton, "job": job, "i": i, "hero": hero,
				"e": float(HERO.light) if hero else float(EXTRA.light)})
	hn.set_meta("vp", vp)
	hn.set_meta("cam", cam)
	hn.set_meta("lamp", lamp)
	hn.set_meta("tvs", tvs)
	hn.set_meta("end", cam_end)
	tick(hn, 0.0)
	return hn


static var _tv_mesh := {}


static func _mesh(nm: String) -> Mesh:
	if _tv_mesh.is_empty():
		_tv_mesh[""] = null
		var ps: PackedScene = load(TVS_GLB) as PackedScene if ResourceLoader.exists(TVS_GLB) else null
		var sc: Node = ps.instantiate() if ps != null else null
		if sc != null:
			for c in sc.find_children("*", "MeshInstance3D", true, false):
				_tv_mesh[String(c.name)] = (c as MeshInstance3D).mesh
			sc.free()
	return _tv_mesh.get(nm)


static func _surf_aabb(me: Mesh, k: int) -> AABB:
	var vs: PackedVector3Array = me.surface_get_arrays(k)[Mesh.ARRAY_VERTEX]
	var b := AABB(vs[0], Vector3.ZERO)
	for v in vs:
		b = b.expand(v)
	return b


#  몸 재질 — 방과 같은 빛 단 · 바둑 디더. 바탕 빛(fill) · 빛 단 수는 주인공 · 엑스트라가 다르고, 엑스트라는
#  빛깔도 tone 배로 어둡다.
static func _body(col: Color, cf: Dictionary, gloss := 0.0) -> ShaderMaterial:
	var c: Color = col * float(cf.get("tone", 1.0))
	c.a = 1.0
	var m := Door3D._px(c, null, gloss)
	m.set_shader_parameter("fill", cf.fill)
	m.set_shader_parameter("bands", float(cf.bands))
	return m


static func _mats(cf: Dictionary) -> Dictionary:
	return {
		"wood": _body(Color("5e3a20"), cf), "metal": _body(Color("82878f"), cf, 20.0),
		"panel": _body(Color("24252c"), cf), "bezel": _body(Color("0e0e12"), cf),
		"knob": _body(Color("b4b6bc"), cf, 20.0), "grille": _body(Color("16161b"), cf),
		"trim": _body(Color("9a968c"), cf, 20.0), "gun": _body(Color("2c3038"), cf),
		"cap": _body(Color("d4d4cc"), cf, 20.0), "lcd": _body(Color("0c1414"), cf, 30.0),
		"led_r": Room3D._glow(Color("ff3b2e"), 1.6), "led_g": Room3D._glow(Color("3cff6a"), 1.6),
		"led_b": Room3D._glow(Color("3c7bff"), 1.6),
		"floor": _body(Color("34303a"), cf), "wall": _body(Color("24222e"), cf),
	}


static func _scr_mat(job: String, gb: AABB, i: int, cv: SubViewport, hero: bool) -> ShaderMaterial:
	if _scr_sh == null:
		_scr_sh = Shader.new()
		_scr_sh.code = SCR_SHADER
	var m := ShaderMaterial.new()
	m.shader = _scr_sh
	m.set_shader_parameter("mode", int(JOB[job.trim_suffix("0")][0]))
	m.set_shader_parameter("seed", float(i) * 0.37)
	if hero:
		m.set_shader_parameter("res", Vector2(CARD))
		m.set_shader_parameter("tex", cv.get_texture())
	else:
		var k: float = float(EXTRA.cells)
		m.set_shader_parameter("res", Vector2(maxf(roundf(gb.size.x * k), 10.0), maxf(roundf(gb.size.y * k), 8.0)))
		m.set_shader_parameter("dim", float(EXTRA.dim))
		m.set_shader_parameter("sat", float(EXTRA.sat))
	return m


#  방 — 바닥 · 뒷벽(엑스트라 재질 — 거의 안 보인다). 전선은 주인공 앞을 가로질러 뺐다.
static func _room(w: Node3D, mats: Dictionary) -> void:
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12.0, 12.0)
	fl.mesh = pm
	fl.material_override = mats.floor
	w.add_child(fl)
	var wl := MeshInstance3D.new()
	var wm := QuadMesh.new()
	wm.size = Vector2(12.0, 6.0)
	wl.mesh = wm
	wl.material_override = mats.wall
	wl.position = Vector3(0.0, 3.0, -1.2)
	w.add_child(wl)


#  위 등 — LAMP_SW 마다 켜짐/꺼짐을 뒤집는다(처음은 켜짐) · 마지막 뒤로 켜진 채.
static func _lamp(t: float) -> float:
	var u: float = t - float(T.lamp)
	if u < 0.0:
		return 0.0
	var on := false
	for s in LAMP_SW:
		if u >= float(s):
			on = not on
	return 1.0 if on else 0.0


#  TV 켜짐 — 깜박(0.08 켜짐 · 0.1 꺼짐) 뒤 0.45 초에 걸쳐 선다.
static func _pw(t: float, ton: float) -> float:
	var u: float = t - ton
	if u < 0.0:
		return 0.0
	if u < 0.08:
		return 0.5
	if u < 0.18:
		return 0.0
	return clampf((u - 0.18) / 0.45, 0.0, 1.0)


static func tick(hn: Node, t: float) -> void:
	hn.set_meta("t", t)
	var lamp := hn.get_meta("lamp") as SpotLight3D
	lamp.light_energy = 1.3 * _lamp(t)
	for tv in hn.get_meta("tvs"):
		var m := tv.m as ShaderMaterial
		var p: float = 1.0 if String(tv.job) == "snow0" else _pw(t, float(tv.on))
		var c: float = 0.0
		if tv.hero:
			#  주인공 — 켜지면 지지직 → 제작자 그림 · ON.off 부터 꺼진다
			m.set_shader_parameter("mode", 1 if t < float(tv.on) + float(T.snow) else 4)
			c = clampf((t - float(ON.off)) / float(T.off), 0.0, 1.0)
			m.set_shader_parameter("cl", c)
		m.set_shader_parameter("pw", p)
		m.set_shader_parameter("tm", t)
		var fl: float = 0.85 + 0.15 * sin(t * 29.0 + float(tv.i) * 1.7)
		(tv.l as OmniLight3D).light_energy = float(tv.e) * minf(p * 1.6, 1.0) * fl * (1.0 - c)
	var cam := hn.get_meta("cam") as Camera3D
	var ce: Dictionary = hn.get_meta("end")
	if not ce.is_empty():
		var u: float = clampf((t - float(T.push0)) / (float(T.push1) - float(T.push0)), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		cam.look_at_from_position((CAM.at as Vector3).lerp(ce.at, u), (CAM.look as Vector3).lerp(ce.look, u))


static func draw(hn: Node, ci: CanvasItem, dest: Rect2) -> void:
	var vp := hn.get_meta("vp") as SubViewport
	ci.draw_texture_rect(vp.get_texture(), dest, false)
