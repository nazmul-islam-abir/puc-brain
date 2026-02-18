import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GitHubService {
  final String token = dotenv.env['GITHUB_TOKEN'] ?? '';
  final String owner = dotenv.env['GITHUB_OWNER'] ?? '';
  final String repo = dotenv.env['GITHUB_REPO'] ?? '';
  final String branch = dotenv.env['GITHUB_BRANCH'] ?? 'main';

  Future<String?> uploadFile(File file, String fileName) async {
    try {
      if (token.isEmpty || owner.isEmpty || repo.isEmpty) {
        print('GitHub credentials missing');
        return null;
      }

      List<int> fileBytes = await file.readAsBytes();
      String base64File = base64Encode(fileBytes);
      String path = 'uploads/$fileName';
      String url = 'https://api.github.com/repos/$owner/$repo/contents/$path';

      var getResponse = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      String sha = '';
      if (getResponse.statusCode == 200) {
        sha = jsonDecode(getResponse.body)['sha'];
      }

      var response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'token $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': 'Upload $fileName',
          'content': base64File,
          'branch': branch,
          if (sha.isNotEmpty) 'sha': sha,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return 'https://raw.githubusercontent.com/$owner/$repo/$branch/$path';
      }
      return null;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }
}