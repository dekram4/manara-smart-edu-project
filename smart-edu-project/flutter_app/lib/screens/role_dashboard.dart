import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'account_management.dart';
import 'certificates_screen.dart';
import 'children_screen.dart';
import 'content_management_screen.dart';
import 'lesson_library.dart';
import 'quiz_manager.dart';
import 'records_manager.dart';
import 'reports_screen.dart';
import 'teacher_management_screen.dart';

class RoleDashboard extends StatelessWidget {
  const RoleDashboard({super.key, required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final isTeacher = role == UserRole.teacher;
        final isGuardian = role == UserRole.guardian;
        final linkedChildren = state.guardian?.childIds.length ?? 0;
        final visibleStudents = state.studentsForCurrentRole;
        final visibleLessons = role == UserRole.admin
            ? state.lessons
            : state.lessonsForCurrentRole;
        final visibleResults = state.quizResultsForCurrentRole;
        final visibleInteractions = state.interactionsForCurrentRole;
        final visibleCertificates = state.certificatesForCurrentRole;
        final visibleVideos = state.videosForCurrentRole;
        final cards = isTeacher
            ? [
                ('الطلاب المرتبطون', '${visibleStudents.length}', '👨‍🎓', ManaraColors.blue, const RecordsManager(type: RecordType.students)),
                ('الدروس', '${visibleLessons.length}', '📚', ManaraColors.purple, const ContentManagementScreen()),
                ('الفيديوهات', '${visibleVideos.length}', '🎬', ManaraColors.orange, const RecordsManager(type: RecordType.videos)),
                ('الاختبارات', '${state.quizzesForCurrentRole.length}', '🧠', ManaraColors.mint, const QuizManager()),
              ]
            : isGuardian
                ? [
                    ('الأبناء المرتبطون', '$linkedChildren', '👨‍👩‍👧', ManaraColors.mint, const ChildrenScreen()),
                    ('نتائج الاختبارات', '${visibleResults.length}', '📝', ManaraColors.orange, const ReportsScreen()),
                    ('الشهادات', '${visibleCertificates.length}', '🏆', ManaraColors.purple, const CertificatesScreen()),
                    ('الدروس المتاحة', '${state.lessonsForCurrentRole.length}', '📚', ManaraColors.blue, const LessonLibrary()),
                  ]
                : [
                    ('الطلاب', '${state.students.length}', '👨‍🎓', ManaraColors.blue, const AccountManagementScreen()),
                    ('المعلمون', '${state.teachers.length}', '👩‍🏫', ManaraColors.purple, const TeacherManagementScreen()),
                    ('المحتوى', '${state.lessons.length}', '📚', ManaraColors.orange, const ContentManagementScreen()),
                    ('الاختبارات', '${state.quizzes.length}', '🧠', ManaraColors.mint, const QuizManager()),
                    ('النتائج', '${visibleResults.length}', '📈', ManaraColors.blue, const ReportsScreen()),
                    ('النشاطات', '${visibleInteractions.length}', '⚡', ManaraColors.orange, const ReportsScreen()),
                  ];
        return CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
      SliverPadding(padding: const EdgeInsets.all(22), sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('مرحباً بك في لوحة ${role.label}', style: const TextStyle(color: ManaraColors.muted)),
        const SizedBox(height: 5),
        const Text('كل شيء تحت السيطرة ✨', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 22),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [ManaraColors.deepPurple, ManaraColors.purple]), borderRadius: BorderRadius.circular(26)), child: Row(children: [Text(role.icon, style: const TextStyle(fontSize: 44)), const SizedBox(width: 14), Expanded(child: Text(isTeacher ? 'أدر حصصك وامنح طلابك تجربة تعلم ممتعة' : isGuardian ? 'تابع رحلة أبنائك التعليمية أولاً بأول' : 'أدر المنصة التعليمية بكل سهولة', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)))])),
        const SizedBox(height: 24),
        const Text('ملخص اليوم', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
      ]))),
      SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 22), sliver: SliverGrid.count(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.35, children: cards.map((card) => _DashboardMetric(card: card)).toList())),
      const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ]);
      },
    );
  }
}

class _DashboardMetric extends StatefulWidget {
  const _DashboardMetric({required this.card});
  final (String, String, String, Color, Widget) card;

  @override
  State<_DashboardMetric> createState() => _DashboardMetricState();
}

class _DashboardMetricState extends State<_DashboardMetric> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return AnimatedScale(
      scale: pressed ? .97 : 1,
      duration: const Duration(milliseconds: 130),
      child: GestureDetector(
        onTapDown: (_) => setState(() => pressed = true),
        onTapCancel: () => setState(() => pressed = false),
        onTapUp: (_) => setState(() => pressed = false),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => card.$5),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card.$4.withOpacity(.12),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: card.$4.withOpacity(.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.$3, style: const TextStyle(fontSize: 30)),
              const Spacer(),
              Text(card.$2, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: card.$4)),
              Text(card.$1, style: const TextStyle(color: ManaraColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}