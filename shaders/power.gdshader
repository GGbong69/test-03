shader_type canvas_item;
render_mode unshaded;

//  브라운관 켜기 · 끄기(2026-10-06) — game.gd 의 PWR 층(맨 위)에 깔린 온 화면 ColorRect 가 쓴다.
//  CRT 필터까지 다 그려진 화면을 한 번 따서 다시 뱉는다. 도는 동안만 층이 선다.
//
//    켜기  ① 검은 화면 가운데에 흰 실 한 줄이 옆으로 뻗는다(앞 a_on)
//          ② 그 줄이 위아래로 벌어지며 그림이 선다 — 처음엔 과하게 밝고 가라앉는다.
//             벌어지는 위아래 가장자리가 빔이 막 닿은 듯 희다.
//    끄기  ① 그림이 가운데 한 줄로 눌리며 밝아진다(앞 a_off)
//          ② 그 줄이 옆에서 줄어 점이 된다(b_off 까지)
//          ③ 점이 사그라진다 — 마지막 틀은 검정이다.
//
//  p 는 흐른 몫(0 → 1). 화면 가운데에서 논리 px 로 잰다 — logical 은 지금 보이는 논리
//  크기(expand 라 16:10 이면 640x400)다. 실 두께가 화면 배율과 상관없이 논리 2px 쯤이다.

uniform sampler2D scene : hint_screen_texture, filter_nearest, repeat_disable;
uniform float p : hint_range(0.0, 1.0) = 0.0;
uniform float on = 1.0;                       // 1 켜기 · 0 끄기
uniform vec2 logical = vec2(640.0, 360.0);
uniform float a_on = 0.16;                    // 켜기 — 실이 뻗는 몫
uniform float a_off = 0.42;                   // 끄기 — 그림이 눌리는 몫
uniform float b_off = 0.80;                   // 끄기 — 실이 점이 되는 몫까지
uniform float line_h = 1.1;                   // 실의 반 두께(논리 px)
uniform vec3 beam = vec3(0.92, 0.96, 1.0);    // 빔의 흰빛(살짝 푸르다)

float eo(float x) {
	x = clamp(x, 0.0, 1.0);
	return 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x);
}

float ei(float x) {
	x = clamp(x, 0.0, 1.0);
	return x * x * x;
}

//  가운데 한 줄 — 반폭 hw(논리 px)
float strand(vec2 d, float hw) {
	float v = 1.0 - smoothstep(line_h - 0.4, line_h + 0.8, abs(d.y));
	return v * (1.0 - smoothstep(hw - 3.0, hw + 3.0, abs(d.x)));
}

//  가운데에서 sx · sy 배로 눌린 그림. a 는 띠 안(1) · 밖(0) — 빔의 흰 김도 띠 안에만 얹는다.
vec4 squeezed(vec2 d, vec2 L, float sx, float sy) {
	vec2 s = vec2(d.x / sx, d.y / sy);
	if (abs(s.x) > L.x * 0.5 || abs(s.y) > L.y * 0.5) {
		return vec4(0.0);
	}
	return vec4(texture(scene, s / L + 0.5).rgb, 1.0);
}

void fragment() {
	vec2 L = max(logical, vec2(1.0));
	vec2 d = (SCREEN_UV - 0.5) * L;
	vec3 col = vec3(0.0);
	if (on > 0.5) {
		if (p < a_on) {
			float q = eo(p / a_on);
			col = beam * strand(d, mix(0.04, 0.5, q) * L.x) * mix(0.7, 1.6, q);
		} else {
			float q = (p - a_on) / (1.0 - a_on);
			float k = eo(q);
			float sy = mix(0.006, 1.0, k);
			float over = (1.0 - q) * (1.0 - q);
			vec4 g = squeezed(d, L, mix(1.04, 1.0, k), sy);
			col = (g.rgb * (1.0 + 2.2 * over) + beam * over * 0.45) * g.a;
			//  벌어지는 위아래 가장자리 — 빔이 막 닿은 결
			float edge = abs(abs(d.y) - sy * L.y * 0.5);
			col += beam * (1.0 - smoothstep(0.0, 2.0, edge)) * (1.0 - q) * 0.8;
		}
	} else {
		if (p < a_off) {
			float q = ei(p / a_off);
			vec4 g = squeezed(d, L, 1.0, mix(1.0, 0.006, q));
			col = (g.rgb * (1.0 + 3.0 * q) + beam * q * q * 0.8) * g.a;
			col += beam * strand(d, L.x * 0.5) * q * 1.2;
		} else if (p < b_off) {
			float q = ei((p - a_off) / (b_off - a_off));
			col = beam * strand(d, mix(0.5, 0.0, q) * L.x) * 1.6;
			col += beam * (1.0 - smoothstep(0.5, 2.6, length(d))) * q * 1.2;
		} else {
			float q = (p - b_off) / (1.0 - b_off);
			float r = mix(2.2, 0.4, q);
			col = beam * (1.0 - smoothstep(r - 0.5, r + 1.0, length(d))) * (1.0 - q) * 1.4;
		}
	}
	COLOR = vec4(col, 1.0);
}
