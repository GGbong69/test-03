shader_type canvas_item;
render_mode unshaded;

//  보스 판 등장 — 흑백 TV(game.gd 의 BOSSTV 머리말 · 2026-10-10 필기 「흑백 TV 효과」 →
//  「보스 판 등장」). 판이 다 선 순간 화면이 옛 흑백 브라운관으로 떨어진다 — 수직 동기를
//  한 번 놓쳐 그림이 위로 미끄러졌다 돌아오고, 줄마다 가로로 떨리고, 밝은 띠가 위에서
//  아래로 굴러 내려가고, 낟알이 낀다. 색이 한 번 돌아오려다 다시 꺼지고, 그 뒤 천천히 돈다.
//  층(CanvasLayer 93)이 덮개(95) · 도트(97) · VHS(98) · CRT(100) 밑이라 브라운관 결은 그
//  위에 그대로 선다.
//
//  자는 논리 px — static.gdshader 와 같다(logical 로 재서 줄 하나가 논리 1px 이다).
//  snow 0 — 설정 「전환 지지직」 끔(눈이 아프다는 평). 낟알 · 띠 · 떨림 · 미끄럼 · 줄결 없이 흑백만.

uniform sampler2D scene : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec2 logical = vec2(640.0, 360.0);
uniform float bw = 0.0;        // 흑백 0..1 — 0 이면 원래 화면 그대로
uniform float snow = 1.0;      // 결(낟알 · 띠 · 떨림 · 줄결) 0..1
uniform float clock = 0.0;
uniform float slip = 0.0;      // 세로 미끄럼(화면 비) — 수직 동기를 놓친 순간
uniform float jit = 0.0;       // 줄마다 가로 떨림(논리 px)
uniform float roll = -1.0;     // 굴러가는 밝은 띠의 한가운데(화면 비 · 위 0 → 아래 1)
uniform float grain = 0.09;    // 낟알 세기
uniform float band_a = 0.12;   // 띠 밝기
uniform float band_w = 0.07;   // 띠 두께(화면 비)
uniform float lines = 0.07;    // 줄결 — 짝 줄을 이만큼 어둡게
uniform float vig = 0.55;      // 가장자리 어둠
uniform float tint = 0.04;     // 인광 — 흰 쪽이 조금 푸르다
uniform float blank = 0.035;   // 미끄러진 이음매의 검은 띠(화면 비) — 수직 귀선 구간

float h12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float fr = floor(clock * 30.0);
	float ln = floor(uv.y * logical.y);
	float sl = slip * snow;
	uv.y = fract(uv.y + sl);
	float lj = floor(uv.y * logical.y);
	uv.x += (h12(vec2(lj, fr)) - 0.5) * 2.0 * jit * snow / logical.x;
	vec3 c = texture(scene, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	//  대비를 조금 세운다 — 흑백 브라운관의 검정은 깊고 흰색은 번진다.
	l = mix(l, smoothstep(0.03, 0.97, l), 0.35);
	vec3 g = vec3(l) * vec3(1.0 - tint, 1.0, 1.0 + tint);
	float px = floor(SCREEN_UV.x * logical.x);
	g += (h12(vec2(px, ln) + fr * 7.13) - 0.5) * grain * snow;
	float dy = SCREEN_UV.y - roll;
	g += exp(-dy * dy / max(band_w * band_w, 0.0001)) * band_a * snow;
	g *= 1.0 - lines * snow * step(0.5, fract(ln * 0.5));
	vec2 q = SCREEN_UV - vec2(0.5);
	g *= 1.0 - vig * dot(q, q);
	vec3 o = mix(c, clamp(g, vec3(0.0), vec3(1.0)), bw);
	//  미끄러진 동안 그림의 끝과 처음이 만나는 자리(1 - sl)에 귀선 구간이 검게 선다.
	if (sl > 0.001) {
		float sy = 1.0 - sl;
		o *= smoothstep(0.0, 0.006, abs(SCREEN_UV.y - sy) - blank * 0.5);
	}
	COLOR = vec4(o, 1.0);
}
