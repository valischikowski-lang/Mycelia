// MYCELIA — Magical crystal. Faceted flat shading via derivative normals,
// iridescent hue drift and inner glow. Vertex color sets the base hue.
shader_type spatial;
render_mode cull_back;

uniform float glow = 1.4;
uniform float iridescence = 0.35;
uniform float pulse_speed = 0.7;
uniform vec4 rim_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);

varying vec3 v_local;
varying float v_phase;

vec3 hue_shift(vec3 c, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void vertex() {
	v_local = VERTEX;
	v_phase = fract(dot(MODEL_MATRIX[3].xyz, vec3(0.21, 0.13, 0.37))) * 6.2831;
}

void fragment() {
	vec3 flat_n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = flat_n;
	float fres = pow(1.0 - clamp(abs(dot(flat_n, VIEW)), 0.0, 1.0), 2.0);
	vec3 base = COLOR.rgb;
	vec3 iri = hue_shift(base, (fres + v_local.y * 0.15) * iridescence * 6.0 + sin(TIME * 0.3 + v_phase) * 0.4);
	float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed + v_phase + v_local.y);
	ALBEDO = iri * 0.6;
	ROUGHNESS = 0.15;
	METALLIC = 0.2;
	SPECULAR = 0.9;
	EMISSION = iri * glow * pulse * (0.45 + COLOR.a * 0.55) + rim_color.rgb * fres * 0.6;
}
