import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lottie/lottie.dart';

import '../models/student_profile.dart';
import '../services/student_content_service.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/student_experience.dart';

/// A child-friendly editor for the appearance stored with a student profile.
///
/// [creatorUrl] is optional so the local editor remains useful when a Ready
/// Player Me application subdomain has not been configured.
class StudentPersonalityScreen extends StatefulWidget {
  const StudentPersonalityScreen({
    required this.profile,
    required this.contentService,
    this.creatorUrl,
    super.key,
  });

  final StudentProfile profile;
  final StudentContentService contentService;
  final String? creatorUrl;

  @override
  State<StudentPersonalityScreen> createState() =>
      _StudentPersonalityScreenState();
}

class _StudentPersonalityScreenState extends State<StudentPersonalityScreen> {
  static const _emojis = [
    '🦸',
    '🧑‍🚀',
    '🧙',
    '🥷',
    '🧑‍🔬',
    '🧑‍🎨',
    '🧑‍🚒',
    '🧑‍✈️',
    '🦁',
    '🐼',
    '🦊',
    '🌟',
  ];
  static const _outfits = <String, (String, String)>{
    'hero': ('بطل', '🦸‍♂️'),
    'space': ('فضاء', '🚀'),
    'sport': ('رياضي', '🏅'),
    'science': ('عالِم', '🥼'),
    'artist': ('فنان', '🎨'),
    'adventure': ('مغامر', '🎒'),
  };
  static const _accessories = <String, String>{
    'none': 'بدون',
    'crown': '👑',
    'glasses': '🕶️',
    'headphones': '🎧',
    'cape': '🦸',
    'star': '⭐',
  };
  static const _motions = <String, (String, IconData)>{
    'idle': ('وقفة البطل', Icons.accessibility_new_rounded),
    'wave': ('تلويح', Icons.waving_hand_rounded),
    'celebrate': ('احتفال', Icons.celebration_rounded),
  };
  static const _colors = [
    Color(0xFF38BDF8),
    Color(0xFFF97316),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFFACC15),
  ];

  late Map<String, dynamic> _appearance;
  bool _loadingAppearance = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _appearance = Map<String, dynamic>.from(widget.profile.appearance ?? {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _loadingAppearance = false);
    });
  }

  String get _emoji {
    final value = _appearance['shape']?.toString().trim() ?? '';
    return _emojis.contains(value) ? value : _emojis.first;
  }

  Color get _color {
    final value = _appearance['color']?.toString() ?? '';
    return _colors.firstWhere(
      (color) => _hex(color).toLowerCase() == value.toLowerCase(),
      orElse: () => _colors.first,
    );
  }

  String get _outfit {
    final value = _appearance['outfit']?.toString() ?? '';
    return _outfits.containsKey(value) ? value : 'hero';
  }

  String get _accessory {
    final value = _appearance['accessory']?.toString() ?? '';
    return _accessories.containsKey(value) ? value : 'none';
  }

  String get _motion {
    final value = _appearance['motion']?.toString() ?? '';
    if (value == 'bounce') return 'idle';
    if (value == 'dance') return 'celebrate';
    return _motions.containsKey(value) ? value : 'idle';
  }

  String? get _avatarImageUrl {
    final value = _appearance['readyPlayerMeAvatarImageUrl']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get _canOpenCreator => _validCreatorUrl(widget.creatorUrl) != null;

  Future<void> _save(Map<String, dynamic> next) async {
    setState(() => _saving = true);
    try {
      await widget.contentService.saveAppearance(
        profile: widget.profile,
        appearance: next,
      );
      if (!mounted) return;
      setState(() => _appearance = Map<String, dynamic>.from(next));
      StudentSoundService.instance.play(StudentSoundCue.success);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أحسنت! تم حفظ شخصيتك ✨')));
    } catch (error) {
      if (!mounted) return;
      StudentSoundService.instance.play(StudentSoundCue.warning);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لم نتمكن من حفظ الشخصية: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveLocalAppearance() {
    final next = <String, dynamic>{
      ..._appearance,
      'shape': _emoji,
      'color': _hex(_color),
      'outfit': _outfit,
      'accessory': _accessory,
      'motion': _motion,
    };
    next.remove('readyPlayerMeAvatarUrl');
    next.remove('readyPlayerMeAvatarId');
    next.remove('readyPlayerMeAvatarImageUrl');
    return _save(next);
  }

  Future<void> _openCreator() async {
    final url = _validCreatorUrl(widget.creatorUrl);
    if (url == null) return;
    StudentSoundService.instance.playTap();
    final export = await Navigator.of(context).push<_ReadyPlayerMeExport>(
      StudentPageRoute<_ReadyPlayerMeExport>(
        builder: (_) => _ReadyPlayerMeCreatorScreen(creatorUrl: url),
      ),
    );
    if (export == null || !mounted) return;
    await _save(<String, dynamic>{
      ..._appearance,
      'readyPlayerMeAvatarUrl': export.modelUrl,
      'readyPlayerMeAvatarId': export.avatarId,
      'readyPlayerMeAvatarImageUrl': export.imageUrl,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAppearance) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Color(0xFFF4F8FF),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF9B3E68)),
                SizedBox(height: 14),
                Text(
                  'نجهّز شخصيتك الرائعة...',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        appBar: AppBar(
          title: const Text('شخصيتي'),
          centerTitle: true,
          actions: const [StudentSoundToggle()],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const StudentScreenHero(
              title: 'اصنع بطلك الرائع!',
              subtitle: 'صمّم بطلك الكامل واختر حركته، ثم احفظ شخصيتك.',
              icon: Icons.face_retouching_natural_rounded,
              colors: [Color(0xFF9B3E68), Color(0xFFE05A86)],
            ),
            const SizedBox(height: 22),
            StudentEntrance(
              delay: const Duration(milliseconds: 100),
              child: _AppearancePreview(
                emoji: _emoji,
                color: _color,
                imageUrl: _avatarImageUrl,
                outfit: _outfit,
                accessory: _accessory,
                motion: _motion,
                level: widget.profile.gamification.level,
                gems: widget.profile.gamification.gems,
                levelProgress: widget.profile.gamification.levelProgress,
              ),
            ),
            const SizedBox(height: 20),
            StudentEntrance(
              delay: const Duration(milliseconds: 150),
              child: _EditorCard(
                title: 'اختر شارة بطلك',
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: _emojis
                      .map(
                        (emoji) => ChoiceChip(
                          label: Text(
                            emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          selected: _emoji == emoji,
                          onSelected: (_) {
                            StudentSoundService.instance.playTap();
                            setState(() => _appearance['shape'] = emoji);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            StudentEntrance(
              delay: const Duration(milliseconds: 175),
              child: _EditorCard(
                title: 'اختر ملابس المغامرة',
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 9,
                  runSpacing: 9,
                  children: _outfits.entries
                      .map(
                        (entry) => ChoiceChip(
                          avatar: Text(entry.value.$2),
                          label: Text(entry.value.$1),
                          selected: _outfit == entry.key,
                          onSelected: (_) {
                            StudentSoundService.instance.playTap();
                            setState(() => _appearance['outfit'] = entry.key);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            StudentEntrance(
              delay: const Duration(milliseconds: 200),
              child: _EditorCard(
                title: 'اختر لون الملابس',
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 13,
                  runSpacing: 12,
                  children: _colors
                      .map(
                        (color) => InkWell(
                          onTap: () {
                            StudentSoundService.instance.playTap();
                            setState(() => _appearance['color'] = _hex(color));
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _color == color
                                    ? const Color(0xFF102A43)
                                    : Colors.white,
                                width: _color == color ? 4 : 2,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            StudentEntrance(
              delay: const Duration(milliseconds: 225),
              child: _EditorCard(
                title: 'أضف لمسة مرحة',
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 9,
                  runSpacing: 9,
                  children: _accessories.entries
                      .map(
                        (entry) => ChoiceChip(
                          label: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: entry.key == 'none' ? 13 : 24,
                            ),
                          ),
                          selected: _accessory == entry.key,
                          onSelected: (_) => setState(
                            () => _appearance['accessory'] = entry.key,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            StudentEntrance(
              delay: const Duration(milliseconds: 240),
              child: _EditorCard(
                title: 'اختر حركة شخصيتك',
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 9,
                  runSpacing: 9,
                  children: _motions.entries
                      .map(
                        (entry) => ChoiceChip(
                          avatar: Icon(entry.value.$2, size: 18),
                          label: Text(entry.value.$1),
                          selected: _motion == entry.key,
                          onSelected: (_) {
                            StudentSoundService.instance.playTap();
                            setState(() => _appearance['motion'] = entry.key);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 18),
            StudentEntrance(
              delay: const Duration(milliseconds: 250),
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveLocalAppearance,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('حفظ شخصيتي'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            if (_canOpenCreator) ...[
              const SizedBox(height: 12),
              StudentEntrance(
                delay: const Duration(milliseconds: 300),
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _openCreator,
                  icon: const Icon(Icons.view_in_ar_rounded),
                  label: const Text('صمّم أفاتار ثلاثي الأبعاد'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppearancePreview extends StatefulWidget {
  const _AppearancePreview({
    required this.emoji,
    required this.color,
    required this.imageUrl,
    required this.outfit,
    required this.accessory,
    required this.motion,
    required this.level,
    required this.gems,
    required this.levelProgress,
  });

  final String emoji;
  final Color color;
  final String? imageUrl;
  final String outfit;
  final String accessory;
  final String motion;
  final int level;
  final int gems;
  final int levelProgress;

  @override
  State<_AppearancePreview> createState() => _AppearancePreviewState();
}

class _AppearancePreviewState extends State<_AppearancePreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _AppearancePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motion != widget.motion) {
      _controller
        ..duration = widget.motion == 'celebrate'
            ? const Duration(milliseconds: 700)
            : const Duration(milliseconds: 1400)
        ..repeat(reverse: true);
    }
  }

  void _playInteraction() {
    StudentSoundService.instance.playTap();
    _controller
      ..stop()
      ..forward(from: 0).whenComplete(() {
        if (mounted) _controller.repeat(reverse: true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.imageUrl;
    return StudentPressScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _playInteraction,
        child: Container(
        height: 330,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              StudentPalette.deepIndigo,
              StudentPalette.indigo,
              StudentPalette.sky,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: widget.color.withAlpha(90),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _GameRoomBackdrop(),
            Padding(
              padding: const EdgeInsets.only(top: 38, bottom: 62),
              child: Center(
                child: imageUrl != null
                    ? _networkAvatar(imageUrl)
                    : _animatedAvatarPreview(),
              ),
            ),
            PositionedDirectional(
              top: 16,
              start: 16,
              child: _RoomBadge(
                icon: Icons.workspace_premium_rounded,
                label: 'المستوى ${widget.level}',
                color: StudentPalette.orange,
              ),
            ),
            PositionedDirectional(
              top: 16,
              end: 16,
              child: _RoomBadge(
                icon: Icons.diamond_rounded,
                label: '${widget.gems}',
                color: StudentPalette.cyan,
              ),
            ),
            Positioned(
              right: 18,
              left: 18,
              bottom: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'تقدم البطل',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${widget.levelProgress}%',
                        style: const TextStyle(
                          color: Color(0xFFFFE08A),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: widget.levelProgress / 100,
                      minHeight: 10,
                      color: StudentPalette.orange,
                      backgroundColor: const Color(0x44FFFFFF),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'اضغط على بطلك ليتحرك!',
                    style: TextStyle(
                      color: Color(0xFFDFF8FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _networkAvatar(String imageUrl) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final progress = Curves.easeInOut.transform(_controller.value);
      final offset = widget.motion == 'celebrate'
          ? -12 * progress
          : -3 * progress;
      final angle = widget.motion == 'wave'
          ? -0.035 + (0.07 * progress)
          : 0.0;
      return Transform.translate(
        offset: Offset(0, offset),
        child: Transform.rotate(angle: angle, child: child),
      );
    },
    child: Image.network(
      imageUrl,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _animatedAvatarPreview(),
    ),
  );

  Widget _animatedAvatarPreview() => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final progress = Curves.easeInOut.transform(_controller.value);
      final translateY = widget.motion == 'celebrate'
          ? -14 * progress
          : -3 * progress;
      final angle = widget.motion == 'wave'
          ? (-0.035 + (0.07 * progress))
          : 0.0;
      return Transform.translate(
        offset: Offset(0, translateY),
        child: Transform.rotate(angle: angle, child: child),
      );
    },
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                widget.color.withOpacity(0.30),
                BlendMode.srcATop,
              ),
              child: Lottie.asset(
                'assets/animations/student-avatar-hero.json',
                width: 190,
                height: 210,
                fit: BoxFit.contain,
                repeat: true,
                animate: true,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.accessibility_new_rounded,
                  size: 140,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              top: 44,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 42)),
            ),
            Positioned(
              bottom: 42,
              child: Text(
                _StudentPersonalityScreenState._outfits[widget.outfit]?.$2 ??
                    '⭐',
                style: const TextStyle(fontSize: 28),
              ),
            ),
            if (widget.accessory != 'none')
              Positioned(
                top: 4,
                right: 5,
                child: Text(
                  _StudentPersonalityScreenState._accessories[widget
                          .accessory] ??
                      '⭐',
                  style: const TextStyle(fontSize: 38),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        const SizedBox.shrink(),
      ],
    ),
  );
}

class _GameRoomBackdrop extends StatelessWidget {
  const _GameRoomBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -55,
            left: -35,
            child: Container(
              width: 170,
              height: 170,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x3322D3EE),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4422D3EE),
                    blurRadius: 50,
                    spreadRadius: 12,
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            top: 78,
            right: 28,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xAAFFE08A),
              size: 28,
            ),
          ),
          const Positioned(
            top: 116,
            left: 34,
            child: Icon(
              Icons.sports_esports_rounded,
              color: Color(0x887DD3FC),
              size: 38,
            ),
          ),
          Positioned(
            right: 30,
            left: 30,
            bottom: 62,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0x55172554),
                borderRadius: BorderRadius.circular(50),
                boxShadow: const [
                  BoxShadow(color: Color(0x99000000), blurRadius: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomBadge extends StatelessWidget {
  const _RoomBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC172554),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Student3DCard(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9E6F5)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 13),
          child,
        ],
      ),
    ),
  );
}

class _ReadyPlayerMeCreatorScreen extends StatefulWidget {
  const _ReadyPlayerMeCreatorScreen({required this.creatorUrl});

  final Uri creatorUrl;

  @override
  State<_ReadyPlayerMeCreatorScreen> createState() =>
      _ReadyPlayerMeCreatorScreenState();
}

class _ReadyPlayerMeCreatorScreenState
    extends State<_ReadyPlayerMeCreatorScreen> {
  bool _loaded = false;
  String? _message;

  void _onMessage(List<dynamic> arguments) {
    if (arguments.isEmpty || arguments.first is! Map) return;
    final payload = Map<String, dynamic>.from(arguments.first as Map);
    if (payload['source'] != 'readyplayerme' ||
        payload['eventName'] != 'v1.avatar.exported' ||
        payload['origin'] != widget.creatorUrl.origin) {
      return;
    }
    final data = payload['data'];
    if (data is! Map) return;
    final export = _readyPlayerMeExport(data['url']?.toString());
    if (export == null) {
      setState(() => _message = 'رابط الأفاتار غير صالح. حاول الحفظ مرة أخرى.');
      return;
    }
    Navigator.of(context).pop(export);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFF071425),
      appBar: AppBar(
        title: const Text('مصمم شخصيتي'),
        backgroundColor: const Color(0xFF071425),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(_creatorWithFrameApi().toString()),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              supportMultipleWindows: false,
              javaScriptCanOpenWindowsAutomatically: false,
            ),
            onWebViewCreated: (controller) {
              controller.addJavaScriptHandler(
                handlerName: 'manaraReadyPlayerMe',
                callback: _onMessage,
              );
            },
            onLoadStop: (controller, _) async {
              await controller.evaluateJavascript(
                source: '''
                    window.addEventListener('message', function(event) {
                      var data = event.data;
                      if (typeof data === 'string') {
                        try { data = JSON.parse(data); } catch (_) { return; }
                      }
                      if (data && data.source === 'readyplayerme' &&
                          window.flutter_inappwebview) {
                        window.flutter_inappwebview.callHandler(
                           'manaraReadyPlayerMe', {
                             source: data.source,
                             eventName: data.eventName,
                             data: data.data,
                             origin: event.origin
                           });
                      }
                    });
                    window.parent.postMessage(JSON.stringify({
                      target: 'readyplayerme', type: 'subscribe',
                      eventName: 'v1.avatar.exported'
                    }), '*');
                  ''',
              );
              if (mounted) setState(() => _loaded = true);
            },
          ),
          if (!_loaded) const Center(child: CircularProgressIndicator()),
          if (_message != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F1D1D),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _message ?? 'تعذر إكمال تصميم الشخصية.',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Uri _creatorWithFrameApi() {
    final parameters =
        Map<String, String>.from(widget.creatorUrl.queryParameters)
          ..['frameApi'] = ''
          ..['source'] = 'manara';
    return widget.creatorUrl.replace(queryParameters: parameters);
  }
}

class _ReadyPlayerMeExport {
  const _ReadyPlayerMeExport({
    required this.modelUrl,
    required this.avatarId,
    required this.imageUrl,
  });

  final String modelUrl;
  final String avatarId;
  final String imageUrl;
}

Uri? _validCreatorUrl(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
      ? uri
      : null;
}

_ReadyPlayerMeExport? _readyPlayerMeExport(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.toLowerCase() != 'models.readyplayer.me' ||
      !uri.path.toLowerCase().endsWith('.glb')) {
    return null;
  }
  final filename = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  final avatarId = filename.substring(0, filename.length - 4);
  if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(avatarId)) return null;
  return _ReadyPlayerMeExport(
    modelUrl: uri.toString(),
    avatarId: avatarId,
    imageUrl:
        'https://models.readyplayer.me/$avatarId.png?camera=fullbody&size=512',
  );
}

String _hex(Color color) =>
    '#${color.red.toRadixString(16).padLeft(2, '0')}${color.green.toRadixString(16).padLeft(2, '0')}${color.blue.toRadixString(16).padLeft(2, '0')}';
