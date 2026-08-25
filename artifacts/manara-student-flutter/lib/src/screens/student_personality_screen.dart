import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/student_profile.dart';
import '../services/student_content_service.dart';
import '../services/student_sound_service.dart';
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
  static const _emojis = ['🦸', '🧑‍🚀', '🧙', '🦁', '🐼', '🌟'];
  static const _colors = [
    Color(0xFF38BDF8),
    Color(0xFFF97316),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFFACC15),
  ];

  late Map<String, dynamic> _appearance;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _appearance = Map<String, dynamic>.from(widget.profile.appearance ?? {});
  }

  String get _emoji => _appearance['shape']?.toString().trim().isNotEmpty == true
      ? _appearance['shape'].toString()
      : '🌟';

  Color get _color {
    final value = _appearance['color']?.toString() ?? '';
    return _colors.firstWhere(
      (color) => _hex(color).toLowerCase() == value.toLowerCase(),
      orElse: () => _colors.first,
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أحسنت! تم حفظ شخصيتك ✨')),
      );
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
    };
    next.remove('readyPlayerMeAvatarUrl');
    next.remove('readyPlayerMeAvatarId');
    next.remove('readyPlayerMeAvatarImageUrl');
    return _save(next);
  }

  Future<void> _openCreator() async {
    final url = _validCreatorUrl(widget.creatorUrl);
    if (url == null) return;
    StudentSoundService.instance.play(StudentSoundCue.navigation);
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        appBar: AppBar(title: const Text('شخصيتي'), centerTitle: true, actions: const [StudentSoundToggle()]),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const StudentEntrance(
              child: Text(
                'اصنع بطلك الرائع!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 7),
            const StudentEntrance(
              delay: Duration(milliseconds: 50),
              child: Text(
                'اختر شارة ولونًا يعبران عنك، ثم احفظ شخصيتك.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF49617C), fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 22),
            StudentEntrance(
              delay: const Duration(milliseconds: 100),
              child: _AppearancePreview(
                emoji: _emoji,
                color: _color,
                imageUrl: _avatarImageUrl,
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
                          label: Text(emoji, style: const TextStyle(fontSize: 28)),
                          selected: _emoji == emoji,
                          onSelected: (_) {
                            StudentSoundService.instance.play(StudentSoundCue.navigation);
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
                            StudentSoundService.instance.play(StudentSoundCue.navigation);
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
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({
    required this.emoji,
    required this.color,
    required this.imageUrl,
  });

  final String emoji;
  final Color color;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 244,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(colors: [color, const Color(0xFF102A43)]),
        boxShadow: [BoxShadow(color: color.withAlpha(90), blurRadius: 22)],
      ),
      child: Center(
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _emojiPreview(),
              )
            : _emojiPreview(),
      ),
    );
  }

  Widget _emojiPreview() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 100)),
          const SizedBox(height: 5),
          const Text(
            'هذا بطلي!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ],
      );
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
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
      );
}

class _ReadyPlayerMeCreatorScreen extends StatefulWidget {
  const _ReadyPlayerMeCreatorScreen({required this.creatorUrl});

  final Uri creatorUrl;

  @override
  State<_ReadyPlayerMeCreatorScreen> createState() =>
      _ReadyPlayerMeCreatorScreenState();
}

class _ReadyPlayerMeCreatorScreenState extends State<_ReadyPlayerMeCreatorScreen> {
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
                  await controller.evaluateJavascript(source: '''
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
                  ''');
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
                    child: Text(_message!, style: const TextStyle(color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      );

  Uri _creatorWithFrameApi() {
    final parameters = Map<String, String>.from(widget.creatorUrl.queryParameters)
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
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty ? uri : null;
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
    imageUrl: 'https://models.readyplayer.me/$avatarId.png',
  );
}

String _hex(Color color) =>
    '#${color.red.toRadixString(16).padLeft(2, '0')}${color.green.toRadixString(16).padLeft(2, '0')}${color.blue.toRadixString(16).padLeft(2, '0')}';