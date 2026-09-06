shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0, 0.65, 0.08, 1.0);
uniform float strength = 1.0;
void vertex() {
	float wave = sin(UV.x * 50.0 + TIME * 12.0 + UV.y * 13.0);
	VERTEX += NORMAL * wave * (0.09 + 0.15 * (1.0 - UV.y));
}
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
	float streak = pow(max(0.0, sin(UV.x * 65.0 + sin(UV.y * 14.0 - TIME * 9.0) * 1.6)), 8.0);
	float pulse = 0.75 + 0.25 * sin(UV.y * 28.0 - TIME * 14.0);
	ALBEDO = tint.rgb * 0.9;
	ALPHA = strength * (rim * (0.1 + streak * 0.5) + streak * pulse * 0.4) * tint.a;
}
