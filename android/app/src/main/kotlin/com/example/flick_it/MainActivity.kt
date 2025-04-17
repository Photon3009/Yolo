// android/app/src/main/kotlin/com/example/ml_object_detection/MainActivity.kt

package com.example.flick_it

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import android.content.Context
import android.view.View
import android.widget.FrameLayout
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.objects.ObjectDetection
import com.google.mlkit.vision.objects.ObjectDetector
import com.google.mlkit.vision.objects.ObjectDetectorOptionsBase
import com.google.mlkit.vision.objects.defaults.ObjectDetectorOptions
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.flick_it/detection"
    private lateinit var objectDetectionHelper: ObjectDetectionHelper

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        objectDetectionHelper = ObjectDetectionHelper(this)
        
        // Register platform view factory
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.example.ml_object_detection/camera_view",
            CameraViewFactory(objectDetectionHelper)
        )
        
        // Set up method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDetection" -> {
                    val previewSize = objectDetectionHelper.startDetection()
                    result.success(mapOf(
                        "previewWidth" to previewSize.first,
                        "previewHeight" to previewSize.second
                    ))
                }
                "stopDetection" -> {
                    objectDetectionHelper.stopDetection()
                    result.success(null)
                }
                "getDetectionResults" -> {
                    result.success(objectDetectionHelper.getDetectionResults())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}

class CameraViewFactory(private val objectDetectionHelper: ObjectDetectionHelper) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return CameraView(context, objectDetectionHelper)
    }
}

class CameraView(context: Context, private val objectDetectionHelper: ObjectDetectionHelper) : PlatformView {
    private val view: View = objectDetectionHelper.getCameraPreview()

    override fun getView(): View {
        return view
    }

    override fun dispose() {
        // No-op
    }
}

class ObjectDetectionHelper(private val context: Context) {
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private val cameraExecutor = Executors.newSingleThreadExecutor()
    private val previewView = PreviewView(context)
    private var objectDetector: ObjectDetector? = null
    private val detectedObjects = mutableListOf<Map<String, Any>>()
    private var previewWidth = 0
    private var previewHeight = 0
    
    init {
        // Initialize ObjectDetector
        val options = ObjectDetectorOptions.Builder()
            .setDetectorMode(ObjectDetectorOptions.STREAM_MODE)
            .enableMultipleObjects()
            .enableClassification()
            .build()
        
        objectDetector = ObjectDetection.getClient(options)
    }
    
    fun getCameraPreview(): View {
        return previewView
    }
    
    fun startDetection(): Pair<Int, Int> {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            
            // Set up the preview use case
            val preview = Preview.Builder()
                .build()
                .also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
            
            // Set up the image analysis use case
            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
            
            imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
                processImageProxy(imageProxy)
            }
            
            // Select back camera
            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
            
            try {
                // Unbind use cases before rebinding
                cameraProvider?.unbindAll()
                
                // Bind use cases to camera
                camera = cameraProvider?.bindToLifecycle(
                    context as LifecycleOwner,
                    cameraSelector,
                    preview,
                    imageAnalysis
                )
                
                // Get preview size
                preview.resolutionInfo?.let {
                    previewWidth = it.resolution.width
                    previewHeight = it.resolution.height
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }, ContextCompat.getMainExecutor(context))
        
        return Pair(previewWidth, previewHeight)
    }
    
    fun stopDetection() {
        cameraProvider?.unbindAll()
        detectedObjects.clear()
    }
    
    fun getDetectionResults(): List<Map<String, Any>> {
        return detectedObjects.toList()
    }
    
    private fun processImageProxy(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage != null) {
            val image = InputImage.fromMediaImage(
                mediaImage, 
                imageProxy.imageInfo.rotationDegrees
            )
            
            objectDetector?.process(image)
                ?.addOnSuccessListener { detectedObjectList ->
                    synchronized(detectedObjects) {
                        detectedObjects.clear()
                        
                        for (detectedObject in detectedObjectList) {
                            val boundingBox = detectedObject.boundingBox
                            
                            val objectData = mutableMapOf<String, Any>()
                            objectData["left"] = boundingBox.left.toFloat()
                            objectData["top"] = boundingBox.top.toFloat()
                            objectData["right"] = boundingBox.right.toFloat()
                            objectData["bottom"] = boundingBox.bottom.toFloat()
                            
                            // Get the highest confidence classification
                            if (detectedObject.labels.isNotEmpty()) {
                                val highestConfLabel = detectedObject.labels.maxByOrNull { it.confidence }
                                if (highestConfLabel != null) {
                                    objectData["label"] = highestConfLabel.text
                                    objectData["confidence"] = highestConfLabel.confidence
                                } else {
                                    objectData["label"] = "Unknown"
                                    objectData["confidence"] = 0.0f
                                }
                            } else {
                                objectData["label"] = "Unknown"
                                objectData["confidence"] = 0.0f
                            }
                            
                            detectedObjects.add(objectData)
                        }
                    }
                }
                ?.addOnFailureListener { e ->
                    e.printStackTrace()
                }
                ?.addOnCompleteListener {
                    imageProxy.close()
                }
        } else {
            imageProxy.close()
        }
    }
}