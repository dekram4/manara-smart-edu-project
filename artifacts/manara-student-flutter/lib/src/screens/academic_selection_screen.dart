import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_gamification.dart';
import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../services/student_sound_service.dart';
import '../services/student_content_service.dart';
import '../widgets/student_experience.dart';
import '../widgets/student_mascot.dart';
import 'student_home_screen.dart';

/// The books illustration's own aspect ratio (4095 x 3374), used to work
/// out exactly where it renders under `BoxFit.contain` so every control can
/// be pinned onto the right book at any window size.
const double _booksAspect = 4095 / 3374;

/// Where a control sits inside that illustration, as fractions of its
/// width/height — measured off the asset. A control pinned with these
/// lands on its book no matter how large the window is.
class _BookSlot {
  const _BookSlot({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
    required this.color,
  });

  final double centerX;
  final double centerY;
  final double width;
  final double height;
  final Color color;

  Rect resolve(Rect imageRect) => Rect.fromCenter(
    center: Offset(
      imageRect.left + centerX * imageRect.width,
      imageRect.top + centerY * imageRect.height,
    ),
    width: width * imageRect.width,
    height: height * imageRect.height,
  );
}

/// One slot per book, top to bottom, each measured against the white page
/// block of that book — never its coloured cover — so every control lands
/// on paper the way the login fields sit inside the green board.
const _gradeSlot = _BookSlot(
  centerX: 0.355,
  centerY: 0.118,
  width: 0.27,
  height: 0.090,
  color: Color(0xFF2FA8BE), // teal, top book
);
const _atramSlot = _BookSlot(
  centerX: 0.680,
  centerY: 0.248,
  width: 0.26,
  height: 0.075,
  color: Color(0xFFE8930C), // orange
);
const _subjectSlot = _BookSlot(
  centerX: 0.690,
  centerY: 0.447,
  width: 0.33,
  height: 0.072,
  color: Color(0xFFA974BE), // purple
);
const _unitSlot = _BookSlot(
  centerX: 0.345,
  centerY: 0.612,
  width: 0.42,
  height: 0.072,
  color: Color(0xFFC0392B), // red
);
const _lessonSlot = _BookSlot(
  centerX: 0.300,
  centerY: 0.752,
  width: 0.32,
  height: 0.060,
  color: Color(0xFF2E7D4F), // green
);
const _startSlot = _BookSlot(
  centerX: 0.310,
  centerY: 0.900,
  width: 0.40,
  height: 0.090,
  color: Color(0xFF12406B), // navy, bottom book
);

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
  AcademicSelectionData? _data;
  String? _grade;
  String? _atram;
  String? _subject;
  String? _term;
  String? _unit;
  LessonContent? _lesson;
  bool _loading = true;
  bool _isEntering = false;
  String? _loadError;
  StudentGamification _gamification = const StudentGamification();

  bool get _ready => !_loading && _data != null && !_data!.isEmpty;

  @override
  void initState() {
    super.initState();
    _contentService = StudentContentService(
      widget.authService.client,
      baseUrl: widget.apiBaseUrl,
    );
    _loadSelectionData();
    _loadGamification();
  }

  Future<void> _loadGamification() async {
    try {
      final snapshot = await _contentService.fetchGamification(widget.profile);
      if (mounted) setState(() => _gamification = snapshot);
    } catch (_) {
      // The gems HUD chip just keeps showing 0 if this is unavailable —
      // never blocks picking an academic path.
    }
  }

  Future<void> _loadSelectionData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final data = await _contentService.fetchAcademicSelectionData(widget.profile);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        if (data.isEmpty) {
          _loadError =
              'لا توجد مسارات أكاديمية مكتملة مرتبطة بدروس متاحة لحسابك حاليًا.';
          _clearSelection();
          return;
        }
        _applyInitialSelection(data);
        if (data.hierarchyUnavailable) {
          _loadError =
              'تعذر قراءة إعدادات الشجرة؛ تم عرض المسارات المكتملة من الدروس المتاحة فقط.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _data = null;
        _clearSelection();
        _loadError = 'تعذر تحميل البيانات الأكاديمية من Supabase: $error';
      });
    }
  }

  void _clearSelection() {
    _grade = null;
    _atram = null;
    _subject = null;
    _term = null;
    _unit = null;
    _lesson = null;
  }

  void _applyInitialSelection(AcademicSelectionData data) {
    final grade = _pick(data.grades, widget.profile.grade);
    final atram = _pick(data.atramsFor(grade), widget.profile.atram);
    final subject = _pick(
      data.subjectsFor(grade: grade, atram: atram),
      widget.profile.subject,
    );
    final term = _pick(
      data.termsFor(grade: grade, atram: atram, subject: subject),
      widget.profile.term,
    );
    final unit = _pick(
      data.unitsFor(
        grade: grade,
        atram: atram,
        subject: subject,
        term: term,
      ),
      widget.profile.unit,
    );
    final lessons = data.lessonsFor(
      grade: grade,
      atram: atram,
      subject: subject,
      term: term,
      unit: unit,
    );

    _grade = grade;
    _atram = atram;
    _subject = subject;
    _term = term;
    _unit = unit;
    _lesson = lessons.isEmpty ? null : lessons.first;
  }

  String _pick(List<String> values, String? preferred) {
    if (values.isEmpty) return '';
    final matched = values.where(
      (value) => _normalized(value) == _normalized(preferred),
    );
    return matched.isEmpty ? values.first : matched.first;
  }

  void _selectGrade(String? grade) {
    final data = _data;
    if (data == null || grade == null) return;
    setState(() {
      _grade = grade;
      _atram = _pick(data.atramsFor(grade), null);
      _subject = _pick(
        data.subjectsFor(grade: _grade!, atram: _atram!),
        null,
      );
      _term = _pick(
        data.termsFor(
          grade: _grade!,
          atram: _atram!,
          subject: _subject!,
        ),
        null,
      );
      _unit = _pick(
        data.unitsFor(
          grade: _grade!,
          atram: _atram!,
          subject: _subject!,
          term: _term!,
        ),
        null,
      );
      _lesson = _lessonsForSelection().firstOrNull;
    });
    _playSelectionFeedback();
  }

  void _selectAtram(String? atram) {
    final data = _data;
    if (data == null || _grade == null || atram == null) return;
    setState(() {
      _atram = atram;
      _subject = _pick(data.subjectsFor(grade: _grade!, atram: atram), null);
      _term = _pick(
        data.termsFor(
          grade: _grade!,
          atram: _atram!,
          subject: _subject!,
        ),
        null,
      );
      _unit = _pick(
        data.unitsFor(
          grade: _grade!,
          atram: _atram!,
          subject: _subject!,
          term: _term!,
        ),
        null,
      );
      _lesson = _lessonsForSelection().firstOrNull;
    });
    _playSelectionFeedback();
  }

  void _selectSubject(String? subject) {
    final data = _data;
    if (data == null || _grade == null || _atram == null || subject == null) return;
    setState(() {
      _subject = subject;
      _term = _pick(
        data.termsFor(grade: _grade!, atram: _atram!, subject: subject),
        null,
      );
      _unit = _pick(
        data.unitsFor(
          grade: _grade!,
          atram: _atram!,
          subject: _subject!,
          term: _term!,
        ),
        null,
      );
      _lesson = _lessonsForSelection().firstOrNull;
    });
    _playSelectionFeedback();
  }

  void _selectTerm(String? term) {
    final data = _data;
    if (data == null ||
        _grade == null ||
        _atram == null ||
        _subject == null ||
        term == null) {
      return;
    }
    setState(() {
      _term = term;
      _unit = _pick(
        data.unitsFor(
          grade: _grade!,
          atram: _atram!,
          subject: _subject!,
          term: _term!,
        ),
        null,
      );
      _lesson = _lessonsForSelection().firstOrNull;
    });
    _playSelectionFeedback();
  }

  void _selectUnit(String? unit) {
    if (_data == null || unit == null) return;
    setState(() {
      _unit = unit;
      _lesson = _lessonsForSelection().firstOrNull;
    });
    _playSelectionFeedback();
  }

  /// The lesson dropdown deals in names, so the pick is resolved back to the
  /// real [LessonContent] the rest of the app navigates with.
  void _selectLessonNamed(String? lessonName) {
    if (lessonName == null) return;
    final matches = _lessonsForSelection().where(
      (lesson) => _normalized(lesson.lessonName) == _normalized(lessonName),
    );
    if (matches.isEmpty) return;
    setState(() => _lesson = matches.first);
    _playSelectionFeedback();
  }

  void _playSelectionFeedback() {
    StudentSoundService.instance.play(StudentSoundCue.answerSelected);
  }

  List<LessonContent> _lessonsForSelection() {
    final data = _data;
    if (data == null ||
        _grade == null ||
        _atram == null ||
        _subject == null ||
        _term == null ||
        _unit == null) {
      return const [];
    }
    return data.lessonsFor(
      grade: _grade!,
      atram: _atram!,
      subject: _subject!,
      term: _term!,
      unit: _unit!,
    );
  }

  AcademicContext? get _selection {
    final lesson = _lesson;
    if (lesson == null ||
        _grade == null ||
        _atram == null ||
        _subject == null ||
        _term == null ||
        _unit == null) {
      return null;
    }
    return AcademicContext(
      grade: _grade!,
      atram: _atram!,
      subject: _subject!,
      term: _term!,
      unit: _unit!,
      selectedLesson: lesson,
    );
  }

  /// The options behind each of the three books, read from exactly the same
  /// [AcademicSelectionData] getters the original dropdown UI used — the
  /// real hierarchy the teacher configured, each level filtered by what is
  /// picked above it.
  List<String> get _gradeOptions => _data?.grades ?? const [];

  List<String> get _atramOptions {
    final data = _data;
    if (data == null || _grade == null) return const [];
    return data.atramsFor(_grade!);
  }

  List<String> get _subjectOptions {
    final data = _data;
    if (data == null || _grade == null || _atram == null) return const [];
    return data.subjectsFor(grade: _grade!, atram: _atram!);
  }

  List<String> get _termOptions {
    final data = _data;
    if (data == null || _grade == null || _atram == null || _subject == null) {
      return const [];
    }
    return data.termsFor(grade: _grade!, atram: _atram!, subject: _subject!);
  }

  List<String> get _unitOptions {
    final data = _data;
    if (data == null ||
        _grade == null ||
        _atram == null ||
        _subject == null ||
        _term == null) {
      return const [];
    }
    return data.unitsFor(
      grade: _grade!,
      atram: _atram!,
      subject: _subject!,
      term: _term!,
    );
  }

  List<String> get _lessonOptions =>
      _lessonsForSelection().map((lesson) => lesson.lessonName).toList();

  Future<void> _enterDashboard() async {
    final selection = _selection;
    if (selection == null || _isEntering) return;
    StudentSoundService.instance.playTap();
    setState(() => _isEntering = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        StudentPageRoute<void>(
          builder: (_) => StudentHomeScreen(
            profile: widget.profile,
            authService: widget.authService,
            apiBaseUrl: widget.apiBaseUrl,
            academicContext: selection,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isEntering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE3EEF7), Color(0xFFF7F1E6), Color(0xFFE9F1F5)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final areaSize = constraints.biggest;
                final imageRect = _containRect(areaSize, _booksAspect);
                // Whatever margin the (wide) illustration leaves at the
                // sides is where the guide stands — she never covers the
                // books or their controls.
                final sideMargin = (areaSize.width - imageRect.width) / 2;
                // Both side characters are capped by the gutter they stand
                // in, so neither can ever be laid out wider than its own
                // slot — the guide is simply hidden below the width that
                // would shrink her under the 180px she is meant to have.
                final mascotHeight =
                    math.min(200.0, sideMargin - 16).toDouble();
                final showMascot = _ready && mascotHeight >= 180;
                final pencilWidth =
                    math.min(230.0, sideMargin - 20).toDouble();

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fromRect(
                      rect: imageRect,
                      child: Image.asset(
                        'assets/images/learning_path_bg.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    if (_ready) ..._buildBookControls(imageRect),
                    if (!_ready)
                      Positioned.fromRect(
                        rect: imageRect,
                        child: Center(child: _buildLoadingOrError()),
                      ),
                    if (showMascot)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        width: sideMargin - 12,
                        child: _MascotGuide(height: mascotHeight),
                      ),
                    if (pencilWidth >= 150)
                      Positioned(
                        right: 8,
                        bottom: 4,
                        child: Transform.rotate(
                          angle: -0.14,
                          child: Image.asset(
                            'assets/images/winter_fun.png',
                            width: pencilWidth,
                            height: pencilWidth,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      left: 10,
                      child: Image.asset(
                        'assets/images/manara-logo-mark-transparent.png',
                        height: 70,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 8,
                      child: Row(
                        children: [
                          if (_ready)
                            _HudChip(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.diamond_rounded,
                                      color: Color(0xFF0EA5A5), size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_gamification.gems}',
                                    style: const TextStyle(
                                      color: Color(0xFF22303A),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0x14000000),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const StudentSoundToggle(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOrError() {
    if (_loading) {
      return StudentEntrance(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PathMascot(size: 120),
            const SizedBox(height: 10),
            Text(
              'أهلًا ${widget.profile.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF22303A),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const StudentRiveLoading(size: 84, label: 'جارٍ تحميل المسار الأكاديمي'),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: _InfoBanner(
        message: _loadError ?? 'لا توجد مسارات أكاديمية متاحة حاليًا.',
      ),
    );
  }

  /// One control per book, in hierarchy order, each pinned onto that book's
  /// page area via its measured slot.
  List<Widget> _buildBookControls(Rect imageRect) {
    final canStart = _selection != null;
    // The tree has a chapter level between subject and unit. It shares the
    // red book with the unit — and only claims room there when the teacher
    // actually configured more than one chapter, so the six-book layout
    // stays exactly as designed for the usual single-chapter subject.
    final chapters = _termOptions;
    final unitControl = _BookDropdown(
      label: 'الوحدة التعليمية',
      icon: Icons.category_rounded,
      color: _unitSlot.color,
      value: _unit,
      options: _unitOptions,
      onSelected: _selectUnit,
    );

    return [
      Positioned.fromRect(
        rect: _gradeSlot.resolve(imageRect),
        child: _BookDropdown(
          label: 'الصف الدراسي',
          icon: Icons.school_rounded,
          color: _gradeSlot.color,
          value: _grade,
          options: _gradeOptions,
          onSelected: _selectGrade,
        ),
      ),
      Positioned.fromRect(
        rect: _atramSlot.resolve(imageRect),
        child: _BookDropdown(
          label: 'الفصل الدراسي / الترم',
          icon: Icons.calendar_month_rounded,
          color: _atramSlot.color,
          value: _atram,
          options: _atramOptions,
          onSelected: _selectAtram,
        ),
      ),
      Positioned.fromRect(
        rect: _subjectSlot.resolve(imageRect),
        child: _BookDropdown(
          label: 'المادة التعليمية',
          icon: Icons.menu_book_rounded,
          color: _subjectSlot.color,
          value: _subject,
          options: _subjectOptions,
          onSelected: _selectSubject,
        ),
      ),
      Positioned.fromRect(
        rect: _unitSlot.resolve(imageRect),
        child: chapters.length > 1
            ? Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _BookDropdown(
                      label: 'الفصل',
                      icon: Icons.bookmarks_rounded,
                      color: _unitSlot.color,
                      value: _term,
                      options: chapters,
                      onSelected: _selectTerm,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(flex: 6, child: unitControl),
                ],
              )
            : unitControl,
      ),
      Positioned.fromRect(
        rect: _lessonSlot.resolve(imageRect),
        child: _BookDropdown(
          label: 'الدرس',
          icon: Icons.play_lesson_rounded,
          color: _lessonSlot.color,
          value: _lesson?.lessonName,
          options: _lessonOptions,
          onSelected: _selectLessonNamed,
        ),
      ),
      Positioned.fromRect(
        rect: _startSlot.resolve(imageRect),
        child: _StartAdventureButton(
          enabled: canStart && !_isEntering,
          busy: _isEntering,
          onPressed: _enterDashboard,
        ),
      ),
      if (_loadError != null)
        Positioned(
          left: imageRect.left + imageRect.width * 0.12,
          width: imageRect.width * 0.76,
          bottom: 4,
          child: _InfoBanner(message: _loadError!),
        ),
    ];
  }
}

/// The rect an image with [aspectRatio] (width / height) actually renders
/// into under `BoxFit.contain` inside [container] — the anchor every book
/// control is positioned from.
Rect _containRect(Size container, double aspectRatio) {
  final containerAspect = container.width / container.height;
  double width;
  double height;
  if (containerAspect > aspectRatio) {
    height = container.height;
    width = height * aspectRatio;
  } else {
    width = container.width;
    height = width / aspectRatio;
  }
  return Rect.fromLTWH(
    (container.width - width) / 2,
    (container.height - height) / 2,
    width,
    height,
  );
}

/// A dropdown that sits on a book's page area: a near-white card so the
/// text stays black-on-paper legible for young readers, a soft rim and a
/// light 3D shadow in that book's own colour, and a real popup menu of the
/// options the teacher configured.
class _BookDropdown extends StatelessWidget {
  const _BookDropdown({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final enabled = options.isNotEmpty;
    final dark = Color.lerp(color, Colors.black, 0.34)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        return PopupMenuButton<String>(
          enabled: enabled,
          // The label is already printed on the control, so a hover
          // tooltip would just repeat it over the artwork.
          tooltip: '',
          offset: const Offset(0, 8),
          constraints: const BoxConstraints(minWidth: 200, maxHeight: 320),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: onSelected,
          itemBuilder: (context) => [
            for (final option in options)
              PopupMenuItem<String>(
                value: option,
                child: Row(
                  children: [
                    Icon(
                      option == value
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 18,
                      color: option == value ? color : Colors.black26,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontWeight:
                              option == value ? FontWeight.w900 : FontWeight.w700,
                          color: const Color(0xFF22303A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: Container(
            // A slim ledge in the book's own colour under the card is the
            // whole 3D effect — light, so it never fights the artwork.
            padding: EdgeInsets.only(
              bottom: math.min(5.0, constraints.maxHeight * 0.09),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: dark,
              boxShadow: [
                BoxShadow(
                  color: dark.withOpacity(0.30),
                  blurRadius: 9,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: const Color(0xFFFDFDFD),
                border: Border.all(color: color.withOpacity(0.85), width: 1.8),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: dark, size: 16),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: dark.withOpacity(0.85),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              enabled ? (value ?? 'اختر') : 'غير متاح',
                              maxLines: 1,
                              style: const TextStyle(
                                color: Color(0xFF1B2733),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, color: dark, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The chunky 3D "start the adventure" button on the lower books.
class _StartAdventureButton extends StatelessWidget {
  const _StartAdventureButton({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? const Color(0xFFFF9F1C) : const Color(0xFFB6BEC6);
    return StudentPressScale(
      child: StudentEmbossedShell(
        color: color,
        depth: 6,
        borderRadius: 24,
        // Expands so the button's face covers the whole shell — without
        // this the button sizes to its label and leaves the darker 3D
        // ledge showing beside it.
        child: SizedBox.expand(
          child: FilledButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.rocket_launch_rounded),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(busy ? 'نجهّز رحلتك...' : 'ابدأ المغامرة!'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFB6BEC6),
              disabledForegroundColor: Colors.white70,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The girl guide standing beside the books with a speech bubble above her
/// head, both drifting gently up and down together.
class _MascotGuide extends StatelessWidget {
  const _MascotGuide({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SpeechBubble(text: 'اختر صفك لنبدأ الرحلة يا بطل! ✨'),
        const SizedBox(height: 2),
        PathMascot(size: height),
      ],
    );
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return content;
    return content
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(begin: 0, end: -9, duration: 1800.ms, curve: Curves.easeInOut);
  }
}

/// A soft cartoon speech bubble with a little tail pointing down at the
/// guide's head.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFD9A0), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF22303A),
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        CustomPaint(size: const Size(18, 9), painter: _BubbleTailPainter()),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * 0.42, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFD9A0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
      ),
      child: child,
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

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _normalized(Object? value) => value?.toString().trim().toLowerCase() ?? '';
