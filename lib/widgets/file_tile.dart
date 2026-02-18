import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class FileTile extends StatefulWidget {
  final Map<String, dynamic> file;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final Color accentColor;

  const FileTile({
    super.key,
    required this.file,
    required this.onDelete,
    required this.onRename,
    required this.accentColor,
  });

  @override
  State<FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<FileTile> with SingleTickerProviderStateMixin {
  bool _isDownloading = false;
  double _downloadProgress = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _downloadFile() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final response = await http.get(Uri.parse(widget.file['url']));
      
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          setState(() {
            _downloadProgress = i / 10;
          });
        }
      }

      if (response.statusCode == 200 && mounted) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/${widget.file['name']}');
        await file.writeAsBytes(response.bodyBytes);
        
        setState(() {
          _isDownloading = false;
        });

        _showNotification('Downloaded: ${widget.file['name']}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        _showNotification('Download failed', isError: true);
      }
    }
  }

  void _showNotification(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.download_done_rounded,
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
      case 'avi':
        return Icons.video_library;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_fields;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.blue;
      case 'mp4':
      case 'mov':
        return Colors.purple;
      case 'mp3':
        return Colors.orange;
      case 'doc':
      case 'docx':
        return Colors.teal;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.pink;
      default:
        return widget.accentColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileColor = _getFileColor(widget.file['type']);
    final fileIcon = _getFileIcon(widget.file['type']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _downloadFile,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: fileColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(fileIcon, color: fileColor, size: 24),
                      if (_isDownloading)
                        CircularProgressIndicator(
                          value: _downloadProgress,
                          valueColor: AlwaysStoppedAnimation<Color>(fileColor),
                          strokeWidth: 2,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.file['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: fileColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.file['type'].toUpperCase(),
                              style: TextStyle(
                                color: fileColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.file['size'] ?? 'Unknown',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 0.8 + (_pulseController.value * 0.4),
                            child: Icon(
                              Icons.download_rounded,
                              color: widget.accentColor,
                              size: 14,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.file['downloads'] ?? 0}',
                        style: TextStyle(
                          color: widget.accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                  onPressed: widget.onRename,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}