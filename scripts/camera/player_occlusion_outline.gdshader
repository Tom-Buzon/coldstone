shader_type canvas_item;
render_mode unshaded;
uniform vec4 outline_color : source_color = vec4(0.0, 0.78622156, 0.5315931, 1.0);
void fragment() {
	float center = texture(TEXTURE, UV).a;
	float expanded = center;
	for (int y = -3; y <= 3; y++) {
		for (int x = -3; x <= 3; x++) {
			if (x*x + y*y <= 9) {
				expanded = max(expanded, texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE).a);
			}
		}
	}
	COLOR = vec4(outline_color.rgb, outline_color.a * max(0.0, expanded - center));
}
