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
#  어둡고(EXTRA) 화면은 흐리고 덜 붉다. 주인공은 게임 TV 다 — 크레딧 뒤에 깜박이며 켜져 **게임의 인트로를
#  그대로 튼다**(「크로즈업 되기전에 TV가 깜박이고 좀 재생되는 중에 클로즈업 되야 좀 몰입하는 느낌이 나지
#  않을까?」 · 인트로 첫 그림을 보냈다). 무대 · 층은 도트 화판 **밖**(game.gd screen_host)에 서고, 주인공 유리는
#  화판 그림(게임이 그 밑에서 그리는 인트로)을 유리 높이에 꽉 채우고 양옆을 잘라 비춘다(처음엔 16:9 를 통째로
#  넣어 위아래 띠가 섰다 — 「해상도가 안 맞는데?」). 클로즈업은 TV 속으로 들어간다(「클로즈업이 아예 TV속으로
#  들어가는것 같이」) — 카메라가 유리를 지나 테가 화면 밖으로 빠질 때까지 밀고 들고, 그동안 유리 속 그림은 유리를
#  따라 커지던 것에서 화면에 박힌 게임 그림(SCREEN_UV — portal)으로 옮겨 간다. 끝에는 층 안에 화판 그림을 그대로
#  깔아(Feed) 층을 걷어도 같은 그림이다 — 그때(handoff) 게임 필터가 켜지고 층이 걷힌다.
#  「제작 김건의」는 왼쪽 빨간 휴대용 TV(maker — 엑스트라지만 흐리지 않다)에 뜬다
#  (「이름은 붉은색으로 표시한곳에 표시해도 되잖아」 → 「이름 표시 TV 위치도 왼쪽으로」 · 지지직 → 그림).
#  그 그림은 옛 방송 끝 자막이다 — 검은 바탕 · 크림빛 글 · 빛깔 번짐 · 낟알 · 가끔 튀는 줄 · 흐르는 밝은 띠
#  (「색이 무슨 유아용 게임도 아니고 좀 레트로한 감성 살린 화면으로」 — 주황 띠 바탕을 걷었다).
#  카메라는 처음부터 주인공 **화면** 한가운데를 곧게 본다(「tv화면을 진짜 중앙에 배치해 지금 클로즈업 될때
#  살짝 왼쪽으로 가는게 있잖아」 — 화면이 몸 왼쪽에 있어 몸 한가운데를 보던 카메라가 다가가며 옆으로 흘렀다).
#  빛 · 그늘 — 「방을 진짜 어둡게 하라고 tv 빛 이외에는 빛도 없도록」 · 「이름 표시 tv는 메인 TV보다 뒤에 있는거
#  아니야? 근데 왜 메인 TV 앞면까지 빛에 째이는거야」(사용자). 방에는 등 · 환경광이 없다 — 빛은 켜진 화면뿐이다.
#  화면 빛은 유리 바로 앞에서 앞쪽 반구로만 나가는 원뿔(SCR_LIT)이라 뒤에 선 TV 는 주인공 앞면을 못 비추고
#  옆면 · 바닥만 물들인다(처음엔 화면 앞 35cm 의 점 빛이라 뒤 TV 빛이 주인공 앞면에 닿았다). 「불이 깜박깜박」은
#  TV 들이 차례로 깜박이며 켜지는 것이다. 몸은 제목 문(Door3D)과 같은 결 그림 재질(TRI_SHADER — UV 없는
#  Blender 몸에 앞 · 옆 · 위로 결을 비춘다 · 나무 결은 결 대비 · 채도를 누른다) · 필름 톤 · 둘레 비네트.
#  TV 는 scripts/tools/blender/tvs.py 가 짓는다(assets/models/tvs.glb). 무대는 논리 화면 크기의 SubViewport
#  — 게임 도트와 같은 격자에 그려 가장 가까운 점으로 붙인다. 화면은 SCR_SHADER(화면 도트 칸 · 주사선).
#  화면은 tvs.py 에서 귀만 둥근 네모다(「tv의 테두리가 너무 둥글지 않아?」).
#  흐름 — 어둠(구석 지지직 한 대) → 둘레 TV 가 차례로 깜박이며 흐리게 켜진다 → 크레딧 TV 가 켜진다
#  (지지직 → 제작자) → 주인공이 깜박이며 켜져 인트로를 튼다 → 카메라가 곧게 다가간다 → 유리 속 그림이 화면을
#  채우면 층이 걷히고 인트로가 이어진다.
#  API — make(game, outer) · tick(h, t) · length() · handoff() · feed_at() · ON(소리 때 — hero 는 켜짐 소리).

const Door3D = preload("res://scripts/door3d.gd")
const Room3D = preload("res://scripts/room3d.gd")
const TVS_GLB := "res://assets/models/tvs.glb"
const LEN := 6.1
#  켜지는 때 — tvs 둘레 TV(차례로) · maker 크레딧 TV · hero 주인공(이때 인트로 시계가 출발한다)
const ON := {"tvs": 1.0, "maker": 1.75, "hero": 2.55}
#  stag 둘레 TV 가 차례로 켜지는 사이 · snow 크레딧 TV 가 켜진 뒤 지지직 동안 · push0~push1 다가가는 동안
const T := {"stag": 0.07, "snow": 0.45, "push0": 3.55, "push1": 5.65}
#  어둠에서 떠오르는 시간 · 끝에 층이 걷히는 시간(LEN 앞 out 초부터 — handoff)
const FADE := {"in": 0.9, "out": 0.45}
#  층 — 게임 필터(CRT 100 · VHS 98 · 도트 97 · 반전 96) 밑
const LAYER := 90
const FONT_BIG := "res://fonts/Paperlogy-7Bold.ttf"
const FONT_SM := "res://fonts/Galmuri9.ttf"
#  제작자 그림 — 크레딧 TV 유리가 첫 장면에서 차지하는 논리 px 언저리(1 칸 = 1 px)
const CARD := Vector2i(120, 108)
#  카메라 — 주인공 화면 한가운데에서 앞으로 dist(m) · 세로 화각(주인공 폭이 화면 폭의 여섯 몫 언저리)
const CAM := {"dist": 1.42, "fov": 34.0}
#  빛 — glow 화면 번짐 세기 · 문턱 · vig 둘레 비네트 짙기(가장자리 알파)
const LIT := {"glow": 0.45, "glow_thr": 0.9, "vig": 0.55}
#  화면 빛(SCR_LIT) — 유리 앞 at(m)에서 앞으로 원뿔 ang(도) · 닿는 거리 range · 세기는 MAKER · EXTRA 의 light
const SCR_LIT := {"at": 0.08, "ang": 85.0, "range": 1.3, "att": 1.0}
#  재질 — den 결 그림 1 텍셀이 첫 장면의 주인공 앞면에서 논리 1px(1m 당 텍셀) · walnut 주인공 몸(짙은 호두
#  나무) · wood 엑스트라 나무 장
const MAT := {"den": 450.0, "walnut": Color("3a2414"), "wood": Color("4a2e18")}
#  MAKER — 크레딧 TV 의 화면 빛 세기(주인공 왼쪽 옆면 · 바닥을 물들인다).
const MAKER := {"light": 1.3}
#  주인공 화면 빛 — light 앞으로 나가는 원뿔 세기 · rim 유리 둘레(테 · 검은 판 안쪽)를 비추는 작은 빛 세기 ·
#  rim_r 그 닿는 거리 · dive 끝 거리 — 유리 폭이 화면 폭을 꼭 채우는 거리의 몫(1 밑이면 유리를 지나 테가 화면
#  밖으로 빠진다) · portal 다가가는 몫(0~1)의 이 구간에서 유리 속 그림이 화면에 박힌 그림으로 옮겨 간다 ·
#  flat 이 구간에서 층 안에 화판 그림을 그대로 깐다(필름 톤 · 번짐이 낀 무대 그림과 게임 그림의 톤 차를 잇는다)
const HERO := {"light": 1.1, "rim": 0.5, "rim_r": 0.32, "dive": 0.78, "portal": [0.45, 0.95], "flat": [0.8, 1.0]}
#  엑스트라 — 점 빛 세기 · 몸 빛깔 배수 · 화면 밝기 · 채도 · 화면 도트(1m 당 칸) · 화면 색 단 수
const EXTRA := {"light": 0.7, "tone": 0.42, "dim": 0.28, "sat": 0.6, "cells": 110.0, "lv": 8.0}
#  화면 장면 — 번호(SCR_SHADER mode) · 앞에 둔 점 빛 빛깔. game 은 주인공(지지직 1 → 화판 그림 9) · maker 는
#  크레딧(지지직 1 → 제작자 그림 4).
const JOB := {
	"game": [9, Color(1.0, 0.80, 0.60)], "maker": [4, Color(1.0, 0.90, 0.74)],
	"snow": [1, Color(0.62, 0.68, 0.80)], "bars": [2, Color(0.72, 0.70, 0.60)],
	"blue": [3, Color(0.25, 0.40, 1.0)], "wave": [5, Color(0.35, 1.0, 0.50)],
	"ball": [6, Color(0.60, 0.62, 0.70)], "sunset": [7, Color(1.0, 0.50, 0.38)], "board": [8, Color(0.85, 0.72, 0.60)],
}
const PLASTIC := {"red": Color("a83c30"), "teal": Color("2f8a84"), "graph": Color("2b2f3c"), "slate": Color("3d4456"),
		"": Color("8c2924")}
#  더미 — [꼴, x, 앞뒤 z, 돌림(도), 기울기(도), 플라스틱 빛깔, 장면]. 밑에서 위로 — 그 폭 밑의 가장 높은 윗면에
#  얹는다. 기울면 낮은 귀가 윗면에 닿게 든다. 주인공(TvHero · 장면 game)과 데크는 앞으로 · 엑스트라는 뒤로
#  물린다. snow0 은 처음부터 켜진 구석 지지직(어둠 속 첫 빛) · maker 는 왼쪽 빨간 휴대용 TV.
const PILE := [
	["TvConsole", -1.02, -0.10, 5.0, 0.0, "", "bars"],
	["TvConsole", 0.0, -0.02, 0.0, 0.0, "", "sunset"],
	["TvWood", 0.98, -0.10, -6.0, 0.0, "", "snow"],
	["Speaker", 1.50, -0.12, -8.0, 0.0, "", ""],
	["Speaker", -1.55, -0.12, 8.0, 0.0, "", ""],
	["Deck", 0.0, 0.04, 0.0, 0.0, "", ""],
	["TvHero", 0.0, 0.04, 0.0, 0.0, "", "game"],
	["TvMon", -0.84, -0.12, 8.0, -3.0, "graph", "snow0"],
	["Speaker", 0.68, -0.10, -6.0, 0.0, "", ""],
	["TvPort", -0.69, -0.10, 9.0, 3.0, "red", "maker"],
	["TvPort", 0.73, -0.14, -7.0, -4.0, "teal", "ball"],
	["TvBox", -0.28, -0.16, 6.0, -4.0, "", "wave"],
	["TvMon", 0.24, -0.18, -5.0, 3.0, "slate", "board"],
	["TvPort", -1.28, -0.16, 9.0, 3.0, "teal", "snow"],
	["TvMon", 1.20, -0.16, -9.0, -4.0, "graph", "bars"],
	["TvBox", -0.79, -0.16, 12.0, -5.0, "", "blue"],
]
const HERO_KINDS := ["TvHero", "Deck"]

#  화면 — UV(0,0 왼 위) 를 res 칸으로 끊는다. pw 켜짐(0~1 · 가운데 줄이 위아래로 벌어지고 처음엔 하얗다) ·
#  dim · sat 엑스트라의 밝기 · 채도. 꺼진 유리는 위가 옅은 짙은 회색 · 귀가 어둡고 · 왼 위에 비스듬한 반짝 띠
#  둘 · amb 켜진 TV 몫을 따라 옅어진다(다 꺼진 어둠에서는 유리도 거의 안 보인다).
#  lv 가 있으면(엑스트라) 색을 그 단으로 끊는다 — 바둑 점은 안 얹는다(제목에 없는 결).
#  mode 9(주인공) — tex(게임 화판)를 유리 높이에 꽉 채우고 양옆을 잘라(cw 보이는 폭 몫) 칸 없이 비춘다 ·
#  feed 화판 크기(주사선 줄). mode 4(크레딧) — 빛깔 번짐(빨강만 한 칸 옆에서 — r · b 둘 다 밀면 작은 글이
#  무지개가 됐다) · 옅은 낟알(밝은 쪽만 — 검은 바탕이 회색 모래로 떴다) · 가끔 튀는 줄 · 흐르는 밝은 띠(옛 테이프).
const SCR_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform int mode = 0;
uniform float pw = 0.0;
uniform float tm = 0.0;
uniform float seed = 0.0;
uniform float dim = 1.0;
uniform float sat = 1.0;
uniform float lv = 0.0;
uniform float amb = 1.0;
uniform vec2 res = vec2(40.0, 30.0);
uniform float cw = 0.6;
uniform float portal = 0.0;
uniform vec2 feed = vec2(640.0, 360.0);
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;

float hs(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed * 17.0) * 43758.5453);
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
		float row = floor(q.y * res.y);
		float tk = floor(tm * 12.0);
		vec2 j = vec2(0.0);
		if (hs(vec2(row, tk)) > 0.965) {
			j.x = (hs(vec2(row + 3.0, tk)) - 0.5) * 0.05;
		}
		float ca = 1.0 / res.x;
		vec3 c = texture(tex, q + j).rgb;
		c.r = texture(tex, q + j + vec2(ca, 0.0)).r;
		c += vec3(max(hs(q * res + tk) - 0.6, 0.0) * 0.06);
		c += vec3(0.03, 0.027, 0.024) * (1.0 - smoothstep(0.0, 0.06, abs(fract(q.y - tm * 0.18) - 0.5)));
		return c;
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
	vec3 off = mix(vec3(0.05, 0.056, 0.07), vec3(0.016, 0.018, 0.024), smoothstep(0.0, 0.8, UV.y));
	off *= (1.0 - 1.6 * dot(UV - 0.5, UV - 0.5)) * amb;
	float gd = UV.x * 0.85 + UV.y;
	if ((abs(gd - 0.42) < 0.045 || abs(gd - 0.56) < 0.012) && UV.x < 0.5) {
		off += vec3(0.03, 0.034, 0.042) * amb * 2.5;
	}
	vec3 c = off;
	if (pw > 0.0 && mode > 0) {
		vec3 s;
		if (mode == 9) {
			q = UV;
			vec2 cu = mix(vec2((UV.x - 0.5) * cw + 0.5, UV.y), SCREEN_UV, portal);
			s = texture(tex, cu).rgb * mix(1.08, 1.0, portal);
			if (mod(floor(cu.y * feed.y), 2.0) > 0.5) {
				s *= mix(0.86, 1.0, portal);
			}
		} else {
			s = scene(q);
			if (mod(cell.y, 2.0) > 0.5) {
				s *= 0.78;
			}
		}
		s = mix(s, vec3(0.9, 0.95, 1.0), (1.0 - smoothstep(0.0, 0.35, pw)) * 0.85);
		s *= 1.0 - (mode == 9 ? 0.5 * (1.0 - portal) : 1.2) * dot(UV - 0.5, UV - 0.5);
		s = mix(vec3(dot(s, vec3(0.299, 0.587, 0.114))), s, sat) * dim;
		float open = max(smoothstep(0.0, 0.55, pw), 1.5 / res.y);
		if (abs(q.y - 0.5) * 2.0 < open) {
			c = s;
		}
	}
	if (lv > 0.0) {
		c = floor(c * lv + 0.5) / lv;
	}
	ALBEDO = c;
}
"""
static var _scr_sh: Shader = null

#  몸 — 결 그림을 앞 · 옆 · 위(몸 좌표에서 가장 큰 노멀 축)로 비춘다(Blender 몸은 UV 가 화면 유리에만 있다).
#  나무는 제목 문(Door3D.LIT_SHADER)과 같이 결 대비(grain) · 채도(sat)를 바탕(base) 쪽으로 누른다 —
#  안 누르면 결이 주황 줄로 서서 램프 밑에서 지글거렸다(「긁힌 라미네이트」). 빛은 엔진 빛 그대로(단 없음).
const TRI_SHADER := """
shader_type spatial;
uniform sampler2D alb : source_color, filter_nearest, repeat_enable;
uniform bool use_tex = false;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 base : source_color = vec3(0.5);
uniform float grain = 1.0;
uniform float sat = 1.0;
uniform float den = 450.0;
uniform vec2 tsz = vec2(256.0);
uniform float rough = 0.8;
uniform float spec = 0.3;
uniform float metal = 0.0;
varying vec3 op;
varying vec3 on;

void vertex() {
	op = VERTEX;
	on = NORMAL;
}

void fragment() {
	vec3 c = vec3(1.0);
	if (use_tex) {
		vec3 a = abs(on);
		vec2 uv = (a.z >= a.x && a.z >= a.y) ? op.xy : ((a.x >= a.y) ? op.zy : op.xz);
		c = texture(alb, vec2(uv.x, -uv.y) * den / tsz).rgb;
		vec3 lw = vec3(0.2126, 0.7152, 0.0722);
		float lb = max(dot(base, lw), 0.0001);
		float dd = dot(c, lw) / lb - 1.0;
		float k = mix(grain, 1.0, smoothstep(0.40, 0.60, -dd));
		c = base + (c - base) * k;
		c = mix(vec3(dot(c, lw)), c, sat);
	}
	ALBEDO = c * tint;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = metal;
}
"""
static var _tri_sh: Shader = null
static var _wood_im := {}       # 바탕 빛깔 → 결 그림(처음 부를 때 굽는다)


#  제작자 그림 — 옛 방송 끝 자막. 검은 남빛 바탕(위가 조금 옅다) · 「제작」 양옆에 가는 줄 · 크림빛 「김건의」에
#  호박빛 번짐(겹쳐 찍은 옅은 테) · 밑에 가는 줄 하나.
class Card extends Node2D:
	var big: Font
	var sm: Font

	func _draw() -> void:
		var s := Vector2(CARD)
		for y in int(s.y):
			var k: float = float(y) / s.y
			draw_rect(Rect2(0.0, float(y), s.x, 1.0), Color("10121a").lerp(Color("050508"), k))
		var cream := Color("f1e4c4")
		var dim := Color(cream, 0.55)
		draw_rect(Rect2(16.0, 34.0, 24.0, 1.0), dim)
		draw_rect(Rect2(s.x - 40.0, 34.0, 24.0, 1.0), dim)
		_txt(sm, 40.0, "제작", 18, Color(cream, 0.85), 0)
		_txt(big, 80.0, "김건의", 30, cream, 2)
		draw_rect(Rect2(34.0, 90.0, s.x - 68.0, 1.0), Color(cream, 0.35))

	func _txt(f: Font, y: float, s: String, sz: int, col: Color, k: int) -> void:
		if f == null:
			return
		var glow := Color(1.0, 0.62, 0.25, 0.16)
		for dx in range(-k, k + 1):
			for dy in range(-k, k + 1):
				if dx != 0 or dy != 0:
					draw_string(f, Vector2(dx, y + dy), s, HORIZONTAL_ALIGNMENT_CENTER, float(CARD.x), sz, glow)
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


#  game — 인트로를 그리는 게임(그 화판 그림이 주인공 유리에 뜬다) · outer — 화판 밖(game.screen_host · box 를
#  가진 boot). 무대 · 층은 outer 밑에 선다 — 화판 안에 두면 화판 그림이 제 그림을 비춘다.
static func make(game: Node, outer: Node) -> Node:
	var hn := Node.new()
	hn.name = "Prologue"
	outer.add_child(hn)
	var sz: Vector2 = game.get_viewport().get_visible_rect().size
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
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = float(LIT.glow)
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = float(LIT.glow_thr)
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for lvl in 7:
		env.set_glow_level(lvl, 1.0 if lvl < 3 else 0.0)
	we.environment = env
	w.add_child(we)
	var cam := Camera3D.new()
	cam.fov = float(CAM.fov)
	w.add_child(cam)

	var hm := _mats(true)
	var xm := _mats(false)
	var dm := hm.duplicate()
	dm["gun"] = _lit(Color("2c3038"), null, 0.45, 0.45, 0.3)
	var tvs := []
	var tops := []      # [x0, x1, 윗면] — 얹힌 것들
	var cam_end := {}
	var cam_start := {}
	var feed: Texture2D = game.get_viewport().get_texture()
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
		var ms: Dictionary = (dm if String(e[0]) == "Deck" else hm) if hero else xm
		var gm: ShaderMaterial = null
		var gb := AABB()
		for k in me.get_surface_count():
			var sm: Material = me.surface_get_material(k)
			var key: String = sm.resource_name if sm != null else ""
			if key == "glass":
				gb = _surf_aabb(me, k)
				gm = _scr_mat(job, gb, i, cv, hero, feed, sz)
				mi.set_surface_override_material(k, gm)
			elif key == "plastic":
				var pc: Color = PLASTIC.get(String(e[5]), PLASTIC[""])
				mi.set_surface_override_material(k, _lit(pc * float(EXTRA.tone), null, 0.45, 0.5))
			elif ms.has(key):
				mi.set_surface_override_material(k, ms[key])
		if gm == null:
			continue
		var g: Vector3 = mi.transform * gb.get_center()
		var n: Vector3 = mi.transform.basis * Vector3(0.0, 0.0, 1.0)
		if hero:
			#  끝 — 유리 꼭지(가장 나온 가운데)에서 유리 폭이 화면 폭을 꼭 채우는 거리의 dive 몫 — 유리를 지나
			#  테가 화면 밖으로 빠진다(TV 속으로 든다).
			var ar: float = sz.x / maxf(sz.y, 1.0)
			var apex: Vector3 = g + n * gb.size.z * 0.5
			var de: float = gb.size.x * 0.5 / (tan(deg_to_rad(float(CAM.fov)) * 0.5) * ar) * float(HERO.dive)
			cam_end = {"look": apex, "at": apex + n * de}
			cam_start = {"look": g, "at": g + n * float(CAM.dist)}
		else:
			#  빨간 대기등 — 화면 오른쪽 아래 테 밖
			var led := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.014, 0.014, 0.01)
			led.mesh = lm
			led.material_override = Room3D._glow(Color("ff3b2e"), 1.2)
			led.position = Vector3(gb.end.x - 0.02, gb.position.y - 0.012, 0.004)
			mi.add_child(led)
		var ton: float = 0.0 if job == "snow0" else (float(ON.maker) if job == "maker" else
				(float(ON.hero) if hero else float(ON.tvs) + float(T.stag) * float(tvs.size())))
		var rl: OmniLight3D = null
		if hero:
			#  유리 둘레 — 켜진 화면이 제 테 · 검은 판 안쪽을 비춘다(남의 앞면은 아니다)
			rl = OmniLight3D.new()
			rl.light_color = JOB.game[1]
			rl.omni_range = float(HERO.rim_r)
			rl.omni_attenuation = 1.6
			rl.light_energy = 0.0
			rl.position = g + n * (gb.size.z * 0.5 + 0.02)
			w.add_child(rl)
		#  화면 빛 — 유리 바로 앞에서 앞쪽으로만(뒤 · 옆 뒤로는 안 샌다)
		var lt := SpotLight3D.new()
		lt.light_color = JOB[job.trim_suffix("0")][1]
		lt.spot_angle = float(SCR_LIT.ang)
		lt.spot_range = float(SCR_LIT.range)
		lt.spot_attenuation = float(SCR_LIT.att)
		lt.light_energy = 0.0
		w.add_child(lt)
		var at: Vector3 = g + n * (gb.size.z * 0.5 + float(SCR_LIT.at))
		lt.look_at_from_position(at, at + n)
		tvs.append({"m": gm, "l": lt, "r": rl, "on": ton, "job": job, "i": i, "hero": hero,
				"e": float(HERO.light) if hero else (float(MAKER.light) if job == "maker" else float(EXTRA.light))})
	hn.set_meta("vp", vp)
	hn.set_meta("cam", cam)
	hn.set_meta("tvs", tvs)
	hn.set_meta("end", cam_end)
	hn.set_meta("start", cam_start)
	if not cam_start.is_empty():
		cam.look_at_from_position(cam_start.at, cam_start.look)
	_room(w, xm)
	var vg := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	gr.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, float(LIT.vig))])
	vg.gradient = gr
	vg.fill = GradientTexture2D.FILL_RADIAL
	vg.fill_from = Vector2(0.5, 0.5)
	vg.fill_to = Vector2(1.0, 0.5)
	vg.width = 320
	vg.height = 180
	#  층 — 무대 · 비네트 · 어둠 막. 자리는 tick 이 화판(outer.box)에 맞춘다.
	var ly := CanvasLayer.new()
	ly.name = "PrologueLayer"
	ly.layer = LAYER
	hn.add_child(ly)
	var root := Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ly.add_child(root)
	var under := ColorRect.new()
	under.color = Color.BLACK
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(under)
	for pr in [["Stage", vp.get_texture()], ["Vig", vg], ["Feed", feed]]:
		var tr := TextureRect.new()
		tr.name = String(pr[0])
		tr.texture = pr[1]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(tr)
	var fade := ColorRect.new()
	fade.name = "Fade"
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fade)
	(root.get_node("Feed") as CanvasItem).modulate.a = 0.0
	hn.set_meta("outer", outer)
	hn.set_meta("root", root)
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


#  몸 재질 — TRI_SHADER. tex 가 있으면 결 그림(나무 — wood 가 바탕이면 결 · 채도를 누른다) · 없으면 맨 색.
static func _lit(col: Color, tex: Image = null, rough := 0.8, spec := 0.3, metal := 0.0,
		wood := Color(0, 0, 0, 0)) -> ShaderMaterial:
	if _tri_sh == null:
		_tri_sh = Shader.new()
		_tri_sh.code = TRI_SHADER
	var m := ShaderMaterial.new()
	m.shader = _tri_sh
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("spec", spec)
	m.set_shader_parameter("metal", metal)
	if tex != null:
		m.set_shader_parameter("alb", ImageTexture.create_from_image(tex))
		m.set_shader_parameter("use_tex", true)
		m.set_shader_parameter("tsz", Vector2(tex.get_size()))
		m.set_shader_parameter("den", float(MAT.den))
	if wood.a > 0.0:
		m.set_shader_parameter("base", wood)
		m.set_shader_parameter("grain", float(Door3D.LOOK.grain))
		m.set_shader_parameter("sat", float(Door3D.LOOK.sat))
	return m


#  나무 결 그림 — 제목 문 판자(Room3D._plank)를 판 한 장 높이로(이음이 드물다 · 못 없음). 바탕 빛깔마다 한 번.
static func _wood(base: Color) -> Image:
	var key := base.to_html()
	if not _wood_im.has(key):
		_wood_im[key] = Room3D._plank(256, 256, base, 2026101 + _wood_im.size(), 200, 256, false)[0]
	return _wood_im[key]


#  주인공(hero) · 엑스트라 재질 — 엑스트라는 빛깔을 tone 배로 어둡게. 나무는 결 · 니스(반짝은 조금),
#  쇠는 매끈하게.
static func _mats(hero: bool) -> Dictionary:
	var k: float = 1.0 if hero else float(EXTRA.tone)
	var wb: Color = MAT.walnut if hero else MAT.wood
	var wd := _lit(Color(k, k, k), _wood(wb), 0.55, 0.35, 0.0, wb)
	return {
		"wood": wd, "gun": wd,
		"metal": _lit(Color("82878f") * k, null, 0.35, 0.5, 0.5),
		"panel": _lit(Color("24252c") * k, null, 0.6, 0.3),
		"bezel": _lit(Color("060608") * k, null, 0.7, 0.15),
		"knob": _lit(Color("c8cacf") * k, null, 0.25, 0.6, 0.6),
		"grille": _lit(Color("16161b") * k, null, 0.9, 0.1),
		"trim": _lit(Color("9a968c") * k, null, 0.35, 0.5, 0.5),
		"cap": _lit(Color("d4d4cc") * k, null, 0.4, 0.4),
		"lcd": _lit(Color("0c1414"), null, 0.15, 0.6),
		"led_r": Room3D._glow(Color("ff3b2e"), 1.6), "led_g": Room3D._glow(Color("3cff6a"), 1.6),
		"led_b": Room3D._glow(Color("3c7bff"), 1.6),
		"floor": _lit(Color(0.5, 0.5, 0.5), _wood(Color("2a1a10")), 0.7, 0.2, 0.0, Color("2a1a10")),
	}


static func _scr_mat(job: String, gb: AABB, i: int, cv: SubViewport, hero: bool, feed: Texture2D,
		sz: Vector2) -> ShaderMaterial:
	if _scr_sh == null:
		_scr_sh = Shader.new()
		_scr_sh.code = SCR_SHADER
	var m := ShaderMaterial.new()
	m.shader = _scr_sh
	m.set_shader_parameter("mode", int(JOB[job.trim_suffix("0")][0]))
	m.set_shader_parameter("seed", float(i) * 0.37)
	if hero:
		m.set_shader_parameter("res", sz)
		m.set_shader_parameter("tex", feed)
		m.set_shader_parameter("feed", sz)
		m.set_shader_parameter("cw", (gb.size.x / gb.size.y) / (sz.x / maxf(sz.y, 1.0)))
	elif job == "maker":
		m.set_shader_parameter("res", Vector2(CARD))
		m.set_shader_parameter("tex", cv.get_texture())
	else:
		var k: float = float(EXTRA.cells)
		m.set_shader_parameter("res", Vector2(maxf(roundf(gb.size.x * k), 10.0), maxf(roundf(gb.size.y * k), 8.0)))
		m.set_shader_parameter("dim", float(EXTRA.dim))
		m.set_shader_parameter("sat", float(EXTRA.sat))
		m.set_shader_parameter("lv", float(EXTRA.lv))
	return m


#  방 — 나무 바닥(화면 빛이 앞으로 나가 바닥에 고인다). 뒤 벽은 빛이 안 닿아 두지 않는다.
static func _room(w: Node3D, mats: Dictionary) -> void:
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12.0, 12.0)
	fl.mesh = pm
	fl.material_override = mats.floor
	w.add_child(fl)


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
	var lit := 0.0
	var nx := 0
	for tv in hn.get_meta("tvs"):
		var m := tv.m as ShaderMaterial
		m.set_shader_parameter("tm", t)
		var p: float = 1.0 if String(tv.job) == "snow0" else _pw(t, float(tv.on))
		if String(tv.job) == "maker":
			m.set_shader_parameter("mode", 1 if t < float(tv.on) + float(T.snow) else 4)
		if tv.hero:
			#  주인공 — 깜박이며 켜지면 곧장 화판 그림(첫 그림이 어둠이라 지지직을 안 거친다)
			(tv.r as OmniLight3D).light_energy = float(HERO.rim) * minf(p * 1.6, 1.0)
		else:
			lit += minf(p * 1.6, 1.0)
			nx += 1
		m.set_shader_parameter("pw", p)
		var fl: float = 0.85 + 0.15 * sin(t * 29.0 + float(tv.i) * 1.7)
		(tv.l as SpotLight3D).light_energy = float(tv.e) * minf(p * 1.6, 1.0) * fl
	_layer(hn, t)
	#  꺼진 유리(주인공 · 아직 안 켜진 엑스트라)는 켜진 TV 몫만큼만 비친다
	for tv in hn.get_meta("tvs"):
		(tv.m as ShaderMaterial).set_shader_parameter("amb", 0.04 + 0.3 * lit / float(maxi(nx, 1)))
	var cam := hn.get_meta("cam") as Camera3D
	var ce: Dictionary = hn.get_meta("end")
	var cs: Dictionary = hn.get_meta("start")
	if not ce.is_empty():
		var u: float = clampf((t - float(T.push0)) / (float(T.push1) - float(T.push0)), 0.0, 1.0)
		var e: float = u * u * (3.0 - 2.0 * u)
		cam.look_at_from_position((cs.at as Vector3).lerp(ce.at, e), (cs.look as Vector3).lerp(ce.look, e))
		var pr: Array = HERO.portal
		var fr: Array = HERO.flat
		var po: float = smoothstep(float(pr[0]), float(pr[1]), u)
		for tv in hn.get_meta("tvs"):
			if tv.hero:
				(tv.m as ShaderMaterial).set_shader_parameter("portal", po)
		var root := hn.get_meta("root") as Control
		(root.get_node("Vig") as CanvasItem).modulate.a = 1.0 - po
		(root.get_node("Feed") as CanvasItem).modulate.a = smoothstep(float(fr[0]), float(fr[1]), u)


#  층 — 화판(outer.box) 자리에 맞추고 · 처음 FADE.in 어둠에서 떠오르고 · handoff 뒤 FADE.out 동안 걷힌다.
static func _layer(hn: Node, t: float) -> void:
	var root := hn.get_meta("root") as Control
	var outer: Node = hn.get_meta("outer")
	var box: Control = outer.get("box") as Control if outer != null else null
	if box != null:
		root.position = box.position
		root.size = box.size
	(root.get_node("Fade") as ColorRect).color.a = 1.0 - clampf(t / float(FADE["in"]), 0.0, 1.0)
	root.modulate.a = 1.0 - clampf((t - handoff()) / float(FADE.out), 0.0, 1.0)


#  층이 걷히기 시작하는 때 — 게임 필터가 이때 켜진다(game.gd _plg_cover).
static func handoff() -> float:
	return LEN - float(FADE.out)


#  주인공이 화판 그림을 틀기 시작하는 때 — 게임의 인트로 시계가 이때 출발한다.
static func feed_at() -> float:
	return float(ON.hero)
