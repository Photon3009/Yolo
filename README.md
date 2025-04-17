# Flutter ML Kit Object Detection

A Flutter application that performs real-time object detection using native ML Kit APIs on both Android and iOS platforms. This project demonstrates how to integrate ML Kit's object detection capabilities using platform channels without relying on third-party pub.dev packages.

## Features

- Real-time camera feed on Android and iOS
- Object detection using native ML Kit APIs
- Platform-specific implementation via Flutter's MethodChannel
- Visual bounding boxes around detected objects
- Object labels with confidence scores

## Project Structure

- `lib/`: Flutter code
  - `main.dart`: Main application entry point with UI implementation
- `android/`: Android platform-specific code
  - Native implementation using Kotlin and ML Kit for Android
- `ios/`: iOS platform-specific code
  - Native implementation using Swift and ML Kit for iOS

## Setup Instructions

### Prerequisites

- Flutter SDK (latest version) - [Install Flutter](https://flutter.dev/docs/get-started/install)
- Android Studio / Xcode
- ML Kit dependencies

### Android Setup

1. Add the following dependencies to your `android/app/build.gradle` file:

```gradle
dependencies {
    // ML Kit Object Detection
    implementation 'com.google.mlkit:object-detection:17.0.0'

    // CameraX
    def camerax_version = "1.2.3"
    implementation "androidx.camera:camera-core:$camerax_version"
    implementation "androidx.camera:camera-camera2:$camerax_version"
    implementation "androidx.camera:camera-lifecycle:$camerax_version"
    implementation "androidx.camera:camera-view:$camerax_version"
}
```

2. Update `android/app/src/main/AndroidManifest.xml` to add camera permissions:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" />

    <!-- Rest of your manifest file -->
</manifest>
```

### iOS Setup

1. Add camera usage description to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to perform object detection</string>
```

2. Install the required CocoaPods by adding the following to your `ios/Podfile`:

```ruby
target 'Runner' do
  # ...

  # Add ML Kit dependencies
  pod 'GoogleMLKit/ObjectDetection', '~> 3.2.0'

  # ...
end
```

3. Run `pod install` in the iOS directory:

```bash
cd ios
pod install
```

### Flutter Setup

1. Add the following dependencies to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  permission_handler: ^10.2.0
```

2. Run `flutter pub get` to install the dependencies:

```bash
flutter pub get
```

## Implementation Details

### Flutter Layer

The Flutter layer handles:

- UI components for displaying the camera feed
- Painting detected object bounding boxes on the screen
- Managing the platform channels for communication with native code

Platform channels are used to:

- Start/stop the object detection process
- Retrieve detection results from native code
- Configure the camera preview

### Android Implementation

The Android side uses:

- CameraX API for camera preview and image analysis
- ML Kit's ObjectDetector for real-time object detection
- Custom View for displaying camera preview in Flutter

### iOS Implementation

The iOS side uses:

- AVFoundation for camera capture and preview
- ML Kit's ObjectDetector for real-time object detection
- Custom UIView for displaying camera preview in Flutter

## How It Works

1. The app initializes the Flutter UI with a platform view for the camera preview.
2. The camera permission is requested using `permission_handler`.
3. When the camera permission is granted, the app starts the native camera preview.
4. The native code processes each frame from the camera to detect objects using ML Kit.
5. Detection results are passed back to Flutter through the platform channel.
6. Flutter renders bounding boxes and labels on top of the camera preview.

## Implementation Explanation

The implementation follows three main layers:

1. **Flutter UI Layer**:

   - Handles user interface elements
   - Manages permission requests
   - Renders bounding boxes using CustomPaint
   - Communicates with native platforms

2. **Platform Channel Bridge**:

   - Establishes bidirectional communication between Flutter and native code
   - Uses MethodChannel for function calls
   - Passes binary data for image processing

3. **Native Platform Layer**:
   - Android: Uses Kotlin with CameraX and ML Kit
   - iOS: Uses Swift with AVFoundation and ML Kit
   - Processes camera frames in real-time
   - Returns detection results to Flutter

The key challenge was synchronizing the camera feed display with the detection results while maintaining good performance.

## Issues and Roadblocks

During development, several challenges were encountered:

1. **Performance Bottlenecks**:

   - Processing every frame caused lag on lower-end devices
   - Solution: Implemented frame skipping to process every n-th frame

2. **Platform View Synchronization**:

   - Camera preview and detection overlay were sometimes misaligned
   - Solution: Used proper coordinate transformation between native and Flutter UI

3. **Memory Management**:

   - Continuous image processing caused memory leaks on iOS
   - Solution: Implemented proper disposal of detection objects and camera resources

4. **UI Thread Blocking**:
   - Detection processing blocked the UI thread
   - Solution: Moved detection to background threads with proper synchronization

## Limitations

- Performance may vary depending on the device's hardware capabilities.
- Object detection accuracy is limited by ML Kit's pre-trained models.
- The app currently only supports the back camera.

## Troubleshooting

### Common Issues

- **Permission denied**: Make sure to grant camera permissions when prompted.
- **Black screen**: This could indicate issues with camera initialization. Check the console logs for errors.
- **Slow detection**: Try reducing the frequency of detection updates to improve performance.

## Resources

### Android Resources

- [ML Kit Object Detection for Android (Official Documentation)](https://developers.google.com/ml-kit/vision/object-detection/android)
- [CameraX Documentation](https://developer.android.com/training/camerax)
- [Android ML Kit API Reference](https://developers.google.com/android/reference/com/google/mlkit/vision/objects/ObjectDetector)

### iOS Resources

- [ML Kit Object Detection for iOS (Official Documentation)](https://developers.google.com/ml-kit/vision/object-detection/ios)
- [AVFoundation Documentation](https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture)
- [iOS ML Kit API Reference](https://developers.google.com/ml-kit/reference/ios)

### Flutter Integration Resources

- [Flutter Platform Channels Documentation](https://docs.flutter.dev/platform-integration/platform-channels)
- [Method Channels Documentation](https://api.flutter.dev/flutter/services/MethodChannel-class.html)
- [Platform Views Documentation](https://docs.flutter.dev/platform-integration/platform-views)
- [Flutter Platform Channels Integration Guide](https://docs.flutter.dev/platform-integration/platform-channels?tab=type-mappings-kotlin-tab)

### ML Kit Model Information

- [ML Kit Pre-trained Models Documentation](https://developers.google.com/ml-kit/vision/object-detection/custom-models)
- [Model Specifications](https://developers.google.com/ml-kit/vision/object-detection/android#using-the-default-on-device-model)

### Reference Projects

- [Flutter Body Detection Example](https://github.com/0x48lab/flutter_body_detection)
