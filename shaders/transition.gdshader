// MYCELIA — screen transition: a swirling spore-vortex dissolve.
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color_a : source_color = vec4(0.05, 0.02, 0.12, 1.0);
uniform vec4 color_b : source_color = vec4(0.45, 0.1, 0.6, 1.0);
uniform vec4 color_c : source_color = vec4(0.2, 1.0, 0.95, 1.0);
uniform float aspect = 1.777;

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= aspect;
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	float swirl = a + r * 6.0 - TIME * 1.5;
	float bands = 0.5 + 0.5 * sin(swirl * 5.0);
	float spots = 0.5 + 0.5 * sin(uv.x * 40.0 + sin(uv.y * 30.0 + TIME) * 2.0) * sin(uv.y * 40.0 + TIME * 0.7);
	// Coverage grows from the edges inward, with a wobbly organic front.
	float front = progress * 1.6 - (1.0 - r) * 0.6 + sin(a * 7.0 + TIME * 2.0) * 0.04;
	float cover = smoothstep(0.0, 0.08, front);
	vec3 col = mix(color_a.rgb, color_b.rgb, bands * 0.5);
	col += color_c.rgb * smoothstep(0.85, 1.0, spots) * 0.25;
	float edge = smoothstep(0.0, 0.05, front) * (1.0 - smoothstep(0.05, 0.12, front));
	col += color_c.rgb * edge * 1.5;
	COLOR = vec4(col, clamp(cover + step(0.999, progress), 0.0, 1.0));
}
