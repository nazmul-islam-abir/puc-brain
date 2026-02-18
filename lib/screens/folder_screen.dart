import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../services/upload_service.dart';
import '../services/download_service.dart'; // Import DownloadService
import 'package:path/path.dart' as path;

class FolderScreen extends StatefulWidget {
  final int courseId;
  final String courseName;
  final Color courseColor;
  final int? parentFolderId;
  final String? currentFolderName;

  const FolderScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.courseColor,
    this.parentFolderId,
    this.currentFolderName,
  });

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final DownloadService _downloadService = DownloadService(); // Instantiate DownloadService

  List<Map<String, dynamic>> _folders = [];
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = true;
  Map<String, dynamic>? _currentFolder;

  // ─── Theme ────────────────────────────────────────────────────────────────
  static const Color _bg        = Color(0xFF0A0A14);
  static const Color _surface   = Color(0xFF13121F);
  static const Color _card      = Color(0xFF1A1928);
  static const Color _border    = Color(0xFF2A2840);
  static const Color _textPri   = Color(0xFFF0EFFF);
  static const Color _textSec   = Color(0xFF7A7A9A);
  static const Color _textMuted = Color(0xFF4A4A6A);

  Color get _accent => widget.courseColor;
  Color get _accentDim => widget.courseColor.withOpacity(0.15);
  Color get _accentBorder => widget.courseColor.withOpacity(0.3);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (widget.parentFolderId != null) {
        _currentFolder = await _supabaseService.getFolder(widget.parentFolderId!);
        _folders = await _supabaseService.getSubFolders(widget.parentFolderId!);
        _files = await _supabaseService.getFiles(widget.parentFolderId!);
      } else {
        _folders = await _supabaseService.getRootFolders(widget.courseId);
        _files = [];
      }
    } catch (e) {
      _snack('Error loading data', isError: true);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _openFile(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        _snack('Could not launch $url: $e', isError: true);
      }
    } else {
      _snack('Could not launch $url', isError: true);
    }
  }

  // Method to handle file download
  Future<void> _downloadFile(String url, String fileName) async {
    await _downloadService.downloadFile(
      url: url,
      fileName: fileName,
      onStarted: (message) => _snack(message),
      onSuccess: (message) => _snack(message),
      onError: (title, message) => _snack('$title: $message', isError: true),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: isError ? const Color(0xFFCF4A5A) : const Color(0xFF3A8A5A),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── Upload Fix ───────────────────────────────────────────────────────────
  // BUG FIX: Original code blocked uploads when parentFolderId == null.
  // Now we allow uploads only inside folders (parentFolderId != null),
  // but show a clear message at root level prompting user to open a folder first.
  Future<void> _uploadFiles() async {
    if (widget.parentFolderId == null) {
      _snack('Open a folder first to upload files', isError: true);
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return;
      if (!mounted) return;

      final uploadService = Provider.of<UploadService>(context, listen: false);
      int success = 0, failed = 0;

      for (final file in result.files) {
        if (file.path == null) { failed++; continue; }
        try {
          final uploadFile = File(file.path!);
          final fileName  = file.name;
          final fileType  = path.extension(fileName).replaceAll('.', '').toLowerCase().ifEmpty('file');
          final fileSize  = _fmtBytes(file.size);

          // Upload to GitHub via UploadService (tracks progress in upload screen)
          final rawUrl = await uploadService.uploadFile(
            uploadFile, fileName, widget.parentFolderId!,
          );

          if (rawUrl != null) {
            // Save metadata to Supabase
            await _supabaseService.addFile(
              widget.parentFolderId!, fileName, rawUrl, fileType, fileSize,
            );
            success++;
          } else {
            failed++;
          }
        } catch (e) {
          debugPrint('Upload error: $e');
          failed++;
        }
      }

      if (mounted) {
        _loadData();
        _snack(failed == 0
            ? 'Uploaded $success file${success == 1 ? '' : 's'} successfully'
            : 'Uploaded $success, failed $failed');
      }
    } catch (e) {
      _snack('Could not pick files: $e', isError: true);
    }
  }

  String _fmtBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ─── File type helpers ────────────────────────────────────────────────────
  IconData _fileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':  return Icons.picture_as_pdf_rounded;
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp':
        return Icons.image_rounded;
      case 'mp4': case 'mov': case 'avi': case 'mkv':
        return Icons.play_circle_rounded;
      case 'mp3': case 'wav': case 'aac':
        return Icons.music_note_rounded;
      case 'doc': case 'docx': return Icons.article_rounded;
      case 'xls': case 'xlsx': return Icons.table_chart_rounded;
      case 'ppt': case 'pptx': return Icons.slideshow_rounded;
      case 'zip': case 'rar': return Icons.folder_zip_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Color _fileColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':  return const Color(0xFFFF5B5B);
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp':
        return const Color(0xFF4F8EF7);
      case 'mp4': case 'mov': case 'avi':
        return const Color(0xFFA855F7);
      case 'mp3': case 'wav':
        return const Color(0xFFFFBE0B);
      case 'doc': case 'docx': return const Color(0xFF4ECDC4);
      case 'xls': case 'xlsx': return const Color(0xFF8AC926);
      case 'ppt': case 'pptx': return const Color(0xFFFF9F1C);
      default: return const Color(0xFF8A8AAA);
    }
  }

  // ─── Folder actions ───────────────────────────────────────────────────────
  Future<void> _deleteFolder(int id) async {
    final ok = await _confirmDialog(
      'Delete folder?',
      'All subfolders and files inside will be permanently removed.',
      confirmLabel: 'Delete',
      isDanger: true,
    );
    if (ok != true) return;
    try {
      await _supabaseService.deleteFolder(id);
      if (mounted) { _loadData(); _snack('Folder deleted'); }
    } catch (e) { _snack('Error: $e', isError: true); }
  }

  Future<void> _deleteFile(int id) async {
    final ok = await _confirmDialog(
      'Delete file?', 'This file will be permanently removed.',
      confirmLabel: 'Delete', isDanger: true,
    );
    if (ok != true) return;
    try {
      await _supabaseService.deleteFile(id);
      if (mounted) { _loadData(); _snack('File deleted'); }
    } catch (e) { _snack('Error: $e', isError: true); }
  }

  Future<bool?> _confirmDialog(String title, String body, {
    String confirmLabel = 'Confirm', bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: (isDanger ? Colors.red : _accent).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(isDanger ? Icons.delete_outline_rounded : Icons.info_outline_rounded,
                  color: isDanger ? Colors.redAccent : _accent, size: 24),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center,
                style: const TextStyle(color: _textSec, fontSize: 12)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textSec,
                  side: BorderSide(color: _border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDanger ? Colors.redAccent : _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(confirmLabel),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  // ─── Create folder sheet ──────────────────────────────────────────────────
  void _showCreateFolderSheet() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final semCtrl  = TextEditingController();
    final secCtrl  = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
                )),
                // Header
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: _accentDim, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.create_new_folder_rounded, color: _accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('New Folder',
                      style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 20),
                _sheetField(nameCtrl, 'Folder name', Icons.folder_rounded),
                const SizedBox(height: 12),
                _sheetField(descCtrl, 'Description (optional)', Icons.notes_rounded, maxLines: 2),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _sheetField(semCtrl, 'Semester', Icons.calendar_month_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _sheetField(secCtrl, 'Section', Icons.group_rounded)),
                ]),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSec,
                      side: BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      try {
                        await _supabaseService.addFolder(
                          courseId: widget.courseId,
                          parentId: widget.parentFolderId,
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          semester: semCtrl.text.trim(),
                          section: secCtrl.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          _loadData();
                          _snack('Folder created');
                        }
                      } catch (e) { _snack('Error: $e', isError: true); }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w600)),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditFolderSheet(Map<String, dynamic> folder) {
    final nameCtrl = TextEditingController(text: folder['name']);
    final descCtrl = TextEditingController(text: folder['description'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
                )),
                const Text('Edit Folder',
                    style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _sheetField(nameCtrl, 'Folder name', Icons.folder_rounded),
                const SizedBox(height: 12),
                _sheetField(descCtrl, 'Description', Icons.notes_rounded, maxLines: 2),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSec, side: BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      try {
                        await _supabaseService.updateFolder(
                            folder['id'], nameCtrl.text.trim(), descCtrl.text.trim());
                        if (mounted) { Navigator.pop(context); _loadData(); _snack('Folder updated'); }
                      } catch (e) { _snack('Error: $e', isError: true); }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRenameFileSheet(int fileId, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36, height: 4,
                decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
              )),
              const Text('Rename File',
                  style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _sheetField(ctrl, 'File name', Icons.edit_rounded),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textSec, side: BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: () async {
                    if (ctrl.text.trim().isEmpty) return;
                    try {
                      await _supabaseService.updateFileName(fileId, ctrl.text.trim());
                      if (mounted) { Navigator.pop(context); _loadData(); _snack('File renamed'); }
                    } catch (e) { _snack('Error: $e', isError: true); }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController c, String hint, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: c,
      style: const TextStyle(color: _textPri, fontSize: 14),
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: _textSec, size: 18),
        filled: true,
        fillColor: _card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final uploadService = Provider.of<UploadService>(context);
    final isInsideFolder = widget.parentFolderId != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Hero header ──────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader(uploadService, isInsideFolder)),

              // ── Content ──────────────────────────────────────────────────
              if (_isLoading)
                const SliverFillRemaining(child: Center(child: _Spinner()))
              else if (_folders.isEmpty && _files.isEmpty)
                SliverFillRemaining(child: _buildEmpty(isInsideFolder))
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_folders.isNotEmpty) ...[
                          _sectionHeader('Folders', _folders.length),
                          const SizedBox(height: 10),
                          _buildFolderGrid(),
                          const SizedBox(height: 24),
                        ],
                        if (_files.isNotEmpty) ...[
                          _sectionHeader('Files', _files.length),
                          const SizedBox(height: 10),
                          _buildFileList(),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── FABs ─────────────────────────────────────────────────────────
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isInsideFolder) ...[
              _Fab(
                icon: Icons.upload_file_rounded,
                label: 'Upload',
                color: _accent,
                small: true,
                onTap: _uploadFiles,
              ),
              const SizedBox(height: 10),
            ],
            _Fab(
              icon: Icons.create_new_folder_rounded,
              label: 'New Folder',
              color: _accent,
              onTap: _showCreateFolderSheet,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero header ──────────────────────────────────────────────────────────
  Widget _buildHeader(UploadService uploadService, bool isInsideFolder) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPri, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              // Breadcrumb
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(widget.courseName,
                          style: TextStyle(color: _accent, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    if (_currentFolder != null) ...[
                      Icon(Icons.chevron_right_rounded, color: _textMuted, size: 16),
                      Text(_currentFolder!['name'],
                          style: const TextStyle(color: _textSec, fontSize: 13)),
                    ],
                  ]),
                ),
              ),
              // Upload badge button
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/uploads'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: uploadService.pendingCount > 0
                        ? Colors.orange.withOpacity(0.15)
                        : _card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: uploadService.pendingCount > 0
                          ? Colors.orange.withOpacity(0.4)
                          : _border,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.cloud_upload_rounded,
                        color: uploadService.pendingCount > 0 ? Colors.orange : _textSec,
                        size: 16),
                    if (uploadService.pendingCount > 0) ...[
                      const SizedBox(width: 5),
                      Text('${uploadService.pendingCount}',
                          style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _loadData,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.refresh_rounded, color: _textSec, size: 18),
                ),
              ),
            ]),
          ),

          // Big title area with colour accent bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Colour bar
              Container(
                width: 4, height: 44,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    _currentFolder != null
                        ? _currentFolder!['name']
                        : widget.courseName,
                    style: const TextStyle(
                        color: _textPri, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_folders.length} folder${_folders.length == 1 ? '' : 's'}'
                    '${_files.isNotEmpty ? ' · ${_files.length} file${_files.length == 1 ? '' : 's'}' : ''}',
                    style: const TextStyle(color: _textSec, fontSize: 12),
                  ),
                ]),
              ),
              // Current folder info badge
              if (_currentFolder?['semester'] != null &&
                  (_currentFolder!['semester'] as String).isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _accentDim,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accentBorder),
                  ),
                  child: Text(
                    _currentFolder!['semester'],
                    style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, int count) {
    return Row(children: [
      Text(label,
          style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: _accentDim,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$count',
            style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  // ─── Folder grid ──────────────────────────────────────────────────────────
  Widget _buildFolderGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _folders.length,
      itemBuilder: (_, i) {
        final folder = _folders[i];
        return _FolderCard(
          folder: folder,
          accent: _accent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FolderScreen(
              courseId: widget.courseId,
              courseName: widget.courseName,
              courseColor: widget.courseColor,
              parentFolderId: folder['id'],
              currentFolderName: folder['name'],
            )),
          ).then((_) => _loadData()),
          onEdit: () => _showEditFolderSheet(folder),
          onDelete: () => _deleteFolder(folder['id']),
        );
      },
    );
  }

  // ─── File list ────────────────────────────────────────────────────────────
  Widget _buildFileList() {
    return Column(
      children: _files.map((file) => _FileRow(
        file: file,
        icon: _fileIcon(file['type'] ?? ''),
        iconColor: _fileColor(file['type'] ?? ''),
        accent: _accent,
        onTap: () => _openFile(file['url']),
        onDownload: () => _downloadFile(file['url'], file['name']), // Add onDownload callback
        onDelete: () => _deleteFile(file['id']),
        onRename: () => _showRenameFileSheet(file['id'], file['name']),
      )).toList(),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmpty(bool isInsideFolder) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: _accentDim, shape: BoxShape.circle),
            child: Icon(Icons.folder_open_rounded, color: _accent, size: 36),
          ),
          const SizedBox(height: 18),
          const Text('Nothing here yet',
              style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            isInsideFolder
                ? 'Create a subfolder or upload files'
                : 'Create a folder to get started',
            style: const TextStyle(color: _textSec, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _OutlineBtn(
              icon: Icons.create_new_folder_rounded,
              label: 'New Folder',
              color: _accent,
              onTap: _showCreateFolderSheet,
            ),
            if (isInsideFolder) ...[
              const SizedBox(width: 12),
              _OutlineBtn(
                icon: Icons.upload_file_rounded,
                label: 'Upload',
                color: _accent,
                onTap: _uploadFiles,
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Folder Card
// ═══════════════════════════════════════════════════════════════════════════

class _FolderCard extends StatelessWidget {
  final Map<String, dynamic> folder;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FolderCard({
    required this.folder,
    required this.accent,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  static const Color _card    = Color(0xFF1A1928);
  static const Color _border  = Color(0xFF2A2840);
  static const Color _textPri = Color(0xFFF0EFFF);
  static const Color _textSec = Color(0xFF7A7A9A);

  @override
  Widget build(BuildContext context) {
    final name = folder['name']?.toString() ?? '';
    final semester = folder['semester']?.toString() ?? '';
    final section  = folder['section']?.toString() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: icon + menu
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.folder_rounded, color: accent, size: 20),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 30, height: 30,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.more_vert_rounded, color: _textSec, size: 17),
                      color: const Color(0xFF252538),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) {
                        if (v == 'edit')   onEdit();
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit',
                            child: _mrow(Icons.edit_rounded, 'Edit', Colors.blue)),
                        PopupMenuItem(value: 'delete',
                            child: _mrow(Icons.delete_outline_rounded, 'Delete', Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom: name + meta
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w700)),
                  if (semester.isNotEmpty || section.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      [if (semester.isNotEmpty) semester, if (section.isNotEmpty) section].join(' · '),
                      style: const TextStyle(color: _textSec, fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mrow(IconData ico, String label, Color c) => Row(children: [
    Icon(ico, color: c, size: 16),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(color: Color(0xFFF0EFFF), fontSize: 13)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════
// File Row
// ═══════════════════════════════════════════════════════════════════════════

class _FileRow extends StatelessWidget {
  final Map<String, dynamic> file;
  final IconData icon;
  final Color iconColor;
  final Color accent;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final VoidCallback onDownload; // Add onDownload callback
  final VoidCallback onTap;

  const _FileRow({
    required this.file,
    required this.icon,
    required this.iconColor,
    required this.accent,
    required this.onDelete,
    required this.onRename,
    required this.onDownload, // Add onDownload callback
    required this.onTap,
  });

  static const Color _card    = Color(0xFF1A1928);
  static const Color _border  = Color(0xFF2A2840);
  static const Color _textPri = Color(0xFFF0EFFF);
  static const Color _textSec = Color(0xFF7A7A9A);

  @override
  Widget build(BuildContext context) {
    final name = file['name']?.toString() ?? '';
    final type = (file['type'] ?? '').toString().toUpperCase();
    final size = file['size']?.toString() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          // File type icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
  
          // Name + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Row(children: [
                  if (type.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(type,
                          style: TextStyle(color: iconColor, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  if (size.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(size, style: const TextStyle(color: _textSec, fontSize: 10)),
                  ],
                ]),
              ],
            ),
          ),
  
          // Actions
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: _textSec, size: 18),
            color: const Color(0xFF252538),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'open') onTap();
              if (v == 'download') onDownload();
              if (v == 'rename') onRename();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
               PopupMenuItem(value: 'open',
                  child: _mrow(Icons.open_in_new_rounded, 'Open', Colors.lightBlue)),
              PopupMenuItem(value: 'download',
                  child: _mrow(Icons.download_rounded, 'Download', Colors.greenAccent)),
              PopupMenuItem(value: 'rename',
                  child: _mrow(Icons.edit_rounded, 'Rename', Colors.blue)),
              PopupMenuItem(value: 'delete',
                  child: _mrow(Icons.delete_outline_rounded, 'Delete', Colors.redAccent)),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _mrow(IconData ico, String label, Color c) => Row(children: [
    Icon(ico, color: c, size: 16),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(color: Color(0xFFF0EFFF), fontSize: 13)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════
// FAB helper
// ═══════════════════════════════════════════════════════════════════════════

class _Fab extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool small;

  const _Fab({
    required this.icon, required this.label,
    required this.color, required this.onTap, this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    if (small) {
      return FloatingActionButton.small(
        heroTag: label,
        onPressed: onTap,
        backgroundColor: color.withOpacity(0.85),
        child: Icon(icon, size: 20),
      );
    }
    return FloatingActionButton.extended(
      heroTag: label,
      onPressed: onTap,
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Outline button for empty state
// ═══════════════════════════════════════════════════════════════════════════

class _OutlineBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OutlineBtn({required this.icon, required this.label,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Spinner
// ═══════════════════════════════════════════════════════════════════════════

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C5CBF)),
    );
  }
}

// Extension helper
extension _StrExt on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}