shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.65;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec4 zone_visibility_0 = vec4(1.0);
uniform vec4 zone_visibility_1 = vec4(1.0);
uniform vec2 zone_visibility_2 = vec2(1.0);

varying float body_zone;

void vertex() {
	body_zone = COLOR.r;
}

void fragment() {
	int zone = int(floor(body_zone * 10.0));
	float zone_visible = 1.0;
	if (zone == 0) zone_visible = zone_visibility_0.x;
	else if (zone == 1) zone_visible = zone_visibility_0.y;
	else if (zone == 2) zone_visible = zone_visibility_0.z;
	else if (zone == 3) zone_visible = zone_visibility_0.w;
	else if (zone == 4) zone_visible = zone_visibility_1.x;
	else if (zone == 5) zone_visible = zone_visibility_1.y;
	else if (zone == 6) zone_visible = zone_visibility_1.z;
	else if (zone == 7) zone_visible = zone_visibility_1.w;
	else if (zone == 8) zone_visible = zone_visibility_2.x;
	else if (zone == 9) zone_visible = zone_visibility_2.y;
	if (zone_visible < 0.5) {
		discard;
	}
	vec4 base = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = base.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
