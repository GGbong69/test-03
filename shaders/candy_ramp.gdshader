shader_type spatial;
render_mode unshaded, cull_back, depth_prepass_alpha;

//  ══════════════════════════════════════════════════════════
//   사탕 — 네 단 램프 + 반짝임 한 점
//  ──────────────────────────────────────────────────────────
//   다트통 통(cup_ramp)과 같은 어법이다 — 빛을 계산하지 않고 문턱으로
//   단을 고른다. 다른 것은 **반짝임** 하나다. 하드 캔디 · 젤리 · 은박이
//   진짜로 보이는 것은 빛 쪽에 선 흰 점 한 개 덕분인데, 통의 광택은 램프
//   꼭대기 단(주황이면 f7ba70)까지만 올라가서 사탕이 점토로 읽혔다.
//   glint 는 램프 밖 한 색(cream 3단 fbf6ea)이다 — 팔레트 밖 색을 새로
//   짓지 않는다(ART_PAL 주석).
//
//   cup_ramp 를 안 고친 까닭: 다트 자루 칠(_cup3_dart_toon)이 그 셰이더를
//   같이 쓴다. 사탕 몫은 이 파일 하나에 둔다(2026-10-16).
//  ══════════════════════════════════════════════════════════

uniform vec4 r0 : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 r1 : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform vec4 r2 : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform vec4 r3 : source_color = vec4(0.9, 0.9, 0.9, 1.0);
//  둘째 램프 — 질감 G 가 켜진 자리(지팡이 · 막대사탕의 흰 줄, 꼬인 사탕의 줄).
uniform vec4 b0 : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 b1 : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform vec4 b2 : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform vec4 b3 : source_color = vec4(0.9, 0.9, 0.9, 1.0);

uniform float base = 1.0;
uniform float base_b = 1.0;
uniform float t_hi = 0.55;
uniform float t_lo = 0.0;
uniform float bounce_on = 1.0;
uniform float spec_th = 0.0;     // 램프 꼭대기 단으로 올리는 광택 문턱
uniform float spec_s = 3.0;
uniform float glint_th = 0.0;    // 흰 점 문턱. 0 이면 없다
uniform vec4 glint : source_color = vec4(0.984, 0.965, 0.918, 1.0);
//  젤리 속 빛. 그늘 쪽이라도 빛 반대편 가장자리는 한 단 올린다 —
//  빛이 젤리를 지나 반대쪽 테로 새는 것(곰젤리가 고무가 아니라 젤리로 읽힌다).
uniform float gel = 0.0;

uniform float lamp = 1.0;        // 다트통 무대 램프(선물 통 발치의 젤리만 받는다)

uniform sampler2D pat : filter_nearest, repeat_enable, hint_default_white;
uniform float use_pat = 0.0;
uniform float use_mask = 0.0;

uniform vec3 to_light = vec3(-0.5417, 0.7071, 0.4545);


vec3 ramp4(vec3 c0, vec3 c1, vec3 c2, vec3 c3, float s) {
	float i = clamp(floor(s + 0.5), 0.0, 3.0);
	vec3 lo = mix(c0, c1, clamp(i, 0.0, 1.0));
	vec3 hi = mix(c2, c3, clamp(i - 2.0, 0.0, 1.0));
	return mix(lo, hi, step(1.5, i));
}


void fragment() {
	vec3 lw = normalize(to_light);
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float ndl = dot(nw, lw);

	float off = 0.0;
	bool alt = false;
	if (use_pat > 0.5) {
		vec4 p = texture(pat, UV);
		off = floor((p.r - 0.5) * 4.0 + 0.5);
		alt = (use_mask > 0.5 && p.g > 0.5);
	}
	float bs = alt ? base_b : base;
	float s = bs + off;
	s += (ndl > t_hi) ? 1.0 : 0.0;
	s -= (ndl < t_lo) ? 1.0 : 0.0;
	s -= (1.0 - lamp);

	float rim = 1.0 - dot(NORMAL, VIEW);
	if (bounce_on > 0.5 && rim > 0.8 && ndl < 0.0) {
		s = max(s, bs);
	}
	if (gel > 0.5 && ndl < -0.25 && rim > 0.55) {
		s = max(s, bs + 1.0);
	}

	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float hv = dot(nw, normalize(lw + vw));
	if (spec_th > 0.0 && hv > spec_th) {
		s = max(s, spec_s);
	}
	vec3 c = alt ? ramp4(b0.rgb, b1.rgb, b2.rgb, b3.rgb, s)
			: ramp4(r0.rgb, r1.rgb, r2.rgb, r3.rgb, s);
	if (glint_th > 0.0 && hv > glint_th && lamp > 0.5) {
		c = glint.rgb;
	}
	ALBEDO = c;
}
