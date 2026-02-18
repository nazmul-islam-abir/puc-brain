import 'package:flutter/material.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int pendingUploads;

  const CustomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.pendingUploads = 0,
  });

  // ─── Theme (matches CoursesScreen) ───────────────────────────────────────
  static const Color _bg          = Color(0xFF13122A);
  static const Color _surface     = Color(0xFF1E1D35);
  static const Color _accent      = Color(0xFF7C5CBF);
  static const Color _accentLight = Color(0xFFAB8EEE);
  static const Color _inactive    = Color(0xFF5A5A7A);
  static const Color _border      = Color(0xFF2A2848);

  static const _items = [
    _NavItem(icon: Icons.class_rounded,        label: 'Classes'),
    _NavItem(icon: Icons.folder_rounded,        label: 'Materials'),
    _NavItem(icon: Icons.cloud_upload_rounded,  label: 'Uploads'),
    _NavItem(icon: Icons.person_rounded,        label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      // Respects system bottom inset (home bar / navigation bar)
      padding: EdgeInsets.only(bottom: bottomPad),
      decoration: BoxDecoration(
        color: _bg,
        border: const Border(
          top: BorderSide(color: _border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          children: List.generate(_items.length, (i) {
            final selected = i == currentIndex;
            final showBadge = i == 2 && pendingUploads > 0;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: _NavCell(
                  item: _items[i],
                  selected: selected,
                  badge: showBadge ? pendingUploads : null,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Single nav cell ──────────────────────────────────────────────────────────

class _NavCell extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final int? badge;

  const _NavCell({
    required this.item,
    required this.selected,
    this.badge,
  });

  static const Color _accent      = Color(0xFF7C5CBF);
  static const Color _accentLight = Color(0xFFAB8EEE);
  static const Color _inactive    = Color(0xFF5A5A7A);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Icon + badge ──────────────────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 46,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? _accent.withOpacity(0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: selected
                    ? Border.all(color: _accent.withOpacity(0.35), width: 1)
                    : null,
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: selected ? _accentLight : _inactive,
              ),
            ),
            if (badge != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF13122A), width: 1.5),
                  ),
                  child: Text(
                    '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 3),

        // ── Label ────────────────────────────────────────────────────────────
        Text(
          item.label,
          style: TextStyle(
            color: selected ? _accentLight : _inactive,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ── Data class ───────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}