struct v2f {
    float4 color    : COLOR;
    float2 uv       : UV;
    float3 normal   : NORMAL;
    float4 position : SV_Position;
};

struct Vertex {
    float3 position;
    float uv_x;
    float3 normal;
    float uv_y;
    float4 color;
    float3 tangent;
};


struct PushConstant {
    float4x4 mvp;
    Vertex *vertices;
};

[shader("vertex")]
v2f vsMain(
    [[vk::push_constant]] ConstantBuffer<PushConstant> pushConst, 
    uint vertexID : SV_VertexID
) {
    Vertex v = pushConst.vertices[vertexID];
    v2f o;
    o.position = mul(pushConst.mvp, float4(v.position, 1.0));
    o.uv = float2(v.uv_x, v.uv_y);
    o.color = v.color;
    o.normal = v.normal;
    return o;
}

[shader("fragment")]
float4 fsMain(
    uniform ParameterBlock<Sampler2D> texture, 
    v2f i
) : SV_Target {
    return texture.Sample(i.uv);
}
