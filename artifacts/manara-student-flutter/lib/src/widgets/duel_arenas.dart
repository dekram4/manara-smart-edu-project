import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/student_duel_service.dart';
import '../theme/student_theme.dart';
import 'arena_widgets.dart';
import 'student_avatar_view.dart';

/// حلباتُ المبارزة الأربع، وخياراتُها.
///
/// ── لماذا الشكلُ وحده هنا ──
/// الألعابُ الأربع مباراةٌ واحدة في جوهرها: الأسئلةُ نفسها ببذرةٍ واحدة،
/// وخمسةُ أشواط، ونتيجةٌ يحسمها الخادم. ولو نُسخ ذلك أربعَ مرّات لاختلفت
/// الأربعُ عند أوّل تعديل بلا خطأٍ يظهر.
///
/// فالمحرّكُ واحدٌ في `StudentDuelGameScreen`، وهذه تلبسه: حلبةٌ تُرى فيها
/// المنافسة، وخياراتٌ تُلمس. وكلُّها تقرأ الشيءَ نفسه — نتيجتي ونتيجته من
/// خمسة — فلا تُخترع لعبةٌ حساباً خاصّاً بها.

/// الحلبة: كيف تُرى المنافسةُ في هذه اللعبة.
class DuelArena extends StatelessWidget {
  const DuelArena({
    required this.game,
    required this.mine,
    required this.theirs,
    required this.total,
    required this.live,
    required this.myAppearance,
    required this.theirAppearance,
    required this.opponentName,
    super.key,
  });

  final DuelGame game;
  final int mine;
  final int theirs;
  final int total;
  final bool live;
  final Map<String, dynamic>? myAppearance;
  final Map<String, dynamic>? theirAppearance;
  final String opponentName;

  String get _rival => opponentName.isEmpty ? tr('duel.rival') : opponentName;

  /// نقطةٌ تقول إن كان الخصم يلعب الآن أو لعب من قبل.
  String get _badge => tr(live ? 'duel.liveNow' : 'duel.ghost');

  @override
  Widget build(BuildContext context) {
    return Card(
      color: StudentSurface.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: switch (game) {
          DuelGame.sprint => _RaceTrack(
              mine: mine,
              theirs: theirs,
              total: total,
              myAppearance: myAppearance,
              theirAppearance: theirAppearance,
              rival: _rival,
              badge: _badge,
            ),
          DuelGame.balloons => _BalloonWar(
              mine: mine,
              theirs: theirs,
              total: total,
              rival: _rival,
              badge: _badge,
            ),
          DuelGame.tug => _TugRope(
              mine: mine,
              theirs: theirs,
              total: total,
              myAppearance: myAppearance,
              theirAppearance: theirAppearance,
              rival: _rival,
              badge: _badge,
            ),
          DuelGame.gems => _GemHaul(
              mine: mine,
              theirs: theirs,
              total: total,
              rival: _rival,
              badge: _badge,
            ),
        },
      ),
    );
  }
}

/// عنوانُ مسارٍ في الحلبة: الاسمُ، وحالُ الخصم، والنتيجة.
class _LaneLabel extends StatelessWidget {
  const _LaneLabel({
    required this.name,
    required this.at,
    required this.total,
    required this.tint,
    this.badge,
  });

  final String name;
  final int at;
  final int total;
  final Color tint;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: StudentSurface.ink(context),
            ),
          ),
        ),
        // يتقلّص ولا يتجاوز: في جرّة الجواهر نصفُ الشاشة للاسم والشارة والعدد.
        if (badge != null)
          Flexible(
            child: Text(
              badge!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: StudentSurface.mutedInk(context),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          '$at/$total',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: tint,
          ),
        ),
      ],
    );
  }
}

const _mineTint = Color(0xFF16A34A);
const _rivalTint = Color(0xFFDC2626);

// ── سباقُ الحلبة ──

/// مضمارٌ يمشي عليه العدّاء، وخطُّ النهاية في آخره.
class _RaceTrack extends StatelessWidget {
  const _RaceTrack({
    required this.mine,
    required this.theirs,
    required this.total,
    required this.myAppearance,
    required this.theirAppearance,
    required this.rival,
    required this.badge,
  });

  final int mine;
  final int theirs;
  final int total;
  final Map<String, dynamic>? myAppearance;
  final Map<String, dynamic>? theirAppearance;
  final String rival;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Lane(
          name: tr('duel.you'),
          appearance: myAppearance,
          at: mine,
          total: total,
          tint: _mineTint,
        ),
        const SizedBox(height: 10),
        _Lane(
          name: rival,
          appearance: theirAppearance,
          at: theirs,
          total: total,
          tint: _rivalTint,
          badge: badge,
        ),
      ],
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    required this.name,
    required this.appearance,
    required this.at,
    required this.total,
    required this.tint,
    this.badge,
  });

  final String name;
  final Map<String, dynamic>? appearance;
  final int at;
  final int total;
  final Color tint;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final fraction = total <= 0 ? 0.0 : (at / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LaneLabel(
          name: name,
          at: at,
          total: total,
          tint: tint,
          badge: badge,
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            const runner = 34.0;
            final span = (constraints.maxWidth - runner).clamp(0.0, 4000.0);
            return SizedBox(
              height: runner + 8,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: runner / 2,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: tint.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    end: 0,
                    top: 0,
                    child: Text('🏁', style: TextStyle(fontSize: runner * 0.6)),
                  ),
                  AnimatedPositionedDirectional(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    start: span * fraction,
                    top: 0,
                    child:
                        StudentAvatarView(size: runner, appearance: appearance),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── حربُ البالونات ──

/// صفٌّ من البالونات لكلِّ لاعب، تُفرقع واحدةً بكل إجابةٍ صحيحة.
///
/// والفرقعةُ تُرى: البالونةُ تصغر وتبهت ويبقى أثرُها مكانها، فيُعرف عددُ ما
/// فُرقع بالنظر لا بقراءة رقم.
class _BalloonWar extends StatelessWidget {
  const _BalloonWar({
    required this.mine,
    required this.theirs,
    required this.total,
    required this.rival,
    required this.badge,
  });

  final int mine;
  final int theirs;
  final int total;
  final String rival;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BalloonRow(
          name: tr('duel.you'),
          popped: mine,
          total: total,
          tint: _mineTint,
          colors: const [Color(0xFF22C55E), Color(0xFF15803D)],
        ),
        const SizedBox(height: 12),
        _BalloonRow(
          name: rival,
          popped: theirs,
          total: total,
          tint: _rivalTint,
          badge: badge,
          colors: const [Color(0xFFF87171), Color(0xFFB91C1C)],
        ),
      ],
    );
  }
}

class _BalloonRow extends StatelessWidget {
  const _BalloonRow({
    required this.name,
    required this.popped,
    required this.total,
    required this.tint,
    required this.colors,
    this.badge,
  });

  final String name;
  final int popped;
  final int total;
  final Color tint;
  final List<Color> colors;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LaneLabel(
          name: name,
          at: popped,
          total: total,
          tint: tint,
          badge: badge,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var index = 0; index < total; index += 1)
              _Balloon(burst: index < popped, colors: colors),
          ],
        ),
      ],
    );
  }
}

class _Balloon extends StatelessWidget {
  const _Balloon({required this.burst, required this.colors});

  final bool burst;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      scale: burst ? 0.6 : 1,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 320),
        opacity: burst ? 0.45 : 1,
        child: SizedBox(
          width: 30,
          height: 40,
          child: Column(
            children: [
              Container(
                width: 26,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: burst
                      ? null
                      : LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: burst
                      ? StudentSurface.mutedInk(context).withValues(alpha: 0.18)
                      : null,
                ),
                child: burst
                    ? const Center(
                        child: Text('💥', style: TextStyle(fontSize: 14)),
                      )
                    : null,
              ),
              // خيطُ البالونة: يُسقط عند الفرقعة، فيُرى الفرقُ بلا لون.
              if (!burst)
                Container(
                  width: 1.6,
                  height: 8,
                  color: colors.last.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── شدُّ الحبل ──

/// حبلٌ وعقدةٌ في وسطه تنزلق إلى صاحب الإجابات الأكثر.
///
/// والموضعُ هو الفرقُ بين النتيجتين لا النتيجةَ نفسها: عقدةٌ في المنتصف
/// تعني تعادلاً، وهو ما يعنيه شدُّ الحبل.
class _TugRope extends StatelessWidget {
  const _TugRope({
    required this.mine,
    required this.theirs,
    required this.total,
    required this.myAppearance,
    required this.theirAppearance,
    required this.rival,
    required this.badge,
  });

  final int mine;
  final int theirs;
  final int total;
  final Map<String, dynamic>? myAppearance;
  final Map<String, dynamic>? theirAppearance;
  final String rival;
  final String badge;

  @override
  Widget build(BuildContext context) {
    // الفرقُ منسوباً إلى أقصى ما يمكن: من ‎-1‎ (كلُّها له) إلى ‎+1‎ (كلُّها لي).
    final lead = total <= 0 ? 0.0 : ((mine - theirs) / total).clamp(-1.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            StudentAvatarView(size: 34, appearance: myAppearance, showRing: false),
            const SizedBox(width: 8),
            Expanded(
              child: _LaneLabel(
                name: tr('duel.you'),
                at: mine,
                total: total,
                tint: _mineTint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const knot = 30.0;
            final half = (constraints.maxWidth - knot) / 2;
            return SizedBox(
              height: knot + 6,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: knot / 2 - 3,
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(0xFFB45309).withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  // علامةُ المنتصف: بها يُقرأ الميل.
                  Positioned(
                    left: constraints.maxWidth / 2 - 1,
                    top: 0,
                    child: Container(
                      width: 2,
                      height: knot,
                      color: StudentSurface.mutedInk(context)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  AnimatedPositionedDirectional(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    start: half + half * lead,
                    top: 0,
                    child: Container(
                      width: knot,
                      height: knot,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFB45309),
                      ),
                      child: const Text('🪢', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            StudentAvatarView(
              size: 34,
              appearance: theirAppearance,
              showRing: false,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LaneLabel(
                name: rival,
                at: theirs,
                total: total,
                tint: _rivalTint,
                badge: badge,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── صائدُ الجواهر ──

/// كيسانِ يمتلئان بالجواهر، واحدٌ لكلِّ لاعب.
class _GemHaul extends StatelessWidget {
  const _GemHaul({
    required this.mine,
    required this.theirs,
    required this.total,
    required this.rival,
    required this.badge,
  });

  final int mine;
  final int theirs;
  final int total;
  final String rival;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _GemJar(
            name: tr('duel.you'),
            count: mine,
            total: total,
            tint: _mineTint,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GemJar(
            name: rival,
            count: theirs,
            total: total,
            tint: _rivalTint,
            badge: badge,
          ),
        ),
      ],
    );
  }
}

class _GemJar extends StatelessWidget {
  const _GemJar({
    required this.name,
    required this.count,
    required this.total,
    required this.tint,
    this.badge,
  });

  final String name;
  final int count;
  final int total;
  final Color tint;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final fraction = total <= 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LaneLabel(
          name: name,
          at: count,
          total: total,
          tint: tint,
          badge: badge,
        ),
        const SizedBox(height: 8),
        // الكيسُ يمتلئ من أسفله: الارتفاعُ هو العدّاد.
        Container(
          height: 74,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tint.withValues(alpha: 0.4), width: 1.4),
            color: tint.withValues(alpha: 0.06),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  heightFactor: fraction,
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: tint.withValues(alpha: 0.26),
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  '💎' * (count > 3 ? 3 : count),
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// الخياراتُ بالشكل الذي تُلمس به في هذه اللعبة.
///
/// ── والجوابُ الصحيحُ لا يُكشف قبل وقته ──
/// من أخطأ مبكّراً يرى خطأه وحده، لا الصحيح: زميلُه ما زال يفكّر، والدردشةُ
/// مفتوحةٌ بينهما — وجوابٌ يُرى قبل الكشف يُرسل في رسالة. فالصحيحُ يظهر للاثنين
/// معاً حين يُحسم السؤال ([revealed]).
class DuelChoices extends StatelessWidget {
  const DuelChoices({
    required this.game,
    required this.options,
    required this.answerAt,
    required this.picked,
    required this.pickedCorrect,
    required this.revealed,
    required this.onPick,
    super.key,
  });

  final DuelGame game;
  final List<String> options;
  final int answerAt;
  final int? picked;

  /// ما قاله الخادمُ عن اختياري: `null` قبل أن يردّ.
  final bool? pickedCorrect;

  /// حُسم السؤال: يُرى الصحيح.
  final bool revealed;

  /// `null`: الخياراتُ مقفلة — اخترتُ، أو حُسم السؤال.
  final ValueChanged<int>? onPick;

  _ChoiceState _state(int index) =>
      _stateOf(index, picked, pickedCorrect, answerAt, revealed);

  AnswerTileState _tile(int index) {
    if (revealed) {
      if (index == answerAt) return AnswerTileState.correct;
      if (index == picked) return AnswerTileState.wrong;
      return AnswerTileState.dimmed;
    }
    if (picked == null) return AnswerTileState.idle;
    if (index == picked) {
      return pickedCorrect == false ? AnswerTileState.wrong : AnswerTileState.picked;
    }
    return AnswerTileState.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    return switch (game) {
      DuelGame.balloons => _BalloonChoices(
          options: options,
          state: _state,
          picked: picked,
          onPick: onPick,
        ),
      DuelGame.gems => _GemChoices(
          options: options,
          state: _state,
          picked: picked,
          onPick: onPick,
        ),
      // السباقُ وشدُّ الحبل: بلاطاتٌ مجسّمةٌ على طراز Kahoot — لونٌ وشكلٌ لكل
      // موضع. والفرقُ بينهما في الحلبة لا في الخيار.
      DuelGame.sprint || DuelGame.tug => LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 2 : 1;
            const gap = 10.0;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var index = 0; index < options.length; index += 1)
                  SizedBox(
                    width: width,
                    child: AnswerTile(
                      index: index,
                      label: options[index],
                      state: _tile(index),
                      onPressed: onPick == null ? null : () => onPick!(index),
                    ),
                  ),
              ],
            );
          },
        ),
    };
  }
}

/// حالُ الخيار بعد الاختيار: صحيحٌ، أو خطأٌ اختِير، أو محايد.
enum _ChoiceState { idle, right, wrong }

_ChoiceState _stateOf(
  int index,
  int? picked,
  bool? pickedCorrect,
  int answerAt,
  bool revealed,
) {
  if (revealed) {
    if (index == answerAt) return _ChoiceState.right;
    if (index == picked) return _ChoiceState.wrong;
    return _ChoiceState.idle;
  }
  if (index != picked) return _ChoiceState.idle;
  return switch (pickedCorrect) {
    true => _ChoiceState.right,
    false => _ChoiceState.wrong,
    null => _ChoiceState.idle,
  };
}

({Color border, Color fill, Color ink}) _paint(
  _ChoiceState state,
  BuildContext context,
) =>
    switch (state) {
      _ChoiceState.right => (
          border: const Color(0xFF16A34A),
          fill: const Color(0xFFDCFCE7),
          ink: const Color(0xFF14532D),
        ),
      _ChoiceState.wrong => (
          border: const Color(0xFFDC2626),
          fill: const Color(0xFFFEE2E2),
          ink: const Color(0xFF7F1D1D),
        ),
      _ChoiceState.idle => (
          border: const Color(0xFF7C3AED).withValues(alpha: 0.30),
          fill: Colors.transparent,
          ink: StudentSurface.ink(context),
        ),
    };

/// بالوناتٌ تُفرقع: الجوابُ في واحدةٍ منها.
class _BalloonChoices extends StatelessWidget {
  const _BalloonChoices({
    required this.options,
    required this.state,
    required this.picked,
    required this.onPick,
  });

  final List<String> options;
  final _ChoiceState Function(int index) state;
  final int? picked;
  final ValueChanged<int>? onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var index = 0; index < options.length; index += 1)
          _BalloonChoice(
            text: options[index],
            state: state(index),
            popped: picked != null && index == picked,
            onTap: onPick == null ? null : () => onPick!(index),
          ),
      ],
    );
  }
}

class _BalloonChoice extends StatelessWidget {
  const _BalloonChoice({
    required this.text,
    required this.state,
    required this.popped,
    required this.onTap,
  });

  final String text;
  final _ChoiceState state;
  final bool popped;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final paint = _paint(state, context);
    final neutral = state == _ChoiceState.idle;
    return AnimatedScale(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      // المفرقعةُ تصغر: أثرُ الضغطة يُرى على البالونة التي لُمست.
      scale: popped ? 0.86 : 1,
      child: Material(
        color: neutral ? const Color(0xFFEDE9FE) : paint.fill,
        shape: const _BalloonBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 104,
            height: 104,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: ShapeDecoration(
              shape: _BalloonBorder(side: BorderSide(color: paint.border, width: 1.6)),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: paint.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// بالونةٌ: دائرةٌ بذيلٍ صغير أسفلها.
class _BalloonBorder extends ShapeBorder {
  const _BalloonBorder({this.side = BorderSide.none});

  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final body = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      rect.height * 0.88,
    );
    final tailTop = body.bottom - 2;
    final centre = rect.center.dx;
    return Path()
      ..addOval(body)
      ..moveTo(centre - 6, tailTop)
      ..lineTo(centre + 6, tailTop)
      ..lineTo(centre, rect.bottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      getOuterPath(rect, textDirection: textDirection),
      side.toPaint()..style = PaintingStyle.stroke,
    );
  }

  @override
  ShapeBorder scale(double t) => _BalloonBorder(side: side.scale(t));
}

/// جواهرُ في كهف: الجوابُ محفورٌ في واحدةٍ منها.
class _GemChoices extends StatelessWidget {
  const _GemChoices({
    required this.options,
    required this.state,
    required this.picked,
    required this.onPick,
  });

  final List<String> options;
  final _ChoiceState Function(int index) state;
  final int? picked;
  final ValueChanged<int>? onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var index = 0; index < options.length; index += 1)
          _GemChoice(
            text: options[index],
            state: state(index),
            taken: picked != null && index == picked,
            onTap: onPick == null ? null : () => onPick!(index),
          ),
      ],
    );
  }
}

class _GemChoice extends StatelessWidget {
  const _GemChoice({
    required this.text,
    required this.state,
    required this.taken,
    required this.onTap,
  });

  final String text;
  final _ChoiceState state;
  final bool taken;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final paint = _paint(state, context);
    final neutral = state == _ChoiceState.idle;
    return AnimatedScale(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      scale: taken ? 1.06 : 1,
      child: Material(
        color: neutral ? const Color(0xFFCFFAFE) : paint.fill,
        // معيَّنٌ لا مستطيل: شكلُ الجوهرة يُعرف قبل أن يُقرأ ما فيها.
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 112,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: paint.border, width: 1.6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💎', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 6),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: paint.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
