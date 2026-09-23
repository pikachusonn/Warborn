shader_type canvas_item;
render_mode unshaded;
uniform float opacity : hint_range(0.0, 1.0) = 0.3;
uniform bool hovered = false;
uniform vec2 cloud_offset = vec2(0.0);
uniform vec2 cutout_origins[100];
uniform int cutout_count = 0;
varying vec2 board_position;

void vertex() {
	board_position = VERTEX + cloud_offset;
}

void fragment() {
	// Anchor holes to the floor, independently of the cloud's height and drift.
	for (int i = 0; i < cutout_count; i++) {
		vec2 tile_position = board_position - cutout_origins[i];
		if (tile_position.x >= 0.0 && tile_position.y >= 0.0
			&& tile_position.x <= 64.0 && tile_position.y <= 64.0) {
			discard;
		}
	}
	vec4 source = texture(TEXTURE, UV);
	// The supplied sheet has a warm dark backdrop; retain the cool cloud pixels.
	float cloud_mask = smoothstep(0.005, 0.045, source.b - source.r);
	vec3 pale_cloud = mix(vec3(0.78, 0.84, 0.94), vec3(1.0), source.r);
	vec3 cloud_color = hovered ? source.rgb : pale_cloud;
	COLOR = vec4(cloud_color, source.a * cloud_mask * opacity);
}
