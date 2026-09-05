shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2DArray catalog_textures : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D splat_map0 : filter_linear, repeat_disable;
uniform sampler2D splat_map1 : filter_linear, repeat_disable;
uniform sampler2D splat_map2 : filter_linear, repeat_disable;
uniform sampler2D splat_map3 : filter_linear, repeat_disable;
uniform sampler2D splat_map4 : filter_linear, repeat_disable;
uniform sampler2D splat_map5 : filter_linear, repeat_disable;
uniform sampler2D splat_map6 : filter_linear, repeat_disable;
uniform sampler2D splat_map7 : filter_linear, repeat_disable;
uniform int catalog_layer_count = 1;
uniform int active_layer_count = 0;
uniform int active_layer_indices[32];
uniform int base_layer_index = 0;
uniform vec4 layer_tints[32];
uniform float layer_scales[32];
uniform float layer_roughness[32];
uniform float layer_anti_tiling[32];
uniform float layer_macro_variation[32];
uniform float layer_seeds[32];
uniform float layer_mirror_repeat[32];
uniform float layer_secondary_rotation[32];
uniform float blend_sharpness : hint_range(1.0, 12.0) = 5.0;

varying vec3 world_position;
varying vec3 world_normal;
varying vec2 splat_uv;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	splat_uv = UV2;
}

vec3 projection_weights(vec3 surface_normal) {
	vec3 weights = pow(abs(surface_normal), vec3(blend_sharpness));
	return weights / max(weights.x + weights.y + weights.z, 0.0001);
}

vec2 repeated_uv(vec2 uv, bool mirror_repeat) {
	if (!mirror_repeat) {
		return uv;
	}
	vec2 mirrored = abs(fract(uv * 0.5) * 2.0 - 1.0);
	return mix(vec2(0.002), vec2(0.998), mirrored);
}

vec2 anti_tiled_uv(vec2 plane_position, float scale, float strength, float seed, float axis_seed, bool mirror_repeat) {
	float phase = seed * 31.4159 + axis_seed;
	vec2 warp = vec2(
		sin(dot(plane_position, vec2(0.173, 0.117)) + phase),
		sin(dot(plane_position, vec2(-0.131, 0.193)) - phase * 0.73)
	);
	return repeated_uv(plane_position * scale + warp * strength, mirror_repeat);
}

float macro_pattern(vec3 position) {
	return sin(dot(position, vec3(0.071, 0.113, 0.047)))
		* sin(dot(position, vec3(-0.053, 0.067, 0.127)));
}

vec3 sample_plane(int layer_index, vec2 plane_position, float scale, float strength, float seed, float axis_seed, bool mirror_repeat, float secondary_rotation) {
	vec2 primary_uv = anti_tiled_uv(plane_position, scale, strength, seed, axis_seed, mirror_repeat);
	vec3 primary = texture(catalog_textures, vec3(primary_uv, float(layer_index))).rgb;
	float cosine = cos(secondary_rotation);
	float sine = sin(secondary_rotation);
	vec2 secondary_plane = vec2(
		cosine * plane_position.x - sine * plane_position.y,
		sine * plane_position.x + cosine * plane_position.y
	) * 1.071 + vec2(3.17, -2.43);
	vec2 secondary_uv = anti_tiled_uv(secondary_plane, scale, strength, seed, axis_seed + 7.3, mirror_repeat);
	vec3 secondary = texture(catalog_textures, vec3(secondary_uv, float(layer_index))).rgb;
	float mask = 0.5 + 0.5 * sin(dot(plane_position, vec2(0.097, 0.137)) + seed * 12.7 + axis_seed);
	return mix(primary, secondary, smoothstep(0.18, 0.82, mask));
}

vec3 sample_triplanar(int layer_index, vec3 position, vec3 weights) {
	float scale = layer_scales[layer_index];
	float strength = layer_anti_tiling[layer_index];
	float seed = layer_seeds[layer_index];
	bool mirror_repeat = layer_mirror_repeat[layer_index] > 0.5;
	float secondary_rotation = layer_secondary_rotation[layer_index];
	vec3 result = vec3(0.0);
	float sampled_weight = 0.0;
	if (weights.x > 0.003) {
		result += sample_plane(layer_index, position.zy, scale, strength, seed, 0.0, mirror_repeat, secondary_rotation) * weights.x;
		sampled_weight += weights.x;
	}
	if (weights.y > 0.003) {
		result += sample_plane(layer_index, position.xz, scale, strength, seed, 2.1, mirror_repeat, secondary_rotation) * weights.y;
		sampled_weight += weights.y;
	}
	if (weights.z > 0.003) {
		result += sample_plane(layer_index, position.xy, scale, strength, seed, 4.2, mirror_repeat, secondary_rotation) * weights.z;
		sampled_weight += weights.z;
	}
	return result / max(sampled_weight, 0.0001);
}

void fragment() {
	vec4 packed0 = texture(splat_map0, splat_uv);
	vec4 packed1 = active_layer_count > 4 ? texture(splat_map1, splat_uv) : vec4(0.0);
	vec4 packed2 = active_layer_count > 8 ? texture(splat_map2, splat_uv) : vec4(0.0);
	vec4 packed3 = active_layer_count > 12 ? texture(splat_map3, splat_uv) : vec4(0.0);
	vec4 packed4 = active_layer_count > 16 ? texture(splat_map4, splat_uv) : vec4(0.0);
	vec4 packed5 = active_layer_count > 20 ? texture(splat_map5, splat_uv) : vec4(0.0);
	vec4 packed6 = active_layer_count > 24 ? texture(splat_map6, splat_uv) : vec4(0.0);
	vec4 packed7 = active_layer_count > 28 ? texture(splat_map7, splat_uv) : vec4(0.0);
	float weights[32] = {
		packed0.r, packed0.g, packed0.b, packed0.a,
		packed1.r, packed1.g, packed1.b, packed1.a,
		packed2.r, packed2.g, packed2.b, packed2.a,
		packed3.r, packed3.g, packed3.b, packed3.a,
		packed4.r, packed4.g, packed4.b, packed4.a,
		packed5.r, packed5.g, packed5.b, packed5.a,
		packed6.r, packed6.g, packed6.b, packed6.a,
		packed7.r, packed7.g, packed7.b, packed7.a
	};
	int top_indices[4] = {-1, -1, -1, -1};
	float top_weights[4] = {0.0, 0.0, 0.0, 0.0};
	for (int layer = 0; layer < 32; layer++) {
		if (layer >= active_layer_count) {
			break;
		}
		float candidate = clamp(weights[layer], 0.0, 1.0);
		for (int slot = 0; slot < 4; slot++) {
			if (candidate > top_weights[slot]) {
				for (int shift = 3; shift > slot; shift--) {
					top_weights[shift] = top_weights[shift - 1];
					top_indices[shift] = top_indices[shift - 1];
				}
				top_weights[slot] = candidate;
				top_indices[slot] = active_layer_indices[layer];
				break;
			}
		}
	}
	float painted_total = clamp(top_weights[0] + top_weights[1] + top_weights[2] + top_weights[3], 0.0, 1.0);
	float base_weight = 1.0 - painted_total;
	vec3 projection = projection_weights(world_normal);
	vec3 final_color = sample_triplanar(base_layer_index, world_position, projection) * layer_tints[base_layer_index].rgb * base_weight;
	float final_roughness = layer_roughness[base_layer_index] * base_weight;
	float macro_strength = layer_macro_variation[base_layer_index] * base_weight;
	for (int slot = 0; slot < 4; slot++) {
		int layer_index = top_indices[slot];
		float layer_weight = top_weights[slot];
		if (layer_index >= 0 && layer_weight > 0.001) {
			final_color += sample_triplanar(layer_index, world_position, projection) * layer_tints[layer_index].rgb * layer_weight;
			final_roughness += layer_roughness[layer_index] * layer_weight;
			macro_strength += layer_macro_variation[layer_index] * layer_weight;
		}
	}
	ALBEDO = final_color * (1.0 + macro_pattern(world_position) * macro_strength);
	ROUGHNESS = clamp(final_roughness, 0.04, 1.0);
	SPECULAR = 0.24;
	AO = 0.88;
}
