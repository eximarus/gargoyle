struct Camera {
    float4x4 view;
    float4x4 proj;
    float4x4 viewProj;
};

struct Object {
    float4x4 worldMat;
    float3 origin;
    uint firstIndex;

    Material *material;
};

struct DrawIndexedIndirectCommand {
    uint indexCount;
    uint instanceCount;
    uint firstIndex;
    int vertexOffset;
    uint firstInstance;
};

[[vk::binding(0, 0)]]
ConstantBuffer<Camera> camera;

namespace Cluster {

struct BoundingCone {
    float4 coneApex;
    float4 coneAxis;
};

struct Input {
    BoundingCone boundingCone;
    DrawIndexedIndirectCommand command;
};
}

namespace Scene {

struct BoundingSphere {
    float x;
    float y;
    float z;
    float r;
};

struct AABB {
    float min_x;
    float min_y;
    float min_z;
    float max_x;
    float max_y;
    float max_z;
};

struct Node {
    float x;
    float y;
    float z;
    float boundingRadius;
    uint materialID;
};

struct PushConstant {
    float3 cameraPos;
    float4 frustumPlanes[6];

    uint objectCount;
    Node *nodes;
};

[[vk::push_constant]]
ConstantBuffer<PushConstant> pushConst;

RWBuffer<uint2> drawCount;

bool coneApexCull(float3 apex, float3 axis, float coneAngle) {
    return dot(normalize(apex - pushConst.cameraPos), axis) < coneAngle;
}

bool frustumCull(float3 bboxMin, float3 bboxMax) {
    for (int i = 0; i < 6; ++i) {
        float4 plane = pushConst.frustumPlanes[i];
        float3 positiveVertex = float3(plane.x > 0.0 ? bboxMax.x : bboxMin.x,
                                       plane.y > 0.0 ? bboxMax.y : bboxMin.y,
                                       plane.z > 0.0 ? bboxMax.z : bboxMin.z);
        if (dot(plane.xyz, positiveVertex) + plane.w < 0.0)
            return true;
    }
    return false;
}

[shader("compute")]
[numthreads(256, 1, 1)]
void cullMain(uint dtid: SV_DispatchThreadID) {
    if (dtid == 0) {
        drawCount = 0;
    }

    GroupMemoryBarrierWithGroupSync();

    if (dtid >= pushConst.objectCount) {
        return;
    }

    let node = pushConst.nodes[dtid];

    bool cull_result = true;

    if (cull_result) {
        InterlockedAdd(drawCount[0].x, 1);
    }

    // Model model = compPushConst.models[id];
    // TODO culling turns instanceCount to 0
    // TODO VK_KHR_draw_indirect_count
    // pushConst.drawCommands[dtid].instanceCount = 1;
    // TODO meshlets
}

}

struct GraphicsPushConstant {
    Model *models;

    Vertex *vertices;
    float4x4 viewProjection;

    float3 eye;
    Material *materials;
    // Light *lights;
};

struct Vertex {
    float3 position : POSITION;
    float3 normal : NORMAL;
    float3 tangent : TANGENT;
    float4 color : COLOR;
    float2 uv : UV;
};

struct v2f {
    float3 worldPos;
    float2 uv;
    float4 color;
    float3x3 TBN;
    nointerpolation Material *material;
    float4 position : SV_Position;
};

[[vk::push_constant]]
ConstantBuffer<GraphicsPushConstant> gfxPushConst;

[shader("vertex")]
v2f vsMain(uint vertexID: SV_VertexID,
           [[KnownBuiltin("DrawIndex")]] uint drawID: POSITION0) {

    let v = gfxPushConst.vertices[vertexID];
    let model = gfxPushConst.models[drawID];
    let worldPos = mul(model.worldMat, float4(v.position, 1.0));

    float3 T = normalize(float3(mul(model.worldMat, float4(v.tangent, 1.0))));
    float3 N = normalize(float3(mul(model.worldMat, float4(v.normal, 1.0))));
    T = normalize(T - dot(T, N) * N);
    float3 B = cross(N, T);
    float3x3 TBN = float3x3(T, B, N);

    let pos = gfxPushConst.viewProjection * worldPos;
    return v2f(float3(worldPos), v.uv, v.color, TBN, model.material, pos);
}

// default direction = float3(0.0, 0.0, 1.0) worlspace
struct DirectionalLight {
    float3 rotation;
    float3 color;
    float intensity;
}

struct PointLight {
    float3 position; // worldSpace

    float3 color;
    float intensity;
    float range; // default to infinity
}

struct SpotLight {
    float3 position; // worldSpace
    float3 rotation;

    float3 color;
    float intensity;
    float range;          // default to infinity
    float innerConeAngle; // default 0
    float outerConeAngle; // default PI / 4.0
}

// PBR
struct Material {
    uint albedoTexID;
    uint metallicRoughnessTexID;
    uint normalTexID;
    uint occlusionTexID;
    uint emissiveTexID;

    float occlusionStrength;
};

[[vk::binding(0, 0)]]
Sampler2D textures[];

const float PI = 3.14159265359;

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

// float3 brdf() { let H = normalize(V + L); }

// float3 pbr(float3 N, float3 V, float3 L, float3 albedo, float metallic,
// float roughness, float occlusion, float emissive,
// float3 ambientColor) {

// var color = brdf(N, V, L, albedo, metallic, roughness);
// color += ambientColor * occlusion;
// color += emissive;

// return color;
//}

[shader("fragment"), require(spirv, sm_6_6, SPV_EXT_descriptor_indexing)]
float4 fsMain(v2f i) : SV_Target {
    let mat = i.material;

    let albedo = textures[mat.albedoTexID].Sample(i.uv).rgb;
    let metallicRoughness =
        textures[mat.metallicRoughnessTexID].Sample(i.uv).rgb;
    let metallic = metallicRoughness.b;
    let roughness = metallicRoughness.r;
    var normal = textures[mat.normalTexID].Sample(i.uv).rgb;
    normal = normal * 2.0 - 1.0;
    normal = normalize(i.TBN * normal);

    let occlusion =
        1.0 + mat.occlusionStrength *
                  (textures[mat.occlusionTexID].Sample(i.uv).r - 1.0);
    let emissive = textures[mat.emissiveTexID].Sample(i.uv).r;

    let eye = gfxPushConst.eye;

    let light = gfxPushConst.lights[0]; // TODO loop lights
    let V = normalize(eye - i.worldPos);
    let L = normalize(light.position - i.worldPos);

    return float4(pbr(normal, V, L, albedo, metallic, roughness, occlusion,
                      emissive, light.ambient),
                  1.0);
}

