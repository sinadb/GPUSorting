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



func createGenericPipeline(device : MTLDevice, vertexStageName : String, fragmentStageName : String, drawableColourFormat : MTLPixelFormat) -> MTLRenderPipelineState {
    
    let library = device.makeDefaultLibrary()
    let pipelineDC = MTLRenderPipelineDescriptor()
    pipelineDC.vertexFunction = library?.makeFunction(name: vertexStageName)
    pipelineDC.fragmentFunction = library?.makeFunction(name: fragmentStageName)
    pipelineDC.colorAttachments[0].pixelFormat = drawableColourFormat
    pipelineDC.depthAttachmentPixelFormat = .depth32Float
    
    
    return try! device.makeRenderPipelineState(descriptor: pipelineDC)
    
   
    
}



class skyBoxScene {
    var fps = 0
    var translateFirst = 0
    var rotateFirst = 1
    var False = false
    var True = true
    var centreOfReflection : simd_float3
    var camera : Camera
    var projection : simd_float4x4
    var nodes = [Mesh]()
    var skyBoxMesh : Mesh
    var reflectiveNodeMesh : Mesh?
   
    var reflectiveNodeInitialState = [simd_float3]()
    var current_node = 0
    // use these to render to cubeMap
    var renderToCubeframeConstants = [FrameConstants]()
    
    // use this to render the skybox and the final pass
    var frameConstants : FrameConstants


    // pipelines
    var renderToCubePipelineForSkyBox : pipeLine?
    var renderToCubePipelineForMesh : pipeLine?
    var simplePipeline : pipeLine?
    var renderSkyboxPipeline : pipeLine?
    var renderReflectionPipleline : pipeLine?
   
    let device : MTLDevice

    var renderTarget : Texture?
    var depthRenderTarget : MTLTexture?

    var commandQueue : MTLCommandQueue
    var view : MTKView
    var depthStencilState : MTLDepthStencilState
    var sampler : MTLSamplerState
    var directionalLight : simd_float3?
    var cameraChanged = false
    
    

    func initiatePipeline(){
        let posAttrib = Attribute(format: .float4, offset: 0, length: 16, bufferIndex: 0)
        let normalAttrib = Attribute(format: .float3, offset: MemoryLayout<Float>.stride*4,length: 12, bufferIndex: 0)
        let texAttrib = Attribute(format: .float2, offset: MemoryLayout<Float>.stride*7, length : 8, bufferIndex: 0)
        let tangentAttrib = Attribute(format: .float4, offset: MemoryLayout<Float>.stride*9, length: 16, bufferIndex: 0)
        let bitangentAttrib = Attribute(format: .float4, offset: MemoryLayout<Float>.stride*13, length: 16, bufferIndex: 0)

        let instanceAttrib = Attribute(format : .float3, offset: 0, length : 12, bufferIndex: 1)
        let vertexDescriptor = createVertexDescriptor(attributes: posAttrib,normalAttrib,texAttrib,tangentAttrib,bitangentAttrib)

        // render world into cubemap
        
        let FC = functionConstant()
        
        FC.setValue(type: .bool, value: &False, at: FunctionConstantValues.constant_colour)
        FC.setValue(type: .bool, value: &True, at: FunctionConstantValues.cube)
        
       
    
        
        renderToCubePipelineForSkyBox  = pipeLine(device, "vertexRenderToCube", "fragmentRenderToCube", vertexDescriptor, true,amplificationCount: 6,functionConstant: FC.functionConstant,label: "RenderToCubePipeline")
      
        
        
        FC.setValue(type: .bool, value: &True, at: FunctionConstantValues.constant_colour)
        FC.setValue(type: .bool, value: &False, at: FunctionConstantValues.cube)
        
        renderToCubePipelineForMesh = pipeLine(device, "vertexRenderToCube", "fragmentRenderToCube", vertexDescriptor, true,amplificationCount: 6,functionConstant: FC.functionConstant,label: "RenderToCubePipeline")
        
        // simple pipeline for the final pass

       
        simplePipeline = pipeLine(device, "vertexSimpleShader", "fragmentSimpleShader", vertexDescriptor,false,label: "simpleShaderPipeline")


        // render the reflections using cubemap
      
        renderReflectionPipleline = pipeLine(device, "vertexRenderCubeReflection", "fragmentRenderCubeReflection", vertexDescriptor, false, label: "renderCubeMapReflection")
        
        // pipeline for rendering skybox

        renderSkyboxPipeline = pipeLine(device, "vertexRenderSkyBox", "fragmentRenderSkyBox", vertexDescriptor, false, label: "SkyboxPipeline")

    }

    func initialiseRenderTarget(){
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .bgra8Unorm_srgb
        textureDescriptor.textureType = .typeCube
        textureDescriptor.width = 1200
        textureDescriptor.height = 1200
        textureDescriptor.storageMode = .private
        textureDescriptor.mipmapLevelCount = 8
        textureDescriptor.usage = [.shaderRead,.renderTarget]
        var renderTargetTexture = device.makeTexture(descriptor: textureDescriptor)
        textureDescriptor.pixelFormat = .depth32Float
        depthRenderTarget = device.makeTexture(descriptor: textureDescriptor)
        renderTarget = Texture(texture: renderTargetTexture!, index: textureIDs.cubeMap)
    }

    init(device : MTLDevice, at view : MTKView, from centreOfReflection: simd_float3, attachTo camera : Camera, with projection : simd_float4x4) {
        self.device = device
        self.centreOfReflection = centreOfReflection
        self.camera = camera
        self.projection = projection
        commandQueue = device.makeCommandQueue()!
        self.view = view

        // make depthstencil state
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilDescriptor.depthCompareFunction = .lessEqual
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)!

        // create a samplerState
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.rAddressMode = .repeat
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat
        samplerDescriptor.normalizedCoordinates = True
        sampler = device.makeSamplerState(descriptor: samplerDescriptor)!
        
        
        frameConstants = FrameConstants(viewMatrix: self.camera.cameraMatrix, projectionMatrix: projection)
        
        let allocator = MTKMeshBufferAllocator(device: device)
        let cubeMDLMesh = MDLMesh(boxWithExtent: simd_float3(1,1,1), segments: simd_uint3(1,1,1), inwardNormals: false, geometryType: .triangles, allocator: allocator)
        skyBoxMesh = Mesh(device: device, Mesh: cubeMDLMesh)!
        let frameConstantBuffer = device.makeBuffer(bytes: &frameConstants, length: MemoryLayout<FrameConstants>.stride,options: [])
        //skyBoxMesh.addUniformBuffer(buffer: UniformBuffer(buffer: frameConstantBuffer!, index: vertexBufferIDs.frameConstant))

       

       
        
        initiatePipeline()
        initialiseRenderTarget()
        
    }

//    func attach_camera_to_scene(camera : Camera){
//        sceneCamera = camera
//    }



    func addDirectionalLight(with direction : simd_float3){
        directionalLight = direction
    }

    func addNodes(mesh : Mesh){
        // firest pass nodes are being rendered from the centre of reflection
        
        mesh.init_instance_buffers(with: camera.cameraMatrix)
        nodes.append(mesh)
        
      

    }

    func addReflectiveNode(mesh : Mesh, with size : Float){
        
        reflectiveNodeMesh = mesh
        let modelMatrix = create_modelMatrix(rotation: simd_float3(0), translation: centreOfReflection, scale: simd_float3(size))
        reflectiveNodeMesh?.createInstance(with: modelMatrix)
        reflectiveNodeMesh?.init_instance_buffers(with: self.camera.cameraMatrix)
        reflectiveNodeMesh?.add_textures(texture: renderTarget!)
        
        let projection = simd_float4x4(fovRadians: 3.14/2, aspectRatio: 1, near: size, far: 100)
        
        var cameraArray = [simd_float4x4]()
        
        cameraArray.append(simd_float4x4(eye: centreOfReflection, center: simd_float3(1,0,0) + centreOfReflection , up: simd_float3(0,-1,0)))
                           
        cameraArray.append(simd_float4x4(eye: centreOfReflection, center: simd_float3(-1,0,0) + centreOfReflection , up: simd_float3(0,-1,0)))
        
        cameraArray.append(simd_float4x4(eye: centreOfReflection,  center: simd_float3(0,-1,0) + centreOfReflection , up: simd_float3(0,0,-1)))
           
        cameraArray.append(simd_float4x4(eye: centreOfReflection, center: simd_float3(0,1,0) + centreOfReflection , up: simd_float3(0,0,1)))
                           
        cameraArray.append(simd_float4x4(eye: centreOfReflection, center: simd_float3(0,0,1) + centreOfReflection , up: simd_float3(0,-1,0)))
                   
        cameraArray.append(simd_float4x4(eye: centreOfReflection, center: simd_float3(0,0,-1) + centreOfReflection, up: simd_float3(0,-1,0)))
                   
        
        for i in 0..<6{
            renderToCubeframeConstants.append(FrameConstants(viewMatrix: cameraArray[i], projectionMatrix: projection))
        }
     
    }

    func setSkyMapTexture(with texture : Texture){
        skyBoxMesh.add_textures(texture: texture)
    }



    func renderScene(){
        
        frameConstants.viewMatrix = camera.cameraMatrix
        if(cameraChanged){
            for mesh in nodes {
                mesh.updateNormalMatrix(with: frameConstants.viewMatrix)

            }
            cameraChanged = false
        }

        fps += 1
          guard let commandBuffer = commandQueue.makeCommandBuffer() else {return}
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {return}
        renderPassDescriptor.colorAttachments[0].texture = renderTarget?.texture
        renderPassDescriptor.depthAttachment.texture = depthRenderTarget!
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.clearDepth = 1
        renderPassDescriptor.renderTargetArrayLength = 6
        
        // render to cubempa pass
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {return}
        renderEncoder.setRenderPipelineState(renderToCubePipelineForMesh!.m_pipeLine)
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setVertexAmplificationCount(6, viewMappings: nil)
        renderEncoder.setVertexBytes(&renderToCubeframeConstants, length: MemoryLayout<FrameConstants>.stride*6, index: vertexBufferIDs.frameConstant)
        
        
        for mesh in nodes {
            //mesh.rotateMesh(with: simd_float3(0,Float(fps)*0.2,0), and: camera.cameraMatrix)
            mesh.draw(renderEncoder: renderEncoder)
        }
        
        renderEncoder.setRenderPipelineState(renderToCubePipelineForSkyBox!.m_pipeLine)
        skyBoxMesh.draw(renderEncoder: renderEncoder, with: 1)
        
        renderEncoder.endEncoding()
        
        guard let mipRenderEncoder = commandBuffer.makeBlitCommandEncoder() else {return}
        mipRenderEncoder.generateMipmaps(for: renderTarget!.texture)
        mipRenderEncoder.endEncoding()
        
        
        
        guard let finalRenderPassDescriptor = view.currentRenderPassDescriptor else {return}
        finalRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
        finalRenderPassDescriptor.depthAttachment.clearDepth = 1
       finalRenderPassDescriptor.depthAttachment.loadAction = .clear
//
        guard let finalRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: finalRenderPassDescriptor) else {return}
        finalRenderEncoder.setDepthStencilState(depthStencilState)
        finalRenderEncoder.setFrontFacing(.counterClockwise)
        
        finalRenderEncoder.setRenderPipelineState(renderReflectionPipleline!.m_pipeLine)
        finalRenderEncoder.setVertexBytes(&frameConstants, length: MemoryLayout<FrameConstants>.stride, index: vertexBufferIDs.frameConstant)
        finalRenderEncoder.setFragmentBytes(&self.camera.eye, length: 16, index: 0)
        
        // render reflective mesh
        reflectiveNodeMesh?.draw(renderEncoder: finalRenderEncoder,with: 1, culling: .back)

        // render the meshes
        
        finalRenderEncoder.setRenderPipelineState(simplePipeline!.m_pipeLine)
        
        var eyeSpaceLightDirection = camera.cameraMatrix * simd_float4(directionalLight!.x,directionalLight!.y,directionalLight!.z,0)
        
        finalRenderEncoder.setFragmentBytes(&eyeSpaceLightDirection, length: 16, index: vertexBufferIDs.lightPos)
        for mesh in nodes {
            mesh.draw(renderEncoder: finalRenderEncoder,culling: .back)
        }

        
        // render the skybox
        
        finalRenderEncoder.setRenderPipelineState(renderSkyboxPipeline!.m_pipeLine)
        skyBoxMesh.draw(renderEncoder: finalRenderEncoder, with: 1, culling: .front)

        finalRenderEncoder.endEncoding()

        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()



    }
}











class Renderer : NSObject, MTKViewDelegate {
    
  
    
 
    let True = true
    let False = false
   
    
    let device: MTLDevice
    let commandQueue : MTLCommandQueue
    var cameraLists = [Camera]()
    
    let pipeline : pipeLine
   
    var frameSephamore = DispatchSemaphore(value: 1)
    var fps = 0
     var frameConstants = FrameConstants(viewMatrix: simd_float4x4(eye: simd_float3(0), center: simd_float3(0,0,-1), up: simd_float3(0,1,0)) , projectionMatrix: simd_float4x4(fovRadians: 3.14/2, aspectRatio: 2.0, near: 0.1, far: 50))
    
    let depthStencilState : MTLDepthStencilState
    
    
     var moveTriangle : Bool = true
    
    
   
    let gridMesh : GridMesh
    var camera : Camera
     
    var length : Float = 0.06
    let minBound = simd_float3(-3,-3,-16)
    let maxBound = simd_float3(3,3,-10)
    let voxelizedMesh : Voxel
    
    
    
    let renderToScreenPipeline : MTLRenderPipelineState
    let rayTracingPipeline : MTLComputePipelineState
    let drawableTexture : MTLTexture
    let drawableSize = MTLSize(width: 800, height: 800, depth: 1)
    var spheres = [Sphere(origin: simd_float3(0,0,0), colour: simd_float3(1,0,0), radiusSquared: 0.25, radius: 0.5)]
   
    var BB = MTLAxisAlignedBoundingBox(min: MTLPackedFloat3Make(-0.5, -0.5, -0.5), max: MTLPackedFloat3Make(0.5, 0.5, 0.5))
    
    
    let accelerationStructureDC : MTLPrimitiveAccelerationStructureDescriptor
    let accelerationStructure : MTLAccelerationStructure
    
    let functionTable : MTLIntersectionFunctionTable
    let scratchBufferAC : MTLBuffer
    let sizesAC : MTLAccelerationStructureSizes
    
    
    let instancedAccelerationStructureDC : MTLInstanceAccelerationStructureDescriptor
    let instancedAccelerationStructure : MTLAccelerationStructure
    let scratchBufferIAC : MTLBuffer
    let sizesIAC : MTLAccelerationStructureSizes
    let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true){_ in
        print("Timer")
    }
    var colours = [packed_float4]()
    let colourBuffer : MTLBuffer
    var rt_camera = RT_Camera(origin: simd_float3(6,0,0), right: simd_float3(1,0,0), up: simd_float3(0,1,0), forward: simd_float3(-2,0,-1))
    
    
    
    init?(mtkView: MTKView){
        
        
        device = mtkView.device!
        mtkView.preferredFramesPerSecond = 120
        //drawableSize = MTLSize(width: Int(mtkView.drawableSize.width), height: Int(mtkView.drawableSize.height), depth: 1)
        commandQueue = device.makeCommandQueue()!
        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        mtkView.depthStencilPixelFormat = .depth32Float
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilDescriptor.depthCompareFunction = .lessEqual
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
        
        camera = Camera(for: mtkView, eye: simd_float3(0), centre: simd_float3(0,0,-1))
        cameraLists.append(camera)
           
        let vertexDescriptor = cushionedVertexDescriptor()
        
        pipeline = pipeLine(device, "render_vertex", "render_fragment", vertexDescriptor, false)!
       
        let halfLength : Float = length * 0.5
        
        gridMesh = GridMesh(device: device, minBound: minBound, maxBound: maxBound, length: length)
        
        
      
        
       
        
        voxelizedMesh = Voxel(device: device, address: "blub_triangulated", minmax: [minBound,maxBound], gridLength: length)
        
        renderToScreenPipeline = createGenericPipeline(device: device, vertexStageName: "drawToScreenVertex", fragmentStageName: "drawToScreenFragment", drawableColourFormat: mtkView.colorPixelFormat)
        
        
        let textureDC = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: mtkView.colorPixelFormat, width: drawableSize.width, height: drawableSize.height, mipmapped: False)
        textureDC.usage = [.shaderRead,.shaderWrite]
        drawableTexture = device.makeTexture(descriptor: textureDC)!
        
        
        
        // set up the acceleration structure
        accelerationStructureDC = MTLPrimitiveAccelerationStructureDescriptor()
        
        let geometryDC = MTLAccelerationStructureBoundingBoxGeometryDescriptor()
        
        let boundingBoxBuffer = device.makeBuffer(bytes: &BB, length: MemoryLayout<MTLAxisAlignedBoundingBox>.stride * 1 ,options: [])
        let sphereBuffer = device.makeBuffer(bytes: spheres, length: MemoryLayout<Sphere>.stride * 1,options: [])
        
        geometryDC.boundingBoxBuffer = boundingBoxBuffer
        geometryDC.boundingBoxCount = 1
        geometryDC.boundingBoxStride = MemoryLayout<MTLAxisAlignedBoundingBox>.stride * 1
        geometryDC.intersectionFunctionTableOffset = 0

        
        geometryDC.primitiveDataBuffer = sphereBuffer
        geometryDC.primitiveDataStride = MemoryLayout<Sphere>.stride
        geometryDC.primitiveDataElementSize = MemoryLayout<Sphere>.stride
        
        
        accelerationStructureDC.geometryDescriptors = [geometryDC]
        
        
        
       
        sizesAC = device.accelerationStructureSizes(descriptor: accelerationStructureDC)
        accelerationStructure = device.makeAccelerationStructure(descriptor: accelerationStructureDC)!
        scratchBufferAC = device.makeBuffer(length: sizesAC.buildScratchBufferSize)!
        
      
        
       
        
        instancedAccelerationStructureDC = MTLInstanceAccelerationStructureDescriptor()
        instancedAccelerationStructureDC.instanceDescriptorType = .userID
        instancedAccelerationStructureDC.instanceCount = 100
        instancedAccelerationStructureDC.instancedAccelerationStructures = [accelerationStructure]
        
        let instancesBuffer = device.makeBuffer(length: MemoryLayout<MTLAccelerationStructureUserIDInstanceDescriptor>.size * 100)!
        
        let DCsPtr = instancesBuffer.contents().bindMemory(to: MTLAccelerationStructureUserIDInstanceDescriptor.self,capacity:100)
        
        var transformationMatrices = [MTLPackedFloat4x3]()
        for i in 0...99{
            let x = Float.random(in: -10...10)
            let y = Float.random(in: -5...5)
            let z = Float.random(in: -15 ... -5)
            transformationMatrices.append(create_translation_matix_packed(translate: simd_float3(x,y,z)))
            
            (DCsPtr + i).pointee.accelerationStructureIndex = UInt32(0)
            (DCsPtr + i).pointee.intersectionFunctionTableOffset = 0
            (DCsPtr + i).pointee.transformationMatrix = transformationMatrices[i]
            (DCsPtr + i).pointee.mask = UInt32(1)
            (DCsPtr + i).pointee.userID = UInt32(i)
            
            let r = Float.random(in: 0...1)
            let g = Float.random(in: 0...1)
            let b = Float.random(in: 0...1)
            
            colours.append(packed_float4(r, g, b))
        }
        
       
      
        colourBuffer = device.makeBuffer(bytes: colours, length: MemoryLayout<packed_float4>.stride * 100,options: [])!
       
        
        instancedAccelerationStructureDC.instanceDescriptorBuffer = instancesBuffer
        //instancedAccelerationStructureDC.instanceDescriptorStride = MemoryLayout<MTLAccelerationStructureInstanceDescriptor>.stride
        
       
        sizesIAC = device.accelerationStructureSizes(descriptor: instancedAccelerationStructureDC)

        instancedAccelerationStructure = device.makeAccelerationStructure(descriptor: instancedAccelerationStructureDC)!
        scratchBufferIAC = device.makeBuffer(length: sizesIAC.buildScratchBufferSize, options: .storageModePrivate)!
        
       
        
        // intersectionfunctions
        
        let library = device.makeDefaultLibrary()!
        
        let sphereIntersectionFunction = library.makeFunction(name: "sphereIntersection")!
        let linkedFunctions = MTLLinkedFunctions()
        linkedFunctions.functions = [sphereIntersectionFunction]
        
        
        let rayTracingPipelineDC = MTLComputePipelineDescriptor()
        let rayTracingFunction = library.makeFunction(name: "RayTracing_Instanced")!
        rayTracingPipelineDC.computeFunction = rayTracingFunction
        rayTracingPipelineDC.linkedFunctions = linkedFunctions
        rayTracingPipelineDC.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        
        rayTracingPipeline = try! device.makeComputePipelineState(descriptor: rayTracingPipelineDC, options: [], reflection: nil)
        print(rayTracingPipeline.threadExecutionWidth)
        
        let functionTableDC = MTLIntersectionFunctionTableDescriptor()
        functionTableDC.functionCount = 1
        functionTable = rayTracingPipeline.makeIntersectionFunctionTable(descriptor: functionTableDC)!
        let functionHandle = rayTracingPipeline.functionHandle(function: sphereIntersectionFunction)
        functionTable.setFunction(functionHandle, index: 0)
        
        
        
        
        
        
    }
   
    // mtkView will automatically call this function
    // whenever it wants new content to be rendered.
    
    
   
    
    
    func draw(in view: MTKView) {
        if(fps == 0){
            print(view.drawableSize)
        }
        
       
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {return}
        
        guard let accelerationStructorEncoder = commandBuffer.makeAccelerationStructureCommandEncoder() else {return}
        accelerationStructorEncoder.build(accelerationStructure: instancedAccelerationStructure, descriptor: instancedAccelerationStructureDC, scratchBuffer: scratchBufferIAC, scratchBufferOffset: 0)
        
        accelerationStructorEncoder.build(accelerationStructure: accelerationStructure, descriptor: accelerationStructureDC, scratchBuffer: scratchBufferAC, scratchBufferOffset: 0)
        
        accelerationStructorEncoder.endEncoding()
        
      
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {return}
        //renderPassDescriptor.colorAttachments[0].storeAction = .dontCare
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {return}
        computeEncoder.setComputePipelineState(rayTracingPipeline)
        computeEncoder.setTexture(drawableTexture, index: 0)
        computeEncoder.setBuffer(colourBuffer, offset: 0, index: 10)
        computeEncoder.setBytes(&rt_camera, length: MemoryLayout<RT_Camera>.stride, index: 11)
        computeEncoder.useResource(accelerationStructure, usage: .read)
        computeEncoder.setIntersectionFunctionTable(functionTable, bufferIndex: 1)
        computeEncoder.setAccelerationStructure(instancedAccelerationStructure, bufferIndex: 0)
        computeEncoder.dispatchThreads(drawableSize, threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
        computeEncoder.endEncoding()
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {return}
        
        renderEncoder.setRenderPipelineState(renderToScreenPipeline)
        renderEncoder.setFragmentTexture(drawableTexture, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
       
        
        
        commandBuffer.present(view.currentDrawable!)
       
        commandBuffer.commit()
        fps+=1
       
        
        
        

       
    }

    // mtkView will automatically call this function
    // whenever the size of the view changes (such as resizing the window).
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
}
