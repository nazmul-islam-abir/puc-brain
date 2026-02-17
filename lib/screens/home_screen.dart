import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/github_service.dart';
import '../services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GitHubService _gitHubService = GitHubService();
  final SupabaseService _supabaseService = SupabaseService();
  
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await _supabaseService.getFiles();
      setState(() => _files = files);
    } catch (e) {
      _showSnackBar('Error loading files: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result != null) {
      setState(() => _isUploading = true);
      
      int successCount = 0;
      int failCount = 0;
      
      for (var file in result.files) {
        if (file.path != null) {
          try {
            File uploadFile = File(file.path!);
            String fileName = file.name;
            String fileType = fileName.split('.').last;
            
            // Upload to GitHub
            String? rawUrl = await _gitHubService.uploadFile(uploadFile, fileName);
            
            if (rawUrl != null) {
              // Save to Supabase
              await _supabaseService.insertFileRecord(fileName, rawUrl, fileType);
              successCount++;
            } else {
              failCount++;
            }
          } catch (e) {
            failCount++;
          }
        }
      }
      
      setState(() => _isUploading = false);
      _showSnackBar('Uploaded: $successCount files, Failed: $failCount files');
      _loadFiles(); // Refresh list
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _deleteFile(int id, String url) async {
    try {
      await _supabaseService.deleteFileRecord(id);
      _showSnackBar('File deleted successfully');
      _loadFiles();
    } catch (e) {
      _showSnackBar('Error deleting file: $e');
    }
  }

  void _showEditDialog(int id, String currentName) {
    TextEditingController controller = TextEditingController(text: currentName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit File Name'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await _supabaseService.updateFileRecord(id, controller.text);
                  _showSnackBar('File name updated');
                  _loadFiles();
                  Navigator.pop(context);
                } catch (e) {
                  _showSnackBar('Error updating: $e');
                }
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('File Uploader'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadFiles,
              icon: _isUploading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.upload_file),
              label: Text(_isUploading ? 'Uploading...' : 'Upload Files'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload, size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No files uploaded yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _files.length,
                        itemBuilder: (context, index) {
                          final file = _files[index];
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: Icon(
                                _getFileIcon(file['type']),
                                color: Colors.blue,
                              ),
                              title: Text(
                                file['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'Type: ${file['type']}',
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.green),
                                    onPressed: () => _showEditDialog(
                                      file['id'],
                                      file['name'],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteFile(
                                      file['id'],
                                      file['url'],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => _showFileOptions(file),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'mov':
        return Icons.video_library;
      case 'mp3':
        return Icons.audio_file;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  void _showFileOptions(Map<String, dynamic> file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: Icon(Icons.open_in_browser),
            title: Text('Open in Browser'),
            onTap: () {
              Navigator.pop(context);
              _openFile(file['url']);
            },
          ),
          ListTile(
            leading: Icon(Icons.share),
            title: Text('Copy Link'),
            onTap: () {
              Navigator.pop(context);
              _copyLink(file['url']);
            },
          ),
        ],
      ),
    );
  }

  void _openFile(String url) {
    // You can use url_launcher package to open in browser
    _showSnackBar('Opening: $url');
  }

  void _copyLink(String url) {
    // You can use clipboard package to copy
    _showSnackBar('Link copied to clipboard');
  }
}