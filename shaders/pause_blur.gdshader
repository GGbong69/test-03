shader_type canvas_item;

//  멈춤 흐림 — ESC 로 설정을 열면 뒤의 게임이 뿌예진다.
//
//  화면이 640x360 이라 반지름을 크게 잡을 일이 없다. 3x3 아홉 점이면
//  픽셀 하나가 이웃에 번져 "초점이 나갔다" 로 읽히고, 그 이상은 도트가
//  녹아 진흙이 된다 — 이 게임은 도트가 곧 그림이라 거기서 끊는다.
//
//  amount 가 0 이면 게임이 그린 그대로를 다시 뱉는다. 그래도 후면 복사는
//  도므로, 부르는 쪽이 0 일 때 아예 안 보이게 꺼 준다.

uniform sampler2D scene : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float radius : hint_range(0.0, 6.0) = 1.8;
// 뒤로 물러난 만큼 어두워지고 색이 빠진다. 앞의 글씨가 읽히는 값이다.
uniform float dim : hint_range(0.0, 1.0) = 0.62;
uniform float desat : hint_range(0.0, 1.0) = 0.45;
uniform vec3 tint : source_color = vec3(0.08, 0.06, 0.13);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius * amount;
	// 3x3 가우시안 — 가운데 4 · 변 2 · 모서리 1, 합 16
	vec3 c = texture(scene, SCREEN_UV).rgb * 4.0;
	c += texture(scene, SCREEN_UV + vec2( px.x, 0.0)).rgb * 2.0;
	c += texture(scene, SCREEN_UV + vec2(-px.x, 0.0)).rgb * 2.0;
	c += texture(scene, SCREEN_UV + vec2(0.0,  px.y)).rgb * 2.0;
	c += texture(scene, SCREEN_UV + vec2(0.0, -px.y)).rgb * 2.0;
	c += texture(scene, SCREEN_UV + vec2( px.x,  px.y)).rgb;
	c += texture(scene, SCREEN_UV + vec2( px.x, -px.y)).rgb;
	c += texture(scene, SCREEN_UV + vec2(-px.x,  px.y)).rgb;
	c += texture(scene, SCREEN_UV + vec2(-px.x, -px.y)).rgb;
	c /= 16.0;

	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), desat * amount);
	c = mix(c, tint, dim * amount);
	COLOR = vec4(mix(texture(scene, SCREEN_UV).rgb, c, amount), 1.0);
}
