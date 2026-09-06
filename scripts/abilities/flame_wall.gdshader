shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float wall_length = 15.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

void fragment() {
	float height = 1.0 - UV.y;
	float along = UV.x * wall_length;
	vec2 flow = vec2(along * 2.4, height * 3.0 - TIME * 2.8);
	float turbulence = noise(flow) * 0.65 + noise(flow * 2.1) * 0.35;
	float tongues = noise(vec2(along * 2.0 + sin(height * 5.0 - TIME * 3.0) * 0.3, TIME * 0.7));
	float top = 0.35 + tongues * 0.60;
	float body = 1.0 - smoothstep(top - 0.18, top, height + turbulence * 0.12);
	float edge = smoothstep(0.0, 0.035, UV.x) * smoothstep(0.0, 0.035, 1.0 - UV.x);
	float heat = clamp(1.0 - height * 1.5 - turbulence * 0.38, 0.0, 1.0);
	vec3 color = mix(vec3(0.95, 0.065, 0.005), vec3(1.0, 0.52, 0.025), smoothstep(0.1, 0.6, heat));
	color = mix(color, vec3(1.0, 0.93, 0.46), smoothstep(0.65, 0.95, heat));
	ALBEDO = color;
	ALPHA = body * edge * strength * (0.8 + turbulence * 0.2);
}
