shader_type spatial;
render_mode cull_back;

//  ══════════════════════════════════════════════════════════
//   손 · 팔 · 소매 — 빛 사다리 셰이더 (2026-10-16 · game.gd _hand3_toon)
//  ──────────────────────────────────────────────────────────
//   옛 손은 면마다 법선 하나(8각 기둥)에 램버트 감싸기라, 면 안에서 램프 감쇠가
//   1 씩 오르다 면 경계에서 계단으로 뛰었다 — 손 하나에 살빛이 166 톤(검토 실측).
//   픽셀 그림처럼 몇 안 되는 색 덩어리도, 매끈한 3D 도 아니라 「저해상도로 찍은
//   로우폴리」로 읽혀 HUD · 동전 그림과 결이 갈렸다.
//   그래서 빛마다 세기를 **문턱으로 고른다** — 다트통(cup_ramp)과 같은 어법이다.
//   다만 통처럼 빛을 지어내지 않고 무대의 빛(램프 웅덩이 · 소품 스포트 · 바닥 반사)을
//   그대로 받는다 — 손이 램프 웅덩이 가장자리에서 밝고 팔꿈치가 어둠으로 가라앉는 것은
//   그 빛들이 맡는다. 빛 하나가 내는 것은 네 단(0 · l1 · l2 · l3) 에 감쇠 계단을 곱한 것뿐이고,
//   상인 무대의 약한 해 둘은 고른 한 단이다(dir_flat). 실측: 쉬는 손 · 팔뚝 살빛 474 · 450 톤
//   → 51 · 71 톤(손 화판 그대로).
//   매끈한 법선(game.gd _hand3_loft)과 같이 가야 단이 곡면을 따라 선다 — 평평한 면에
//   걸면 면 하나가 한 단이 될 뿐이다.
//  ══════════════════════════════════════════════════════════

uniform vec4 albedo : source_color = vec4(0.77, 0.6, 0.62, 1.0);
//  손바닥 쪽 — 메시 좌표 아래(−y)를 보는 면만. 0 이면 안 쓴다(천 · 쇠).
uniform vec4 under : source_color = vec4(0.85, 0.69, 0.69, 1.0);
uniform float under_k = 0.0;
//  감싸기 — 빛을 등진 면이 순흑까지 안 떨어지게(옛 LAMBERT_WRAP 의 일).
uniform float wrap = 0.35;
//  단 문턱과 그 단의 세기 — 문턱은 빛을 보는 각(감싼 NdotL)에만 건다. 옛 감싸기(거칠기 0.72)의
//  단 한가운데 값과 맞춘다(0.55 · 0.41 · 0.28).
uniform float t1 = 0.14;
uniform float t2 = 0.50;
uniform float t3 = 0.78;
uniform float l1 = 0.28;
uniform float l2 = 0.42;
uniform float l3 = 0.58;
//  빛의 감쇠(램프 웅덩이 가장자리 · 거리)는 곱의 계단으로 — 한 계단이 2^(1/att_steps) 배다.
//  절대 세기를 몰라도(램프 세기 7 이 거리 감쇠 0.3 을 메운다) 고르게 끊긴다.
uniform float att_steps = 3.0;
//  해(방향광)를 단 대신 고른 한 단으로 — 1 상인 무대 · 0 다트 무대(라이벌 손).
uniform float dir_flat = 1.0;
uniform float gain = 1.0;
//  반짝임 한 점 — 문턱을 넘는 자리만(쇠 · 손톱). 0 이면 없다.
uniform float spec = 0.0;
uniform float spec_cut = 0.6;
uniform float shin = 40.0;
uniform float glow = 0.0;
//  확산 몫 — 쇠는 빛을 거의 안 퍼뜨리고 반짝임으로 선다(놋쇠 띠 · 반지 0.5 언저리).
uniform float diff = 1.0;
//  바탕빛을 받는 몫 — 다트 무대처럼 바탕빛이 센 자리에서 손이 한 색 판때기가 안 되게 줄인다.
uniform float amb = 1.0;
//  프롤로그 앞 토막만(2026-10-23 「라이팅이랑 쉐이딩 더 퀄리티 있게 해줘 진짜 영화같은 장면 같이」 — prologue3d LOOK.skin) —
//  soft 가 0 보다 크면 단 경계를 그 폭으로 녹이고 감쇠(무른 그림자가 든다)는 끊지 않는다 · sheen 넓고 옅은 살 윤기(너클 ·
//  손톱). 둘 다 0 이면 옛 계단 그대로다(상점 · 다트 손).
uniform float soft = 0.0;
uniform float sheen = 0.0;

varying float v_ny;


void vertex() {
	v_ny = NORMAL.y;
}


void fragment() {
	vec3 c = albedo.rgb;
	if (under_k > 0.0) {
		c = mix(c, under.rgb, under_k * step(v_ny, -0.35));
	}
	//  꼭짓점 색 — 접힌 천의 골 · 걷은 단의 겹 사이(_hand3_loft 의 ao).
	ALBEDO = c * COLOR.rgb;
	ROUGHNESS = 1.0;
	EMISSION = ALBEDO * glow;
	AO = amb;
	AO_LIGHT_AFFECT = 0.0;
}


void light() {
	float nl = dot(NORMAL, LIGHT);
	float v = clamp((nl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float a = ATTENUATION;
	float aq = a > 0.0001 ? exp2(floor(log2(a) * att_steps + 0.5) / att_steps) : 0.0;
	float q = v < t1 ? 0.0 : (v < t2 ? l1 : (v < t3 ? l2 : l3));
	if (soft > 0.0) {
		aq = a;
		q = l1 * smoothstep(t1 - soft, t1 + soft, v) + (l2 - l1) * smoothstep(t2 - soft, t2 + soft, v)
				+ (l3 - l2) * smoothstep(t3 - soft, t3 + soft, v);
	}
	if (LIGHT_IS_DIRECTIONAL) {
		//  상인 무대의 해 둘(왼쪽 위 채움빛 · 바닥 반사)은 약한 빛이라 고른 한 단(l1)으로 얹는다 —
		//  빛마다 제 방향으로 단을 끊으면 경계가 겹쳐 팔뚝이 조각보가 됐다(촬영). 단은 램프가 세운다.
		//  다트 무대는 해가 곧 키 라이트라 끊는다(dir_flat 0).
		q = mix(q, l1, dir_flat);
	}
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * q * aq * gain * diff;
	if (spec > 0.0 && nl > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float s = pow(max(dot(NORMAL, h), 0.0), shin);
		//  쇠의 반짝임은 제 빛깔이다(금 · 놋쇠) — 흰 점이면 쇠가 아니라 유리 구슬이다.
		vec3 sc = ALBEDO / max(max(ALBEDO.r, ALBEDO.g), max(ALBEDO.b, 0.001));
		float cut = soft > 0.0 ? smoothstep(spec_cut * 0.6, spec_cut, s) : step(spec_cut, s);
		SPECULAR_LIGHT += LIGHT_COLOR / PI * spec * cut * aq * sc;
	}
	if (sheen > 0.0 && nl > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		SPECULAR_LIGHT += LIGHT_COLOR * sheen * pow(max(dot(NORMAL, h), 0.0), 18.0) * a;
	}
}
