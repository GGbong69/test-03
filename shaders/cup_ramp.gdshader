shader_type spatial;
//  깊이 선통과에서도 같은 식을 돌린다. discard 를 쓰는데 선통과가 원래
//  프래그먼트를 안 돌리면 구멍 자리가 깊이에만 남아 뒤가 지워진다.
render_mode unshaded, cull_back, depth_prepass_alpha;

//  ══════════════════════════════════════════════════════════
//   다트통 통 — 네 단 램프 셰이더
//  ──────────────────────────────────────────────────────────
//   이 게임의 그림은 전부 **네 단 램프**로 칠해져 있다(coin_paint.PAL).
//   판 얼굴 · 와펜 · 동전이 그렇게 칠해졌는데, 통만 매끈한 램버트라
//   열셋이 나란히 선 화면에서 통만 다른 게임의 물건으로 보였다.
//
//   그래서 빛을 **계산**하지 않고 **고른다.** 램버트 값을 그라데이션으로
//   쓰는 대신 임계값 둘로 단을 가른다 — 빛 띠(+1) · 몸(0) · 그늘(-1).
//   그 셋이 램프의 세 단으로 떨어지므로 통 픽셀이 100% 팔레트 안에 남는다.
//
//   선형식(base + gain*ndl)을 먼저 써 봤는데(프로토타입 v4) 통이 거의
//   한 단으로 눌려 원통이 평평해졌다. 램프가 몇 단인지가 아니라 **어디서
//   갈리는지**가 원통을 세운다.
//
//   참고(구성·색·규칙만. 어떤 그림도 베끼지 않았다)
//     lospec.com 「pixel art cylinder」— 원통 앞면은 빛 띠 · 몸 · 그늘 셋이고
//         그늘 쪽 가장자리에 반사광 1px 이 선다
//     slynyrd.com 「pixelblog — shading」— 2px 가 기본 단위 · 1px 반복 줄 금지
//     saint11.art pixel art article 4 — 광원 하나 · 곡면은 램프 방향으로만
//  ══════════════════════════════════════════════════════════

//  ── 램프 ─────────────────────────────────────────
//  넷을 따로 둔다. 힌트 달린 배열(uniform vec4 r[4] : source_color)은
//  고닷 판마다 받아 주는 문법이 갈려서, 판을 올리면 잠자코 검게 나온다.
uniform vec4 r0 : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 r1 : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform vec4 r2 : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform vec4 r3 : source_color = vec4(0.9, 0.9, 0.9, 1.0);

//  두 번째 램프. 질감의 G 채널이 켜진 자리만 이쪽으로 간다 —
//  일당 병의 금 동전층, 무쇠의 녹, [?? ???] 의 박음질이 그것이다.
//  한 통에 재질 둘을 그리려고 메시를 둘로 가르면 z-fight 가 난다.
uniform vec4 b0 : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 b1 : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform vec4 b2 : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform vec4 b3 : source_color = vec4(0.9, 0.9, 0.9, 1.0);

//  ── 단 ───────────────────────────────────────────
uniform float base = 1.0;       // 빛도 그늘도 아닌 자리의 단
uniform float base_b = 1.0;     // 두 번째 램프 쪽의 그 값
uniform float t_hi = 0.55;      // 이 위는 빛 띠(+1). 9 로 두면 띠가 없다
uniform float t_lo = 0.0;       // 이 아래는 그늘(-1)
uniform float bounce_on = 1.0;  // 그늘 쪽 반사광 1px
uniform float spec_th = 0.0;    // 광택이 서는 반각 문턱. 0 이면 광택 없음
uniform float spec_s = 3.0;     // 광택의 단

//  ── 속 어둠 ──────────────────────────────────────
//  아가리 깊은 데가 어두워야 통이 뚫려 보인다. 그림자맵은 껐으므로
//  (138x118 에서 그림자맵은 계단만 남긴다) 이 한 줄이 그 일을 한다.
uniform float ao_inner = 0.0;
instance uniform float rim_h = 1.0;   // 이 통의 아가리 높이(월드). 통마다 다르다

//  ── 무대 램프 ────────────────────────────────────
//  0 이면 불이 꺼진 자리다 — 잠긴 다트통이 그렇다. 통 전체가 한 단 내려간다.
uniform float lamp = 1.0;
uniform float keep_lit = 0.0;   // 아가리·테는 불이 꺼져도 실루엣을 남긴다

//  ── 질감 ─────────────────────────────────────────
//  R = 단 오프셋 (0.5 → 0 · 0.25 → -1 · 0.75 → +1 · 1.0 → +2)
//  G = 두 번째 램프 플래그
//  A = 뚫림 (0.5 미만이면 구멍. 철망이 이것으로 진짜로 뚫린다)
//  **source_color 를 안 붙인다.** 붙이면 고닷이 이 그림을 sRGB 로 보고
//  샘플할 때 선형으로 옮기므로 R 0.5 가 0.214 로 떨어져, 단 오프셋이
//  온 통에 -1 로 걸린다(한 번 당했다 — 몸이 통째로 한 단 내려앉았다).
//  여기 R·G 는 색이 아니라 **수**다.
uniform sampler2D pat : filter_nearest, repeat_enable, hint_default_white;
uniform float use_pat = 0.0;
uniform float use_mask = 0.0;

//  ── 빛 ───────────────────────────────────────────
//  빛으로 **가는** 방향(월드). CUP3.light 의 회전에서 뽑은 값이라
//  2D 무대의 램프와 3D 의 키 라이트가 같은 데서 온다.
uniform vec3 to_light = vec3(-0.5417, 0.7071, 0.4545);

varying float wy;   // 월드 높이. 통은 서서 가로로만 미끄러지므로 곧 통 높이다


vec3 ramp4(vec3 c0, vec3 c1, vec3 c2, vec3 c3, float s) {
	float i = clamp(floor(s + 0.5), 0.0, 3.0);
	vec3 lo = mix(c0, c1, clamp(i, 0.0, 1.0));
	vec3 hi = mix(c2, c3, clamp(i - 2.0, 0.0, 1.0));
	return mix(lo, hi, step(1.5, i));
}


void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}


void fragment() {
	vec3 lw = normalize(to_light);
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float ndl = dot(nw, lw);

	//  질감 먼저. 두 번째 램프로 갈 자리는 base 부터 다르다.
	float off = 0.0;
	bool alt = false;
	if (use_pat > 0.5) {
		vec4 p = texture(pat, UV);
		if (p.a < 0.5) {
			discard;
		}
		off = floor((p.r - 0.5) * 4.0 + 0.5);
		alt = (use_mask > 0.5 && p.g > 0.5);
	}
	float bs = alt ? base_b : base;
	float s = bs + off;

	//  단 가르기. 그라데이션이 아니라 문턱이다.
	s += (ndl > t_hi) ? 1.0 : 0.0;
	s -= (ndl < t_lo) ? 1.0 : 0.0;

	//  속 어둠. 아가리(rim_h)에서 바닥으로 갈수록 깊어진다.
	s -= ao_inner * (1.0 - clamp(wy / max(rim_h, 0.0001), 0.0, 1.0));

	//  무대 램프가 꺼지면 통이 한 단 내려앉는다.
	s -= (1.0 - lamp);
	if (keep_lit > 0.5) {
		s = max(s, 1.0);
	}

	//  그늘 쪽 반사광. 원통 그늘 가장자리의 1px 한 줄 — 없으면 통이
	//  그늘 쪽에서 바탕에 먹힌다(lospec 원통 규칙).
	float rim = 1.0 - dot(NORMAL, VIEW);
	if (bounce_on > 0.5 && rim > 0.8 && ndl < 0.0) {
		s = max(s, bs);
	}

	//  광택 한 점. 쇠붙이와 유약만 받는다 — 칠한 몸과 캔버스는 안 받는다.
	if (spec_th > 0.0) {
		vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		if (dot(nw, normalize(lw + vw)) > spec_th) {
			s = max(s, spec_s);
		}
	}

	ALBEDO = alt ? ramp4(b0.rgb, b1.rgb, b2.rgb, b3.rgb, s)
			: ramp4(r0.rgb, r1.rgb, r2.rgb, r3.rgb, s);
}
