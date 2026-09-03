shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

// 3D 를 이 화면의 어법으로 끌어내린다.
//
// 640x360 에 nearest 로 찍히니 도트는 이미 된다. 안 되는 것은 **색 단계**다.
// PBR 조명은 명암이 매끄럽게 흘러서, 도트로 찍혀도 손으로 칠한 화면과
// 안 붙는다. 빛을 몇 계단으로 끊고 색도 계단으로 끊는다.

uniform sampler2D albedo_tex : source_color, filter_nearest, hint_default_white;
uniform vec4 tint : source_color = vec4(1.0);
uniform int light_bands : hint_range(2, 8) = 4;    // 명암 계단 수
uniform int color_steps : hint_range(2, 32) = 12;  // 색 계단 수
uniform float ambient : hint_range(0.0, 1.0) = 0.34;

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * tint.rgb;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}

void light() {
	float d = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);
	// 계단. floor 뒤 +0.5 는 반올림이라 첫 계단이 0 으로 죽지 않는다.
	float n = float(light_bands);
	d = floor(d * n + 0.5) / n;
	d = mix(ambient, 1.0, d);
	vec3 c = ALBEDO * LIGHT_COLOR * ATTENUATION * d;
	// 색도 끊는다. 이게 없으면 계단 사이가 다시 매끄러워진다.
	float s = float(color_steps);
	c = floor(c * s + 0.5) / s;
	DIFFUSE_LIGHT += c;
}
