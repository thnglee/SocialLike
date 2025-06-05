import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  static Future<Map<Permission, bool>> requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses =
        await [
          Permission.camera,
          Permission.notification,
          Permission.location,
        ].request();

    return statuses.map(
      (permission, status) => MapEntry(permission, status.isGranted),
    );
  }

  static Future<bool> checkCameraPermission() async {
    return await Permission.camera.status.isGranted;
  }

  static Future<bool> checkNotificationPermission() async {
    return await Permission.notification.status.isGranted;
  }

  static Future<bool> checkLocationPermission() async {
    return await Permission.location.status.isGranted;
  }

  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
