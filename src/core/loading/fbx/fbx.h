#include<stdbool.h>
#include<stdint.h>


#ifdef __cplusplus
#include <fbxsdk.h>

typedef FbxManager* FbxManagerHandle;
typedef FbxImporter* FbxImporterHandle;
typedef FbxDocument* FbxDocumentHandle;
typedef FbxScene* FbxSceneHandle;

extern "C" {
#else

typedef void* FbxManagerHandle;
typedef void* FbxImporterHandle;
typedef void* FbxDocumentHandle;
typedef void* FbxSceneHandle;

#endif

typedef struct FbxParsedVertex {
    float position[3];
    float normal[3];
    float uv[2];
    float color[4];
    float tangent[4];
}FbxParsedVertex;

typedef struct FbxParsedMesh {
    int vertex_count;
    FbxParsedVertex* vertices;
    int index_count;
    int* indices;
}FbxParsedMesh ;

typedef struct FbxParsedScene{
    int mesh_count;
    FbxParsedMesh *meshes;
}FbxParsedScene;


FbxManagerHandle fbxManagerCreate(void);
void fbxManagerDestroy(FbxManagerHandle);

FbxImporterHandle fbxImporterCreate(FbxManagerHandle);
bool fbxImporterInitialize(FbxImporterHandle, const char*, FbxManagerHandle);
const char* fbxImporterGetErrorString(FbxImporterHandle);
void fbxImporterImport(FbxImporterHandle, FbxSceneHandle);
void fbxImporterDestroy(FbxImporterHandle);

FbxSceneHandle fbxSceneCreate(FbxManagerHandle, const char*);
void fbxParseScene(FbxSceneHandle fbx_scene);

#ifdef __cplusplus
}
#endif
