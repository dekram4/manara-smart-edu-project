import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../services/coloring_canvas.dart';
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
  const MagicColoringScreen({this.random, this.playIntro, this.cheer, super.key});

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

enum ColoringTool { fill, brush, rainbow, eraser }

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

  /// عرضُ الفرشاة بوحدات الرسمة: صغيرة، ووسط، وكبيرة.
  static const brushSizes = [6.0, 12.0, 20.0];

  late final math.Random _random = widget.random ?? math.Random();
  late final ConfettiController _confetti = ConfettiController(duration: const Duration(milliseconds: 900));

  List<String> _set = const [];
  final Map<String, ColoringController> _blank = {};
  List<ColoringArtwork> _gallery = const [];
  final Set<String> _colored = {};

  ColoringArtwork? _controller;

  /// `null`: شاشةُ الاختيار بين الطريقتين.
  ColoringMode? _mode;

  /// موضعُ اللوحة في «لوحاتي» إن فُتحت منها: حفظُها يحلّ محلّ القديمة.
  int? _galleryIndex;

  ColoringTool _tool = ColoringTool.fill;
  Color _color = palette.first;
  int _size = 1;
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
    final gallery = await ColoringGallery.load();
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
    HapticFeedback.mediumImpact();
    final yes = await showDialog<bool>(
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
                    child: CustomPaint(painter: _gallery[index].painter(outline: 4)),
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
    if (yes != true || !mounted) return;
    final ok = await ColoringGallery.delete(index);
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
      _size = 0;
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

  Future<void> _save() async {
    final controller = _controller;
    if (controller == null || _saving) return;
    if (controller.isEmpty) {
      _toast(tr('coloring.empty'));
      return;
    }
    setState(() => _saving = true);
    final ok = await ColoringGallery.save(controller, replacing: _galleryIndex);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      _toast(tr('coloring.saveFailed'));
      return;
    }
    _colored.add(controller.artworkId);
    _galleryIndex = 0;
    unawaited(_loadGallery());
    setState(() => _celebrating = true);
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
                _toolChip(ColoringTool.eraser, Icons.cleaning_services_rounded, 'coloring.eraser'),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _tool == ColoringTool.fill
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < brushSizes.length; i++)
                            GestureDetector(
                              key: ValueKey('coloring-size-$i'),
                              onTap: () => setState(() => _size = i),
                              child: Container(
                                width: 44,
                                height: 44,
                                margin: const EdgeInsets.symmetric(horizontal: 6),
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
                                  width: 8.0 + i * 8,
                                  height: 8.0 + i * 8,
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
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 7,
              runSpacing: 7,
              children: [
                for (var i = 0; i < palette.length; i++) _swatch(i),
              ],
            ),
          ],
        ),
      );

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

  Widget _swatch(int i) {
    final color = palette[i];
    final selected = _color == color && _tool != ColoringTool.eraser && _tool != ColoringTool.rainbow;
    return GestureDetector(
      key: ValueKey('coloring-color-$i'),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _color = color;
          // ‏لونٌ اختير والممحاةُ أو قوسُ قزح بيده: يريد أن يلوّن به.
          if (_tool == ColoringTool.eraser || _tool == ColoringTool.rainbow) _tool = ColoringTool.brush;
        });
      },
      child: AnimatedScale(
        scale: selected ? 1.18 : 1,
        duration: const Duration(milliseconds: 160),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? Colors.white : const Color(0x33000000), width: selected ? 3 : 1),
            boxShadow: selected
                ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 1)]
                : null,
          ),
          child: selected ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
        ),
      ),
    );
  }

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
                        '⭐⭐⭐  ${tr('coloring.savedSub')}',
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
    super.key,
  });

  final ColoringArtwork controller;
  final ColoringTool tool;
  final Color color;
  final double width;

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
        break;
      case ColoringTool.brush:
        widget.controller.beginStroke(p, color: widget.color, width: widget.width);
      case ColoringTool.rainbow:
        widget.controller.beginStroke(p, color: null, width: widget.width);
      case ColoringTool.eraser:
        widget.controller.beginStroke(p, color: ColoringPainter.paper, width: widget.width);
    }
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer || widget.tool == ColoringTool.fill) return;
    widget.controller.extendStroke(_toDrawing(e.localPosition));
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (widget.tool == ColoringTool.fill) {
      final start = _downAt;
      // ‏لمسةٌ لا سحب: سحبٌ طويلٌ بالدلو ليس قصدَ تعبئة.
      if (start != null && (e.localPosition - start).distance < 24 && e is PointerUpEvent) {
        widget.controller.fillAt(_toDrawing(e.localPosition), widget.color);
        HapticFeedback.lightImpact();
        _ripple(e.localPosition, widget.color);
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
