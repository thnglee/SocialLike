import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:camera/camera.dart';

// Provider to track detailed permission state
enum CameraPermissionState {
  notDetermined,
  granted,
  denied,
  restricted,
  permanentlyDenied,
}

final cameraPermissionStateProvider =
    StateNotifierProvider<CameraPermissionNotifier, CameraPermissionState>(
      (ref) => CameraPermissionNotifier(),
    );

// Compatibility provider for existing code
final cameraPermissionProvider =
    StateNotifierProvider<CameraPermissionCompatNotifier, PermissionStatus>(
      (ref) => CameraPermissionCompatNotifier(ref),
    );

class CameraPermissionCompatNotifier extends StateNotifier<PermissionStatus> {
  final Ref _ref;

  CameraPermissionCompatNotifier(this._ref) : super(PermissionStatus.denied) {
    // Update state when detailed permission state changes
    _ref.listen(cameraPermissionStateProvider, (previous, next) {
      state = _mapToPermissionStatus(next);
    });
  }

  PermissionStatus _mapToPermissionStatus(CameraPermissionState state) {
    switch (state) {
      case CameraPermissionState.granted:
        return PermissionStatus.granted;
      case CameraPermissionState.permanentlyDenied:
        return PermissionStatus.permanentlyDenied;
      case CameraPermissionState.restricted:
        return PermissionStatus.restricted;
      case CameraPermissionState.denied:
        return PermissionStatus.denied;
      case CameraPermissionState.notDetermined:
        return PermissionStatus.denied;
    }
  }

  Future<bool> requestPermission() async {
    final result =
        await _ref
            .read(cameraPermissionStateProvider.notifier)
            .requestPermission();
    return result == CameraPermissionState.granted;
  }
}

class CameraPermissionNotifier extends StateNotifier<CameraPermissionState> {
  CameraPermissionNotifier() : super(CameraPermissionState.notDetermined) {
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      if (Platform.isIOS) {
        // On iOS, we first check if cameras are available
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          state = CameraPermissionState.restricted;
          return;
        }
      }

      final status = await Permission.camera.status;
      state = _mapPermissionStatus(status);
    } catch (e) {
      print('Error checking camera permission: $e');
      state = CameraPermissionState.restricted;
    }
  }

  CameraPermissionState _mapPermissionStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return CameraPermissionState.granted;
      case PermissionStatus.denied:
        return CameraPermissionState.denied;
      case PermissionStatus.restricted:
        return CameraPermissionState.restricted;
      case PermissionStatus.limited:
        return CameraPermissionState.granted; // Treat limited as granted
      case PermissionStatus.permanentlyDenied:
        return CameraPermissionState.permanentlyDenied;
      case PermissionStatus.provisional:
        return CameraPermissionState.notDetermined;
    }
  }

  Future<CameraPermissionState> requestPermission() async {
    try {
      if (Platform.isIOS) {
        // For iOS, we need to ensure cameras are available first
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          state = CameraPermissionState.restricted;
          return state;
        }
      }

      // If already granted, return current state
      if (state == CameraPermissionState.granted) {
        return state;
      }

      // If permanently denied on iOS, direct to settings
      if (Platform.isIOS && state == CameraPermissionState.permanentlyDenied) {
        await openAppSettings();
        return state;
      }

      // Request permission
      final status = await Permission.camera.request();

      // On iOS, a denial means permanent denial
      if (Platform.isIOS && status.isDenied) {
        state = CameraPermissionState.permanentlyDenied;
      } else {
        state = _mapPermissionStatus(status);
      }

      return state;
    } catch (e) {
      print('Error requesting camera permission: $e');
      state = CameraPermissionState.restricted;
      return state;
    }
  }
}
