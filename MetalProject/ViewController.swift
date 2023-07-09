//
//  ViewController.swift
//  MetalProject
//
//  Created by Sina Dashtebozorgy on 22/12/2022.
//

import Cocoa
import Metal
import MetalKit




class custom_Timer {
    var timer : Timer? = nil
    let key : UInt16
    var increment : Float
    let direction : simd_float3
    let interval : Double = 1/60
    init(key : UInt16, increment : Float){
        self.key = key
        self.increment = increment
        if(key == Keycode.w || key == Keycode.s){
            direction = increment * simd_float3(0,0,1)
        }
        else if(key == Keycode.a || key == Keycode.d){
            direction = increment * simd_float3(1,0,0)
        }
        else{
            direction = increment * simd_float3(0,1,0)
        }
        
    }
    func run(keyDown : Bool, camera : Camera){
        
        if((!keyDown) && (timer != nil)){
            timer?.invalidate()
            timer = nil
            return
        }
        
        if((timer == nil) && keyDown){
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true){[self] _ in
                camera.update_eye(with: direction)
            }
        }
    }
    
    
}


var mouse_x : Float?
var mouse_y : Float?

class ViewController: NSViewController {
   
    var cameraOrigin : simd_float3?
    var cameraDirection : simd_float3?
    let camerakeyHandler : [UInt16 : custom_Timer] = [Keycode.w : custom_Timer(key: Keycode.w, increment: -1.0/60), Keycode.s : custom_Timer(key: Keycode.s, increment: 1.0/60), Keycode.d : custom_Timer(key: Keycode.d, increment: 1.0/60), Keycode.a : custom_Timer(key: Keycode.a, increment: -1.0/60), Keycode.q : custom_Timer(key: Keycode.q, increment: 1.0/60), Keycode.e : custom_Timer(key: Keycode.e, increment: -1.0/60)]
    var cameraState : Bool = false {
        didSet {
            
            if let origin = cameraOrigin, let direction = cameraDirection {
               // print(origin,direction)
                var camera = simd_float4x4(eye: origin, center: direction, up: simd_float3(0,1,0))
                //renderer.currentScene.updateCamera(with: camera)
//                self.renderer.currentScene.eye = origin
//                self.renderer.currentScene.direction = direction
            }

                cameraState = false
        }
    }
    
    @IBOutlet weak var xEye: NSTextField!
    @IBOutlet weak var yEye: NSTextField!
    @IBOutlet weak var zEye: NSTextField!
    
    @IBOutlet weak var FrameRate: NSTextField!
    @IBOutlet weak var testOrigin: NSTextField!
    
    @IBOutlet weak var testDirection: NSTextField!
    
    @IBAction func adjustFrameRate(_ sender: NSTextField) {
        renderer.frameRate = sender.integerValue
    }
    
    @IBAction func adjustSorting(_ sender: NSMenuItem) {
        switch sender.title {
        case "X-ascending":
            print("x-up")
            if(renderer.sorting_setting != .X_ascending){
                renderer.sorting_setting_changed = true
                renderer.sorting_setting = .X_ascending
            }
            break
        case "X-descending":
            if(renderer.sorting_setting != .X_descending){
                renderer.sorting_setting_changed = true
                renderer.sorting_setting = .X_descending
            }
            print("x_down")
            break
        case "Y-ascending":
            if(renderer.sorting_setting != .Y_ascending){
                renderer.sorting_setting_changed = true
                renderer.sorting_setting = .Y_ascending
            }
            print("y_up")
            break
        case "Y-descending":
            if(renderer.sorting_setting != .Y_descending){
                renderer.sorting_setting_changed = true
                renderer.sorting_setting = .Y_descending
            }
            print("y-down")
            break
        case "Diagonal-ascending":
            if(renderer.sorting_setting != .diagonal_ascending){
                renderer.sorting_setting_changed = true
                renderer.sorting_setting = .diagonal_ascending
            }
            print("diagonal-up")
            break
        case "Diagonal-descending":
            if(renderer.sorting_setting != .diagonal_descending){
                renderer.sorting_setting_changed = true
                renderer.sorting_setting = .diagonal_descending
            }
            print("diagonal-down")
            break
        default:
            break
        }
    }
    
    @IBAction func updateCamera(_ sender: NSTextField) {
        
        switch sender {
        case xEye:
            print(sender.doubleValue)
            return
        case yEye:
            print(sender.doubleValue)
            return
        case zEye:
            print(sender.doubleValue)
            return
        case testOrigin:
            let origin = sender.stringValue.split(separator: ",")
            cameraState = true
            cameraOrigin = simd_float3(Float(origin[0])!,Float(origin[1])!,Float(origin[2])!)
            return
        case testDirection:
            let direction = sender.stringValue.split(separator: ",")
            cameraDirection = simd_float3(Float(direction[0])!,Float(direction[1])!,Float(direction[2])!)
            cameraState = true
        default:
            return
        }
    }
    

    @IBOutlet weak var skybox1: NSButton!
    @IBOutlet weak var skybox0: NSButton!
    
   
    var mtkView: MTKView!
    var renderer: Renderer!
    
    override func mouseUp(with event: NSEvent) {
//        renderer.rt_camera.reset_mouse()
//        renderer.cameraBeingChanged = false
    }
    
    override func mouseDragged(with event: NSEvent) {
//        renderer.cameraBeingChanged = true
//        let pos = simd_float2(Float(event.locationInWindow.x),Float(event.locationInWindow.y))
//        renderer.rt_camera.update_mouse(with: pos)
    }
   
    
    func myKeyDownEvent(event: NSEvent) -> NSEvent
    {
        
        switch event.keyCode {
        case Keycode.z:
            
            break
        case Keycode.x:
            break
        default:
            break
        }
//        switch event.keyCode {
//        case Keycode.one:
//            renderer.samplingFunctionIndex = 0
//            renderer.restart = true
//            break
//        case Keycode.two:
//            renderer.samplingFunctionIndex = 1
//            renderer.restart = true
//            break
//        case Keycode.w:
//            renderer.cameraBeingChanged = true
//            camerakeyHandler[Keycode.w]?.run(keyDown: true, camera: renderer.rt_camera)
//            break
//        case Keycode.s:
//            renderer.cameraBeingChanged = true
//            camerakeyHandler[Keycode.s]?.run(keyDown: true, camera: renderer.rt_camera)
//            break
//        case Keycode.a:
//            renderer.cameraBeingChanged = true
//            camerakeyHandler[Keycode.a]?.run(keyDown: true, camera: renderer.rt_camera)
//            break
//        case Keycode.d:
//            renderer.cameraBeingChanged = true
//            camerakeyHandler[Keycode.d]?.run(keyDown: true, camera: renderer.rt_camera)
//            break
//        case Keycode.q:
//            renderer.cameraBeingChanged = true
//            camerakeyHandler[Keycode.q]?.run(keyDown: true, camera: renderer.rt_camera)
//            break
//        case Keycode.e:
//            renderer.cameraBeingChanged = true
//            camerakeyHandler[Keycode.e]?.run(keyDown: true, camera: renderer.rt_camera)
//            break
//        default:
//            break
//        }
//
        return event
    }
    
    
    func myKeyUpEvent(event: NSEvent) -> NSEvent
    {
        
//        if(event.keyCode == Keycode.w || event.keyCode == Keycode.s || event.keyCode == Keycode.a || event.keyCode == Keycode.d || event.keyCode == Keycode.q || event.keyCode == Keycode.e){
//            for (_, value) in camerakeyHandler {
//                value.run(keyDown: false, camera: renderer.camera)
//            }
//            renderer.cameraBeingChanged = false
//        }
        return event
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.keyDown, handler: myKeyDownEvent)
       NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.keyUp, handler: myKeyUpEvent)
        let ta = NSTrackingArea(rect: CGRect.zero, options: [.activeAlways, .inVisibleRect, .mouseMoved], owner: self, userInfo: nil)
        self.view.addTrackingArea(ta)
        
        
        
        // First we save the MTKView to a convenient instance variable
        guard let mtkViewTemp = self.view as? MTKView else {
            print("View attached to ViewController is not an MTKView!")
            return
        }
        
        mtkView = mtkViewTemp
        mtkView.framebufferOnly = false
        //mtkView.drawableSize = CGSize(width: 800, height: 800)
       
        

        // Then we create the default device, and configure mtkView with it
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }

        print("My GPU is: \(defaultDevice)")
        mtkView.device = defaultDevice

        // Lastly we create an instance of our Renderer object,
        // and set it as the delegate of mtkView
        guard let tempRenderer = Renderer(mtkView: mtkView) else {
            print("Renderer failed to initialize")
            return
        }
       renderer = tempRenderer
//
       mtkView.delegate = renderer


    }
}

