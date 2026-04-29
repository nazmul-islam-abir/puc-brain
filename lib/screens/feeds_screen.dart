import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:myapp/services/supabase_service.dart';
import 'package:myapp/services/upload_service.dart';
import 'package:myapp/widgets/animated_background.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedsScreen extends StatefulWidget {
  final UserRole userRole;
  const FeedsScreen({super.key, required this.userRole});

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  late final Stream<List<Map<String, dynamic>>> _postsStream;
  String? _currentUserId;
  String? _currentUsername;
  late Future<void> _initFuture;
  
  // For post creation
  final TextEditingController _postController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final List<PlatformFile> _selectedFiles = [];
  bool _isCreatingPost = false;
  bool _showCreatePost = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _initFeeds();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _initFeeds() async {
    _currentUserId = await _supabaseService.getCurrentUserId();
    _currentUsername = await _supabaseService.getUsername();
    _postsStream = _supabaseService.getPosts();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result != null) {
      setState(() {
        _selectedFiles.addAll(result.files);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty && 
        _selectedImages.isEmpty && 
        _selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some content to your post')),
      );
      return;
    }

    setState(() => _isCreatingPost = true);

    try {
      final uploadService = Provider.of<UploadService>(context, listen: false);
      
      // Upload images if any
      List<String> imageUrls = [];
      for (var image in _selectedImages) {
        if (image.path.isNotEmpty) {
          final File file = File(image.path);
          final fileName = 'post_image_${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
          final url = await uploadService.uploadFile(file, fileName, 0); // folderId 0 for posts
          if (url != null) {
            imageUrls.add(url);
          }
        }
      }

      // Upload files if any
      List<Map<String, String>> fileAttachments = [];
      for (var file in _selectedFiles) {
        if (file.path != null) {
          final File uploadFile = File(file.path!);
          final fileName = 'post_file_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          final url = await uploadService.uploadFile(uploadFile, fileName, 0);
          if (url != null) {
            fileAttachments.add({
              'name': file.name,
              'url': url,
              'type': path.extension(file.name).replaceAll('.', ''),
              'size': _formatBytes(file.size),
            });
          }
        }
      }

      // Create post with attachments
      final Map<String, dynamic> postContent = {
        'text': _postController.text.trim(),
      };
      
      if (imageUrls.isNotEmpty) {
        postContent['images'] = imageUrls;
      }
      
      if (fileAttachments.isNotEmpty) {
        postContent['files'] = fileAttachments;
      }

      await _supabaseService.addPost(postContent);

      // Clear form
      setState(() {
        _postController.clear();
        _selectedImages.clear();
        _selectedFiles.clear();
        _showCreatePost = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating post: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isCreatingPost = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _deletePost(int postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C2E),
        title: const Text('Delete Post', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this post?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabaseService.deletePost(postId);
    }
  }

  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat.yMMMd().format(dateTime);
      }
    } catch (e) {
      return '';
    }
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
      case 'zip': case 'rar': return Icons.folder_zip;
      default: return Icons.insert_drive_file;
    }
  }

  // Helper method to safely parse post content
  Map<String, dynamic> _parsePostContent(dynamic content) {
    if (content == null) return {'text': ''};
    
    // If it's already a Map, return it
    if (content is Map<String, dynamic>) {
      return content;
    }
    
    // If it's a String, try to parse as JSON
    if (content is String) {
      try {
        // Check if it looks like JSON
        final trimmed = content.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          final parsed = jsonDecode(content);
          if (parsed is Map<String, dynamic>) {
            return parsed;
          }
        }
      } catch (e) {
        // Not valid JSON, treat as plain text
        print('Error parsing post content: $e');
      }
      
      // Plain text post
      return {'text': content};
    }
    
    return {'text': ''};
  }

  @override
  Widget build(BuildContext context) {
    bool isAlumni = widget.userRole == UserRole.alumni;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return AnimatedBackground(
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: 60,
                  floating: true,
                  backgroundColor: Colors.transparent,
                  title: const Text(
                    'Feeds',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  actions: [
                    if (isAlumni)
                      IconButton(
                        icon: Icon(
                          _showCreatePost ? Icons.close : Icons.add_circle,
                          color: const Color(0xFF7C5CBF),
                        ),
                        onPressed: () {
                          setState(() {
                            _showCreatePost = !_showCreatePost;
                            if (!_showCreatePost) {
                              _postController.clear();
                              _selectedImages.clear();
                              _selectedFiles.clear();
                            }
                          });
                        },
                      ),
                  ],
                ),

                // Create Post Section
                if (_showCreatePost && isAlumni)
                  SliverToBoxAdapter(
                    child: _buildCreatePost(),
                  ),

                // Posts Stream
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _postsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return SliverFillRemaining(
                        child: Center(child: Text('Error: ${snapshot.error}')),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C5CBF).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.feed_outlined,
                                  size: 40,
                                  color: Color(0xFF7C5CBF),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No posts yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isAlumni
                                    ? 'Create the first post!'
                                    : 'Check back later for updates',
                                style: const TextStyle(color: Color(0xFF7A7A9A)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final posts = snapshot.data!;
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final post = posts[index];
                          final isOwner = post['user_id'] == _currentUserId;
                          final parsedContent = _parsePostContent(post['content']);
                          
                          return _buildPostCard(post, parsedContent, isOwner, isAlumni);
                        },
                        childCount: posts.length,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreatePost() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1928),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2840)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C5CBF), Color(0xFF4F8EF7)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _currentUsername?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _postController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "What's on your mind?",
                    hintStyle: const TextStyle(color: Color(0xFF7A7A9A)),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),

          // Selected images preview
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(File(_selectedImages[index].path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],

          // Selected files preview
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._selectedFiles.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF252538),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getFileIcon(path.extension(file.name).replaceAll('.', '')),
                      color: const Color(0xFF7C5CBF),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatBytes(file.size),
                            style: const TextStyle(color: Color(0xFF7A7A9A), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeFile(index),
                      child: const Icon(Icons.close, color: Colors.red, size: 18),
                    ),
                  ],
                ),
              );
            }),
          ],

          const Divider(color: Color(0xFF2A2840)),

          // Action buttons
          Row(
            children: [
              _buildActionButton(
                icon: Icons.image,
                label: 'Photo',
                color: Colors.green,
                onTap: _pickImages,
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.attach_file,
                label: 'File',
                color: Colors.blue,
                onTap: _pickFiles,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isCreatingPost ? null : _createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5CBF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isCreatingPost
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Post'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(
    Map<String, dynamic> post,
    Map<String, dynamic> parsedContent,
    bool isOwner,
    bool isAlumni,
  ) {
    final username = post['username'] ?? 'Unknown User';
    final userInitial = username.toString().isNotEmpty 
        ? username[0].toUpperCase() 
        : '?';
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1928),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2840)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // User avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C5CBF), Color(0xFF4F8EF7)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      userInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(post['created_at']),
                        style: const TextStyle(
                          color: Color(0xFF7A7A9A),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Options menu for owner
                if (isOwner && isAlumni)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Color(0xFF7A7A9A)),
                    color: const Color(0xFF252538),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deletePost(post['id']);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Post text content
          if (parsedContent.containsKey('text') && parsedContent['text'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                parsedContent['text'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),

          // Images grid
          if (parsedContent.containsKey('images') && (parsedContent['images'] as List?)?.isNotEmpty == true)
            _buildImageGrid(parsedContent['images'] as List),

          // File attachments
          if (parsedContent.containsKey('files') && (parsedContent['files'] as List?)?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attachments',
                    style: TextStyle(
                      color: Color(0xFF7A7A9A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(parsedContent['files'] as List).map((file) => _buildFileAttachment(file)),
                ],
              ),
            ),

          // Post actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildPostAction(
                  icon: Icons.favorite_border,
                  label: 'Like',
                  onTap: () {},
                ),
                const SizedBox(width: 20),
                _buildPostAction(
                  icon: Icons.chat_bubble_outline,
                  label: 'Comment',
                  onTap: () {},
                ),
                const Spacer(),
                _buildPostAction(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // In _FeedsScreenState class, replace the _buildImageGrid method:

Widget _buildImageGrid(dynamic imagesData) {
  // Convert to List<String> safely
  List<String> imageUrls = [];
  
  if (imagesData is List) {
    imageUrls = imagesData.map((item) {
      if (item is String) {
        return item;
      }
      return item.toString(); // Convert to string if it's not already
    }).toList();
  }
  
  if (imageUrls.isEmpty) return const SizedBox.shrink();
  
  int imageCount = imageUrls.length;
  
  if (imageCount == 1) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrls[0],
          fit: BoxFit.cover,
          height: 250,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 250,
              color: Colors.grey.shade800,
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
              ),
            );
          },
        ),
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: imageCount > 2 ? 2 : imageCount,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: imageCount > 4 ? 4 : imageCount,
      itemBuilder: (context, index) {
        if (index == 3 && imageCount > 4) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrls[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade800,
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black.withOpacity(0.5),
                ),
                child: Center(
                  child: Text(
                    '+${imageCount - 3}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrls[index],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade800,
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

  Widget _buildFileAttachment(Map<String, dynamic> file) {
    return GestureDetector(
      onTap: () async {
        final url = file['url'];
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF252538),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              _getFileIcon(file['type']),
              color: const Color(0xFF7C5CBF),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file['name'],
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    file['size'] ?? 'Unknown size',
                    style: const TextStyle(color: Color(0xFF7A7A9A), fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.download, color: Color(0xFF7C5CBF), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPostAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF7A7A9A), size: 18),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF7A7A9A), fontSize: 12),
          ),
        ],
      ),
    );
  }
}