// MYCELIA — chaos magic screen distortion: swirling UV warp, hue rotation
// and chromatic split, driven by `strength`.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.3, 0.7, 1.0);

vec3 hue_rotate(vec3 c, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c);
	float a = atan(c.y, c.x) + strength * 2.5 * (1.0 - r) * sin(TIME * 7.0);
	vec2 warped = 0.5 + vec2(cos(a), sin(a)) * r * (1.0 + sin(r * 30.0 - TIME * 10.0) * 0.02 * strength);
	vec2 off = vec2(0.006, 0.0) * strength;
	vec3 col;
	col.r = textureLod(screen_tex, warped + off, 0.0).r;
	col.g = textureLod(screen_tex, warped, 0.0).g;
	col.b = textureLod(screen_tex, warped - off, 0.0).b;
	col = hue_rotate(col, strength * 2.0 * sin(TIME * 3.0));
	col = mix(col, col * tint.rgb * 1.6, strength * 0.35);
	COLOR = vec4(col, strength);
}
