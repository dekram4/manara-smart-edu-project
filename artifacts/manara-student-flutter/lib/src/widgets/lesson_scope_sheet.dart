import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../services/student_settings.dart';
import '../theme/student_theme.dart';
import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';

/// Picks a lesson by stepping down the academic hierarchy the teacher
/// registered: المادة, الفصل, الوحدة, then الدرس.
///
/// The labels are the teacher's own, from the Academic Settings screen.
/// `term` is الفصل — the level once called الترم is gone from the whole
/// system, so the subject now sits directly under the grade and every
/// step here is one the student actually makes.
///
/// Presented as a sheet of soft choice cards rather than a stack of
/// dropdowns. A dropdown hides its options until it is opened and shows
/// one at a time; a child choosing between four subjects should see four
/// subjects. Each step only appears once the one above it has an answer,
/// so the sheet grows as the student works down it instead of showing
/// four dead menus at once.
///
/// Grade and class are not offered. Those are who the student is —
/// registered against their account — not something to pick from a menu;
/// they are carried through from the current scope unchanged.
///
/// ── رحلةٌ لا استمارة ──
/// كلُّ مستوىً بلونه ورمزه، وشريطُ تقدّمٍ بأربع محطّاتٍ يمتلئ مع كل اختيار،
/// والمستوى التالي ينزلق إلى مكانه ويُمرَّر إليه تلقائياً، والبطاقةُ تنضغط تحت
/// الإصبع وتُعلّم اختيارها بعلامةٍ تقفز، ومسارُ الطالب يُقرأ في أسفل الورقة،
/// وزرُّ التأكيد ينبض حين يكتمل. وكلُّ حركةٍ متكرّرة تسكن لمن طلب تقليل الحركة.
class LessonScopeSheet extends StatefulWidget {
  const LessonScopeSheet({
    required this.data,
    required this.current,
    this.allowsSubject,
    super.key,
  });

  final AcademicSelectionData data;
  final AcademicContext? current;

  /// ما يُسمح للطالب بمادته. الغياب يعني «كل المواد».
  ///
  /// تُمرَّر قاعدةً لا قائمةً: القاعدة تسكن في حساب الطالب، وتمريرها
  /// كما هي يمنع أن تُحسب هنا مرة وهناك مرة فتختلفا.
  final bool Function(String subject)? allowsSubject;

  /// Opens the sheet and returns the chosen scope, or null if the student
  /// backed out.
  static Future<AcademicContext?> show(
    BuildContext context, {
    required AcademicSelectionData data,
    required AcademicContext? current,
    bool Function(String subject)? allowsSubject,
  }) {
    return showModalBottomSheet<AcademicContext>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // ‏الورقةُ تصعد بمنحنى نابض لا بخطٍّ مستقيم.
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        reverseDuration: const Duration(milliseconds: 220),
      ),
      builder: (_) => LessonScopeSheet(
        data: data,
        current: current,
        allowsSubject: allowsSubject,
      ),
    );
  }

  @override
  State<LessonScopeSheet> createState() => _LessonScopeSheetState();
}

/// لونُ كل مستوىً ورمزُه: الطفلُ يعرف أين هو من اللون قبل أن يقرأ.
class _Level {
  const _Level(this.color, this.emoji, this.icon);

  final Color color;
  final String emoji;
  final IconData icon;

  static const subject = _Level(Color(0xFF0E7490), '📚', Icons.menu_book_rounded);
  static const term = _Level(Color(0xFF7C3AED), '🗂️', Icons.class_rounded);
  static const unit = _Level(Color(0xFFDB2777), '🧩', Icons.layers_rounded);
  static const lesson = _Level(Color(0xFFEA8A00), '🎬', Icons.play_lesson_rounded);

  static const all = [subject, term, unit, lesson];
}

class _LessonScopeSheetState extends State<LessonScopeSheet> {
  String? _grade;
  String? _subject;
  String? _term;
  String? _unit;
  LessonContent? _lesson;

  final _scroll = ScrollController();

  /// مفتاحُ كل مستوى، ليُمرَّر إليه حين يظهر.
  final _stepKeys = List.generate(4, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    // Opens on what the student already has, so changing the unit does
    // not mean re-picking the subject and term first.
    // Grade is the student's own registration, not a choice: it is
    // carried through untouched and never offered as a step.
    _grade = current?.grade ?? widget.data.grades.firstOrNull;
    _subject = current?.subject;
    _term = current?.term;
    _unit = current?.unit;
    _lesson = current?.selectedLesson;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _still => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  // The four levels, named as the teacher's own Academic Settings screen
  // names them, each filtering the real registered paths so no combination
  // is offered that does not exist.
  List<String> get _subjects {
    if (_grade == null) return const [];
    final all = widget.data.subjectsFor(grade: _grade!);
    final allows = widget.allowsSubject;
    return allows == null ? all : all.where(allows).toList();
  }

  List<String> get _terms => (_grade == null || _subject == null)
      ? const []
      : widget.data.termsFor(grade: _grade!, subject: _subject!);

  List<String> get _units =>
      (_grade == null || _subject == null || _term == null)
          ? const []
          : widget.data.unitsFor(
              grade: _grade!,
              subject: _subject!,
              term: _term!,
            );

  List<LessonContent> get _lessons =>
      (_grade == null || _subject == null || _term == null || _unit == null)
          ? const []
          : widget.data.lessonsFor(
              grade: _grade!,
              subject: _subject!,
              term: _term!,
              unit: _unit!,
            );

  /// كم مستوىً اكتمل: ٠ إلى ٤.
  int get _done => _lesson != null
      ? 4
      : _unit != null
          ? 3
          : _term != null
              ? 2
              : _subject != null
                  ? 1
                  : 0;

  /// يختار، ثم يُمرّر إلى المستوى التالي الذي ظهر للتوّ.
  void _pick(int nextStep, VoidCallback change) {
    StudentSoundService.instance.play(StudentSoundCue.answerSelected);
    HapticFeedback.selectionClick();
    setState(change);
    if (nextStep >= _stepKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _stepKeys[nextStep].currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: _still ? Duration.zero : const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    });
  }

  void _confirm() {
    HapticFeedback.mediumImpact();
    StudentSoundService.instance.play(StudentSoundCue.success);
    Navigator.of(context).pop(
      AcademicContext(
        grade: _grade!,
        subject: _subject!,
        term: _term!,
        unit: _unit!,
        selectedLesson: _lesson!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dark = StudentSurface.isDark(context);
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Container(
        // Never taller than most of the screen, so the sheet is always
        // recognisable as a sheet with the hub behind it.
        constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: dark
                ? const [Color(0xFF141821), Color(0xFF0E1117)]
                : const [Color(0xFFFFF6E7), Color(0xFFEFF6FA)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _grabber(),
              _header(),
              _progress(),
              Flexible(
                child: SingleChildScrollView(
                  controller: _scroll,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // All four levels, each shown and each depending on
                        // the one above it. Nothing is picked silently.
                        _step<String>(
                          index: 0,
                          title: tr('scope.subject'),
                          items: _subjects,
                          labelOf: (value) => value,
                          selected: _subject,
                          isSame: (a, b) => a == b,
                          onPick: (value) => _pick(1, () {
                            _subject = value;
                            _term = null;
                            _unit = null;
                            _lesson = null;
                          }),
                        ),
                        // Each step appears only once the one above it has
                        // an answer. A student is never looking at a row of
                        // empty menus wondering which to try first.
                        if (_subject != null)
                          _step<String>(
                            index: 1,
                            title: tr('scope.term'),
                            items: _terms,
                            labelOf: (value) => value,
                            selected: _term,
                            isSame: (a, b) => a == b,
                            onPick: (value) => _pick(2, () {
                              _term = value;
                              _unit = null;
                              _lesson = null;
                            }),
                          ),
                        if (_term != null)
                          _step<String>(
                            index: 2,
                            title: tr('scope.unit'),
                            items: _units,
                            labelOf: (value) => value,
                            selected: _unit,
                            isSame: (a, b) => a == b,
                            onPick: (value) => _pick(3, () {
                              _unit = value;
                              _lesson = null;
                            }),
                          ),
                        if (_unit != null)
                          _step<LessonContent>(
                            index: 3,
                            title: tr('scope.lesson'),
                            items: _lessons,
                            labelOf: (value) => value.lessonName,
                            selected: _lesson,
                            isSame: (a, b) => a.id == b.id,
                            onPick: (value) => _pick(4, () => _lesson = value),
                          ),
                      ],
                  ),
                ),
              ),
              _confirmBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grabber() => Container(
        width: 46,
        height: 5,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          borderRadius: BorderRadius.circular(4),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
        child: Row(
          children: [
            // ‏أيقونةُ المسار تتأرجح بلطفٍ مرّةً عند الفتح.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: _still ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, t, child) => Transform.rotate(
                angle: (1 - t) * -0.5,
                child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E7490), Color(0xFF14B8A6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0E7490).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.alt_route_rounded, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('scope.title'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: StudentSurface.ink(context),
                    ),
                  ),
                  Text(
                    tr('scope.hint'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: StudentSurface.mutedInk(context),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              tooltip: tr('action.close'),
            ),
          ],
        ),
      );

  /// أربعُ محطّاتٍ موصولة: تمتلئ بلون مستواها كلما اكتمل اختيار.
  Widget _progress() {
    final done = _done;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 5, color: const Color(0x1A00304A)),
                      AnimatedFractionallySizedBox(
                        duration: _still ? Duration.zero : const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic,
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: done >= i ? 1 : 0,
                        child: Container(height: 5, color: _Level.all[i].color),
                      ),
                    ],
                  ),
                ),
              ),
            AnimatedContainer(
              duration: _still ? Duration.zero : const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              width: done > i ? 30 : 26,
              height: done > i ? 30 : 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done > i ? _Level.all[i].color : StudentSurface.card(context),
                border: Border.all(
                  color: done == i ? _Level.all[i].color : const Color(0x2200304A),
                  width: done == i ? 2.5 : 1.2,
                ),
                boxShadow: done > i
                    ? [
                        BoxShadow(
                          color: _Level.all[i].color.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: done > i
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : Text(_Level.all[i].emoji, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _step<T>({
    required int index,
    required String title,
    required List<T> items,
    required String Function(T) labelOf,
    required T? selected,
    required bool Function(T, T) isSame,
    required ValueChanged<T> onPick,
  }) {
    final level = _Level.all[index];
    // ‏المستوى الجديد ينزلق من تحت ويظهر — مرّةً واحدة حين يُضاف.
    return TweenAnimationBuilder<double>(
      key: _stepKeys[index],
      tween: Tween(begin: _still ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          color: level.color.withValues(alpha: StudentSurface.isDark(context) ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: level.color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: level.color, shape: BoxShape.circle),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(level.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: StudentSurface.ink(context),
                    ),
                  ),
                ),
                Icon(level.icon, size: 24, color: level.color),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  tr('scope.noOptions'),
                  style: const TextStyle(
                    color: Color(0xFF8092A8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _ScopeChoice(
                      label: labelOf(items[i]),
                      // ‏كلُّ بطاقةٍ بلونها ورمزها: الطفلُ يعرفها قبل أن يقرأ.
                      color: _tileColors[(index + i) % _tileColors.length],
                      emoji: _emojiFor(labelOf(items[i]), level.emoji),
                      chosen: selected != null && isSame(items[i], selected),
                      // ‏البطاقاتُ تدخل متتابعةً، كلٌّ بعد أختها بلحظة.
                      delay: _still ? Duration.zero : Duration(milliseconds: 40 * i.clamp(0, 10)),
                      still: _still,
                      onTap: () => onPick(items[i]),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _confirmBar() {
    final ready = _lesson != null;
    final trail = [_subject, _term, _unit].whereType<String>().toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        // ‏كانت بيضاءَ ثابتة، فتلمع في الوضع الداكن.
        color: StudentSurface.card(context),
        border: const Border(top: BorderSide(color: Color(0x1400304A))),
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: _still ? Duration.zero : const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.3), end: Offset.zero)
                      .animate(animation),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey('${_lesson?.id}|${trail.join('|')}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (trail.isNotEmpty)
                    Text(
                      trail.join('  ›  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: StudentSurface.mutedInk(context),
                      ),
                    ),
                  Text(
                    ready ? '🎬 ${_lesson!.lessonName}' : tr('scope.incomplete'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: ready ? StudentSurface.ink(context) : const Color(0xFF8092A8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _ConfirmButton(
            ready: ready,
            still: _still,
            // Stays disabled until a real lesson has been reached, so the
            // app can never be handed a half-built scope.
            onPressed: ready ? _confirm : null,
          ),
        ],
      ),
    );
  }
}

/// ألوانُ بطاقات الاختيار، بالتناوب: زاهيةٌ لا باهتة.
const _tileColors = [
  Color(0xFF0EA5E9),
  Color(0xFF8B5CF6),
  Color(0xFFF97316),
  Color(0xFF10B981),
  Color(0xFFEC4899),
  Color(0xFFEAB308),
  Color(0xFF6366F1),
  Color(0xFF14B8A6),
];

/// رمزٌ كبيرٌ يدلّ على المادة أو الدرس من اسمه، وإلا رمزُ المستوى.
String _emojiFor(String label, String fallback) {
  final key = label
      .replaceAll(RegExp('[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .toLowerCase();
  const table = [
    ('قران', '📖'),
    ('سور', '📖'),
    ('اسلام', '🕌'),
    ('توحيد', '🕌'),
    ('حديث', '🕌'),
    ('انجليز', '🔠'),
    ('english', '🔠'),
    ('حروف', '🔤'),
    ('عربي', '🔤'),
    ('لغت', '🔤'),
    ('ارقام', '🔢'),
    ('رياضيات', '🔢'),
    ('حساب', '🔢'),
    ('math', '🔢'),
    ('علوم', '🔬'),
    ('science', '🔬'),
    ('فن', '🎨'),
    ('رسم', '🎨'),
    ('موسيق', '🎵'),
    ('رياض', '⚽'),
    ('بدني', '⚽'),
    ('اجتماع', '🌍'),
    ('وطن', '🌍'),
    ('حاسب', '💻'),
    ('رقمي', '💻'),
    ('مهارات', '🧠'),
    ('حيوان', '🦁'),
    ('نبات', '🌱'),
    ('الوان', '🌈'),
    ('اشكال', '🔷'),
  ];
  for (final (needle, emoji) in table) {
    if (key.contains(needle)) return emoji;
  }
  return fallback;
}

/// بطاقةُ اختيارٍ كبيرة: رمزٌ كبير، واسمٌ واضح، ولونٌ زاهٍ — تنضغط تحت
/// الإصبع، وتمتلئ بلونها حين تُختار، وعلامتُها تقفز.
class _ScopeChoice extends StatefulWidget {
  const _ScopeChoice({
    required this.label,
    required this.color,
    required this.emoji,
    required this.chosen,
    required this.delay,
    required this.still,
    required this.onTap,
  });

  final String label;
  final Color color;
  final String emoji;
  final bool chosen;
  final Duration delay;
  final bool still;
  final VoidCallback onTap;

  @override
  State<_ScopeChoice> createState() => _ScopeChoiceState();
}

class _ScopeChoiceState extends State<_ScopeChoice> {
  bool _down = false;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (widget.still || widget.delay == Duration.zero) {
      _shown = true;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chosen = widget.chosen;
    final color = widget.color;
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      child: AnimatedScale(
        scale: _down ? 0.94 : (_shown ? 1 : 0.9),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Semantics(
          button: true,
          selected: chosen,
          label: widget.label,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _down = true),
            onTapCancel: () => setState(() => _down = false),
            onTapUp: (_) => setState(() => _down = false),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 132,
              constraints: const BoxConstraints(minHeight: 118),
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: chosen
                      ? [color, Color.lerp(color, Colors.black, 0.18)!]
                      : [
                          Color.lerp(color, Colors.white, 0.80)!,
                          Color.lerp(color, Colors.white, 0.62)!,
                        ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: chosen ? Colors.white : color.withValues(alpha: 0.55),
                  width: chosen ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: chosen ? 0.45 : 0.22),
                    blurRadius: chosen ? 16 : 8,
                    offset: Offset(0, chosen ? 7 : 4),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: chosen ? Colors.white.withValues(alpha: 0.25) : Colors.white,
                          boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: Text(widget.emoji, style: const TextStyle(fontSize: 32)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          color: chosen ? Colors.white : Color.lerp(color, Colors.black, 0.55),
                        ),
                      ),
                    ],
                  ),
                  PositionedDirectional(
                    top: -6,
                    end: -4,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
                        child: child,
                      ),
                      child: chosen
                          ? Container(
                              key: const ValueKey('on'),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Icon(Icons.check_circle_rounded, size: 26, color: color),
                            )
                          : const SizedBox(key: ValueKey('off')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// زرُّ «تأكيد»: معطّلٌ حتى يُختار درس، ثم ينبض نبضاً هادئاً يدعو إليه.
class _ConfirmButton extends StatefulWidget {
  const _ConfirmButton({
    required this.ready,
    required this.still,
    required this.onPressed,
  });

  final bool ready;
  final bool still;
  final VoidCallback? onPressed;

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_ConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.ready && !widget.still) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: 1 + 0.05 * Curves.easeInOut.transform(_pulse.value),
        child: child,
      ),
      child: FilledButton.icon(
        onPressed: widget.onPressed,
        icon: const Icon(Icons.rocket_launch_rounded),
        label: Text(
          tr('action.confirm'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0E7490),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: widget.ready ? 4 : 0,
          shadowColor: const Color(0xFF0E7490),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
      ),
    );
  }
}

/// زرُّ «تغيير الدرس» في رأس الواجهة: كبسولةٌ بتدرّج، وتوهّجٌ يتنفّس بهدوء يدلّ
/// عليه، وتنضغط تحت الإصبع، وتدور أيقونةُ المسار مع الضغطة.
///
/// [narrow] للشريط الضيّق: الأيقونةُ وحدها في دائرة، كما كان — كي لا يفيض الشريط.
class ChangeLessonButton extends StatefulWidget {
  const ChangeLessonButton({
    required this.label,
    required this.onPressed,
    this.narrow = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool narrow;

  @override
  State<ChangeLessonButton> createState() => _ChangeLessonButtonState();
}

class _ChangeLessonButtonState extends State<ChangeLessonButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _down = false;
  int _turns = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const from = Color(0xFF0E5F6B);
    const to = Color(0xFF14B8A6);
    final icon = AnimatedRotation(
      turns: _turns * 0.5,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      child: Text('🎒', style: TextStyle(fontSize: widget.narrow ? 22 : 20)),
    );
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _turns += 1);
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _down ? 0.92 : 1,
          duration: const Duration(milliseconds: 130),
          child: AnimatedBuilder(
            animation: _breath,
            builder: (context, child) {
              final glow = Curves.easeInOut.transform(_breath.value);
              return Container(
                padding: widget.narrow
                    ? const EdgeInsets.all(10)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [from, to]),
                  borderRadius: BorderRadius.circular(widget.narrow ? 999 : 22),
                  boxShadow: [
                    BoxShadow(
                      color: to.withValues(alpha: 0.25 + 0.25 * glow),
                      blurRadius: 8 + 10 * glow,
                      spreadRadius: glow * 1.5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: widget.narrow
                ? icon
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 6),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
