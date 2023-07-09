//
//  ShaderDefinitions.h
//  MetalProject
//
//  Created by Sina Dashtebozorgy on 09/07/2023.
//

#ifndef ShaderDefinitions_h
#define ShaderDefinitions_h


#include <simd/simd.h>


struct PivotBuffer {
    simd_int2 start_index;
    simd_int2 end_index;
};


enum GPU_Sorting_shader {
    X_ascending = 0,
    Y_ascending = 1,
    X_descending = 2,
    Y_descending = 3
};


struct vector3{
    float x;
    float y;
    float z;
};

typedef struct vector3 vector_3;

struct RT_Camera {
    simd_float3 origin;
    simd_float3 right;
    simd_float3 up;
    simd_float3 forward;
};

struct Sphere {
    simd_float3 origin;
    simd_float3 colour;
    float radiusSquared;
    float radius;
    
};





struct Transforms {
    simd_float4x4 Scale;
    simd_float4x4 Translate;
    simd_float4x4 Rotation;
    simd_float4x4 Projection;
    simd_float4x4 Camera;
    
};


struct InstanceConstants {
    simd_float4x4 modelMatrix;
    simd_float4x4 normalMatrix;
};

struct FrameConstants {
    simd_float4x4 viewMatrix;
    simd_float4x4 projectionMatrix;
};


struct lightConstants {
    simd_float4x4 lightViewMatrix;
    simd_float4x4 lightProjectionMatrix;
};

struct Lights {
    simd_float3 direction;
    simd_float3 position;
    uint type;
};


typedef struct Vertex {
    vector_3 pos;
    vector_3 normal;
}Vertex;

struct Triangle{
    Vertex data[3];
};


typedef enum rayTracingPipeLineConstants : int {
    directLighting,
    ambientLighting,
}RTPipelineFCs;






#endif /* ShaderDefinitions_h */
