import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_gamification.dart';
import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../services/student_sound_service.dart';
import '../services/student_avatar_store.dart';
import '../services/student_content_service.dart';
import '../theme/student_theme.dart';
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
///
/// [angle] is the slope of that book's page band in radians, read straight
/// off the artwork: for every book the top and bottom edges of the white
/// block were traced across 21 sample columns and a line fitted through
/// them. The books do not share one slope — the top book is almost flat,
/// the two the reader sees edge-on rise to the right, and the three at the
/// base fall to the right — so each control carries its own book's angle
/// and ends up sitting along the printed page lines instead of across them.
/// Because the illustration is scaled uniformly by `BoxFit.contain`, an
/// angle measured in source pixels is exactly the angle on screen.
class _BookSlot {
  const _BookSlot({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
    required this.angle,
    required this.color,
  });

  final double centerX;
  final double centerY;
  final double width;
  final double height;
  final double angle;
  final Color color;

  Rect resolve(Rect imageRect) => Rect.fromCenter(
    center: Offset(
      imageRect.left + centerX * imageRect.width,
      imageRect.top + centerY * imageRect.height,
    ),
    width: width * imageRect.width,
    height: height * imageRect.height,
  );

  /// Pins [child] onto this book and tilts it to the page's own slope.
  /// `Transform.rotate` is paint-only, so the tilt can never change the
  /// laid-out size and can never produce an overflow.
  Widget place(Rect imageRect, Widget child) => Positioned.fromRect(
    rect: resolve(imageRect),
    child: Transform.rotate(angle: angle, child: child),
  );
}

/// One slot per book, top to bottom, each measured against the white page
/// block of that book — never its coloured cover — so every control lands
/// on paper the way the login fields sit inside the green board.
/// Each band was then walked column by column along its own slope until
/// the white ran out, which gives the page's true usable length. Every
/// control below is centred on its band's midpoint and set to 85% of that
/// length — the top of the range that still leaves clear paper at both
/// ends. The bands are very different lengths (the top book's page is
/// barely a quarter of the illustration wide, the bottom book's is over
/// half), which is why these widths are not uniform.
const _gradeSlot = _BookSlot(
  centerX: 0.3773,
  centerY: 0.1164,
  width: 0.2138,
  height: 0.077,
  angle: 0.035,
  color: Color(0xFF2FA8BE), // teal, top book
);
const _atramSlot = _BookSlot(
  centerX: 0.6239,
  centerY: 0.2640,
  width: 0.2636,
  height: 0.066,
  angle: -0.155,
  color: Color(0xFFE8930C), // orange
);
const _subjectSlot = _BookSlot(
  centerX: 0.6667,
  centerY: 0.4381,
  width: 0.3321,
  height: 0.077,
  angle: -0.155,
  color: Color(0xFFA974BE), // purple
);
// The red book is the one exception to the flat 85%: the purple book's
// bottom corner dips into its page around x=0.47, so this field is set to
// 81% and dropped ~20px to pass under that corner.
const _unitSlot = _BookSlot(
  centerX: 0.3626,
  centerY: 0.6130,
  width: 0.3720,
  height: 0.064,
  angle: 0.089,
  color: Color(0xFFC0392B), // red
);
const _lessonSlot = _BookSlot(
  centerX: 0.3578,
  centerY: 0.7398,
  width: 0.3923,
  height: 0.064,
  angle: 0.089,
  color: Color(0xFF2E7D4F), // green
);
const _startSlot = _BookSlot(
  centerX: 0.3419,
  centerY: 0.8928,
  width: 0.4400,
  height: 0.075,
  angle: 0.089,
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
  /// Set once, when the student starts the adventure: the characters fly
  /// off and fade before the route is replaced.
  bool _leaving = false;
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
    // The characters fly off before the route changes, so starting the
    // adventure reads as them leading the way rather than as a cut.
    setState(() {
      _isEntering = true;
      _leaving = true;
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 620));
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
          // The mark is the screen's background now rather than a badge in
          // the corner: one large, very pale blue silhouette spanning the
          // whole screen behind everything. It is drawn at 7% so it reads
          // as watermarked paper — present when looked for, invisible when
          // reading the books over it — and ignores pointers so it can
          // never take a tap meant for a field.
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.92,
                  heightFactor: 0.92,
                  child: Opacity(
                    opacity: 0.07,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        StudentPalette.brandBlue,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/images/manara-logo-mark-transparent.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final areaSize = constraints.biggest;
                // The side art is sized from the screen, not from whatever
                // margin the illustration happens to leave over. On a
                // 16:9 desktop window the books are much narrower than the
                // screen so there was margin to spare, but a 4:3 tablet in
                // landscape leaves almost none — which is why the guide and
                // the pencil vanished there. So the reserve is decided
                // first and the illustration is laid out inside what is
                // left, which means the characters always have their place
                // and simply scale down instead of disappearing.
                final portrait = areaSize.height > areaSize.width;

                const edge = 12.0;
                // The HUD chips sit top-right; everything keeps clear of
                // them.
                const topReserve = 52.0;

                // The two orientations get genuinely different layouts,
                // because the same one cannot serve both.
                //
                // Landscape is a left/right pair: the guide holds a column
                // on the left and the books take the rest.
                //
                // Portrait used to do the same, and that was the bug — on
                // a tall narrow screen a third of the width went to her,
                // leaving the books a strip too small to read or tap. So
                // portrait stacks instead: she stands in a band across the
                // top as a greeter, and the books get almost the whole
                // width beneath her, which is where they belong on a phone
                // held upright.
                final double girlColumn;
                final double mascotHeight;
                final Rect imageRect;

                if (portrait) {
                  // She is sized off the width so she reads at a glance,
                  // then capped against the height so the band she stands
                  // in — her plus the bubble over her head — never eats
                  // the room the books need.
                  mascotHeight = math.min(
                    areaSize.width * 0.30,
                    (areaSize.height - topReserve - edge) * 0.26,
                  );
                  girlColumn = 0;
                  // Her band: her own height plus the speech bubble above
                  // her, which is roughly half as tall again.
                  final greeterBand = mascotHeight * 1.62 + 10;
                  final content = Size(
                    math.max(0.0, areaSize.width - edge * 2),
                    math.max(
                      0.0,
                      areaSize.height - topReserve - greeterBand - edge,
                    ),
                  );
                  // Drawn to 88% of the width it is offered, inside the
                  // 85-90% the design calls for — big enough to read the
                  // printed fields on, with just enough margin that it
                  // does not touch the screen edges.
                  final fitted = _containRect(content, _booksAspect);
                  final booksRect = Rect.fromCenter(
                    center: fitted.center,
                    width: fitted.width * 0.88,
                    height: fitted.height * 0.88,
                  );
                  imageRect =
                      booksRect.translate(edge, topReserve + greeterBand);
                } else {
                  girlColumn = (areaSize.width * 0.28)
                      .clamp(96.0, 460.0)
                      .toDouble();
                  mascotHeight = math.min(
                    girlColumn * 1.02,
                    (areaSize.height - topReserve - edge) * 0.66,
                  );
                  final content = Size(
                    math.max(0.0, areaSize.width - girlColumn - edge * 2),
                    math.max(0.0, areaSize.height - topReserve - edge),
                  );
                  final fitted = _containRect(content, _booksAspect);
                  final booksRect = Rect.fromCenter(
                    center: fitted.center,
                    width: fitted.width * 0.90,
                    height: fitted.height * 0.90,
                  );
                  // A nudge further right, bounded by the slack the
                  // contain fit actually left over — so it can never push
                  // the stack off its own half.
                  final slackX = math.max(0.0, content.width - booksRect.width);
                  final nudge = math.min(areaSize.width * 0.02, slackX / 2);
                  imageRect =
                      booksRect.translate(girlColumn + edge + nudge, topReserve);
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The guide is painted BEFORE the books, so if she ever
                    // overlaps the stack she passes behind it instead of
                    // covering a book's face and its field.
                    if (portrait)
                      Positioned(
                        top: topReserve,
                        left: edge,
                        right: edge,
                        child: Center(
                          child: _FlyAway(
                            away: _leaving,
                            angle: -0.32,
                            delay: const Duration(milliseconds: 120),
                            child: _MascotGuide(height: mascotHeight),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        left: edge,
                        bottom: edge,
                        width: math.max(0.0, girlColumn - edge),
                        child: _FlyAway(
                          away: _leaving,
                          angle: -0.32,
                          delay: const Duration(milliseconds: 120),
                          child: _MascotGuide(height: mascotHeight),
                        ),
                      ),
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
      _gradeSlot.place(
        imageRect,
        _BookDropdown(
          label: 'الصف الدراسي',
          icon: Icons.school_rounded,
          color: _gradeSlot.color,
          value: _grade,
          options: _gradeOptions,
          onSelected: _selectGrade,
        ),
      ),
      _atramSlot.place(
        imageRect,
        _BookDropdown(
          label: 'الفصل الدراسي / الترم',
          icon: Icons.calendar_month_rounded,
          color: _atramSlot.color,
          value: _atram,
          options: _atramOptions,
          onSelected: _selectAtram,
        ),
      ),
      _subjectSlot.place(
        imageRect,
        _BookDropdown(
          label: 'المادة التعليمية',
          icon: Icons.menu_book_rounded,
          color: _subjectSlot.color,
          value: _subject,
          options: _subjectOptions,
          onSelected: _selectSubject,
        ),
      ),
      _unitSlot.place(
        imageRect,
        chapters.length > 1
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
                  const SizedBox(width: 6),
                  Expanded(flex: 6, child: unitControl),
                ],
              )
            : unitControl,
      ),
      _lessonSlot.place(
        imageRect,
        _BookDropdown(
          label: 'الدرس',
          icon: Icons.play_lesson_rounded,
          color: _lessonSlot.color,
          value: _lesson?.lessonName,
          options: _lessonOptions,
          onSelected: _selectLessonNamed,
        ),
      ),
      _startSlot.place(
        imageRect,
        _StartAdventureButton(
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
      builder: (context, box) {
        // On a small screen a book's page — and therefore this control —
        // can get very narrow. The icon badge and the chevron are fixed
        // width, so they are dropped in that order once they no longer fit
        // alongside the value: the label text always wins the space. This
        // is what the runtime caught as a RIGHT OVERFLOWED error on a
        // narrow window, and dropping ornaments keeps the control legible
        // instead of hiding it.
        final showIcon = box.maxWidth >= 128;
        final showChevron = box.maxWidth >= 78;
        final pad = box.maxWidth >= 110 ? 9.0 : 5.0;
        final iconSize = (box.maxHeight * 0.34).clamp(11.0, 17.0).toDouble();
        final chevronSize =
            (box.maxHeight * 0.42).clamp(13.0, 20.0).toDouble();
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
              padding: EdgeInsets.symmetric(horizontal: pad),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                // Slightly translucent white so the page lines still read
                // faintly underneath — the field looks printed on the
                // paper rather than dropped on top of it. No drop shadow
                // for the same reason; the rim alone gives it its edge.
                color: Colors.white.withOpacity(0.86),
                border: Border.all(color: color.withOpacity(0.55), width: 1.3),
              ),
              child: Row(
                children: [
                  if (showIcon) ...[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, color: dark, size: iconSize),
                    ),
                    const SizedBox(width: 7),
                  ],
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
                  if (showChevron)
                    Icon(Icons.expand_more_rounded,
                        color: dark, size: chevronSize),
                ],
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

/// A piece of side art kept aloft by a continuous bob, optionally with a
/// tilt sway a quarter cycle behind it — that offset is what stops the
/// motion looking mechanical. Used for the pencil crew and the reading
/// pair, with different periods so the two never drift in lockstep.
/// How a character on the path moves.
///
/// The screen used to give every character the same sine drift, which read
/// as one lifeless motion repeated. Each style below has its own shape and
/// its own beat, so the characters look like separate creatures reacting
/// rather than parts of one mechanism.
enum _Motion {
  /// A hop with squash-and-stretch: stretched tall leaving the ground,
  /// squashed wide on landing, with a hang at the top.
  bounce,

  /// Stays put and rocks side to side, like a wave.
  wiggle,

  /// Breathes — a slow scale pulse with the faintest lift.
  pulse,

  /// Hovers: a slow, even rise and fall with no squash and the barest
  /// tilt. The quietest of the four, for a character that should feel
  /// alive without drawing the eye away from what it is pointing at.
  float,
}

class _FloatingArt extends StatefulWidget {
  const _FloatingArt({
    required this.asset,
    required this.size,
    this.baseAngle = 0,
    this.motion = _Motion.bounce,
    this.amount = 1,
    this.period = const Duration(milliseconds: 3400),
    this.phase = 0,
    super.key,
  });

  final String asset;
  final double size;
  final double baseAngle;
  final _Motion motion;

  /// Scales the whole movement, so one character can be livelier than
  /// another without needing its own style.
  final double amount;

  final Duration period;

  /// 0..1 offset into the cycle. Staggering the characters is what stops
  /// them moving in lockstep.
  final double phase;

  @override
  State<_FloatingArt> createState() => _FloatingArtState();
}

class _FloatingArtState extends State<_FloatingArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      widget.asset,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return Transform.rotate(angle: widget.baseAngle, child: image);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = (_controller.value + widget.phase) % 1.0;
        final turn = t * 2 * math.pi;
        final k = widget.amount;
        final s = widget.size;

        double dy = 0;
        double scaleX = 1;
        double scaleY = 1;
        double tilt = 0;

        switch (widget.motion) {
          case _Motion.bounce:
            // `sin` raised to a power spends longer near zero and peaks
            // sharply — a hop with a hang at the top, rather than the
            // even glide a plain sine gives.
            final hop = math.pow(math.sin(turn).abs(), 0.65).toDouble();
            dy = -hop * s * 0.16 * k;
            // Squash on the ground, stretch in the air.
            scaleY = 1 + (hop - 0.35) * 0.10 * k;
            scaleX = 1 - (hop - 0.35) * 0.10 * k;
            tilt = math.sin(turn * 2) * 0.03 * k;
          case _Motion.wiggle:
            tilt = math.sin(turn) * 0.13 * k;
            // A small counter-lift on the swing, so the rock has weight.
            dy = -math.sin(turn * 2).abs() * s * 0.03 * k;
          case _Motion.pulse:
            final breath = (math.sin(turn) + 1) / 2;
            scaleX = scaleY = 1 + breath * 0.07 * k;
            dy = -breath * s * 0.05 * k;
            tilt = math.sin(turn) * 0.02 * k;
          case _Motion.float:
            // A plain sine, so the rise and the fall take the same time
            // and neither end snaps — the character simply hovers.
            dy = math.sin(turn) * s * 0.045 * k;
            tilt = math.sin(turn) * 0.012 * k;
        }

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: widget.baseAngle + tilt,
            // Anchored to the feet so a character deforms without
            // sinking through the floor it stands on.
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
              child: child,
            ),
          ),
        );
      },
      child: image,
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
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The bubble breathes on its own, slower than the guide, so the
        // pair no longer moves as one rigid block.
        reduceMotion
            ? const _SpeechBubble(text: 'اختر صفك لنبدأ الرحلة يا بطل! ✨')
            : const _SpeechBubble(text: 'اختر صفك لنبدأ الرحلة يا بطل! ✨')
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                  begin: 1,
                  end: 1.035,
                  duration: 2600.ms,
                  curve: Curves.easeInOut,
                ),
        const SizedBox(height: 2),
        // She is the only character left in the scene, so she hovers
        // rather than waves: a slow even rise and fall that reads as calm
        // next to the books instead of competing with them.
        _FloatingArt(
          asset: 'assets/images/path_mascot.png',
          size: height,
          motion: _Motion.float,
          period: const Duration(milliseconds: 3600),
        ),
      ],
    );
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

/// Sends the guide flying off-screen on a diagonal and fades her out when
/// the student starts the adventure, so the exit reads as her heading off
/// rather than a layer being switched off.
class _FlyAway extends StatelessWidget {
  const _FlyAway({
    required this.away,
    required this.child,
    this.angle = 0,
    this.delay = Duration.zero,
  });

  /// Flipped once. While false the child is drawn untouched, so the idle
  /// motion underneath is unaffected.
  final bool away;

  final Widget child;

  /// Direction of travel, in radians from straight up — the guide and the
  /// pencil lean opposite ways.
  final double angle;

  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (!away) return child;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return const SizedBox.shrink();
    }
    const travel = Duration(milliseconds: 520);
    // Up and out along `angle`, shrinking and fading as it goes.
    final dx = math.sin(angle) * 420;
    final dy = -math.cos(angle) * 420;
    return child
        .animate(delay: delay)
        .move(
          begin: Offset.zero,
          end: Offset(dx, dy),
          duration: travel,
          curve: Curves.easeInBack,
        )
        .fadeOut(duration: travel, curve: Curves.easeIn)
        .scaleXY(begin: 1, end: 0.72, duration: travel)
        .rotate(begin: 0, end: angle * 0.5, duration: travel);
  }
}
