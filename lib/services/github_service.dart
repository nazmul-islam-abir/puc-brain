import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class GitHubService {
  final String token = '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';
  final String owner = 'nazmul-islam-abir';
  final String repo = 'varsityBank';
  final String branch = 'main'; // or your default branch

  Future<String?> uploadFile(File file, String fileName) async {
    try {
      // Read file as base64
      List<int> fileBytes = await file.readAsBytes();
      String base64File = base64Encode(fileBytes);

      // Create path in repo
      String path = 'uploads/$fileName';

      // GitHub API URL
      String url = 'https://api.github.com/repos/$owner/$repo/contents/$path';

      // Check if file exists
      var getResponse = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      String sha;
      if (getResponse.statusCode == 200) {
        // File exists, get its SHA
        var jsonResponse = jsonDecode(getResponse.body);
        sha = jsonResponse['sha'];
      } else {
        sha = '';
      }

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

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Get the raw URL
        String rawUrl =
            'https://raw.githubusercontent.com/$owner/$repo/$branch/$path';
        return rawUrl;
      } else {
        print('Upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading: $e');
      return null;
    }
  }
}
