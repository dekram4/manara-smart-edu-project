import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../models/academic_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ContentManagementScreen extends StatefulWidget {
  const ContentManagementScreen({super.key});
  @override
  State<ContentManagementScreen> createState() => _ContentManagementScreenState();
}

class _ContentManagementScreenState extends State<ContentManagementScreen> {
  String query = '';
  String grade = 'الكل';
  String subject = 'الكل';
  String status = 'الكل';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المحتوى', style: TextStyle(fontWeight: FontWeight.w900))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContentEditorScreen())),
        backgroundColor: ManaraColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة محتوى'),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          final sourceLessons = state.lessonsForCurrentRole;
          final grades = sourceLessons.map((e) => e.grade).toSet().toList()..sort();
          final subjects = sourceLessons.map((e) => e.subject).toSet().toList()..sort();
          final lessons = sourceLessons.where((lesson) {
            final haystack = '${lesson.title} ${lesson.grade} ${lesson.subject} ${lesson.unit} ${lesson.content}'.toLowerCase();
            final hasMedia = lesson.explanationVideoUrl.isNotEmpty || lesson.avatarInteractionUrl.isNotEmpty || lesson.liveMeetingUrl.isNotEmpty;
            return (query.isEmpty || haystack.contains(query.toLowerCase())) &&
                (grade == 'الكل' || lesson.grade == grade) &&
                (subject == 'الكل' || lesson.subject == subject) &&
                (status == 'الكل' || (status == 'وسائط' ? hasMedia : !hasMedia));
          }).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
            children: [
              _ContentStats(total: sourceLessons.length, visible: lessons.length, media: sourceLessons.where((e) => e.explanationVideoUrl.isNotEmpty || e.avatarInteractionUrl.isNotEmpty || e.liveMeetingUrl.isNotEmpty).length),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث بعنوان الدرس أو المادة أو الوحدة...'),
              ),
              const SizedBox(height: 9),
              Row(children: [
                Expanded(child: _select('الصف', grade, ['الكل', ...grades], (v) => setState(() => grade = v ?? 'الكل'))),
                const SizedBox(width: 8),
                Expanded(child: _select('المادة', subject, ['الكل', ...subjects], (v) => setState(() => subject = v ?? 'الكل'))),
              ]),
              const SizedBox(height: 9),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'الكل', label: Text('الكل')),
                  ButtonSegment(value: 'وسائط', label: Text('مرتبط بوسائط')),
                  ButtonSegment(value: 'بدون', label: Text('بدون وسائط')),
                ],
                selected: {status},
                onSelectionChanged: (value) => setState(() => status = value.first),
              ),
              const SizedBox(height: 17),
              Row(children: [
                const Text('مكتبة الدروس', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text('${lessons.length} نتيجة', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              if (lessons.isEmpty)
                _empty()
              else
                ...lessons.map((lesson) => _LessonCard(
                      lesson: lesson,
                      onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContentEditorScreen(lesson: lesson))),
                      onDelete: () => _delete(context, lesson),
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _select(String label, String value, List<String> values, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(
        value: values.contains(value) ? value : 'الكل',
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: values.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      );

  Widget _empty() => Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Column(children: [Icon(Icons.library_books_outlined, size: 42, color: ManaraColors.muted), SizedBox(height: 10), Text('لا يوجد محتوى مطابق للفلاتر', style: TextStyle(color: ManaraColors.muted))]),
      );

  Future<void> _delete(BuildContext context, Lesson lesson) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المحتوى؟'),
        content: Text('سيتم حذف «${lesson.title}» وجميع روابطه من القائمة المحلية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true && context.mounted) context.read<AppState>().removeLesson(lesson.id);
  }
}

class _ContentStats extends StatelessWidget {
  const _ContentStats({required this.total, required this.visible, required this.media});
  final int total;
  final int visible;
  final int media;
  @override
  Widget build(BuildContext context) => Row(children: [
        _box('إجمالي الدروس', '$total', Icons.library_books_rounded, ManaraColors.purple),
        _box('نتائج الفلترة', '$visible', Icons.filter_alt_rounded, ManaraColors.blue),
        _box('بموارد مرتبطة', '$media', Icons.perm_media_rounded, ManaraColors.orange),
      ]);
  Widget _box(String label, String value, IconData icon, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsetsDirectional.only(end: 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 6), Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 10, color: ManaraColors.muted))]),
        ),
      );
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, required this.onEdit, required this.onDelete});
  final Lesson lesson;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final resources = <String>[
      if (lesson.explanationVideoUrl.isNotEmpty) 'فيديو',
      if (lesson.avatarInteractionUrl.isNotEmpty) 'Avatar',
      if (lesson.liveMeetingUrl.isNotEmpty) 'مباشر',
    ];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CircleAvatar(radius: 25, backgroundColor: ManaraColors.lavender, child: Icon(Icons.menu_book_rounded, color: ManaraColors.purple)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lesson.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('${lesson.grade} • ${lesson.atram} • ${lesson.subject}', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
            Text('${lesson.term} • ${lesson.unit}', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
            if (lesson.createdByName.isNotEmpty) Text('المنشئ: ${lesson.createdByName}', style: const TextStyle(color: ManaraColors.muted, fontSize: 11)),
            const SizedBox(height: 7),
            Wrap(spacing: 5, children: [
              Chip(label: Text(resources.isEmpty ? 'بدون موارد' : '${resources.length} موارد'), visualDensity: VisualDensity.compact),
              ...resources.map((resource) => Chip(label: Text(resource), visualDensity: VisualDensity.compact, backgroundColor: ManaraColors.lavender)),
            ]),
          ])),
          Column(children: [
            IconButton(tooltip: 'تعديل', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: ManaraColors.blue)),
            IconButton(tooltip: 'حذف', onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
          ]),
        ]),
      ),
    );
  }
}

class ContentEditorScreen extends StatefulWidget {
  const ContentEditorScreen({super.key, this.lesson});
  final Lesson? lesson;
  @override
  State<ContentEditorScreen> createState() => _ContentEditorScreenState();
}

class _ContentEditorScreenState extends State<ContentEditorScreen> {
  late final TextEditingController title, grade, atram, subject, term, unit, content, video, avatar, live;
  @override
  void initState() {
    super.initState();
    final l = widget.lesson;
    title = TextEditingController(text: l?.title ?? '');
    grade = TextEditingController(text: l?.grade ?? '');
    atram = TextEditingController(text: l?.atram ?? '');
    subject = TextEditingController(text: l?.subject ?? '');
    term = TextEditingController(text: l?.term ?? '');
    unit = TextEditingController(text: l?.unit ?? '');
    content = TextEditingController(text: l?.content ?? '');
    video = TextEditingController(text: l?.explanationVideoUrl ?? '');
    avatar = TextEditingController(text: l?.avatarInteractionUrl ?? '');
    live = TextEditingController(text: l?.liveMeetingUrl ?? '');
  }
  @override
  void dispose() {
    for (final c in [title, grade, atram, subject, term, unit, content, video, avatar, live]) c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.lesson == null ? 'إضافة محتوى جديد' : 'تعديل المحتوى', style: const TextStyle(fontWeight: FontWeight.w900))),
        body: Consumer<AppState>(
          builder: (context, state, _) => ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const Text('التصنيف الأكاديمي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                'اختر المسار من الهيكل الأكاديمي حتى يرتبط الدرس بالطلاب والمعلم الصحيحين.',
                style: TextStyle(color: ManaraColors.muted),
              ),
              const SizedBox(height: 12),
              ..._academicSelectors(state),
              const SizedBox(height: 8),
              const Text('بيانات الدرس والموارد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _field(title, 'عنوان الدرس *'),
              _field(content, 'شرح الدرس *', maxLines: 5),
              _field(video, 'رابط فيديو الشرح'),
              _field(avatar, 'رابط تفاعل Avatar'),
              _field(live, 'رابط الاجتماع المباشر'),
              const SizedBox(height: 10),
              FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const Text('حفظ وربط المحتوى')),
            ],
          ),
        ),
      );

  Iterable<AcademicUnit> _paths(AppState state) sync* {
    yield* state.academicUnits;
    for (final config in state.hierarchicalConfigs) {
      for (final atramItem in config.atrams) {
        for (final subjectItem in atramItem.subjects) {
          for (final termItem in subjectItem.terms) {
            for (final unitItem in termItem.units) {
              yield AcademicUnit(
                grade: config.grade,
                atram: atramItem.atram,
                subject: subjectItem.subject,
                term: termItem.term,
                unit: unitItem,
                createdBy: config.createdBy,
                createdByName: config.createdByName,
              );
            }
          }
        }
      }
    }
  }

  List<String> _unique(Iterable<String> values, String current) {
    final result = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (current.trim().isNotEmpty) result.add(current.trim());
    return result.toList()..sort();
  }

  List<Widget> _academicSelectors(AppState state) {
    final paths = _paths(state).toList();
    final grades = _unique(paths.map((item) => item.grade), grade.text);
    final atrams = _unique(
      paths.where((item) => item.grade == grade.text).map((item) => item.atram),
      atram.text,
    );
    final subjects = _unique(
      paths.where((item) =>
          item.grade == grade.text && item.atram == atram.text).map((item) => item.subject),
      subject.text,
    );
    final terms = _unique(
      paths.where((item) =>
          item.grade == grade.text &&
          item.atram == atram.text &&
          item.subject == subject.text).map((item) => item.term),
      term.text,
    );
    final units = _unique(
      paths.where((item) =>
          item.grade == grade.text &&
          item.atram == atram.text &&
          item.subject == subject.text &&
          item.term == term.text).map((item) => item.unit),
      unit.text,
    );
    return [
      _academicSelect('الصف *', grade, grades, () {
        atram.clear();
        subject.clear();
        term.clear();
        unit.clear();
      }),
      _academicSelect('الفصل الدراسي *', atram, atrams, () {
        subject.clear();
        term.clear();
        unit.clear();
      }),
      _academicSelect('المادة *', subject, subjects, () {
        term.clear();
        unit.clear();
      }),
      _academicSelect('الترم *', term, terms, unit.clear),
      _academicSelect('الوحدة *', unit, units, () {}),
    ];
  }

  Widget _academicSelect(
    String label,
    TextEditingController controller,
    List<String> values,
    VoidCallback clearChildren,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: values.contains(controller.text) ? controller.text : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: values.isEmpty
            ? null
            : (value) => setState(() {
                  controller.text = value ?? '';
                  clearChildren();
                }),
      ),
    );
  }
  Widget _field(TextEditingController c, String label, {int maxLines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, maxLines: maxLines, decoration: InputDecoration(labelText: label)));
  void _save() {
    final requiredFields = [title, grade, atram, subject, term, unit, content];
    if (requiredFields.any((c) => c.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل التصنيف الأكاديمي وبيانات الدرس أولاً')));
      return;
    }
    final state = context.read<AppState>();
    final args = {
      'title': title.text.trim(), 'grade': grade.text.trim(), 'atram': atram.text.trim(), 'subject': subject.text.trim(),
      'term': term.text.trim(), 'unit': unit.text.trim(), 'content': content.text.trim(),
      'explanationVideoUrl': video.text.trim(), 'avatarInteractionUrl': avatar.text.trim(), 'liveMeetingUrl': live.text.trim(),
    };
    if (widget.lesson == null) {
      state.addLesson(title: args['title']!, grade: args['grade']!, atram: args['atram']!, subject: args['subject']!, term: args['term']!, unit: args['unit']!, content: args['content']!, explanationVideoUrl: args['explanationVideoUrl']!, avatarInteractionUrl: args['avatarInteractionUrl']!, liveMeetingUrl: args['liveMeetingUrl']!);
    } else {
      state.updateLesson(id: widget.lesson!.id, title: args['title']!, grade: args['grade']!, atram: args['atram']!, subject: args['subject']!, term: args['term']!, unit: args['unit']!, content: args['content']!, explanationVideoUrl: args['explanationVideoUrl']!, avatarInteractionUrl: args['avatarInteractionUrl']!, liveMeetingUrl: args['liveMeetingUrl']!);
    }
    Navigator.pop(context);
  }
}