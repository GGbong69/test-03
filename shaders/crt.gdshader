shader_type canvas_item;
render_mode unshaded;

//  CRT 필터 — 설정의 「CRT 필터」 한 손잡이가 strength 하나로 전부를 민다.
//
//  맨 위 CanvasLayer(game.gd 의 _crt_open)에 깔린 온 화면 ColorRect 가 이것을
//  쓴다. 게임 · HUD · 메뉴 · 말상자가 다 그려진 뒤의 화면을 한 번 따서 다시 뱉는다.
//  strength 가 0 이면 부르는 쪽이 층째 꺼 두므로 값을 한 톨도 안 낸다.
//
//  ── 화면은 **기기 픽셀**로 돈다 ─────────────────────────────
//  canvas_items 스트레치라 캔버스가 창 해상도로 그려진다 — 글자는 1280 에서
//  래스터화되고 도트는 정수배로 선다. 그래서 이 판은 기기 픽셀 하나마다 돈다.
//  **통째로 흐리지 않는다.** 뼈대 탭은 날카로운 쌍선형(sharp)이라 굽힘이 0 인
//  한가운데에서는 원본 텍셀을 그대로 집고, 굽은 자리에서도 이음 폭이 기기 1/4px
//  이다. 번짐(glow)은 밝은 것만 **더하는** 층이라 원본 획을 안 무른다.
//
//  ── 주사선은 **논리 행**에 선다 ────────────────────────────
//  logical 은 지금 보이는 논리 크기다(expand 라 16:10 이면 640x400). 스크립트가
//  창이 바뀔 때마다 넣는다. 논리 1px 이 기기 몇 px 인지(ppl)를 여기서 셈해
//  논리 행마다 **바닥 쪽 0.4 행**을 어둡게 한다 — 2배면 바닥 기기 1줄이 다 어둡고
//  윗줄은 그대로, 4배면 바닥 1줄 + 그 위 줄이 3/8. 띠 폭을 기기 1줄로 못 박았더니
//  4배 창(고해상도 모니터)에서 행의 1/4 만 어두워 2배 창보다 주사선이 반쯤 옅었다.
//  주사선은 굽히지 않는다 — 2배 화면에서 행 하나가 기기 두 줄뿐이라 굽은 띠는
//  위상이 반 줄 밀리는 자리에서 사라졌다 나타나는 물결(모아레)이 된다.
//
//  ── 굽힘은 작게 ─────────────────────────────────────────────
//  입력을 되짚지 않는다(클릭은 원래 자리로 간다). 그래서 다 켠 때도 모서리에서
//  논리 4px 안쪽만 밀린다(bend 3.0 x 2.6 → 대각 3.97px) — 가장자리 단추를 눌러도
//  손이 안 어긋난다. 바깥에서 따는 자리는 검게 비어 둥근 테가 된다.

uniform sampler2D scene : hint_screen_texture, filter_linear, repeat_disable;
uniform float strength : hint_range(0.0, 1.0) = 0.4;
uniform vec2 logical = vec2(640.0, 360.0);
//  깜박임 · 낟알을 켤 것인가. 모션 끄기면 0 — 움직이는 것은 이 둘뿐이다.
uniform float motion : hint_range(0.0, 1.0) = 1.0;

//  다 켰을 때(strength 1)의 값. strength 가 전부에 곱해진다.
uniform float scan : hint_range(0.0, 1.0) = 0.40;     // 주사선 띠의 어둠
uniform float mask : hint_range(0.0, 1.0) = 0.14;     // 섀도 마스크(기기 열마다 색)
uniform vec2 bend = vec2(3.0, 2.6);                   // 모서리가 밀리는 논리 px
uniform float corner = 12.0;                          // 둥근 모서리 반지름(논리 px)
uniform float aberr = 0.45;                           // 모서리 색 어긋남(논리 px)
uniform float glow : hint_range(0.0, 2.0) = 0.40;     // 번짐 세기
uniform float glow_cut : hint_range(0.0, 1.0) = 0.55; // 번짐 문턱 — 밝은 것만 번진다
uniform float vig : hint_range(0.0, 1.0) = 0.30;      // 모서리 어둠
uniform float gain : hint_range(0.0, 1.0) = 0.16;     // 주사선 · 마스크가 먹은 밝기를 되돌린다
uniform float flick : hint_range(0.0, 0.1) = 0.012;   // 깜박임 · 낟알

//  날카로운 쌍선형. p 는 기기 픽셀 좌표(가운데가 .5). 텍셀 사이 이음을
//  1/4px 로 좁혀 최근접의 또렷함과 쌍선형의 고른 폭을 같이 얻는다.
//  p 가 정확히 텍셀 가운데면 f 가 0 이 되어 원본을 그대로 집는다.
vec3 sharp(vec2 p, vec2 sps) {
	vec2 q = p - 0.5;
	vec2 i = floor(q);
	vec2 f = clamp((fract(q) - 0.5) * 4.0 + 0.5, 0.0, 1.0);
	return texture(scene, (i + 0.5 + f) * sps).rgb;
}

void fragment() {
	vec2 sps = SCREEN_PIXEL_SIZE;
	float s = strength;
	//  논리 1px 당 기기 px. 정수배 스트레치라 2 · 3 · 4 … 로 떨어진다.
	float ppl = (1.0 / sps.y) / logical.y;
	vec2 uv = SCREEN_UV;
	vec2 n = uv * 2.0 - 1.0;             // 한가운데 0 · 가장자리 ±1
	float r2 = dot(n, n) * 0.5;          // 한가운데 0 · 변 가운데 0.5 · 모서리 1

	//  ① 굽힘 — 바깥에서 따 온다(술통). 모서리에서 bend 만큼, 변 가운데에서 그 반.
	vec2 src = uv * logical + n * r2 * bend * s;   // 논리 좌표
	vec2 sp = src * ppl;                            // 기기 좌표

	//  ② 뼈대 + 색 어긋남. 한가운데는 0 이라 글자 획이 안 갈린다.
	//  어긋남은 **차이로만** 얹는다(쌍선형 탭 셋: 제자리 · ±ca). 빨강 · 파랑을
	//  날카로운 탭으로 따로 따면 기기 1px 미만의 어긋남이 반올림돼 어떤 띠에서는
	//  0 · 어떤 띠에서는 꼭 1px 로 튀었다 — 40 에서도 모서리 HUD 의 「24」가
	//  초록 · 빨강 테를 둘렀다. 차이로 얹으면 어긋남이 0.3px 면 0.3px 만큼만 번진다.
	vec2 ca = n * r2 * aberr * s * ppl;
	vec3 c = sharp(sp, sps);
	vec3 l0 = texture(scene, sp * sps).rgb;
	c.r += texture(scene, (sp + ca) * sps).r - l0.r;
	c.b += texture(scene, (sp - ca) * sps).b - l0.b;

	//  ③ 번짐 — 여덟 탭, 논리 1px · 2px 두 고리. 문턱을 넘은 밝기만 모아 더한다.
	//  1.5 · 3px 고리에 문턱 0.45 였을 때는 금빛 글자(골드 수)가 40 에서도 뿌연
	//  달무리를 둘러 획이 물러 보였다 — 고리를 좁히고 문턱을 올렸다.
	vec3 gl = vec3(0.0);
	float rad = 1.0 * ppl;
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398 + 0.392699;
		float rk = (k % 2 == 0) ? rad : rad * 2.0;
		vec3 t = texture(scene, (sp + vec2(cos(a), sin(a)) * rk) * sps).rgb;
		gl += max(t - glow_cut, vec3(0.0));
	}
	c += gl * (glow * s / (8.0 * (1.0 - glow_cut)));

	//  ④ 주사선 — 화면 논리 행의 바닥 쪽. fb 는 행 바닥까지의 기기 px(픽셀 가운데 기준).
	float ly = FRAGCOORD.y / ppl;
	float fb = (1.0 - fract(ly)) * ppl;
	float band = max(ppl * 0.4, 0.8);
	float dark = clamp(1.0 - (fb - 0.5) / band, 0.0, 1.0);
	c *= 1.0 - scan * s * dark;

	//  ⑤ 마스크 — 2배 이하면 자홍 · 초록 두 줄, 그 위면 빨 · 초 · 파 세 줄.
	//  어느 쪽이든 한 벌이 논리 1px 에 든다. 셋을 고르게 깎아 회색이 안 물든다.
	float m = mask * s;
	float col = floor(FRAGCOORD.x);
	vec3 mk;
	if (ppl < 2.5) {
		mk = mod(col, 2.0) < 1.0 ? vec3(1.0, 1.0 - m, 1.0) : vec3(1.0 - m, 1.0, 1.0 - m);
	} else {
		float k3 = mod(col, 3.0);
		mk = k3 < 1.0 ? vec3(1.0, 1.0 - m, 1.0 - m)
				: (k3 < 2.0 ? vec3(1.0 - m, 1.0, 1.0 - m) : vec3(1.0 - m, 1.0 - m, 1.0));
	}
	c *= mk;
	c *= 1.0 + gain * s;

	//  ⑥ 모서리 어둠
	c *= 1.0 - vig * s * smoothstep(0.2, 1.0, r2);

	//  ⑦ 깜박임 · 낟알 — 아주 옅게. 모션 끄기면 없다.
	if (motion > 0.5) {
		float nz = fract(sin(dot(floor(FRAGCOORD.xy / ppl) + floor(TIME * 30.0),
				vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
		c = c * (1.0 + flick * s * sin(TIME * 37.7)) + nz * flick * s;
	}

	//  ⑧ 테 — 바깥에서 따는 자리는 검게(굽힘이 그리는 둥근 변), 화면 모서리는 둥글게.
	//  둘 다 기기 1px 로 녹여 계단이 안 선다.
	vec2 dd = min(src, logical - src) * ppl;
	float inb = clamp(min(dd.x, dd.y) + 0.5, 0.0, 1.0);
	vec2 pl = uv * logical;
	float rc = corner * s;
	vec2 qd = abs(pl - logical * 0.5) - (logical * 0.5 - rc);
	float dist = length(max(qd, vec2(0.0))) - rc;
	float cm = clamp(0.5 - dist * ppl, 0.0, 1.0);

	COLOR = vec4(clamp(c, 0.0, 1.0) * inb * cm, 1.0);
}
