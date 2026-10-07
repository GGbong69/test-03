shader_type canvas_item;
render_mode unshaded;

//  장면 전환 — TV 지지직(2026-10-06 「화면전환 연출을 그 TV 찌지직으로 넣어도 될거 같은데?」).
//  CanvasLayer 95(덮개 자리) — 도트(97) · VHS(98) · CRT(100) 밑이라 지지직도 브라운관을 지난다.
//  화면을 한 번 따서 그 위에 신호가 끊긴 줄무늬를 얹는다.
//
//  ── 생김 ───────────────────────────────────────────────
//  수신이 끊긴 TV — 어두운 바탕에 **가로로 길게 끌린 밝은 줄**이 촘촘하다. 줄마다 길이 ·
//  밝기 · 성김이 다르고, 빨강 · 파랑이 가로로 조금씩 어긋나 줄 끝에 색 테가 선다. 몇 줄은
//  통째로 어둡고 몇 줄은 거의 다 밝다. 초당 30 번 갈린다(매 틀이면 아지랑이가 된다).
//
//  ── 박자 ───────────────────────────────────────────────
//  지지직 띠가 한쪽 끝에서 차올라 화면을 덮고(cov_in 0 → 1), 다 덮인 동안 화면을 가고,
//  같은 쪽부터 걷힌다(cov_out 0 → 1) — 띠가 화면을 한 번 타고 지나간다.
//  띠 앞머리는 줄마다 들쭉날쭉(ragged)하고, 앞머리 앞쪽(tear_band)의 화면은 줄마다 옆으로
//  밀려 찢긴다 — 덮이기 직전의 옛 화면과 걷힌 직후의 새 화면이 신호를 잃고 · 되찾는다.
//
//  ── 눈이 덜 아프게(2026-10-08 「살짝 눈이 아프다는 평」) ─────────────
//  아픈 것은 **화면 통째의 깜빡임**이었다 — 밝기 0.3~1.0 의 줄무늬가 초당 30 번 통째로 새로
//  뽑혀, 한 점이 1/30 초마다 검정과 흰색 사이를 오갔다. 셋을 고쳤다.
//    · 갈림이 아니라 흐름 — 줄 성격은 초당 reroll_hz 번만 바뀌고 그 사이를 섞어 넘긴다(끊어
//      갈리는 틀이 없다). 대신 줄이 제 길을 따라 흘러간다(scroll) — 깜빡임이 움직임이 된다.
//    · 대비를 누른다 — 밝기를 lift ~ lift + gain 안에 가둔다(가장 밝은 점이 흰색이 아니다).
//      다 밝은 줄 · 빛깔 줄도 그 안이다.
//    · 찢김 · 앞서 튄 줄을 줄인다.
//  plain 1 — 설정 「전환 지지직」 끔. 줄무늬 없이 어두운 막이 같은 쪽에서 덮고 걷힌다.
//
//  ── 방향(vert) ─────────────────────────────────────────
//  0 — 줄이 가로 · 띠가 밑에서 위로.  1 — 줄이 세로 · 띠가 왼쪽에서 오른쪽으로.
//
//  ── 자는 논리 px ───────────────────────────────────────
//  vhs.gdshader 와 같다 — ppl(논리 1px 당 기기 px)로 재서 줄 하나가 논리 1px 이다.

uniform sampler2D scene : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec2 logical = vec2(640.0, 360.0);
uniform float cov_in = 0.0;
uniform float cov_out = 0.0;
uniform float clock = 0.0;
uniform float vert = 0.0;
uniform float ragged = 0.06;        // 앞머리 들쭉날쭉(화면 비)
uniform float tear_band = 0.16;     // 앞머리 앞쪽 찢김 띠(화면 비)
uniform float tear_px = 8.0;        // 찢김 최대 밀림(논리 px) — 18 에서 줄였다
uniform float fringe = 1.5;         // 색 어긋남(논리 px)
uniform float reroll_hz = 6.0;      // 줄 성격이 바뀌는 빠르기(초당) — 그 사이는 섞어 넘긴다
uniform float scroll = 80.0;        // 줄이 흐르는 빠르기 상한(논리 px/초) — 줄마다 방향 · 빠르기가 다르다
uniform float lift = 0.07;          // 가장 어두운 밝기
uniform float gain = 0.46;          // 가장 밝은 점 = lift + gain
uniform float plain = 0.0;          // 1 이면 줄무늬 없이 어두운 막(설정 「전환 지지직」 끔)
uniform float soft = 0.10;          // 어두운 막의 앞머리 번짐(화면 비)

float h12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float n1(float x, float r) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(h12(vec2(i, r)), h12(vec2(i + 1.0, r)), f);
}

//  줄 하나(ln)의 지지직 — along 은 줄을 따라가는 논리 좌표 · fr 은 줄 성격의 차례.
vec3 snow1(float along, float ln, float fr) {
	float rk = h12(vec2(ln, 3.0 + fr));                     // 줄 성격
	float bright = mix(0.45, 1.0, h12(vec2(ln, 5.0 + fr)));
	if (rk > 0.88) {
		bright *= 0.25;                                     // 통째로 어두운 줄
	}
	float th = mix(0.56, 0.84, h12(vec2(ln, 9.0 + fr)));    // 낮을수록 줄이 빽빽
	if (rk < 0.07) {
		th = 0.42;                                          // 빽빽한 줄(옛 「거의 다 밝은 줄」 0.25)
	}
	float fq = mix(0.008, 0.06, h12(vec2(ln, 11.0 + fr)));  // 줄 조각 길이(작을수록 길다)
	float off = h12(vec2(ln, 13.0 + fr)) * 977.0;
	vec3 c;
	for (int k = 0; k < 3; k++) {
		float x = along + (float(k) - 1.0) * fringe;
		float v = n1(x * fq + off, ln * 1.7 + fr * 31.0);
		c[k] = smoothstep(th, th + 0.06, v);
	}
	//  드문 줄에 빛깔 — 청록 · 자홍 · 노랑(옅게).
	float tk = h12(vec2(ln, 17.0 + fr));
	vec3 tint = vec3(1.0);
	if (tk > 0.90) {
		tint = vec3(0.70, 1.0, 1.0);
	} else if (tk > 0.83) {
		tint = vec3(1.0, 0.70, 1.0);
	} else if (tk > 0.78) {
		tint = vec3(1.0, 0.97, 0.70);
	}
	float base = 0.10 * h12(vec2(floor(along * 0.5), ln + fr * 7.0));
	return clamp(vec3(base) + c * tint * bright, 0.0, 1.0);
}

//  줄 성격 두 차례를 섞어 넘기고, 줄을 제 길로 흘리고, 밝기를 가둔다.
vec3 snow(float along, float ln, float t) {
	float sp = (h12(vec2(ln, 41.0)) - 0.5) * 2.0 * scroll;  // 줄마다 방향 · 빠르기
	float a = along + sp * clock;
	float f0 = floor(t);
	float k = smoothstep(0.0, 1.0, fract(t));
	vec3 c = mix(snow1(a, ln, f0), snow1(a, ln, f0 + 1.0), k);
	return vec3(lift) + c * gain;
}

void fragment() {
	vec2 sps = SCREEN_PIXEL_SIZE;
	float ppl = (1.0 / sps.y) / logical.y;
	vec2 lp = FRAGCOORD.xy / ppl;
	bool vm = vert > 0.5;
	float along = vm ? lp.y : lp.x;
	float across = vm ? lp.x : lp.y;
	float span = vm ? logical.x : logical.y;
	float ln = floor(across);
	//  띠가 들어오는 끝에서 잰 자리 0 → 1 (가로면 밑에서 · 세로면 왼쪽에서).
	float p = vm ? across / span : 1.0 - across / span;
	float fr = clock * reroll_hz;
	//  앞머리 들쭉날쭉도 끊어 갈리지 않고 섞여 넘어간다.
	float jt = clock * 10.0;
	float jag = (mix(h12(vec2(ln * 0.37, floor(jt))), h12(vec2(ln * 0.37, floor(jt) + 1.0)),
			smoothstep(0.0, 1.0, fract(jt))) - 0.5) * 2.0 * ragged;
	float span_k = 1.0 + 2.0 * ragged + tear_band;
	float head = cov_in * span_k - ragged + jag;     // 덮인 쪽 끝
	float tail = cov_out * span_k - ragged + jag;    // 걷힌 쪽 끝
	vec3 col = texture(scene, SCREEN_UV).rgb;
	if (plain > 0.5) {
		//  어두운 막 — 앞머리 · 꼬리가 soft 만큼 번진다. 줄무늬 · 찢김 · 깜빡임이 없다.
		float hd = cov_in * (1.0 + soft) - soft;
		float tl = cov_out * (1.0 + soft) - soft;
		float k = (1.0 - smoothstep(hd, hd + soft, p)) * smoothstep(tl, tl + soft, p);
		col = mix(col, vec3(0.020, 0.016, 0.030), k);
	} else if (p < head && p >= tail) {
		col = snow(along, ln, fr);
	} else if (cov_in > 0.0 && cov_out < 1.0) {
		//  찢김 — 덮이기 직전(head 앞쪽)이거나 걷힌 직후(tail 뒤쪽).
		float dist = p >= head ? p - head : tail - p;
		if (dist < tear_band) {
			float k = 1.0 - dist / tear_band;
			k = k * k;
			if (h12(vec2(ln, 29.0 + floor(fr))) < 0.05 * k) {
				col = snow(along, ln, fr);                  // 앞서 튄 줄
			} else {
				float dx = (h12(vec2(ln, 23.0 + floor(fr))) - 0.5) * 2.0 * tear_px * k;
				vec2 d = vm ? vec2(0.0, dx) : vec2(dx, 0.0);
				vec3 torn = texture(scene, SCREEN_UV + d * ppl * sps).rgb;
				col = mix(torn, max(torn, snow(along, ln, fr)), 0.25 * k);
			}
		}
	}
	COLOR = vec4(col, 1.0);
}
