import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../services/upload_service.dart';
import '../services/download_service.dart'; // Import DownloadService
import 'package:path/path.dart' as path;

class FilesScreen extends StatefulWidget {
  final String courseName;
  final String semesterName;
  final String? section;
  final int semesterId;

  const FilesScreen({super.key, 
    required this.courseName,
    required this.semesterName,
    this.section,
    required this.semesterId,
  });

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final DownloadService _downloadService = DownloadService(); // Instantiate DownloadService
  
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _files = await _supabaseService.getFiles(widget.semesterId);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading files: $e', isError: true);
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _uploadFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null) {
      if (!mounted) return;
      setState(() => _isUploading = true);
      
      int success = 0;
      int failed = 0;
      
      final uploadService = Provider.of<UploadService>(context, listen: false);
      
      for (var file in result.files) {
        if (file.path != null) {
          try {
            File uploadFile = File(file.path!);
            String fileName = file.name;
            String fileType = path.extension(fileName).replaceAll('.', '').toLowerCase();
            if (fileType.isEmpty) fileType = 'unknown';
            
            String fileSize = _formatBytes(file.size);
            
            // Upload to GitHub - passing folderId (semesterId) as third parameter
            String? rawUrl = await uploadService.uploadFile(uploadFile, fileName, widget.semesterId);
            
            if (rawUrl != null) {
              // Save to Supabase with semester_id
              await _supabaseService.addFile(
                widget.semesterId,
                fileName,
                rawUrl,
                fileType,
                fileSize,
              );
              success++;
            } else {
              failed++;
            }
          } catch (e) {
            print('Upload error: $e');
            failed++;
          }
        }
      }
      
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnackBar('Uploaded: $success files, Failed: $failed files');
        _loadFiles();
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _deleteFile(int id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: const Text('Are you sure you want to delete this file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await _supabaseService.deleteFile(id);
        if (mounted) {
          _loadFiles();
          _showSnackBar('File deleted successfully');
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error deleting file: $e', isError: true);
        }
      }
    }
  }

  void _showEditDialog(int id, String currentName) {
    TextEditingController controller = TextEditingController(text: currentName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit File Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await _supabaseService.updateFileName(id, controller.text);
                  if (mounted) {
                    Navigator.pop(context);
                    _loadFiles();
                    _showSnackBar('File renamed successfully');
                  }
                } catch (e) {
                  if (mounted) {
                    _showSnackBar('Error renaming file: $e', isError: true);
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        _showSnackBar('Could not launch $url: $e', isError: true);
      }
    } else {
      _showSnackBar('Could not launch $url', isError: true);
    }
  }

  // Method to handle file download
  Future<void> _downloadFile(String url, String fileName) async {
    await _downloadService.downloadFile(
      url: url,
      fileName: fileName,
      onStarted: (message) => _showSnackBar(message),
      onSuccess: (message) => _showSnackBar(message),
      onError: (title, message) => _showSnackBar('$title: $message', isError: true),
    );
  }

  IconData _getFileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'jpg': case 'jpeg': case 'png': case 'gif': return Icons.image;
      case 'mp4': case 'mov': case 'avi': return Icons.video_library;
      case 'mp3': case 'wav': return Icons.audio_file;
      case 'doc': case 'docx': return Icons.description;
      case 'xls': case 'xlsx': return Icons.table_chart;
      case 'ppt': case 'pptx': return Icons.slideshow;
      case 'txt': return Icons.text_fields;
      default: return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.courseName),
            Text(
              '${widget.semesterName} ${widget.section != null ? '- ${widget.section}' : ''}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Files', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${_files.length} files total'),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadFiles,
                  icon: _isUploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file),
                  label: Text(_isUploading ? 'Uploading...' : 'Upload'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload, size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text('No files uploaded', style: TextStyle(fontSize: 18)),
                            const SizedBox(height: 8),
                            const Text('Tap upload to add files'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _files.length,
                        itemBuilder: (context, index) {
                          final file = _files[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(_getFileIcon(file['type']), color: Colors.blue, size: 32),
                              title: Text(file['name'], maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${file['type']} • ${file['size'] ?? 'Unknown size'}'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'open') {
                                    _openFile(file['url']);
                                  } else if (value == 'download') {
                                    _downloadFile(file['url'], file['name']);
                                  } else if (value == 'edit') {
                                    _showEditDialog(file['id'], file['name']);
                                  } else if (value == 'delete') {
                                    _deleteFile(file['id']);
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'open',
                                    child: ListTile(leading: Icon(Icons.open_in_new), title: Text('Open')),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'download',
                                    child: ListTile(leading: Icon(Icons.download), title: Text('Download')),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: ListTile(leading: Icon(Icons.edit), title: Text('Rename')),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete')),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}