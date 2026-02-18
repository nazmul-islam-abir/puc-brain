
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class DownloadService {
  final Dio _dio = Dio();

  // Requests storage permission.
  Future<bool> _requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    // Permissions are not required for web or iOS downloads in this manner.
    return true;
  }

  // Gets the appropriate download directory.
  Future<String?> _getDownloadDirectory() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return '/storage/emulated/0/Download'; // Standard public downloads folder
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return (await getApplicationDocumentsDirectory()).path;
    }
    // Web downloads are handled by the browser, no specific path needed.
    return null;
  }

  // The core download method.
  Future<void> downloadFile({
    required String url,
    required String fileName,
    required Function(String) onStarted,
    required Function(String) onSuccess,
    required Function(String, String) onError,
  }) async {
    if (kIsWeb) {
      // On web, we can just open the URL and the browser will handle the download.
      // This is simpler and more reliable than trying to save it via code.
      // We can use the url_launcher for this, which is already in the project.
      // However, to keep this service self-contained, I will implement this later
      // in the UI layer where I have access to url_launcher.
      // For now, I will show an error.
      onError("Not Supported", "Downloads are not yet configured for the web.");
      return;
    }

    final hasPermission = await _requestPermission();
    if (!hasPermission) {
      onError('Permission Denied', 'Storage permission is required to download files.');
      return;
    }

    final directory = await _getDownloadDirectory();
    if (directory == null) {
      onError('Error', 'Could not determine the download directory.');
      return;
    }

    final savePath = '$directory/$fileName';
    onStarted('Download started...');

    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          // Progress can be handled here in the future.
        },
      );
      onSuccess('File saved to your Downloads folder!');
    } on DioException catch (e) {
      debugPrint("Dio download error: $e");
      onError('Download Failed', 'Could not fetch the file. Check your connection.');
    } catch (e) {
      debugPrint("General download error: $e");
      onError('An Error Occurred', 'Could not save the file.');
    }
  }
}
