import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/app_models.dart';
import '../models/gamification_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.studentId});
  final String? studentId;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? selectedStudentId;
  String selectedSubject = 'الكل';

  @override
  void initState() {
    super.initState();
    selectedStudentId = widget.studentId;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final students = _studentsInScope(state);
    final studentIds = students.map((student) => student.id).toSet();
    final effectiveStudentId =
        selectedStudentId != null && studentIds.contains(selectedStudentId)
            ? selectedStudentId
            : null;
    final availableSubjects =
        _subjectsForSelection(state, effectiveStudentId, students);
    final effectiveSubject = availableSubjects.contains(selectedSubject)
        ? selectedSubject
        : 'الكل';
    final results = state.quizResultsForCurrentRole.where((result) {
      final studentMatches =
          effectiveStudentId == null || result.studentId == effectiveStudentId;
      final subjectMatches = effectiveSubject == 'الكل' ||
          result.subject.trim().toLowerCase() ==
              effectiveSubject.trim().toLowerCase();
      return studentMatches && subjectMatches;
    }).toList();
    final interactions = state.interactionsForCurrentRole.where((interaction) {
      final studentMatches = effectiveStudentId == null ||
          interaction.studentId == effectiveStudentId;
      final subjectMatches = effectiveSubject == 'الكل' ||
          interaction.subject?.trim().toLowerCase() ==
              effectiveSubject.trim().toLowerCase();
      return studentMatches && subjectMatches;
    }).toList();
    final lessons = _lessonsForSelection(
      state,
      effectiveStudentId,
      students,
    ).where((lesson) {
      return effectiveSubject == 'الكل' ||
          lesson.subject.trim().toLowerCase() ==
              effectiveSubject.trim().toLowerCase();
    }).toList();
    final reports = _buildReports(lessons, results, interactions);
    final resultAverage = results.isEmpty
        ? 0
        : (results
                    .map((item) => item.percentage)
                    .reduce((a, b) => a + b) /
                results.length)
            .round();
    final average = results.isNotEmpty
        ? resultAverage
        : (reports.isEmpty
            ? 0
            : reports.map((item) => item.score).reduce((a, b) => a + b) ~/
                reports.length);
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والتقدم',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'تصدير التقرير',
            onPressed: () => _exportReport(context, reports, results, average),
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [ManaraColors.deepPurple, ManaraColors.purple]),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 42)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('متوسط الأداء', style: TextStyle(color: Colors.white70)),
                  Text('$average%', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  const Text('استمر، تقدمك واضح كل يوم!', style: TextStyle(color: Colors.white70)),
                ])),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (students.length > 1)
            DropdownButtonFormField<String?>(
              value: effectiveStudentId,
              decoration: const InputDecoration(labelText: 'الطالب'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('كل الطلاب'),
                ),
                ...students.map(
                  (student) => DropdownMenuItem<String?>(
                    value: student.id,
                    child: Text(student.name),
                  ),
                ),
              ],
              onChanged: (value) =>
                  setState(() => selectedStudentId = value),
            ),
          if (students.length > 1) const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: effectiveSubject,
            decoration: const InputDecoration(labelText: 'المادة'),
            items: [
              const DropdownMenuItem(value: 'الكل', child: Text('كل المواد')),
              ...availableSubjects
                  .map((subject) => DropdownMenuItem(
                        value: subject,
                        child: Text(subject),
                      )),
            ],
            onChanged: (value) =>
                setState(() => selectedSubject = value ?? 'الكل'),
          ),
          const SizedBox(height: 24),
          const Text('الأداء حسب المادة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('لا توجد بيانات أداء كافية بعد',
                  style: TextStyle(color: ManaraColors.muted)),
            )
          else
            ...reports.map((report) => _ReportCard(report: report)),
          if (results.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('نتائج الاختبارات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...results.reversed.map((result) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                  leading: const CircleAvatar(backgroundColor: ManaraColors.lavender, child: Text('🧠')),
                  title: Text(result.quizTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('النتيجة: ${result.score} من ${result.total}'),
                  trailing: Text(
                    result.total == 0 ? '0%' : '${(result.score * 100) ~/ result.total}%',
                    style: const TextStyle(color: ManaraColors.purple, fontWeight: FontWeight.w900),
                  ),
                )),
          ],
           const SizedBox(height: 18),
           const Text('النشاط الأخير', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
           const SizedBox(height: 10),
           if (interactions.isEmpty)
             const _ActivityTile(icon: '🌱', title: 'ابدأ أول نشاط تعليمي', subtitle: 'سيظهر تقدمك هنا', value: 'جاهز')
           else
              ...interactions.reversed.take(8).map((activity) => _ActivityTile(
                   icon: _activityIcon(activity.action),
                   title: _activityTitle(activity.action),
                   subtitle: activity.timestamp.split('T').first,
                   value: activity.subject ?? '',
                 )),
        ],
      ),
    );
  }

  Future<void> _exportReport(
    BuildContext context,
    List<_SubjectReport> reports,
    List<QuizResult> results,
    int average,
  ) async {
    if (reports.isEmpty && results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات لتصديرها بعد')),
      );
      return;
    }
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('منصة منارة المعرفة',
                    style: pw.TextStyle(
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('تقرير التقدم والأداء',
                    style: pw.TextStyle(
                        fontSize: 17, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 14),
                pw.Text('متوسط الأداء: $average%',
                    style: pw.TextStyle(
                        fontSize: 15, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 18),
                if (reports.isNotEmpty) ...[
                  pw.Text('الأداء حسب المادة',
                      style: pw.TextStyle(
                          fontSize: 15, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Table.fromTextArray(
                    headers: const ['المادة', 'النتيجة', 'الدروس المكتملة'],
                    data: reports
                        .map((report) => [
                              report.subject,
                              '${report.score}%',
                              '${report.completedLessons} من ${report.totalLessons}',
                            ])
                        .toList(),
                  ),
                  pw.SizedBox(height: 18),
                ],
                if (results.isNotEmpty) ...[
                  pw.Text('نتائج الاختبارات',
                      style: pw.TextStyle(
                          fontSize: 15, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Table.fromTextArray(
                    headers: const ['الاختبار', 'المادة', 'النتيجة', 'التاريخ'],
                    data: results
                        .map((result) => [
                              result.quizTitle,
                              result.subject,
                              '${result.score} من ${result.total}',
                              result.date.split('T').first,
                            ])
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) async => document.save(),
      name: 'manara-progress-report.pdf',
    );
  }

  static String _activityIcon(String action) {
    if (action.contains('lesson')) return '📚';
    if (action.contains('game')) return '🎮';
    if (action.contains('chat')) return '💬';
    if (action.contains('video')) return '🎬';
    if (action.contains('live_meeting')) return '📡';
    return '✅';
  }

  static String _activityTitle(String action) {
    switch (action) {
      case 'lesson_complete':
        return 'أكمل درساً';
      case 'game_complete':
        return 'أنهى لعبة تعليمية';
      case 'chat_message':
        return 'أرسل رسالة';
      case 'video_view':
        return 'شاهد فيديو';
      case 'live_meeting_join':
        return 'انضم إلى اجتماع مباشر';
      default:
        return 'نشاط تعليمي';
    }
  }

  List<StudentProfile> _studentsInScope(AppState state) {
    switch (state.role) {
      case UserRole.student:
        return state.student == null ? const [] : [state.student!];
      case UserRole.guardian:
        final ids = state.guardian?.childIds ?? const [];
        return state.students.where((student) => ids.contains(student.id)).toList();
      case UserRole.teacher:
        return state.studentsForCurrentTeacher;
      case UserRole.admin:
        return state.students;
      case null:
        return const [];
    }
  }

  List<Lesson> _lessonsForSelection(
    AppState state,
    String? studentId,
    List<StudentProfile> students,
  ) {
    final lessons = state.lessonsForCurrentRole;
    if (studentId == null) return lessons;
    final selected = students.where((student) => student.id == studentId);
    if (selected.isEmpty) return const [];
    final student = selected.first;
    final subjects = student.enrollments
        .map((enrollment) => enrollment.subject.trim().toLowerCase())
        .where((subject) => subject.isNotEmpty)
        .toSet();
    final grade = student.primaryGrade.trim().toLowerCase();
    return lessons.where((lesson) {
      final subject = lesson.subject.trim().toLowerCase();
      final lessonGrade = lesson.grade.trim().toLowerCase();
      return (subject.isEmpty || subjects.isEmpty || subjects.contains(subject)) &&
          (lessonGrade.isEmpty || grade.isEmpty || lessonGrade == grade);
    }).toList();
  }

  List<String> _subjectsForSelection(
    AppState state,
    String? studentId,
    List<StudentProfile> students,
  ) {
    final lessons = _lessonsForSelection(state, studentId, students);
    final results = state.quizResultsForCurrentRole.where((result) {
      return studentId == null || result.studentId == studentId;
    });
    return {
      ...lessons.map((lesson) => lesson.subject).where((subject) => subject.isNotEmpty),
      ...results.map((result) => result.subject).where((subject) => subject.isNotEmpty),
    }.toList()
      ..sort();
  }

  List<_SubjectReport> _buildReports(
    List<Lesson> lessons,
    List<QuizResult> results,
    List<InteractionRecord> interactions,
  ) {
    final subjects = <String>{
      ...lessons.map((lesson) => lesson.subject).where((value) => value.isNotEmpty),
      ...results.map((result) => result.subject).where((value) => value.isNotEmpty),
    }.toList();
    const colors = [
      0xFF4ED6B5,
      0xFF55A8FF,
      0xFFFF9D4D,
      0xFF9B7BFF,
    ];
    return subjects.asMap().entries.map((entry) {
      final subject = entry.value;
      final subjectResults =
          results.where((result) => result.subject == subject).toList();
      final subjectLessons =
          lessons.where((lesson) => lesson.subject == subject).toList();
      final completedIds = interactions
          .where((item) =>
              item.subject == subject && item.action == 'lesson_complete')
          .map((item) => item.lessonId)
          .whereType<String>()
          .toSet();
      final score = subjectResults.isEmpty
          ? (subjectLessons.isEmpty
              ? 0
              : ((completedIds.length / subjectLessons.length) * 100).round())
          : (subjectResults
                      .map((item) => item.percentage)
                      .reduce((a, b) => a + b) /
                  subjectResults.length)
              .round();
      return _SubjectReport(
        subject: subject,
        score: score < 0 ? 0 : score > 100 ? 100 : score,
        completedLessons: completedIds.length,
        totalLessons: subjectLessons.length,
        color: colors[entry.key % colors.length],
      );
    }).toList();
  }
}

class _SubjectReport {
  const _SubjectReport({
    required this.subject,
    required this.score,
    required this.completedLessons,
    required this.totalLessons,
    required this.color,
  });
  final String subject;
  final int score;
  final int completedLessons;
  final int totalLessons;
  final int color;
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final _SubjectReport report;

  @override
  Widget build(BuildContext context) {
    final progress = report.totalLessons == 0
        ? 0.0
        : report.completedLessons / report.totalLessons;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: Text(report.subject, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            Text('${report.score}%', style: TextStyle(color: Color(report.color), fontWeight: FontWeight.w900, fontSize: 17)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: report.score / 100, minHeight: 9, color: Color(report.color), backgroundColor: Color(report.color).withOpacity(.12)),
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: Text('${report.completedLessons} من ${report.totalLessons} دروس مكتملة', style: const TextStyle(color: ManaraColors.muted, fontSize: 12))),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 5, color: ManaraColors.deepPurple, backgroundColor: ManaraColors.lavender),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.icon, required this.title, required this.subtitle, required this.value});
  final String icon;
  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 6),
        leading: CircleAvatar(backgroundColor: ManaraColors.lavender, child: Text(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Text(value, style: const TextStyle(color: ManaraColors.purple, fontWeight: FontWeight.bold)),
      );
}