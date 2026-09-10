import 'package:flutter/material.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../services/student_sound_service.dart';

/// Picks a lesson by stepping down the academic hierarchy the teacher
/// registered: subject, then term, then unit, then the lesson itself.
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
class LessonScopeSheet extends StatefulWidget {
  const LessonScopeSheet({
    required this.data,
    required this.current,
    super.key,
  });

  final AcademicSelectionData data;
  final AcademicContext? current;

  /// Opens the sheet and returns the chosen scope, or null if the student
  /// backed out.
  static Future<AcademicContext?> show(
    BuildContext context, {
    required AcademicSelectionData data,
    required AcademicContext? current,
  }) {
    return showModalBottomSheet<AcademicContext>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LessonScopeSheet(data: data, current: current),
    );
  }

  @override
  State<LessonScopeSheet> createState() => _LessonScopeSheetState();
}

class _LessonScopeSheetState extends State<LessonScopeSheet> {
  String? _grade;
  String? _atram;
  String? _subject;
  String? _term;
  String? _unit;
  LessonContent? _lesson;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    // Opens on what the student already has, so changing the unit does
    // not mean re-picking the subject and term first.
    _grade = current?.grade ?? widget.data.grades.firstOrNull;
    if (_grade != null) {
      _atram = current?.atram ?? widget.data.atramsFor(_grade!).firstOrNull;
    }
    _subject = current?.subject;
    _term = current?.term;
    _unit = current?.unit;
    _lesson = current?.selectedLesson;
  }

  List<String> get _subjects => (_grade == null || _atram == null)
      ? const []
      : widget.data.subjectsFor(grade: _grade!, atram: _atram!);

  List<String> get _terms =>
      (_grade == null || _atram == null || _subject == null)
          ? const []
          : widget.data
              .termsFor(grade: _grade!, atram: _atram!, subject: _subject!);

  List<String> get _units =>
      (_grade == null || _atram == null || _subject == null || _term == null)
          ? const []
          : widget.data.unitsFor(
              grade: _grade!,
              atram: _atram!,
              subject: _subject!,
              term: _term!,
            );

  List<LessonContent> get _lessons => (_grade == null ||
          _atram == null ||
          _subject == null ||
          _term == null ||
          _unit == null)
      ? const []
      : widget.data.lessonsFor(
          grade: _grade!,
          atram: _atram!,
          subject: _subject!,
          term: _term!,
          unit: _unit!,
        );

  void _pick(VoidCallback change) {
    StudentSoundService.instance.play(StudentSoundCue.answerSelected);
    setState(change);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        // Never taller than most of the screen, so the sheet is always
        // recognisable as a sheet with the hub behind it.
        constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFFFF6E7), Color(0xFFEFF6FA)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _grabber(),
              _header(),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _step<String>(
                        step: 1,
                        title: 'المادة',
                        icon: Icons.menu_book_rounded,
                        items: _subjects,
                        labelOf: (value) => value,
                        selected: _subject,
                        isSame: (a, b) => a == b,
                        onPick: (value) => _pick(() {
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
                          step: 2,
                          title: 'الترم',
                          icon: Icons.event_note_rounded,
                          items: _terms,
                          labelOf: (value) => value,
                          selected: _term,
                          isSame: (a, b) => a == b,
                          onPick: (value) => _pick(() {
                            _term = value;
                            _unit = null;
                            _lesson = null;
                          }),
                        ),
                      if (_term != null)
                        _step<String>(
                          step: 3,
                          title: 'الوحدة',
                          icon: Icons.layers_rounded,
                          items: _units,
                          labelOf: (value) => value,
                          selected: _unit,
                          isSame: (a, b) => a == b,
                          onPick: (value) => _pick(() {
                            _unit = value;
                            _lesson = null;
                          }),
                        ),
                      if (_unit != null)
                        _step<LessonContent>(
                          step: 4,
                          title: 'الدرس',
                          icon: Icons.play_lesson_rounded,
                          items: _lessons,
                          labelOf: (value) => value.lessonName,
                          selected: _lesson,
                          isSame: (a, b) => a.id == b.id,
                          onPick: (value) => _pick(() => _lesson = value),
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
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF0E5F6B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.alt_route_rounded,
                color: Color(0xFF0E5F6B),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تغيير الدرس',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0E3A52),
                    ),
                  ),
                  Text(
                    'اختر مادتك ثم الترم والوحدة والدرس.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5680AC),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'إغلاق',
            ),
          ],
        ),
      );

  Widget _step<T>({
    required int step,
    required String title,
    required IconData icon,
    required List<T> items,
    required String Function(T) labelOf,
    required T? selected,
    required bool Function(T, T) isSame,
    required ValueChanged<T> onPick,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: const Color(0xFF0E5F6B),
                child: Text(
                  '$step',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: const Color(0xFF0E3A52)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0E3A52),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'لا توجد خيارات هنا بعد.',
                style: TextStyle(
                  color: Color(0xFF8092A8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final item in items)
                  _choice(
                    label: labelOf(item),
                    chosen: selected != null && isSame(item, selected),
                    onTap: () => onPick(item),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _choice({
    required String label,
    required bool chosen,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: chosen ? const Color(0xFF0E5F6B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: chosen ? const Color(0xFF0E5F6B) : const Color(0x2200304A),
              width: chosen ? 2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: chosen
                    ? const Color(0xFF0E5F6B).withOpacity(0.28)
                    : const Color(0x11000000),
                blurRadius: chosen ? 14 : 6,
                offset: Offset(0, chosen ? 6 : 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chosen) ...[
                const Icon(Icons.check_rounded, size: 17, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: chosen ? Colors.white : const Color(0xFF0E3A52),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _confirmBar() {
    final ready = _lesson != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x1400304A))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ready
                  ? _lesson!.lessonName
                  : 'أكمل الاختيار للوصول إلى الدرس',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: ready ? const Color(0xFF0E3A52) : const Color(0xFF8092A8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            // Stays disabled until a real lesson has been reached, so the
            // app can never be handed a half-built scope.
            onPressed: !ready
                ? null
                : () => Navigator.of(context).pop(
                      AcademicContext(
                        grade: _grade!,
                        atram: _atram!,
                        subject: _subject!,
                        term: _term!,
                        unit: _unit!,
                        selectedLesson: _lesson!,
                      ),
                    ),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text(
              'تثبيت ومتابعة',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0E5F6B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
