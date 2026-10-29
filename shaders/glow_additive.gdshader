// MYCELIA — Unshaded additive glow for light beams, motes, auras and
// spell energy. Vertex color multiplies the tint; UV.y fades beams.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.4, 1.0, 1.0, 1.0);
uniform float intensity = 1.5;
uniform float fade_power = 1.5;
uniform float flicker = 0.15;
uniform bool use_uv_fade = true;
uniform bool fresnel_fade = false;

void fragment() {
	float f = 1.0;
	if (use_uv_fade) {
		f = pow(clamp(1.0 - UV.y, 0.0, 1.0), fade_power);
	}
	if (fresnel_fade) {
		f *= pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	}
	float fl = 1.0 + sin(TIME * 7.0 + UV.x * 12.0) * flicker;
	ALBEDO = vec3(0.0);
	EMISSION = color.rgb * COLOR.rgb * intensity * f * fl;
	ALPHA = f;
}
