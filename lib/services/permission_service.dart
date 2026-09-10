import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // =========================================================
  // REQUEST MICROPHONE PERMISSION
  // =========================================================

  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();

    return status.isGranted;
  }

  // =========================================================
  // REQUEST CAMERA PERMISSION
  // =========================================================

  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();

    return status.isGranted;
  }

  // =========================================================
  // REQUEST AUDIO + VIDEO PERMISSIONS
  // =========================================================

  static Future<bool> requestCallPermissions({
    required bool isVideoCall,
  }) async {
    final microphoneStatus =
        await Permission.microphone.request();

    if (!microphoneStatus.isGranted) {
      return false;
    }

    if (isVideoCall) {
      final cameraStatus =
          await Permission.camera.request();

      if (!cameraStatus.isGranted) {
        return false;
      }
    }

    return true;
  }

  // =========================================================
  // OPEN APP SETTINGS
  // =========================================================

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}