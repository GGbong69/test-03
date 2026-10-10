shader_type canvas_item;
render_mode unshaded;

//  VHS 비디오테이프 — 게이지 하나(strength 0~1)가 전부를 민다.
//    가로 흔들림 · 색 번짐(빨강 · 파랑이 오른쪽으로 밀린다) · 헤드 스위칭(맨 밑 몇 행) ·
//    테이프 낟알 · 옅은 바램
//  트래킹 잡음 띠(화면을 타고 지나가는 하얀 눈발 띠)와 깨진 점(한 행의 하얀 가로 금)은
//  걷었다 — 「요거 흰줄은 좀 뺴던가 하자 살ㅉ가 별로야」(2026-10-04).
//  CanvasLayer 98 — 덮개(95) 위 · CRT(100) 밑. 테이프에서 나온 그림을 브라운관이 받는다.
//  화면을 한 번 따서 다시 뱉는다. 0 이면 값을 한 톨도 안 바꾼다(아래 「차이로만 얹는다」).
//
//  ── 테이프가 그림을 어떻게 망가뜨리나(레퍼런스 — 생각만 가져왔다) ──────
//  · 색은 루마와 따로 낮은 띠(약 0.5MHz, 루마는 3MHz)에 실린다 — 색 해상도가 밝기의
//    6~8분의 1이라 색이 가로로만 넓게 번지고, 색 지연으로 오른쪽으로 조금 밀린다.
//    밝기(글자 획)는 날카롭게 남는다. 그래서 YIQ 로 갈라 **I · Q 만** 흐린다.
//  · 비디오 앰프의 윤곽 강조가 밝은 획 오른쪽에 옅은 그늘 꼬리(링잉)를 끈다.
//  · 헤드 스위칭 — 드럼의 두 헤드가 수직 귀선 몇 줄 앞에서 갈마든다. 그 자리가 화면 맨
//    밑 몇 줄이라 거기만 옆으로 밀려 찢긴다. 브라운관은 넘치게 그려 숨기지만 캡처본에는 보인다.
//  · 시간축 떨림 — 줄마다 시작이 조금씩 어긋나 세로 획이 미세하게 물결친다.
//  · 낟알 · 바램 — 밝기 잡음은 가로로 길쭉하고, 색은 빠지고 검은 데가 조금 뜬다.
//
//  ── 기기 픽셀로 돈다 · 자는 논리 px ─────────────────────────
//  crt.gdshader 와 같다 — canvas_items 스트레치라 글자가 창 해상도로 래스터화된다.
//  ppl(논리 1px 당 기기 px)을 logical 로 셈해 모든 거리 · 행을 논리 px 로 잰다.
//  밝기는 날카로운 쌍선형(sharp)으로 집는다 — 흔들림이 0 인 자리는 원본 텍셀 그대로,
//  흔들린 자리도 이음이 기기 1/4px 이라 글자 획이 안 무른다. 줄 단위는 **화면 논리 행**
//  이다(CRT 주사선과 같은 행) — 행 안의 기기 줄들은 같이 밀려 글자 획이 안 갈린다.
//
//  ── 흔들림은 논리 1px 를 안 넘는다 ─────────────────────────
//  입력은 이 판을 되짚지 않는다(굴곡과 다르다). 그래서 그림이 누르는 자리에서 벗어나면
//  안 된다 — 물결 · 떨림을 다 더해 ±1 논리 px 에서 자른다. 헤드 스위칭만
//  맨 밑 hs_rows 행 안에서 hs_shift 까지 민다(누를 것이 없는 화면 밑 가장자리).
//
//  ── 차이로만 얹는다 ───────────────────────────────────────
//  결과 = 원본 + YIQ 차이를 RGB 로 되돌린 것. 세기 0 이면 차이가 정확히 0 이라
//  변환 행렬의 반올림이 원본 도트를 한 톨도 안 바꾼다.
//
//  ── 움직임 끔(motion 0) ────────────────────────────────────
//  시계가 0 에 선다 — 물결 · 떨림은 없고(0 에 멈춘다), 낟알은 한
//  장으로 얼고, 헤드 스위칭은 고정된 밀림으로 남는다. 번짐 · 바램은 시간과 무관하다.

uniform sampler2D scene : hint_screen_texture, filter_linear, repeat_disable;
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform vec2 logical = vec2(640.0, 360.0);
uniform float motion : hint_range(0.0, 1.0) = 1.0;
//  0 이상이면 TIME 대신 이 시계로 돈다 — 촬영 도구가 틀을 못 박는다.
uniform float clock = -1.0;

//  다 켰을 때(strength 1)의 값. strength 가 전부에 곱해진다. 길이는 논리 px.
uniform float wave = 0.45;               // 가로 물결(행을 따라 느리게 굽이친다)
uniform float jit = 0.2;                 // 행마다 떨림(반은 몇 행에 걸쳐 매끈, 반은 행마다)
uniform float chroma_w = 11.0;           // 색 번짐 폭 — 오른쪽으로 끌리는 꼬리
uniform float chroma_d = 2.4;            // 색 지연 — 색이 오른쪽으로 밀린다
uniform float ring = 0.20;               // 밝은 획 오른쪽 그늘(링잉)
uniform float ring_d = 1.5;              // 링잉 거리
uniform float fade = 0.15;               // 채도 빠짐 — 0.25 는 100 에서 다트판 초록 고리가 회녹색으로 바랬다
uniform float lift = 0.05;               // 검은 데 뜸
uniform float grain = 0.06;              // 밝기 낟알
uniform float cgrain = 0.07;             // 색 낟알(가로로 길쭉한 얼룩)
uniform float hs_rows = 5.0;             // 헤드 스위칭 — 맨 밑 몇 행
uniform float hs_shift = 3.0;            // 맨 밑 행의 밀림
//  밝기 띠 폭(논리 px · strength 1) — 테이프는 밝기도 가로로 조금 무른다(색보다는 훨씬 덜).
//  2026-10-10 「폰트에는 필터나 라이팅이 안되어 잇는거 같아서 좀 어색하다는 평」 — 옛 판은 밝기를
//  날카롭게만 집어 창 해상도 글자가 테이프를 안 지난 것처럼 떴다. 이제 글자도 그림과 같이 무른다.
uniform float luma_w = 1.0;

const vec3 LY = vec3(0.299, 0.587, 0.114);
const vec3 LI = vec3(0.5959, -0.2746, -0.3213);
const vec3 LQ = vec3(0.2115, -0.5227, 0.3112);

//  crt.gdshader 의 sharp 와 같다. p 는 기기 픽셀 좌표(가운데가 .5).
vec3 sharp(vec2 p, vec2 sps) {
	vec2 q = p - 0.5;
	vec2 i = floor(q);
	vec2 f = clamp((fract(q) - 0.5) * 4.0 + 0.5, 0.0, 1.0);
	return texture(scene, (i + 0.5 + f) * sps).rgb;
}

//  0~1 해시. 틀 번호는 부르는 쪽이 mod 로 접어 넣는다 — sin 이 큰 수에서 결이 무너진다.
float h12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

//  가로로 매끈한 잡음(행 r 마다 다른 줄).
float n1(float x, float r) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(h12(vec2(i, r)), h12(vec2(i + 1.0, r)), f);
}

//  YIQ 차이 → RGB 차이.
vec3 yiq_rgb(vec3 d) {
	return vec3(d.x + 0.9563 * d.y + 0.6210 * d.z,
			d.x - 0.2721 * d.y - 0.6474 * d.z,
			d.x - 1.1070 * d.y + 1.7046 * d.z);
}

void fragment() {
	vec2 sps = SCREEN_PIXEL_SIZE;
	float s = strength;
	float ppl = (1.0 / sps.y) / logical.y;
	bool mo = motion > 0.5;
	float t = mo ? (clock >= 0.0 ? clock : TIME) : 0.0;
	vec2 lp = FRAGCOORD.xy / ppl;           // 화면 논리 좌표
	float row = floor(lp.y);
	float fr = mod(floor(t * 20.0), 509.0);  // 떨림 · 찢김은 초당 20 번 갈린다
	float fg = mod(floor(t * 30.0), 467.0);  // 낟알은 30 번

	//  ② 가로 흔들림(논리 px) — 물결 + 행마다 떨림. ±1 에서 자른다.
	float dx = 0.0;
	if (mo) {
		dx += wave * sin(lp.y * 0.045 + t * 1.9) * (0.55 + 0.45 * sin(t * 0.43 + 1.0));
		dx += jit * ((n1(row * 0.4, fr + 7.0) - 0.5) * 1.2 + (h12(vec2(row, fr)) - 0.5) * 0.8);
	}
	dx = clamp(dx * s, -1.0, 1.0);
	//  헤드 스위칭 — 맨 밑 hs_rows 행. 밑으로 갈수록 세게, 오른쪽으로. 하얀 눈발은 걷었다.
	float hz = 1.0 - smoothstep(0.0, hs_rows, logical.y - lp.y);
	float hk = hz * hz;
	float hj = mo ? 0.7 + 0.3 * h12(vec2(row + 41.0, fr)) : 1.0;
	dx += hs_shift * s * hk * hj;

	vec2 sp = FRAGCOORD.xy + vec2(dx * ppl, 0.0);   // 기기 좌표

	//  ③ 밝기 — 날카롭게 집는다. 링잉은 ring_d 왼쪽과의 차이를 조금 더한다
	//  (밝은 획 바로 오른쪽이 어두워지고 어두운 데서 밝은 데로 넘는 자리가 조금 솟는다).
	vec3 c0 = sharp(sp, sps);
	float y0 = dot(c0, LY);
	//  밝기 띠 — 가로 다섯 탭(1 · 4 · 6 · 4 · 1). 세기 0 이면 폭이 0 이라 y0 그대로다.
	float lw = luma_w * s * 0.5 * ppl;
	float yb = y0 * 6.0;
	yb += dot(texture(scene, (sp + vec2(-lw, 0.0)) * sps).rgb, LY) * 4.0;
	yb += dot(texture(scene, (sp + vec2(lw, 0.0)) * sps).rgb, LY) * 4.0;
	yb += dot(texture(scene, (sp + vec2(-2.0 * lw, 0.0)) * sps).rgb, LY);
	yb += dot(texture(scene, (sp + vec2(2.0 * lw, 0.0)) * sps).rgb, LY);
	yb /= 16.0;
	vec2 iq0 = vec2(dot(c0, LI), dot(c0, LQ));
	float yl = dot(texture(scene, (sp - vec2(ring_d * ppl, 0.0)) * sps).rgb, LY);
	float y = yb + ring * s * (yb - yl);

	//  ④ 색 — I · Q 만 가로로. 탭 여덟이 왼쪽으로 늘어서고 멀수록 가볍다 → 왼쪽의 색이
	//  오른쪽으로 끌려온다(꼬리). 전체가 chroma_d 만큼 왼쪽을 집으니 색이 오른쪽으로 밀린다.
	vec2 iq = vec2(0.0);
	float ws = 0.0;
	for (int k = 0; k < 8; k++) {
		float a = float(k) / 7.0;
		float o = -(chroma_d + chroma_w * (a - 0.15)) * s;
		float w = exp(-2.6 * a);
		vec3 tc = texture(scene, (sp + vec2(o * ppl, 0.0)) * sps).rgb;
		iq += w * vec2(dot(tc, LI), dot(tc, LQ));
		ws += w;
	}
	iq /= ws;

	//  ⑤ 바램 — 채도 빠짐 · 검은 데 뜸
	iq *= 1.0 - fade * s;
	y = y + lift * s * (1.0 - y);

	//  ⑥ 낟알 — 밝기는 논리 반 px × 한 행(가로로 길쭉), 색은 넓은 얼룩.
	//  움직임 끔이면 fg 가 0 에 서서 한 장으로 언다.
	vec2 go = vec2(mod(fg * 7.31, 97.0), mod(fg * 13.7, 89.0));
	float gn = h12(vec2(floor(lp.x * 2.0), row) + go) - 0.5;
	y += grain * s * gn;
	iq += cgrain * s * (vec2(n1(lp.x * 0.08 + go.x, row + go.y),
			n1(lp.x * 0.08 + go.y, row + go.x + 91.0)) - 0.5);

	//  원본 + 차이. 세기 0 이면 dy · diq 가 정확히 0 이다.
	vec3 c = c0 + yiq_rgb(vec3(y - y0, iq - iq0));
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
