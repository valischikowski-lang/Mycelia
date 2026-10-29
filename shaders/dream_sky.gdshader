// MYCELIA — The painted dream sky. A living gradient with slow swirling
// aurora ribbons, a ringed moon, star dust and painterly cloud bands.
shader_type sky;
render_mode use_half_res_pass;

uniform vec4 top_color : source_color = vec4(0.12, 0.04, 0.3, 1.0);
uniform vec4 mid_color : source_color = vec4(0.55, 0.12, 0.55, 1.0);
uniform vec4 horizon_color : source_color = vec4(1.0, 0.5, 0.35, 1.0);
uniform vec4 band_color : source_color = vec4(0.2, 0.95, 0.9, 1.0);
uniform vec4 moon_color : source_color = vec4(1.0, 0.9, 0.75, 1.0);
uniform vec4 ground_color : source_color = vec4(0.12, 0.05, 0.2, 1.0);
uniform vec3 moon_dir = vec3(0.3, 0.45, -0.85);
uniform float moon_size = 0.11;
uniform float swirl_speed = 0.015;
uniform float star_density = 1.0;
uniform float aurora_strength = 1.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float y = d.y;
	if (y < -0.02) {
		COLOR = mix(horizon_color.rgb * 0.35, ground_color.rgb, clamp(-y * 4.0, 0.0, 1.0));
	} else {
		float t = clamp(y, 0.0, 1.0);
		vec3 col = mix(horizon_color.rgb, mid_color.rgb, smoothstep(0.0, 0.28, t));
		col = mix(col, top_color.rgb, smoothstep(0.22, 0.85, t));

		// Spherical coordinates for swirling patterns.
		float az = atan(d.x, d.z);
		vec2 uv = vec2(az / 6.2831, t);
		float swirl = TIME * swirl_speed;

		// Painterly cloud bands near horizon.
		float c1 = textureLod(noise_tex, vec2(uv.x * 3.0 + swirl, t * 2.5 - swirl * 0.5), 0.0).r;
		float c2 = textureLod(noise_tex, vec2(uv.x * 7.0 - swirl * 1.7, t * 5.0), 0.0).r;
		float clouds = smoothstep(0.45, 0.85, c1 * 0.7 + c2 * 0.4) * smoothstep(0.42, 0.04, t) * smoothstep(-0.02, 0.05, t);
		col = mix(col, mix(horizon_color.rgb * 1.25, mid_color.rgb * 1.3, c2), clouds * 0.65);

		// Aurora ribbons: curved bands that drift and fold.
		float wave = sin(uv.x * 18.8496 + sin(uv.x * 12.5664 + TIME * 0.05) * 2.0 + TIME * 0.04);
		float band_y = 0.42 + wave * 0.08;
		float ribbon = exp(-pow((t - band_y) * 11.0, 2.0));
		float fold = textureLod(noise_tex, vec2(uv.x * 5.0 + swirl * 2.0, TIME * 0.01), 0.0).r;
		col += band_color.rgb * ribbon * (0.35 + fold * 0.9) * aurora_strength;
		float ribbon2 = exp(-pow((t - (0.62 + wave * 0.05)) * 16.0, 2.0));
		col += mid_color.rgb * vec3(1.4, 0.7, 1.6) * ribbon2 * fold * 0.5 * aurora_strength;

		// Stars.
		vec3 sp = floor(d * 220.0);
		float s = hash(sp);
		float twinkle = 0.6 + 0.4 * sin(TIME * (1.0 + s * 3.0) + s * 40.0);
		float star = step(1.0 - 0.006 * star_density, s) * smoothstep(0.15, 0.6, t) * twinkle;
		col += vec3(1.0, 0.95, 1.0) * star * 1.4;

		// Ringed moon.
		vec3 md = normalize(moon_dir);
		float md_dot = dot(d, md);
		float ang = acos(clamp(md_dot, -1.0, 1.0));
		float disc = smoothstep(moon_size, moon_size * 0.92, ang);
		vec3 tangent = normalize(cross(md, vec3(0.2, 1.0, 0.1)));
		vec3 bit = cross(md, tangent);
		vec2 mp = vec2(dot(d - md * md_dot, tangent), dot(d - md * md_dot, bit)) / moon_size;
		float shade = clamp(0.55 + mp.x * 0.45, 0.0, 1.0);
		float crater = textureLod(noise_tex, mp * 0.4 + 0.5, 0.0).r;
		vec3 moon = moon_color.rgb * (0.65 + crater * 0.5) * shade;
		// Tilted ring around the moon.
		vec2 rp = vec2(mp.x, mp.y * 3.2 + mp.x * 0.6);
		float r = length(rp);
		float ring = smoothstep(0.08, 0.0, abs(r - 1.75)) + smoothstep(0.05, 0.0, abs(r - 2.05)) * 0.6;
		float ring_front = step(0.0, mp.y * 3.2 + mp.x * 0.6) + (1.0 - disc);
		col += band_color.rgb * ring * clamp(ring_front, 0.0, 1.0) * 0.9;
		col = mix(col, moon, disc);
		col += moon_color.rgb * exp(-ang * 9.0) * 0.35;

		COLOR = col;
	}
}
