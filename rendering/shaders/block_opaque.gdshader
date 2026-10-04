// Opaque voxel surfaces. Block face textures live in one Texture2DArray;
// the layer index arrives in UV2.x and UV is in block units, so quads larger
// than one block (greedy meshing) tile correctly. COLOR carries baked AO.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform sampler2DArray block_textures : source_color, filter_nearest_mipmap, repeat_enable;

void fragment() {
	vec4 texel = texture(block_textures, vec3(UV, UV2.x));
	ALBEDO = texel.rgb * COLOR.rgb;
	ROUGHNESS = 1.0;
}
