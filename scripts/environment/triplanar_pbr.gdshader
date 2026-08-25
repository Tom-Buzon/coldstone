shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal_texture = false;
uniform bool use_roughness_texture = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float texture_scale : hint_range(0.02, 2.0) = 0.28;
uniform float blend_sharpness : hint_range(1.0, 12.0) = 5.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.82;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.65;
uniform float derived_relief : hint_range(0.0, 4.0) = 0.45;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec3 projection_weights(vec3 surface_normal) {
	vec3 weights = pow(abs(surface_normal), vec3(blend_sharpness));
	return weights / max(weights.x + weights.y + weights.z, 0.0001);
}

vec4 sample_albedo_triplanar(vec3 position, vec3 weights) {
	vec4 projection_x = texture(albedo_texture, position.zy * texture_scale);
	vec4 projection_y = texture(albedo_texture, position.xz * texture_scale);
	vec4 projection_z = texture(albedo_texture, position.xy * texture_scale);
	return projection_x * weights.x + projection_y * weights.y + projection_z * weights.z;
}

float sample_roughness_triplanar(vec3 position, vec3 weights) {
	float projection_x = texture(roughness_texture, position.zy * texture_scale).r;
	float projection_y = texture(roughness_texture, position.xz * texture_scale).r;
	float projection_z = texture(roughness_texture, position.xy * texture_scale).r;
	return projection_x * weights.x + projection_y * weights.y + projection_z * weights.z;
}

vec3 sample_normal_triplanar(vec3 position, vec3 weights, vec3 geometric_normal) {
	vec3 normal_x = texture(normal_texture, position.zy * texture_scale).xyz * 2.0 - 1.0;
	vec3 normal_y = texture(normal_texture, position.xz * texture_scale).xyz * 2.0 - 1.0;
	vec3 normal_z = texture(normal_texture, position.xy * texture_scale).xyz * 2.0 - 1.0;
	vec3 oriented_x = vec3(normal_x.z * sign(geometric_normal.x), normal_x.y, normal_x.x);
	vec3 oriented_y = vec3(normal_y.x, normal_y.z * sign(geometric_normal.y), normal_y.y);
	vec3 oriented_z = vec3(normal_z.x, normal_z.y, normal_z.z * sign(geometric_normal.z));
	return normalize(oriented_x * weights.x + oriented_y * weights.y + oriented_z * weights.z);
}

void fragment() {
	vec3 weights = projection_weights(world_normal);
	vec4 sampled_albedo = sample_albedo_triplanar(world_position, weights);
	ALBEDO = sampled_albedo.rgb * tint.rgb;
	ROUGHNESS = use_roughness_texture
		? clamp(sample_roughness_triplanar(world_position, weights) * roughness_value, 0.04, 1.0)
		: roughness_value;
	SPECULAR = 0.28;
	AO = clamp(0.72 + dot(sampled_albedo.rgb, vec3(0.2126, 0.7152, 0.0722)) * 0.28, 0.0, 1.0);

	vec3 view_normal = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	if (use_normal_texture) {
		vec3 mapped_world_normal = sample_normal_triplanar(world_position, weights, world_normal);
		vec3 mapped_view_normal = normalize((VIEW_MATRIX * vec4(mapped_world_normal, 0.0)).xyz);
		NORMAL = normalize(mix(view_normal, mapped_view_normal, normal_strength));
	} else {
		// Current source images are albedo-only. A restrained derivative relief
		// makes mortar/stone readable until authored normal maps are supplied.
		float height = dot(sampled_albedo.rgb, vec3(0.2126, 0.7152, 0.0722));
		NORMAL = normalize(view_normal + vec3(-dFdx(height), -dFdy(height), 0.0) * derived_relief);
	}
}
