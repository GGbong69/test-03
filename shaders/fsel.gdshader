shader_type canvas_item;

//  화면 고르기(game.gd FSEL · 2026-10-10) — 같은 장면 한 칸(src)을 그림 칸 셋(p0 · p1 · p2)에 1:1 로
//  옮겨 붙이고, 칸 밖 바닥은 dim 만큼 가라앉힌다. 이 층(94)은 필터 셋(97 · 98 · 100) 밑이다 —
//  필터는 저마다 제 칸(win) 안에만 먹는다(끔 · 브라운관 · 비디오테이프를 나란히 견준다).
//  칸은 모두 화면 UV(x0, y0, x1, y1)다.
uniform sampler2D scene : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec4 src = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 p0 = vec4(-1.0);
uniform vec4 p1 = vec4(-1.0);
uniform vec4 p2 = vec4(-1.0);
uniform float dim = 0.28;

bool inside(vec2 uv, vec4 r) {
	return uv.x >= r.x && uv.x < r.z && uv.y >= r.y && uv.y < r.w;
}

vec3 from_src(vec2 uv, vec4 r) {
	vec2 l = (uv - r.xy) / (r.zw - r.xy);
	return texture(scene, mix(src.xy, src.zw, l)).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(scene, uv).rgb * dim;
	if (inside(uv, p0)) {
		c = from_src(uv, p0);
	} else if (inside(uv, p1)) {
		c = from_src(uv, p1);
	} else if (inside(uv, p2)) {
		c = from_src(uv, p2);
	}
	COLOR = vec4(c, 1.0);
}
