import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;

// Utility function for consistent log formatting
void _logCamera(String category, String message, {Object? error}) {
  final timestamp = DateTime.now().toIso8601String();
  final errorMsg = error != null ? '\n┗━━ Error: $error' : '';
  print('📸 CAMERA [$timestamp] ($category) $message$errorMsg');
}

final availableCamerasProvider = FutureProvider<List<CameraDescription>>((
  ref,
) async {
  try {
    _logCamera('INIT', 'Searching for available cameras...');
    final cameras = await availableCameras();
    _logCamera('INIT', 'Found ${cameras.length} cameras');
    return cameras;
  } catch (e) {
    _logCamera('ERROR', 'Failed to get available cameras', error: e);
    return [];
  }
});

// Selected camera index provider
final selectedCameraIndexProvider = StateProvider<int>((ref) => 0);

// Camera mode enum to control camera behavior
enum CameraMode { preview, capture }

// Provider to track current camera mode
final cameraModeProvider = StateProvider<CameraMode>(
  (ref) => CameraMode.preview,
);

// Provider for camera controller with square ratio and max resolution
final cameraControllerProvider = FutureProvider.autoDispose((ref) async {
  _logCamera('SETUP', 'Initializing camera controller...');

  final cameras = await ref.watch(availableCamerasProvider.future);
  if (cameras.isEmpty) {
    _logCamera('ERROR', 'No cameras available on device');
    throw Exception('No cameras available');
  }

  // Get the selected camera index
  final selectedIndex = ref.watch(selectedCameraIndexProvider);
  final selectedCamera = cameras[selectedIndex % cameras.length];
  _logCamera('INFO', 'Selected camera: ${selectedCamera.name}');

  // Create controller with max resolution
  final controller = CameraController(
    selectedCamera,
    ResolutionPreset.max,
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.jpeg,
  );

  try {
    _logCamera('INIT', 'Starting camera initialization...');
    await controller.initialize();

    if (!controller.value.isInitialized) {
      _logCamera('ERROR', 'Camera failed to initialize');
      throw Exception('Failed to initialize camera');
    }

    // Get the camera preview size
    final previewSize = controller.value.previewSize!;
    _logCamera(
      'INFO',
      'Preview size: ${previewSize.width}x${previewSize.height}',
    );

    // Calculate zoom level to achieve square ratio
    final screenRatio = previewSize.width / previewSize.height;
    final targetRatio = 1.0; // Square ratio

    if (screenRatio > targetRatio) {
      // Width is larger, zoom in to crop width
      final scale = screenRatio / targetRatio;
      final maxZoom = await controller.getMaxZoomLevel();
      await controller.setZoomLevel(math.min(scale, maxZoom));
    }

    _logCamera('SUCCESS', 'Camera initialized successfully with square ratio');
  } catch (e) {
    _logCamera('ERROR', 'Fatal error during camera initialization', error: e);
    await controller.dispose();
    throw Exception('Failed to initialize camera: $e');
  }

  ref.onDispose(() {
    _logCamera('CLEANUP', 'Disposing camera controller');
    controller.dispose();
  });

  return controller;
});

// Function to take a square photo
Future<XFile?> takeSquarePhoto(CameraController controller) async {
  try {
    _logCamera('CAPTURE', 'Taking square photo...');

    // Take the picture at full resolution
    final XFile photo = await controller.takePicture();
    _logCamera('SUCCESS', 'Photo captured: ${photo.path}');

    return photo;
  } catch (e) {
    _logCamera('ERROR', 'Failed to take photo', error: e);
    return null;
  }
}

// Function to switch camera
Future<void> switchCamera(WidgetRef ref) async {
  _logCamera('SWITCH', 'Switching camera...');

  final cameras = await ref.read(availableCamerasProvider.future);
  if (cameras.length < 2) {
    _logCamera('ERROR', 'No alternative cameras available');
    return;
  }

  final currentIndex = ref.read(selectedCameraIndexProvider);
  ref.read(selectedCameraIndexProvider.notifier).state =
      (currentIndex + 1) % cameras.length;
  _logCamera(
    'SUCCESS',
    'Switched to camera index: ${(currentIndex + 1) % cameras.length}',
  );
}
