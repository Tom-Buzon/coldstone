shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D impostor_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float frame_count = 4.0;
uniform float frames_per_second = 3.0;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.16;

varying flat float instance_phase;
varying flat float allied;

void vertex() {
	instance_phase = INSTANCE_CUSTOM.r;
	allied = INSTANCE_CUSTOM.b;
	VERTEX *= max(INSTANCE_CUSTOM.g, 0.01);
	// The quad keeps its authored metric size while its axes follow the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
}

void fragment() {
	float frame = floor(mod(TIME * frames_per_second + instance_phase * frame_count, frame_count));
	vec2 atlas_uv = vec2((UV.x + frame) / frame_count, UV.y);
	vec4 sampled = texture(impostor_atlas, atlas_uv);
	if (sampled.a < alpha_cutoff) {
		discard;
	}
	ALBEDO = sampled.rgb * mix(vec3(1.0),vec3(0.3,0.55,1.0),allied);
	ALPHA = sampled.a;
}
