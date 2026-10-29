// MYCELIA — Living ground. Vertex colors carry the painted terrain layers
// (grass / moss / path / rock). World-space noise adds painterly variation and
// a cellular noise draws the glowing Mycelium network, which pulses outward
// in slow waves — the visual heartbeat of the world.
shader_type spatial;
render_mode cull_back;

uniform sampler2D detail_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D vein_noise : filter_linear_mipmap, repeat_enable;
uniform vec4 vein_color : source_color = vec4(0.2, 1.0, 0.95, 1.0);
uniform float vein_strength = 1.6;
uniform float vein_scale = 0.045;
uniform float vein_width = 0.035;
uniform vec3 pulse_origin = vec3(0.0);
uniform float detail_scale = 0.045;
uniform float detail_amount = 0.22;
uniform vec4 shadow_tint : source_color = vec4(0.3, 0.18, 0.7, 1.0);
uniform float wrap = 0.5;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;
	float n1 = texture(detail_noise, p * detail_scale).r;
	float n2 = texture(detail_noise, p * detail_scale * 3.7 + vec2(0.37, 0.11)).r;
	vec3 base = COLOR.rgb;
	base *= 1.0 + (n1 - 0.5) * detail_amount * 2.0;
	base = mix(base, base * vec3(1.08, 0.92, 1.12), smoothstep(0.55, 0.8, n2));
	ALBEDO = base;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;

	// Mycelium veins: thin bright lines along cellular noise edges.
	float v = texture(vein_noise, p * vein_scale).r;
	float line = 1.0 - smoothstep(0.0, vein_width, v);
	float d = length(v_world - pulse_origin);
	float wave = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(d * 0.08 - TIME * 0.9), 6.0);
	// Veins fade on paths (low COLOR.a marks path / rock).
	float mask = COLOR.a;
	EMISSION = vein_color.rgb * line * wave * vein_strength * mask;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0) * ATTENUATION;
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), clamp(w + 0.45, 0.0, 1.0));
	DIFFUSE_LIGHT += LIGHT_COLOR * w * shade;
}
