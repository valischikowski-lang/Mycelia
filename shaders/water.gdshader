// MYCELIA — Glowing dream water. Gentle vertex swell, concentric ripple
// rings, drifting caustic glints and a bright fresnel edge.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec4 deep_color : source_color = vec4(0.02, 0.25, 0.4, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.1, 0.95, 0.9, 1.0);
uniform vec4 glint_color : source_color = vec4(0.85, 1.0, 1.0, 1.0);
uniform float alpha = 0.82;
uniform float glow = 0.8;
uniform float wave_height = 0.08;
uniform float flow_speed = 0.0;
uniform vec2 flow_dir = vec2(0.0, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 v_world;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 0.35 + TIME * 1.1) * wave_height + cos(w.z * 0.27 + TIME * 0.8) * wave_height;
	v_world = w;
}

void fragment() {
	vec2 p = v_world.xz;
	vec2 flow = flow_dir * TIME * flow_speed;
	float n1 = texture(noise_tex, p * 0.03 + vec2(TIME * 0.01, TIME * 0.013) + flow * 0.05).r;
	float n2 = texture(noise_tex, p * 0.08 - vec2(TIME * 0.02, -TIME * 0.015) + flow * 0.1).r;
	float caustic = pow(1.0 - abs(n1 - n2) * 2.0, 10.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(n1 * 0.6 + fres * 0.7, 0.0, 1.0));
	float rings = 0.5 + 0.5 * sin(length(fract(p * 0.05) - 0.5) * 40.0 - TIME * 2.0);
	rings = smoothstep(0.92, 1.0, rings) * 0.25 * n2;
	ALBEDO = col;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	EMISSION = col * glow * 0.45 + glint_color.rgb * (caustic * 0.9 + rings);
	ALPHA = clamp(alpha + fres * 0.15, 0.0, 1.0);
}
