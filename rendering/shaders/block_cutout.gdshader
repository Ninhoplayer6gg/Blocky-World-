// Alpha-tested voxel surfaces (leaves, glass). Same layout as block_opaque.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform sampler2DArray block_textures : source_color, filter_nearest_mipmap, repeat_enable;
uniform float alpha_cutoff = 0.5;

void fragment() {
	vec4 texel = texture(block_textures, vec3(UV, UV2.x));
	ALBEDO = texel.rgb * COLOR.rgb;
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = 1.0;
}
