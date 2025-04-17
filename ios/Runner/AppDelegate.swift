// ios/Runner/AppDelegate.swift

import UIKit
import Flutter
import AVFoundation
import MLKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var objectDetectionHelper: ObjectDetectionHelper?
    private let channel = "com.example.flick_it/detection"
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        
        // Initialize ObjectDetectionHelper
        objectDetectionHelper = ObjectDetectionHelper()
        
        // Register method channel
        let methodChannel = FlutterMethodChannel(name: channel, binaryMessenger: controller.binaryMessenger)
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            
            switch call.method {
            case "startDetection":
                let previewSize = self.objectDetectionHelper?.startDetection() ?? (0, 0)
                result([
                    "previewWidth": previewSize.0,
                    "previewHeight": previewSize.1
                ])
            case "stopDetection":
                self.objectDetectionHelper?.stopDetection()
                result(nil)
            case "getDetectionResults":
                let detectionResults = self.objectDetectionHelper?.getDetectionResults() ?? []
                result(detectionResults)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        // Register platform view factory
        let factory = CameraViewFactory(objectDetectionHelper: objectDetectionHelper!)
        registrar(forPlugin: "ObjectDetectionPlugin").register(
            factory,
            withId: "com.example.ml_object_detection/camera_view"
        )
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

class CameraViewFactory: NSObject, FlutterPlatformViewFactory {
    private let objectDetectionHelper: ObjectDetectionHelper
    
    init(objectDetectionHelper: ObjectDetectionHelper) {
        self.objectDetectionHelper = objectDetectionHelper
        super.init()
    }
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return CameraView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            objectDetectionHelper: objectDetectionHelper
        )
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class CameraView: NSObject, FlutterPlatformView {
    private var _view: UIView
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        objectDetectionHelper: ObjectDetectionHelper
    ) {
        _view = objectDetectionHelper.getCameraPreview()
        super.init()
    }
    
    func view() -> UIView {
        return _view
    }
}

class ObjectDetectionHelper: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var previewView: UIView
    private var objectDetector: ObjectDetector?
    private var detectedObjects: [[String: Any]] = []
    private var previewWidth: Int = 0
    private var previewHeight: Int = 0
    
    override init() {
        previewView = UIView()
        
        super.init()
        
        // Initialize ObjectDetector
        let options = ObjectDetectorOptions()
        options.detectorMode = .stream
        options.shouldEnableMultipleObjects = true
        options.shouldEnableClassification = true
        
        objectDetector = ObjectDetector.objectDetector(options: options)
    }
    
    func getCameraPreview() -> UIView {
        return previewView
    }
    
    func startDetection() -> (Int, Int) {
        setupCamera()
        
        session?.startRunning()
        
        return (previewWidth, previewHeight)
    }
    
    func stopDetection() {
        session?.stopRunning()
        detectedObjects.removeAll()
    }
    
    func getDetectionResults() -> [[String: Any]] {
        return detectedObjects
    }
    
    private func setupCamera() {
        // Create capture session
        session = AVCaptureSession()
        session?.sessionPreset = .high
        
        // Get back camera
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return
        }
        
        do {
            // Create input for camera
            let input = try AVCaptureDeviceInput(device: backCamera)
            
            if session?.canAddInput(input) == true {
                session?.addInput(input)
            }
            
            // Create and add video output
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            
            if session?.canAddOutput(videoOutput) == true {
                session?.addOutput(videoOutput)
            }
            
            // Configure preview layer
            previewLayer = AVCaptureVideoPreviewLayer(session: session!)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = previewView.bounds
            
            // Add preview layer to preview view
            if let previewLayer = previewLayer {
                previewView.layer.addSublayer(previewLayer)
            }
            
            // Store preview dimensions
            if let connection = previewLayer?.connection {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            // Get preview dimensions
            if let dimensions = backCamera.activeFormat.formatDescription.dimensions {
                previewWidth = Int(dimensions.width)
                previewHeight = Int(dimensions.height)
            }
            
        } catch {
            print("Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let visionImage = VisionImage(buffer: sampleBuffer)
        
        // Set orientation based on device orientation
        if let connection = output.connection(with: .video) {
            visionImage.orientation = videoOrientationFromDeviceOrientation()
        }
        
        do {
            // Process image with ML Kit
            let objects = try objectDetector?.results(in: visionImage)
            
            var newDetectedObjects: [[String: Any]] = []
            
            // Process the detected objects
            if let objects = objects {
                for object in objects {
                    let frame = object.frame
                    
                    var objectData: [String: Any] = [
                        "left": frame.origin.x,
                        "top": frame.origin.y,
                        "right": frame.origin.x + frame.size.width,
                        "bottom": frame.origin.y + frame.size.height
                    ]
                    
                    // Get highest confidence label
                    if let highestConfLabel = object.labels.max(by: { $0.confidence < $1.confidence }) {
                        objectData["label"] = highestConfLabel.text
                        objectData["confidence"] = highestConfLabel.confidence
                    } else {
                        objectData["label"] = "Unknown"
                        objectData["confidence"] = 0.0
                    }
                    
                    newDetectedObjects.append(objectData)
                }
            }
            
            // Update the detected objects on main thread
            DispatchQueue.main.async {
                self.detectedObjects = newDetectedObjects
            }
            
        } catch {
            print("Error detecting objects: \(error.localizedDescription)")
        }
    }
    
    private func videoOrientationFromDeviceOrientation() -> UIImage.Orientation {
        let deviceOrientation = UIDevice.current.orientation
        switch deviceOrientation {
        case .portrait:
            return .up
        case .landscapeLeft:
            return .right
        case .landscapeRight:
            return .left
        case .portraitUpsideDown:
            return .down
        default:
            return .up
        }
    }
}