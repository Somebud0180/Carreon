shader_type canvas_item;
render_mode unshaded, blend_mix;

// Flat ghost overlay to keep the character visible behind cover.
uniform vec4 ghost_color : source_color = vec4(0.20, 0.85, 1.0, 0.35);
uniform float outline_size = 1.2;
uniform float outline_strength = 0.65;

void fragment() {
	vec2 uv = UV;
	float base_alpha = texture(TEXTURE, uv).a;

	// Simple 4-neighbor dilation for a soft outline.
	vec2 px = TEXTURE_PIXEL_SIZE * outline_size;
	float dilated = 0.0;
	dilated = max(dilated, texture(TEXTURE, uv + vec2(px.x, 0.0)).a);
	dilated = max(dilated, texture(TEXTURE, uv + vec2(-px.x, 0.0)).a);
	dilated = max(dilated, texture(TEXTURE, uv + vec2(0.0, px.y)).a);
	dilated = max(dilated, texture(TEXTURE, uv + vec2(0.0, -px.y)).a);

	float outline_only = max(dilated - base_alpha, 0.0) * outline_strength;
	float final_alpha = clamp(base_alpha + outline_only, 0.0, 1.0) * ghost_color.a;

	COLOR = vec4(ghost_color.rgb, final_alpha);
}
