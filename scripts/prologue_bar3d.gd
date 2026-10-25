extends RefCounted
# ══════════════════════════════════════════════════════════
#  다른 여는 장면 — 바에 앉아 눈을 뜬다 (2026-10-25)
# ──────────────────────────────────────────────────────────
#  「시작하면 눈을 뜨고 주변을 살펴보는데 바에 앉아있는거지 … 외국 바에 CCTV같이 달린 TV 작은거 … 그걸 보다가
#  빨려 들어가는거지」 · 판지(outputs/prologue/bar_board)를 보고 「이대로 만들기는 하는데 좀 퀄리티 업을 많이 해야
#  될거 같은데? 지금은 그냥 뭐 3류 3D게임 같거든? 모델링은 최대한 하고 좀 이팩트같은걸로 가려야 될거 같은데?」(사용자).
#  테이프 프롤로그(prologue3d.gd · Plg)는 그대로 두고 같은 API(make · tick · cues · handoff · feed_at · length)로 선다 —
#  game.gd 의 시계 · 누름(첫 누름 빨리 감기 · 둘째 끝) · 필터 덮개 · 넘김이 그대로 돈다(PLGP.kind · plg_mod).
#  흐름(약 11 초 · 글 · 말 없음):
#   1 0~1.5 검다 — 먹먹한 방 소리(냉장고 · 먼 잔 한 번). 1.2 초에 감은 눈꺼풀 너머 빛이 한 단 든다(검붉은 판).
#   2-1 1.5~2.2 눈꺼풀이 반쯤 — 흐린 도트(덩어리 4 · 8px) · 뺨을 카운터에 댄 낮은 눈 · 코앞에 맥주잔.
#   2-2 2.2~3 한 번 더 깜박 → 또렷 · 받침 위 반 남은 잔. TV 는 아직 안 보인다 — 찬 빛이 단으로 깜박이며 잔 테 · 카운터
#       끝을 짚는다(화면 밖 TV 를 먼저 알린다).
#   3 3~5 고개를 들며 왼쪽 — 가운데 펜던트 밑에서 상인의 손이 잔을 닦는다(가슴에서 잘린다 · 얼굴은 늘 밖 · 어둠).
#   4 5~6.5 오른쪽 — 빈 홀 · 벽의 다트 장 · 테이블에 남은 빈 잔 둘 · 다트(방금 누가 있었다).
#   5 6.5~8 위 — 바 뒤 천장에 매단 작은 브라운관(관 · 멍에 · 쟁반). 지지직 사이로 게임 인트로 그림이 단으로 비친다.
#   6 8~10.2 눈 깜박임으로 한 번 다가가 끊고(30%) · 화각이 좁아지며 조금 다가간다. 방 빛이 한 등씩 꺼진다(가운데
#     펜던트가 마지막 — 상인의 손이 마지막에 사라진다) · 방 소리가 먹먹해지고 TV 소리만 남는다.
#   7 10.2~ TV 유리 속으로 든다(테이프 프롤로그의 다이브 · 유리 속 그림이 화면에 박힌 게임 그림으로 · Plg SCR_SHADER
#     mode 9 · portal) → 인트로 → 제목 문.
#  빛 · 효과로 가린다(조사 T01~T14): 채움빛을 걷고 찬 바탕 한 단만(밤 · 주인공만 빛) · 펜던트 · TV 의 단단한 그림자 ·
#  니스 반짝 · 빛무리 · 전구 · 도트 잔 그림 · 거울 비침 걷기 · 선반 병은 뒤에서 · 채도를 누른다 · 깊이 덩어리 흐림(초점은
#  깜박임 · 눈길에 뛴다 — 흐르지 않는다) · TV 빛줄기에만 옅은 안개 · 눈길은 눈이 먼저 튀고 고개가 따라 살짝 넘쳤다 서고
#  멈춤은 완전히 멈춘다 · 빛은 이어 붙이지 않고 단으로 바뀐다 · 눈꺼풀은 렌즈 꼴(가운데가 넓다 · 위 눈꺼풀이 거의 다
#  움직인다 · 단단한 테).
#  세트는 제목 문 안의 술집(Door3D._inside)을 그대로 짓고 이 장면에서만 고친다(재질 · 빛 · 그림 카드). 주인공 소품 ·
#  상인 몸통 · TV · 잔 걸이 · 양철 천장은 scripts/tools/blender/bar_intro.py(assets/models/bar_intro.glb), 상인의
#  팔뚝 · 손은 상점 손 그대로(game.gd _hand3_build · _fore3_build). TV 는 이 장면의 세계(제 SubViewport)에만 있다 —
#  제목 문 카메라는 다른 세계라 못 본다.
#  소리는 제 자리에서 낸다(cues 는 비었다) — 방 소리 · 잔 · 닦기 · 잔 놓기는 이 장면의 BarAmb 버스(로패스 — 눈과 같이
#  열리고 다이브에 닫힌다 · 넘김에 걷는다)로, TV 지지직 · 웅은 SFX 로(먹먹해지지 않는다).
const Door3D = preload("res://scripts/door3d.gd")
const Room3D = preload("res://scripts/room3d.gd")
const Plg = preload("res://scripts/prologue3d.gd")
const GLB := "res://assets/models/bar_intro.glb"

#  때 — feed 화면 그림(게임 인트로 시계)이 출발 · dive0 ~ dive1 유리 속으로 · 넘김(handoff) = dive1 · 그 뒤 fade 동안
#  층이 걷힌다(LEN)
const T := {"feed": 7.0, "dive0": 10.2, "dive1": 11.4, "fade": 0.45}
const LEN := 11.85
#  층 — 게임 필터 밑(Plg.LAYER 와 같다)
const LAYER := 90
#  렌더 층 — 안(Door3D.LAYER_IN) · 상인(TV 빛이 안 닿는다) · 펜던트 · TV 그림자를 드리우는 주인공 것
const L_IN := 2
const L_MERCH := 1 << 4
const L_HERO := 1 << 5
#  자세 [눈, 보는 데, 굴림(도 — 뺨을 카운터에 댄 머리), 화각] — 바 좌표(Door3D BAR · 카운터 윗면 y −0.14 · 앞판 z −3.50 ·
#  오른쪽 바 의자 x −0.10 · z −3.12)
const POSE := {
	"cheek": [Vector3(-0.13, -0.075, -3.57), Vector3(-0.14, -0.085, -3.88), -66.0, 44.0],
	"merch": [Vector3(-0.10, 0.30, -3.20), Vector3(-0.40, -0.07, -3.98), 0.0, 44.0],
	"dart": [Vector3(-0.10, 0.30, -3.20), Vector3(1.12, -0.16, -4.80), 0.0, 48.0],
	"tv": [Vector3(-0.10, 0.30, -3.20), Vector3(-0.12, 1.0, -4.47), 0.0, 31.0],
	"tv2": [Vector3(-0.10, 0.30, -3.24), Vector3(-0.10, 0.88, -4.47), 0.0, 24.0],
	"push": [Vector3(-0.10, 0.36, -3.36), Vector3(-0.10, 0.86, -4.47), 0.0, 16.0],
}
#  길 [시작, 끝, 자세에서, 자세로, 꼴] — lift 고개를 든다(굴림이 늦게 끝난다) · look 눈이 먼저 튀고(3 틀) 고개가 따라
#  조금 넘쳤다 선다 · cut 눈을 감은 틈에 바뀐다 · push 화각이 좁아지며 조금 다가간다. 그 사이는 완전히 멈춘다 —
#  흔들림 · 숨 · 미세한 흐름이 있으면 640×360 텍셀이 기어 다닌다(T09).
const MOVE := [
	[3.0, 4.2, "cheek", "merch", "lift"],
	[5.0, 5.75, "merch", "dart", "look"],
	[6.5, 7.25, "dart", "tv", "look"],
	[8.05, 8.05, "tv", "tv2", "cut"],
	[8.3, 10.2, "tv2", "push", "push"],
]
#  눈꺼풀 [때, 뜬 몫] — 감기 0.1 · 뜨기 0.2(둘째는 0.3) · 첫 뜸은 반(0.45)
const LID := [[0.0, 0.0], [1.5, 0.0], [1.95, 0.45], [2.2, 0.45], [2.3, 0.0], [2.35, 0.0], [2.65, 1.0],
		[7.95, 1.0], [8.05, 0.0], [8.1, 0.0], [8.3, 1.0]]
#  감은 눈 너머 빛 — 검붉은 판(검정 위 두 단 안) · 1.2 초에 한 단 든다
const SKIN := [Color8(8, 2, 2), Color8(20, 6, 4)]
#  초점 [때부터, 띠 앞 m, 띠 뒤 m, 가장 작은 덩어리 px, 가장 큰 덩어리 px] — 흐름 없이 뛴다(깜박임 · 눈길 한가운데)
const FOCUS := [
	[0.0, 0.0, 0.0, 4.0, 8.0],
	[2.3, 0.12, 0.42, 1.0, 4.0],
	[3.75, 0.62, 1.40, 1.0, 4.0],
	[5.35, 1.9, 3.5, 1.0, 4.0],
	[6.85, 1.05, 1.95, 1.0, 4.0],
	[10.2, 0.0, 999.0, 1.0, 1.0],
]
#  빛 밑값(세기) · 표 [때부터, 이름 → 밑값의 몫] — 그 때에 그 자리에서 바뀐다(이어 붙이지 않는다). 8.4 부터 한 등씩
#  꺼진다: 다트 장 그림등 → 촛불 · 네온 → 왼 펜던트 → 선반 밑불 · 채움 반 → 오른 펜던트 → 가운데 펜던트 · 채움 0.
const LBASE := {"pl": 1.2, "pm": 3.0, "pr": 1.15, "shelf": 0.15, "pict": 2.6, "candle": 0.9, "neon": 0.7}
const LIGHT := [
	[0.0, {"pl": 1.0, "pm": 1.0, "pr": 1.0, "shelf": 1.0, "pict": 0.0, "candle": 0.4, "neon": 0.0, "fill": 1.0}],
	[5.0, {"pict": 1.0, "candle": 0.75, "neon": 0.15}],
	[8.4, {"pict": 0.0}],
	[8.7, {"candle": 0.0, "neon": 0.0}],
	[9.0, {"pl": 0.0}],
	[9.25, {"shelf": 0.0, "fill": 0.5}],
	[9.5, {"pr": 0.0}],
	[9.85, {"pm": 0.0, "fill": 0.0}],
]
const CLICK := [8.4, 8.7, 9.0, 9.25, 9.5, 9.85]
#  채움 — 웅덩이 밖 바탕(안 재질 fill · 문 장면 BAR.fill 의 0.12 배 언저리 · 찬 쪽)
const FILL := Color(0.035, 0.04, 0.06)
#  주인공 소품 자리 — 손님 잔(받침째) · 상인(바닥 · 요(도) · 닦는 잔 밑동 · 기울기(도)) · TV(천장 걸이 · 요 · 숙임 · 기울기
#  축) · 잔 걸이 · 양철 천장
const PINT := Vector3(-0.18, -0.14, -3.86)
const MERCH := {"at": Vector3(-0.62, -1.22, -4.32), "yaw": 15.0, "glass": Vector3(0.02, 1.15, 0.36), "tilt": 30.0}
const TV := {"at": Vector3(-0.10, 1.30, -4.60), "yaw": 4.0, "tilt": 15.0, "pivot": -0.4224, "aim": Vector3(-0.15, -0.12, -4.0)}
const RACK := Vector3(-0.15, 1.30, -3.86)
#  TV 빛 — 세기 · 빛깔(지지직 찬 빛 → 그림이 비친 뒤) · 단(밑값의 몫 — 0.5~2 초씩 버틴다 · 이어 붙이지 않는다)
const TVL := {"e": 2.6, "c": Color(0.62, 0.68, 0.80), "c2": Color(0.74, 0.72, 0.74), "lv": [0.6, 0.68, 0.76, 0.84, 0.92, 1.0],
		"hold": [0.5, 2.0], "rim": 0.2, "fog": 2.2}
#  화면 — 지지직이 그림을 덮는 몫 [때부터, 몫](단으로 걷힌다) · 지지직 칸
const SNOW := [[0.0, 1.0], [7.0, 0.72], [7.3, 0.42], [7.6, 0.16], [8.05, 0.05], [9.0, 0.0]]
const SNOW_RES := Vector2(46.0, 34.0)
#  상인 — 비틀기(도 · 1.5 초에 한 번 — bar_polish 의 박자 · t 0 이 정방향 가장 빠른 때) · 받치는 손이 반대로 돌리는 몫 ·
#  고쳐 쥐기 [시작, 끝, 잔을 돌리는 각] · 내려놓기 [시작, 닿음] · gone 안쪽으로 빠진 때(눈이 다트 장을 보는 동안)
const POLISH := {"a": 55.0, "per": 1.5, "back": 0.45, "regrip": [4.45, 4.8, 60.0], "down": [5.45, 5.8], "gone": 6.3}
#  팔 — 위팔 길이(bar_intro.py L_UA) · 팔뚝(팔꿈치 → 손목) · 손 단위(m — prologue3d TAPE.s)
const ARM := {"ua": 0.2956, "fa": 0.27, "s": 0.00328}
#  손가락 [첫 굽힘 ×4 · 끝 굽힘 ×4 · 부채 · 엄지 접기 · 엄지 굽힘 · 엄지 내림](game.gd FPOSE 차례)
const HPOSE := {
	"pinch": [42.0, 64.0, 76.0, 88.0, 46.0, 82.0, 92.0, 100.0, 0.0, 0.45, 26.0, 16.0],
	"cup": [28.0, 40.0, 50.0, 60.0, 30.0, 40.0, 50.0, 58.0, 4.0, 0.0, 14.0, 8.0],
}

#  바 안 재질 — 문 장면의 IN_SHADER 를 이 장면만 고친 사본. 빛의 감쇠(거리 · 원뿔)는 매끈하게 두고 면의 빛 각도만
#  둥근 것에서 nb 단으로 끊는다(평평한 판 · 벽 · 바닥은 0 — 웅덩이에 고리가 안 선다) · 바탕빛은 방향 없이 고르게
#  (눈이 돌아도 결 그늘이 안 뒤집힌다) · sat 채도.
static var _in_sh: Shader = null
const IN_LIGHT_OLD := """	float v = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += steps(v, FRAGCOORD.xy) * LIGHT_COLOR / PI;"""
const IN_LIGHT_NEW := """	float g = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	g = nb > 0.0 ? floor(g * nb + 0.5) / nb : g;
	DIFFUSE_LIGHT += g * ATTENUATION * LIGHT_COLOR / PI;"""
const IN_FK_OLD := "float fk = floor(clamp(0.6 + 0.55 * dot(fn, FD), 0.3, 1.2) * 5.0 + 0.5) / 5.0;"
const IN_ALB_OLD := """	ALBEDO = c.rgb;
	EMISSION = c.rgb * (fill * fk + vec3(glow_k));"""
const IN_ALB_NEW := """	ALBEDO = mix(vec3(dot(c.rgb, vec3(0.2126, 0.7152, 0.0722))), c.rgb, sat);
	EMISSION = ALBEDO * (fill * fk + vec3(glow_k));"""

#  유리 — 너머를 굴려 비춘다(화면 그림 · 온 px 만큼만 밀고 덩어리로 — 유리 너머는 늘 초점 밖이다) · 스치는 면은 세
#  단으로 어둡다(테가 검은 선으로 선다) · 빛을 비추는 자리만 단단한 반짝 줄(빛 자리에서 — 붙인 도형이 아니다).
const GLASS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, fog_disabled;
uniform sampler2D scr : hint_screen_texture, filter_nearest;
uniform sampler2D dep : hint_depth_texture, filter_nearest;
uniform vec3 tint : source_color = vec3(0.86, 0.92, 0.90);
uniform float f0 = 0.0;
uniform float f1 = 999.0;
uniform float bmin = 1.0;
uniform float bmax = 4.0;
uniform vec4 lp0 = vec4(0.0);
uniform vec4 lp1 = vec4(0.0);
uniform vec4 lp2 = vec4(0.0);
uniform vec3 lc0 : source_color = vec3(1.0, 0.81, 0.54);
uniform vec3 lc1 : source_color = vec3(1.0, 0.81, 0.54);
uniform vec3 lc2 : source_color = vec3(0.62, 0.68, 0.80);
uniform float bend = 5.0;
uniform float cut = 0.986;
uniform float hi = 0.9;
uniform vec3 edge : source_color = vec3(0.10, 0.08, 0.06);

vec3 strip(vec4 lp, vec3 lc, vec3 r, vec3 vert, mat4 vm) {
	vec3 l = normalize((vm * vec4(lp.xyz, 1.0)).xyz - vert);
	return lc * lp.w * hi * step(cut, dot(r, l));
}

float want(float z) {
	float o = max(f0 - z, z - f1);
	if (o <= 0.0) {
		return 1.0;
	}
	float r = o / max(f1, 0.2);
	return r < 0.35 ? 2.0 : (r < 1.0 ? 4.0 : 8.0);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float f = 1.0 - abs(dot(n, v));
	vec2 vs = VIEWPORT_SIZE;
	//  너머 그림 — 온 px 만큼 굴려 밀고, 화면 덩어리 흐림(POST_SHADER)과 같은 셈으로 그 깊이의 덩어리를 고른다
	vec2 fc = floor(FRAGCOORD.xy + round(n.xy * bend));
	vec2 uv = (fc + 0.5) / vs;
	for (int k = 3; k >= 1; k--) {
		float s = exp2(float(k));
		if (s > bmax) {
			continue;
		}
		vec2 bc = (floor(fc / s) * s + s * 0.5) / vs;
		vec4 vw = INV_PROJECTION_MATRIX * vec4(bc * 2.0 - 1.0, texture(dep, bc).r, 1.0);
		if (max(want(-vw.z / vw.w), bmin) >= s) {
			uv = bc;
			break;
		}
	}
	vec3 c = texture(scr, clamp(uv, vec2(0.0), vec2(1.0))).rgb * tint;
	c = f > 0.86 ? max(c * 0.3, edge) : c * (f > 0.6 ? 0.7 : 1.0);
	vec3 r = reflect(-v, n);
	c += strip(lp0, lc0, r, VERTEX, VIEW_MATRIX) + strip(lp1, lc1, r, VERTEX, VIEW_MATRIX)
			+ strip(lp2, lc2, r, VERTEX, VIEW_MATRIX);
	ALBEDO = c;
}
"""
static var _glass_sh: Shader = null

#  맥주 — 밑 한 단 짙고(두 단) · 면 바로 밑 한 줄 밝고 · 뒤에서 TV 가 받치면 제 빛이 단으로 든다(glow) · 빛 각도도 세 단.
const BEER_SHADER := """
shader_type spatial;
uniform vec3 col : source_color = vec3(0.78, 0.47, 0.13);
uniform vec3 lo : source_color = vec3(0.42, 0.19, 0.05);
uniform vec3 top : source_color = vec3(0.98, 0.80, 0.42);
uniform float y0 = 0.0127;
uniform float y1 = 0.0762;
uniform float glow = 0.1;
varying float my;
void vertex() {
	my = VERTEX.y;
}
void fragment() {
	float h = (my - y0) / (y1 - y0);
	vec3 c = h < 0.4 ? lo : col;
	c = h > 0.93 ? top : c;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = c * glow;
}
void light() {
	float g = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	g = floor(g * 3.0 + 0.5) / 3.0;
	DIFFUSE_LIGHT += g * ATTENUATION * LIGHT_COLOR / PI;
}
"""
static var _beer_sh: Shader = null

#  깊이 덩어리 흐림 — 화면 한 장(층 맨 앞 · 투명 차례 맨 처음)이 깊이 그림을 읽어 초점 띠 밖을 2 · 4 · 8px 덩어리로
#  뭉갠다(덩어리 한가운데의 깊이로 고른다 — 고운 흐림이 아니라 도트 단). 주인공 유리는 이 뒤에 그려 또렷하다.
const POST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;
uniform sampler2D scr : hint_screen_texture, filter_nearest;
uniform sampler2D dep : hint_depth_texture, filter_nearest;
uniform float f0 = 0.0;
uniform float f1 = 999.0;
uniform float bmin = 1.0;
uniform float bmax = 4.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin(vec2 uv, mat4 ip) {
	float d = texture(dep, uv).r;
	vec4 v = ip * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

float want(float z) {
	float o = max(f0 - z, z - f1);
	if (o <= 0.0) {
		return 1.0;
	}
	float r = o / max(f1, 0.2);
	return r < 0.35 ? 2.0 : (r < 1.0 ? 4.0 : 8.0);
}

void fragment() {
	vec2 vs = VIEWPORT_SIZE;
	vec2 fc = floor(FRAGCOORD.xy);
	vec2 uv = (fc + 0.5) / vs;
	for (int k = 3; k >= 1; k--) {
		float s = exp2(float(k));
		if (s > bmax) {
			continue;
		}
		vec2 c = (floor(fc / s) * s + s * 0.5) / vs;
		if (max(want(lin(c, INV_PROJECTION_MATRIX)), bmin) >= s) {
			uv = c;
			break;
		}
	}
	ALBEDO = texture(scr, uv).rgb;
}
"""


#  묶음 — 무대 · 층 · 소리 자리가 다 이 밑이다. 걷힐 때 제 버스(로패스)를 같이 걷는다(넘김 · 일찍 끊음).
class Hold extends Node:
	var bus := ""
	var spk := []         # SFX 버스에 건 TV 스피커 효과(고역 · 저역 · 줄임)

	func _exit_tree() -> void:
		spk_off()
		var bi := AudioServer.get_bus_index(bus) if bus != "" else -1
		if bi >= 0:
			AudioServer.remove_bus(bi)
		bus = ""

	func spk_on() -> void:
		var bi := AudioServer.get_bus_index("SFX")
		if bi < 0 or not spk.is_empty():
			return
		var tv: Array = SND.tv
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = float(tv[0])
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = float(tv[1])
		var am := AudioEffectAmplify.new()
		am.volume_db = float(tv[2])
		spk = [hp, lp, am]
		for e in spk:
			AudioServer.add_bus_effect(bi, e)

	func spk_off() -> void:
		var bi := AudioServer.get_bus_index("SFX")
		if bi >= 0:
			for i in range(AudioServer.get_bus_effect_count(bi) - 1, -1, -1):
				if spk.has(AudioServer.get_bus_effect(bi, i)):
					AudioServer.remove_bus_effect(bi, i)
		spk = []


static func length() -> float:
	return LEN


#  층이 걷히기 시작하는 때 — 게임 필터가 이때 켜진다(game.gd _plg_cover).
static func handoff() -> float:
	return float(T.dive1)


#  TV 가 게임 그림을 틀기 시작하는 때 — 게임의 인트로 시계가 이때 출발한다(지지직 사이로 비친다).
static func feed_at() -> float:
	return float(T.feed)


#  소리는 이 장면이 제 자리에서 낸다(로패스 버스 · 박자) — game.gd 가 낼 것은 없다.
static func cues() -> Dictionary:
	return {}


# ══ 짓기 ═══════════════════════════════════════════════════
#  game — 인트로를 그리는 게임(그 화판 그림이 TV 에 뜬다) · outer — 화판 밖(game.screen_host).
static func make(game: Node, outer: Node) -> Node:
	var hn := Hold.new()
	hn.name = "PrologueBar"
	outer.add_child(hn)
	var sz: Vector2 = game.get_viewport().get_visible_rect().size
	var vp := SubViewport.new()
	vp.name = "Stage"
	vp.size = Vector2i(maxi(int(sz.x), 2), maxi(int(sz.y), 2))
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.gui_disable_input = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	#  그림자 지도 — 가운데 펜던트가 한 사분면을 혼자 · 오른 펜던트 · TV 는 둘째 사분면(단단한 테 · 1px 가 안 기게)
	vp.positional_shadow_atlas_size = 4096
	vp.positional_shadow_atlas_quad_0 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
	vp.positional_shadow_atlas_quad_1 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
	hn.add_child(vp)
	var w := Node3D.new()
	w.name = "World"
	vp.add_child(w)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false
	#  옅은 안개 — 제 빛 · 바탕빛이 없어 빛을 받은 데만 선다. TV 빛만 안개에 줄기를 세운다(펜던트는 0 · 둥근 안개 공 금지).
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.82, 0.80, 0.78)
	env.volumetric_fog_emission = Color.BLACK
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 3.0
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_amount = 0.6
	we.environment = env
	w.add_child(we)
	hn.set_meta("env", env)
	var cam := Camera3D.new()
	cam.near = 0.02
	cam.far = 30.0
	w.add_child(cam)
	hn.set_meta("cam", cam)
	hn.set_meta("vp", vp)
	hn.set_meta("game", game)
	#  세트 — 제목 문 안의 술집 그대로 짓고 이 장면만 고친다
	Door3D._inside(w)
	var bar := w.get_node("Bar") as Node3D
	_patch(hn, w, bar)
	_props(hn, w)
	_merchant(hn, w, game)
	var feed: Texture2D = game.get_viewport().get_texture()
	_tv(hn, w, feed, sz)
	_lights_make(hn, w, bar)
	_post_make(hn, w)
	_lids_make(hn, vp)
	_layer_make(hn, vp, feed, outer)
	_audio_make(hn, game)
	tick(hn, 0.0)
	return hn


#  안 재질 하나(이 장면 사본) — col 맨 색 · nb 둥근 것의 빛 단
static func _inm(hn: Node, col: Color, nb := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _in_shader()
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("nb", nb)
	m.set_shader_parameter("fill", FILL)
	(hn.get_meta("ins") as Array).append(m)
	return m


static func _in_shader() -> Shader:
	if _in_sh == null:
		var code: String = Door3D.IN_SHADER
		var ok: bool = code.contains(IN_LIGHT_OLD) and code.contains(IN_FK_OLD) and code.contains(IN_ALB_OLD)
		if not ok:
			push_warning("prologue_bar3d — Door3D.IN_SHADER 가 바뀌어 빛 고침이 안 먹는다")
		code = code.replace(IN_LIGHT_OLD, IN_LIGHT_NEW).replace(IN_FK_OLD, "float fk = 0.8;") \
				.replace(IN_ALB_OLD, IN_ALB_NEW).replace("uniform float seam = 0.15;",
				"uniform float seam = 0.15;\nuniform float nb = 0.0;\nuniform float sat = 1.0;")
		_in_sh = Shader.new()
		_in_sh.code = code
	return _in_sh


#  세트 고치기 — 안 재질을 사본으로(반짝 0 · 찬 바탕 · 평평한 판은 빛 단 없음 · 둥근 것은 4 단), 빛무리 · 바닥 그늘 막 ·
#  전구 · 거울 비침 · 도트 잔 그림을 걷고, 술병 그림은 눈을 보게 돌려 채도를 누르고 어둡게, 카운터 코는 팔걸이로.
static func _patch(hn: Node, w: Node3D, bar: Node3D) -> void:
	hn.set_meta("ins", [])
	var conv := {}
	var glows := []
	var eye: Vector3 = POSE.merch[0]
	var hide_bulb := ShaderMaterial.new()
	hide_bulb.shader = Shader.new()
	hide_bulb.shader.code = "shader_type spatial;\nrender_mode unshaded;\nvoid fragment() {\n\tdiscard;\n}\n"
	for n in bar.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var mo := mi.material_override
		#  빛무리 · 바닥 그늘 막(고운 그러데이션) — 이 장면은 진짜 그림자 · 어둠이 맡는다
		if mo is StandardMaterial3D and (mo as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			mi.visible = false
			continue
		if mi.mesh == Door3D._bar_mesh.get("CntNose"):
			mi.visible = false
			continue
		#  그림 카드(Door3D._sprite — 이름은 겹쳐 붙으며 바뀌므로 재질로 가린다: 잘라 내기 0.5 · 위로 든 노멀 · 제 빛 몫)
		var spr := false
		if mi.mesh is QuadMesh and mo is ShaderMaterial and (mo as ShaderMaterial).shader == Door3D._in_sh:
			var sm := mo as ShaderMaterial
			var gk: float = _num(sm.get_shader_parameter("glow_k"))
			var cut: float = _num(sm.get_shader_parameter("cut"))
			var tint: Color = sm.get_shader_parameter("tint")
			if cut > 0.4 and (is_equal_approx(gk, 0.3) or is_equal_approx(gk, 0.4) or not tint.is_equal_approx(Color.WHITE)):
				mi.visible = false            # 도트 잔(0.3 · 0.4) · 거울 비침(어두운 색) — 잔은 3D 로 바꿔 놓는다
				continue
			if cut > 0.4 and is_equal_approx(gk, 0.12):
				spr = true
				mi.rotation.y = atan2(eye.x - mi.position.x, eye.z - mi.position.z)
		#  다트 장 칠판(분필 점수) — 글로 읽히지 않게 한 단 어둡게
		var chalk: bool = mi.mesh is QuadMesh and absf((mi.mesh as QuadMesh).size.y - (float(Door3D.BAR.cab) * 2.0 - 0.05)) < 0.001
		var pr := mi.mesh is BoxMesh or mi.mesh is QuadMesh or mi.mesh is PlaneMesh
		var nb: float = 0.0 if pr else 4.0
		var slots := [mo]
		if mo == null:
			slots = []
			for k in mi.mesh.get_surface_count():
				slots.append(mi.get_surface_override_material(k))
		for k in slots.size():
			var om: Material = slots[k]
			if om is StandardMaterial3D:
				var gm := om as StandardMaterial3D
				if gm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
					if gm.emission_energy_multiplier >= 3.9 and gm.albedo_color.is_equal_approx(Color("fbf6ea")):
						#  전구 — 갓 밑으로 2cm 삐져나와 올려다보면 큰 크림 공이다(젖빛 판이 막는다)
						if mo == null:
							mi.set_surface_override_material(k, hide_bulb)
						else:
							mi.visible = false
					elif not glows.has(gm):
						glows.append(gm)
				continue
			if not (om is ShaderMaterial) or (om as ShaderMaterial).shader != Door3D._in_sh:
				continue
			var key := "%d_%d_%d" % [om.get_instance_id(), int(nb), int(chalk)]
			if not conv.has(key):
				var nmat := (om as ShaderMaterial).duplicate() as ShaderMaterial
				nmat.shader = _in_shader()
				nmat.set_shader_parameter("gloss", 0.0)
				nmat.set_shader_parameter("fill", FILL)
				nmat.set_shader_parameter("nb", nb)
				if chalk:
					nmat.set_shader_parameter("tint", Color(0.3, 0.3, 0.3))
				if spr:
					#  선반 병 — 채도 · 밝기를 누르고 제 빛을 거의 걷는다(사탕 빛깔 금지 · 주인공만 제 빛깔)
					nmat.set_shader_parameter("sat", 0.5)
					nmat.set_shader_parameter("tint", Color(0.62, 0.6, 0.6))
					nmat.set_shader_parameter("glow_k", 0.02)
				conv[key] = nmat
				(hn.get_meta("ins") as Array).append(nmat)
			if mo != null:
				mi.material_override = conv[key]
			else:
				mi.set_surface_override_material(k, conv[key])
		if mi.mesh == Door3D._bar_mesh.get("Lamp"):
			#  펜던트 갓 밑 젖빛 판(bar_intro PendDiffuser) — 등마다 제 재질(한 등씩 꺼진다)
			var pd := _glb_mesh("PendDiffuser")
			if pd != null:
				var di := MeshInstance3D.new()
				di.name = "Diffuser"
				di.mesh = pd
				var fm := Room3D._glow(Color("b89a6a"), 0.45)
				di.material_override = fm
				di.layers = L_IN
				#  갓 속 깊이 올려 줄인다 — 올려다보면 치마가 대부분을 가려 반달만 비친다(큰 크림 원판 금지)
				di.position = Vector3(0.0, 0.08, 0.0)
				di.scale = Vector3(0.52, 1.0, 0.52)
				mi.add_child(di)
				var ds: Array = hn.get_meta("diff", [])
				ds.append({"m": fm, "x": mi.position.x})
				hn.set_meta("diff", ds)
		if mi.mesh == Door3D._bar_mesh.get("Tap"):
			#  탭은 카운터 뒤끝으로 물린다 — 뺨 눈 코앞에 물받이 상자가 섰다 · 오른쪽으로 빼면 다트 장 쪽 테이블을 가렸다(이 장면만)
			mi.position.z -= 0.18
			mi.layers = L_IN | L_HERO
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			#  탭은 앞 켜 실루엣 — 놋쇠가 밝은 노랑 점으로 튀지 않게 한 단 누른다
			for k in mi.mesh.get_surface_count():
				var tm := mi.get_surface_override_material(k) as ShaderMaterial
				if tm != null:
					var dm := tm.duplicate() as ShaderMaterial
					dm.set_shader_parameter("tint", (tm.get_shader_parameter("tint") as Color) * 0.3)
					mi.set_surface_override_material(k, dm)
					(hn.get_meta("ins") as Array).append(dm)
	#  제 빛 재질 — 바탕색이 곧 밝기(빛 없음 재질). 무리로 나눠 빛과 같이 끈다.
	var gl := {"shelf": [], "cab": [], "neon": [], "candle": [], "shade": []}
	for gm in glows:
		var c: Color = gm.albedo_color
		var e: float = gm.emission_energy_multiplier
		var grp := ""
		if c.is_equal_approx(Door3D.BAR.lamp):
			grp = "shelf" if is_equal_approx(e, 1.6) else "cab"
		elif c.is_equal_approx(Color("f2b134")) or (c.is_equal_approx(Color("fbf6ea")) and is_equal_approx(e, 2.0)):
			grp = "neon"
		elif c.is_equal_approx(Color("b03a32")) or (c.is_equal_approx(Color("fdeaa0")) and is_equal_approx(e, 3.0)):
			grp = "candle"
		elif c.is_equal_approx(Color("fdeaa0")):
			grp = "shade"
		if grp != "":
			(gl[grp] as Array).append({"m": gm, "c": c})
	hn.set_meta("glows", gl)
	#  테이블 앞 의자 — 밀려난 채(방금 누가 일어났다) · 앉은 눈과 테이블 사이에 서서 윗면을 통째로 가렸다 — 테이블
	#  너머 벽 쪽으로 빼고 비스듬히 돌린다
	var ch: Array = Door3D.BAR.chairs[0]
	for c in bar.get_children():
		if c is Node3D and not (c is VisualInstance3D) and (c as Node3D).position.distance_to(
				Vector3(float(ch[0]), float(Door3D.BAR.floor), float(ch[1]))) < 0.01:
			(c as Node3D).position = Vector3(0.58, float(Door3D.BAR.floor), -4.62)
			(c as Node3D).rotation.y = 2.3


#  셰이더 값(안 준 값은 null — 기본값 0)
static func _num(v: Variant) -> float:
	return 0.0 if v == null else float(v)


#  glb 메시 · 빈 노드 변환(이름 → 처음 부를 때 한 번 읽는다)
static var _mesh := {}
static var _xf := {}


static func _glb_mesh(nm: String) -> Mesh:
	if _mesh.is_empty():
		_mesh[""] = null
		var ps: PackedScene = load(GLB) as PackedScene if ResourceLoader.exists(GLB) else null
		var sc: Node = ps.instantiate() if ps != null else null
		if sc != null:
			for c in sc.find_children("*", "Node3D", true, false):
				_xf[String(c.name)] = (c as Node3D).transform
				if c is MeshInstance3D:
					_mesh[String(c.name)] = (c as MeshInstance3D).mesh
			sc.free()
	return _mesh.get(nm)


#  glb 메시 하나를 재질 이름으로 입혀 세운다
static func _glb_mi(nm: String, mats: Dictionary, at := Vector3.ZERO, layers := L_IN) -> MeshInstance3D:
	var me := _glb_mesh(nm)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.position = at
	mi.layers = layers
	if me == null:
		return mi
	mi.mesh = me
	for k in me.get_surface_count():
		var sm: Material = me.surface_get_material(k)
		var key: String = sm.resource_name if sm != null else ""
		if mats.has(key):
			mi.set_surface_override_material(k, mats[key])
	return mi


static func _glass_mat(hn: Node) -> ShaderMaterial:
	if _glass_sh == null:
		_glass_sh = Shader.new()
		_glass_sh.code = GLASS_SHADER
	var m := ShaderMaterial.new()
	m.shader = _glass_sh
	if not hn.has_meta("glass"):
		hn.set_meta("glass", [])
	(hn.get_meta("glass") as Array).append(m)
	return m


#  주인공 소품 — 손님 잔 · 받침 · 팔걸이 · 고무 매트 · 땅콩 그릇 · 테이블에 남은 빈 잔 둘 · 다트 둘 · 카운터 왼끝 잔 ·
#  천장 잔 걸이 · 양철 천장.
static func _props(hn: Node, w: Node3D) -> void:
	var B: Dictionary = Door3D.BAR
	if _beer_sh == null:
		_beer_sh = Shader.new()
		_beer_sh.code = BEER_SHADER
	var beer := ShaderMaterial.new()
	beer.shader = _beer_sh
	hn.set_meta("beer", beer)
	var pm := {
		"glass": _glass_mat(hn), "beer": beer, "foam": _inm(hn, Color("e6dcc4"), 3.0),
		"coaster": _inm(hn, Color("7a2a20")), "coaster_ink": _inm(hn, Color("d8c9a8")),
		"coaster_wet": _inm(hn, Color("4a1812")), "card": _inm(hn, Color("b8ab90")),
		"rail": _inm(hn, B.wood, 4.0), "wood_dk": _inm(hn, B.wood_dk), "rubber": _inm(hn, Color("161214")),
		"wood": _inm(hn, B.wood, 4.0), "nut": _inm(hn, Color("9a6a32"), 3.0), "iron": _inm(hn, Color("1c1a1c"), 4.0),
		"tin": _inm(hn, Color("4a4038"), 4.0),
	}
	hn.set_meta("pm", pm)
	var hero := L_IN | L_HERO
	var co := _glb_mi("Coaster", pm, PINT, hero)
	w.add_child(co)
	var pt := _glb_mi("Pint", pm, PINT + Vector3(0.0, 0.0022, 0.0), hero)
	pt.rotation_degrees.y = 20.0
	w.add_child(pt)
	var pb := _glb_mi("PintBeer", pm, PINT + Vector3(0.0, 0.0022, 0.0), hero)
	pb.rotation_degrees.y = 20.0
	w.add_child(pb)
	#  팔걸이 — 카운터 코(CntNose) 자리 그대로(앉은 눈에서 니스 반짝이 큰 크림 원판이던 것 · 재질 rail)
	var x0: float = B.x0
	var x1: float = B.cnt_x1
	var rl := _glb_mi("CntRail", pm, Vector3((x0 + x1) * 0.5, float(B.cnt_y), float(B.cnt_z) + 0.08))
	rl.scale = Vector3(x1 - x0 + 0.06, 1.0, 1.0)
	w.add_child(rl)
	w.add_child(_glb_mi("BarMat", pm, Vector3(-0.32, float(B.cnt_y), -3.98)))
	w.add_child(_glb_mi("NutBowl", pm, Vector3(-0.44, float(B.cnt_y), -3.70)))
	#  카운터 왼끝 — 누가 두고 간 반 잔(어둠 속 엑스트라)
	var lx := Vector3(-1.95, float(B.cnt_y), -3.70)
	w.add_child(_glb_mi("Coaster", pm, lx))
	w.add_child(_glb_mi("Pint", pm, lx + Vector3(0.0, 0.0022, 0.0)))
	w.add_child(_glb_mi("PintBeer", pm, lx + Vector3(0.0, 0.0022, 0.0)))
	#  테이블 — 빈 잔 둘 · 내려놓은 다트 둘(아무도 없지만 방금 누가 있었다)
	var tc: Vector2 = B.table
	var ty: float = float(B.floor) + float(B.table_h)
	#  테이블 윗판 — Blender 테이블(bar_props Table) 윗면 법선이 밑을 봐서 촛불을 못 받고 검은 판이었다(문 장면은 바탕빛으로만
	#  봤다). 윗면 바로 위에 나무 원판 한 장(평평한 면 — 빛 단 없음)을 얹는다
	var top := Room3D._cyl(0.285, 0.285, 0.004, Vector3(tc.x, ty + 0.004, tc.y), _inm(hn, B.wood), 32)
	top.layers = L_IN
	w.add_child(top)
	var tm := pm.duplicate()
	var tg := ShaderMaterial.new()
	tg.shader = (pm.glass as ShaderMaterial).shader
	tg.set_shader_parameter("lp0", Vector4(tc.x + 0.02, ty + 0.12, tc.y + 0.10, 0.8))
	tg.set_shader_parameter("lc0", Color("ff9a50"))
	tm["glass"] = tg
	hn.set_meta("table_glass", tg)
	for g in [Vector2(-0.14, 0.04), Vector2(0.12, -0.08)]:
		w.add_child(_glb_mi("Pint", tm, Vector3(tc.x + g.x, ty, tc.y + g.y)))
	#  한 잔엔 김 빠진 맥주가 한 뼘 남았다(면을 반 높이로 · 벽 안으로 조금 줄인다)
	var lb := _glb_mi("PintBeer", pm, Vector3(tc.x - 0.14, ty, tc.y + 0.04))
	lb.scale = Vector3(0.93, 0.5, 0.93)
	w.add_child(lb)
	var steel := _inm(hn, B.steel, 4.0)
	var fl := _inm(hn, Color("8c2a52"))
	#  카운터 오른끝 — 마시고 간 빈 잔 둘 · 내려놓은 다트 둘(테이블은 앉은 눈에서 카운터 끝에 가려 이쪽에도 둔다 · 오른 펜던트 웅덩이)
	var cy0: float = float(B.cnt_y)
	for gp in [Vector3(0.30, cy0, -3.66), Vector3(0.41, cy0, -3.80)]:
		w.add_child(_glb_mi("Pint", pm, gp))
	var darts := [[Vector3(tc.x - 0.02, ty + 0.006, tc.y + 0.13), 70.0], [Vector3(tc.x + 0.10, ty + 0.006, tc.y + 0.09), 115.0],
			[Vector3(0.33, cy0 + 0.006, -3.58), 20.0], [Vector3(0.38, cy0 + 0.006, -3.62), 35.0]]
	for d in darts:
		var dn := Node3D.new()
		dn.position = d[0]
		dn.rotation_degrees = Vector3(0.0, float(d[1]), 90.0)
		w.add_child(dn)
		dn.add_child(Room3D._cyl(0.004, 0.004, 0.05, Vector3(0.0, 0.0, 0.0), steel, 6))
		dn.add_child(Room3D._cyl(0.0022, 0.0022, 0.045, Vector3(0.0, 0.047, 0.0), _inm(hn, Color("0d0b16")), 4))
		for fr in [0.0, 90.0]:
			var f := Room3D._box(Vector3(0.026, 0.03, 0.001), Vector3(0.0, 0.075, 0.0), fl)
			f.rotation_degrees.y = fr
			dn.add_child(f)
		for c in dn.get_children():
			(c as VisualInstance3D).layers = L_IN
	#  천장 — 양철 판(TV 둘레 · 펜던트 너머) · 잔 걸이(눈과 TV 사이 — 거꾸로 걸린 잔이 TV 빛에 테만 선다)
	var cy: float = float(B.ceil) - 0.001
	for i in 5:
		for j in 4:
			w.add_child(_glb_mi("TinTile", pm, Vector3(float(TV.at.x) + (float(i) - 2.0) * 0.61, cy,
					float(TV.at.z) + (float(j) - 1.0) * 0.61)))
	#  걸이 잔 — 펜던트 반짝은 빼고 TV 찬 빛만 테에 얹는다(어둠 속 실루엣 · 흰 점이 안 튀게)
	var rm := pm.duplicate()
	var rg := ShaderMaterial.new()
	rg.shader = (pm.glass as ShaderMaterial).shader
	rg.set_shader_parameter("hi", 0.4)
	rg.set_shader_parameter("tint", Color(0.5, 0.55, 0.6))
	rm["glass"] = rg
	hn.set_meta("rack_glass", rg)
	w.add_child(_glb_mi("GlassRack", rm, RACK))


# ══ 상인 ══════════════════════════════════════════════════
#  허리 ~ 깃 몸통(Blender · 머리 없음 · 깃 안은 먹 목) · 위팔 둘(어깨 축) · 상점 손 · 팔뚝(game.gd) · 닦는 빈 잔 · 바 천.
#  얼굴은 늘 그림 밖이거나 가장 어두운 단이다(가운데 펜던트는 손을 겨눈 좁은 원뿔 · TV 빛은 이 층을 안 비춘다).
static func _merchant(hn: Node, w: Node3D, g: Node) -> void:
	if g == null or not g.has_method("_hand3_build") or _glb_mesh("BarTorso") == null:
		return
	var m := Node3D.new()
	m.name = "Merchant"
	m.position = MERCH.at
	m.rotation_degrees = Vector3(0.0, float(MERCH.yaw), 0.0)
	w.add_child(m)
	var V: Dictionary = g.VEST3
	var lay := L_MERCH | L_HERO
	var tm := {
		"shirt": g._hand3_toon(g.FORE3.cloth), "shirt_btn": g._hand3_toon(Color("d8d2c4")),
		"vest": g._hand3_toon(V.vest), "lapel": g._hand3_toon(V.lap, Color(0, 0, 0, 0), 0.5),
		"vest_back": g._hand3_toon(Color8(30, 22, 30)), "trousers": g._hand3_toon(Color8(24, 24, 30)),
		"belt": g._hand3_toon(Color8(48, 28, 18)),
		"brass": g._hand3_toon(g.FORE3.brass, Color(0, 0, 0, 0), 0.4, 0.09, 1.0, 0.5),
		"chain": g._hand3_toon(V.chain, Color(0, 0, 0, 0), 0.6, 0.1, 1.0, 0.5),
		"void": Room3D._glow(Color.BLACK, 0.0),
		"cloth": g._hand3_toon(Color("cfc6ae")), "cloth_stripe": g._hand3_toon(Color("6a3a22")),
		"glass": _glass_mat(hn),
	}
	m.add_child(_glb_mi("BarTorso", tm, Vector3.ZERO, lay))
	var ua := {}
	for sd in ["R", "L"]:
		var u := _glb_mi("UpperArm" + sd, tm, Vector3.ZERO, lay)
		m.add_child(u)
		ua[sd] = u
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.scale = Vector3.ONE * float(ARM.s)
	m.add_child(arm)
	var mats: Dictionary = g._hand3_mats()
	var fm := {"skin": mats.skin, "cloth": tm.shirt, "brass": tm.brass}
	var hj := {"R": g._hand3_build(mats, false, false), "L": g._hand3_build(mats, true, true)}
	var fo := {"R": g._fore3_build(fm, float(g.FORE3.bare), 1.0), "L": g._fore3_build(fm, float(g.FORE3.bare_r), -1.0)}
	for sd in ["R", "L"]:
		arm.add_child(hj[sd].root)
		(fo[sd].sty as Node3D).visible = false
		arm.add_child(fo[sd].root)
	var gl := Node3D.new()
	gl.name = "Glass"
	m.add_child(gl)
	gl.add_child(_glb_mi("PolishGlass", tm, Vector3.ZERO, lay))
	gl.add_child(_glb_mi("TowelWrap", tm, Vector3.ZERO, lay))
	var tails := []
	for k in ["A", "B", "C"]:
		var tl := _glb_mi("TowelTail_" + k, tm, Vector3.ZERO, lay)
		m.add_child(tl)
		tails.append(tl)
	for c in m.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).layers = lay
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hn.set_meta("merch", {"n": m, "ua": ua, "hj": hj, "fo": fo, "glass": gl, "tails": tails, "g": g})


#  두 마디 IK — 어깨 s 에서 손목 w 로(위팔 l1 · 팔뚝 l2) · 팔꿈치는 pole 쪽으로 굽는다
static func _ik(s: Vector3, w: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var d: float = clampf(s.distance_to(w), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var dir: Vector3 = (w - s).normalized()
	var a: float = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h: float = sqrt(maxf(l1 * l1 - a * a, 0.0))
	var pp: Vector3 = (pole - s) - dir * dir.dot(pole - s)
	return s + dir * a + pp.normalized() * h


#  손 · 팔 하나를 세운다 — 손목 wr(상인 좌표 m) · 손 basis hb(손끝 x · 손등 y · 엄지 쪽 z) · 어깨에서 팔꿈치를 IK 로
static func _arm_set(g: Node, sd: String, M: Dictionary, wr: Vector3, hb: Basis) -> void:
	var s: float = ARM.s
	var hj: Dictionary = M.hj[sd]
	var fo: Dictionary = M.fo[sd]
	var out: float = -1.0 if sd == "R" else 1.0
	var sh: Vector3 = (_xf.get("Shoulder" + sd, Transform3D()) as Transform3D).origin
	var el: Vector3 = _ik(sh, wr, float(ARM.ua), float(ARM.fa), sh + Vector3(out * 0.35, -0.55, -0.3))
	(hj.root as Node3D).transform = Transform3D(hb, wr / s)
	var y: Vector3 = (sh - el).normalized()
	var z: Vector3 = (Vector3.BACK - y * y.dot(Vector3.BACK)).normalized()
	(M.ua[sd] as Node3D).transform = Transform3D(Basis(y.cross(z), y, z), sh)
	var ws: Vector3 = wr / s + hb.y * 0.5
	var es: Vector3 = el / s
	var ax: Vector3 = es - (ws - es).normalized() * float(g.HAND3.back)
	(fo.root as Node3D).transform = g._aim3(ax, ws, 1.0, 0.0, hb.y)
	g._fore3_fit(fo, (ws - ax).length(), 1.0)


#  손가락 — game.gd FPOSE 차례(prologue3d _tape_pose 와 같은 길)
static func _fingers(g: Node, hj: Dictionary, p: Array) -> void:
	var sg: float = hj.sg
	var fan: Array = g.FING3.fan
	for f in 4:
		(hj.j1[f] as Node3D).basis = Basis(Vector3.UP, deg_to_rad(float(p[8]) * float(fan[f])) * sg) \
				* Basis(Vector3.BACK, -deg_to_rad(float(p[f])))
		(hj.j2[f] as Node3D).basis = Basis(Vector3.BACK, -deg_to_rad(float(p[4 + f])))
	g._thumb3_pose(sg, PackedFloat32Array(p), 0)
	g._thumb3_set(hj, g.thumb_mr, Transform3D(g.thumb_pr, Vector3(float(g.THUMB3.lm), 0.0, 0.0)),
			Basis(Vector3.BACK, -deg_to_rad(float(g.thumb_cr))), sg, clampf(float(p[9]), 0.0, 1.0))


#  비틀기(도) — 일하는 손이 잔 축을 따라 돈다(사인 · 1.5 초 · t 0 이 정방향 가장 빠른 때 = bar_polish 박자). 고쳐 쥘 때 ·
#  내려놓은 뒤에는 멎는다.
static func _twist(t: float) -> float:
	var P: Dictionary = POLISH
	var rg: Array = P.regrip
	var dn: Array = P.down
	var env: float = 1.0 - smoothstep(float(rg[0]) - 0.1, float(rg[0]) + 0.05, t) * (1.0 - smoothstep(float(rg[1]) - 0.05,
			float(rg[1]) + 0.1, t))
	env *= 1.0 - smoothstep(float(dn[0]) - 0.15, float(dn[0]), t)
	return float(P.a) * sin(TAU * t / float(P.per)) * env


static func _merch_tick(hn: Node, t: float) -> void:
	if not hn.has_meta("merch"):
		return
	var M: Dictionary = hn.get_meta("merch")
	#  잔을 내려놓고 안쪽으로 든다 — 눈이 다트 장을 보는 동안(그림 밖) 빠진다 · 올려다볼 때 깃이 그림 귀에 안 걸린다
	(M.n as Node3D).visible = t < float(POLISH.gone)
	if t >= float(POLISH.gone):
		return
	var g: Node = M.g
	var P: Dictionary = POLISH
	var th: float = _twist(t)
	var rg: Array = P.regrip
	var dn: Array = P.down
	var sp: float = -float(P.back) * th + float(rg[2]) * smoothstep(float(rg[0]), float(rg[1]), t)
	#  내려놓기 — 잔이 곧게 서며 카운터(상인 좌표 y 1.08)로 내려와 닿는다(잔 놓는 소리)
	var dk: float = smoothstep(float(dn[0]), float(dn[1]), t)
	var gp: Vector3 = (MERCH.glass as Vector3).lerp(Vector3(-0.02, 1.081, 0.40), dk)
	var gb := Basis(Vector3.BACK, deg_to_rad(float(MERCH.tilt) * (1.0 - dk))) * Basis(Vector3.UP, deg_to_rad(sp))
	(M.glass as Node3D).transform = Transform3D(gb, gp)
	var a: Vector3 = gb.y
	var fwd: Vector3 = (Vector3.BACK - a * a.dot(Vector3.BACK)).normalized()
	#  받치는 손(왼손 · 반지) — 손바닥이 위로 밑동을 받친다 · 손끝은 몸 앞쪽 · 잔을 반대로 돌린 만큼 같이 돈다
	var side: Vector3 = a.cross(fwd).normalized()          # 잔 축에서 상인의 왼쪽(+x) 언저리
	var spl := Basis(a, deg_to_rad(sp * 0.5))
	var xl: Vector3 = spl * (fwd * 0.55 - side * 0.8).normalized()
	var yl: Vector3 = -a
	yl = (yl - xl * xl.dot(yl)).normalized()
	var wl: Vector3 = gp - a * 0.025 - xl * 0.075
	_arm_set(g, "L", M, wl, Basis(xl, yl, xl.cross(yl)))
	_fingers(g, M.hj.L, HPOSE.cup)
	#  일하는 손(오른손) — 손등이 손님 쪽 · 손끝이 잔 바깥 앞면을 따라 내려가고 엄지가 천째 입 안에 · 잔 축을 따라 비튼다
	var tw := Basis(a, deg_to_rad(th))
	var u: Vector3 = tw * fwd
	var xr: Vector3 = (-a * 0.92 + u * 0.38).normalized()
	var yr: Vector3 = (u - xr * xr.dot(u)).normalized()
	var rim: Vector3 = gp + a * 0.148
	var wr: Vector3 = rim + a * 0.045 - u * 0.012
	_arm_set(g, "R", M, wr, Basis(xr, yr, xr.cross(yr)))
	_fingers(g, M.hj.R, HPOSE.pinch)
	#  천 꼬리 — 받치는 손 새끼 쪽 모서리에서 늘 곧게 늘어진다 · 비틀기를 0.15 초 늦게 따라 셋을 갈아 끼운다
	var lag: float = _twist(t - 0.15)
	var pick: int = 0 if absf(lag) < float(P.a) * 0.35 else (1 if lag > 0.0 else 2)
	var zl: Vector3 = xl.cross(yl)
	var tp: Vector3 = wl + xl * 0.07 - zl * 0.03 - Vector3(0.0, 0.015, 0.0)
	for i in 3:
		var tn := M.tails[i] as Node3D
		tn.visible = i == pick and dk < 0.5
		tn.position = tp


# ══ TV ═══════════════════════════════════════════════════
#  천장 걸이(관 · 멍에 · 축 손잡이 · 줄) · 14″ 브라운관(두 단 테 · 볼록 유리 · 받침 띠 · 쟁반 — 숙여 단다). 유리는 테이프
#  프롤로그의 화면(Plg SCR_SHADER mode 9 — 게임 화판 그림) + 브라운관 결(crt · snowk · refl). 찬 빛 한 줄기가 카운터
#  끝 · 손님 잔으로(상인 층은 안 비춘다 · 원뿔이 머리에 안 닿는다) · 작은 빛 하나가 제 테 · 걸이 · 천장을 짚는다.
static func _tv(hn: Node, w: Node3D, feed: Texture2D, sz: Vector2) -> void:
	var pm: Dictionary = hn.get_meta("pm")
	var tm := {
		"crt_body": _inm(hn, Color("2a292d"), 4.0), "crt_bezel": _inm(hn, Color("121114"), 4.0),
		"crt_btn": _inm(hn, Color("3a3a40"), 4.0), "crt_grille": _inm(hn, Color("0c0c0f")),
		"crt_led": Room3D._glow(Color("ff3b2e"), 1.0), "iron": pm.iron, "knob": _inm(hn, Color("26232a"), 4.0),
		"cable": _inm(hn, Color("0c0a0e"), 4.0), "rubber": pm.rubber,
	}
	var mnt := _glb_mi("TvMount", tm, TV.at)
	mnt.rotation_degrees = Vector3(0.0, float(TV.yaw), 0.0)
	w.add_child(mnt)
	var crt := _glb_mi("BarCrt", tm, Vector3(0.0, float(TV.pivot), 0.0))
	crt.rotation_degrees = Vector3(float(TV.tilt), 0.0, 0.0)
	mnt.add_child(crt)
	var me := crt.mesh
	if me == null:
		return
	var gb := AABB()
	var scr: ShaderMaterial = null
	for k in me.get_surface_count():
		var sm: Material = me.surface_get_material(k)
		if sm != null and sm.resource_name == "crt_glass":
			gb = Plg._surf_aabb(me, k)
			scr = Plg._scr_mat("game", gb, 0, null, true, feed, sz)
			scr.set_shader_parameter("res", SNOW_RES)
			scr.set_shader_parameter("crt", 1.0)
			scr.set_shader_parameter("snowk", 1.0)
			scr.set_shader_parameter("pw", 1.0)
			scr.set_shader_parameter("amb", 0.0)
			crt.set_surface_override_material(k, scr)
	hn.set_meta("scr", scr)
	#  유리 꼭지 · 앞(세계) — 다이브 끝 자리(유리 폭이 화면 폭을 꼭 채우는 거리의 Plg HERO.dive 몫)
	var gx: Transform3D = crt.global_transform
	var gc: Vector3 = gx * gb.get_center()
	var n: Vector3 = (gx.basis * Vector3.BACK).normalized()
	var apex: Vector3 = gc + n * gb.size.z * 0.5
	var fov: float = float(POSE.push[3])
	var ar: float = sz.x / maxf(sz.y, 1.0)
	var de: float = gb.size.x * 0.5 / (tan(deg_to_rad(fov) * 0.5) * ar) * float(Plg.HERO.dive)
	hn.set_meta("end", {"look": apex, "at": apex + n * de})
	hn.set_meta("tv_c", gc)
	var tl := SpotLight3D.new()
	tl.name = "TvLight"
	tl.light_color = TVL.c
	tl.spot_angle = 22.0
	tl.spot_range = 2.4
	tl.spot_attenuation = 1.0
	tl.spot_angle_attenuation = 1.0
	tl.light_cull_mask = L_IN
	tl.light_volumetric_fog_energy = float(TVL.fog)
	tl.shadow_enabled = true
	tl.shadow_blur = 0.0
	tl.light_size = 0.0
	tl.shadow_opacity = 0.8
	tl.shadow_caster_mask = L_HERO
	w.add_child(tl)
	var at: Vector3 = apex + n * 0.03
	tl.look_at_from_position(at, TV.aim)
	var rl := OmniLight3D.new()
	rl.name = "TvRim"
	rl.light_color = TVL.c
	rl.omni_range = 0.6
	rl.omni_attenuation = 1.4
	rl.light_cull_mask = L_IN
	rl.light_volumetric_fog_energy = 0.0
	rl.light_specular = 0.0
	rl.position = apex + n * 0.12 + Vector3(0.0, 0.12, 0.0)
	w.add_child(rl)
	hn.set_meta("tvl", [tl, rl])
	#  찬 빛 단 — 0.5~2 초씩 버티고 그 자리에서 바뀐다(이어 붙이지 않는다 · 씨 고정)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20251025
	var st := []
	var tt := 0.0
	var lv: Array = TVL.lv
	var last := -1
	while tt < LEN + 1.0:
		var i := rng.randi_range(0, lv.size() - 1)
		if i == last:
			i = (i + 2) % lv.size()
		last = i
		st.append([tt, float(lv[i])])
		var h: Array = TVL.hold
		tt += rng.randf_range(float(h[0]), float(h[1])) if rng.randf() > 0.2 else rng.randf_range(0.18, 0.35)
	hn.set_meta("tv_steps", st)


static func _tv_level(hn: Node, t: float) -> float:
	var v := 1.0
	for s in hn.get_meta("tv_steps"):
		if t >= float(s[0]):
			v = float(s[1])
	return v


# ══ 빛 ═══════════════════════════════════════════════════
#  세트의 빛을 찾아 이 장면 차림으로 — 채움 끄기 · 펜던트는 좁혀 겨눈다(가운데는 상인의 손 · 오른쪽은 손님 잔 —
#  단단한 그림자 · 주인공 것만 드리운다) · 선반 밑불은 병 뒤 밑으로(어깨만 빛나고 몸은 어둡다) · 안개는 TV 만.
static func _lights_make(hn: Node, w: Node3D, bar: Node3D) -> void:
	var L := {"pend": [], "shelf": []}
	var hands: Vector3 = (MERCH.at as Vector3) + Basis(Vector3.UP, deg_to_rad(float(MERCH.yaw))) * (MERCH.glass as Vector3)
	for n in bar.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		#  빛 이름도 겹쳐 붙으며 바뀐다 — 꼴 · 닿는 거리 · 빛깔로 가린다(Door3D _bar_lamps · _bar_back · _bar_darts · _bar_table ·
		#  _bar_deco · _inside)
		l.light_volumetric_fog_energy = 0.0
		l.light_specular = 0.0
		if l is SpotLight3D:
			if is_equal_approx((l as SpotLight3D).spot_range, 2.6):
				(L.pend as Array).append(l)
			else:
				#  그림등 — 판만(칠판 분필 점수는 어둠에 둔다 · 글로 읽히지 않게)
				(l as SpotLight3D).spot_angle = 14.0
				L["pict"] = l
			continue
		var o := l as OmniLight3D
		if is_equal_approx(o.omni_range, 0.85):
			(L.shelf as Array).append(l)
			o.position = Vector3(o.position.x, o.position.y - 0.11, float(Door3D.BAR.back) + 0.10)
			o.omni_range = 0.6
		elif is_equal_approx(o.omni_range, 5.2):
			o.light_energy = 0.0
			o.visible = false
		elif o.light_color.is_equal_approx(Color("ff9a50")):
			L["candle"] = l
		elif o.light_color.is_equal_approx(Color("f2a13a")):
			L["neon"] = l
	(L.pend as Array).sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.x < b.position.x)
	var pd: Array = L.pend
	if pd.size() == 3:
		var aims := [Vector3(float(pd[0].position.x), float(Door3D.BAR.cnt_y), float(Door3D.BAR.pend_z) - 0.08),
				hands + Vector3(0.0, -0.05, 0.05), Vector3(0.06, float(Door3D.BAR.cnt_y), -3.74)]
		var ang := [26.0, 22.0, 24.0]
		for i in 3:
			var s := pd[i] as SpotLight3D
			s.spot_angle = float(ang[i])
			s.spot_angle_attenuation = 1.0
			s.spot_range = 2.2
			s.light_cull_mask = L_IN | L_MERCH
			s.look_at_from_position(s.position, aims[i])
			if i > 0:
				s.shadow_enabled = true
				s.shadow_blur = 0.0
				s.light_size = 0.0
				s.shadow_opacity = 0.82
				s.shadow_bias = 0.03
				s.shadow_normal_bias = 1.0
				s.shadow_caster_mask = L_HERO
			if i == 1:
				s.light_volumetric_fog_energy = 0.12
	hn.set_meta("L", L)
	hn.set_meta("lt_last", {})


#  빛 표를 그 때까지 쌓은 몫
static func _light_at(t: float) -> Dictionary:
	var d := {}
	for row in LIGHT:
		if t >= float(row[0]):
			for k in row[1]:
				d[k] = row[1][k]
	return d


static func _lights(hn: Node, t: float) -> void:
	var L: Dictionary = hn.get_meta("L")
	var d := _light_at(t)
	var pd: Array = L.pend
	var pk := ["pl", "pm", "pr"]
	for i in mini(pd.size(), 3):
		(pd[i] as Light3D).light_energy = float(LBASE[pk[i]]) * float(d[pk[i]])
	for l in L.shelf:
		(l as Light3D).light_energy = float(LBASE.shelf) * float(d.shelf)
	for k in ["pict", "candle", "neon"]:
		if L.has(k):
			(L[k] as Light3D).light_energy = float(LBASE[k]) * float(d[k])
	#  제 빛 재질 — 그 빛과 같이(무리마다 밑 몫 × 지금 몫)
	var gl: Dictionary = hn.get_meta("glows")
	var gk := {"shelf": 0.15 * float(d.shelf), "cab": 0.85 * float(d.pict), "neon": 0.5 * float(d.neon),
			"candle": float(d.candle) / 0.7 * 0.8, "shade": 0.12 * maxf(float(d.pm), float(d.pr))}
	for grp in gl:
		for e in gl[grp]:
			(e.m as StandardMaterial3D).albedo_color = (e.c as Color) * clampf(float(gk[grp]), 0.0, 1.0)
	for df in hn.get_meta("diff", []):
		var x: float = df.x
		var k: float = float(d.pl) if x < -1.0 else (float(d.pm) if x < 0.0 else float(d.pr))
		(df.m as StandardMaterial3D).albedo_color = Color("b89a6a") * (0.05 + 0.5 * k) * (0.6 if x < -1.0 else 1.0)
	#  채움 — 바뀐 때만 재질을 다 고친다
	var fk: float = float(d.fill)
	if not is_equal_approx(float((hn.get_meta("lt_last") as Dictionary).get("fill", -1.0)), fk):
		(hn.get_meta("lt_last") as Dictionary)["fill"] = fk
		for m in hn.get_meta("ins"):
			(m as ShaderMaterial).set_shader_parameter("fill", FILL * fk)
	#  TV — 찬 빛 단 · 그림이 비친 뒤 덜 차다 · 유리 반짝 줄 · 맥주 뒤 빛
	var tvk: float = _tv_level(hn, t)
	var tc: Color = TVL.c if t < float(T.feed) else TVL.c2
	var tl: Array = hn.get_meta("tvl", [])
	if tl.size() == 2:
		(tl[0] as SpotLight3D).light_energy = float(TVL.e) * tvk
		(tl[0] as SpotLight3D).light_color = tc
		(tl[1] as OmniLight3D).light_energy = float(TVL.rim) * tvk
		(tl[1] as OmniLight3D).light_color = tc
	var ps: Array = []
	for i in mini(pd.size(), 3):
		ps.append((pd[i] as Node3D).global_position)
	if ps.size() == 3:
		for gm in hn.get_meta("glass", []):
			var m := gm as ShaderMaterial
			m.set_shader_parameter("lp0", Vector4(ps[1].x, ps[1].y, ps[1].z, 0.9 * float(d.pm)))
			m.set_shader_parameter("lp1", Vector4(ps[2].x, ps[2].y, ps[2].z, 0.9 * float(d.pr)))
			if tl.size() == 2:
				var tp: Vector3 = (tl[0] as Node3D).global_position
				m.set_shader_parameter("lp2", Vector4(tp.x, tp.y, tp.z, 0.7 * tvk))
				m.set_shader_parameter("lc2", tc)
	if hn.has_meta("rack_glass") and tl.size() == 2:
		var rp: Vector3 = (tl[1] as Node3D).global_position
		var rg := hn.get_meta("rack_glass") as ShaderMaterial
		rg.set_shader_parameter("lp2", Vector4(rp.x, rp.y, rp.z, tvk))
		rg.set_shader_parameter("lc2", tc)
	if hn.has_meta("beer"):
		(hn.get_meta("beer") as ShaderMaterial).set_shader_parameter("glow", 0.05 + 0.1 * tvk)
	var scr: ShaderMaterial = hn.get_meta("scr")
	if scr != null:
		scr.set_shader_parameter("refl", 0.9 * float(d.pm))
	#  깨는 노출 — 둘째 깜박임까지 한 단 밝다가 그 자리에서 내린다(빛이 먼저 · 모양이 뒤)
	(hn.get_meta("env") as Environment).tonemap_exposure = 1.35 if t < 2.32 else 1.0


# ══ 효과 ═════════════════════════════════════════════════
static func _post_make(hn: Node, w: Node3D) -> void:
	var q := MeshInstance3D.new()
	q.name = "Post"
	var qm := QuadMesh.new()
	qm.size = Vector2(2.0, 2.0)
	q.mesh = qm
	var sh := Shader.new()
	sh.code = POST_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = -100
	q.material_override = m
	q.extra_cull_margin = 16384.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(q)
	hn.set_meta("post", m)


static func _post_tick(hn: Node, t: float) -> void:
	var row: Array = FOCUS[0]
	for r in FOCUS:
		if t >= float(r[0]):
			row = r
	var ms: Array = [hn.get_meta("post")] + (hn.get_meta("glass", []) as Array)
	if hn.has_meta("rack_glass"):
		ms.append(hn.get_meta("rack_glass"))
	if hn.has_meta("table_glass"):
		ms.append(hn.get_meta("table_glass"))
	for m in ms:
		(m as ShaderMaterial).set_shader_parameter("f0", float(row[1]))
		(m as ShaderMaterial).set_shader_parameter("f1", float(row[2]))
		(m as ShaderMaterial).set_shader_parameter("bmin", float(row[3]))
		(m as ShaderMaterial).set_shader_parameter("bmax", float(row[4]))


#  눈꺼풀 — 무대 화판 위 2D 두 장(논리 px 에 그려 테가 도트 계단이다). 틈은 렌즈 꼴 — 가운데가 넓고 귀가 좁다.
#  감긴 선은 높이 85% · 위 눈꺼풀이 그만큼 · 밑 눈꺼풀은 15% 만 움직인다.
static func _lids_make(hn: Node, vp: SubViewport) -> void:
	var up := Polygon2D.new()
	var lo := Polygon2D.new()
	vp.add_child(up)
	vp.add_child(lo)
	hn.set_meta("lids", [up, lo])


static func _lid(t: float) -> float:
	for i in range(1, LID.size()):
		var b: Array = LID[i]
		if t <= float(b[0]):
			var a: Array = LID[i - 1]
			var u: float = (t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			return lerpf(float(a[1]), float(b[1]), clampf(u, 0.0, 1.0))
	return float(LID[LID.size() - 1][1])


static func _lids_tick(hn: Node, t: float) -> void:
	var lids: Array = hn.get_meta("lids")
	var vs: Vector2 = Vector2((hn.get_meta("vp") as SubViewport).size)
	var o: float = _lid(t)
	var col: Color = SKIN[0] if t < 1.2 else (SKIN[1] if t < 1.5 else Color.BLACK)
	for l in lids:
		(l as Polygon2D).visible = o < 0.999
		(l as Polygon2D).color = col
	if o >= 0.999:
		return
	var W: float = vs.x
	var H: float = vs.y
	var pu := PackedVector2Array([Vector2(W + 2.0, -2.0), Vector2(-2.0, -2.0)])
	var pl := PackedVector2Array([Vector2(W + 2.0, H + 2.0), Vector2(-2.0, H + 2.0)])
	var n := 40
	for i in n + 1:
		var x: float = W * float(i) / float(n)
		var u: float = float(i) / float(n) * 2.0 - 1.0
		var lens: float = 1.0 - 0.38 * u * u
		pu.append(Vector2(x, 0.85 * H - o * 1.5 * H * lens + 0.5))
		pl.append(Vector2(x, 0.85 * H + o * 0.32 * H * lens - 0.5))
	(lids[0] as Polygon2D).polygon = pu
	(lids[1] as Polygon2D).polygon = pl


#  층 — 무대 · 화판 그림(Feed — 다이브 끝에 깐다). 무대 그림에만 필름 말(Plg GRADE_SHADER · 낟알 0 — 그늘은 차게 ·
#  밝은 데는 따뜻하게). 자리는 tick 이 화판(outer.box)에 맞춘다.
static func _layer_make(hn: Node, vp: SubViewport, feed: Texture2D, outer: Node) -> void:
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
	for pr in [["Stage", vp.get_texture()], ["Feed", feed]]:
		var tr := TextureRect.new()
		tr.name = String(pr[0])
		tr.texture = pr[1]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(tr)
		if pr[0] == "Stage":
			var gs := Shader.new()
			gs.code = Plg.GRADE_SHADER
			var gm := ShaderMaterial.new()
			gm.shader = gs
			var gd: Array = Plg.LOOK.grade
			for pk in [["lift", gd[0]], ["cool", gd[1]], ["warm", gd[2]]]:
				var pc: Color = pk[1]
				gm.set_shader_parameter(String(pk[0]), Vector3(pc.r, pc.g, pc.b))
			gm.set_shader_parameter("grain", Vector2.ZERO)
			gm.set_shader_parameter("px", Vector2(vp.size))
			tr.material = gm
			hn.set_meta("grade", gm)
	(root.get_node("Feed") as CanvasItem).modulate.a = 0.0
	hn.set_meta("outer", outer)
	hn.set_meta("root", root)


static func _layer(hn: Node, t: float) -> void:
	var root := hn.get_meta("root") as Control
	var outer: Node = hn.get_meta("outer")
	var box: Control = outer.get("box") as Control if outer != null else null
	if box != null:
		root.position = box.position
		root.size = box.size
	root.modulate.a = 1.0 - clampf((t - handoff()) / float(T.fade), 0.0, 1.0)


# ══ 카메라 ═══════════════════════════════════════════════
#  고개 — 0.75 몫 동안 3% 넘게 가서(고르게 빨라졌다 느려진다) 나머지 동안 제자리로 돌아와 선다
static func _back(u: float) -> float:
	if u < 0.75:
		return 1.03 * smoothstep(0.0, 1.0, u / 0.75)
	return 1.0 + 0.03 * (1.0 - smoothstep(0.0, 1.0, (u - 0.75) / 0.25))


static func _pose_at(t: float) -> Array:
	var cur: Array = POSE.cheek
	for mv in MOVE:
		var t0: float = mv[0]
		var t1: float = mv[1]
		if t < t0:
			break
		var a: Array = POSE[mv[2]]
		var b: Array = POSE[mv[3]]
		if t >= t1 or String(mv[4]) == "cut":
			cur = b
			continue
		var u: float = (t - t0) / (t1 - t0)
		var fe := u
		var fr := u
		var dip := 0.0
		match String(mv[4]):
			"lift":
				fe = 1.0 - pow(1.0 - u, 3.0)
				fr = 1.0 - pow(1.0 - clampf((u - 0.2) / 0.8, 0.0, 1.0), 2.0)
				dip = 0.22 * sin(PI * u)          # 드는 동안 눈길이 카운터 쪽으로 처진다(굴린 그림 위끝이 상인 깃을 안 지나게)
			"look":
				fe = 0.12 * clampf((t - t0) / 0.05, 0.0, 1.0) + 0.88 * _back(u)
				fr = fe
				dip = 0.1 * sin(PI * clampf(u / 0.75, 0.0, 1.0))      # 고개는 낮은 호로 돈다(굽은 길)
			"push":
				fe = u * u * (3.0 - 2.0 * u)
				fr = fe
		return [(a[0] as Vector3).lerp(b[0], fe), (a[1] as Vector3).lerp(b[1], fe) - Vector3(0.0, dip, 0.0),
				lerpf(float(a[2]), float(b[2]), fr),
				lerpf(float(a[3]), float(b[3]), fe)]
	return cur


static func _cam(hn: Node, t: float) -> void:
	var cam := hn.get_meta("cam") as Camera3D
	var p := _pose_at(t)
	var eye: Vector3 = p[0]
	var look: Vector3 = p[1]
	var fov: float = p[3]
	var u: float = clampf((t - float(T.dive0)) / (float(T.dive1) - float(T.dive0)), 0.0, 1.0)
	if u > 0.0 and hn.has_meta("end"):
		var ce: Dictionary = hn.get_meta("end")
		var e: float = u * u * (3.0 - 2.0 * u)
		eye = eye.lerp(ce.at, e)
		look = look.lerp(ce.look, e)
	cam.fov = fov
	cam.look_at_from_position(eye, look, Vector3.UP)
	if absf(float(p[2])) > 0.01:
		cam.rotate_object_local(Vector3.BACK, deg_to_rad(float(p[2])))
	#  유리 속 — 그림이 화면에 박힌 게임 그림으로 옮겨 가고(portal) · 끝에 화판 그림을 깐다 · 필름 말 · 안개가 걷힌다
	var po: float = smoothstep(float(Plg.HERO.portal[0]), float(Plg.HERO.portal[1]), u)
	var scr: ShaderMaterial = hn.get_meta("scr")
	if scr != null:
		scr.set_shader_parameter("portal", po)
	var root := hn.get_meta("root") as Control
	(root.get_node("Feed") as CanvasItem).modulate.a = smoothstep(float(Plg.HERO.flat[0]), float(Plg.HERO.flat[1]), u)
	var gk: float = 1.0 - smoothstep(float(Plg.LOOK.gone[0]), float(Plg.LOOK.gone[1]), u)
	(hn.get_meta("grade") as ShaderMaterial).set_shader_parameter("k", gk)
	(hn.get_meta("env") as Environment).volumetric_fog_density = 0.006 * gk


#  TV 화면 — 시계 · 지지직 몫(단)
static func _tv_tick(hn: Node, t: float) -> void:
	var scr: ShaderMaterial = hn.get_meta("scr")
	if scr == null:
		return
	scr.set_shader_parameter("tm", t)
	scr.set_shader_parameter("snowk", _snow(t))


static func _snow(t: float) -> float:
	var v := 1.0
	for s in SNOW:
		if t >= float(s[0]):
			v = float(s[1])
	return v


# ══ 소리 ═════════════════════════════════════════════════
#  방 소리 · 닦기(순환) · 먼 잔 · 잔 놓기 · 딸깍(한 번)은 제 버스(BarAmb_… — 로패스가 눈과 같이 열리고 빛이 꺼지는 단마다
#  닫히고 다이브에 다 닫힌다) · TV 지지직 · 웅(순환)은 SFX(먹먹해지지 않는다). 넘김에 버스를 걷는다.
#  clink 먼 잔 · lp 로패스 [닫힘 · 열림](Hz) · static TV 지지직 [감은 눈 · 화면 밖(눈 뜬 뒤) · 올려다본 뒤](dB) · hum 웅(같은 차례) ·
#  click 빛 딸깍 · tv 그림이 비치는 동안 SFX 에 거는 작은 스피커 [고역 통과 · 저역 통과(Hz) · 줄임(dB)] — 게임 인트로 소리가
#  TV 소리로 들리다가 유리 속으로 들며(넘김) 걷힌다
const SND := {"clink": 0.8, "lp": [600.0, 16000.0], "static": [-24.0, -15.0, 0.0], "hum": [-20.0, -12.0, 0.0],
		"click_db": -8.0, "tv": [350.0, 4800.0, -4.0]}


static func _loop(g: Node, nm: String) -> AudioStreamWAV:
	var st := g._sfx_file(nm) as AudioStreamWAV if g.has_method("_sfx_file") else null
	if st == null:
		return null
	st = st.duplicate() as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = int(st.get_length() * float(st.mix_rate))
	return st


static func _audio_make(hn: Node, g: Node) -> void:
	if AudioServer.get_bus_index("SFX") < 0 or g == null:
		return
	var bus := "BarAmb_%d" % hn.get_instance_id()
	var bi := AudioServer.bus_count
	AudioServer.add_bus(bi)
	AudioServer.set_bus_name(bi, bus)
	AudioServer.set_bus_send(bi, "SFX")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = float(SND.lp[0])
	lp.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(bi, lp)
	(hn as Hold).bus = bus
	hn.set_meta("lp", lp)
	var pl := {}
	for k in [["room", "bar_room", bus], ["polish", "bar_polish", bus], ["static", "bar_tv_static", "SFX"],
			["hum", "bar_tv_hum", "SFX"]]:
		var st := _loop(g, String(k[1]))
		if st == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.bus = String(k[2])
		hn.add_child(p)
		pl[k[0]] = p
	hn.set_meta("snd", pl)
	hn.set_meta("rang", {})


static func _shot(hn: Node, nm: String, bus: String, db := 0.0, pitch := 1.0) -> void:
	var g: Node = hn.get_meta("game")
	var st: AudioStream = g._sfx_file(nm) if g != null and g.has_method("_sfx_file") else null
	if st == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = bus
	p.volume_db = db
	p.pitch_scale = pitch
	hn.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


static func _audio_tick(hn: Node, t: float) -> void:
	if not hn.has_meta("snd"):
		return
	var pl: Dictionary = hn.get_meta("snd")
	var rang: Dictionary = hn.get_meta("rang")
	var bus: String = (hn as Hold).bus
	var bi := AudioServer.get_bus_index(bus) if bus != "" else -1
	if not rang.has("start"):
		rang["start"] = true
		for k in pl:
			(pl[k] as AudioStreamPlayer).play()
	#  눈과 같이 열리는 로패스(로그 눈금) — 감으면 0 · 반쯤 0.45 · 첫 뜸 뒤 깜박임은 0.3 까지만 · 빛이 꺼지는 단마다 닫힌다 ·
	#  다이브에 다 닫힌다
	var k: float = _lid(t)
	if t > 2.0:
		k = maxf(k, 0.3)
	var steps := [1.0, 0.85, 0.7, 0.58, 0.45, 0.35, 0.25]
	var n := 0
	for c in CLICK:
		if t >= float(c):
			n += 1
	k = minf(k, float(steps[n]))
	var du: float = clampf((t - float(T.dive0)) / (float(T.dive1) - float(T.dive0)), 0.0, 1.0)
	k *= 1.0 - du
	if hn.has_meta("lp"):
		var lf: Array = SND.lp
		(hn.get_meta("lp") as AudioEffectLowPassFilter).cutoff_hz = float(lf[0]) * pow(float(lf[1]) / float(lf[0]), k)
	if bi >= 0:
		AudioServer.set_bus_volume_db(bi, linear_to_db(maxf(1.0 - 0.12 * float(n), 0.05) * (1.0 - du * 0.999)))
	#  닦기 — 고쳐 쥘 때 잦아들고 내려놓으면 멎는다(박자는 시작부터 비틀기와 같다)
	if pl.has("polish"):
		var pp := pl.polish as AudioStreamPlayer
		var rg: Array = POLISH.regrip
		var q: float = 1.0 if (t < float(rg[0]) or t > float(rg[1])) else 0.2
		pp.volume_db = linear_to_db(q) - 3.0
		if t >= float(POLISH.down[0]) and pp.playing:
			pp.stop()
	#  TV — 지지직은 그림이 비칠수록 단으로 잦아들고 · 웅은 올려다볼 때부터 크다
	if pl.has("static"):
		var sk: float = _snow(t)
		var sp := pl.static as AudioStreamPlayer
		var sd: Array = SND.static
		var near: float = float(sd[2]) if t >= 6.5 else (float(sd[1]) if t >= 2.3 else float(sd[0]))
		sp.volume_db = near + linear_to_db(0.3 + 0.7 * sk)
		if t > handoff() and sp.playing:
			sp.stop()
	if pl.has("hum"):
		var hp := pl.hum as AudioStreamPlayer
		var hd: Array = SND.hum
		hp.volume_db = float(hd[2]) if t >= 6.5 else (float(hd[1]) if t >= 2.3 else float(hd[0]))
		hp.volume_db += linear_to_db(1.0 - clampf((t - handoff()) / float(T.fade), 0.0, 0.999))
	#  한 번씩 — 먼 잔 · 잔 놓기 · 빛이 꺼질 때마다 딸깍
	if t >= float(SND.clink) and not rang.has("clink"):
		rang["clink"] = true
		_shot(hn, "bar_clink", bus)
	if t >= float(POLISH.down[1]) and not rang.has("down"):
		rang["down"] = true
		_shot(hn, "bar_glass_down", bus, -2.0)
	for i in CLICK.size():
		var ck := "click%d" % i
		if t >= float(CLICK[i]) and not rang.has(ck):
			rang[ck] = true
			_shot(hn, "deck_grab", bus, float(SND.click_db), 0.72)
	#  TV 스피커 — 그림이 비치는 동안 게임 인트로 소리(SFX)를 작은 통 소리로 · 넘김에 걷는다
	var tv_on: bool = t >= float(T.feed) and t < handoff()
	if tv_on != (not (hn as Hold).spk.is_empty()):
		if tv_on:
			(hn as Hold).spk_on()
		else:
			(hn as Hold).spk_off()
	#  넘김 — 방 소리 자리 · 버스를 걷는다(TV 웅은 층과 같이 잦아든다)
	if t >= handoff() and bi >= 0:
		for kk in ["room", "polish"]:
			if pl.has(kk):
				(pl[kk] as AudioStreamPlayer).stop()
		AudioServer.remove_bus(bi)
		(hn as Hold).bus = ""


# ══ 한 틀 ═════════════════════════════════════════════════
static func tick(hn: Node, t: float) -> void:
	hn.set_meta("t", t)
	_layer(hn, t)
	_lights(hn, t)
	_merch_tick(hn, t)
	_tv_tick(hn, t)
	_cam(hn, t)
	_post_tick(hn, t)
	_lids_tick(hn, t)
	_audio_tick(hn, t)
