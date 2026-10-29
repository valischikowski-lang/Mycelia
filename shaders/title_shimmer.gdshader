// MYCELIA — shimmering psychedelic gradient for title text.
shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(1.0, 0.45, 0.85, 1.0);
uniform vec4 color_b : source_color = vec4(0.3, 1.0, 0.95, 1.0);
uniform vec4 color_c : source_color = vec4(1.0, 0.85, 0.35, 1.0);
uniform float width = 700.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 tex = COLOR;
	float t = local_pos.x / width + TIME * 0.12 + sin(local_pos.y * 0.03 + TIME) * 0.05;
	float k = fract(t);
	vec3 g = k < 0.33 ? mix(color_a.rgb, color_b.rgb, k / 0.33)
		: (k < 0.66 ? mix(color_b.rgb, color_c.rgb, (k - 0.33) / 0.33) : mix(color_c.rgb, color_a.rgb, (k - 0.66) / 0.34));
	float sparkle = pow(0.5 + 0.5 * sin(local_pos.x * 0.15 - TIME * 4.0 + local_pos.y * 0.2), 24.0);
	COLOR = vec4(g * (1.0 + sparkle * 0.8) * tex.rgb, tex.a);
}
