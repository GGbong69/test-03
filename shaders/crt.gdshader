shader_type canvas_item;
render_mode unshaded;

//  CRT 필터 · 화면 굴곡 — 설정 「화면」 갈래의 손잡이 둘이 이 판 하나를 민다.
//    「CRT 필터」  strength 0~1 — 주사선 · 섀도 마스크 · 색 어긋남 · 번짐 · 모서리 어둠 · 깜박임
//    「화면 굴곡」 warp 0~1     — 술통 굽힘 · 둥근 검은 테(발라트로의 브라운관 곡면)
//  「약간 발라트로 같이 그 화면의 왜곡? 그런건 못 넣어?」(사용자, 2026-10-03) — 그 전까지는
//  굽힘이 CRT 손잡이에 딸린 논리 4px 짜리였다. 둘을 갈라 굴곡만 따로 세게 민다.
//
//  맨 위 CanvasLayer(game.gd 의 _crt_open)에 깔린 온 화면 ColorRect 가 이것을
//  쓴다. 게임 · HUD · 메뉴 · 말상자가 다 그려진 뒤의 화면을 한 번 따서 다시 뱉는다.
//  둘 다 0 이면 부르는 쪽이 층째 꺼 두므로 값을 한 톨도 안 낸다.
//
//  ── 화면은 **기기 픽셀**로 돈다 ─────────────────────────────
//  canvas_items 스트레치라 캔버스가 창 해상도로 그려진다 — 글자는 1280 에서
//  래스터화되고 도트는 정수배로 선다. 그래서 이 판은 기기 픽셀 하나마다 돈다.
//  **통째로 흐리지 않는다.** 뼈대 탭은 날카로운 쌍선형(sharp)이라 굽힘이 0 인
//  자리에서는 원본 텍셀을 그대로 집고, 굽은 자리에서도 이음 폭이 기기 1/4px
//  이다. 번짐(glow)은 밝은 것만 **더하는** 층이라 원본 획을 안 무른다.
//
//  ── 굴곡 — 발라트로와 같은 꼴의 술통 ───────────────────────
//  화면 자리 d(논리) 의 정규 좌표 n(가운데 0 · 가장자리 ±1)에서
//      m = n + n · (n.yx)² · k        k = warp_k · warp
//  를 따 온다. 가로는 **세로 거리의 제곱**만큼, 세로는 **가로 거리의 제곱**만큼
//  바깥에서 집는다. 그래서
//    · 한가운데 · 네 변의 한가운데는 제자리다(n.yx 가 0) — HUD 가 변 가운데에서 안 잘린다
//    · 모서리일수록 바깥을 집어 원본 모서리가 안으로 끌려 들어오고, 원본 밖을 집는
//      화면 모서리는 검게 빈다 → 네 변이 바깥으로 불룩한 둥근 브라운관
//    · 원본은 둥근 모서리(rc) 말고는 **안 잘린다** — 화면 네 변의 그림(g 의 상)이
//      원본 사각을 다 두른다. 반지름 식(n·r²)은 변 가운데까지 밀어내 가장자리 HUD 를 잘랐다.
//  k 는 (0.08, 0.12) — 50 에서 (0.04, 0.06)이 모서리를 가로 12 · 세로 10 논리 px
//  안으로 들인다(발라트로 기본 CRT 의 곡면). 100 은 그 두 배.
//  ⚠ **입력이 같은 식으로 되짚는다.** 화면 d 를 누르면 그 자리에 그려진 것은 원본
//  g(d) 이므로, 게임이 읽는 포인터 자리는 전부 g(d) 를 지난다(game.gd 의 _warp_src).
//  그래서 이 식과 k · rc 를 바꾸면 그쪽도 **글자 그대로** 같이 바꾼다 — 수는 game.gd
//  의 WARP 한 곳에 살고 _crt_apply 가 여기 uniform 으로 넣는다(qa_warp 가 대 본다).
//
//  ── 테 ───────────────────────────────────────────────────
//  원본 자리가 화면(모서리 반지름 rc 의 둥근 사각) 밖이면 검다 — 굽힘이 그리는 둥근
//  변이다. 녹이는 폭 fe(논리) 의 **한가운데(0.5)가 정확히 거리 0** 이라 「누르면 화면
//  안인가」(game.gd 의 _warp_hit)와 눈에 보이는 테의 반이 같은 선이다. 테 안쪽 몇 px 는
//  유리관 두께처럼 살짝 어둡다(rim).
//
//  ── 주사선은 **화면 행**에 곧게 선다 — 굴곡을 안 따른다 ──────────
//  logical 은 지금 보이는 논리 크기다(expand 라 16:10 이면 640x400). 스크립트가
//  창이 바뀔 때마다 넣는다. 논리 1px 이 기기 몇 px 인지(ppl)를 여기서 셈해
//  화면 논리 행마다 **바닥 쪽 0.4 행**을 어둡게 한다 — 2배면 바닥 기기 1줄이 다 어둡고
//  윗줄은 그대로, 4배면 바닥 1줄 + 그 위 줄이 3/8.
//  굴곡을 따라 휘게 하면(원본 행 src.y 에 세우면) 2배 화면에서 행 하나가 기기 두 줄
//  뿐이라 휜 띠의 위상이 반 줄 밀리는 자리마다 띠가 두 줄에 반씩 번졌다 또렷해졌다
//  한다 — 50 의 굴곡은 위아래 변이 가로로 가면서 10px(= 기기 20줄) 처지므로 위 · 아래
//  변을 따라 물결(모아레)이 스무 개 선다. 100 이면 마흔 개다. 곧은 주사선은 화면 유리에
//  박힌 래스터로 읽히고(그림이 휘고 격자는 안 휜다) 어느 배율에서도 물결이 없다.
//  굴곡은 그림이 이미 말한다 — 둥근 테와 휜 가장자리 HUD 로 충분하다.

uniform sampler2D scene : hint_screen_texture, filter_linear, repeat_disable;
uniform float strength : hint_range(0.0, 1.0) = 0.4;
uniform vec2 logical = vec2(640.0, 360.0);
//  깜박임 · 낟알을 켤 것인가. 모션 끄기면 0 — 움직이는 것은 이 둘뿐이다.
uniform float motion : hint_range(0.0, 1.0) = 1.0;

//  화면 굴곡 0~1. 0 이면 굽힘 · 테가 없고 따는 자리가 정확히 제자리다.
uniform float warp : hint_range(0.0, 1.0) = 0.0;
//  다 켰을 때(warp 1)의 값. warp 가 곱해진다. 넣는 쪽은 game.gd 의 WARP 다.
uniform vec2 warp_k = vec2(0.08, 0.12);    // 술통 세기(가로 · 세로)
uniform float warp_rc = 16.0;              // 테의 둥근 모서리 반지름(원본 논리 px)
uniform float warp_fe = 2.0;               // 테를 녹이는 폭(논리 px)
uniform float warp_rim = 0.30;             // 테 안쪽 그늘의 짙기

//  다 켰을 때(strength 1)의 값. strength 가 전부에 곱해진다.
uniform float scan : hint_range(0.0, 1.0) = 0.40;     // 주사선 띠의 어둠
uniform float mask : hint_range(0.0, 1.0) = 0.14;     // 섀도 마스크(기기 열마다 색)
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

//  g(d) — 화면 자리 d(논리 px) 에 따 오는 원본 자리. game.gd 의 _warp_src 와 같은 식.
vec2 warp_src(vec2 d, vec2 L, float w) {
	vec2 n = d / L * 2.0 - 1.0;
	vec2 m = n + n * (n.yx * n.yx) * (warp_k * w);
	return (m + 1.0) * 0.5 * L;
}

//  원본 자리 s 가 둥근 화면(L · 모서리 rc) 밖으로 얼마나 나갔나(논리 px). 음수면 안.
//  game.gd 의 _warp_out 과 같은 식.
float warp_out(vec2 s, vec2 L, float rc) {
	vec2 h = L * 0.5;
	vec2 q = abs(s - h) - (h - vec2(rc));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - rc;
}

void fragment() {
	vec2 sps = SCREEN_PIXEL_SIZE;
	float s = strength;
	//  논리 1px 당 기기 px. 정수배 스트레치라 2 · 3 · 4 … 로 떨어진다.
	float ppl = (1.0 / sps.y) / logical.y;
	vec2 uv = SCREEN_UV;
	vec2 n = uv * 2.0 - 1.0;             // 한가운데 0 · 가장자리 ±1
	float r2 = dot(n, n) * 0.5;          // 한가운데 0 · 변 가운데 0.5 · 모서리 1

	//  ① 굽힘 — 0 이면 식을 안 지나 제자리를 그대로 집는다(기기 픽셀 가운데 그대로).
	vec2 src = uv * logical;                        // 논리 좌표
	if (warp > 0.0) {
		src = warp_src(src, logical, warp);
	}
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
	//  굴곡을 안 따른다(머리말 「주사선은 화면 행에 곧게 선다」).
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

	//  ⑧ 테 — 원본 자리가 둥근 화면 밖이면 검다. 녹이는 폭의 한가운데가 거리 0 이다.
	//  굴곡이 0 이면 반지름 0 · 폭 기기 1px — 가장자리 기기 픽셀(거리 −½ 기기 px)이
	//  꼭 1 로 남아 CRT 만 켠 화면은 테가 없다.
	float dist = warp_out(src, logical, warp_rc * warp);
	float fe = max(warp_fe * warp, 1.0 / ppl);
	float inb = clamp(0.5 - dist / fe, 0.0, 1.0);
	//  테 안쪽 그늘 — 거리 0 에서 rim 만큼 어둡고 안으로 10px 에 걸쳐 걷힌다.
	float rim = 1.0 - warp_rim * warp * (1.0 - smoothstep(0.0, 10.0, -dist));

	COLOR = vec4(clamp(c, 0.0, 1.0) * inb * rim, 1.0);
}
