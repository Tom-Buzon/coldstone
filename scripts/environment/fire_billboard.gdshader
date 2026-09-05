shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 core_color : source_color = vec4(1.0, 0.86, 0.32, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.16, 0.015, 1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float flame_width = mix(0.78, 0.18, UV.y);
	float body = 1.0 - smoothstep(flame_width * 0.58, flame_width, abs(centered.x));
	float vertical = smoothstep(0.0, 0.14, UV.y) * (1.0 - smoothstep(0.70, 1.0, UV.y));
	float flicker = 0.78 + 0.22 * sin(TIME * 13.0 + UV.y * 19.0 + centered.x * 7.0);
	float alpha = body * vertical * flicker;
	vec3 color = mix(edge_color.rgb, core_color.rgb, clamp((1.0 - abs(centered.x)) * (1.0 - UV.y * 0.45), 0.0, 1.0));
	ALBEDO = color;
	EMISSION = color * 2.4;
	ALPHA = alpha;
}
