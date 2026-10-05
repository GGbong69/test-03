shader_type canvas_item;
render_mode unshaded;

//  불스아이 반전 — 「다트의 볼스아이를 맞췄을때 진짜 짧게 색상 반전 주는거 어때? 시작 화면
//  말고 인게임 플레이에서만」(2026-10-06). 화면을 한 번 따서 색을 뒤집는다.
//  CanvasLayer 96 — 덮개(95) 위 · 도트(97) · VHS(98) · CRT(100) 밑이라 뒤집힌 그림도
//  필터를 지난다. 켜진 동안만 층이 서고(game.gd INV) 나머지는 층째 숨는다.
//  기기 픽셀 그대로 읽는다(nearest) — 뒤집기만 하므로 글자 획이 안 무른다.

uniform sampler2D scene : hint_screen_texture, filter_nearest, repeat_disable;

void fragment() {
	vec3 c = texture(scene, SCREEN_UV).rgb;
	COLOR = vec4(vec3(1.0) - c, 1.0);
}
