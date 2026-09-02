import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/academic_context.dart';
import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../services/student_content_service.dart';
import '../widgets/manara_logo.dart';
import 'student_home_screen.dart';

class AcademicSelectionScreen extends StatefulWidget {
  const AcademicSelectionScreen({
    required this.profile,
    required this.authService,
    required this.apiBaseUrl,
    super.key,
  });

  final StudentProfile profile;
  final StudentAuthService authService;
  final String apiBaseUrl;

  @override
  State<AcademicSelectionScreen> createState() => _AcademicSelectionScreenState();
}

class _AcademicSelectionScreenState extends State<AcademicSelectionScreen> {
  late final StudentContentService _contentService;
  late AcademicOptions _options;
  late AcademicContext _selection;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _contentService = StudentContentService(
      widget.authService.client,
      baseUrl: widget.apiBaseUrl,
    );
    _options = AcademicOptions.defaults(widget.profile.academicValues);
    _selection = _defaultSelection(_options);
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await _contentService.fetchAcademicOptions(widget.profile);
      if (!mounted) return;
      setState(() {
        _options = options;
        _selection = _keepSelectionAvailable(_selection, options);
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'تعذر تحميل الخيارات من Supabase، وتم استخدام الخيارات الافتراضية.';
      });
    }
  }

  AcademicContext _defaultSelection(AcademicOptions options) {
    return AcademicContext(
      grade: options.grades.first,
      term: options.terms.first,
      subject: options.subjects.first,
      unit: options.units.first,
      lesson: options.lessons.first,
    );
  }

  AcademicContext _keepSelectionAvailable(
    AcademicContext current,
    AcademicOptions options,
  ) {
    return AcademicContext(
      grade: _available(current.grade, options.grades),
      term: _available(current.term, options.terms),
      subject: _available(current.subject, options.subjects),
      unit: _available(current.unit, options.units),
      lesson: _available(current.lesson, options.lessons),
    );
  }

  String _available(String value, List<String> options) {
    return options.contains(value) ? value : options.first;
  }

  void _updateSelection({
    String? grade,
    String? term,
    String? subject,
    String? unit,
    String? lesson,
  }) {
    setState(() {
      _selection = AcademicContext(
        grade: grade ?? _selection.grade,
        term: term ?? _selection.term,
        subject: subject ?? _selection.subject,
        unit: unit ?? _selection.unit,
        lesson: lesson ?? _selection.lesson,
      );
    });
  }

  Future<void> _enterDashboard() async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => StudentDashboardScreen(
          profile: widget.profile,
          authService: widget.authService,
          apiBaseUrl: widget.apiBaseUrl,
          academicContext: _selection,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF07272E), Color(0xFF0E1B2A), Color(0xFF274E76)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    const ManaraLogo(size: 84),
                    const SizedBox(height: 12),
                    const Text(
                      'اختر رحلتك التعليمية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
                    const SizedBox(height: 6),
                    Text(
                      'أهلًا ${widget.profile.name}، حدّد الدرس الذي تريد البدء به',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF9EEBEA),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Card(
                      elevation: 18,
                      shadowColor: Colors.black54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'البيانات الأكاديمية',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Color(0xFF0E1B2A),
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'سنستخدم اختيارك لعرض الدروس والأنشطة المناسبة.',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_loadError != null) ...[
                              const SizedBox(height: 12),
                              _InfoBanner(message: _loadError!),
                            ],
                            const SizedBox(height: 18),
                            _AcademicDropdown(
                              label: 'الصف الدراسي',
                              icon: Icons.school_rounded,
                              value: _selection.grade,
                              options: _options.grades,
                              onChanged: (value) => _updateSelection(grade: value),
                            ),
                            _AcademicDropdown(
                              label: 'الفصل الدراسي',
                              icon: Icons.calendar_month_rounded,
                              value: _selection.term,
                              options: _options.terms,
                              onChanged: (value) => _updateSelection(term: value),
                            ),
                            _AcademicDropdown(
                              label: 'المادة الدراسية',
                              icon: Icons.menu_book_rounded,
                              value: _selection.subject,
                              options: _options.subjects,
                              onChanged: (value) => _updateSelection(subject: value),
                            ),
                            _AcademicDropdown(
                              label: 'الوحدة التعليمية',
                              icon: Icons.view_list_rounded,
                              value: _selection.unit,
                              options: _options.units,
                              onChanged: (value) => _updateSelection(unit: value),
                            ),
                            _AcademicDropdown(
                              label: 'الدرس الحالي',
                              icon: Icons.play_lesson_rounded,
                              value: _selection.lesson,
                              options: _options.lessons,
                              onChanged: (value) => _updateSelection(lesson: value),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _loading ? null : _enterDashboard,
                              icon: _loading
                                  ? const SizedBox(
                                      width: 19,
                                      height: 19,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.arrow_back_rounded),
                              label: Text(_loading ? 'جاري تحميل الخيارات...' : 'الدخول إلى لوحة الطالب'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                backgroundColor: const Color(0xFF0B8693),
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1),
                    const SizedBox(height: 16),
                    Text(
                      _selection.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AcademicDropdown extends StatelessWidget {
  const _AcademicDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        onChanged: onChanged,
        icon: const Icon(Icons.expand_more_rounded),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF0B8693)),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF92400E),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }
}