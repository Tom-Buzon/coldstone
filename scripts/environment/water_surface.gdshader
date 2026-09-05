shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.08, 0.42, 0.52, 0.58);
uniform vec4 deep_color : source_color = vec4(0.015, 0.10, 0.20, 0.74);
uniform sampler2D surface_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_surface_texture = false;
uniform float texture_scale : hint_range(0.25, 32.0) = 4.0;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.18;
uniform float wave_scale : hint_range(0.05, 4.0) = 0.55;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.7;
uniform float wave_height : hint_range(0.0, 0.5) = 0.08;
uniform float roughness_value : hint_range(0.02, 1.0) = 0.18;
uniform float opacity : hint_range(0.05, 1.0) = 0.68;

varying vec3 world_position;

void vertex() {
	vec3 global_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float first = sin((global_position.x + TIME * wave_speed) * wave_scale);
	float second = cos((global_position.z - TIME * wave_speed * 0.73) * wave_scale * 1.37);
	VERTEX.y += (first + second) * wave_height * 0.5;
	world_position = global_position;
}

void fragment() {
	float ripples = sin((world_position.x + world_position.z) * wave_scale * 2.1 + TIME * wave_speed * 1.6) * 0.5 + 0.5;
	vec3 water_color = mix(deep_color.rgb, shallow_color.rgb, 0.32 + ripples * 0.18);
	if (use_surface_texture) {
		vec3 detail = texture(surface_texture, UV * texture_scale + vec2(TIME * wave_speed * 0.01, 0.0)).rgb;
		water_color = mix(water_color, water_color * (0.55 + detail * 0.7), texture_strength);
	}
	ALBEDO = water_color;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.72;
	METALLIC = 0.0;
	EMISSION = shallow_color.rgb * ripples * 0.035;
	ALPHA = opacity;
}
