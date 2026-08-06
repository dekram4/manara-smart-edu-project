import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/academic_scope_selector.dart';
import 'video_player_screen.dart';

class LessonLibrary extends StatefulWidget {
  const LessonLibrary({super.key, this.initialSelection});
  final AcademicScopeSelection? initialSelection;

  @override
  State<LessonLibrary> createState() => _LessonLibraryState();
}

class _LessonLibraryState extends State<LessonLibrary> {
  late AcademicScopeSelection selection;

  @override
  void initState() {
    super.initState();
    selection = widget.initialSelection ?? const AcademicScopeSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final allLessons = state.lessonsForCurrentRole;
        final paths = state.academicPathsForCurrentRole;
        final lessons = allLessons.where(_matchesSelection).toList();
        return Scaffold(
          appBar: AppBar(
              title: const Text('دروسي',
                  style: TextStyle(fontWeight: FontWeight.w900))),
          body: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              const Text('اختر مادة وابدأ مغامرة جديدة',
                  style: TextStyle(color: ManaraColors.muted, fontSize: 16)),
              const SizedBox(height: 16),
              AcademicScopeSelector(
                paths: paths,
                initialGrade: state.student?.primaryGrade ?? '',
                initialSelection: selection,
                onChanged: (next) => setState(() => selection = next),
              ),
              const SizedBox(height: 20),
              if (selection.subject.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ManaraColors.lavender,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'المسار المختار: ${_selectionLabel()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 20),
              if (lessons.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                      child: Text('لا توجد دروس متاحة حالياً',
                          style: TextStyle(
                              color: ManaraColors.muted,
                              fontWeight: FontWeight.w700))),
                )
              else
                ...lessons.map((lesson) => _LessonCard(lesson: lesson)),
            ],
          ),
        );
      },
    );
  }

  bool _matchesSelection(Lesson lesson) {
    bool matches(String selected, String actual) =>
        selected.isEmpty ||
        actual.trim().isEmpty ||
        selected.trim().toLowerCase() == actual.trim().toLowerCase();

    return matches(selection.grade, lesson.grade) &&
        matches(selection.atram, lesson.atram) &&
        matches(selection.subject, lesson.subject) &&
        matches(selection.term, lesson.term) &&
        matches(selection.unit, lesson.unit);
  }

  String _selectionLabel() => [
        selection.grade,
        selection.atram,
        selection.subject,
        selection.term,
        selection.unit,
      ].where((value) => value.isNotEmpty).join(' • ');
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LessonDetail(lesson: lesson))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: lesson.subject == 'العلوم' ? ManaraColors.mint.withOpacity(.2) : ManaraColors.orange.withOpacity(.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(child: Text(lesson.subject == 'العلوم' ? '🧬' : '🔢', style: const TextStyle(fontSize: 30))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text('${lesson.subject} • ${lesson.unit}', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: ManaraColors.purple),
            ],
          ),
        ),
      ),
    );
  }
}

class LessonDetail extends StatelessWidget {
  const LessonDetail({super.key, required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final lessonVideoUrl = lesson.videoUrl?.trim().isNotEmpty == true
        ? lesson.videoUrl!.trim()
        : lesson.explanationVideoUrl.trim();
    final completed = context.select<AppState, bool>(
      (state) => state.isLessonCompleted(lesson.id),
    );
    return Scaffold(
      appBar: AppBar(title: Text(lesson.subject, style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(colors: [ManaraColors.deepPurple, ManaraColors.blue]),
            ),
            child: const Center(child: Text('📚', style: TextStyle(fontSize: 72))),
          ),
          const SizedBox(height: 22),
          Text(lesson.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(lesson.content, style: const TextStyle(fontSize: 17, height: 1.7, color: ManaraColors.ink)),
          const SizedBox(height: 24),
          if (lessonVideoUrl.isNotEmpty) ...[
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(
                      video: VideoLesson(
                        id: 'lesson-video-${lesson.id}',
                        title: lesson.title,
                        subject: lesson.subject,
                        emoji: '🎬',
                        duration: 'فيديو الدرس',
                        url: lessonVideoUrl,
                        teacherId: lesson.teacherId,
                        createdBy: lesson.createdBy,
                        createdByName: lesson.createdByName,
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('مشاهدة فيديو الشرح'),
            ),
            const SizedBox(height: 12),
          ],
          if (lesson.avatarInteractionUrl.trim().isNotEmpty) ...[
            OutlinedButton.icon(
              onPressed: () => _openLessonLink(
                context,
                lesson.avatarInteractionUrl,
                action: 'avatar_interaction_open',
              ),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('فتح التفاعل مع الشخصية'),
            ),
            const SizedBox(height: 12),
          ],
          if (lesson.liveMeetingUrl.trim().isNotEmpty) ...[
            OutlinedButton.icon(
              onPressed: () => _openLessonLink(
                context,
                lesson.liveMeetingUrl,
                action: 'live_meeting_join',
              ),
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('الانضمام إلى الاجتماع المباشر'),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: completed ? null : () => _completeLesson(context),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              completed
                  ? 'تم إكمال الدرس'
                  : 'أنهيت الدرس واحصل على المكافأة',
            ),
          ),
        ],
      ),
    );
  }

  void _completeLesson(BuildContext context) {
    context.read<AppState>().completeLesson(
          lessonId: lesson.id,
          subject: lesson.subject,
          unit: lesson.unit,
        );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ممتاز! حصلت على 50 XP و5 جواهر 🌟')));
  }

  Future<void> _openLessonLink(
    BuildContext context,
    String rawUrl, {
    required String action,
  }) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرابط غير صالح')),
      );
      return;
    }
    context.read<AppState>().recordInteraction(
          action: action,
          lessonId: lesson.id,
          grade: lesson.grade,
          subject: lesson.subject,
          unit: lesson.unit,
        );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط، تحقق من الاتصال')),
      );
    }
  }
}