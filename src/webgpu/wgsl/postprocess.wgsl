struct VSIn {
	@location(0) position: vec2f,
};

struct VSOut {
	@builtin(position) 	position: 	vec4f,
	@location(0) 		uv: 		vec2f,
};

@group(0) @binding(0) var src_texture: texture_2d<f32>;
@group(0) @binding(1) var dst_texture: texture_storage_2d<rgba16float,write>;

@vertex
fn vs_main(in: VSIn) -> VSOut {
	var out: VSOut;
	out.position = vec4f(in.position, 0.0, 1.0);
	out.uv = in.position * 0.5 + 0.5;
	return out;
}

@fragment
fn fs_main(in: VSOut) -> @location(0) vec4f {
    let L: vec4f = textureLoad(src_texture, vec2i(in.position.xy), 0);

    textureStore(dst_texture, vec2i(in.position.xy), L);

    /* TODO: tonemap */
    return L;
}
