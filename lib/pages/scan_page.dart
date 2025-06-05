import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/permission_provider.dart';
import '../providers/camera_provider.dart';
import '../services/post_service.dart';
import '../services/location_service.dart';
import '../widgets/loading_overlay.dart';
import 'dart:io';
import '../pages/main_layout.dart';

// Provider to access PageController globally
final pageControllerProvider = Provider<PageController>((ref) {
  throw UnimplementedError('PageController must be set by MainLayout');
});

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  XFile? _imageFile;
  bool _isPreviewMode = false;
  bool _isSwitchingCamera = false;
  bool _isCreatingPost = false;
  final _postService = PostService();

  Future<void> _takePicture() async {
    final cameraController = ref.read(cameraControllerProvider).value;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    try {
      final XFile? image = await takeSquarePhoto(cameraController);
      if (image != null && mounted) {
        setState(() {
          _imageFile = image;
          _isPreviewMode = true;
        });
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _createPost() async {
    if (_imageFile == null || _isCreatingPost) return;

    setState(() {
      _isCreatingPost = true;
    });

    try {
      // Get location data first
      final locationData = await LocationService.getLocationData();

      // Create post
      final success = await _postService.createPost(_imageFile!.path);

      if (mounted) {
        if (success) {
          // Show success message with location if available
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                locationData != null
                    ? 'Posted successfully from ${locationData['address']}'
                    : 'Posted successfully',
              ),
              duration: const Duration(seconds: 2),
            ),
          );

          // Reset state and navigate
          setState(() {
            _imageFile = null;
            _isPreviewMode = false;
          });

          // Navigate to feed
          ref.read(currentPageProvider.notifier).state = 1;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create post'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingPost = false;
        });
      }
    }
  }

  void _retakePicture() {
    setState(() {
      _imageFile = null;
      _isPreviewMode = false;
    });
  }

  Future<void> _handleCameraSwitch() async {
    if (_isSwitchingCamera) return;

    setState(() {
      _isSwitchingCamera = true;
    });

    try {
      await switchCamera(ref);
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
      }
    }
  }

  Widget _buildPermissionDeniedWidget() {
    final permissionStatus = ref.watch(cameraPermissionProvider);
    final bool isPermanentlyDenied = permissionStatus.isPermanentlyDenied;
    final bool isFirstRequest = permissionStatus == PermissionStatus.denied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermanentlyDenied ? Icons.no_photography : Icons.camera_alt,
              size: 64,
              color: isPermanentlyDenied ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              isPermanentlyDenied
                  ? 'Camera Access Required'
                  : isFirstRequest
                  ? 'Camera Permission'
                  : 'Camera Permission Required',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              isPermanentlyDenied
                  ? 'Please enable camera access in your device settings to use this feature.'
                  : isFirstRequest
                  ? 'This app needs access to your camera to take photos.'
                  : 'Please grant camera permission to use this feature.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            if (!isPermanentlyDenied)
              ElevatedButton.icon(
                onPressed: () async {
                  final granted =
                      await ref
                          .read(cameraPermissionProvider.notifier)
                          .requestPermission();
                  if (!granted && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Camera permission is required'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  isFirstRequest ? 'Allow Camera Access' : 'Grant Permission',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            if (isPermanentlyDenied)
              ElevatedButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Consumer(
      builder: (context, ref, child) {
        final cameraAsync = ref.watch(cameraControllerProvider);
        final cameras = ref.watch(availableCamerasProvider).value ?? [];

        return cameraAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (controller) {
            if (!controller.value.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }

            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Container(
                        color: Colors.black,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.center,
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: controller.value.previewSize!.height,
                                    height: controller.value.previewSize!.width,
                                    child: CameraPreview(controller),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      color: Colors.black,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (cameras.length > 1)
                            FloatingActionButton(
                              heroTag: 'switchCamera',
                              onPressed:
                                  _isSwitchingCamera
                                      ? null
                                      : _handleCameraSwitch,
                              backgroundColor: Colors.white54,
                              child:
                                  _isSwitchingCamera
                                      ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                      : const Icon(
                                        Icons.flip_camera_ios,
                                        color: Colors.black,
                                      ),
                            ),
                          FloatingActionButton(
                            heroTag: 'takePicture',
                            onPressed: _takePicture,
                            backgroundColor: Colors.white,
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.black,
                            ),
                          ),
                          if (cameras.length > 1) const SizedBox(width: 56),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildImagePreview() {
    if (_imageFile == null) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        Center(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Image.file(File(_imageFile!.path), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'retake',
                onPressed: _retakePicture,
                backgroundColor: Colors.red,
                child: const Icon(Icons.refresh),
              ),
              FloatingActionButton(
                heroTag: 'confirm',
                onPressed: _isCreatingPost ? null : _createPost,
                backgroundColor: Colors.green,
                child: const Icon(Icons.check),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissionStatus = ref.watch(cameraPermissionProvider);

    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isCreatingPost,
        message: 'Creating post...',
        child: Container(
          color: Colors.black,
          child: SafeArea(
            child:
                permissionStatus.isGranted
                    ? _isPreviewMode
                        ? _buildImagePreview()
                        : _buildCameraPreview()
                    : _buildPermissionDeniedWidget(),
          ),
        ),
      ),
    );
  }
}
