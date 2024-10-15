struct Vertex {
    float3 position : POSITION;
    float3 normal   : NORMAL;
    float2 uv       : UV;
    float4 color    : COLOR;
    float4 tangent  : TANGENT;
};

struct v2f {
    float4 color    : COLOR;
    float2 uv       : UV;
    float3 normal   : NORMAL;
    float4 position : SV_Position;
};

struct PushConstant {
    float4x4 mvp;
    Vertex *vertices;
};

[[vk::push_constant]]
ConstantBuffer<PushConstant> pushConst;

[shader("vertex")]
v2f vsMain(uint vertexID : SV_VertexID) {
    Vertex v = pushConst.vertices[vertexID];
    v2f o;
    o.position = mul(pushConst.mvp, float4(v.position, 1.0));
    o.uv = v.uv;
    o.color = v.color;
    o.normal = v.normal;
    return o;
}

[[vk::binding(0, 0)]] Sampler2D texture;

[shader("fragment")]
float4 fsMain(v2f i) : SV_Target {
    return texture.Sample(i.uv);
}
