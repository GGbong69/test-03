shader_type canvas_item;

//  게임 오버 — 다트판이 카메라로 덮쳐 온다(game.gd 의 OVERC 머리말).
//  화면을 읽어 한 점(다트판 한가운데)을 중심으로 키운다. 키울수록 그 점 쪽으로 번지고
//  (방사 흐림 — 다가오는 속도), 조금 돌고, 가장자리부터 어두워져 마지막에 검다.
//  층(CanvasLayer 90)이 CRT(100) 밑이라 브라운관 결은 그 위에 그대로 선다.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform vec2 center = vec2(0.5);   // 다가오는 점(화면 UV)
uniform float zoom = 1.0;          // 키움 — 1 이면 그대로
uniform float spin = 0.0;          // 도는 각(라디안)
uniform float blur = 0.0;          // 방사 흐림 세기 0..1
uniform float dark = 0.0;          // 어둠 0..1 — 1 이면 검다
uniform float aspect = 1.7778;     // 화면 가로 / 세로

vec3 sample_at(vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return vec3(0.0);
	}
	return texture(screen_tex, uv).rgb;
}

void fragment() {
	vec2 d = SCREEN_UV - center;
	d.x *= aspect;
	float c = cos(spin);
	float s = sin(spin);
	d = vec2(c * d.x - s * d.y, s * d.x + c * d.y);
	d /= max(zoom, 0.001);
	d.x /= aspect;
	vec3 col = vec3(0.0);
	float tot = 0.0;
	for (int i = 0; i < 6; i++) {
		float f = 1.0 - blur * 0.18 * float(i);
		float w = 1.0 - float(i) / 7.0;
		col += sample_at(center + d * f) * w;
		tot += w;
	}
	col /= tot;
	//  가장자리부터 닫힌다 — 어둠이 오를수록 고리가 다가오는 점 쪽으로 좁혀 든다.
	vec2 q = (SCREEN_UV - vec2(0.5)) * vec2(aspect, 1.0);
	float vig = smoothstep(1.15 - dark * 0.9, 1.25 - dark * 0.6, length(q));
	col *= (1.0 - vig) * (1.0 - dark * dark);
	COLOR = vec4(col, 1.0);
}
