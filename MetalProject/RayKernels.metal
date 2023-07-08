//
//  RayKernels.metal
//  MetalProject
//
//  Created by Sina Dashtebozorgy on 04/07/2023.
//

#include <metal_stdlib>

using namespace metal;
using namespace metal::raytracing;

#include "ShaderDefinition.h"






struct BoundingBoxIntersection {
    bool accept [[accept_intersection]];
    float distance [[distance]];
};

struct IntersectionData {
    float3 normal;
    float3 intersection_point;
};




//sphere intersection function
[[intersection(bounding_box,triangle_data,instancing,world_space_data)]]
BoundingBoxIntersection sphereIntersection(float3 origin [[origin]],
                                           float3 direction [[direction]],
                                           float minDistance [[min_distance]],
                                           float maxDistance [[max_distance]],
                                           ray_data IntersectionData& intersection_data [[payload]],
                                           float4x3 objToWorld [[object_to_world_transform]],
                                           const device Sphere* sphere [[primitive_data]]
                                           ){
    Sphere current_sphere = *sphere;
    
    float3 oc = origin - float3(0);

    float a = dot(direction, direction);
    float b = 2 * dot(oc, direction);
    float c = dot(oc, oc) - current_sphere.radiusSquared;

    float disc = b * b - 4 * a * c;

    BoundingBoxIntersection ret;

    if (disc <= 0.0f) {
        // If the ray missed the sphere, return false.
        ret.accept = false;
    }
    else {
        // Otherwise, compute the intersection distance.
        ret.distance = (-b - sqrt(disc)) / (2 * a);
        

        // The intersection function must also check whether the intersection distance is
        // within the acceptable range. Intersection functions do not run in any particular order,
        // so the maximum distance may be different from the one passed into the ray intersector.
        ret.accept = ret.distance >= minDistance && ret.distance <= maxDistance;
        if(ret.accept){
            simd_float4x4 objectMatrix(1);
            
            for (int column = 0; column < 4; column++)
                for (int row = 0; row < 3; row++)
                    objectMatrix[column][row] = objToWorld[column][row];
            
            float3 intersectionPoint = origin + ret.distance * direction;
            intersection_data.normal = normalize(intersectionPoint - current_sphere.origin);
            intersection_data.intersection_point = (objectMatrix * float4(intersectionPoint,1)).xyz;
            
            
        }
    }

    return ret;
}





kernel void RayTracing(texture2d<float, access::write> drawable [[texture(0)]],
                       uint2 tid [[thread_position_in_grid]],
                       primitive_acceleration_structure PAS [[buffer(0)]],
                       intersection_function_table<> functionTable [[buffer(1)]]
                       ){
    
    ray ray;
    float2 pixel = (float2)tid;
    float2 uv = (float2)pixel / float2(800,800);
    uv = uv * 2.0f - 1.0f;
    ray.origin = float3(0,0,0);
    ray.direction = normalize(uv.x * float3(1,0,0) + uv.y * float3(0,1,0) + float3(0,0,-1));
    ray.max_distance = INFINITY;
    ray.min_distance = 0;
    
    
    intersector<> i;
    IntersectionData intersection_data;
    typename intersector<>::result_type intersection;
    intersection = i.intersect(ray,PAS,functionTable,intersection_data);
    if(intersection.type == intersection_type::none){
        drawable.write(float4(1,1,1,1),tid);
    }
    else{
        Sphere sphere = *(const device Sphere*)(intersection.primitive_data);
        float4 colour = float4(intersection_data.intersection_point,1);
        drawable.write(colour,tid);
    }
    
    
}


float simple_lighting(IntersectionData intersection_data, simd_float3 light_position){
    
    float3 to_light = light_position - intersection_data.intersection_point;
    float3 to_view = normalize(- intersection_data.intersection_point);
    float distance = length(to_light);
    float light_strength = 1 / (4 * 3.14 * distance);
    
    to_light = normalize(to_light);
    float3 reflection = normalize(reflect(-to_light, intersection_data.normal));
    
    float specular_strength = pow(saturate(dot(to_view,reflection)),50);
    
    
    return saturate(dot(to_light,intersection_data.normal)) + specular_strength;
    
}



kernel void RayTracing_Instanced(texture2d<float, access::write> drawable [[texture(0)]],
                       uint2 tid [[thread_position_in_grid]],
                       instance_acceleration_structure PAS [[buffer(0)]],
                       intersection_function_table<triangle_data,instancing,world_space_data> functionTable [[buffer(1)]],
                       constant packed_float4* sphereColours [[buffer(10)]],
                       constant RT_Camera& camera [[buffer(11)]]
                       ){
    
    ray ray;
    float2 pixel = (float2)tid;
    float2 uv = (float2)pixel / float2(800,800);
    uv = uv * 2.0f - 1.0f;
    ray.origin = camera.origin;
    ray.direction = normalize(uv.x * camera.right + uv.y * camera.up + camera.forward);
    ray.max_distance = INFINITY;
    
    //drawable.write(float4(1,0,1,1),tid);
    
    intersector<triangle_data,instancing,world_space_data> i;
    typename intersector<triangle_data,instancing,world_space_data>::result_type intersection;
    IntersectionData intersection_data;
    float3 intersection_point;
    float3 light = simd_float3(0,0,10);
    intersection = i.intersect(ray, PAS, functionTable, intersection_data);
    if(intersection.type == intersection_type::none){
        drawable.write(float4(1,1,1,1),tid);
    }
    else{
       
        uint instanceID = intersection.instance_id;
        Sphere sphere = *(const device Sphere*)(intersection.primitive_data);
        float4 colour = float4(sphereColours[instanceID].rgb * simple_lighting(intersection_data, light),1);
        drawable.write(colour,tid);
    }
    
    
}








constant simd_float4 QuadVertices[4] = {
    simd_float4(-1,-1,0,1),
    simd_float4(1,-1,0,1),
    simd_float4(-1,1,0,1),
    simd_float4(1,1,0,1)
};

constant simd_float2 QuadTex[4] = {
    simd_float2(0,0),
    simd_float2(1,0),
    simd_float2(0,1),
    simd_float2(1,1)
};


struct QuadOut {
    simd_float4 pos [[position]];
    simd_float2 tex;
};




vertex QuadOut drawToScreenVertex(uint vID [[vertex_id]]){
    QuadOut out;
    out.pos = QuadVertices[vID];
    out.tex = QuadTex[vID];
    return out;
    
};

fragment float4 drawToScreenFragment(QuadOut in [[stage_in]],
                                     texture2d<float> drawable [[texture(0)]]){
    
    constexpr sampler normal_sampler(coord::normalized,
                                    address::clamp_to_edge,
                                    filter::nearest,
                                    compare_func::less);
    
    return drawable.sample(normal_sampler,in.tex);
    
    return float4(0,1,0,1);
};

