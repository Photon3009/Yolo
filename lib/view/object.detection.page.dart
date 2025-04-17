import 'dart:async';

import 'package:flick_it/components/object.detection.painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class ObjectDetectionPage extends StatefulWidget {
  const ObjectDetectionPage({super.key});

  @override
  State<ObjectDetectionPage> createState() => _ObjectDetectionPageState();
}

class _ObjectDetectionPageState extends State<ObjectDetectionPage> {
  static const MethodChannel _channel =
      MethodChannel('com.example.flick_it/detection');

  bool _isDetecting = false;
  List<Map<String, dynamic>> _detectedObjects = [];
  Size? _previewSize;
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    _stopDetection();
    _detectionTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
    ].request();

    // Start the camera and detection after permissions are granted
    await _startDetection();
  }

  Future<void> _startDetection() async {
    if (_isDetecting) return;

    try {
      final Map<dynamic, dynamic> result =
          await _channel.invokeMethod('startDetection');

      setState(() {
        _isDetecting = true;
        if (result.containsKey('previewWidth') &&
            result.containsKey('previewHeight')) {
          _previewSize = Size(
            result['previewWidth'].toDouble(),
            result['previewHeight'].toDouble(),
          );
        }
      });

      // Start a timer to periodically get detection results
      _detectionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        _getDetectionResults();
      });
    } catch (e) {
      debugPrint('Error starting object detection: $e');
    }
  }

  Future<void> _stopDetection() async {
    if (!_isDetecting) return;

    try {
      await _channel.invokeMethod('stopDetection');
      setState(() {
        _isDetecting = false;
        _detectedObjects = [];
      });
    } catch (e) {
      debugPrint('Error stopping object detection: $e');
    }
  }

  Future<void> _getDetectionResults() async {
    if (!_isDetecting) return;

    try {
      final List<dynamic> result =
          await _channel.invokeMethod('getDetectionResults');
      setState(() {
        _detectedObjects =
            result.map((item) => Map<String, dynamic>.from(item)).toList();
      });
    } catch (e) {
      debugPrint('Error getting detection results: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ML Object Detection'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Native camera preview
                _isDetecting
                    ? const AndroidView(
                        viewType: 'com.example.ml_object_detection/camera_view',
                        creationParams: {},
                        creationParamsCodec: StandardMessageCodec(),
                      )
                    : const Center(child: Text('Camera initializing...')),

                // Overlay with detected objects
                if (_isDetecting && _previewSize != null)
                  CustomPaint(
                    painter: ObjectDetectionPainter(
                      _detectedObjects,
                      _previewSize!,
                      MediaQuery.of(context).size,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detected Objects: ${_detectedObjects.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _detectedObjects.length,
                    itemBuilder: (context, index) {
                      final object = _detectedObjects[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            '${object['label']} (${(object['confidence'] * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isDetecting ? _stopDetection : _startDetection,
        child: Icon(_isDetecting ? Icons.stop : Icons.play_arrow),
      ),
    );
  }
}
