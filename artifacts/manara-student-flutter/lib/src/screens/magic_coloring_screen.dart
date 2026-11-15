import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import 'package:gal/gal.dart';

import '../services/coloring_canvas.dart';
import '../services/coloring_cloud.dart';
import '../services/coloring_drawings.dart';
import '../services/free_drawing.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/student_avatar_view.dart';

/// «لوحة الألوان السحرية»: يختار الطفلُ رسمةً ويلوّنها بإصبعه.
///
/// ── الأدوات ──
/// الدلو يملأ المنطقةَ تحت الإصبع، والفرشاةُ ترسم خطّاً لا يخرج عن المنطقة
/// التي بدأ فيها، وفرشاةُ قوس قزح يتبدّل لونُها مع الحركة، والممحاةُ تعيد
/// الورقَ أبيض. وفي كل حين: تراجعٌ خطوةً، ومسحُ اللوحة.
///
/// ── الحفظ ──
/// «احفظ لوحتي» يضعها في «لوحاتي» على الجهاز ([ColoringGallery]) ثم يحتفل:
/// ورقٌ ملوّنٌ يطير و«أحسنت يا بطل!» بصوتها المسجّل وخلفها التصفيق.
///
/// ── والتجديد ──
/// كلُّ دخولٍ يأتي بمجموعةٍ جديدة ([pickColoringSet]): ما عُرض في المرّة
/// السابقة لا يعود حتى تُعرض البقية، ورسمتان مولَّدتان لم تُرَيا قط.
class MagicColoringScreen extends StatefulWidget {
  const MagicColoringScreen({
    this.account,
    this.random,
    this.playIntro,
    this.cheer,
    this.saveToPhotos,
    super.key,
  });

  /// الطالبُ: معرّفُه يفصل «لوحاتي» على الجهاز، وسحابتُه تحفظ لوحاته على
  /// الخادم. وبلا قيمة (الاختبار): «لوحاتُ» ضيفٍ على الجهاز وحده.
  final ColoringAccount? account;

  /// يحفظ صورةً في استوديو الجهاز. وبلا قيمة: `gal`.
  final Future<bool> Function(Uint8List png)? saveToPhotos;

  /// تُستبدل في الاختبار.
  final math.Random? random;

  /// مقدّمةُ اللعبة بصوتها المسجّل. وبلا قيمة: `intro_coloring.mp3`.
  final VoidCallback? playIntro;

  /// «أحسنت يا بطل» وخلفها التصفيق، عند الحفظ.
  final Future<void> Function()? cheer;

  /// مقدّمةُ اللعبة: «لعبة التلوين.mp3» منسوخاً باسمٍ لاتينيّ — الأسماءُ
  /// العربية في مسارات الأصول تُرمَّز في بيان الحزمة فلا يجدها المشغّل.
  static const introClip = 'audio/games/intro_coloring.mp3';

  @override
  State<MagicColoringScreen> createState() => MagicColoringScreenState();
}

enum ColoringTool { fill, brush, rainbow, shapes, stamps, eraser, smartEraser }

/// أين حُفظت اللوحة: على الجهاز، أو في السحابة، أو في استوديو الجهاز.
enum ColoringSaveTarget { device, cloud, photos }

/// طريقتا اللعب: رسمةٌ جاهزةٌ تُلوَّن، أو ورقةٌ بيضاء يرسم عليها الطفلُ بنفسه.
enum ColoringMode { ready, free }

@visibleForTesting
class MagicColoringScreenState extends State<MagicColoringScreen> {
  static const palette = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFFACC15),
    Color(0xFFFDE68A),
    Color(0xFF84CC16),
    Color(0xFF16A34A),
    Color(0xFF14B8A6),
    Color(0xFF38BDF8),
    Color(0xFF2563EB),
    Color(0xFF1E3A8A),
    Color(0xFF8B5CF6),
    Color(0xFFD946EF),
    Color(0xFFF472B6),
    Color(0xFFFBCFE8),
    Color(0xFFFDBA74),
    Color(0xFF92400E),
    Color(0xFF9CA3AF),
    Color(0xFF111827),
  ];

  /// عرضُ الفرشاة بوحدات الرسمة: من خطٍّ رفيعٍ جدّاً إلى فرشاةٍ عريضة.
  static const brushSizes = [3.0, 6.0, 12.0, 20.0, 32.0];

  /// لوحةُ الألوان الموسّعة: اثنا عشر لوناً بستّ درجاتٍ لكلٍّ منها، ثم الرماديات.
  static final extendedPalette = <Color>[
    for (var hue = 0; hue < 12; hue++)
      for (final (s, v) in const [(0.25, 1.0), (0.5, 1.0), (0.8, 1.0), (1.0, 0.9), (1.0, 0.65), (1.0, 0.4)])
        HSVColor.fromAHSV(1, hue * 30.0, s, v).toColor(),
    for (var i = 0; i <= 7; i++) Color.lerp(const Color(0xFFFFFFFF), const Color(0xFF000000), i / 7)!,
    const Color(0xFFFFE0BD),
    const Color(0xFFF1C27D),
    const Color(0xFFC68642),
    const Color(0xFF8D5524),
  ];

  static const brushIcons = <BrushStyle, (IconData, String)>{
    BrushStyle.pen: (Icons.edit_rounded, 'coloring.brush.pen'),
    BrushStyle.marker: (Icons.border_color_rounded, 'coloring.brush.marker'),
    BrushStyle.crayon: (Icons.draw_rounded, 'coloring.brush.crayon'),
    BrushStyle.spray: (Icons.blur_on_rounded, 'coloring.brush.spray'),
    BrushStyle.neon: (Icons.flare_rounded, 'coloring.brush.neon'),
    BrushStyle.dotted: (Icons.more_horiz_rounded, 'coloring.brush.dotted'),
    BrushStyle.calligraphy: (Icons.gesture_rounded, 'coloring.brush.calligraphy'),
    BrushStyle.glitter: (Icons.auto_awesome_rounded, 'coloring.brush.glitter'),
  };

  /// الأختام: تُطبع بلمسة، وحجمُها من حجم الفرشاة.
  static const stampIcons = <ShapeKind, String>{
    ShapeKind.star: '⭐',
    ShapeKind.heart: '❤️',
    ShapeKind.flower: '🌸',
    ShapeKind.sparkle: '✨',
    ShapeKind.moon: '🌙',
    ShapeKind.cloud: '☁️',
    ShapeKind.circle: '🔵',
  };

  /// نصفُ قطر الختم بوحدات الرسمة، لكل حجمٍ من [brushSizes].
  static const stampRadii = [10.0, 16.0, 24.0, 34.0, 46.0];

  static const shapeIcons = <ShapeKind, (IconData, String)>{
    ShapeKind.line: (Icons.horizontal_rule_rounded, 'coloring.shape.line'),
    ShapeKind.rectangle: (Icons.crop_square_rounded, 'coloring.shape.rectangle'),
    ShapeKind.circle: (Icons.circle_outlined, 'coloring.shape.circle'),
    ShapeKind.triangle: (Icons.change_history_rounded, 'coloring.shape.triangle'),
    ShapeKind.star: (Icons.star_outline_rounded, 'coloring.shape.star'),
    ShapeKind.heart: (Icons.favorite_border_rounded, 'coloring.shape.heart'),
  };

  late final math.Random _random = widget.random ?? math.Random();
  late final ConfettiController _confetti = ConfettiController(duration: const Duration(milliseconds: 900));

  List<String> _set = const [];
  final Map<String, ColoringController> _blank = {};
  List<ColoringArtwork> _gallery = const [];
  final Set<String> _colored = {};

  ColoringArtwork? _controller;

  /// `null`: شاشةُ الاختيار بين الطريقتين.
  ColoringMode? _mode;

  String get _owner => widget.account?.studentId ?? 'guest';
  ColoringCloud? get _cloud => widget.account?.cloud;

  /// «لوحاتي في السحابة»، و`null` قبل أن تُحمَّل.
  List<CloudArtwork>? _cloudItems;
  CloudProblem? _cloudProblem;

  /// اللوحةُ مفتوحةٌ من السحابة: حفظُها فيها يحلّ محلّها.
  String? _cloudId;
  ColoringSaveTarget? _savedTo;

  @visibleForTesting
  List<CloudArtwork>? get cloudItems => _cloudItems;

  /// موضعُ اللوحة في «لوحاتي» إن فُتحت منها: حفظُها يحلّ محلّ القديمة.
  int? _galleryIndex;

  ColoringTool _tool = ColoringTool.fill;
  Color _color = palette.first;
  int _size = 2;
  BrushStyle _brush = BrushStyle.pen;
  ShapeKind _shape = ShapeKind.rectangle;
  bool _shapeFilled = false;
  ShapeKind _stamp = ShapeKind.star;

  /// تدرّجٌ سحريٌّ مختار بدل اللون، أو `null`.
  int? _magic;

  @visibleForTesting
  int? get magic => _magic;

  @visibleForTesting
  ColoringTool get tool => _tool;
  @visibleForTesting
  Color get color => _color;
  bool _celebrating = false;
  bool _saving = false;

  @visibleForTesting
  List<String> get drawingSet => _set;

  @visibleForTesting
  ColoringArtwork? get controller => _controller;

  @visibleForTesting
  ColoringMode? get mode => _mode;

  @visibleForTesting
  bool get celebrating => _celebrating;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSet());
    unawaited(_loadGallery());
    unawaited(_loadCloud());
    try {
      (widget.playIntro ?? () => StudentSoundService.instance.playGameIntro(MagicColoringScreen.introClip))();
    } catch (error) {
      debugPrint('[coloring] intro failed: $error');
    }
  }

  @override
  void dispose() {
    if (widget.playIntro == null) StudentSoundService.instance.stopGameSounds();
    _confetti.dispose();
    for (final c in _blank.values) {
      c.dispose();
    }
    _controller?.dispose();
    for (final c in _gallery) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSet() async {
    final recent = await ColoringGallery.recent();
    final set = pickColoringSet(_random, recent: [...recent, ..._set]);
    unawaited(ColoringGallery.remember(set));
    if (!mounted) return;
    setState(() => _set = set);
  }

  Future<void> _loadGallery() async {
    final gallery = await ColoringGallery.load(owner: _owner);
    if (!mounted) {
      for (final c in gallery) {
        c.dispose();
      }
      return;
    }
    final old = _gallery;
    setState(() => _gallery = gallery);
    _disposeAfterFrame(old);
  }

  /// ما زالت صورُه المصغّرةُ مرسومةً حتى الإطار التالي — فيُتخلّص منه بعده.
  void _disposeAfterFrame(Iterable<ColoringArtwork> controllers) {
    final list = controllers.toList();
    if (list.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in list) {
        c.dispose();
      }
    });
  }

  ColoringController _blankFor(String id) =>
      _blank[id] ??= ColoringController(coloringDrawingById(id) ?? mandala(1));

  void _openDrawing(String id) {
    final drawing = coloringDrawingById(id);
    if (drawing == null) return;
    HapticFeedback.selectionClick();
    _mode = ColoringMode.ready;
    _replaceController(ColoringController(drawing), galleryIndex: null);
  }

  /// يسأل ثم يمحو اللوحةَ من «لوحاتي» على الجهاز.
  Future<void> _confirmDelete(int index) async {
    if (index < 0 || index >= _gallery.length) return;
    final yes = await _askDelete(CustomPaint(painter: _gallery[index].painter(outline: 4)));
    if (yes != true || !mounted) return;
    final ok = await ColoringGallery.delete(index, owner: _owner);
    if (!mounted) return;
    if (!ok) {
      _toast(tr('coloring.saveFailed'));
      return;
    }
    // ‏لوحةٌ مفتوحةٌ من «لوحاتي»: موضعُها يتبع الحذف، أو تصير جديدةً إن حُذفت هي.
    final open = _galleryIndex;
    if (open != null) _galleryIndex = open == index ? null : (open > index ? open - 1 : open);
    await _loadGallery();
    _toast(tr('coloring.deleted'));
  }

  /// نافذةُ «حذف هذه اللوحة؟» بصورتها — للجهاز وللسحابة.
  Future<bool?> _askDelete(Widget preview) {
    HapticFeedback.mediumImpact();
    return showDialog<bool>(
      context: context,
      builder: (dialog) => Directionality(
        textDirection: StudentSettings.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.delete_rounded, color: Color(0xFFDC2626)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tr('coloring.deleteAsk'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 140,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFCA5A5), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: preview,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(tr('coloring.deleteHint'), textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('coloring-delete-cancel'),
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(tr('coloring.cancel'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            FilledButton.icon(
              key: const ValueKey('coloring-delete-confirm'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626), shape: const StadiumBorder()),
              onPressed: () => Navigator.of(dialog).pop(true),
              icon: const Icon(Icons.delete_forever_rounded),
              label: Text(tr('coloring.deleteYes'), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  // ── السحابة ──

  Future<void> _loadCloud() async {
    final cloud = _cloud;
    if (cloud == null) return;
    try {
      final items = await cloud.list();
      if (mounted) {
        setState(() {
          _cloudItems = items;
          _cloudProblem = null;
        });
      }
    } on CloudException catch (error) {
      debugPrint('[coloring] cloud list: ${error.problem}');
      if (mounted) setState(() => _cloudProblem = error.problem);
    }
  }

  String _cloudMessage(CloudProblem problem, [String? said]) => switch (problem) {
        CloudProblem.notDeployed => tr('coloring.cloud.notDeployed'),
        CloudProblem.full => said ?? tr('coloring.cloud.full'),
        CloudProblem.session => tr('coloring.cloud.session'),
        CloudProblem.unavailable => tr('coloring.cloud.unavailable'),
      };

  Future<void> _openCloud(CloudArtwork item) async {
    final cloud = _cloud;
    if (cloud == null) return;
    HapticFeedback.selectionClick();
    try {
      final artwork = await cloud.open(item.id);
      if (!mounted) return;
      if (artwork == null) {
        _toast(tr('coloring.cloud.unavailable'));
        return;
      }
      _mode = artwork is FreeDrawingController ? ColoringMode.free : ColoringMode.ready;
      if (artwork is FreeDrawingController) _tool = ColoringTool.brush;
      _replaceController(artwork, galleryIndex: null);
      _cloudId = item.id;
    } on CloudException catch (error) {
      if (mounted) _toast(_cloudMessage(error.problem, error.message));
    }
  }

  Future<void> _deleteCloud(CloudArtwork item) async {
    final cloud = _cloud;
    if (cloud == null) return;
    final yes = await _askDelete(_cloudThumb(item));
    if (yes != true || !mounted) return;
    try {
      await cloud.delete(item.id);
      if (_cloudId == item.id) _cloudId = null;
      await _loadCloud();
      if (mounted) _toast(tr('coloring.deleted'));
    } on CloudException catch (error) {
      if (mounted) _toast(_cloudMessage(error.problem, error.message));
    }
  }

  Widget _cloudThumb(CloudArtwork item) => Image.network(
        _cloud!.imageUrl(item.id).toString(),
        headers: _cloud!.imageHeaders,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Text('☁️', style: TextStyle(fontSize: 34))),
      );

  void _openArtwork(int index) {
    final saved = _gallery[index];
    // ‏نسخةٌ للتعديل: الصورةُ المصغّرة في «لوحاتي» تبقى كما حُفظت حتى يُحفظ جديد.
    final copy = ColoringArtwork.fromJson(saved.toJson());
    if (copy == null) return;
    HapticFeedback.selectionClick();
    _mode = copy is FreeDrawingController ? ColoringMode.free : ColoringMode.ready;
    if (copy is FreeDrawingController) _tool = ColoringTool.brush;
    _replaceController(copy, galleryIndex: index);
  }


  /// ورقةٌ بيضاءُ جديدة: قلمٌ أسودُ رفيعٌ في اليد، ليرسم الطفلُ خطوطَه أوّلاً.
  void _startFree() {
    HapticFeedback.selectionClick();
    setState(() {
      _mode = ColoringMode.free;
      _tool = ColoringTool.brush;
      _color = palette.last;
      _size = 1;
      _brush = BrushStyle.pen;
    });
    _replaceController(FreeDrawingController(), galleryIndex: null);
  }

  void _chooseReady() {
    HapticFeedback.selectionClick();
    setState(() => _mode = ColoringMode.ready);
  }

  void _replaceController(ColoringArtwork? next, {required int? galleryIndex}) {
    final old = _controller;
    setState(() {
      _controller = next;
      _galleryIndex = galleryIndex;
      _cloudId = null;
      _celebrating = false;
    });
    if (old != null) _disposeAfterFrame([old]);
  }

  /// من اللوح: الرسمُ الحرُّ يعود إلى شاشة الاختيار، والجاهزُ إلى رسوماته.
  void _backToPicker() {
    if (_mode == ColoringMode.free) _mode = null;
    _replaceController(null, galleryIndex: null);
  }

  void _nextDrawing() {
    if (_controller is FreeDrawingController) {
      _startFree();
      return;
    }
    final current = _controller?.artworkId;
    if (current != null) _colored.add(current);
    final next = _set.where((id) => !_colored.contains(id) && id != current).toList();
    if (next.isEmpty) {
      unawaited(_loadSet().then((_) {
        if (mounted && _set.isNotEmpty) _openDrawing(_set.first);
      }));
      return;
    }
    _openDrawing(next.first);
  }

  /// «احفظ لوحتي»: يختار الطالبُ أين — على هذا الجهاز، أو في السحابة، أو في
  /// استوديو الجهاز.
  Future<void> _save() async {
    final controller = _controller;
    if (controller == null || _saving) return;
    if (controller.isEmpty) {
      _toast(tr('coloring.empty'));
      return;
    }
    HapticFeedback.selectionClick();
    final cloudReady = _cloud != null && _cloudProblem != CloudProblem.notDeployed;
    final target = await showModalBottomSheet<ColoringSaveTarget>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => Directionality(
        textDirection: StudentSettings.direction,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('💾 ${tr('coloring.saveWhere')}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                _saveOption(sheet,
                    key: 'coloring-save-device',
                    emoji: '📱',
                    title: tr('coloring.save.device'),
                    subtitle: tr('coloring.save.deviceSub'),
                    target: ColoringSaveTarget.device),
                if (_cloud != null)
                  _saveOption(sheet,
                      key: 'coloring-save-cloud',
                      emoji: '☁️',
                      title: tr('coloring.save.cloud'),
                      subtitle: cloudReady ? tr('coloring.save.cloudSub') : tr('coloring.cloud.notDeployed'),
                      target: cloudReady ? ColoringSaveTarget.cloud : null),
                _saveOption(sheet,
                    key: 'coloring-save-photos',
                    emoji: '🖼️',
                    title: tr('coloring.save.photos'),
                    subtitle: tr('coloring.save.photosSub'),
                    target: ColoringSaveTarget.photos),
              ],
            ),
          ),
        ),
      ),
    );
    if (target == null || !mounted) return;
    setState(() => _saving = true);
    final ok = switch (target) {
      ColoringSaveTarget.device => await _saveDevice(controller),
      ColoringSaveTarget.cloud => await _saveCloud(controller),
      ColoringSaveTarget.photos => await _savePhotos(controller),
    };
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) await _celebrate(controller, target);
  }

  Widget _saveOption(
    BuildContext sheet, {
    required String key,
    required String emoji,
    required String title,
    required String subtitle,
    required ColoringSaveTarget? target,
  }) =>
      ListTile(
        key: ValueKey(key),
        enabled: target != null,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFCE7F3),
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        onTap: target == null ? null : () => Navigator.of(sheet).pop(target),
      );

  Future<bool> _saveDevice(ColoringArtwork controller) async {
    final ok = await ColoringGallery.save(controller, owner: _owner, replacing: _galleryIndex);
    if (!mounted) return false;
    if (!ok) {
      _toast(tr('coloring.saveFailed'));
      return false;
    }
    _galleryIndex = 0;
    unawaited(_loadGallery());
    return true;
  }

  Future<bool> _saveCloud(ColoringArtwork controller) async {
    final cloud = _cloud;
    if (cloud == null) return false;
    try {
      final saved = await cloud.save(
        controller,
        title: controller.title(arabic: StudentSettings.isArabic),
        replaces: _cloudId,
      );
      _cloudId = saved.id.isEmpty ? null : saved.id;
      unawaited(_loadCloud());
      return true;
    } on CloudException catch (error) {
      if (error.problem == CloudProblem.notDeployed && mounted) {
        setState(() => _cloudProblem = CloudProblem.notDeployed);
      }
      if (mounted) _toast(_cloudMessage(error.problem, error.message));
      return false;
    }
  }

  /// صورةٌ بضلع ١٠٢٤ في استوديو الجهاز — الصور في iOS والمعرض في أندرويد.
  Future<bool> _savePhotos(ColoringArtwork controller) async {
    final png = await controller.toPng(size: 1024);
    if (png == null) {
      if (mounted) _toast(tr('chat.art.saveToPhotosFailed'));
      return false;
    }
    final saver = widget.saveToPhotos ??
        (Uint8List bytes) async {
          if (!await Gal.hasPermission() && !await Gal.requestPermission()) {
            if (mounted) _toast(tr('chat.art.saveDenied'));
            return false;
          }
          await Gal.putImageBytes(bytes, name: 'manara_${DateTime.now().millisecondsSinceEpoch}');
          return true;
        };
    try {
      return await saver(png);
    } catch (error) {
      debugPrint('[coloring] photos save failed: $error');
      if (mounted) {
        _toast(tr(error is GalException && error.type == GalExceptionType.permissionDenied
            ? 'chat.art.saveDenied'
            : 'chat.art.saveToPhotosFailed'));
      }
      return false;
    }
  }

  Future<void> _celebrate(ColoringArtwork controller, ColoringSaveTarget target) async {
    _colored.add(controller.artworkId);
    setState(() {
      _savedTo = target;
      _celebrating = true;
    });
    _confetti.play();
    try {
      if (widget.cheer != null) {
        await widget.cheer!();
      } else {
        final sound = StudentSoundService.instance..stopGameSounds();
        await sound.playCheerToEnd(StudentSoundService.ahsantClip);
      }
    } catch (error) {
      debugPrint('[coloring] cheer failed: $error');
    }
  }

  void _toast(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
      ));
  }

  String _title(ColoringDrawing d) => StudentSettings.isArabic ? d.titleAr : d.titleEn;

  // ── البناء ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final painting = _controller != null;
    return Directionality(
      textDirection: StudentSettings.direction,
      child: PopScope(
        canPop: !painting && _mode == null,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (painting) {
            _backToPicker();
          } else if (_mode != null) {
            setState(() => _mode = null);
          }
        },
        child: Scaffold(
          backgroundColor: StudentSurface.ground(context),
          body: Stack(
            children: [
              const PortalWatermark(asset: PortalBackgrounds.games, opacity: 0.22),
              SafeArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  child: painting
                      ? _painting(context, _controller!)
                      : _mode == ColoringMode.ready
                          ? _picker(context)
                          : _modeMenu(context),
                ),
              ),
              if (_celebrating && _controller != null) _celebration(context, _controller!),
              Align(
                alignment: Alignment.topCenter,
                child: IgnorePointer(
                  child: ConfettiWidget(
                    confettiController: _confetti,
                    blastDirectionality: BlastDirectionality.explosive,
                    emissionFrequency: 0,
                    numberOfParticles: 36,
                    maxBlastForce: 24,
                    minBlastForce: 8,
                    gravity: 0.22,
                    shouldLoop: false,
                    colors: const [
                      Color(0xFFEF4444),
                      Color(0xFFF59E0B),
                      Color(0xFF22C55E),
                      Color(0xFF3B82F6),
                      Color(0xFFA855F7),
                      Color(0xFFEC4899),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleBar(BuildContext context, {required String title, required VoidCallback onBack, List<Widget> actions = const []}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 10, 2),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('coloring-back'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: StudentSurface.ink(context),
            ),
            const Text('🎨', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: StudentSurface.vivid(context, const Color(0xFFDB2777)),
                ),
              ),
            ),
            ...actions,
          ],
        ),
      );

  // ── اختيارُ الرسمة ──

  static const _categoryEmoji = {
    ColoringCategory.animals: '🐾',
    ColoringCategory.nature: '🌿',
    ColoringCategory.characters: '🤖',
    ColoringCategory.shapes: '⭐',
    ColoringCategory.objects: '🚀',
    ColoringCategory.magic: '✨',
  };

  Widget _picker(BuildContext context) => Column(
        key: const ValueKey('coloring-picker'),
        children: [
          _titleBar(
            context,
            title: tr('coloring.mode.ready'),
            onBack: () => setState(() => _mode = null),
            actions: [
              FilledButton.icon(
                key: const ValueKey('coloring-new-set'),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  unawaited(_loadSet());
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(tr('coloring.newSet'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                ..._gallerySlivers(context),
                SliverToBoxAdapter(child: _sectionLabel(context, '✏️ ${tr('coloring.pick')}')),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 210,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.84,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      childCount: _set.length,
                      (context, i) => _drawingCard(context, i),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );


  /// «لوحاتي»: اللوحاتُ المحفوظة بنوعيها، وعلى كلٍّ منها زرُّ حذف.
  List<Widget> _gallerySlivers(BuildContext context) => [
        ..._cloudSlivers(context),
        if (_gallery.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _sectionLabel(context, '🖼️ ${tr('coloring.myArt')}')),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 128,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: _gallery.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, i) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _thumb(
                              key: ValueKey('coloring-art-$i'),
                              controller: _gallery[i],
                              size: 104,
                              onTap: () => _openArtwork(i),
                            ),
                            // ‏زرُّ حذفٍ أحمرُ ظاهرٌ على زاوية اللوحة، وبتأكيد.
                            PositionedDirectional(
                              top: -8,
                              end: -8,
                              child: Semantics(
                                button: true,
                                label: tr('coloring.delete'),
                                child: GestureDetector(
                                  key: ValueKey('coloring-art-delete-$i'),
                                  onTap: () => unawaited(_confirmDelete(i)),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: const [
                                        BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2)),
                                      ],
                                    ),
                                    child: const Icon(Icons.delete_rounded, size: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
        ],
      ];

  /// «لوحاتي في السحابة»: تُفتح من أيّ جهاز، وعلى كلٍّ منها زرُّ حذف.
  List<Widget> _cloudSlivers(BuildContext context) {
    final items = _cloudItems;
    if (_cloud == null || items == null || items.isEmpty) return const [];
    return [
      SliverToBoxAdapter(child: _sectionLabel(context, '☁️ ${tr('coloring.cloud.title')}')),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 128,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) => Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  key: ValueKey('coloring-cloud-$i'),
                  onTap: () => unawaited(_openCloud(items[i])),
                  child: Container(
                    width: 104,
                    height: 104,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF93C5FD), width: 2),
                      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3))],
                    ),
                    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _cloudThumb(items[i])),
                  ),
                ),
                PositionedDirectional(
                  top: -8,
                  end: -8,
                  child: Semantics(
                    button: true,
                    label: tr('coloring.delete'),
                    child: GestureDetector(
                      key: ValueKey('coloring-cloud-delete-$i'),
                      onTap: () => unawaited(_deleteCloud(items[i])),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: const Icon(Icons.delete_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  // ── شاشةُ الاختيار: تلوينٌ جاهز، أو رسمٌ حرّ ──

  Widget _modeMenu(BuildContext context) => Column(
        key: const ValueKey('coloring-menu'),
        children: [
          _titleBar(context, title: tr('portal.coloring'), onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _sectionLabel(context, '🌟 ${tr('coloring.mode.pick')}')),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final cards = [
                          _modeCard(
                            key: const ValueKey('coloring-mode-ready'),
                            emoji: '🖍️',
                            title: tr('coloring.mode.ready'),
                            subtitle: tr('coloring.mode.readySub'),
                            colors: const [Color(0xFFF97316), Color(0xFFEC4899)],
                            onTap: _chooseReady,
                            index: 0,
                          ),
                          _modeCard(
                            key: const ValueKey('coloring-mode-free'),
                            emoji: '✏️',
                            title: tr('coloring.mode.free'),
                            subtitle: tr('coloring.mode.freeSub'),
                            colors: const [Color(0xFF0EA5E9), Color(0xFF8B5CF6)],
                            onTap: _startFree,
                            index: 1,
                          ),
                        ];
                        if (c.maxWidth < 520) {
                          return Column(children: [cards[0], const SizedBox(height: 14), cards[1]]);
                        }
                        return Row(children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 14),
                          Expanded(child: cards[1]),
                        ]);
                      },
                    ),
                  ),
                ),
                ..._gallerySlivers(context),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ],
      );

  Widget _modeCard({
    required Key key,
    required String emoji,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
    required int index,
  }) =>
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 500 + 150 * index),
        curve: Curves.elasticOut,
        builder: (context, t, child) => Transform.scale(scale: 0.6 + 0.4 * t, child: child),
        child: GestureDetector(
          key: key,
          onTap: onTap,
          child: Container(
            height: 170,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 3),
              boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))],
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 58)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [Shadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2))],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.95)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      );

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
        child: Text(
          text,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
        ),
      );

  Widget _thumb({required Key key, required ColoringArtwork controller, required double size, required VoidCallback onTap}) =>
      GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF9A8D4), width: 2),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(painter: controller.painter(outline: 4)),
          ),
        ),
      );

  Widget _drawingCard(BuildContext context, int i) {
    final id = _set[i];
    final blank = _blankFor(id);
    final drawing = blank.drawing;
    return TweenAnimationBuilder<double>(
      key: ValueKey('coloring-card-$id'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + 70 * i),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
      child: GestureDetector(
        key: ValueKey('coloring-pick-$i'),
        onTap: () => _openDrawing(id),
        child: Container(
          decoration: BoxDecoration(
            color: StudentSurface.card(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFFBCFE8), width: 2),
            boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 12, offset: Offset(0, 5))],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    clipBehavior: Clip.antiAlias,
                    child: CustomPaint(painter: ColoringPainter(blank, outline: 3.6)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _title(drawing),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
              ),
              Text(
                '${_categoryEmoji[drawing.category]} ${tr('coloring.cat.${drawing.category.name}')}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: StudentSurface.mutedInk(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── التلوين ──

  Widget _painting(BuildContext context, ColoringArtwork controller) => LayoutBuilder(
        key: const ValueKey('coloring-painting'),
        builder: (context, constraints) {
          final wide = constraints.maxWidth > constraints.maxHeight * 1.05;
          final board = Padding(
            padding: const EdgeInsets.all(10),
            child: Center(
              child: _ColoringBoard(
                key: const ValueKey('coloring-board'),
                controller: controller,
                tool: _tool,
                color: _color,
                width: brushSizes[_size],
                brush: _brush,
                shape: _shape,
                shapeFilled: _shapeFilled,
                stamp: _stamp,
                stampRadius: stampRadii[_size],
                magic: _magic,
              ),
            ),
          );
          final bar = _titleBar(
            context,
            title: controller.title(arabic: StudentSettings.isArabic),
            onBack: _backToPicker,
            actions: [
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => IconButton(
                  key: const ValueKey('coloring-undo'),
                  tooltip: tr('coloring.undo'),
                  onPressed: controller.canUndo ? controller.undo : null,
                  icon: const Icon(Icons.undo_rounded),
                  color: StudentSurface.ink(context),
                ),
              ),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => IconButton(
                  key: const ValueKey('coloring-redo'),
                  tooltip: tr('coloring.redo'),
                  onPressed: controller.canRedo ? controller.redo : null,
                  icon: const Icon(Icons.redo_rounded),
                  color: StudentSurface.ink(context),
                ),
              ),
              IconButton(
                key: const ValueKey('coloring-clear'),
                tooltip: tr('coloring.clear'),
                onPressed: controller.clear,
                icon: const Icon(Icons.delete_sweep_rounded),
                color: StudentSurface.ink(context),
              ),
              const SizedBox(width: 4),
              _saveButton(),
            ],
          );
          if (wide) {
            return Column(
              children: [
                bar,
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: board),
                      SizedBox(
                        width: math.min(300, constraints.maxWidth * 0.36),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(4, 8, 14, 14),
                          child: _toolPanel(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              bar,
              Expanded(child: board),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: _toolPanel(context),
              ),
            ],
          );
        },
      );

  Widget _saveButton() => FilledButton.icon(
        key: const ValueKey('coloring-save'),
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.save_rounded, size: 20),
        label: Text(tr('coloring.save'), style: const TextStyle(fontWeight: FontWeight.w900)),
      );

  Widget _toolPanel(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: StudentSurface.glass(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: StudentSurface.outline(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _toolChip(ColoringTool.fill, Icons.format_color_fill_rounded, 'coloring.fill'),
                _toolChip(ColoringTool.brush, Icons.brush_rounded, 'coloring.brush'),
                _toolChip(ColoringTool.rainbow, Icons.gradient_rounded, 'coloring.rainbow'),
                _toolChip(ColoringTool.shapes, Icons.category_rounded, 'coloring.shapes'),
                _toolChip(ColoringTool.stamps, Icons.emoji_emotions_rounded, 'coloring.stamps'),
                _toolChip(ColoringTool.eraser, Icons.cleaning_services_rounded, 'coloring.eraser'),
                _toolChip(ColoringTool.smartEraser, Icons.auto_fix_high_rounded, 'coloring.smartEraser'),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: switch (_tool) {
                ColoringTool.brush => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in brushIcons.entries)
                          _optionChip(
                            key: ValueKey('coloring-brush-${e.key.name}'),
                            icon: e.value.$1,
                            label: tr(e.value.$2),
                            selected: _brush == e.key,
                            onTap: () => setState(() => _brush = e.key),
                          ),
                      ],
                    ),
                  ),
                ColoringTool.shapes => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in shapeIcons.entries)
                          _optionChip(
                            key: ValueKey('coloring-shape-${e.key.name}'),
                            icon: e.value.$1,
                            label: tr(e.value.$2),
                            selected: _shape == e.key,
                            onTap: () => setState(() => _shape = e.key),
                          ),
                        _optionChip(
                          key: const ValueKey('coloring-shape-filled'),
                          icon: _shapeFilled ? Icons.square_rounded : Icons.check_box_outline_blank_rounded,
                          label: tr('coloring.shape.filled'),
                          selected: _shapeFilled,
                          onTap: () => setState(() => _shapeFilled = !_shapeFilled),
                        ),
                      ],
                    ),
                  ),
                ColoringTool.stamps => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in stampIcons.entries)
                          GestureDetector(
                            key: ValueKey('coloring-stamp-${e.key.name}'),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _stamp = e.key);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _stamp == e.key ? const Color(0xFFFCE7F3) : StudentSurface.card(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _stamp == e.key ? const Color(0xFFDB2777) : StudentSurface.outline(context),
                                  width: _stamp == e.key ? 2 : 1,
                                ),
                              ),
                              child: Text(e.value, style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ColoringTool.smartEraser => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      tr('coloring.smartEraser.hint'),
                      key: const ValueKey('coloring-smart-eraser-hint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: StudentSurface.mutedInk(context)),
                    ),
                  ),
                _ => const SizedBox(width: double.infinity),
              },
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _tool == ColoringTool.fill || _tool == ColoringTool.smartEraser
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        runSpacing: 6,
                        children: [
                          for (var i = 0; i < brushSizes.length; i++)
                            GestureDetector(
                              key: ValueKey('coloring-size-$i'),
                              onTap: () => setState(() => _size = i),
                              child: Container(
                                width: 42,
                                height: 42,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _size == i ? const Color(0xFFFCE7F3) : Colors.transparent,
                                  border: Border.all(
                                    color: _size == i ? const Color(0xFFDB2777) : StudentSurface.outline(context),
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 5.0 + i * 7,
                                  height: 5.0 + i * 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _tool == ColoringTool.eraser ? const Color(0xFF9CA3AF) : _color,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              tr('coloring.magic'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: StudentSurface.mutedInk(context)),
            ),
            const SizedBox(height: 5),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final (i, (_, colors)) in magicGradients.indexed)
                  GestureDetector(
                    key: ValueKey('coloring-magic-$i'),
                    onTap: () => _pickMagic(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: _magic == i ? 40 : 34,
                      height: _magic == i ? 40 : 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                        border: Border.all(
                          color: _magic == i ? const Color(0xFFDB2777) : Colors.white,
                          width: _magic == i ? 3 : 2,
                        ),
                        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: _magic == i ? const Icon(Icons.auto_awesome, color: Colors.white, size: 16) : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 7,
              runSpacing: 7,
              children: [
                for (var i = 0; i < palette.length; i++) _swatch(i),
                // ‏لونٌ اختير من اللوحة الموسّعة: يبقى ظاهراً هنا.
                if (!palette.contains(_color)) _colorDot(_color, key: const ValueKey('coloring-color-custom')),
                GestureDetector(
                  key: const ValueKey('coloring-more-colors'),
                  onTap: _moreColors,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: [
                        Color(0xFFEF4444),
                        Color(0xFFFACC15),
                        Color(0xFF22C55E),
                        Color(0xFF38BDF8),
                        Color(0xFF8B5CF6),
                        Color(0xFFEC4899),
                        Color(0xFFEF4444),
                      ]),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _optionChip({
    required Key key,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        key: key,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFCE7F3) : StudentSurface.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFFDB2777) : StudentSurface.outline(context),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? const Color(0xFFDB2777) : StudentSurface.ink(context)),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: StudentSurface.ink(context))),
            ],
          ),
        ),
      );

  /// اختيارُ لونٍ من أيّ مكان: الممحاةُ أو قوسُ قزح بيده فيريد أن يلوّن به.
  void _pickColor(Color color) {
    HapticFeedback.selectionClick();
    setState(() {
      _color = color;
      _magic = null;
      if (_tool == ColoringTool.eraser || _tool == ColoringTool.rainbow || _tool == ColoringTool.smartEraser) {
        _tool = ColoringTool.brush;
      }
    });
  }

  /// تدرّجٌ سحريّ: للفرشاة والأشكال والأختام — الدلوُ والممحاةُ يصيران فرشاة.
  void _pickMagic(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _magic = index;
      if (_tool != ColoringTool.brush && _tool != ColoringTool.shapes && _tool != ColoringTool.stamps) {
        _tool = ColoringTool.brush;
      }
    });
  }

  bool get _usesColor =>
      _magic == null &&
      (_tool == ColoringTool.fill || _tool == ColoringTool.brush || _tool == ColoringTool.shapes ||
          _tool == ColoringTool.stamps);

  Widget _colorDot(Color color, {required Key key, double size = 34, VoidCallback? onTap}) {
    final selected = _color == color && _usesColor;
    return GestureDetector(
      key: key,
      onTap: onTap ?? () => _pickColor(color),
      child: AnimatedScale(
        scale: selected ? 1.18 : 1,
        duration: const Duration(milliseconds: 160),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? Colors.white : const Color(0x33000000), width: selected ? 3 : 1),
            boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 1)] : null,
          ),
          child: selected
              ? Icon(Icons.check_rounded, size: 18, color: color.computeLuminance() > 0.6 ? Colors.black87 : Colors.white)
              : null,
        ),
      ),
    );
  }

  /// لوحةُ الألوان الموسّعة: ثمانون لوناً ودرجة.
  Future<void> _moreColors() async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          key: const ValueKey('coloring-palette-sheet'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('coloring.moreColors'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, color) in extendedPalette.indexed)
                    GestureDetector(
                      key: ValueKey('coloring-extended-$i'),
                      onTap: () => Navigator.of(context).pop(color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color == _color ? const Color(0xFFDB2777) : const Color(0x33000000),
                            width: color == _color ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) _pickColor(picked);
  }

  Widget _toolChip(ColoringTool tool, IconData icon, String label) {
    final selected = _tool == tool;
    return GestureDetector(
      key: ValueKey('coloring-tool-${tool.name}'),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _tool = tool);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)])
              : null,
          color: selected ? null : StudentSurface.card(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.white : StudentSurface.outline(context), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: selected ? Colors.white : StudentSurface.ink(context)),
            const SizedBox(width: 5),
            Text(
              tr(label),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : StudentSurface.ink(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(int i) => _colorDot(palette[i], key: ValueKey('coloring-color-$i'));

  // ── الاحتفال ──

  Widget _celebration(BuildContext context, ColoringArtwork controller) => Positioned.fill(
        child: Container(
          key: const ValueKey('coloring-celebration'),
          color: Colors.black.withValues(alpha: 0.45),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.elasticOut,
            builder: (context, t, child) => Transform.scale(scale: 0.6 + 0.4 * t, child: child),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFF7ED), Color(0xFFFCE7F3)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFF9A8D4), width: 3),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const StudentAvatarView(size: 84),
                          const SizedBox(width: 8),
                          _thumb(
                            key: const ValueKey('coloring-celebration-art'),
                            controller: controller,
                            size: 110,
                            onTap: () => setState(() => _celebrating = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr('coloring.saved'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFFDB2777)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '⭐⭐⭐  ${tr(switch (_savedTo) {
                          ColoringSaveTarget.cloud => 'coloring.saved.cloud',
                          ColoringSaveTarget.photos => 'coloring.saved.photos',
                          _ => 'coloring.savedSub',
                        })}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF6B21A8)),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            key: const ValueKey('coloring-next'),
                            onPressed: _nextDrawing,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFDB2777),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: Text(tr('coloring.next'), style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('coloring-all'),
                            onPressed: _backToPicker,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6D28D9),
                              side: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                            icon: const Icon(Icons.grid_view_rounded),
                            label: Text(tr('coloring.backToPick'), style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// لوحُ الرسم: يأخذ لمسَ الإصبع ويحوّله إلى إحداثيّات الرسمة.
///
/// بالمؤشّر الخام ([Listener]) لا بالإيماءات: الفرشاةُ تبدأ لحظةَ اللمس، لا بعد
/// أن يتحرّك الإصبعُ مسافةَ «السحب». وإصبعٌ واحد يرسم — الثاني يُهمَل، فلا
/// تقفز الخطوطُ بين إصبعين.
class _ColoringBoard extends StatefulWidget {
  const _ColoringBoard({
    required this.controller,
    required this.tool,
    required this.color,
    required this.width,
    this.brush = BrushStyle.pen,
    this.shape = ShapeKind.rectangle,
    this.shapeFilled = false,
    this.stamp = ShapeKind.star,
    this.stampRadius = 24,
    this.magic,
    super.key,
  });

  final ColoringArtwork controller;
  final ColoringTool tool;
  final Color color;
  final double width;
  final BrushStyle brush;
  final ShapeKind shape;
  final bool shapeFilled;
  final ShapeKind stamp;
  final double stampRadius;
  final int? magic;

  /// التدرّجُ السحريّ لا يكون للدلو: يُملأ باللون.
  int? get _magicForStroke => tool == ColoringTool.fill ? null : magic;

  /// أداةٌ تعمل باللمس لا بالسحب.
  bool get taps => tool == ColoringTool.fill || tool == ColoringTool.smartEraser || tool == ColoringTool.stamps;

  @override
  State<_ColoringBoard> createState() => _ColoringBoardState();
}

class _ColoringBoardState extends State<_ColoringBoard> {
  int? _pointer;
  Offset? _downAt;
  double _side = 1;
  final List<(int, Offset, Color)> _ripples = [];
  int _rippleId = 0;

  Offset _toDrawing(Offset local) => local / _side * coloringCanvasSize;

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _downAt = e.localPosition;
    final p = _toDrawing(e.localPosition);
    switch (widget.tool) {
      case ColoringTool.fill:
      case ColoringTool.smartEraser:
      case ColoringTool.stamps:
        break;
      case ColoringTool.brush:
        widget.controller.beginStroke(p,
            color: widget.color, width: widget.width, brush: widget.brush, magic: widget._magicForStroke);
      case ColoringTool.shapes:
        widget.controller.beginStroke(
          p,
          color: widget.color,
          width: widget.width,
          shape: widget.shape,
          filled: widget.shapeFilled,
          magic: widget._magicForStroke,
        );
      case ColoringTool.rainbow:
        widget.controller.beginStroke(p, color: null, width: widget.width);
      case ColoringTool.eraser:
        widget.controller.beginStroke(p, color: ColoringPainter.paper, width: widget.width);
    }
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer || widget.taps) return;
    widget.controller.extendStroke(_toDrawing(e.localPosition));
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (widget.taps) {
      final start = _downAt;
      // ‏لمسةٌ لا سحب: سحبٌ طويلٌ بالدلو ليس قصدَ تعبئة.
      if (start != null && (e.localPosition - start).distance < 24 && e is PointerUpEvent) {
        if (widget.tool == ColoringTool.smartEraser) {
          widget.controller.eraseAt(_toDrawing(e.localPosition));
          HapticFeedback.lightImpact();
          _ripple(e.localPosition, ColoringPainter.paper);
        } else if (widget.tool == ColoringTool.stamps) {
          // ‏الختمُ شكلٌ مملوءٌ مربّعُه حول اللمسة.
          final at = _toDrawing(e.localPosition);
          final r = Offset(widget.stampRadius, widget.stampRadius);
          widget.controller
            ..beginStroke(at - r,
                color: widget.color, width: 4, shape: widget.stamp, filled: true, magic: widget.magic)
            ..extendStroke(at + r)
            ..endStroke();
          HapticFeedback.lightImpact();
          _ripple(e.localPosition, widget.color);
        } else {
          widget.controller.fillAt(_toDrawing(e.localPosition), widget.color);
          HapticFeedback.lightImpact();
          _ripple(e.localPosition, widget.color);
        }
      }
    } else {
      widget.controller.endStroke();
    }
    _downAt = null;
  }

  void _ripple(Offset at, Color color) {
    if (MediaQuery.of(context).disableAnimations) return;
    final id = ++_rippleId;
    setState(() => _ripples.add((id, at, color)));
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _ripples.removeWhere((r) => r.$1 == id));
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          _side = math.max(1, math.min(constraints.maxWidth, constraints.maxHeight));
          return SizedBox.square(
            dimension: _side,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF9A8D4), width: 3),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: LayoutBuilder(
                  builder: (context, inner) {
                    _side = math.max(1, math.min(inner.maxWidth, inner.maxHeight));
                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _down,
                      onPointerMove: _move,
                      onPointerUp: _up,
                      onPointerCancel: _up,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                isComplex: true,
                                willChange: true,
                                painter: widget.controller.painter(),
                              ),
                            ),
                          ),
                          for (final (id, at, color) in _ripples)
                            Positioned(
                              key: ValueKey('ripple-$id'),
                              left: at.dx - 40,
                              top: at.dy - 40,
                              child: IgnorePointer(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeOut,
                                  builder: (context, t, _) => Opacity(
                                    opacity: (1 - t).clamp(0.0, 1.0),
                                    child: Transform.scale(
                                      scale: 0.3 + t,
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: color, width: 4),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text('✨', style: TextStyle(fontSize: 22)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
}
