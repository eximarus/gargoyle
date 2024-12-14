struct v2f {
    float4 position : SV_Position;
    float4 color    : COLOR;
    float3 normal   : NORMAL;
    nointerpolation uint drawID;
    float2 uv       : UV;
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

[[vk::push_constant]] ConstantBuffer<PushConstant> pushConst;

[shader("vertex")]
v2f vsMain(
    uint vertexID : SV_VertexID,
    uint drawID : SV_DrawIndex,
) {
    Vertex v = pushConst.vertices[vertexID];
    v2f o;
    o.position = mul(pushConst.mvp, float4(v.position, 1.0));
    o.uv = float2(v.uv_x, v.uv_y);
    o.color = v.color;
    o.normal = v.normal;
    o.drawID = drawID;
    return o;
}

static const float PI = 3.14159265359;

float DistributionGGX(float3 N, float3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float nom = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return nom / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float nom = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}

float GeometrySmith(float3 N, float3 V, float3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

float3 fresnelSchlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

float3 brdf(
    float3 N,
    float3 V,
    float3 L,
    float3 F0,
    float3 albedo,
    float metallic,
    float roughness,
) {
    let H = normalize(L + V);

    let NdotL = max(dot(N, L), 0.0);

    let NDF = DistributionGGX(N, H, roughness);
    let G = GeometrySmith(N, V, L, roughness);
    let F = fresnelSchlick(max(dot(H,V), 0.0), F0);
    
    var kD = float3(1.0) - F;
    kD *= 1.0 - metallic;

    let denominator = 4.0 * max(dot(N, V), 0.0) * NdotL + 0.0001;
    let specular = (NDF * G * F) / denominator;

    return (kD * albedo / PI + specular) * NdotL;
}

struct DirectionalLight {
    float3 direction;
    float3 color;
    float intensity;
}

struct PointLight {
    float3 position; 
    float3 color;
    float intensity;
}

struct SpotLight {
    float3 position; 
    float3 direction;
    float3 color;
    float intensity;

    float innerConeAngle; 
    float outerConeAngle;
}

struct Material {
    uint albedoTexID;
    uint metallicRoughnessTexID;
    uint normalTexID;
    uint occlusionTexID;
    uint emissiveTexID;

    float occlusionStrength;
};

struct FsUniforms {
    Sampler2D textures[];
};

[shader("fragment")]
float4 fsMain(
    Sampler2D textures[],
    //uniform ParameterBlock<FsUniforms> u, 
    v2f i
) : SV_Target {
    return textures[i.drawID].Sample(i.uv);
}
