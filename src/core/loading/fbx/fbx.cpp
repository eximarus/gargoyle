#include "fbx.h"

extern "C" {
    FbxManagerHandle fbxManagerCreate() {
        return FbxManager::Create();
    }

    void createFbxIOSettings(FbxManagerHandle fbx_manager) {
         FbxIOSettings* ios = FbxIOSettings::Create(fbx_manager, IOSROOT);
         fbx_manager->SetIOSettings(ios);
    }

    FbxImporterHandle fbxImporterCreate(FbxManagerHandle fbx_manager) {
        return FbxImporter::Create(fbx_manager, "");
    }

    bool fbxImporterInitialize(FbxImporterHandle fbx_importer, const char* filename, FbxManagerHandle fbx_manager) {
        return fbx_importer->Initialize(filename, -1, fbx_manager->GetIOSettings());
    }

    const char* fbxImporterGetErrorString(FbxImporterHandle fbx_importer) {
        return fbx_importer->GetStatus().GetErrorString();
    }

    FbxSceneHandle fbxSceneCreate(FbxManagerHandle fbx_manager, const char* name) {
        return FbxScene::Create(fbx_manager, name);
    }

    void fbxImporterImport(FbxImporterHandle fbx_importer, FbxSceneHandle fbx_scene) {
        fbx_importer->Import(fbx_scene);
    }

    void fbxImporterDestroy(FbxImporterHandle fbx_importer) {
        fbx_importer->Destroy();
    }

    void fbxManagerDestroy(FbxManagerHandle fbx_manager) {
        fbx_manager->Destroy();
    }

    static void fbxParseNode(FbxNode* node) {
        const char* node_name = node->GetName();
        // FbxDouble3 translation = node->LclTranslation.Get();
        // FbxDouble3 rotation = node->LclRotation.Get();
        // FbxDouble3 scaling = node->LclScaling.Get();

        for(int i = 0; i < node->GetNodeAttributeCount(); i++) {
            FbxNodeAttribute* attribute = node->GetNodeAttributeByIndex(i);
            switch(attribute->GetAttributeType()) {
            case FbxNodeAttribute::eMesh: {
                FbxMesh* mesh = (FbxMesh*)attribute;

                break;
            }
            default:
                break;
            }
        }

        for(int i = 0; i < node->GetChildCount(); i++) {
            fbxParseNode(node->GetChild(i));
        }
    }

    void fbxParseScene(FbxSceneHandle fbx_scene) {
        FbxNode* root_node = fbx_scene->GetRootNode();
        if(!root_node) {
            return; //NULL;
        }

        for(int i = 0; i < root_node->GetChildCount(); i++) {
            FbxNode* node = root_node->GetChild(i);
            fbxParseNode(node);
        }
    }
}
