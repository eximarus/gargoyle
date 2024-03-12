@group(0)
@binding(0) 
var<uniform> view_proj_mat: mat4x4<f32>;

struct VertexOut {
    @builtin(position) pos: vec4<f32>,
    @location(0) color: vec4<f32>,
    @location(1) tex_coord: vec2<f32>,
}

@vertex
fn main(
    @location(0) pos: vec3<f32>,
    @location(1) color: vec4<f32>,
    @location(2) tex_coord: vec2<f32>,
) -> VertexOut {
    var out: VertexOut;
    out.pos = view_proj_mat * vec4(pos, 1.0);
    out.color = color;
    out.tex_coord = tex_coord;
    return out;
}
