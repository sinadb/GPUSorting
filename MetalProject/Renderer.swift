//
//  Renderer.swift
//  MetalProject
//
//  Created by Sina Dashtebozorgy on 22/12/2022.
//

import Foundation
import Metal
import MetalKit
import AppKit
import MetalFX


enum GPU_Sorting : UInt32 {
    case X_ascending = 0
    case Y_ascending = 1
    case X_descending = 2
    case Y_descending = 3
    case diagonal_ascending = 4
    case diagonal_descending = 5
};

enum sorting_order : UInt32 {
   case ascending = 0, descending
}


func createComputePipeline(device : MTLDevice, with functionName : String) throws -> MTLComputePipelineState {
    let library = device.makeDefaultLibrary()!
    let computeFunction = library.makeFunction(name: functionName)!
    
    do {
        return try device.makeComputePipelineState(function: computeFunction)
    }
    catch {
        print("Failed to init pipeline with function name : \(functionName)")
        throw error
    }

    
}


func getAlignedMemory<T>(for type : T, with alignment : Int, count : Int) -> Int {
    let size = count * MemoryLayout<T>.stride
    //print(size)
    return size - (size & (alignment - 1)) + alignment
}



class Renderer : NSObject, MTKViewDelegate {
    
  
    
 
    var True = true
    var False = false
   
    
    let device: MTLDevice
    let commandQueue : MTLCommandQueue
    let drawToScreenPipeline : MTLRenderPipelineState
    var fps = 0
      
    // kernel for RGB to HSV conversion
    let RGBToHSVConversionKernel : MTLComputePipelineState
    
    
    // kernel for HSV to RGB conversion
    let HSVToRGBConversionKernel : MTLComputePipelineState
    
    
    
    //let testRadixSortPipeline : MTLComputePipelineState
  
    
    
    var mergeSortPipeline_test : MTLComputePipelineState
    var mergeSortTextures_test = [MTLTexture]()
    var sliceLength_test : UInt32 = 1
    var max_sliceLength : UInt32 {
        return UInt32(pow(2,ceil(log2(Float(globalTextureToBeSortedSize))))) / 2
    }
    let visibleFunctionTableForMergeSort : MTLVisibleFunctionTable
    
    
    
    var radixSort_lsbComputePipeline : MTLComputePipelineState
    
    
    var radixSortTextures = [MTLTexture]()
    
    var radixSortThreadCount : Int {
        return 32
    }
    
    // default is always X.ascending
    var sorting_setting : GPU_Sorting?
    
    
    var quickSortComputePipeline : MTLComputePipelineState
    var quickSortTextures = [MTLTexture]()
    var quickSortPivotBuffersGPUSide = [MTLBuffer]()
    var quickSortPivotBufferCPUSide : MTLBuffer
    var quickSortOffsetBuffers = [MTLBuffer]()
    var quickSortTGCount = 1

    var previousSubArrayCount : Int  = 0
    var ptrToQuickSortPivotBuffer : UnsafeMutablePointer<simd_uint3> {
        return quickSortPivotBuffersGPUSide[0].contents().bindMemory(to: simd_uint3.self, capacity: globalTextureToBeSortedSize * 2)
    }
    
    
    var odd_evenComputePipelineState : MTLComputePipelineState
    var odd_evenTextures = [MTLTexture]()
    
    let globalTextureToBeSorted : MTLTexture
    let globalTextureToBeSortedSize = 1024
    let fence : MTLFence
    
    var sorting_setting_changed = false
    
    
    func resetBuffersAndTextures(){
        let pixelCount = globalTextureToBeSortedSize * globalTextureToBeSortedSize * 4
        var globalTextureData = [UInt8](repeating: 0, count: pixelCount)
        for i in stride(from: 0, to: pixelCount, by: 4){
            let r = UInt8.random(in: 0...255)
            let g = UInt8.random(in: 0...255)
            let b = UInt8.random(in: 0...255)
            globalTextureData[i + 0] = r
            globalTextureData[i + 1] = g
            globalTextureData[i + 2] = b
            globalTextureData[i + 3] = 255
        }
        fps = 0
        // copy the content of global texture to the inputs first
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: globalTextureToBeSortedSize, height: globalTextureToBeSortedSize, depth: 1))
        let bytesPerRow = 4 * globalTextureToBeSortedSize
        quickSortTextures[0].replace(region: region, mipmapLevel: 0, withBytes: globalTextureData, bytesPerRow: bytesPerRow)
        mergeSortTextures_test[0].replace(region: region, mipmapLevel: 0, withBytes: globalTextureData, bytesPerRow: bytesPerRow)
        radixSortTextures[0].replace(region: region, mipmapLevel: 0, withBytes: globalTextureData, bytesPerRow: bytesPerRow)
        odd_evenTextures[0].replace(region: region, mipmapLevel: 0, withBytes: globalTextureData, bytesPerRow: bytesPerRow)
        
        
        // the only other things we need to change are the buffers for the quicksort
        quickSortPivotBufferCPUSide = device.makeBuffer(length: MemoryLayout<PivotBuffer>.stride * pixelCount)!
        quickSortPivotBuffersGPUSide[0] = device.makeBuffer(length: MemoryLayout<PivotBuffer>.stride * pixelCount)!
        quickSortPivotBuffersGPUSide[1] = device.makeBuffer(length: MemoryLayout<PivotBuffer>.stride * pixelCount)!
        
        let ptrToPivotBuffer = quickSortPivotBuffersGPUSide[0].contents().bindMemory(to: PivotBuffer.self, capacity: globalTextureToBeSortedSize * globalTextureToBeSortedSize)
       
        for i in 0..<globalTextureToBeSortedSize {
            switch sorting_setting {
            case .X_ascending:
                let current_pivot = PivotBuffer(start_index: simd_int2(Int32(0),Int32(i)), end_index: simd_int2(Int32(globalTextureToBeSortedSize),Int32(i)))
                (ptrToPivotBuffer + i).pointee = current_pivot
                previousSubArrayCount = globalTextureToBeSortedSize
            case .Y_ascending:
                let current_pivot = PivotBuffer(start_index: simd_int2(Int32(i),Int32(0)), end_index: simd_int2(Int32(i),Int32(globalTextureToBeSortedSize)))
                (ptrToPivotBuffer + i).pointee = current_pivot
                previousSubArrayCount = globalTextureToBeSortedSize
                break
            case .X_descending:
                let current_pivot = PivotBuffer(start_index: simd_int2(Int32(0),Int32(i)), end_index: simd_int2(Int32(globalTextureToBeSortedSize),Int32(i)))
                (ptrToPivotBuffer + i).pointee = current_pivot
                previousSubArrayCount = globalTextureToBeSortedSize
                break
            case .Y_descending:
                let current_pivot = PivotBuffer(start_index: simd_int2(Int32(i),Int32(0)), end_index: simd_int2(Int32(i),Int32(globalTextureToBeSortedSize)))
                (ptrToPivotBuffer + i).pointee = current_pivot
                previousSubArrayCount = globalTextureToBeSortedSize
                break
            default:
                previousSubArrayCount = globalTextureToBeSortedSize
                break
            }
           
        }
            if(sorting_setting == .diagonal_ascending || sorting_setting == .diagonal_descending){
                previousSubArrayCount = globalTextureToBeSortedSize * 2 - 1
                for i in 0..<globalTextureToBeSortedSize * 2 - 1{
                    if(i < globalTextureToBeSortedSize){
                        let current_pivot = PivotBuffer(start_index: simd_int2(0,Int32(i)), end_index: simd_int2(Int32(i + 1), 0))
                        (ptrToPivotBuffer + i).pointee = current_pivot
                    }
                    else{
                        let current_pivot = PivotBuffer(start_index: simd_int2(Int32(i % globalTextureToBeSortedSize + 1),Int32(globalTextureToBeSortedSize - 1)), end_index: simd_int2(Int32(globalTextureToBeSortedSize), Int32(i % globalTextureToBeSortedSize + 1)))
                        (ptrToPivotBuffer + i).pointee = current_pivot
                    }
                }
            }
        
        // set slice_length for merge sort back to 1
        sliceLength_test = 1
    }
    
    func sortWithQuickSort(commandBuffer : MTLCommandBuffer, renderPassDescriptor : MTLRenderPassDescriptor){
            var actualCount : Int = 0
            var axis = Int()
            var ascending = Bool()
            var maxCount : Int = previousSubArrayCount * 2
            if(fps == 0){
                switch sorting_setting {
                case .X_ascending:
                    axis = 0
                    ascending = true
                    break
                case .Y_ascending:
                    axis = 1
                    ascending = true
                    break
                case .X_descending:
                    axis = 0
                    ascending = false
                    break
                case .Y_descending:
                    axis = 1
                    ascending = false
                    break
                case .diagonal_ascending:
                    axis = 2
                    ascending = true
                    break
                case .diagonal_descending:
                    axis = 2
                    ascending = false
                    break
                default:
                    break
                }
           
            }
            
            
            else{
                for i in 0..<maxCount {
                    // iterate row per row and add rowCount to totalTGCount
                    
                    // get the pointer to the current row
                    let ptrToCurrentRowPivotBuffer = quickSortPivotBuffersGPUSide[1].contents().bindMemory(to: PivotBuffer.self, capacity: globalTextureToBeSortedSize * globalTextureToBeSortedSize)
                    let ptrToCurrentRowPivotBufferCPU = quickSortPivotBufferCPUSide.contents().bindMemory(to: PivotBuffer.self, capacity: globalTextureToBeSortedSize * globalTextureToBeSortedSize)
                    let currentPivot = (ptrToCurrentRowPivotBuffer + i).pointee
                    var length = Int32()
                    
                    switch sorting_setting {
                    case .X_ascending:
                        length = currentPivot.end_index[0] - currentPivot.start_index[0]
                        axis = 0
                        ascending = true
                        break
                    case .Y_ascending:
                        length = currentPivot.end_index[1] - currentPivot.start_index[1]
                        axis = 1
                        ascending = true
                        break
                    case .X_descending:
                        length = currentPivot.end_index[0] - currentPivot.start_index[0]
                        axis = 0
                        ascending = false
                        break
                    case .Y_descending:
                        length = currentPivot.end_index[1] - currentPivot.start_index[1]
                        axis = 1
                        ascending = false
                        break
                    case .diagonal_ascending:
                        length = currentPivot.end_index[0] - currentPivot.start_index[0]
                        axis = 2
                        ascending = true
                        break
                    case .diagonal_descending:
                        length = currentPivot.end_index[0] - currentPivot.start_index[0]
                        axis = 2
                        ascending = false
                        break
                    default:
                        break
                    }
                    if(length > 1){
                        (ptrToCurrentRowPivotBufferCPU + actualCount).pointee = currentPivot
                        actualCount += 1
                    }
                    previousSubArrayCount = actualCount

                    
                }
                if(actualCount != 0){
                    guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {return}
                    blitEncoder.copy(from: quickSortPivotBufferCPUSide, sourceOffset: 0, to: quickSortPivotBuffersGPUSide[0], destinationOffset: 0, size: actualCount * MemoryLayout<PivotBuffer>.stride)
                    blitEncoder.endEncoding()
                }
               
                
            }
            
            var totalTGCount = (fps == 0 ? globalTextureToBeSortedSize : actualCount)
            
           
            
            if(totalTGCount != 0){

                guard let RGBToHSVEncoder = commandBuffer.makeComputeCommandEncoder() else {return}
                RGBToHSVEncoder.label = "RGBToHSV Input"
                RGBToHSVEncoder.setComputePipelineState(RGBToHSVConversionKernel)
                RGBToHSVEncoder.setTexture(quickSortTextures[0], index: 0)
                RGBToHSVEncoder.dispatchThreads(MTLSize(width: Int(globalTextureToBeSortedSize), height: Int(globalTextureToBeSortedSize), depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 32, depth: 1))
                RGBToHSVEncoder.endEncoding()
                
                
                guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {return}
                computeEncoder.label = "quick sort pipeline"
                computeEncoder.setComputePipelineState(quickSortComputePipeline)
                computeEncoder.setTextures(quickSortTextures, range: 0..<2)
                computeEncoder.setBuffers(quickSortPivotBuffersGPUSide, offsets: [0,0], range: 0..<2)
                let tgMemoryCount = getAlignedMemory(for: UInt32.self, with: 16, count: globalTextureToBeSortedSize)
                computeEncoder.setThreadgroupMemoryLength(tgMemoryCount, index: 0)
                computeEncoder.setThreadgroupMemoryLength(tgMemoryCount, index: 1)
                
                computeEncoder.setBytes(&axis, length: 4, index: 4)
                computeEncoder.setBytes(&ascending, length: 1, index: 5)
              
                if(sorting_setting == .diagonal_ascending || sorting_setting == .diagonal_descending){
                    
                    computeEncoder.dispatchThreadgroups(MTLSize(width: fps == 0 ? globalTextureToBeSortedSize * 2 - 1 : totalTGCount, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 2, height: 1, depth: 1))
                }
                else{
                   
                    computeEncoder.dispatchThreadgroups(MTLSize(width: fps == 0 ? globalTextureToBeSortedSize : totalTGCount, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 2, height: 1, depth: 1))
                    
                }
               
                computeEncoder.endEncoding()
                
                
                guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {return}
                blitEncoder.label = "copy output into input"
                blitEncoder.copy(from: quickSortTextures[1], to: quickSortTextures[0])
                blitEncoder.endEncoding()
                
                guard let HSVToRGBEncoder = commandBuffer.makeComputeCommandEncoder() else {return}
                HSVToRGBEncoder.label = "HSVToRGB Output"
                HSVToRGBEncoder.setComputePipelineState(HSVToRGBConversionKernel)
                HSVToRGBEncoder.setTexture(quickSortTextures[0], index: 0)
                HSVToRGBEncoder.dispatchThreads(MTLSize(width: Int(globalTextureToBeSortedSize), height: Int(globalTextureToBeSortedSize), depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 32, depth: 1))
                HSVToRGBEncoder.endEncoding()
                
                
            }

        guard let quickSorRender = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {return}
        quickSorRender.label = "render Quick Sort"
        quickSorRender.setViewport(MTLViewport(originX: 600, originY: 600, width: 400, height: 400, znear: 0, zfar: 1))
        quickSorRender.setRenderPipelineState(drawToScreenPipeline)
        quickSorRender.setFragmentTexture(quickSortTextures[0], index: 0)
        quickSorRender.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        quickSorRender.endEncoding()
        
    
    }
    
    func sortWithMergeSort(commandBuffer : MTLCommandBuffer, renderPassDescriptor : MTLRenderPassDescriptor){
        if(sliceLength_test <= max_sliceLength){
            
            
            // convert input to HSV
            
            guard let RGBToHSVEncoder = commandBuffer.makeComputeCommandEncoder() else {return}
            RGBToHSVEncoder.label = "RGBToHSV Input"
            RGBToHSVEncoder.setComputePipelineState(RGBToHSVConversionKernel)
            RGBToHSVEncoder.setTexture(mergeSortTextures_test[0], index: 0)
            RGBToHSVEncoder.dispatchThreads(MTLSize(width: Int(globalTextureToBeSortedSize), height: Int(globalTextureToBeSortedSize), depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 32, depth: 1))
            RGBToHSVEncoder.endEncoding()
            
            guard let mergeSort_testEncoder = commandBuffer.makeComputeCommandEncoder() else {return}
            mergeSort_testEncoder.label = "test Merge Sort"
            
            mergeSort_testEncoder.setComputePipelineState(mergeSortPipeline_test)
            mergeSort_testEncoder.setVisibleFunctionTable(visibleFunctionTableForMergeSort, bufferIndex: 3)
            mergeSort_testEncoder.setTextures(mergeSortTextures_test, range: 0..<2)
           
            
            
            switch sorting_setting {
            case .X_ascending:
                var axis = UInt32(0)
                var ascending : Bool = true
                mergeSort_testEncoder.setBytes(&axis, length: 4, index: 1)
                mergeSort_testEncoder.setBytes(&ascending, length: 1, index: 2)
               
                mergeSort_testEncoder.setBytes(&sliceLength_test, length: 4, index: 0)
                mergeSort_testEncoder.dispatchThreadgroups(MTLSize(width: Int(globalTextureToBeSortedSize), height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
                break
            case .Y_ascending:
                var axis = UInt32(1)
                var ascending : Bool = true
                mergeSort_testEncoder.setBytes(&axis, length: 4, index: 1)
                mergeSort_testEncoder.setBytes(&ascending, length: 1, index: 2)
                mergeSort_testEncoder.setBytes(&sliceLength_test, length: 4, index: 0)
                mergeSort_testEncoder.dispatchThreadgroups(MTLSize(width: Int(globalTextureToBeSortedSize), height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .X_descending:
                var axis = UInt32(0)
                var ascending : Bool = false
                mergeSort_testEncoder.setBytes(&axis, length: 4, index: 1)
                mergeSort_testEncoder.setBytes(&ascending, length: 1, index: 2)
                mergeSort_testEncoder.setBytes(&sliceLength_test, length: 4, index: 0)
                mergeSort_testEncoder.dispatchThreadgroups(MTLSize(width: Int(globalTextureToBeSortedSize), height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .Y_descending:
                var axis = UInt32(1)
                var ascending : Bool = false
                mergeSort_testEncoder.setBytes(&axis, length: 4, index: 1)
                mergeSort_testEncoder.setBytes(&ascending, length: 1, index: 2)
                mergeSort_testEncoder.setBytes(&sliceLength_test, length: 4, index: 0)
                mergeSort_testEncoder.dispatchThreadgroups(MTLSize(width: Int(globalTextureToBeSortedSize), height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .diagonal_ascending:
                var axis = UInt32(2)
                var ascending : Bool = true
                mergeSort_testEncoder.setBytes(&axis, length: 4, index: 1)
                mergeSort_testEncoder.setBytes(&ascending, length: 1, index: 2)
               
                mergeSort_testEncoder.setBytes(&sliceLength_test, length: 4, index: 0)
                mergeSort_testEncoder.dispatchThreadgroups(MTLSize(width: Int(globalTextureToBeSortedSize * 2 - 1), height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .diagonal_descending:
                var axis = UInt32(2)
                var ascending : Bool = false
                mergeSort_testEncoder.setBytes(&axis, length: 4, index: 1)
                mergeSort_testEncoder.setBytes(&ascending, length: 1, index: 2)
                mergeSort_testEncoder.setBytes(&sliceLength_test, length: 4, index: 0)
                mergeSort_testEncoder.dispatchThreadgroups(MTLSize(width: Int(globalTextureToBeSortedSize * 2 - 1), height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            default:
                break
            }
           
           
            mergeSort_testEncoder.endEncoding()
            
            // convert output to RGB
            
            guard let HSVToRGBEncoder = commandBuffer.makeComputeCommandEncoder() else {return}
            HSVToRGBEncoder.label = "HSVToRGB Output"
            HSVToRGBEncoder.setComputePipelineState(HSVToRGBConversionKernel)
            HSVToRGBEncoder.setTexture(mergeSortTextures_test[1], index: 0)
            HSVToRGBEncoder.dispatchThreads(MTLSize(width: Int(globalTextureToBeSortedSize), height: Int(globalTextureToBeSortedSize), depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 32, depth: 1))
            HSVToRGBEncoder.endEncoding()
            
            
             //copy output to input before displaying it
            
            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {return}
            blitEncoder.label = "copy output to input"
            blitEncoder.copy(from: mergeSortTextures_test[1], to: mergeSortTextures_test[0])
            blitEncoder.endEncoding()
            
            
            sliceLength_test *= 2
            
        }
        
        guard let renderMergeTestEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {return}
        renderMergeTestEncoder.setViewport(MTLViewport(originX: 600, originY: 0, width: 400, height: 400, znear: 0, zfar: 1))
        renderMergeTestEncoder.setRenderPipelineState(drawToScreenPipeline)
        renderMergeTestEncoder.setFragmentTexture(mergeSortTextures_test[0], index: 0)
        renderMergeTestEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderMergeTestEncoder.endEncoding()
        
        // MERGE SORT
    }
    
    func sortWithRadixSort(commandBuffer : MTLCommandBuffer, renderPassDescriptor : MTLRenderPassDescriptor){
        if(fps <= 7){
            
            guard let radixRGBToHSVEncoder = commandBuffer.makeComputeCommandEncoder() else {return}
            radixRGBToHSVEncoder.label = "RGB To HSV Encoder Radix"
            radixRGBToHSVEncoder.setComputePipelineState(RGBToHSVConversionKernel)
            radixRGBToHSVEncoder.setTexture(radixSortTextures[0], index: 0)
            radixRGBToHSVEncoder.dispatchThreads(MTLSize(width: globalTextureToBeSortedSize, height: globalTextureToBeSortedSize, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 32, depth: 1))
            radixRGBToHSVEncoder.endEncoding()
//
            
            guard let radixSortComputeEncoder = commandBuffer.makeComputeCommandEncoder() else {return}
            radixSortComputeEncoder.label = "test Radix LSB"
            radixSortComputeEncoder.setComputePipelineState(radixSort_lsbComputePipeline)
            radixSortComputeEncoder.setTextures(radixSortTextures, range: 0..<2)
            var frameIndex = UInt32(fps)
            radixSortComputeEncoder.setBytes(&frameIndex, length: 4, index: 0)
            let tgMemorySize = getAlignedMemory(for: UInt8.self, with: 16, count: globalTextureToBeSortedSize)
            radixSortComputeEncoder.setThreadgroupMemoryLength(tgMemorySize, index: 0)
            
            switch sorting_setting {
            case .X_ascending:
                var axis = UInt32(0)
                var ascending : Bool = true
                radixSortComputeEncoder.setBytes(&axis, length: 4, index: 1)
                radixSortComputeEncoder.setBytes(&ascending, length: 1, index: 2)
                radixSortComputeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: radixSortThreadCount, height: 1, depth: 1))
                break
            case .X_descending:
                var axis = UInt32(0)
                var ascending : Bool = false
                radixSortComputeEncoder.setBytes(&axis, length: 4, index: 1)
                radixSortComputeEncoder.setBytes(&ascending, length: 1, index: 2)
                radixSortComputeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: radixSortThreadCount, height: 1, depth: 1))
                break
            case .Y_ascending:
                var axis = UInt32(1)
                var ascending : Bool = true
                radixSortComputeEncoder.setBytes(&axis, length: 4, index: 1)
                radixSortComputeEncoder.setBytes(&ascending, length: 1, index: 2)
                radixSortComputeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: radixSortThreadCount, height: 1, depth: 1))
                break
            case .Y_descending:
                var axis = UInt32(1)
                var ascending : Bool = false
                radixSortComputeEncoder.setBytes(&axis, length: 4, index: 1)
                radixSortComputeEncoder.setBytes(&ascending, length: 1, index: 2)
                radixSortComputeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: radixSortThreadCount, height: 1, depth: 1))
                break
            case .diagonal_ascending:
                print("diagonal")
                var axis = UInt32(2)
                var ascending : Bool = true
                radixSortComputeEncoder.setBytes(&axis, length: 4, index: 1)
                radixSortComputeEncoder.setBytes(&ascending, length: 1, index: 2)
                radixSortComputeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize * 2 - 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: radixSortThreadCount, height: 1, depth: 1))
                break
            case .diagonal_descending:
                var axis = UInt32(2)
                var ascending : Bool = false
                radixSortComputeEncoder.setBytes(&axis, length: 4, index: 1)
                radixSortComputeEncoder.setBytes(&ascending, length: 1, index: 2)
                radixSortComputeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize * 2 - 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: radixSortThreadCount, height: 1, depth: 1))
                break
                
            default:
                break
            }

          
            
            radixSortComputeEncoder.endEncoding()
            
             //convert output to RGB
            
            guard let radixHSVToRGB = commandBuffer.makeComputeCommandEncoder() else {return}
            radixHSVToRGB.label = "HSV To RGB Radix"
            radixHSVToRGB.setComputePipelineState(HSVToRGBConversionKernel)
            radixHSVToRGB.setTexture(radixSortTextures[1], index: 0)
            radixHSVToRGB.dispatchThreads(MTLSize(width: globalTextureToBeSortedSize, height: globalTextureToBeSortedSize, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 32, depth: 1))
            radixHSVToRGB.endEncoding()
            
//
             //blit output to input
            guard let radixBlitEncoder = commandBuffer.makeBlitCommandEncoder() else {return}
            radixBlitEncoder.label = "radix copy output to input"
            radixBlitEncoder.copy(from: radixSortTextures[1], to: radixSortTextures[0])
            radixBlitEncoder.endEncoding()
        }
        
        
        
        // render input for radix
        
        guard let radixRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {return}
        radixRenderEncoder.label = "render radix result"
        radixRenderEncoder.setViewport(MTLViewport(originX: 0, originY: 0, width: 400, height: 400, znear: 0, zfar: 1))
        radixRenderEncoder.setRenderPipelineState(drawToScreenPipeline)
        radixRenderEncoder.setFragmentTexture(radixSortTextures[0], index: 0)
        radixRenderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        radixRenderEncoder.endEncoding()
    }
    
    func sortWithOddEvenSort(commandBuffer : MTLCommandBuffer, renderPassDescriptor : MTLRenderPassDescriptor){
        if(fps <= globalTextureToBeSortedSize){
            
            
            guard let RGBToHSVEncoder = commandBuffer.makeComputeCommandEncoder() else {return}
            RGBToHSVEncoder.label = "RGBToHSV Input"
            RGBToHSVEncoder.setComputePipelineState(RGBToHSVConversionKernel)
            RGBToHSVEncoder.setTexture(odd_evenTextures[0], index: 0)
            RGBToHSVEncoder.dispatchThreads(MTLSize(width: Int(globalTextureToBeSortedSize), height: Int(globalTextureToBeSortedSize), depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 32, depth: 1))
            RGBToHSVEncoder.endEncoding()
            
            
            guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {return}
            computeEncoder.setComputePipelineState(odd_evenComputePipelineState)
            computeEncoder.setTexture(odd_evenTextures[0], index: 0)
            computeEncoder.setTexture(odd_evenTextures[1], index: 1)
            
            switch sorting_setting {
            case .X_ascending:
                var even = true
                var axis = UInt32(0)
                var ascending = true
                computeEncoder.setBytes(&even, length: 1, index: 0)
                computeEncoder.setBytes(&axis, length: 4, index: 1)
                computeEncoder.setBytes(&ascending, length: 1, index: 2)
                computeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .Y_ascending:
                var even = true
                var axis = UInt32(1)
                var ascending = true
                computeEncoder.setBytes(&even, length: 1, index: 0)
                computeEncoder.setBytes(&axis, length: 4, index: 1)
                computeEncoder.setBytes(&ascending, length: 1, index: 2)
                computeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .X_descending:
                var even = true
                var axis = UInt32(0)
                var ascending = false
                computeEncoder.setBytes(&even, length: 1, index: 0)
                computeEncoder.setBytes(&axis, length: 4, index: 1)
                computeEncoder.setBytes(&ascending, length: 1, index: 2)
                computeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .Y_descending:
                var even = true
                var axis = UInt32(1)
                var ascending = false
                computeEncoder.setBytes(&even, length: 1, index: 0)
                computeEncoder.setBytes(&axis, length: 4, index: 1)
                computeEncoder.setBytes(&ascending, length: 1, index: 2)
                computeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .diagonal_ascending:
                var even = true
                var axis = UInt32(2)
                var ascending = true
                computeEncoder.setBytes(&even, length: 1, index: 0)
                computeEncoder.setBytes(&axis, length: 4, index: 1)
                computeEncoder.setBytes(&ascending, length: 1, index: 2)
                computeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize * 2 - 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .diagonal_descending:
                var even = true
                var axis = UInt32(2)
                var ascending = false
                computeEncoder.setBytes(&even, length: 1, index: 0)
                computeEncoder.setBytes(&axis, length: 4, index: 1)
                computeEncoder.setBytes(&ascending, length: 1, index: 2)
                computeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize * 2 - 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            default:
                break
            }
            
           
           
           
            computeEncoder.endEncoding()
            
            
            // blit output into input and run the odd sort
            
            
            

            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {return}
            blitEncoder.label = "copy quick sort"
            blitEncoder.copy(from: odd_evenTextures[1], to: odd_evenTextures[0])
            blitEncoder.endEncoding()
            
            
            guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {return}
            computeEncoder.setComputePipelineState(odd_evenComputePipelineState)
            computeEncoder.setTextures(odd_evenTextures, range: 0..<2)
           
            
            switch sorting_setting {
            case .X_ascending:
                var even = false
                var axis = UInt32(0)
                var ascending = true
                computeEncoder.setBytes(&even, length: 1, index: 0)
                computeEncoder.setBytes(&axis, length: 4, index: 1)
                computeEncoder.setBytes(&ascending, length: 1, index: 2)
                computeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .Y_ascending:
                var even = false
                var axis = UInt32(1)
                var ascending = true
                computeEncoder.setBytes(&even, length: 1, index: 0)
                computeEncoder.setBytes(&axis, length: 4, index: 1)
                computeEncoder.setBytes(&ascending, length: 1, index: 2)
                computeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .X_descending:
                var even = false
                var axis = UInt32(0)
                var ascending = false
                computeEncoder.setBytes(&even, length: 1, index: 0)
                computeEncoder.setBytes(&axis, length: 4, index: 1)
                computeEncoder.setBytes(&ascending, length: 1, index: 2)
                computeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .Y_descending:
                var even = false
                var axis = UInt32(1)
                var ascending = false
                computeEncoder.setBytes(&even, length: 1, index: 0)
                computeEncoder.setBytes(&axis, length: 4, index: 1)
                computeEncoder.setBytes(&ascending, length: 1, index: 2)
                computeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .diagonal_ascending:
                var even = false
                var axis = UInt32(2)
                var ascending = true
                computeEncoder.setBytes(&even, length: 1, index: 0)
                computeEncoder.setBytes(&axis, length: 4, index: 1)
                computeEncoder.setBytes(&ascending, length: 1, index: 2)
                computeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize * 2 - 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            case .diagonal_descending:
                var even = false
                var axis = UInt32(2)
                var ascending = false
                computeEncoder.setBytes(&even, length: 1, index: 0)
                computeEncoder.setBytes(&axis, length: 4, index: 1)
                computeEncoder.setBytes(&ascending, length: 1, index: 2)
                computeEncoder.dispatchThreadgroups(MTLSize(width: globalTextureToBeSortedSize * 2 - 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 1, depth: 1))
            default:
                break
            }
            
           
           
           
            computeEncoder.endEncoding()
            
            
            
            
            guard let HSVToRGBEncoder = commandBuffer.makeComputeCommandEncoder() else {return}
            HSVToRGBEncoder.label = "HSVToRGB Output"
            HSVToRGBEncoder.setComputePipelineState(HSVToRGBConversionKernel)
            HSVToRGBEncoder.setTexture(odd_evenTextures[1], index: 0)
            HSVToRGBEncoder.dispatchThreads(MTLSize(width: Int(globalTextureToBeSortedSize), height: Int(globalTextureToBeSortedSize), depth: 1), threadsPerThreadgroup: MTLSize(width: 32, height: 32, depth: 1))
            HSVToRGBEncoder.endEncoding()
            
            // blit output into output again
            
            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {return}
            blitEncoder.label = "copy quick sort"
            blitEncoder.copy(from: odd_evenTextures[1], to: odd_evenTextures[0])
            blitEncoder.endEncoding()
            
            
           
            
            
            
            
        }
        
        
        guard let odd_evenRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {return}
        odd_evenRenderEncoder.label = "render Quick Sort"
        odd_evenRenderEncoder.setViewport(MTLViewport(originX: 0, originY: 600, width: 400, height: 400, znear: 0, zfar: 1))
        odd_evenRenderEncoder.setRenderPipelineState(drawToScreenPipeline)
        odd_evenRenderEncoder.setFragmentTexture(odd_evenTextures[0], index: 0)
        odd_evenRenderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        odd_evenRenderEncoder.endEncoding()
        
    }
    
    let view : MTKView
    var frameRate = 120 {
        didSet {
            view.preferredFramesPerSecond = frameRate
        }
    }
    
    
    init?(mtkView: MTKView){
        
        
        
        device = mtkView.device!
        fence = device.makeFence()!
        view = mtkView
       
        mtkView.preferredFramesPerSecond = 1
        mtkView.drawableSize = CGSize(width: 1000, height: 1000)
        
        commandQueue = device.makeCommandQueue()!
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .invalid
        
        let library = device.makeDefaultLibrary()!
        
      
        var globalTextureToBeSortedDC = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: globalTextureToBeSortedSize, height: globalTextureToBeSortedSize, mipmapped: false)
        globalTextureToBeSortedDC.usage = [.shaderRead,.shaderWrite]
        globalTextureToBeSorted = device.makeTexture(descriptor: globalTextureToBeSortedDC)!
        
        var globalTextureData = [UInt8](repeating: 0, count: globalTextureToBeSortedSize * globalTextureToBeSortedSize * 4)
        for i in stride(from: 0, to: globalTextureToBeSortedSize * globalTextureToBeSortedSize * 4, by: 4){
            let r = UInt8.random(in: 0...255)
            let g = UInt8.random(in: 0...255)
            let b = UInt8.random(in: 0...255)
            globalTextureData[i + 0] = r
            globalTextureData[i + 1] = g
            globalTextureData[i + 2] = b
            globalTextureData[i + 3] = 255
        }
        globalTextureToBeSorted.replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: globalTextureToBeSortedSize, height: globalTextureToBeSortedSize, depth: 1)), mipmapLevel: 0, withBytes: globalTextureData, bytesPerRow: 4 * globalTextureToBeSortedSize)
        
        do {
            RGBToHSVConversionKernel =  try createComputePipeline(device: device, with: "rgb_to_HSV")
        }
        catch {
            print("rgb to hsv pipeline failed to initialise")
            return nil
        }
        
        do {
            HSVToRGBConversionKernel = try createComputePipeline(device: device, with: "HSV_to_rgb")
        }
        catch{
            print("hsv to rgb pipeline failed to initialise")
            return nil
        }
        
       
        
        
        
       
        let drawToScreenPipelineDC = MTLRenderPipelineDescriptor()
        drawToScreenPipelineDC.fragmentFunction = library.makeFunction(name: "drawToScreenFragment")!
        drawToScreenPipelineDC.vertexFunction = library.makeFunction(name: "drawToScreenVertex")!
        drawToScreenPipelineDC.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        drawToScreenPipelineDC.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        do {
            drawToScreenPipeline = try device.makeRenderPipelineState(descriptor: drawToScreenPipelineDC)
        }
        
        catch {
            print("Failed to init drawToScreen pipeline")
            return nil
        }
        
        //let width = 100
      
        
        let mergeArrays_ascendingKernel = library.makeFunction(name: "mergeArrays_test_ascending")!
        let mergeArrays_descendingKernel = library.makeFunction(name: "mergeArrays_test_descending")!
        let linkedFunctions = MTLLinkedFunctions()
        linkedFunctions.functions = [mergeArrays_ascendingKernel,mergeArrays_descendingKernel]
        
        var mergeSortKernel_test = library.makeFunction(name: "mergeSortPixels_test")!
        
      
        
        let mergeSortComputePipelineDC = MTLComputePipelineDescriptor()
        mergeSortComputePipelineDC.linkedFunctions = linkedFunctions
        mergeSortComputePipelineDC.computeFunction = mergeSortKernel_test
        
        do {
            mergeSortPipeline_test = try device.makeComputePipelineState(descriptor: mergeSortComputePipelineDC, options: [], reflection: nil)
        }
        catch {
            print(error)
            return nil
        }
        
        
        let vftDC = MTLVisibleFunctionTableDescriptor()
        vftDC.functionCount = 2
        visibleFunctionTableForMergeSort = mergeSortPipeline_test.makeVisibleFunctionTable(descriptor: vftDC)!
        let ascedingFH = mergeSortPipeline_test.functionHandle(function: mergeArrays_ascendingKernel)
        let descendingFH = mergeSortPipeline_test.functionHandle(function: mergeArrays_descendingKernel)
        visibleFunctionTableForMergeSort.setFunctions([ascedingFH,descendingFH], range: 0..<2)
        

        for i in 0..<2 {
            mergeSortTextures_test.append(device.makeTexture(descriptor: globalTextureToBeSortedDC)!)
        }
        

        
        mergeSortTextures_test[0].replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: globalTextureToBeSortedSize, height: globalTextureToBeSortedSize, depth: 1)), mipmapLevel: 0, withBytes: globalTextureData, bytesPerRow: 4 * globalTextureToBeSortedSize)
        
        
        let radix_sort_lsbKernel = library.makeFunction(name: "radixSort_lsb")!
       
        do {
            radixSort_lsbComputePipeline = try device.makeComputePipelineState(function: radix_sort_lsbKernel)
        }
        
        catch{
            print(error)
            return nil
        }
        
        let radixSortlsb_textureDC = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: globalTextureToBeSortedSize, height: globalTextureToBeSortedSize, mipmapped: false)
        radixSortlsb_textureDC.usage = [.shaderRead,.shaderWrite]
        for i in 0..<2 {
            radixSortTextures.append(device.makeTexture(descriptor: globalTextureToBeSortedDC)!)
        }
     
        radixSortTextures[0].replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: globalTextureToBeSortedSize, height: globalTextureToBeSortedSize, depth: 1)), mipmapLevel: 0, withBytes: globalTextureData, bytesPerRow: 4 * globalTextureToBeSortedSize)
       
        let quickSortKernel = library.makeFunction(name: "quickSort_test")!
        
        do {
            quickSortComputePipeline = try device.makeComputePipelineState(function: quickSortKernel)
        }
        catch {
            print(error)
            return nil
        }
        

        if(sorting_setting == .diagonal_ascending || sorting_setting == .diagonal_descending){
            previousSubArrayCount = globalTextureToBeSortedSize * 2 - 1
        }
        for i in 0..<2 {
            quickSortPivotBuffersGPUSide.append(device.makeBuffer(length: MemoryLayout<PivotBuffer>.stride * globalTextureToBeSortedSize * globalTextureToBeSortedSize)!)
            quickSortTextures.append(device.makeTexture(descriptor: globalTextureToBeSortedDC)!)
          
            
        }
        quickSortPivotBuffersGPUSide[0].label = "quick pivot 0"
        quickSortPivotBuffersGPUSide[1].label = "quick pivot 1"
        quickSortPivotBufferCPUSide = device.makeBuffer(length: MemoryLayout<PivotBuffer>.stride * globalTextureToBeSortedSize * globalTextureToBeSortedSize)!
       

        
        let ptrToPivotBuffer = quickSortPivotBuffersGPUSide[0].contents().bindMemory(to: PivotBuffer.self, capacity: globalTextureToBeSortedSize * globalTextureToBeSortedSize)
       
        for i in 0..<globalTextureToBeSortedSize {
            switch sorting_setting {
            case .X_ascending:
                let current_pivot = PivotBuffer(start_index: simd_int2(Int32(0),Int32(i)), end_index: simd_int2(Int32(globalTextureToBeSortedSize),Int32(i)))
                (ptrToPivotBuffer + i).pointee = current_pivot
                previousSubArrayCount = globalTextureToBeSortedSize
            case .Y_ascending:
                let current_pivot = PivotBuffer(start_index: simd_int2(Int32(i),Int32(0)), end_index: simd_int2(Int32(i),Int32(globalTextureToBeSortedSize)))
                (ptrToPivotBuffer + i).pointee = current_pivot
                previousSubArrayCount = globalTextureToBeSortedSize
                break
            case .X_descending:
                let current_pivot = PivotBuffer(start_index: simd_int2(Int32(0),Int32(i)), end_index: simd_int2(Int32(globalTextureToBeSortedSize),Int32(i)))
                (ptrToPivotBuffer + i).pointee = current_pivot
                previousSubArrayCount = globalTextureToBeSortedSize
                break
            case .Y_descending:
                let current_pivot = PivotBuffer(start_index: simd_int2(Int32(i),Int32(0)), end_index: simd_int2(Int32(i),Int32(globalTextureToBeSortedSize)))
                (ptrToPivotBuffer + i).pointee = current_pivot
                previousSubArrayCount = globalTextureToBeSortedSize
                break
            default:
                previousSubArrayCount = globalTextureToBeSortedSize
                break
            }
           
        }
            if(sorting_setting == .diagonal_ascending || sorting_setting == .diagonal_descending){
                previousSubArrayCount = globalTextureToBeSortedSize * 2 - 1
                for i in 0..<globalTextureToBeSortedSize * 2 - 1{
                    if(i < globalTextureToBeSortedSize){
                        let current_pivot = PivotBuffer(start_index: simd_int2(0,Int32(i)), end_index: simd_int2(Int32(i + 1), 0))
                        (ptrToPivotBuffer + i).pointee = current_pivot
                    }
                    else{
                        let current_pivot = PivotBuffer(start_index: simd_int2(Int32(i % globalTextureToBeSortedSize + 1),Int32(globalTextureToBeSortedSize - 1)), end_index: simd_int2(Int32(globalTextureToBeSortedSize), Int32(i % globalTextureToBeSortedSize + 1)))
                        (ptrToPivotBuffer + i).pointee = current_pivot
                    }
                }
            }
            
            
        quickSortTextures[0].replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: globalTextureToBeSortedSize, height: globalTextureToBeSortedSize, depth: 1)), mipmapLevel: 0, withBytes: globalTextureData, bytesPerRow: 4 * globalTextureToBeSortedSize)
    
        
        let odd_evenKernel = library.makeFunction(name: "oddEven_test")!
        do {
            odd_evenComputePipelineState = try device.makeComputePipelineState(function: odd_evenKernel)
        }
        catch {
            print(error)
            return nil
        }
        

        
        for _ in 0..<2 {
            odd_evenTextures.append(device.makeTexture(descriptor: globalTextureToBeSortedDC)!)
        }
        
        var odd_evenTextureData = [UInt8](repeating: 0, count: globalTextureToBeSortedSize * globalTextureToBeSortedSize * 4)
        
    
        odd_evenTextures[0].replace(region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: globalTextureToBeSortedSize, height: globalTextureToBeSortedSize, depth: 1)), mipmapLevel: 0, withBytes: globalTextureData, bytesPerRow: 4 * globalTextureToBeSortedSize)
        
        print("aligned memory is : \(getAlignedMemory(for: UInt32.self, with: 16, count: 100*100))")
    }
    
    
    
    
    
    
   
    
    
    func draw(in view: MTKView) {
        
        
        if(sorting_setting_changed){
            resetBuffersAndTextures()
            sorting_setting_changed = false
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {return}
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {return}
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        
        if sorting_setting == nil {
            
            
            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {return}
            renderEncoder.label = "render Quick Sort"
            renderEncoder.setViewport(MTLViewport(originX: 0, originY: 600, width: 400, height: 400, znear: 0, zfar: 1))
            renderEncoder.setRenderPipelineState(drawToScreenPipeline)
            renderEncoder.setFragmentTexture(odd_evenTextures[0], index: 0)
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            
            
            renderEncoder.setViewport(MTLViewport(originX: 0, originY: 0, width: 400, height: 400, znear: 0, zfar: 1))
            renderEncoder.setFragmentTexture(radixSortTextures[0], index: 0)
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

            renderEncoder.setViewport(MTLViewport(originX: 600, originY: 0, width: 400, height: 400, znear: 0, zfar: 1))
            renderEncoder.setFragmentTexture(mergeSortTextures_test[0], index: 0)
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

            
            renderEncoder.setViewport(MTLViewport(originX: 600, originY: 600, width: 400, height: 400, znear: 0, zfar: 1))
            renderEncoder.setFragmentTexture(quickSortTextures[0], index: 0)
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            
            
            renderEncoder.endEncoding()
            
        }
        else{
            // QUICK SORT
            
            sortWithQuickSort(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
            
            
            
            renderPassDescriptor.colorAttachments[0].loadAction = .load

            // ODD EVEN SORT
            sortWithOddEvenSort(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
            
            
            // ODD EVEN SORT
          
            

            
            
            // MERGE SORT
            
           sortWithMergeSort(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
            
                    
            
            // RADIX SORT
            sortWithRadixSort(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
            
            
           // RADIX SORT

        }
        
        
        
       
       
        
        
 
      
       

        
  
            
        
        
        
        
       
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        fps += 1
        
            
        
       
    }

    // mtkView will automatically call this function
    // whenever the size of the view changes (such as resizing the window).
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
       
    }
        
    
}
