import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import 'bouncy_text.dart';

/// مكافأةُ الفوز في المبارزة كما يصرفها الخادم: `DUEL_WIN_GEMS` في
/// `api-server/src/lib/duel.ts` — مرّةً واحدةً لكل درس — والخبرةُ `xpFromGems` = round(الجواهر × 1.5).
///
/// ── ولماذا أرقامٌ حقيقية لا «جوائز» ──
/// البطاقةُ وعدٌ للطفل. «💎 +10» ثم خمسٌ عند الفوز خيبةٌ يتذكّرها، وتجعل
/// كلَّ رقمٍ بعدها في التطبيق موضعَ شكّ. فإن تغيّرت المكافأةُ في الخادم تُغيَّر هنا.
const int duelWinGems = 5;
const int duelWinXp = 8;

/// وجهُ بطاقة «تحدَّ زملاءك»: بطاقةُ لعبةٍ مجسّمة، شخصيتان في مواجهةٍ حول شعار
/// النزال، وتحتهما العنوانُ ومكافأةُ الفوز.
///
/// ── ولماذا وجهٌ لا بطاقةٌ كاملة ──
/// بطاقاتُ الرفّ التسع تشترك في حركةٍ واحدة — التنفّس، والميلان مع الإصبع،
/// ونابضُ الضغط، والصوت، ودخولُ الورق — وعليها اختبارات. فلو بُنيت هذه بحركةٍ
/// خاصّة لصارت غريبةً بين أخواتها تحت الإصبع نفسه. فالحركةُ من البطاقة الأمّ
/// (`_SectionTile`)، وتمرّر قيمَها هنا: [press] و[lift]، والوجهُ يترجمها عمقاً.
///
/// ── والعمقُ حافّةٌ تحت الوجه ──
/// على طراز Duolingo: الوجهُ يقف على حافّةٍ أغمق منه بسُمكٍ ظاهر، والضغطُ يُنزل
/// الوجهَ إليها فتقصر — فيُحسّ الزرُّ ينضغط لا يصغر. والحافّةُ لا تتحرّك، والوجهُ
/// وحده يغوص، وهو ما يجعل الضغطةَ ملموسة.
///
/// ── ولا تجاوزَ في أيّ مقاس ──
/// كلُّ شيءٍ هنا محسوبٌ من حجم البطاقة لا بأرقامٍ ثابتة، والنصوصُ في `FittedBox`
/// تصغر ولا تلتفّ، ولا `Row` ولا `Column` تحمل ما لا يتّسع له — فالرفُّ يعطي
/// البطاقةَ بين 132 و178 ارتفاعاً، وعلى كل ذلك تُرسم كاملة.
class PeerChallengeCard extends StatefulWidget {
  const PeerChallengeCard({
    required this.title,
    this.press = 0,
    this.lift = 0,
    super.key,
  });

  final String title;

  /// الضغط: صفرٌ مرفوع، وواحدٌ مضغوطٌ إلى الحافّة. ونابضُ البطاقة الأمّ يتجاوز
  /// الواحدَ نزولاً والصفرَ رجوعاً، فيُقصّ هنا.
  final double press;

  /// الإصبعُ أو المؤشّرُ فوق البطاقة: يقوّي التوهّج.
  final double lift;

  /// الشخصيتان: المتحدّي يشير إلى خصمه من اليسار، والخصمُ واقفٌ يقابله.
  /// ومن أصول التطبيق نفسها — صورٌ مقصوصةٌ على شفافية، فلا مستطيلَ حولها.
  static const challengerAsset = 'assets/images/avatar_9.png';
  static const rivalAsset = 'assets/images/avatar_2.png';

  @override
  State<PeerChallengeCard> createState() => _PeerChallengeCardState();
}

class _PeerChallengeCardState extends State<PeerChallengeCard>
    with SingleTickerProviderStateMixin {
  /// دورةٌ واحدةٌ لكل ما يتحرّك وحده: اللمعة، ونبضُ «فوري»، ووهجُ الشعار.
  ///
  /// متحكّمٌ واحدٌ لا ثلاثة: ثلاثُ دوراتٍ بأطوالٍ مختلفة تتلاقى وتفترق فتبدو
  /// البطاقةُ مضطربة. وفي دورةٍ واحدةٍ تتتالى في لحظاتها: اللمعةُ تعبر، ثم يهدأ
  /// كلُّ شيء — والهدوءُ هو ما يجعل اللمعةَ تُلحظ.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion) {
      _loop.stop();
      _loop.value = 0;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
        final height =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 160.0;
        final radius = (height * 0.15).clamp(16.0, 26.0);

        // سُمكُ الحافّة من ارتفاع البطاقة: ستّةٌ في الصغيرة وتسعةٌ في الكبيرة.
        final ledge = (height * 0.055).clamp(6.0, 9.0);
        final press = widget.press.clamp(0.0, 1.0);
        final lift = widget.lift.clamp(0.0, 1.0);
        final sink = ledge * press;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ── الحافّة والظلّ المحيط ──
            // الظلُّ على الحافّة لا على الوجه: هي ما يلمس الأرض، والوجهُ فوقها.
            Positioned.fill(
              top: ledge,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3B1478), Color(0xFF250B52)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF250B52)
                          .withValues(alpha: 0.30 + lift * 0.15),
                      blurRadius: 10 + lift * 6 - press * 4,
                      offset: Offset(0, 6 + lift * 4 - press * 3),
                    ),
                    BoxShadow(
                      color: const Color(0xFFA855F7)
                          .withValues(alpha: 0.18 + lift * 0.32),
                      blurRadius: 24 + lift * 30,
                      spreadRadius: lift * 3,
                      offset: Offset(0, 12 + lift * 8),
                    ),
                  ],
                ),
              ),
            ),
            // ── الوجه، يغوص في الحافّة بالضغط ──
            Positioned(
              left: 0,
              right: 0,
              top: sink,
              bottom: ledge - sink,
              child: RepaintBoundary(
                child: _Face(
                  title: widget.title,
                  size: Size(width, height - ledge),
                  radius: radius,
                  lift: lift,
                  loop: _loop,
                  still: _reduceMotion,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.title,
    required this.size,
    required this.radius,
    required this.lift,
    required this.loop,
    required this.still,
  });

  final String title;
  final Size size;
  final double radius;
  final double lift;
  final Animation<double> loop;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height;

    // ── الأشرطة الثلاثة ──
    // العلويّ للشارتين، والسفليّ للعنوان والتشويق، وما بينهما ساحةُ المواجهة.
    final topBand = h * 0.22;
    // والسفليُّ أوسعُ من حاجة النصّ ظاهراً: العنوانُ المتراقص يحجز تحته وفوقه
    // مدى قفزته، فإن ضاق الشريطُ صغّره FittedBox حتى صار أصغرَ من سطر التشويق
    // تحته — والعنوانُ هو ما يُقرأ أوّلاً.
    final bottomBand = h * 0.42;
    final characterHeight = h * 0.62;
    final emblem = (math.min(w, h) * 0.30).clamp(34.0, 58.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF5B21B6),
              Color(0xFF7C3AED),
              Color(0xFFC026D3),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── ضوءُ الساحة خلف الشعار ──
            // دائرةٌ دافئةٌ في وسط المواجهة: العينُ تذهب إليها، والشخصيتان على
            // طرفيها.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.15),
                  radius: 0.62,
                  colors: [Color(0x66FBBF24), Color(0x00FBBF24)],
                ),
              ),
            ),
            // ── الشخصيتان ──
            // بارتفاعٍ وحده، فيُحسب العرضُ من نسبة الصورة: لا تُمطّ ولا تُقصّ.
            // وتنزلان خلف شريط العنوان قليلاً، فتقفان على أرضٍ لا تطفوان.
            Positioned(
              left: -w * 0.05,
              bottom: bottomBand * 0.38,
              height: characterHeight,
              child: const _Character(
                asset: PeerChallengeCard.challengerAsset,
              ),
            ),
            Positioned(
              right: -w * 0.03,
              bottom: bottomBand * 0.38,
              height: characterHeight * 0.96,
              child: const _Character(asset: PeerChallengeCard.rivalAsset),
            ),
            // ── شعارُ النزال ──
            Positioned(
              left: (w - emblem) / 2,
              top: topBand + (h - topBand - bottomBand - emblem) / 2 - h * 0.02,
              width: emblem,
              height: emblem,
              child: _Emblem(loop: loop, lift: lift, still: still),
            ),
            // ── الإضاءة العلوية: لمعانُ السطح المجسّم ──
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.20),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.32],
                  ),
                ),
              ),
            ),
            // ── شريطُ العنوان ──
            // ظلٌّ من الأسفل يحمل النصَّ فوق الشخصيتين: عنوانٌ أبيضُ على ركبتيْ
            // شخصيةٍ ملوّنة لا يُقرأ.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomBand,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x003B0764), Color(0xE63B0764)],
                    stops: [0.0, 0.45],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(8, bottomBand * 0.10, 8, 4),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 70,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: BouncyText(
                            title,
                            fontSize: 21,
                            animate: false,
                            maxScale: 1.12,
                            minScale: 0.92,
                            alignment: WrapAlignment.center,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 30,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tr('portal.challenge.teaser'),
                            maxLines: 1,
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(
                                  color: Color(0x99000000),
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── الشارتان ──
            // «فوري» في البداية، والمكافأةُ في النهاية: ما يحدث، وما يُكسب.
            PositionedDirectional(
              start: 8,
              top: 7,
              height: topBand * 0.78,
              width: w * 0.44,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _LiveBadge(loop: loop, still: still),
                ),
              ),
            ),
            PositionedDirectional(
              end: 8,
              top: 7,
              height: topBand * 0.78,
              width: w * 0.44,
              child: const Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _RewardBadge(),
                ),
              ),
            ),
            // ── اللمعة ──
            if (!still)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: loop,
                  builder: (context, _) => _Sheen(t: loop.value),
                ),
              ),
            // ── الإطار: حافّةٌ مضيئةٌ تقوى تحت الإصبع ──
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Color.lerp(
                      const Color(0x66FFFFFF),
                      const Color(0xFFFDE68A),
                      lift,
                    )!,
                    width: 1.6 + lift * 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شخصيةٌ بنسبة صورتها: `Positioned` يعطيها ارتفاعاً وحده، و`contain` يحفظ
/// نسبتها. وصورةٌ لم تُحمَّل تترك مكانها فارغاً لا علامةَ خطأ في بطاقة لعب.
class _Character extends StatelessWidget {
  const _Character({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

/// السيفان المتقاطعان على قرصٍ ذهبيّ، وشعلةٌ خلفه تنبض.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.loop, required this.lift, required this.still});

  final Animation<double> loop;
  final double lift;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, child) {
        // نبضةٌ ناعمة: جيبٌ على الدورة، لا قفزة.
        final beat = still ? 0.0 : (math.sin(loop.value * math.pi * 4) + 1) / 2;
        final scale = 1 + beat * 0.05 + lift * 0.08;
        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFEA580C)],
                stops: [0.0, 0.62, 1.0],
              ),
              border: Border.all(color: Colors.white, width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF97316)
                      .withValues(alpha: 0.45 + beat * 0.25 + lift * 0.2),
                  blurRadius: 14 + beat * 8 + lift * 10,
                  spreadRadius: 1 + beat * 2,
                ),
                const BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 4,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: const Padding(
        padding: EdgeInsets.all(7),
        child: FittedBox(
          child: Text(
            '⚔️',
            // بلا إطارٍ ولا لون: الرمزُ يُرسم بألوانه.
            style: TextStyle(fontSize: 28, height: 1),
          ),
        ),
      ),
    );
  }
}

/// شارةُ «تحدٍّ فوري» بنقطةٍ حمراء تنبض كضوء البثّ.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.loop, required this.still});

  final Animation<double> loop;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.4),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: loop,
            builder: (context, _) {
              final on = still ? 1.0 : (math.cos(loop.value * math.pi * 6) + 1) / 2;
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.45 + on * 0.55),
                ),
              );
            },
          ),
          const SizedBox(width: 5),
          Text(
            tr('portal.challenge.live'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// مكافأةُ الفوز: جوهرةٌ وخبرة، بأرقامها كما يصرفها الخادم.
class _RewardBadge extends StatelessWidget {
  const _RewardBadge();

  @override
  Widget build(BuildContext context) {
    Widget chip(String icon, String label, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xCC1E1B4B),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.9), width: 1.3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 11, height: 1.1)),
              const SizedBox(width: 3),
              Text(
                label,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ],
          ),
        );

    return Semantics(
      label: trf('portal.challenge.reward', {
        'gems': '$duelWinGems',
        'xp': '$duelWinXp',
      }),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip('💎', '+$duelWinGems', const Color(0xFF67E8F9)),
            const SizedBox(width: 4),
            chip('⚡', '+$duelWinXp XP', const Color(0xFFFDE047)),
          ],
        ),
      ),
    );
  }
}

/// لمعةٌ قُطريةٌ تعبر الوجهَ في أوّل ربع الدورة، ثم يهدأ الوجه.
class _Sheen extends StatelessWidget {
  const _Sheen({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    const window = 0.26;
    if (t > window) return const SizedBox.expand();
    // من خارج الحافّة اليسرى إلى خارج اليمنى.
    final center = -0.25 + (t / window) * 1.5;
    double at(double v) => v.clamp(0.0, 1.0);
    final stops = [
      0.0,
      at(center - 0.14),
      at(center),
      at(center + 0.14),
      1.0,
    ];
    // المواضعُ تُقصّ إلى [0،1] فقد تتساوى عند الطرفين — والتدرّجُ يقبل
    // المتساوي ولا يقبل المتناقص.
    for (var i = 1; i < stops.length; i++) {
      stops[i] = math.max(stops[i], stops[i - 1]);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-1, -0.6),
          end: const Alignment(1, 0.6),
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
          ],
          stops: stops,
        ),
      ),
    );
  }
}
