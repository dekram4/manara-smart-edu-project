import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../services/student_content_service.dart';

enum StudentContentModule { lesson, games, personality, tutor }

class StudentContentScreen extends StatefulWidget {
  const StudentContentScreen({
    required this.profile,
    required this.authService,
    required this.initialModule,
    this.academicContext,
    this.apiBaseUrl = '',
    super.key,
  });

  final StudentProfile profile;
  final StudentAuthService authService;
  final StudentContentModule initialModule;
  final AcademicContext? academicContext;
  final String apiBaseUrl;

  @override
  State<StudentContentScreen> createState() => _StudentContentScreenState();
}

class _StudentContentScreenState extends State<StudentContentScreen> {
  late final StudentContentService _contentService;
  late StudentContentModule _activeModule;
  List<LessonContent> _lessons = const [];
  LessonContent? _selectedLesson;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contentService = StudentContentService(
      widget.authService.client,
      baseUrl: widget.apiBaseUrl,
    );
    _activeModule = widget.initialModule;
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final lessons = await _contentService.fetchLessons(
        widget.profile,
        academicContext: widget.academicContext,
      );
      if (!mounted) return;
      setState(() {
        _lessons = lessons;
        _selectedLesson = lessons.isEmpty ? null : lessons.first;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل محتوى الدروس من Supabase: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F9),
      appBar: AppBar(
        title: Text(_moduleTitle(_activeModule)),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'إغلاق',
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ModuleSwitcher(
              activeModule: _activeModule,
              onChanged: (module) => setState(() => _activeModule = module),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0B8693)),
      );
    }
    if (_error != null && _activeModule == StudentContentModule.lesson) {
      return _StateCard(
        icon: Icons.cloud_off_rounded,
        title: 'تعذر تحميل المحتوى',
        message: _error!,
        actionLabel: 'إعادة المحاولة',
        onAction: () {
          setState(() => _loading = true);
          _loadContent();
        },
      );
    }

    switch (_activeModule) {
      case StudentContentModule.lesson:
        return _LessonModule(
          lessons: _lessons,
          selectedLesson: _selectedLesson,
          apiBaseUrl: widget.apiBaseUrl,
          onLessonChanged: (lesson) => setState(() => _selectedLesson = lesson),
        );
      case StudentContentModule.games:
        return const _GamesModulePlaceholder();
      case StudentContentModule.personality:
        return _PersonalityModule(
          profile: widget.profile,
          contentService: _contentService,
        );
      case StudentContentModule.tutor:
        return _TutorModule(
          profile: widget.profile,
          lesson: _selectedLesson,
          contentService: _contentService,
          apiBaseUrl: widget.apiBaseUrl,
        );
    }
  }
}

String _moduleTitle(StudentContentModule module) {
  switch (module) {
    case StudentContentModule.lesson:
      return 'شرح الدرس وسينما منارة';
    case StudentContentModule.games:
      return 'الترفيه والألعاب';
    case StudentContentModule.personality:
      return 'شخصيتي';
    case StudentContentModule.tutor:
      return 'المعلم الافتراضي';
  }
}

class _ModuleSwitcher extends StatelessWidget {
  const _ModuleSwitcher({
    required this.activeModule,
    required this.onChanged,
  });

  final StudentContentModule activeModule;
  final ValueChanged<StudentContentModule> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (StudentContentModule.lesson, Icons.play_lesson_rounded, 'الدرس'),
      (StudentContentModule.games, Icons.sports_esports_rounded, 'الألعاب'),
      (StudentContentModule.personality, Icons.face_retouching_natural_rounded, 'شخصيتي'),
      (StudentContentModule.tutor, Icons.smart_toy_rounded, 'المعلم'),
    ];
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = activeModule == item.$1;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onChanged(item.$1),
            avatar: Icon(
              item.$2,
              size: 19,
              color: selected ? Colors.white : const Color(0xFF0B8693),
            ),
            label: Text(item.$3),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF274E76),
              fontWeight: FontWeight.w900,
            ),
            selectedColor: const Color(0xFF0B8693),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFD7E3EF)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }
}

class _LessonModule extends StatelessWidget {
  const _LessonModule({
    required this.lessons,
    required this.selectedLesson,
    required this.onLessonChanged,
    required this.apiBaseUrl,
  });

  final List<LessonContent> lessons;
  final LessonContent? selectedLesson;
  final ValueChanged<LessonContent> onLessonChanged;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return const _StateCard(
        icon: Icons.video_library_outlined,
        title: 'لا توجد فيديوهات بعد',
        message: 'سيظهر هنا محتوى المعلم والمشرف المطابق لصفك وترمك ومادتك ووحدتك.',
      );
    }

    final lesson = selectedLesson ?? lessons.first;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          'سينما منارة',
          style: const TextStyle(
            color: Color(0xFF0E1B2A),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),
        const SizedBox(height: 4),
        Text(
          lesson.scopeLabel.isEmpty ? 'فيديوهات الشرح الخاصة بك' : lesson.scopeLabel,
          style: const TextStyle(color: Color(0xFF5680AC), fontWeight: FontWeight.w700),
        ),
        if (lessons.length > 1) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 45,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: lessons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = lessons[index];
                return ChoiceChip(
                  selected: item.id == lesson.id,
                  onSelected: (_) => onLessonChanged(item),
                  label: Text(
                    item.lessonName.isNotEmpty
                        ? item.lessonName
                        : (item.unit.isEmpty ? 'درس ${index + 1}' : item.unit),
                  ),
                  selectedColor: const Color(0xFFBFEFED),
                  labelStyle: const TextStyle(
                    color: Color(0xFF0E1B2A),
                    fontWeight: FontWeight.w800,
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (lesson.videos.isEmpty)
          const _StateCard(
            icon: Icons.video_call_outlined,
            title: 'لم تتم إضافة فيديو',
            message: 'يمكن للمعلم أو المشرف إضافة رابط فيديو أو ملف MP4 لهذا الدرس.',
          )
        else
          _VideoCarousel(videos: lesson.videos, apiBaseUrl: apiBaseUrl),
        if (lesson.lessonText != null) ...[
          const SizedBox(height: 18),
          _GlassPanel(
            child: Text(
              lesson.lessonText!,
              style: const TextStyle(
                color: Color(0xFF274E76),
                fontSize: 16,
                height: 1.7,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VideoCarousel extends StatefulWidget {
  const _VideoCarousel({required this.videos, required this.apiBaseUrl});

  final List<LessonVideo> videos;
  final String apiBaseUrl;

  @override
  State<_VideoCarousel> createState() => _VideoCarouselState();
}

class _VideoCarouselState extends State<_VideoCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  int _activeIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openVideo(LessonVideo video) async {
    var targetUrl = video.url.trim();

    // 1. معالجة المسار النسبي لـ MP4
    if (targetUrl.startsWith('/')) {
      final base = widget.apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
      if (base.isNotEmpty) {
        targetUrl = '$base$targetUrl';
      } else {
        targetUrl = 'https://manara-smart-edu-new.replit.app$targetUrl';
      }
    }

    // 2. معالجة روابط يوتيوب التضمينية
    if (targetUrl.contains('/embed/')) {
      final id = targetUrl.split('/embed/')[1].split('?').first.split('&').first;
      targetUrl = 'https://www.youtube.com/watch?v=$id';
    }

    final uri = Uri.tryParse(targetUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح رابط الفيديو: $targetUrl')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 285,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.videos.length,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            onPageChanged: (index) => setState(() => _activeIndex = index),
            itemBuilder: (context, index) {
              final video = widget.videos[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: _VideoCard(
                  video: video,
                  onPressed: () => _openVideo(video),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.videos.length,
            (index) => AnimatedContainer(
              duration: 220.ms,
              width: index == _activeIndex ? 26 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index == _activeIndex
                    ? const Color(0xFF0B8693)
                    : const Color(0xFFB3C8DE),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.onPressed,
  });

  final LessonVideo video;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFF0B8693), Color(0xFF274E76)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x450B8693),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFBFFBFA), size: 38),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(38),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      video.sourceType == VideoSourceType.mp4 ? 'MP4 / AI' : 'يوتيوب',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                video.description ?? 'اضغط لتشغيل الفيديو بجودة عالية فوراً',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFBFFBFA),
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('شاهد الآن'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0B8693),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
  }
}

class _GamesModulePlaceholder extends StatelessWidget {
  const _GamesModulePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const _StateCard(
      icon: Icons.sports_esports_rounded,
      title: 'قسم الألعاب التفاعلية',
      message: 'الألعاب التعليمية الممتعة قيد التجهيز لهذا الدرس.',
    );
  }
}

class _PersonalityModule extends StatefulWidget {
  const _PersonalityModule({
    required this.profile,
    required this.contentService,
  });

  final StudentProfile profile;
  final StudentContentService contentService;

  @override
  State<_PersonalityModule> createState() => _PersonalityModuleState();
}

class _PersonalityModuleState extends State<_PersonalityModule> {
  late Map<String, dynamic> _appearance;
  double _rotation = 0;
  bool _saving = false;

  static const _hair = ['🦱', '🧑‍🦱', '🧢', '🎓', '🦲'];
  static const _tops = ['👕', '🧥', '🦺', '🥋', '🧑‍🚀', '🎓'];
  static const _bottoms = ['👖', '🩳', '🥋', '🩲', '🦿'];
  static const _shoes = ['👟', '🥾', '🥿', '🛼', '🩴'];
  static const _skinTones = ['#edb891', '#c68642', '#8d5524', '#f1c27d'];

  @override
  void initState() {
    super.initState();
    _appearance = {
      'shape': 'full-body',
      'color': '#38bdf8',
      'outfit': '👕',
      'hair': '🧑‍🦱',
      'top': '👕',
      'bottom': '👖',
      'shoes': '👟',
      'skinTone': '#edb891',
      ...?widget.profile.appearance,
    };
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.contentService.saveAppearance(
        profile: widget.profile,
        appearance: _appearance,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ شخصيتك بنجاح!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الشخصية: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const Text(
          'اصنع شخصيتك كاملة الجسم',
          style: TextStyle(
            color: Color(0xFF0E1B2A),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onPanUpdate: (details) => setState(() {
            _rotation += details.delta.dx * 0.012;
          }),
          child: _GlassPanel(
            child: SizedBox(
              height: 330,
              child: Center(
                child: Transform.rotate(
                  angle: _rotation,
                  child: _FullBodyAvatar(appearance: _appearance),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AvatarPicker(
          title: 'الشعر',
          values: _hair,
          selected: _appearance['hair']?.toString() ?? '',
          onSelected: (value) => setState(() => _appearance['hair'] = value),
        ),
        _AvatarPicker(
          title: 'القطعة العلوية',
          values: _tops,
          selected: _appearance['top']?.toString() ?? '',
          onSelected: (value) {
            setState(() {
              _appearance['top'] = value;
              _appearance['outfit'] = value;
            });
          },
        ),
        _AvatarPicker(
          title: 'القطعة السفلية',
          values: _bottoms,
          selected: _appearance['bottom']?.toString() ?? '',
          onSelected: (value) => setState(() => _appearance['bottom'] = value),
        ),
        _AvatarPicker(
          title: 'الحذاء',
          values: _shoes,
          selected: _appearance['shoes']?.toString() ?? '',
          onSelected: (value) => setState(() => _appearance['shoes'] = value),
        ),
        _AvatarPicker(
          title: 'لون البشرة',
          values: _skinTones,
          selected: _appearance['skinTone']?.toString() ?? '',
          onSelected: (value) => setState(() => _appearance['skinTone'] = value),
          isColor: true,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? 'جاري الحفظ...' : 'حفظ شخصيتي'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0B8693),
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.isColor = false,
  });

  final String title;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool isColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF274E76), fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 53,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final value = values[index];
                final selectedValue = value == selected;
                return GestureDetector(
                  onTap: () => onSelected(value),
                  child: AnimatedContainer(
                    duration: 180.ms,
                    width: 53,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isColor ? _hexColor(value) : Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: selectedValue ? const Color(0xFF0B8693) : const Color(0xFFD7E3EF),
                        width: selectedValue ? 3 : 1,
                      ),
                    ),
                    child: isColor
                        ? null
                        : Text(value, style: const TextStyle(fontSize: 27)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FullBodyAvatar extends StatelessWidget {
  const _FullBodyAvatar({required this.appearance});

  final Map<String, dynamic> appearance;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(appearance['hair']?.toString() ?? '🧑‍🦱', style: const TextStyle(fontSize: 70)),
        Text(appearance['top']?.toString() ?? '👕', style: const TextStyle(fontSize: 92)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(appearance['bottom']?.toString() ?? '👖', style: const TextStyle(fontSize: 72)),
            Text(appearance['shoes']?.toString() ?? '👟', style: const TextStyle(fontSize: 58)),
          ],
        ),
      ],
    );
  }
}

class _TutorModule extends StatefulWidget {
  const _TutorModule({
    required this.profile,
    required this.lesson,
    required this.contentService,
    required this.apiBaseUrl,
  });

  final StudentProfile profile;
  final LessonContent? lesson;
  final StudentContentService contentService;
  final String apiBaseUrl;

  @override
  State<_TutorModule> createState() => _TutorModuleState();
}

class _TutorModuleState extends State<_TutorModule> {
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_TutorMessage> _messages = [];
  bool _solving = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _TutorMessage(
        text: 'أهلًا! أنا معلمك الافتراضي. اكتب سؤالك وسأساعدك خطوة بخطوة.',
        fromStudent: false,
      ),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _solving) return;
    _questionController.clear();
    setState(() {
      _messages.add(_TutorMessage(text: question, fromStudent: true));
      _solving = true;
    });

    String answer;
    try {
      final base = widget.apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
      if (base.isEmpty) throw Exception();
      final res = await http.post(
        Uri.parse('$base/api/gemini/answer'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question}),
      );
      final payload = jsonDecode(res.body);
      answer = payload['answer'] ?? 'سؤال رائع! دعنا نراجعه معاً.';
    } catch (_) {
      answer = 'سؤال رائع! دعنا نتعاون في البحث عن إجابته مع معلمك.';
    }

    if (!mounted) return;
    setState(() {
      _messages.add(_TutorMessage(text: answer, fromStudent: false));
      _solving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return Align(
                alignment: message.fromStudent ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: message.fromStudent
                        ? const Color(0xFF274E76)
                        : const Color(0xFF0B8693),
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionController,
                  decoration: const InputDecoration(hintText: 'اكتب سؤالك هنا...'),
                  onSubmitted: (_) => _ask(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _solving ? null : _ask,
                icon: const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF0B8693)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TutorMessage {
  const _TutorMessage({required this.text, required this.fromStudent});
  final String text;
  final bool fromStudent;
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF0B8693), size: 54),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0E1B2A),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF5680AC), height: 1.5, fontWeight: FontWeight.w700),
              ),
              if (onAction != null) ...[
                const SizedBox(height: 14),
                FilledButton(onPressed: onAction, child: Text(actionLabel ?? 'متابعة')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(225),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withAlpha(210)),
      ),
      child: child,
    );
  }
}

Color _hexColor(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? const Color(0xFFEDB891) : Color(0xFF000000 | parsed);
}