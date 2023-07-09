//
//  sorting.metal
//  MetalProject
//
//  Created by Sina Dashtebozorgy on 21/09/2023.
//

#include <metal_stdlib>
#include "ShaderDefinitions.h"
using namespace metal;

constexpr constant unsigned int maxDigit = 3;
constexpr constant float toFloat = float(1)/255;


enum Axis : uint {
    x = 0,
    y = 1
};



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
    constexpr sampler s = sampler(coord::normalized,
    address::clamp_to_zero,
    filter::nearest);
    in.tex.y = 1 - in.tex.y;
    //float4 colour = float4(drawable.sample(s,in.tex).r * toFloat,0,0,1);
    float4 colour = drawable.sample(s, in.tex);
    return colour;
    
}




















[[visible]] void mergeArrays_test_descending(texture2d<float, access::read> input, texture2d<float, access::write> output, int2 global_leftOffset, int2 global_rightOffset, uint left_length, uint right_length, int2 global_outputWriteOffset, int2 moveVector){
    uint mergedArray_length = left_length + right_length;
    uint local_leftOffset = 0;
    uint local_rigthOffset = 0;
    uint local_writeOffset = 0;
    
    for(uint i = 0; i != mergedArray_length; i++){
        // reached end of left
        // so iterate over rest of right
        if(local_leftOffset == left_length){
            uint current_startIter = local_rigthOffset;
            uint current_endIter = right_length;
            for(uint j = current_startIter; j != current_endIter; j++){
                int2 current_writeOffset = local_writeOffset * moveVector + global_outputWriteOffset;
                int2 current_readOffset = local_rigthOffset * moveVector + global_rightOffset;
                simd_float3 element = input.read(uint2(current_readOffset)).rgb;
                output.write(simd_float4(element,1), uint2(current_writeOffset));
                local_writeOffset++;
                local_rigthOffset++;
            }
            break;
        }
        //reached end of right so iterate over rest of left
        else if(local_rigthOffset == right_length){
            uint current_startIter = local_leftOffset;
            uint current_endIter = left_length;
            for(uint j = current_startIter; j != current_endIter; j++){
                int2 current_writeOffset = local_writeOffset * moveVector + global_outputWriteOffset;
                int2 current_readOffset = local_leftOffset * moveVector + global_leftOffset;
                simd_float3 element = input.read(uint2(current_readOffset)).rgb;
                output.write(simd_float4(element,1), uint2(current_writeOffset));
                local_writeOffset++;
                local_leftOffset++;
            }
            break;
            
            
        }
        else{
            int2 leftRead = local_leftOffset * moveVector + global_leftOffset;
            int2 rightRead = local_rigthOffset * moveVector + global_rightOffset;
            simd_float3 leftElement = input.read(uint2(leftRead)).rgb;
            simd_float3 rightElement = input.read(uint2(rightRead)).rgb;
            
            int2 current_writeOffset = local_writeOffset * moveVector + global_outputWriteOffset;
            if(leftElement.r >= rightElement.r){
                output.write(simd_float4(leftElement,1), uint2(current_writeOffset));
                local_leftOffset++;
            }
            else{
                output.write(simd_float4(rightElement,1), uint2(current_writeOffset));
                local_rigthOffset++;
            }
            local_writeOffset++;
            
        }
    }
}

[[visible]] void mergeArrays_test_ascending(texture2d<float, access::read> input, texture2d<float, access::write> output, int2 global_leftOffset, int2 global_rightOffset, uint left_length, uint right_length, int2 global_outputWriteOffset, int2 moveVector){
    uint mergedArray_length = left_length + right_length;
    uint local_leftOffset = 0;
    uint local_rigthOffset = 0;
    uint local_writeOffset = 0;
    
    for(uint i = 0; i != mergedArray_length; i++){
        // reached end of left
        // so iterate over rest of right
        if(local_leftOffset == left_length){
            uint current_startIter = local_rigthOffset;
            uint current_endIter = right_length;
            for(uint j = current_startIter; j != current_endIter; j++){
                int2 current_writeOffset = local_writeOffset * moveVector + global_outputWriteOffset;
                int2 current_readOffset = local_rigthOffset * moveVector + global_rightOffset;
                simd_float3 element = input.read(uint2(current_readOffset)).rgb;
                output.write(simd_float4(element,1), uint2(current_writeOffset));
                local_writeOffset++;
                local_rigthOffset++;
            }
            break;
        }
        //reached end of right so iterate over rest of left
        else if(local_rigthOffset == right_length){
            uint current_startIter = local_leftOffset;
            uint current_endIter = left_length;
            for(uint j = current_startIter; j != current_endIter; j++){
                int2 current_writeOffset = local_writeOffset * moveVector + global_outputWriteOffset;
                int2 current_readOffset = local_leftOffset * moveVector + global_leftOffset;
                simd_float3 element = input.read(uint2(current_readOffset)).rgb;
                output.write(simd_float4(element,1), uint2(current_writeOffset));
                local_writeOffset++;
                local_leftOffset++;
            }
            break;
            
            
        }
        else{
            int2 leftRead = local_leftOffset * moveVector + global_leftOffset;
            int2 rightRead = local_rigthOffset * moveVector + global_rightOffset;
            simd_float3 leftElement = input.read(uint2(leftRead)).rgb;
            simd_float3 rightElement = input.read(uint2(rightRead)).rgb;
            
            int2 current_writeOffset = local_writeOffset * moveVector + global_outputWriteOffset;
            if(leftElement.r <= rightElement.r){
                output.write(simd_float4(leftElement,1), uint2(current_writeOffset));
                local_leftOffset++;
            }
            else{
                output.write(simd_float4(rightElement,1), uint2(current_writeOffset));
                local_rigthOffset++;
            }
            local_writeOffset++;
            
        }
    }
}
    
    



kernel void mergeSortPixels_test(texture2d<float, access::read> input [[texture(0)]],
                            texture2d<float, access::write> output [[texture(1)]],
                            constant uint& slice_length [[buffer(0)]],
                            constant uint& axis [[buffer(1)]],
                            constant bool& ascending [[buffer(2)]],
                            visible_function_table<void(texture2d<float,access::read>, texture2d<float,access::write>,int2,int2,uint,uint,int2,int2)> mergeFunctions [[buffer(3)]],
                            uint tid [[thread_index_in_threadgroup]],
                            uint tgig [[threadgroup_position_in_grid]]
                            ){
   
    
    
    uint width = input.get_width();
    uint height = input.get_height();
    int2 stride{};
    int2 halfStride{};
    int2 start{};
    uint length{};
    int2 moveVector{};
    uint iterationCount;
    
    
    
    switch (axis){
            // sorting along x
        case 0:
            stride = int2(slice_length * 2, 0);
            halfStride = int2(slice_length,0);
            start = int2(0,tgig);
            length = width;
            moveVector = int2(1,0);
            break;
            // sorting along y
        case 1:
            stride = int2(0, slice_length * 2);
            halfStride = int2(0,slice_length);
            start = int2(tgig,0);
            length = height;
            moveVector = int2(0,1);
            break;
        case 2:
            if(tgig / height < 1){
                start = int2(0,tgig);
                stride = int2(slice_length * 2, - slice_length * 2);
                halfStride = stride / 2;
                length = tgig + 1;
                moveVector = int2(1,-1);
            }
            else{
                start = int2(tgig % width + 1, height - 1);
                stride = int2(slice_length * 2, - slice_length * 2);
                halfStride = stride / 2;
                length = width - start.x;
                moveVector = int2(1,-1);
            }
            
    }
    
    
    iterationCount = length / (32 * slice_length * 2) + ((length % (32 * slice_length * 2) == 0) ? 0 : 1);
    int2 left_offset = start + tid * stride;
    //uint2 left_offset = start + tid * int2(stride,-stride);
    int2 right_offset = left_offset + halfStride;
    uint iteration_offset = 32 * slice_length * 2;
    uint thread_left_offset = tid * slice_length * 2;
    uint thread_right_offset = tid * slice_length * 2 + slice_length;
    
    // diagonal
    
    for(uint i = 0; i != iterationCount; i++){
        uint offset = i * iteration_offset;
        int2 current_left_offset = offset * moveVector + left_offset;
        int2 current_right_offset = offset * moveVector + right_offset;
        if(offset + thread_left_offset  > length){
            break;
        }
            // get the elements that need to go into left threadgroup
        // do not merge arrays if leftReadOffset.x + sliceLength == array_length
        uint leftSliceLength = slice_length;
        if(offset + thread_left_offset + slice_length >= length){
            // if this is true then we need to pop all these elements in output
            int end_iter = length - (offset + tid * slice_length * 2);
            if(end_iter >= 0){
                uint current_startIter = offset + thread_left_offset;
                uint current_endIter = length;
                for(uint i = current_startIter; i != current_endIter; i++){
                    int2 current_readOffset = start + i * moveVector;
                    int2 current_writeOffset = current_readOffset;
                    simd_float4 current_element{input.read(uint2(current_readOffset))};
                    output.write(current_element, uint2(current_writeOffset));
                }
            }
           
            break;
        }
            
         //get the elememnts that need to go into right threadgroup
        
        uint rightSliceLength = slice_length;
        if(offset + thread_right_offset + slice_length > length){
            rightSliceLength = length - (offset + thread_right_offset);
        }

        mergeFunctions[ascending ? 0 : 1](input, output, current_left_offset, current_right_offset, leftSliceLength, rightSliceLength, current_left_offset, moveVector);
        
    }
    
    
}
    

    
kernel void radixSort_lsb(texture2d<float, access::read> input [[texture(0)]],
                          texture2d<float, access::write> output [[texture(1)]],
                          constant uint& frameIndex [[buffer(0)]],
                          constant uint& axis [[buffer(1)]],
                          constant bool& ascending [[buffer(2)]],
                          // put the lsbs here when they are extracted so we won't need to do that again
                          threadgroup uint8_t* LSB [[threadgroup(0)]],
                          uint tisg [[thread_index_in_simdgroup]],
                          uint titg [[thread_index_in_threadgroup]],
                          uint tptg [[threads_per_threadgroup]],
                          uint tgig [[threadgroup_position_in_grid]]
                          
                          ){
    threadgroup simd_uint2 one_zeros;
    if(titg == 0){
        one_zeros = simd_uint2(0,0);
    }
    
    uint width = output.get_width();
    uint height = output.get_height();
    uint threadCount = tptg;
    
    
    uint remainder = width % threadCount;
    uint iterationCount = width / threadCount + (remainder == 0 ? 0 : 1);
    uint correction = (32 - ((width - iterationCount * 32 ) % 32)) % 32;
    // only used if we are sorting diagonally
    uint2 start{};
    uint2 end{};
    uint iteration_width = 0;
    
    // if diagonal we need to change the iteration count
    if(axis == 2){
        
        if(tgig / height < 1){
            start = uint2(0,tgig);
            uint y_0 = tgig;
            uint y_max = 0;
            iteration_width = y_0 - y_max + 1;
            remainder = iteration_width % threadCount;
            iterationCount = iteration_width / threadCount + (remainder == 0 ? 0 : 1);
            correction = (32 - ((iteration_width - iterationCount * 32 ) % 32)) % 32;
            end = uint2(tgig,0);
        }
        
        else{
            start = uint2(tgig % width + 1,height - 1);
            uint x_0 = tgig % width + 1;
            uint x_max = width;
            iteration_width = x_max - x_0 ;
            remainder = iteration_width % threadCount;
            iterationCount = iteration_width / threadCount + (remainder == 0 ? 0 : 1);
            correction = (32 - ((iteration_width - iterationCount * 32 ) % 32)) % 32;
            end = uint2(width - 1, tgig % width + 1);
        }
    }
    
    
    for(uint i = 0; i != iterationCount; i++){
        
        uint offset = i * threadCount;
        // sort along x
        uint8_t r;
        if(axis == 0){
            r = input.read(uint2(tisg + offset,tgig)).r * 255;

        }
        // sort along y
        else if(axis == 1){
            r = input.read(uint2(tgig, tisg + offset)).r * 255;
        }
        // diagonal
        else{
            // find the diagonal length
            //uint2 offset{i * threadCount};
            uint2 readOffset = start + uint2(tisg + offset,-tisg - offset);
            r = input.read(readOffset).r * 255;
        }
            uint8_t lsb = (1) & (r >> frameIndex);
            uint8_t inverse_lsb = lsb ^ 1;
            one_zeros.y += simd_sum(lsb);
            one_zeros.x += simd_sum(inverse_lsb);
            LSB[tisg + offset] = lsb;
       
    }
    
    simd_active_threads_mask();
    threadgroup_barrier(mem_flags::mem_threadgroup);
//    
    if(titg == 0){
        one_zeros[0] = one_zeros[0] - correction;
        if(ascending){
            one_zeros[1] += one_zeros[0];
        }
        else{
            one_zeros[0] += one_zeros[1];
        }
        if(axis == 0){
            for(int i = width - 1; i >= 0; i--){
                uint8_t lsb = LSB[i];
                // find the index that this colour needs to be inserted in the output
                // the index is one_zeros[lsb] - 1;
                uint index = one_zeros[lsb] - 1;
                one_zeros[lsb] = one_zeros[lsb] - 1;
                simd_float4 colour{input.read(uint2(i,tgig))};
                output.write(colour, uint2(index,tgig));
            }
        }
        else if(axis == 1){
            for(int i = height - 1; i >= 0; i--){
                uint8_t lsb = LSB[i];
                uint index = one_zeros[lsb] - 1;
                one_zeros[lsb] = one_zeros[lsb] - 1;
                simd_float4 colour{input.read(uint2(tgig,i))};
                output.write(colour, uint2(tgig,index));
            }
        }
        else{
            // diagonally
            for(int i = iteration_width - 1; i >= 0 ; i--){
                uint8_t lsb = LSB[i];
                uint index = one_zeros[lsb] - 1;
                one_zeros[lsb] = one_zeros[lsb] - 1;
                
                uint2 readOffset = end + uint2(i - (iteration_width - 1),(iteration_width - 1) - i);
                
                uint2 writeOffset = start + uint2(index,-index);
                simd_float4 colour{input.read(readOffset)};
                output.write(colour, writeOffset);
            }
        }
       
    }
    
    
    
    
}
    
    
    
kernel void quickSort_test(texture2d<float, access::read> input [[texture(0)]],
                           texture2d<float, access::write> output [[texture(1)]],
                           constant PivotBuffer* readPivotBuffer [[buffer(0)]],
                           device PivotBuffer* writePivotBuffer [[buffer(1)]],
                           // tells us where each row starts from
                           constant uint& axis [[buffer(4)]],
                           constant bool& ascending [[buffer(5)]],
                           threadgroup uint* smallerIndices [[threadgroup(0)]],
                           threadgroup uint* biggerIndices [[threadgroup(1)]],
                           uint tid [[thread_index_in_threadgroup]],
                           uint tgig [[threadgroup_position_in_grid]]
                           ){
    
    uint height = input.get_height();
    int2 start_index = readPivotBuffer[tgig].start_index;
    int2 end_index = readPivotBuffer[tgig].end_index;
    int2 pivot_index{};
    int2 moveVector{};
    int length;
    
    
    switch (axis) {
        case 0 :
            moveVector = int2(1,0);
            length = end_index.x - start_index.x;
            pivot_index = start_index + (length - 1) * moveVector;
            break;
        case 1 :
            moveVector = int2(0,1);
            length = end_index.y - start_index.y;
            pivot_index = start_index + (length - 1) * moveVector;
            break;
        case 2:
            moveVector = int2(1,-1);
            length = end_index.x - start_index.x;
            pivot_index = start_index + (length - 1) * moveVector;
     }
    
    
    
    simd_float4 pivotColour = input.read(uint2(pivot_index));
    float r_pivot = pivotColour.r * 255;
    threadgroup uint finalSmallerCount = 0;
    threadgroup uint finalBiggerCount = 0;
    if(tid == 0){
        finalSmallerCount = 0;
        finalBiggerCount = 0;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    
    // use tid == 0 to put all the smaller elements before the pivot
    
    if(tid == 0){
        uint currentIndexIntoTG = 0;
        for(int i = 0; i != length; i++){
            int2 readOffset = start_index + i * moveVector;
            if(readOffset.x == pivot_index.x && readOffset.y == pivot_index.y){
                continue;
            }
            float r = input.read(uint2(readOffset)).r * 255;
            if(ascending){
                if(r <= r_pivot){
                    smallerIndices[currentIndexIntoTG++] = i;
                }
            }
            else{
                if(r <= r_pivot){
                    biggerIndices[currentIndexIntoTG++] = i;
                }
            }
            
            
            
        }
        if(ascending){
            finalSmallerCount = currentIndexIntoTG;

        }
        else{
            finalBiggerCount = currentIndexIntoTG;
        }
    }
    
    
    // use tid == 1 to put all bigger elements after the pivot
    if(tid == 1){
        uint currentIndexIntoTG = 0;
        for(int i = 0; i != length; i++){
            int2 readOffset = start_index + i * moveVector;
            if(readOffset.x == pivot_index.x && readOffset.y == pivot_index.y){
                continue;
            }
            float r = input.read(uint2(readOffset)).r * 255;
            if(ascending){
                if(r > r_pivot){
                    biggerIndices[currentIndexIntoTG++] = i;
                }
            }
            else{
                if(r > r_pivot){
                    smallerIndices[currentIndexIntoTG++] = i;
                }
            }
            
           
        }
        if(ascending){
            finalBiggerCount = currentIndexIntoTG;

        }
        else{
            finalSmallerCount = currentIndexIntoTG;
        }
        
        
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if(tid == 0){
        if(finalSmallerCount == 0){
            // all elements are bigger than pivot so we put pivot into smaller array
            // pivot index is always iter_length - 1
            smallerIndices[finalSmallerCount++] = length - 1;
        }
        else if(finalBiggerCount == 0){
            // all elements are smaller than the pivot so we put pivot into the bigger array
            biggerIndices[finalBiggerCount++] = length - 1;
        }
        else{
            // neither array is empty so we put the pivot at the top of smaller array
            smallerIndices[finalSmallerCount++] = length - 1;
            
        }
        for(uint i = 0; i != finalSmallerCount; i++){
            
            int2 writeOffset =  start_index + i * moveVector;
            
            
            uint index = smallerIndices[i];
            int2 readOffset = start_index + index * moveVector;
            //uint2 readOffset = uint2(index, offset.y);
            simd_float4 colour{input.read(uint2(readOffset))};
            uint2 u_writeOffset = uint2(writeOffset);
            output.write(colour, u_writeOffset);
        }
       
        
        for(uint i = 0; i != finalBiggerCount; i++){
            
            int2 writeOffset = start_index + (i + finalSmallerCount) * moveVector;
            
            uint index = biggerIndices[i];
            int2 readOffset = start_index + index * moveVector;
            simd_float4 colour{input.read(uint2(readOffset))};
            uint2 u_writeOffset = uint2(writeOffset);
            output.write(colour, u_writeOffset);
            
        }
    }
    
    if(tid == 0){
        int2 start_1 = start_index;
        int2 end_1 = start_index + finalSmallerCount * moveVector;
        
        int2 start_2 = end_1;
        int2 end_2 = start_2 + finalBiggerCount * moveVector;
        
       
        writePivotBuffer[tgig * 2 + 0] = PivotBuffer{start_1,end_1};
        writePivotBuffer[tgig * 2 + 1] = PivotBuffer{start_2,end_2};
        
        
        
    }
    
   
    
    
    
    
}
    
    
kernel void oddEven_test(texture2d<float, access::read> input [[texture(0)]],
                         texture2d<float, access::write> output [[texture(1)]],
                         constant bool& even [[buffer(0)]],
                         constant uint& axis [[buffer(1)]],
                         constant bool& ascending [[buffer(2)]],
                         uint tid [[thread_index_in_threadgroup]],
                         uint tgig [[threadgroup_position_in_grid]]
                         ){
    uint width = input.get_width();
    uint height = input.get_height();
    int2 stride{};
    int2 halfStride{};
    int2 start{};
    uint length{};
    int2 moveVector{};
    uint iterationCount;
    uint slice_length = 1;
    uint starting_offset = even ? 0 : 1;
    
    
    
    switch (axis){
            // sorting along x
        case 0:
            stride = int2(slice_length * 2, 0);
            halfStride = int2(slice_length,0);
            start = int2(0 + starting_offset,tgig);
            length = width;
            moveVector = int2(1,0);
            break;
            // sorting along y
        case 1:
            stride = int2(0, slice_length * 2);
            halfStride = int2(0,slice_length);
            start = int2(tgig,0 + starting_offset);
            length = height;
            moveVector = int2(0,1);
            break;
        case 2:
            if(tgig / height < 1){
                start = int2(0,tgig);
                
                stride = int2(slice_length * 2, - slice_length * 2);
                halfStride = stride / 2;
                length = tgig + 1;
                moveVector = int2(1,-1);
                if(!even){
                    start += moveVector;
                }
            }
            else{
                start = int2(tgig % width + 1, height - 1);
                
                stride = int2(slice_length * 2, - slice_length * 2);
                halfStride = stride / 2;
                length = width - start.x;
                moveVector = int2(1,-1);
                if(!even){
                    start += moveVector;
                }
            }
            
    }
    
    
    iterationCount = length / (32 * slice_length * 2) + ((length % (32 * slice_length * 2) == 0) ? 0 : 1);
    int2 left_offset = start + tid * stride;
    //uint2 left_offset = start + tid * int2(stride,-stride);
    int2 right_offset = left_offset + halfStride;
    uint iteration_offset = 32 * slice_length * 2;
    uint thread_left_offset = starting_offset + tid * slice_length * 2;
    uint thread_right_offset = starting_offset + tid * slice_length * 2 + slice_length;
    
    if(length % 2 == 0 && !even){
        int2 firstIndex = start - moveVector;
        int2 lastIndex = start - moveVector + (length - 1) * moveVector;
        simd_float4 firstColour{input.read(uint2(firstIndex))};
        simd_float4 lastcolour{input.read(uint2(lastIndex))};
        output.write(firstColour, uint2(firstIndex));
        output.write(lastcolour, uint2(lastIndex));
    }
    if(length % 2 != 0 && even){
        int2 lastIndex = start + (length - 1) * moveVector;
        simd_float4 colour{input.read(uint2(lastIndex))};
        output.write(colour, uint2(lastIndex));
    }
    if(length % 2 != 0 && !even){
        int2 firstIndex = start - moveVector;
        simd_float4 colour{input.read(uint2(firstIndex))};
        output.write(colour, uint2(firstIndex));
    }
    
    
    
    
    for(uint i = 0; i != iterationCount; i++){
        uint offset = i * iteration_offset;
        int2 current_left_offset = offset * moveVector + left_offset;
        int2 current_right_offset = offset * moveVector + right_offset;
        if(offset + thread_left_offset + slice_length >= length){
            break;
        }
        simd_float4 left_c = input.read(uint2(current_left_offset));
        simd_float4 right_c = input.read(uint2(current_right_offset));
        float left_r = left_c.r * 255;
        float right_r = right_c.r * 255;
        //if(ascending){
            if(left_r <= right_r){
                output.write(left_c, uint2(ascending ? current_left_offset : current_right_offset));
                output.write(right_c, uint2(ascending ? current_right_offset : current_left_offset));
            }
            else{
                output.write(left_c, uint2(ascending ? current_right_offset : current_left_offset));
                output.write(right_c, uint2(ascending ? current_left_offset : current_right_offset));
            }
    }

}







kernel void quickSortPixels(device uint8_t* inputBuffer [[buffer(0)]],
                                  constant int& bufferLength [[buffer(1)]],
                                  device uint8_t* outputBuffer [[buffer(2)]],
                                  device int* offsetAndCountBuffer [[buffer(3)]],
                                  constant int& inputBufferOffset [[buffer(4)]],
      //                            device int* smallOutput [[buffer(2)]],
      //                            device int* bigOutput [[buffer(3)]],
                                 
                                  threadgroup uint8_t* smaller [[threadgroup(0)]],
                                  threadgroup uint8_t* bigger [[threadgroup(1)]],
                                  uint tid [[thread_index_in_threadgroup]],
                                  uint tcount [[threads_per_threadgroup]]
                                  ){
          
          int workChunk = bufferLength / tcount;
          int startWork = tid * workChunk;
          int endWork = startWork + workChunk;
          int pivotIndex = bufferLength / 2;
          int pivot = inputBuffer[pivotIndex];
          int smallerOffset = startWork;
          int biggerOffset = startWork;
          
          for(int i = startWork; i != endWork; i++){
              smaller[i] = 0;
              bigger[i] = 0;
          }
          
          threadgroup_barrier(mem_flags::mem_threadgroup);
          
          
          
          for(int i = startWork; i != endWork; i++){
              if(i == pivotIndex){
                  continue;
              }
              int current = inputBuffer[i];
              if(current <= pivot){
                  smaller[smallerOffset++] = current;
              }
              else {
                  bigger[biggerOffset++] = current;
              }
          }
          
          threadgroup_barrier(mem_flags::mem_threadgroup);
          
          
          // put the two buffers back into output and set the offset and count
          if(tid == 0){
              int smallInsert = 0;
              int bigInsert = 0;
              for(int i = 0; i != bufferLength; i++){
                  int small = smaller[i];
                  if(small != 0){
                      outputBuffer[smallInsert++] = small;
                  }
              }
              if(smallInsert == 0){
                  outputBuffer[smallInsert++] = pivot;
              }
              else{
                  outputBuffer[smallInsert + bigInsert++] = pivot;
              }
              for(int i = 0; i != bufferLength; i++){
                  int big = bigger[i];
                  if(big != 0){
                      outputBuffer[smallInsert + bigInsert++] = big;
                  }
            }
              
              // put the count and the offset into countAndOffSetBuffer
              offsetAndCountBuffer[0] = inputBufferOffset;
              offsetAndCountBuffer[1] = smallInsert;
              offsetAndCountBuffer[2] = inputBufferOffset + smallInsert * sizeof(uint8_t);
              offsetAndCountBuffer[3] = bigInsert;
          }
          
     
          
          
}




float4 getHSVFromRGB(float4 rgb){
    float r = rgb.r;
    float g = rgb.g;
    float b = rgb.b;
    float Max = max(r,max(g,b));
    float Min = min(r,min(g,b));
    // inverse of delta between max and min multiplied by 60
    float inverseDelta = 1 / (Max - Min);

    float H;
    float S;
    float V = Max;
    if(Max == 0){
        H = 0;
        S = 0;
    }
    // max is red
    else if(Max == r){
        H = 60 * (fmod(g - b, 6)) * inverseDelta;
        S = (V - Min) / V;
    }
    // max is green
    else if (Max == g){
        H = 60 * (2 + (b - r) * inverseDelta);
        S = (V - Min) / V;
    }
    // max is blue
    else{
        H = 60 * (4 + (r - g) * inverseDelta);
        S = (V - Min) / V;
    }
    
    // normalise Hue
    H /= 360;
    
    return float4(H,S,V,1);
    
    // calculate Saturation
    
    
}




float4 getRGBFromHSV(float4 HSV){
    // get Hue to 0 - 360
    float V = HSV.b;
    float H = HSV.r * 360;
    float C = HSV.g * HSV.b;
    float X = C * (1 - abs(fmod(H / 60, 2.0) - 1));
    float m = V - C;
    
    float3 rgb;
    
    if(H >= 0 && H < 60){
        rgb = float3(C,X,0);
    }
    else if(H >= 60 && H < 120){
        rgb = float3(X,C,0);
    }
    else if(H >= 120 && H < 180){
        rgb = float3(0,C,X);
    }
    else if(H >= 180 && H < 240){
        rgb = float3(0,X,C);
    }
    else if(H >= 240 && H < 300){
        rgb = float3(X,0,C);
    }
    else{
        rgb = float3(C,0,X);
    }
//    (R,G,B) = ((R'+m)×255, (G'+m)×255, (B'+m)×255)
//
    
    return float4((rgb.r+m),(rgb.g+m),(rgb.b+m),1);
                        
    
    
}


kernel void rgb_to_HSV(texture2d<float,access::read_write> src [[texture(0)]],
                       ushort2 global_id [[thread_position_in_grid]]
                       ){
    float4 fC = src.read(global_id);
    float4 HSV = getHSVFromRGB(fC);
    src.write(HSV, global_id);
}


kernel void HSV_to_rgb(texture2d<float,access::read_write> src [[texture(0)]],
                       // swap the indexes here so we do not have to set new textures
                       // on the encoders on the cpu side
                       //texture2d<float,access::write> des [[texture(1)]],
                       ushort2 global_id [[thread_position_in_grid]]
                       ){
    float4 hsvC = src.read(global_id);
    float4 RGB = getRGBFromHSV(hsvC);
    src.write(RGB, global_id);
}











