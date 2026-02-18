import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/upload_service.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  // ─── Theme ────────────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFF0A0A14);
  static const Color _surface = Color(0xFF13121F);
  static const Color _card    = Color(0xFF1A1928);
  static const Color _border  = Color(0xFF2A2840);
  static const Color _accent  = Color(0xFF7C5CBF);
  static const Color _textPri = Color(0xFFF0EFFF);
  static const Color _textSec = Color(0xFF7A7A9A);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _bg,
        body: Consumer<UploadService>(
          builder: (context, service, _) {
            return SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, service),
                  _buildStats(service),
                  Expanded(
                    child: service.tasks.isEmpty
                        ? _buildEmpty()
                        : _buildList(context, service),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, UploadService service) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: const Border(bottom: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPri, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        const Expanded(
          child: Text('Upload Queue',
              style: TextStyle(color: _textPri, fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        if (service.completedCount > 0)
          GestureDetector(
            onTap: service.clearCompleted,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.clear_all_rounded, color: Colors.redAccent, size: 14),
                SizedBox(width: 5),
                Text('Clear done',
                    style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
      ]),
    );
  }

  // ─── Stat cards ───────────────────────────────────────────────────────────
  Widget _buildStats(UploadService service) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        _StatChip(
          label: 'Active',
          value: service.pendingCount,
          color: const Color(0xFFFFBE0B),
          icon: Icons.upload_rounded,
        ),
        const SizedBox(width: 10),
        _StatChip(
          label: 'Done',
          value: service.completedCount,
          color: const Color(0xFF4CAF7D),
          icon: Icons.check_circle_rounded,
        ),
        const SizedBox(width: 10),
        _StatChip(
          label: 'Failed',
          value: service.failedCount,
          color: const Color(0xFFCF4A5A),
          icon: Icons.error_rounded,
        ),
      ]),
    );
  }

  // ─── Task list ────────────────────────────────────────────────────────────
  Widget _buildList(BuildContext context, UploadService service) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: service.tasks.length,
      itemBuilder: (_, i) => _UploadTile(
        task: service.tasks[i],
        service: service,
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cloud_upload_rounded, color: _accent, size: 36),
        ),
        const SizedBox(height: 18),
        const Text('No uploads yet',
            style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Files you upload from folders\nwill appear here in real-time',
            style: TextStyle(color: _textSec, fontSize: 13),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Stat chip
// ═══════════════════════════════════════════════════════════════════════════

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label, required this.value,
    required this.color, required this.icon,
  });

  static const Color _card   = Color(0xFF1A1928);
  static const Color _border = Color(0xFF2A2840);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value > 0 ? color.withOpacity(0.3) : _border,
          ),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$value',
                  style: TextStyle(
                      color: value > 0 ? color : const Color(0xFF4A4A6A),
                      fontSize: 18, fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(color: Color(0xFF7A7A9A), fontSize: 9,
                      fontWeight: FontWeight.w500, letterSpacing: 0.3)),
            ],
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Upload tile
// ═══════════════════════════════════════════════════════════════════════════

class _UploadTile extends StatelessWidget {
  final UploadTask task;
  final UploadService service;

  const _UploadTile({required this.task, required this.service});

  static const Color _card    = Color(0xFF1A1928);
  static const Color _border  = Color(0xFF2A2840);
  static const Color _textPri = Color(0xFFF0EFFF);
  static const Color _textSec = Color(0xFF7A7A9A);

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon, statusLabel) = switch (task.status) {
      UploadStatus.pending   => (const Color(0xFFFFBE0B), Icons.hourglass_top_rounded, 'Waiting'),
      UploadStatus.uploading => (const Color(0xFF4F8EF7), Icons.cloud_upload_rounded, 'Uploading'),
      UploadStatus.completed => (const Color(0xFF4CAF7D), Icons.check_circle_rounded, 'Done'),
      UploadStatus.failed    => (const Color(0xFFCF4A5A), Icons.error_rounded, 'Failed'),
    };

    final ext = task.fileName.split('.').last.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.status == UploadStatus.uploading
              ? statusColor.withOpacity(0.3)
              : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // File type badge
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(statusIcon, color: statusColor, size: 16),
                  const SizedBox(height: 2),
                  Text(ext.length > 4 ? ext.substring(0, 4) : ext,
                      style: TextStyle(color: statusColor, fontSize: 7,
                          fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.fileName,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _textPri, fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    task.status == UploadStatus.uploading
                        ? 'Uploading… ${(task.progress * 100).toInt()}%'
                        : task.status == UploadStatus.failed
                            ? 'Failed${task.error != null ? ': ${task.error}' : ''}'
                            : statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Action button
            if (task.status == UploadStatus.uploading)
              _iconBtn(Icons.close_rounded, Colors.redAccent,
                  () => service.cancelUpload(task.id))
            else if (task.status == UploadStatus.failed)
              _iconBtn(Icons.refresh_rounded, const Color(0xFFFFBE0B),
                  () => service.retryTask(task.id)),
          ]),

          // Progress bar for uploading
          if (task.status == UploadStatus.uploading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: [
                Container(height: 4, color: const Color(0xFF2A2840)),
                FractionallySizedBox(
                  widthFactor: task.progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        const Color(0xFF7C5CBF),
                        statusColor,
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }
}