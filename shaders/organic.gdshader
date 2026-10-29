// MYCELIA — Organic surface shader.
// Albedo comes from vertex colors (baked by the procedural generators).
// Vertex alpha is used as an emission mask so one mesh can carry glowing
// spots, gills and veins without extra surfaces.
shader_type spatial;
render_mode cull_back;

uniform vec4 tint : source_color = vec4(1.0);
uniform float emission_strength = 2.2;
uniform vec4 emission_tint : source_color = vec4(1.0);
uniform float pulse_speed = 1.1;
uniform float pulse_amount = 0.3;
uniform vec4 rim_color : source_color = vec4(0.55, 0.9, 1.0, 1.0);
uniform float rim_strength = 0.55;
uniform float rim_power = 2.6;
uniform float sway_strength = 0.0;
uniform float sway_speed = 1.0;
uniform float sway_height = 4.0;
uniform float breathe = 0.0;
uniform float roughness_value = 0.75;
uniform float wrap = 0.45;
uniform float shade_steps = 3.0;
uniform float shadow_tint_amount = 0.35;
uniform vec4 shadow_tint : source_color = vec4(0.35, 0.2, 0.75, 1.0);

varying float v_glow;
varying float v_phase;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_phase = fract(dot(origin, vec3(0.131, 0.071, 0.173))) * 6.2831;
	if (sway_strength > 0.0) {
		float h = clamp(VERTEX.y / sway_height, 0.0, 1.5);
		float k = h * h * sway_strength;
		VERTEX.x += sin(TIME * sway_speed + v_phase) * k;
		VERTEX.z += cos(TIME * sway_speed * 0.77 + v_phase * 1.3) * k * 0.7;
	}
	if (breathe > 0.0) {
		float b = 1.0 + sin(TIME * 0.8 + v_phase) * breathe;
		VERTEX.xz *= b;
		VERTEX.y *= 2.0 - b;
	}
	v_glow = COLOR.a;
}

void fragment() {
	vec3 base = COLOR.rgb * tint.rgb;
	ALBEDO = base;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.2;
	float pulse = 1.0 + sin(TIME * pulse_speed + v_phase) * pulse_amount;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = base * emission_tint.rgb * v_glow * emission_strength * pulse
		+ rim_color.rgb * fres * rim_strength * 0.4;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0) * ATTENUATION;
	// Soft banded toon ramp.
	float banded = floor(w * shade_steps + 0.5) / shade_steps;
	float ramp = mix(w, banded, 0.55);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), clamp(ramp + (1.0 - shadow_tint_amount), 0.0, 1.0));
	DIFFUSE_LIGHT += LIGHT_COLOR * ramp * shade;
	// Painterly soft highlight.
	vec3 h = normalize(LIGHT + VIEW);
	float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 24.0) * (1.0 - roughness_value) * ATTENUATION;
	SPECULAR_LIGHT += LIGHT_COLOR * smoothstep(0.3, 0.6, spec) * 0.35;
}
