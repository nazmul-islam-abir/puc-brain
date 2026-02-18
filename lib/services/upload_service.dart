import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UploadTask {
  final String id;
  final String fileName;
  final double progress;
  final UploadStatus status;
  final String? error;
  final int? folderId;

  UploadTask({
    required this.id,
    required this.fileName,
    this.progress = 0,
    this.status = UploadStatus.pending,
    this.error,
    this.folderId,
  });

  UploadTask copyWith({
    String? id,
    String? fileName,
    double? progress,
    UploadStatus? status,
    String? error,
    int? folderId,
  }) {
    return UploadTask(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      error: error ?? this.error,
      folderId: folderId ?? this.folderId,
    );
  }
}

enum UploadStatus { pending, uploading, completed, failed }

class CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}

class UploadService extends ChangeNotifier {
  final String token = dotenv.env['GITHUB_TOKEN'] ?? '';
  final String owner = dotenv.env['GITHUB_OWNER'] ?? '';
  final String repo = dotenv.env['GITHUB_REPO'] ?? '';
  final String branch = dotenv.env['GITHUB_BRANCH'] ?? 'main';

  final List<UploadTask> _tasks = [];
  final Map<String, CancelToken> _cancelTokens = {};

  List<UploadTask> get tasks => List.unmodifiable(_tasks);
  int get pendingCount => _tasks.where((t) => t.status == UploadStatus.pending || t.status == UploadStatus.uploading).length;
  int get completedCount => _tasks.where((t) => t.status == UploadStatus.completed).length;
  int get failedCount => _tasks.where((t) => t.status == UploadStatus.failed).length;

  bool get hasGitHubCredentials {
    return token.isNotEmpty && owner.isNotEmpty && repo.isNotEmpty;
  }

  Future<String?> uploadFile(File file, String fileName, int folderId) async {
    print('GitHub Token: $token');
    print('GitHub Owner: $owner');
    print('GitHub Repo: $repo');
    print('GitHub Branch: $branch');

    if (!hasGitHubCredentials) {
      _addTaskWithError(fileName, folderId, 'GitHub credentials not configured');
      return null;
    }

    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    _addTask(fileName, folderId, id: taskId);
    notifyListeners();

    try {
      _updateTask(taskId, status: UploadStatus.uploading, progress: 0.1);

      // Read file as bytes
      List<int> fileBytes = await file.readAsBytes();
      String base64File = base64Encode(fileBytes);

      _updateTask(taskId, progress: 0.3);

      String path = 'uploads/$fileName';
      String url = 'https://api.github.com/repos/$owner/$repo/contents/$path';

      // Check if file exists
      var getResponse = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      print('Get Response Status Code: ${getResponse.statusCode}');
      print('Get Response Body: ${getResponse.body}');

      if (cancelToken.isCancelled) throw 'Upload cancelled';

      _updateTask(taskId, progress: 0.5);

      String sha = '';
      if (getResponse.statusCode == 200) {
        var jsonResponse = jsonDecode(getResponse.body);
        sha = jsonResponse['sha'];
      }

      _updateTask(taskId, progress: 0.7);

      // Create or update file
      var response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'token $token',
          'Content-Type': 'application/json',
          'Accept': 'application/vnd.github.v3+json',
        },
        body: jsonEncode({
          'message': 'Upload $fileName',
          'content': base64File,
          'branch': branch,
          if (sha.isNotEmpty) 'sha': sha,
        }),
      );

      print('Put Response Status Code: ${response.statusCode}');
      print('Put Response Body: ${response.body}');

      if (cancelToken.isCancelled) throw 'Upload cancelled';

      _updateTask(taskId, progress: 0.9);

      if (response.statusCode == 200 || response.statusCode == 201) {
        String rawUrl = 'https://raw.githubusercontent.com/$owner/$repo/$branch/$path';
        _updateTask(taskId, status: UploadStatus.completed, progress: 1.0);
        return rawUrl;
      } else {
        throw 'Upload failed: ${response.statusCode}';
      }
    } catch (e) {
      print('Error: $e');
      if (e == 'Upload cancelled') {
        _updateTask(taskId, status: UploadStatus.failed, error: 'Cancelled');
      } else {
        _updateTask(taskId, status: UploadStatus.failed, error: e.toString());
      }
      return null;
    } finally {
      _cancelTokens.remove(taskId);
    }
  }

  void _addTask(String fileName, int folderId, {String? id}) {
    _tasks.add(UploadTask(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      status: UploadStatus.pending,
      folderId: folderId,
    ));
  }

  void _addTaskWithError(String fileName, int folderId, String errorMessage) {
    _tasks.add(UploadTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      status: UploadStatus.failed,
      error: errorMessage,
      folderId: folderId,
    ));
    notifyListeners();
  }

  void _updateTask(String id, {UploadStatus? status, double? progress, String? error}) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        status: status,
        progress: progress,
        error: error,
      );
      notifyListeners();
    }
  }

  void cancelUpload(String taskId) {
    _cancelTokens[taskId]?.cancel();
    _updateTask(taskId, status: UploadStatus.failed, error: 'Cancelled');
    _cancelTokens.remove(taskId);
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == UploadStatus.completed);
    notifyListeners();
  }

  void retryTask(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    if (task.status == UploadStatus.failed && task.folderId != null) {
      _tasks.remove(task);
      // The UI will trigger re-upload
    }
  }

  @override
  void dispose() {
    for (var token in _cancelTokens.values) {
      token.cancel();
    }
    super.dispose();
  }
}