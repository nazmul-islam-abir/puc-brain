import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import 'folder_screen.dart';
import '../widgets/custom_drawer.dart'; // Import the custom drawer

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // Add scaffold key
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedSemester = 'All';
  bool _isSearchExpanded = false;
  int _navIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // ─── Theme ────────────────────────────────────────────────────────────────
  static const Color _bg          = Color(0xFF0F0F1A);
  static const Color _surface     = Color(0xFF1C1C2E);
  static const Color _surfaceUp   = Color(0xFF252538);
  static const Color _accent      = Color(0xFF7C5CBF);
  static const Color _accentLight = Color(0xFFAB8EEE);
  static const Color _textPrimary = Color(0xFFF0EFFF);
  static const Color _textSecond  = Color(0xFF8A8AAA);

  // ─── Categories ───────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _categories = const [
    {'id': 'all',         'label': 'All',     'icon': Icons.grid_view_rounded,   'color': Color(0xFF7C5CBF)},
    {'id': 'programming', 'label': 'Code',    'icon': Icons.code_rounded,        'color': Color(0xFF4F8EF7)},
    {'id': 'math',        'label': 'Math',    'icon': Icons.calculate_rounded,   'color': Color(0xFF4ECDC4)},
    {'id': 'science',     'label': 'Science', 'icon': Icons.science_rounded,     'color': Color(0xFF45B7D1)},
    {'id': 'art',         'label': 'Art',     'icon': Icons.brush_rounded,       'color': Color(0xFFFF6B9D)},
    {'id': 'music',       'label': 'Music',   'icon': Icons.music_note_rounded,  'color': Color(0xFFFFBE0B)},
    {'id': 'language',    'label': 'Lang',    'icon': Icons.language_rounded,    'color': Color(0xFF8AC926)},
    {'id': 'history',     'label': 'History', 'icon': Icons.history_edu_rounded, 'color': Color(0xFFFF9F1C)},
    {'id': 'psychology',  'label': 'Psych',   'icon': Icons.psychology_rounded,  'color': Color(0xFFA3C4F3)},
  ];

  // ─── Course icons ─────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _courseIcons = const [
    {'icon': Icons.code_rounded,        'color': Color(0xFF4F8EF7), 'key': 'Icons.code_rounded',        'category': 'programming'},
    {'icon': Icons.calculate_rounded,   'color': Color(0xFF4ECDC4), 'key': 'Icons.calculate_rounded',   'category': 'math'},
    {'icon': Icons.science_rounded,     'color': Color(0xFF45B7D1), 'key': 'Icons.science_rounded',     'category': 'science'},
    {'icon': Icons.brush_rounded,       'color': Color(0xFFFF6B9D), 'key': 'Icons.brush_rounded',       'category': 'art'},
    {'icon': Icons.music_note_rounded,  'color': Color(0xFFFFBE0B), 'key': 'Icons.music_note_rounded',  'category': 'music'},
    {'icon': Icons.language_rounded,    'color': Color(0xFF8AC926), 'key': 'Icons.language_rounded',    'category': 'language'},
    {'icon': Icons.history_edu_rounded, 'color': Color(0xFFFF9F1C), 'key': 'Icons.history_edu_rounded', 'category': 'history'},
    {'icon': Icons.psychology_rounded,  'color': Color(0xFFA3C4F3), 'key': 'Icons.psychology_rounded',  'category': 'psychology'},
  ];

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ─── Data ─────────────────────────────────────────────────────────────────
  Future<void> _loadCourses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _courses = await _supabaseService.getCourses();
    } catch (e) {
      if (mounted) _showTopNotification('Failed to load courses', isError: true);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showTopNotification(String msg, {bool isError = false, BuildContext? context}) {
    final effectiveContext = context ?? this.context;
    if (!mounted) return;

    ScaffoldMessenger.of(effectiveContext).hideCurrentMaterialBanner();

    final banner = MaterialBanner(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? const Color(0xFFCF6679) : const Color(0xFF4CAF7D),
      leading: Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => ScaffoldMessenger.of(effectiveContext).hideCurrentMaterialBanner(),
          child: const Text('DISMISS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      overflowAlignment: OverflowBarAlignment.start,
    );

    ScaffoldMessenger.of(effectiveContext).showMaterialBanner(banner);

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) ScaffoldMessenger.of(effectiveContext).hideCurrentMaterialBanner();
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredCourses => _courses.where((c) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = q.isEmpty || c['name'].toString().toLowerCase().contains(q);
        final descMatch = q.isEmpty || (c['description'] ?? '').toString().toLowerCase().contains(q);
        if (!nameMatch && !descMatch) return false;

        if (_selectedCategory != 'all' && _metaFor(c)['category'] != _selectedCategory) {
          return false;
        }

        if (_selectedSemester != 'All' && c['semester'].toString() != _selectedSemester) {
          return false;
        }

        return true;
      }).toList();

  Map<String, dynamic> _metaFor(Map<String, dynamic> course) =>
      _courseIcons.firstWhere(
        (i) => i['key'] == (course['icon'] ?? 'Icons.code_rounded'),
        orElse: () => _courseIcons.first,
      );

  Color _colorFor(Map<String, dynamic> course) {
    try {
      final hex = course['color'];
      if (hex != null && hex.toString().startsWith('#')) {
        return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
      }
    } catch (_) {}
    return _metaFor(course)['color'] as Color;
  }

  IconData _iconFor(Map<String, dynamic> course) =>
      _metaFor(course)['icon'] as IconData;

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCourses;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _bg,
      ),
      child: Scaffold(
        key: _scaffoldKey, // Assign the key to the scaffold
        drawer: const CustomDrawer(), // Add the drawer
        backgroundColor: _bg,
        bottomNavigationBar: _buildNavBar(),
        floatingActionButton: _buildFAB(),
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const NeverScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildFilters()),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              SliverFillRemaining(
                hasScrollBody: true,
                child: _isLoading
                    ? _buildLoading()
                    : filtered.isEmpty
                        ? _buildEmptyState()
                        : _buildCourseGrid(filtered),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Nav bar ──────────────────────────────────────────────────────────────
  Widget _buildNavBar() {
    const items = [
      {'icon': Icons.class_rounded,        'label': 'Classes'},
      {'icon': Icons.folder_rounded,       'label': 'Materials'},
      {'icon': Icons.cloud_upload_rounded, 'label': 'Uploading'},
      {'icon': Icons.person_rounded,       'label': 'Profile'},
    ];

    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFF13122A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: _accent.withOpacity(0.2), width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = i == _navIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _navIndex = i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selected ? _accent.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: selected
                          ? Border.all(color: _accent.withOpacity(0.35), width: 1)
                          : null,
                    ),
                    child: Icon(
                      items[i]['icon'] as IconData,
                      color: selected ? _accentLight : _textSecond,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[i]['label'] as String,
                    style: TextStyle(
                      color: selected ? _accentLight : _textSecond,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Menu button
            _IconBtn(
              icon: Icons.menu,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 8),
            // Logo pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accent.withOpacity(0.35)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.school_rounded, color: _accentLight, size: 16),
                SizedBox(width: 5),
                Text('EduVault', style: TextStyle(color: _accentLight, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
            const Spacer(),
            // Search toggle
            _IconBtn(
              icon: _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
              onTap: () {
                setState(() {
                  _isSearchExpanded = !_isSearchExpanded;
                  if (!_isSearchExpanded) {
                    _searchQuery = '';
                    _searchController.clear();
                  } else {
                    Future.delayed(const Duration(milliseconds: 80),
                        () => _searchFocusNode.requestFocus());
                  }
                });
              },
            ),
            const SizedBox(width: 8),
            _IconBtn(icon: Icons.refresh_rounded, onTap: _loadCourses),
          ]),

          const SizedBox(height: 12),

          // Title OR search — plain conditional, no AnimatedCrossFade
          if (_isSearchExpanded)
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: _textPrimary, fontSize: 14),
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search courses...',
                hintStyle: const TextStyle(color: _textSecond, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: _textSecond, size: 18),
                filled: true,
                fillColor: _surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _accent, width: 1.5),
                ),
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Courses',
                    style: TextStyle(
                        color: _textPrimary, fontSize: 26,
                        fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 2),
                Text(
                  '${_filteredCourses.length} course${_filteredCourses.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: _textSecond, fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─── Filters ──────────────────────────────────────────────────────────────
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(child: _buildCategoryChips()),
          const SizedBox(width: 12),
          _buildSemesterDropdown(),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = _selectedCategory == cat['id'];
          final color = cat['color'] as Color;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat['id'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? color : _surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: selected
                    ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8)]
                    : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(cat['icon'] as IconData,
                    size: 13, color: selected ? Colors.white : _textSecond),
                const SizedBox(width: 5),
                Text(cat['label'] as String,
                    style: TextStyle(
                        color: selected ? Colors.white : _textSecond,
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSemesterDropdown() {
    List<String> semesters = ['All', '1', '2', '3', '4', '5', '6', '7', '8'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 40,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSemester,
          dropdownColor: _surfaceUp,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textSecond, size: 20),
          style: const TextStyle(color: _textSecond, fontSize: 12),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedSemester = newValue);
            }
          },
          items: semesters.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value == 'All' ? 'All Semesters' : 'Semester $value'),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Course grid ──────────────────────────────────────────────────────────
  Widget _buildCourseGrid(List<Map<String, dynamic>> courses) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: courses.length,
      itemBuilder: (_, i) {
        final course = courses[i];
        final color  = _colorFor(course);
        final icon   = _iconFor(course);
        return _CourseCard(
          course: course,
          color: color,
          icon: icon,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FolderScreen(
                courseId: course['id'],
                courseName: course['name'],
                courseColor: color,
              ),
            ),
          ),
          onEdit: () => _showEditCourseDialog(course),
          onDelete: () => _deleteCourse(course['id']),
        );
      },
    );
  }

  // ─── Loading spinner ──────────────────────────────────────────────────────
  Widget _buildLoading() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              color: _accent.withOpacity(0.12), shape: BoxShape.circle),
          child: const Icon(Icons.menu_book_rounded, color: _accent, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          _searchQuery.isNotEmpty ? 'No results found' : 'No courses yet',
          style: const TextStyle(
              color: _textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          _searchQuery.isNotEmpty
              ? 'Try a different search term'
              : 'Tap + to create your first course',
          style: const TextStyle(color: _textSecond, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  // ─── FAB ─────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _showCreateCourseDialog,
      backgroundColor: _accent,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: const Text('New Course', style: TextStyle(fontWeight: FontWeight.w600)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────
  void _showCreateCourseDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? semesterVal = '1';
    String selKey   = _courseIcons[0]['key'] as String;
    Color  selColor = _courseIcons[0]['color'] as Color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (ctx, setM) => _CourseFormSheet(
          title: 'New Course',
          buttonLabel: 'Create Course',
          buttonColor: _accent,
          nameController: nameCtrl,
          descController: descCtrl,
          semesterValue: semesterVal,
          onSemesterChanged: (val) => setM(() => semesterVal = val),
          courseIcons: _courseIcons,
          selectedIconKey: selKey,
          selectedColor: selColor,
          onIconSelected: (k, c) => setM(() { selKey = k; selColor = c; }),
          onSubmit: () async {
            if (nameCtrl.text.trim().isEmpty) {
              _showTopNotification('Course name is required', isError: true, context: modalContext);
              return;
            }
            if (semesterVal == null) {
              _showTopNotification('Please select a semester', isError: true, context: modalContext);
              return;
            }

            try {
              await _supabaseService.addCourse(
                nameCtrl.text.trim(),
                descCtrl.text.trim(),
                semesterVal!,
                '#${selColor.value.toRadixString(16).substring(2).toUpperCase()}',
                selKey,
              );
              if (mounted) {
                Navigator.pop(ctx);
                _loadCourses();
                _showTopNotification('Course created!');
              }
            } catch (e) {
              if (mounted) _showTopNotification('Error: $e', isError: true, context: modalContext);
            }
          },
        ),
      ),
    );
  }

  void _showEditCourseDialog(Map<String, dynamic> course) {
    final nameCtrl = TextEditingController(text: course['name']);
    final descCtrl = TextEditingController(text: course['description'] ?? '');
    String? semesterVal = course['semester']?.toString();
    String selKey   = course['icon'] ?? _courseIcons[0]['key'];
    Color  selColor = _colorFor(course);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (ctx, setM) => _CourseFormSheet(
          title: 'Edit Course',
          buttonLabel: 'Save Changes',
          buttonColor: _accentLight,
          nameController: nameCtrl,
          descController: descCtrl,
          semesterValue: semesterVal,
          onSemesterChanged: (val) => setM(() => semesterVal = val),
          courseIcons: _courseIcons,
          selectedIconKey: selKey,
          selectedColor: selColor,
          onIconSelected: (k, c) => setM(() { selKey = k; selColor = c; }),
          onSubmit: () async {
            if (nameCtrl.text.trim().isEmpty) {
              _showTopNotification('Course name is required', isError: true, context: modalContext);
              return;
            }
            if (semesterVal == null) {
              _showTopNotification('Please select a semester', isError: true, context: modalContext);
              return;
            }

            try {
              await _supabaseService.updateCourse(
                course['id'],
                nameCtrl.text.trim(),
                descCtrl.text.trim(),
                semesterVal!,
                '#${selColor.value.toRadixString(16).substring(2).toUpperCase()}',
                selKey,
              );
              if (mounted) {
                Navigator.pop(ctx);
                _loadCourses();
                _showTopNotification('Course updated!');
              }
            } catch (e) {
              if (mounted) _showTopNotification('Error: $e', isError: true, context: modalContext);
            }
          },
        ),
      ),
    );
  }

  Future<void> _deleteCourse(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 26),
            ),
            const SizedBox(height: 14),
            const Text('Delete Course?',
                style: TextStyle(
                    color: _textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'All folders and files will be permanently removed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecond, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textSecond,
                    side: const BorderSide(color: _surfaceUp),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );

    if (ok == true) {
      try {
        await _supabaseService.deleteCourse(id);
        if (mounted) {
          _loadCourses();
          _showTopNotification('Course deleted');
        }
      } catch (e) {
        if (mounted) _showTopNotification('Error: $e', isError: true);
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Course Card
// ═══════════════════════════════════════════════════════════════════════════

class _CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CourseCard({
    required this.course,
    required this.color,
    required this.icon,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = course['name']?.toString() ?? '';
    final desc = (course['description'] ?? '').toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.6)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top: icon + 3-dot ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 32, height: 32,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert_rounded,
                          color: Colors.white, size: 18),
                      color: const Color(0xFF252538),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) {
                        if (v == 'edit')   onEdit();
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: _menuRow(
                              Icons.edit_rounded, 'Edit', Colors.blue),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: _menuRow(Icons.delete_outline_rounded,
                              'Delete', Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom: name + desc + open pill ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 10,
                            height: 1.4)),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Open',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                        SizedBox(width: 3),
                        Icon(Icons.arrow_forward_rounded,
                            size: 11, color: Colors.white),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(IconData ico, String label, Color c) => Row(children: [
    Icon(ico, color: c, size: 17),
    const SizedBox(width: 9),
    Text(label,
        style: const TextStyle(color: Color(0xFFF0EFFF), fontSize: 13)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════
// Small icon button
// ═══════════════════════════════════════════════════════════════════════════

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF8A8AAA), size: 19),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Course Form Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _CourseFormSheet extends StatelessWidget {
  final String title;
  final String buttonLabel;
  final Color buttonColor;
  final TextEditingController nameController;
  final TextEditingController descController;
  final String? semesterValue;
  final ValueChanged<String?> onSemesterChanged;
  final List<Map<String, dynamic>> courseIcons;
  final String selectedIconKey;
  final Color selectedColor;
  final void Function(String key, Color color) onIconSelected;
  final VoidCallback onSubmit;

  const _CourseFormSheet({
    required this.title,
    required this.buttonLabel,
    required this.buttonColor,
    required this.nameController,
    required this.descController,
    required this.semesterValue,
    required this.onSemesterChanged,
    required this.courseIcons,
    required this.selectedIconKey,
    required this.selectedColor,
    required this.onIconSelected,
    required this.onSubmit,
  });

  static const Color _bg      = Color(0xFF1C1C2E);
  static const Color _surface = Color(0xFF252538);
  static const Color _primary = Color(0xFFF0EFFF);
  static const Color _second  = Color(0xFF8A8AAA);
  static const Color _accent  = Color(0xFF7C5CBF);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              // Live colour strip
              Container(
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [selectedColor, selectedColor.withOpacity(0.2)]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(title,
                  style: const TextStyle(
                      color: _primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              _lbl('Course Name'),
              const SizedBox(height: 7),
              _fld(nameController, 'e.g. Introduction to Python',
                  Icons.school_rounded),
              const SizedBox(height: 14),
              _lbl('Description'),
              const SizedBox(height: 7),
              _fld(descController, 'Short description…',
                  Icons.notes_rounded, maxLines: 2),
              const SizedBox(height: 14),
              _lbl('Semester'),
              const SizedBox(height: 7),
              _buildSemesterFormField(),
              const SizedBox(height: 18),
              _lbl('Pick an Icon'),
              const SizedBox(height: 10),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: courseIcons.length,
                  itemBuilder: (_, i) {
                    final meta  = courseIcons[i];
                    final key   = meta['key']   as String;
                    final color = meta['color'] as Color;
                    final sel   = selectedIconKey == key;
                    return GestureDetector(
                      onTap: () => onIconSelected(key, color),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: sel ? color.withOpacity(0.22) : _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: sel ? color : Colors.transparent,
                              width: 2),
                        ),
                        child: Icon(meta['icon'] as IconData,
                            color: sel ? color : _second, size: 22),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _second,
                      side: const BorderSide(color: _surface),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(buttonLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSemesterFormField() {
    return DropdownButtonFormField<String>(
      value: semesterValue,
      items: List.generate(8, (i) => (i + 1).toString())
          .map((sem) => DropdownMenuItem(
                value: sem,
                child: Text('Semester $sem'),
              ))
          .toList(),
      onChanged: onSemesterChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.calendar_today_rounded, color: _second, size: 17),
        filled: true,
        fillColor: _surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
      ),
      style: const TextStyle(color: _primary, fontSize: 14),
      dropdownColor: _surface,
    );
  }

  Widget _lbl(String t) => Text(t,
      style: const TextStyle(
          color: _second,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4));

  Widget _fld(TextEditingController c, String hint, IconData ico,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: c,
      style: const TextStyle(color: _primary, fontSize: 14),
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _second, fontSize: 12),
        prefixIcon: Icon(ico, color: _second, size: 17),
        filled: true,
        fillColor: _surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
      ),
    );
  }
}