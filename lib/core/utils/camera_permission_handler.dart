import 'package:permission_handler/permission_handler.dart';

class CameraPermissionHandler {
  static Future<bool> hasPermission() async {
    return await Permission.camera.isGranted;
  }

  static Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}