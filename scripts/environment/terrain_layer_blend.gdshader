shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D layer0_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D layer1_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D layer2_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D layer3_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 layer0_tint : source_color = vec4(1.0);
uniform vec4 layer1_tint : source_color = vec4(1.0);
uniform vec4 layer2_tint : source_color = vec4(1.0);
uniform vec4 layer3_tint : source_color = vec4(1.0);
uniform float layer0_scale = 0.24;
uniform float layer1_scale = 0.24;
uniform float layer2_scale = 0.24;
uniform float layer3_scale = 0.24;
uniform float layer0_roughness = 0.9;
uniform float layer1_roughness = 0.9;
uniform float layer2_roughness = 0.9;
uniform float layer3_roughness = 0.9;
uniform float blend_sharpness : hint_range(1.0, 12.0) = 5.0;

varying vec3 world_position;
varying vec3 world_normal;
varying vec3 painted_weights;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	painted_weights = clamp(COLOR.rgb, vec3(0.0), vec3(1.0));
}

vec3 projection_weights(vec3 surface_normal) {
	vec3 weights = pow(abs(surface_normal), vec3(blend_sharpness));
	return weights / max(weights.x + weights.y + weights.z, 0.0001);
}

vec3 sample_triplanar(sampler2D source, vec3 position, vec3 weights, float scale) {
	vec3 projection_x = texture(source, position.zy * scale).rgb;
	vec3 projection_y = texture(source, position.xz * scale).rgb;
	vec3 projection_z = texture(source, position.xy * scale).rgb;
	return projection_x * weights.x + projection_y * weights.y + projection_z * weights.z;
}

void fragment() {
	vec3 projection = projection_weights(world_normal);
	vec3 local_weights = clamp(painted_weights, vec3(0.0), vec3(1.0));
	float painted_total = min(local_weights.r + local_weights.g + local_weights.b, 1.0);
	float base_weight = 1.0 - painted_total;
	vec3 color0 = sample_triplanar(layer0_texture, world_position, projection, layer0_scale) * layer0_tint.rgb;
	vec3 color1 = sample_triplanar(layer1_texture, world_position, projection, layer1_scale) * layer1_tint.rgb;
	vec3 color2 = sample_triplanar(layer2_texture, world_position, projection, layer2_scale) * layer2_tint.rgb;
	vec3 color3 = sample_triplanar(layer3_texture, world_position, projection, layer3_scale) * layer3_tint.rgb;
	ALBEDO = color0 * base_weight + color1 * local_weights.r + color2 * local_weights.g + color3 * local_weights.b;
	ROUGHNESS = clamp(
		layer0_roughness * base_weight
		+ layer1_roughness * local_weights.r
		+ layer2_roughness * local_weights.g
		+ layer3_roughness * local_weights.b,
		0.04,
		1.0
	);
	SPECULAR = 0.24;
	AO = 0.88;
}
