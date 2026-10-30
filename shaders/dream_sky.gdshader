// MYCELIA — The dark dreaming sky. A near-black indigo dome with a slowly
// turning galaxy vortex, dense star dust, a thin ghost-light ribbon and an
// amber moon with a sleeping face that, now and then, opens its eyes.
shader_type sky;
render_mode use_half_res_pass;

uniform vec4 top_color : source_color = vec4(0.01, 0.01, 0.03, 1.0);
uniform vec4 mid_color : source_color = vec4(0.04, 0.05, 0.2, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.14, 0.07, 0.29, 1.0);
uniform vec4 band_color : source_color = vec4(0.24, 0.39, 1.0, 1.0);
uniform vec4 moon_color : source_color = vec4(1.0, 0.81, 0.45, 1.0);
uniform vec4 ground_color : source_color = vec4(0.02, 0.01, 0.05, 1.0);
uniform vec4 ghost_color : source_color = vec4(0.36, 1.0, 0.69, 1.0);
uniform vec3 moon_dir = vec3(-0.35, 0.42, -0.84);
uniform float moon_size = 0.13;
uniform vec3 vortex_dir = vec3(0.45, 0.62, -0.64);
uniform float vortex_strength = 1.0;
uniform float star_density = 1.6;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Thin arc (part of a circle) used to draw the moon's face.
float arc(vec2 p, vec2 c, float r, float w, float lower) {
	float d = abs(length(p - c) - r);
	float side = lower > 0.0 ? step(p.y, c.y) : step(c.y, p.y);
	return smoothstep(w, w * 0.4, d) * side;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float y = d.y;
	if (y < -0.02) {
		COLOR = mix(horizon_color.rgb * 0.4, ground_color.rgb, clamp(-y * 4.0, 0.0, 1.0));
	} else {
		float t = clamp(y, 0.0, 1.0);
		vec3 col = mix(horizon_color.rgb, mid_color.rgb, smoothstep(0.0, 0.25, t));
		col = mix(col, top_color.rgb, smoothstep(0.2, 0.8, t));
		// Sickly green glow hugging the horizon.
		col += ghost_color.rgb * 0.05 * exp(-t * 18.0);

		float az = atan(d.x, d.z);
		vec2 uv = vec2(az / 6.2831, t);

		// Low, dark cloud banks.
		float c1 = textureLod(noise_tex, vec2(uv.x * 3.0 + TIME * 0.004, t * 2.5), 0.0).r;
		float c2 = textureLod(noise_tex, vec2(uv.x * 7.0 - TIME * 0.006, t * 5.0), 0.0).r;
		float clouds = smoothstep(0.5, 0.85, c1 * 0.7 + c2 * 0.4) * smoothstep(0.35, 0.03, t);
		col = mix(col, horizon_color.rgb * 0.5, clouds * 0.7);

		// Galaxy vortex: logarithmic spiral arms around vortex_dir.
		vec3 vc = normalize(vortex_dir);
		float vr = acos(clamp(dot(d, vc), -1.0, 1.0));
		vec3 vt = normalize(cross(vc, vec3(0.0, 1.0, 0.0)));
		vec3 vb = cross(vc, vt);
		vec2 vp = vec2(dot(d, vt), dot(d, vb));
		float va = atan(vp.y, vp.x);
		float spiral = va * 2.0 + log(vr + 0.02) * 4.5 + TIME * 0.035;
		float arms = pow(0.5 + 0.5 * sin(spiral), 3.0);
		float dust = textureLod(noise_tex, vp * 1.6 + vec2(TIME * 0.003, 0.0), 0.0).r;
		float vmask = exp(-vr * 2.4) * vortex_strength;
		vec3 galaxy = band_color.rgb * arms * (0.6 + dust) * vmask;
		galaxy += vec3(0.75, 0.55, 1.0) * pow(arms, 4.0) * dust * vmask * 0.8;
		galaxy += vec3(1.0, 0.75, 0.45) * exp(-vr * 14.0) * 0.9 * vortex_strength;
		col += galaxy * 1.1;

		// Ghost-light ribbon: a thin, slow green-blue curtain.
		float wave = sin(uv.x * 18.8496 + sin(uv.x * 12.5664 + TIME * 0.04) * 2.0 + TIME * 0.03);
		float ribbon = exp(-pow((t - (0.5 + wave * 0.07)) * 22.0, 2.0));
		float fold = textureLod(noise_tex, vec2(uv.x * 5.0 + TIME * 0.01, TIME * 0.008), 0.0).r;
		col += ghost_color.rgb * ribbon * fold * 0.18;

		// Stars: denser inside the galaxy arms.
		vec3 sp = floor(d * 260.0);
		float s = hash(sp);
		float twinkle = 0.55 + 0.45 * sin(TIME * (1.0 + s * 4.0) + s * 40.0);
		float density = 0.006 * star_density * (1.0 + arms * vmask * 6.0);
		float star = step(1.0 - density, s) * smoothstep(0.05, 0.4, t) * twinkle;
		col += mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.9, 0.7), fract(s * 13.0)) * star * 1.5;

		// The sleeping moon.
		vec3 md = normalize(moon_dir);
		float md_dot = dot(d, md);
		float ang = acos(clamp(md_dot, -1.0, 1.0));
		float disc = smoothstep(moon_size, moon_size * 0.95, ang);
		vec3 tangent = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
		vec3 bit = cross(tangent, md);
		vec2 mp = vec2(dot(d - md * md_dot, tangent), dot(d - md * md_dot, bit)) / moon_size;
		float crater = textureLod(noise_tex, mp * 0.5 + 0.5, 0.0).r;
		float shade = clamp(0.75 + mp.x * 0.25 + mp.y * 0.1, 0.0, 1.0);
		vec3 moon = moon_color.rgb * (0.55 + crater * 0.55) * shade;
		// Face: closed (or slowly opening) eyes, a long nose and a crooked smile.
		float awake = smoothstep(0.985, 1.0, sin(TIME * 0.11)) ;
		vec2 le = vec2(-0.33, 0.18);
		vec2 re = vec2(0.33, 0.2);
		float lids = arc(mp, le, 0.17, 0.035, 1.0) + arc(mp, re, 0.17, 0.035, 1.0);
		float open_eyes = smoothstep(0.13, 0.1, length((mp - le) * vec2(1.0, 1.6))) + smoothstep(0.13, 0.1, length((mp - re) * vec2(1.0, 1.6)));
		float pupils = smoothstep(0.05, 0.03, length(mp - le - vec2(0.03, -0.02))) + smoothstep(0.05, 0.03, length(mp - re - vec2(0.03, -0.02)));
		float mouth = arc(mp, vec2(0.04, -0.02), 0.42, 0.04, 1.0) * step(-0.38, mp.x) * step(mp.x, 0.42);
		float nose = smoothstep(0.1, 0.0, length((mp - vec2(0.02, 0.0)) * vec2(2.2, 1.0))) * 0.35;
		moon *= 1.0 - (lids * (1.0 - awake) + mouth) * 0.75;
		moon += moon_color.rgb * nose;
		moon = mix(moon, vec3(1.0, 0.95, 0.75), open_eyes * awake);
		moon = mix(moon, vec3(0.05, 0.0, 0.0), pupils * awake);
		col = mix(col, moon * 1.2, disc);
		col += moon_color.rgb * exp(-ang * 7.0) * 0.25;

		COLOR = col;
	}
}
