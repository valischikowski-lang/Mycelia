// MYCELIA — arena rune circle: concentric rotating rings of procedural glyphs.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color_a : source_color = vec4(0.3, 1.0, 0.95, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.4, 0.9, 1.0);
uniform float intensity = 1.2;
uniform float speed = 0.15;

float glyph(vec2 p, float seed) {
	// Cheap abstract glyph: a few strokes chosen by seed.
	float s = fract(sin(seed * 91.7) * 43758.5);
	float d = 1.0;
	d = min(d, abs(p.x - (s - 0.5) * 0.6));
	d = min(d, abs(p.y - fract(s * 7.3) * 0.8 + 0.4));
	d = min(d, abs(length(p - vec2(0.0, fract(s * 3.1) - 0.5)) - 0.25));
	return smoothstep(0.08, 0.0, d) * step(abs(p.x), 0.45) * step(abs(p.y), 0.45);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	vec3 col = vec3(0.0);
	// Rings.
	col += color_a.rgb * smoothstep(0.015, 0.0, abs(r - 0.95));
	col += color_a.rgb * smoothstep(0.01, 0.0, abs(r - 0.78)) * 0.8;
	col += color_b.rgb * smoothstep(0.01, 0.0, abs(r - 0.55)) * 0.7;
	// Rotating glyph band between 0.8 and 0.93.
	float band_a = a + TIME * speed;
	float cells = 28.0;
	float cell = floor(band_a / 6.2831 * cells);
	float local_a = fract(band_a / 6.2831 * cells) - 0.5;
	if (r > 0.8 && r < 0.93) {
		vec2 gp = vec2(local_a * 1.1, (r - 0.865) / 0.065 * 0.5);
		col += color_a.rgb * glyph(gp, cell) * 1.2;
	}
	// Counter-rotating inner band.
	float band_b = a - TIME * speed * 1.7;
	float cell_b = floor(band_b / 6.2831 * 16.0);
	float local_b = fract(band_b / 6.2831 * 16.0) - 0.5;
	if (r > 0.58 && r < 0.75) {
		vec2 gp2 = vec2(local_b * 1.2, (r - 0.665) / 0.085 * 0.5);
		col += color_b.rgb * glyph(gp2, cell_b + 50.0);
	}
	// Spokes and a soft centre.
	col += color_b.rgb * smoothstep(0.02, 0.0, abs(sin((a + TIME * 0.1) * 3.0))) * step(r, 0.55) * 0.3 * (1.0 - r);
	col += color_a.rgb * exp(-r * 6.0) * 0.4;
	float fade = smoothstep(1.0, 0.96, r);
	ALBEDO = vec3(0.0);
	EMISSION = col * intensity * fade;
	ALPHA = 1.0;
}
