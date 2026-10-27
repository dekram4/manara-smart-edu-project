import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../models/student_gamification.dart';
import '../models/study_games.dart';
import '../services/student_sound_service.dart';
import '../services/student_voice_service.dart';
import '../services/tracing_glyphs.dart';
import '../services/tracing_path.dart';
import '../theme/student_theme.dart';

/// لعبةُ «تتبّع واكتب» في بطاقة المذاكرة.
///
/// ── حروفُ الروضة وأرقامُها: شبكةٌ ثم لوحة ──
/// تظهر المجموعةُ في المساحة البيضاء شبكةً من ستّ بطاقاتٍ كبيرة في الصفحة،
/// تُقلَّب صفحةً صفحة. يلمس الطفلُ حرفاً فيسمع اسمَه في الحال، وتُفتح لوحةُ
/// تتبّعه. وما أنجزه يعود إلى الشبكة أخضرَ بعلامة.
///
/// ── جلسةٌ مفتوحة، وجوهرةٌ لكل حرف ──
/// لا حدَّ ولا نافذةَ احتفالٍ تقطع اللعب: كلُّ حرفٍ يُكتب صحيحاً تتبعه عبارةُ
/// تشجيع، وجوهرةٌ ونقطة ([onTraced]) — يصرفها الخادمُ مرّةً لكل حرفٍ في الدرس،
/// فمن أعاد كتابةَ حرفٍ كتبه يلعب بحرّيةٍ ولا يكسب شيئاً.
///
/// ── والحروفُ العربية بأصواتها المسجّلة ──
/// اسمُ الحرف العربي من تسجيلٍ ([arabicLetterClips]) لا من محرّك النطق؛
/// وما لا تسجيلَ له (الإنجليزية والأعداد) يُنطق بالمحرّك.
///
/// ── وحصراً لروضة منارة المعرفة ──
/// الخادمُ لا يرسلها إلا للروضة في موادّها الأربع، والتطبيقُ يتحقّق كذلك
/// ([tracingAllowedFor]) — فلا تظهر في صفٍّ آخر ولو أرسلها خادمٌ قديم.
///
/// ── واللوحة ──
/// يضع الطفلُ إصبعه على النقطة الخضراء ويمرّ بالنقاط بترتيبها: التاليةُ
/// وحدها تُحتسب، فلا يتقدّم إلا في اتجاه الكتابة. وإن ابتعد عن الخطّ عادت
/// الجرّةُ من أوّلها بتنبيهٍ لطيف. ونقطةُ الحرف تُلمس لمساً.
///
/// ── ولا دائرةَ تحميلٍ بلا نهاية ──
/// أشكالُ الروضة محسوبةٌ مسبقاً ([precomputedTracingShape]) فتُفتح فوراً.
/// وما يُرسم وقتَ اللعب له مهلة؛ فإن انقضت أكمل الطفلُ بدونه (انظر
/// [loadTracingShape]).
class TracingGame extends StatefulWidget {
  const TracingGame({
    required this.game,
    required this.onTraced,
    this.shapeBuilder = loadTracingShape,
    this.speak,
    this.playClip,
    super.key,
  });

  final StudyGame game;

  /// حرفٌ كُتب صحيحاً: يُطلب له من الخادم جوهرةٌ ونقطة. `gems` في الردّ صفرٌ
  /// إن كان قد كُتب في هذا الدرس من قبل.
  final Future<RewardResult?> Function(TracingItem item) onTraced;

  /// يُستبدل في الاختبار وحده.
  final Future<TracingShape?> Function(TracingItem item) shapeBuilder;

  /// النطق؛ وبلا قيمةٍ محرّكُ الجهاز ([StudentVoiceService.speakIn]).
  final Future<void> Function(String text, String lang)? speak;

  /// تشغيلُ مقطعٍ مسجّل؛ وبلا قيمةٍ مشغّلُ أصوات التطبيق
  /// ([StudentSoundService.playClip]).
  final Future<void> Function(String asset)? playClip;

  @override
  State<TracingGame> createState() => TracingGameState();
}

enum _View { grid, board }

@visibleForTesting
class TracingGameState extends State<TracingGame> with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF16A34A);
  static const _amber = Color(0xFFF59E0B);

  /// بطاقاتُ الصفحة: ستّةُ حروف (٣×٢)، أو اثنا عشر رقماً (٤×٣) — الأرقامُ
  /// مئةٌ وواحد، وستّةٌ في الصفحة سبعَ عشرةَ صفحة.
  int get perPage => _numbers ? 12 : 6;

  bool get _numbers => _items.isNotEmpty && _items.first.kind == 'number';

  // يُنشآن في [initState] صراحةً لا كسولين: الشبكةُ لا تلمس النبض، فكان أوّلُ
  // لمسٍ له في [dispose] — وإنشاءُ مؤقّتٍ هناك ممنوع.
  late final AnimationController _pulse;
  late final PageController _pages;

  _View _view = _View.grid;
  int _index = 0;
  int _page = 0;

  TracingShape? _shape;
  bool _loading = false;
  bool _unavailable = false;
  int _loadToken = 0;

  int _stroke = 0;

  /// آخرُ نقطةٍ بلغها الإصبع في الجرّة الحالية؛ -1 قبل أن تبدأ.
  int _reached = -1;
  List<Offset> _trail = [];
  final List<List<Offset>> _doneTrails = [];
  bool _itemDone = false;
  String? _hint;
  Rect _dest = Rect.zero;

  final Set<int> _done = {};
  int _mistakes = 0;

  /// عبارةُ التشجيع على الحرف المكتمل، وهل كسب به جوهرة.
  String? _cheer;
  bool _gemEarned = false;

  /// آخرُ موضعٍ للإصبع، يُملأ منه ما بينه وبين الموضع الجديد.
  Offset? _lastPos;

  List<TracingItem> get _items => widget.game.tracing;
  TracingItem get _item => _items[_index];


  int get _pageCount => (_items.length / perPage).ceil();

  /// مساراتُ العنصر المفتوح، للاختبار.
  @visibleForTesting
  TracePlan? get plan => _shape?.plan;

  /// موضعُ نقطةٍ من المسار على الشاشة، للاختبار.
  @visibleForTesting
  Offset toCanvas(TracePoint p) => _toCanvas(p);

  @override
  void initState() {
    super.initState();
    _index = widget.game.tracingStart.clamp(0, _items.length - 1);
    _page = _index ~/ perPage;
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pages = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _pages.dispose();
    super.dispose();
  }

  // ── النطق ────────────────────────────────────────────────────────

  /// ينطق ولا يُسقط شيئاً: أيُّ عطلٍ في النطق يبقى في النطق.
  ///
  /// ── ما كان يُعلّق اللعبة ──
  /// كان هنا `widget.speak ?? StudentVoiceService.instance.speakIn` — و`speakIn`
  /// تأخذ اللغةَ باسمها (`lang:`) لا بموضعها. فقَدَ `??` نوعَ الدالّة فلم ينبّه
  /// المحلّل، وكانت كلُّ لمسةٍ لحرفٍ ترمي `NoSuchMethodError` قبل أن يُحضَّر
  /// شكلُه: دائرةُ تحميلٍ لا تنتهي في 1.1.19، ولوحةٌ بيضاء فارغة في 1.1.20.
  /// والاختباراتُ كانت تمرّر نطقاً مزيّفاً فلم تمرّ بهذا السطر. فالنوعُ هنا
  /// مكتوبٌ صراحةً، ويُكتشف أيُّ خلافٍ عند البناء لا على جهاز الطفل.
  void _say(String text, String lang) {
    final Future<void> Function(String text, String lang) speak = widget.speak ??
        (text, lang) => StudentVoiceService.instance
            .speakIn(text, lang: lang, pitch: StudentVoiceService.childPitch);
    try {
      unawaited(speak(text, lang == 'en' ? 'en' : 'ar').catchError((Object _) {}));
    } catch (error) {
      debugPrint('[tracing] speech failed: $error');
    }
  }

  /// علوُّ أسماء الحروف المسجّلة: كاملٌ تقريباً — تسجيلٌ نظيفٌ لصوتٍ واحد.
  static const letterClipVolume = 0.95;

  /// اسمُ العنصر: تسجيلُه إن كان حرفاً عربياً له تسجيل، وإلا محرّكُ النطق.
  void _sayCurrent() {
    final item = _item;
    final clip = recordedClipFor(item);
    if (clip == null) {
      _say(item.speech, item.lang);
      return;
    }
    final Future<void> Function(String asset) play = widget.playClip ??
        (asset) => StudentSoundService.instance.playClip(asset, volume: letterClipVolume);
    try {
      unawaited(play(clip).catchError((Object _) {}));
    } catch (error) {
      debugPrint('[tracing] clip failed: $error');
    }
  }

  // ── التنقّل ──────────────────────────────────────────────────────

  /// يفتح لوحةَ عنصرٍ وينطقه في الحال.
  void _open(int index) {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    setState(() {
      _index = index;
      _view = _View.board;
      _hint = null;
      _resetBoard();
    });
    _sayCurrent();
    unawaited(_loadShape(item));
  }

  void _resetBoard() {
    _shape = null;
    _unavailable = false;
    _stroke = 0;
    _reached = -1;
    _trail = [];
    _doneTrails.clear();
    _strokeTrailBase = 0;
    _itemDone = false;
    _cheer = null;
    _gemEarned = false;
    _lastPos = null;
  }

  /// الشكلُ يُحضَّر مع فتح العنصر.
  ///
  /// المحسوبُ مسبقاً يعود قبل أن يُرسم إطارٌ واحد، فلا تظهر دائرةُ تحميل
  /// أصلاً؛ وما يُرسم الآن له مهلةٌ في [loadTracingShape].
  Future<void> _loadShape(TracingItem item) async {
    final token = ++_loadToken;
    setState(() => _loading = true);
    TracingShape? shape;
    try {
      shape = await widget.shapeBuilder(item);
    } catch (error) {
      debugPrint('[tracing] shape failed for "${item.text}": $error');
    }
    if (!mounted || token != _loadToken) return;
    setState(() {
      _loading = false;
      _shape = shape;
      _unavailable = shape == null;
    });
  }

  void _backToGrid() {
    StudentSoundService.instance.playTap();
    setState(() {
      _view = _View.grid;
      _loadToken++;
      _resetBoard();
      _hint = null;
    });
  }

  /// العنصرُ أُنجز: يُعلَّم في الشبكة ويُعاد إليها — والجلسةُ مفتوحة بلا نهاية.
  void _finishItem() {
    _done.add(_index);
    setState(() {
      _view = _View.grid;
      _page = _index ~/ perPage;
      _resetBoard();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pages.hasClients) _pages.jumpToPage(_page);
    });
  }

  void _restartItem() {
    StudentSoundService.instance.playTap();
    setState(() {
      _stroke = 0;
      _reached = -1;
      _trail = [];
      _doneTrails.clear();
      _strokeTrailBase = 0;
      _hint = null;
    });
  }

  // ── الهندسة ──────────────────────────────────────────────────────

  Offset _toCanvas(TracePoint p) =>
      Offset(_dest.left + p.x * _dest.width, _dest.top + p.y * _dest.height);

  /// سُمكُ الخطّ على الشاشة.
  double get _inkPx => (_shape?.plan.inkWidth ?? 0.1) * _dest.height;

  /// كم يقترب الإصبعُ من نقطةٍ لتُحتسب — واسعٌ لإصبعٍ صغيرٍ غير دقيق.
  double get _hitRadius => math.max(34, _inkPx * 1.45);

  /// كم يبتعد عن الخطّ قبل أن تُعاد الجرّة.
  double get _offRadius => math.max(70, _inkPx * 2.8);

  /// أقصى ما يتقدّمه الإصبعُ من نقاطٍ في خطوةٍ واحدة. والحركةُ السريعة لا
  /// تحتاج أكثر: ما بين موضعين للإصبع يُملأ خطوةً خطوة ([_move]).
  static const _maxStepsPerMove = 2;

  /// أوّلُ ما يخصّ الجرّةَ الحالية في [_doneTrails]: قطعُها التي رُسمت قبل
  /// أن يرفع الطفلُ إصبعه، تُمحى إن أُعيدت الجرّة.
  int _strokeTrailBase = 0;

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final length = ab.distanceSquared;
    if (length == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  // ── اللمس على اللوحة ─────────────────────────────────────────────

  TraceStroke? get _current {
    final strokes = _shape?.plan.strokes;
    if (strokes == null || _stroke >= strokes.length) return null;
    return strokes[_stroke];
  }

  void _down(Offset position) {
    final stroke = _current;
    if (stroke == null || _itemDone) return;
    // ── رفع إصبعه في منتصف الجرّة: يكمل من حيث توقّف ──
    // كانت الجرّةُ تُعاد من أوّلها مع كل رفعٍ خفيف، فيُجبَر الطفلُ على رسم
    // الحرف كلِّه بلمسةٍ واحدة لا تنقطع.
    if (_reached >= 0 && !stroke.isDot) {
      final points = stroke.points;
      final near = [
        points[_reached],
        if (_reached + 1 < points.length) points[_reached + 1],
      ].any((p) => (position - _toCanvas(p)).distance <= _hitRadius * 1.5);
      if (near) {
        _lastPos = position;
        setState(() {
          _trail = [position];
          _hint = null;
        });
      } else {
        // بعيداً عن موضعه: تذكيرٌ لطيف، والتقدّمُ باقٍ.
        StudentSoundService.instance.playTap();
        setState(() => _hint = tr('study.trace.continueHere'));
      }
      return;
    }
    final start = _toCanvas(stroke.points.first);
    final reach = stroke.isDot ? _hitRadius * 1.4 : _hitRadius;
    if ((position - start).distance <= reach) {
      if (stroke.isDot) {
        _completeStroke([position]);
        return;
      }
      _lastPos = position;
      setState(() {
        _reached = 0;
        _trail = [position];
        _hint = null;
      });
    } else {
      _miss(stroke.isDot ? tr('study.trace.tapDot') : tr('study.trace.start'));
    }
  }

  /// ── الحركةُ السريعة ──
  /// الجهازُ يرسل موضعَ الإصبع كلَّ إطار؛ وإصبعٌ سريعٌ يقطع بين إطارين أكثرَ من
  /// نقطة، فكان يُحسب خارجاً عن الخطّ وتُعاد الجرّة. فما بين الموضعين يُملأ
  /// بخطواتٍ أقصرَ من نصف مسافة الاحتساب، وكلُّ خطوةٍ تُحسب وحدها.
  void _move(Offset position) {
    if (_current == null || _reached < 0) return;
    final from = _lastPos ?? position;
    final steps = math.max(1, ((position - from).distance / (_hitRadius * 0.5)).ceil());
    for (var i = 1; i <= steps; i++) {
      if (!_step(Offset.lerp(from, position, i / steps)!)) {
        _lastPos = null;
        return;
      }
    }
    _lastPos = position;
  }

  /// خطوةٌ واحدة للإصبع؛ `false` إن انتهت بها الجرّة — اكتملت أو أُعيدت.
  bool _step(Offset position) {
    final stroke = _current;
    if (stroke == null || _reached < 0) return false;
    final points = stroke.points;
    final last = points.length - 1;
    var reached = _reached;
    // إلى الأمام وحده، وبحدٍّ: أبعدُ نقطةٍ في النافذة يبلغها الإصبع. لا رجوعَ
    // يُحتسب، ولا قفزَ إلى ما وراء النافذة.
    var window = math.min(last, reached + _maxStepsPerMove);
    // ── ولا اكتمالَ قبل آخر نقطة، وبالترتيب ──
    // النقطةُ الأخيرة لا تُبلغ إلا من التي قبلها: حرفٌ يلتقي آخرُه بأوّله
    // (الهاء، الصاد، الخمسة) لا يُغلَق بلمسةٍ قرب بدايته.
    if (window == last && reached < last - 1) window = last - 1;
    for (var i = window; i > reached; i--) {
      if ((position - _toCanvas(points[i])).distance <= _hitRadius) {
        reached = i;
        break;
      }
    }
    // بعيدٌ عن الخطّ: عن كل قطعةٍ في النافذة، لا عن القطعة التالية وحدها —
    // تمريرٌ سريعٌ يسبق النقطة التالية ليس خروجاً.
    var off = double.infinity;
    for (var i = math.max(0, _reached); i < window; i++) {
      off = math.min(off, _distanceToSegment(position, _toCanvas(points[i]), _toCanvas(points[i + 1])));
    }
    if (window == _reached) off = (position - _toCanvas(points[reached])).distance;
    if (off > _offRadius) {
      _miss(tr('study.trace.offPath'));
      return false;
    }
    if (reached == last) {
      _completeStroke([..._trail, position]);
      return false;
    }
    setState(() {
      _reached = reached;
      _trail = [..._trail, position];
    });
    return true;
  }

  void _up() {
    final stroke = _current;
    if (stroke == null || _reached < 0) return;
    // رفع إصبعه قبل نهاية الجرّة: يبقى ما رسمه وما بلغه، ويكمل منه.
    _lastPos = null;
    setState(() {
      if (_trail.length > 1) _doneTrails.add(_trail);
      _trail = [];
      _hint = tr('study.trace.continueHere');
    });
  }

  void _miss(String hint) {
    StudentSoundService.instance.play(StudentSoundCue.warning);
    setState(() {
      _mistakes += 1;
      _reached = -1;
      _trail = [];
      // ما رُسم من هذه الجرّة قبل رفع الإصبع يُمحى معها.
      _doneTrails.removeRange(_strokeTrailBase, _doneTrails.length);
      _hint = hint;
    });
  }

  void _completeStroke(List<Offset> trail) {
    final strokes = _shape!.plan.strokes;
    final last = _stroke + 1 >= strokes.length;
    setState(() {
      _doneTrails.add(trail);
      _strokeTrailBase = _doneTrails.length;
      _stroke += 1;
      _reached = -1;
      _trail = [];
      _hint = null;
    });
    if (!last) {
      StudentSoundService.instance.play(StudentSoundCue.answerSelected);
      return;
    }
    _completeItem();
  }

  static const _cheers = [
    'study.trace.cheer1',
    'study.trace.cheer2',
    'study.trace.cheer3',
    'study.trace.cheer4',
    'study.trace.cheer5',
  ];
  final _random = math.Random();

  void _completeItem() {
    StudentSoundService.instance.play(StudentSoundCue.success);
    HapticFeedback.lightImpact();
    final item = _item;
    final index = _index;
    setState(() {
      _itemDone = true;
      _cheer = tr(_cheers[_random.nextInt(_cheers.length)]);
      _gemEarned = false;
    });
    // جوهرةٌ ونقطةٌ من الخادم — تظهر حين تصل، ولا تؤخّر العبارة.
    unawaited(() async {
      try {
        final result = await widget.onTraced(item);
        if (!mounted || _index != index || !_itemDone) return;
        if ((result?.gems ?? 0) > 0) {
          StudentSoundService.instance.playReward();
          setState(() => _gemEarned = true);
        }
      } catch (error) {
        debugPrint('[tracing] reward failed for "${item.text}": $error');
      }
    }());
    // لحظةٌ يرى فيها الحرفَ مكتملاً ويقرأ تشجيعه قبل العودة إلى الشبكة.
    Future.delayed(const Duration(milliseconds: 1800), () {
      // لم يغادره إلى غيره في الانتظار.
      if (mounted && _itemDone && _index == index && _view == _View.board) _finishItem();
    });
  }

  // ── الواجهة ─────────────────────────────────────────────────────

  String _kindLabel(TracingItem item) => switch (item.kind) {
        'letter' => tr('study.trace.letter'),
        'number' => tr('study.trace.number'),
        _ => tr('study.trace.word'),
      };

  @override
  Widget build(BuildContext context) {
    return switch (_view) {
      _View.grid => _gridView(context),
      _View.board => _boardView(context),
    };
  }

  Widget _progressChip() => _Chip(
        text: trf('study.games.placed', {'done': _done.length, 'total': _items.length}),
        color: _green,
      );

  Widget _hintLine(BuildContext context, String idle) => SizedBox(
        height: 30,
        child: Center(
          child: Text(
            _itemDone ? (_cheer ?? tr('study.trace.great')) : (_hint ?? idle),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _itemDone ? _green : StudentSurface.mutedInk(context),
            ),
          ),
        ),
      );

  Widget _surface(BuildContext context, Widget child) => Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: StudentSurface.card(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: StudentSurface.outline(context)),
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
          ),
        ),
      );

  // ── الشبكة ──

  Widget _gridView(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _progressChip(),
              const SizedBox(width: 8),
              _Chip(text: _kindLabel(_items.first), color: _amber),
              const Spacer(),
              if (_pageCount > 1)
                Text(
                  trf('study.trace.page', {'n': _page + 1, 'total': _pageCount}),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: StudentSurface.mutedInk(context),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _surface(
          context,
          PageView.builder(
            key: const ValueKey('tracing-grid'),
            controller: _pages,
            itemCount: _pageCount,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, page) => _gridPage(context, page),
          ),
        ),
        if (_pageCount > 1) _pageDots(context),
        _hintLine(context, tr('study.trace.tapTile')),
      ],
    );
  }

  Widget _gridPage(BuildContext context, int page) {
    final first = page * perPage;
    final count = math.min(perPage, _items.length - first);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= constraints.maxHeight;
        final cols = _numbers ? (wide ? 4 : 3) : (wide ? 3 : 2);
        final rows = (perPage / cols).ceil();
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              for (var r = 0; r < rows; r++)
                Expanded(
                  child: Row(
                    children: [
                      for (var c = 0; c < cols; c++)
                        Expanded(
                          child: r * cols + c < count
                              ? _LetterTile(
                                  key: ValueKey('tracing-tile-${first + r * cols + c}'),
                                  item: _items[first + r * cols + c],
                                  done: _done.contains(first + r * cols + c),
                                  color: _LetterTile.colors[(first + r * cols + c) % _LetterTile.colors.length],
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _open(first + r * cols + c);
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _pageDots(BuildContext context) {
    void go(int page) {
      if (page < 0 || page >= _pageCount) return;
      StudentSoundService.instance.playTap();
      _pages.animateToPage(page, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }

    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const ValueKey('tracing-page-prev'),
            onPressed: _page > 0 ? () => go(_page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          for (var i = 0; i < _pageCount; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == _page ? _amber : StudentSurface.mutedInk(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          IconButton(
            key: const ValueKey('tracing-page-next'),
            onPressed: _page < _pageCount - 1 ? () => go(_page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  // ── اللوحة ──

  Widget _boardView(BuildContext context) {
    final item = _item;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              TextButton.icon(
                key: const ValueKey('tracing-back-to-grid'),
                onPressed: _backToGrid,
                icon: const Icon(Icons.apps_rounded),
                label: Text(_numbers ? tr('study.trace.backToNumbers') : tr('study.trace.backToGrid')),
                style: TextButton.styleFrom(
                  foregroundColor: _amber,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 6),
              _Chip(text: _kindLabel(item), color: _amber),
              const Spacer(),
              _mistakesText(context),
              _speakButton(),
              IconButton(
                tooltip: tr('study.trace.redo'),
                onPressed: _shape == null || _itemDone ? null : _restartItem,
                icon: const Icon(Icons.replay_rounded),
              ),
            ],
          ),
        ),
        _surface(
          context,
          _shape != null
              ? Stack(
                  children: [
                    Positioned.fill(child: _board(context)),
                    if (_itemDone && _cheer != null) _cheerBadge(),
                  ],
                )
              : _unavailable
                  ? _unavailableNote(context)
                  : Center(
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const SizedBox.shrink(),
                    ),
        ),
        _hintLine(context, tr('study.trace.start')),
      ],
    );
  }

  /// عبارةُ التشجيع فوق الحرف المكتمل، وجوهرتُه إن كسبها — تكبر وتثبت.
  Widget _cheerBadge() => Align(
        alignment: const Alignment(0, -0.82),
        child: TweenAnimationBuilder<double>(
          key: ValueKey(_cheer),
          tween: Tween(begin: 0.4, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.elasticOut,
          builder: (context, t, child) => Transform.scale(scale: t, child: child),
          child: Container(
            key: const ValueKey('tracing-cheer'),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFEC4899), Color(0xFFF59E0B)]),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x557C3AED), blurRadius: 14, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _cheer!,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                if (_gemEarned) ...[
                  const SizedBox(width: 10),
                  Container(
                    key: const ValueKey('tracing-gem'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '+1 💎',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0EA5E9)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _unavailableNote(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🙈', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                tr('study.trace.unavailable'),
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, color: StudentSurface.mutedInk(context)),
              ),
            ],
          ),
        ),
      );

  Widget _mistakesText(BuildContext context) => _mistakes == 0
      ? const SizedBox.shrink()
      : Text(
          trf('study.games.mistakes', {'n': _mistakes}),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: StudentSurface.mutedInk(context),
          ),
        );

  Widget _speakButton() => IconButton(
        key: const ValueKey('tracing-speak'),
        tooltip: tr('study.trace.listen'),
        onPressed: _sayCurrent,
        icon: const Icon(Icons.volume_up_rounded),
      );

  Widget _board(BuildContext context) {
    final shape = _shape!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Offset.zero & constraints.biggest;
        final area = box.deflate(math.min(28, box.shortestSide * 0.08));
        final aspect = shape.crop.width / shape.crop.height;
        var w = area.width;
        var h = w / aspect;
        if (h > area.height) {
          h = area.height;
          w = h * aspect;
        }
        _dest = Rect.fromCenter(center: area.center, width: w, height: h);
        final ink = StudentSurface.ink(context);
        return RawGestureDetector(
          key: const ValueKey('tracing-board'),
          behavior: HitTestBehavior.opaque,
          gestures: {
            _EagerPanRecognizer: GestureRecognizerFactoryWithHandlers<_EagerPanRecognizer>(
              _EagerPanRecognizer.new,
              (recognizer) => recognizer
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = (details) {
                  _down(details.localPosition);
                }
                ..onUpdate = (details) {
                  _move(details.localPosition);
                }
                ..onEnd = (_) {
                  _up();
                }
                ..onCancel = _up,
            ),
          },
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _TracingPainter(
                shape: shape,
                dest: _dest,
                stroke: _stroke,
                reached: _reached,
                trail: _trail,
                doneTrails: _doneTrails,
                pulse: _pulse.value,
                ink: ink,
                inkPx: _inkPx,
                done: _itemDone,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// منحنى Catmull–Rom يمرّ بكل نقطةٍ من [points] بالترتيب — ناعمٌ بينها،
/// ومارٌّ بها عينها: مسلكُ الحرف على اللوحة هو نقاطُ تتبّعه، لا رسمٌ آخر.
Path tracingLanePath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  if (points.length == 1) return path..lineTo(points.first.dx, points.first.dy);
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = points[math.max(0, i - 1)];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = points[math.min(points.length - 1, i + 2)];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path;
}

/// بطاقةُ حرفٍ أو رقمٍ في الشبكة: كبيرةٌ ملوّنة، تصغر قليلاً تحت الإصبع،
/// والمنجَزُ منها أخضرُ بعلامة.
class _LetterTile extends StatefulWidget {
  const _LetterTile({
    required this.item,
    required this.done,
    required this.color,
    required this.onTap,
    super.key,
  });

  static const colors = [
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFEF4444),
  ];

  final TracingItem item;
  final bool done;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<_LetterTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.done ? const Color(0xFF16A34A) : widget.color;
    final shape = precomputedTracingShape(widget.item);
    return Padding(
      padding: const EdgeInsets.all(7),
      child: Semantics(
        button: true,
        label: widget.item.speech,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutBack,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, Color.lerp(color, Colors.white, 0.28)!],
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: Color.lerp(color, Colors.black, 0.35)!, offset: const Offset(0, 5)),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    // الحرفُ مقصوصاً إلى حبره ([TracingShape.crop]) لا إلى سطره:
                    // ذيلُ الجيم والعين ينزل تحت سطر الخطّ، فكان [FittedBox]
                    // يقصّه. وما لا شكلَ محسوباً له يُكتب نصّاً.
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: shape != null
                          ? CustomPaint(
                              painter: _GlyphPainter(
                                glyph: tracingTextPainter(widget.item, color: Colors.white),
                                crop: shape.crop,
                              ),
                            )
                          : FittedBox(
                              child: Text(
                                widget.item.text,
                                style: const TextStyle(
                                  fontFamily: tracingFontFamily,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (widget.done)
                    const PositionedDirectional(
                      top: 6,
                      end: 8,
                      child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// حرفٌ مقصوصٌ إلى حبره، في وسط مساحته وبأكبر ما تتّسع له.
class _GlyphPainter extends CustomPainter {
  _GlyphPainter({required this.glyph, required this.crop});

  final TextPainter glyph;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    // أصغرُ قليلاً من البطاقة: الحرفُ يتنفّس ولا يلمس حوافّها.
    final scale = math.min(size.width / crop.width, size.height / crop.height) * 0.82;
    final w = crop.width * scale;
    final h = crop.height * scale;
    canvas
      ..save()
      ..translate((size.width - w) / 2, (size.height - h) / 2)
      ..scale(scale)
      ..translate(-crop.left, -crop.top);
    glyph.paint(canvas, const Offset(tracingPad, tracingPad));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.crop != crop || old.glyph.text != glyph.text;
}

/// يكسب ساحةَ اللمس فور النزول: بدونه تأخذ الصفحاتُ الأفقية في بطاقة
/// المذاكرة كلَّ جرّةٍ أفقية، فينتقل التبويبُ بدل أن يُكتب الحرف.
class _EagerPanRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: color),
        ),
      );
}

class _TracingPainter extends CustomPainter {
  _TracingPainter({
    required this.shape,
    required this.dest,
    required this.stroke,
    required this.reached,
    required this.trail,
    required this.doneTrails,
    required this.pulse,
    required this.ink,
    required this.inkPx,
    required this.done,
  });

  final TracingShape shape;
  final Rect dest;
  final int stroke;
  final int reached;
  final List<Offset> trail;
  final List<List<Offset>> doneTrails;
  final double pulse;
  final Color ink;
  final double inkPx;
  final bool done;

  static const _start = Color(0xFF16A34A);
  static const _next = Color(0xFFF59E0B);
  static const _drawn = Color(0xFF7C3AED);

  Offset _at(TracePoint p) => Offset(dest.left + p.x * dest.width, dest.top + p.y * dest.height);

  @override
  void paint(Canvas canvas, Size size) {
    // سطرا الكرّاسة.
    final guide = Paint()
      ..color = ink.withValues(alpha: 0.08)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, dest.top), Offset(size.width, dest.top), guide);
    canvas.drawLine(Offset(0, dest.bottom), Offset(size.width, dest.bottom), guide);

    // ── الحرفُ من نقاطه نفسها، لا من الخطّ ──
    // كان الحرفُ يُرسم بالخطّ تحت النقاط، والنقاطُ محسوبةٌ منه في موضعٍ آخر:
    // أيُّ فرقٍ بين الرسمين (خطٌّ بديل، تقريبٌ في الحجم) يُزيح النقاطَ عن
    // الحرف. فالمسلكُ الآن منحنىً ناعمٌ يمرّ بالنقاط ذاتها بسُمك خطّ الحرف:
    // ما يتّبعه الإصبعُ هو ما يراه، في إحداثيّاتٍ واحدة.
    final lane = Paint()
      ..color = (done ? _start : ink).withValues(alpha: done ? 0.45 : 0.13)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(12, inkPx);
    for (final part in shape.plan.strokes) {
      if (part.isDot) {
        canvas.drawCircle(_at(part.points.single), math.max(7, inkPx * 0.6), Paint()..color = lane.color);
      } else {
        canvas.drawPath(tracingLanePath([for (final p in part.points) _at(p)]), lane);
      }
    }

    final pen = Paint()
      ..color = _drawn
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(8, inkPx * 0.7);
    for (final line in [...doneTrails, trail]) {
      if (line.length == 1) {
        canvas.drawCircle(line.first, pen.strokeWidth * 0.7, Paint()..color = _drawn);
      } else if (line.length > 1) {
        final path = Path()..moveTo(line.first.dx, line.first.dy);
        for (final p in line.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, pen);
      }
    }
    if (done) return;

    final strokes = shape.plan.strokes;
    final dotR = math.max(5.0, inkPx * 0.18);

    // أرقامُ الجرّات القادمة عند بداياتها: ترتيبُ الكتابة ظاهرٌ من الأول.
    for (var i = stroke + 1; i < strokes.length; i++) {
      _label(canvas, _at(strokes[i].points.first), '${i + 1}', ink.withValues(alpha: 0.35), dotR * 1.6);
    }
    if (stroke >= strokes.length) return;

    final current = strokes[stroke];
    final points = current.points;
    for (var i = 1; i < points.length; i++) {
      final p = _at(points[i]);
      final isNext = i == reached + 1;
      final paint = Paint()
        ..color = i <= reached
            ? _drawn
            : isNext
                ? _next
                : ink.withValues(alpha: 0.30);
      canvas.drawCircle(p, isNext ? dotR * (1.2 + pulse * 0.5) : dotR, paint);
    }

    // البداية: دائرةٌ خضراء نابضة برقم الجرّة، وسهمٌ إلى النقطة التالية.
    final start = _at(points.first);
    final startR = dotR * (2.0 + (reached < 0 ? pulse * 0.6 : 0));
    canvas.drawCircle(start, startR, Paint()..color = _start);
    _label(canvas, start, '${stroke + 1}', Colors.white, startR, fill: false);
    if (points.length > 1 && reached < 0) {
      final toward = _at(points[math.min(2, points.length - 1)]);
      final direction = toward - start;
      if (direction.distance > 0) {
        final unit = direction / direction.distance;
        final tip = start + unit * (startR + dotR * 4);
        final base = start + unit * (startR + dotR * 1.2);
        final arrow = Paint()
          ..color = _start
          ..strokeWidth = math.max(3, dotR * 0.6)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(base, tip, arrow);
        final normal = Offset(-unit.dy, unit.dx) * dotR * 1.2;
        final back = tip - unit * dotR * 1.4;
        canvas.drawLine(tip, back + normal, arrow);
        canvas.drawLine(tip, back - normal, arrow);
      }
    }
  }

  void _label(Canvas canvas, Offset at, String text, Color color, double radius, {bool fill = true}) {
    if (fill) {
      canvas.drawCircle(at, radius, Paint()..color = color.withValues(alpha: 0.15));
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: radius * 1.1, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_TracingPainter old) => true;
}
