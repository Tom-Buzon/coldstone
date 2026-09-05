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
uniform float anti_tiling_strength : hint_range(0.0, 0.25) = 0.075;
uniform float macro_variation_strength : hint_range(0.0, 0.2) = 0.06;
uniform float variation_seed : hint_range(0.0, 1.0) = 0.0;
uniform bool mirror_repeat = true;
uniform float secondary_rotation : hint_range(-3.1416, 3.1416) = 0.0;

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

vec2 repeated_uv(vec2 uv) {
	if (!mirror_repeat) {
		return uv;
	}
	// Ping-pong repeat guarantees continuous borders for albedo-only sources,
	// including legacy images that were not authored pixel-perfectly seamless.
	vec2 mirrored = abs(fract(uv * 0.5) * 2.0 - 1.0);
	// Stay inside the edge texels because the sampler itself remains repeatable
	// for authored PBR materials that bypass this branch.
	return mix(vec2(0.002), vec2(0.998), mirrored);
}

vec2 anti_tiled_uv(vec2 plane_position, float axis_seed) {
	float phase = variation_seed * 31.4159 + axis_seed;
	vec2 warp = vec2(
		sin(dot(plane_position, vec2(0.173, 0.117)) + phase),
		sin(dot(plane_position, vec2(-0.131, 0.193)) - phase * 0.73)
	);
	return repeated_uv(plane_position * texture_scale + warp * anti_tiling_strength);
}

float macro_variation(vec3 position) {
	float phase = variation_seed * 19.7392;
	float broad = sin(dot(position, vec3(0.071, 0.113, 0.047)) + phase);
	float crossing = sin(dot(position, vec3(-0.053, 0.067, 0.127)) - phase * 0.61);
	return 1.0 + broad * crossing * macro_variation_strength;
}

vec2 decorrelated_plane(vec2 plane_position) {
	float cosine = cos(secondary_rotation);
	float sine = sin(secondary_rotation);
	vec2 rotated = vec2(
		cosine * plane_position.x - sine * plane_position.y,
		sine * plane_position.x + cosine * plane_position.y
	);
	return rotated * 1.071 + vec2(3.17, -2.43);
}

vec3 undo_secondary_normal_rotation(vec3 tangent_normal) {
	float cosine = cos(secondary_rotation);
	float sine = sin(secondary_rotation);
	return vec3(
		cosine * tangent_normal.x + sine * tangent_normal.y,
		-sine * tangent_normal.x + cosine * tangent_normal.y,
		tangent_normal.z
	);
}

vec4 sample_albedo_plane(vec2 plane_position, float axis_seed) {
	vec2 primary_uv = anti_tiled_uv(plane_position, axis_seed);
	vec4 primary = texture(albedo_texture, primary_uv);
	// The same decorrelated coordinates and blend mask are reused for albedo,
	// normal and roughness so authored PBR maps remain spatially aligned.
	vec2 secondary_plane = decorrelated_plane(plane_position);
	vec2 secondary_uv = anti_tiled_uv(secondary_plane, axis_seed + 7.3);
	vec4 secondary = texture(albedo_texture, secondary_uv);
	float mask = 0.5 + 0.5 * sin(dot(plane_position, vec2(0.097, 0.137)) + variation_seed * 12.7 + axis_seed);
	return mix(primary, secondary, smoothstep(0.18, 0.82, mask));
}

vec4 sample_albedo_triplanar(vec3 position, vec3 weights) {
	vec4 result = vec4(0.0);
	float sampled_weight = 0.0;
	if (weights.x > 0.003) {
		result += sample_albedo_plane(position.zy, 0.0) * weights.x;
		sampled_weight += weights.x;
	}
	if (weights.y > 0.003) {
		result += sample_albedo_plane(position.xz, 2.1) * weights.y;
		sampled_weight += weights.y;
	}
	if (weights.z > 0.003) {
		result += sample_albedo_plane(position.xy, 4.2) * weights.z;
		sampled_weight += weights.z;
	}
	return result / max(sampled_weight, 0.0001);
}

float sample_roughness_plane(vec2 plane_position, float axis_seed) {
	float primary = texture(roughness_texture, anti_tiled_uv(plane_position, axis_seed)).r;
	vec2 secondary_plane = decorrelated_plane(plane_position);
	float secondary = texture(roughness_texture, anti_tiled_uv(secondary_plane, axis_seed + 7.3)).r;
	float mask = 0.5 + 0.5 * sin(dot(plane_position, vec2(0.097, 0.137)) + variation_seed * 12.7 + axis_seed);
	return mix(primary, secondary, smoothstep(0.18, 0.82, mask));
}

float sample_roughness_triplanar(vec3 position, vec3 weights) {
	float result = 0.0;
	float sampled_weight = 0.0;
	if (weights.x > 0.003) {
		result += sample_roughness_plane(position.zy, 0.0) * weights.x;
		sampled_weight += weights.x;
	}
	if (weights.y > 0.003) {
		result += sample_roughness_plane(position.xz, 2.1) * weights.y;
		sampled_weight += weights.y;
	}
	if (weights.z > 0.003) {
		result += sample_roughness_plane(position.xy, 4.2) * weights.z;
		sampled_weight += weights.z;
	}
	return result / max(sampled_weight, 0.0001);
}

vec3 sample_normal_plane(vec2 plane_position, float axis_seed) {
	vec3 primary = texture(normal_texture, anti_tiled_uv(plane_position, axis_seed)).xyz * 2.0 - 1.0;
	vec2 secondary_plane = decorrelated_plane(plane_position);
	vec3 secondary = texture(normal_texture, anti_tiled_uv(secondary_plane, axis_seed + 7.3)).xyz * 2.0 - 1.0;
	secondary = undo_secondary_normal_rotation(secondary);
	float mask = 0.5 + 0.5 * sin(dot(plane_position, vec2(0.097, 0.137)) + variation_seed * 12.7 + axis_seed);
	return normalize(mix(primary, secondary, smoothstep(0.18, 0.82, mask)));
}

vec3 sample_normal_triplanar(vec3 position, vec3 weights, vec3 geometric_normal) {
	vec3 result = vec3(0.0);
	if (weights.x > 0.003) {
		vec3 normal_x = sample_normal_plane(position.zy, 0.0);
		result += vec3(normal_x.z * sign(geometric_normal.x), normal_x.y, normal_x.x) * weights.x;
	}
	if (weights.y > 0.003) {
		vec3 normal_y = sample_normal_plane(position.xz, 2.1);
		result += vec3(normal_y.x, normal_y.z * sign(geometric_normal.y), normal_y.y) * weights.y;
	}
	if (weights.z > 0.003) {
		vec3 normal_z = sample_normal_plane(position.xy, 4.2);
		result += vec3(normal_z.x, normal_z.y, normal_z.z * sign(geometric_normal.z)) * weights.z;
	}
	return normalize(result);
}

void fragment() {
	vec3 weights = projection_weights(world_normal);
	vec4 sampled_albedo = sample_albedo_triplanar(world_position, weights);
	ALBEDO = sampled_albedo.rgb * tint.rgb * macro_variation(world_position);
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
		vec2 screen_gradient = vec2(dFdx(height), dFdy(height));
		float gradient_scale = min(1.0, 0.08 / max(length(screen_gradient), 0.0001));
		NORMAL = normalize(view_normal + vec3(-screen_gradient * gradient_scale, 0.0) * derived_relief);
	}
}
