import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../models/academic_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../widgets/academic_scope_selector.dart';

enum RecordType { students, teachers, lessons, videos }

class RecordsManager extends StatelessWidget {
  const RecordsManager({super.key, required this.type});
  final RecordType type;

  String get title {
    switch (type) {
      case RecordType.students:
        return 'إدارة الطلاب';
      case RecordType.teachers:
        return 'إدارة المعلمين';
      case RecordType.lessons:
        return 'إدارة المحتوى';
      case RecordType.videos:
        return 'إدارة الفيديوهات';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        backgroundColor: ManaraColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) => _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, AppState state) {
    switch (type) {
      case RecordType.students:
        return _recordList(
          context,
          state.studentsForCurrentTeacher,
          (item) => '${item.name} • ${item.primaryGrade}',
          (item) => item.username,
          (item) => state.removeStudent(item.id),
        );
      case RecordType.teachers:
        return _recordList(
          context,
          state.role == UserRole.admin ? state.teachers : const <TeacherProfile>[],
          (item) => '${item.name} • ${item.subject ?? 'بدون تخصص'}',
          (item) => 'رقم المعلم: ${item.teacherId}',
          (item) => state.removeTeacher(item.id),
        );
      case RecordType.lessons:
        return _recordList(
          context,
          state.lessonsForCurrentRole,
          (item) => item.title,
          (item) => '${item.subject} • ${item.unit}',
          null,
        );
      case RecordType.videos:
        return _recordList(
          context,
          state.videosForCurrentRole,
          (item) => item.title,
          (item) => '${item.subject} • ${item.duration}',
          (item) => state.removeVideo(item.id),
          (item) => _openEditVideo(context, item),
        );
    }
  }

  Widget _recordList<T>(
    BuildContext context,
    List<T> records,
    String Function(T) primary,
    String Function(T) secondary,
    void Function(T)? onDelete,
    [
    void Function(T)? onEdit,
    ]
  ) {
    if (records.isEmpty) {
      return const Center(child: Text('لا توجد سجلات بعد', style: TextStyle(color: ManaraColors.muted)));
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19)),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: ManaraColors.lavender,
              child: Text(type == RecordType.students ? '🎒' : type == RecordType.teachers ? '👩‍🏫' : type == RecordType.videos ? '🎬' : '📚'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(primary(records[index]), style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(secondary(records[index]), style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
              ]),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'حذف',
                onPressed: () => _confirmDelete(context, () => onDelete(records[index])),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            if (onEdit != null)
              IconButton(
                tooltip: 'تعديل',
                onPressed: () => onEdit(records[index]),
                icon: const Icon(Icons.edit_outlined, color: ManaraColors.blue),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, VoidCallback action) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذا السجل؟ لا يمكن التراجع عن هذه العملية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              action();
              Navigator.pop(context);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRecordScreen(type: type)));
  }

  void _openEditVideo(BuildContext context, VideoLesson video) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateRecordScreen(type: RecordType.videos, video: video)),
    );
  }
}

class CreateRecordScreen extends StatefulWidget {
  const CreateRecordScreen({super.key, required this.type, this.video});
  final RecordType type;
  final VideoLesson? video;

  @override
  State<CreateRecordScreen> createState() => _CreateRecordScreenState();
}

class _CreateRecordScreenState extends State<CreateRecordScreen> {
  final title = TextEditingController();
  final second = TextEditingController();
  final third = TextEditingController();
  final url = TextEditingController();
  final description = TextEditingController();
  final grade = TextEditingController();
  final atram = TextEditingController();
  final term = TextEditingController();
  final unit = TextEditingController();
  String? selectedTeacherId;
  PlatformFile? pickedVideo;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    final video = widget.video;
    if (video != null) {
      title.text = video.title;
      second.text = video.subject;
      third.text = video.duration;
      url.text = video.url ?? '';
      description.text = video.description;
      grade.text = video.grade;
      atram.text = video.atram;
      term.text = video.term;
      unit.text = video.unit;
      selectedTeacherId = video.createdBy;
    }
  }

  @override
  void dispose() {
    title.dispose();
    second.dispose();
    third.dispose();
    url.dispose();
    description.dispose();
    grade.dispose();
    atram.dispose();
    term.dispose();
    unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fields();
    return Scaffold(
      appBar: AppBar(title: Text('إضافة ${_name()}', style: const TextStyle(fontWeight: FontWeight.w900))),
      body: Consumer<AppState>(
        builder: (context, state, _) => ListView(
          padding: const EdgeInsets.all(22),
          children: [
          Text('أدخل بيانات ${_name()} ثم احفظ السجل', style: const TextStyle(color: ManaraColors.muted, fontSize: 16)),
          const SizedBox(height: 22),
          TextField(controller: title, decoration: InputDecoration(labelText: fields[0], prefixIcon: const Icon(Icons.edit_outlined))),
          const SizedBox(height: 14),
          if (widget.type == RecordType.videos)
            ..._videoFields(state)
          else if (widget.type == RecordType.lessons)
            ..._lessonFields(state)
          else ...[
            TextField(controller: second, decoration: InputDecoration(labelText: fields[1], prefixIcon: const Icon(Icons.category_outlined))),
            const SizedBox(height: 14),
            TextField(controller: third, maxLines: widget.type == RecordType.lessons ? 4 : 1, decoration: InputDecoration(labelText: fields[2], prefixIcon: const Icon(Icons.notes_outlined))),
          ],
          if (widget.type == RecordType.videos) ...[
            const SizedBox(height: 14),
            TextField(controller: url, decoration: const InputDecoration(labelText: 'رابط الفيديو (اختياري)', prefixIcon: Icon(Icons.link_rounded))),
             const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: uploading ? null : () => _pickVideo(state),
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(
                  pickedVideo == null
                      ? state.videoStorageConfigured
                          ? 'اختيار ورفع فيديو إلى التخزين الخاص'
                          : 'اختيار فيديو (اضبط bucket أولاً)'
                      : 'تم اختيار: ${pickedVideo!.name}',
                ),
             ),
             if (!state.videoStorageConfigured)
               const Padding(
                 padding: EdgeInsets.only(top: 6),
                 child: Text(
                   'الرفع يتطلب SUPABASE_VIDEO_BUCKET مع bucket خاص وسياسات Storage مناسبة.',
                   style: TextStyle(color: ManaraColors.muted, fontSize: 12),
                 ),
               ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: uploading ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('حفظ السجل')),
        ],
        ),
      ),
    );
  }

  List<Widget> _videoFields(AppState state) {
    final paths = <AcademicUnit>[
      ...state.academicUnits,
      ...state.hierarchicalConfigs.expand(
        (config) => config.atrams.expand(
          (atramItem) => atramItem.subjects.expand(
            (subjectItem) => subjectItem.terms.expand(
              (termItem) => termItem.units.map(
                (unitItem) => AcademicUnit(
                  grade: config.grade,
                  atram: atramItem.atram,
                  subject: subjectItem.subject,
                  term: termItem.term,
                  unit: unitItem,
                  createdBy: config.createdBy,
                  createdByName: config.createdByName,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
    final grades = _unique([
      ...paths.map((item) => item.grade),
      if (widget.video?.grade.isNotEmpty == true) widget.video!.grade,
    ]);
    final atrams = _unique(paths
        .where((item) => grade.text.isEmpty || item.grade == grade.text)
        .map((item) => item.atram));
    final subjects = _unique(paths.where((item) {
      return (grade.text.isEmpty || item.grade == grade.text) &&
          (atram.text.isEmpty || item.atram == atram.text);
    }).map((item) => item.subject));
    final terms = _unique(paths.where((item) {
      return (grade.text.isEmpty || item.grade == grade.text) &&
          (atram.text.isEmpty || item.atram == atram.text) &&
          (second.text.isEmpty || item.subject == second.text);
    }).map((item) => item.term));
    final units = _unique(paths.where((item) {
      return (grade.text.isEmpty || item.grade == grade.text) &&
          (atram.text.isEmpty || item.atram == atram.text) &&
          (second.text.isEmpty || item.subject == second.text) &&
          (term.text.isEmpty || item.term == term.text);
    }).map((item) => item.unit));

    final teachers = state.role == UserRole.admin
        ? state.teachers
        : state.teachersForCurrentRole;
    if (state.role == UserRole.teacher && selectedTeacherId == null) {
      selectedTeacherId = state.teacher?.id;
    }
    return [
      _selectField(
        label: 'المعلم المحدد *',
        value: selectedTeacherId,
        values: teachers.map((item) => item.id).toList(),
        labels: {for (final item in teachers) item.id: item.name},
        enabled: state.role == UserRole.admin,
        onChanged: (value) => setState(() => selectedTeacherId = value),
      ),
      const SizedBox(height: 12),
      _selectField(
        label: 'الصف المحدد *',
        value: grade.text.isEmpty ? null : grade.text,
        values: grades,
        onChanged: (value) => setState(() {
          grade.text = value ?? '';
          atram.clear();
          second.clear();
          term.clear();
          unit.clear();
        }),
      ),
      const SizedBox(height: 12),
      _selectField(
        label: 'الفصل الدراسي',
        value: atram.text.isEmpty ? null : atram.text,
        values: atrams,
        onChanged: (value) => setState(() {
          atram.text = value ?? '';
          second.clear();
          term.clear();
          unit.clear();
        }),
      ),
      const SizedBox(height: 12),
      _selectField(
        label: 'المادة *',
        value: second.text.isEmpty ? null : second.text,
        values: subjects,
        onChanged: (value) => setState(() {
          second.text = value ?? '';
          term.clear();
          unit.clear();
        }),
      ),
      const SizedBox(height: 12),
      _selectField(
        label: 'الترم',
        value: term.text.isEmpty ? null : term.text,
        values: terms,
        onChanged: (value) => setState(() {
          term.text = value ?? '';
          unit.clear();
        }),
      ),
      const SizedBox(height: 12),
      _selectField(
        label: 'الوحدة',
        value: unit.text.isEmpty ? null : unit.text,
        values: units,
        onChanged: (value) => setState(() => unit.text = value ?? ''),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: third,
        decoration: const InputDecoration(
          labelText: 'المدة، مثال 08:30 *',
          prefixIcon: Icon(Icons.timer_outlined),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: description,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'وصف الفيديو',
          prefixIcon: Icon(Icons.description_outlined),
        ),
      ),
    ];
  }

  List<Widget> _lessonFields(AppState state) {
    final paths = <AcademicUnit>[
      ...state.academicUnits,
      ...state.hierarchicalConfigs.expand(
        (config) => config.atrams.expand(
          (atramItem) => atramItem.subjects.expand(
            (subjectItem) => subjectItem.terms.expand(
              (termItem) => termItem.units.map(
                (unitItem) => AcademicUnit(
                  grade: config.grade,
                  atram: atramItem.atram,
                  subject: subjectItem.subject,
                  term: termItem.term,
                  unit: unitItem,
                  createdBy: config.createdBy,
                  createdByName: config.createdByName,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
    return [
      AcademicScopeSelector(
        paths: paths,
        initialGrade: grade.text,
        onChanged: (selection) => setState(() {
          grade.text = selection.grade;
          atram.text = selection.atram;
          second.text = selection.subject;
          term.text = selection.term;
          unit.text = selection.unit;
        }),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: third,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'شرح الدرس *',
          prefixIcon: Icon(Icons.notes_outlined),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: url,
        decoration: const InputDecoration(
          labelText: 'رابط فيديو الشرح (اختياري)',
          prefixIcon: Icon(Icons.link_rounded),
        ),
      ),
    ];
  }

  Widget _selectField({
    required String label,
    required String? value,
    required List<String> values,
    Map<String, String> labels = const {},
    bool enabled = true,
    required ValueChanged<String?> onChanged,
  }) {
    final safeValue = values.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(labels[item] ?? item, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: enabled && values.isNotEmpty ? onChanged : null,
    );
  }

  List<String> _unique(Iterable<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _fields() {
    switch (widget.type) {
      case RecordType.students:
        return ['اسم الطالب', 'اسم المستخدم', 'الصف'];
      case RecordType.teachers:
        return ['اسم المعلم', 'اسم المستخدم', 'التخصص'];
      case RecordType.lessons:
        return ['عنوان الدرس', 'المادة', 'محتوى الدرس'];
      case RecordType.videos:
        return ['عنوان الفيديو', 'المادة', 'المدة، مثال 08:30'];
    }
  }

  String _name() {
    switch (widget.type) {
      case RecordType.students:
        return 'الطالب';
      case RecordType.teachers:
        return 'المعلم';
      case RecordType.lessons:
        return 'الدرس';
      case RecordType.videos:
        return 'الفيديو';
    }
  }

  Future<void> _pickVideo(AppState state) async {
    if (!state.videoStorageConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم إعداد التخزين الآمن للفيديوهات بعد')),
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'm4v', 'webm'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null || file.bytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر قراءة ملف الفيديو من الجهاز')),
      );
      return;
    }
    if (file.bytes!.length > 500 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حجم الفيديو يتجاوز الحد المسموح 500 ميجابايت')),
      );
      return;
    }
    setState(() => pickedVideo = file);
  }

  Future<void> _save() async {
    final isLesson = widget.type == RecordType.lessons;
    final isVideo = widget.type == RecordType.videos;
    final hasRequiredLessonScope = !isLesson ||
        [
          grade.text,
          atram.text,
          second.text,
          term.text,
          unit.text,
        ].every((value) => value.trim().isNotEmpty);
    if (title.text.trim().isEmpty ||
        second.text.trim().isEmpty ||
        third.text.trim().isEmpty ||
        !hasRequiredLessonScope ||
        (isVideo &&
            (grade.text.trim().isEmpty || selectedTeacherId == null))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل جميع الحقول أولاً')));
      return;
    }
    final state = context.read<AppState>();
    var videoUrl = url.text.trim();
    if (widget.type == RecordType.videos && pickedVideo != null) {
      setState(() => uploading = true);
      final uploadedPath = await state.uploadVideoFile(
        fileName: pickedVideo!.name,
        bytes: pickedVideo!.bytes!,
        contentType: _contentType(pickedVideo!.extension),
      );
      if (!mounted) return;
      setState(() => uploading = false);
      if (uploadedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل رفع الفيديو. تحقق من bucket والسياسات والاتصال.')),
        );
        return;
      }
      videoUrl = uploadedPath;
    }
    ManaraAudioService.instance.playSuccess();
    switch (widget.type) {
      case RecordType.students:
        state.addStudent(name: title.text.trim(), username: second.text.trim(), grade: third.text.trim());
      case RecordType.teachers:
        state.addTeacher(name: title.text.trim(), username: second.text.trim(), subject: third.text.trim());
      case RecordType.lessons:
        state.addLesson(
          title: title.text.trim(),
          subject: second.text.trim(),
          grade: grade.text.trim(),
          atram: atram.text.trim(),
          term: term.text.trim(),
          unit: unit.text.trim(),
          content: third.text.trim(),
          explanationVideoUrl: url.text.trim(),
        );
      case RecordType.videos:
        final selectedTeacher = state.teachers.cast<TeacherProfile?>().firstWhere(
              (item) => item?.id == selectedTeacherId,
              orElse: () => null,
            );
        if (widget.video == null) {
          state.addVideo(
            title: title.text.trim(),
            subject: second.text.trim(),
            duration: third.text.trim(),
            url: videoUrl,
            description: description.text.trim(),
            grade: grade.text.trim(),
            atram: atram.text.trim(),
            term: term.text.trim(),
            unit: unit.text.trim(),
            teacherId: selectedTeacherId,
            teacherName: selectedTeacher?.name,
          );
        } else {
          state.updateVideo(
            id: widget.video!.id,
            title: title.text.trim(),
            subject: second.text.trim(),
            duration: third.text.trim(),
            url: videoUrl,
            description: description.text.trim(),
            grade: grade.text.trim(),
            atram: atram.text.trim(),
            term: term.text.trim(),
            unit: unit.text.trim(),
            teacherId: selectedTeacherId,
            teacherName: selectedTeacher?.name,
          );
        }
    }
    Navigator.pop(context);
  }

  String _contentType(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'm4v':
      case 'mp4':
      default:
        return 'video/mp4';
    }
  }
}