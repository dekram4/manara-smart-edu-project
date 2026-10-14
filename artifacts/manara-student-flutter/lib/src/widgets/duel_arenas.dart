import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/student_duel_service.dart';
import '../theme/student_theme.dart';
import 'arena_widgets.dart';
import 'duel_game_arenas.dart';

export 'duel_game_arenas.dart' show ArenaRacer;

/// حلباتُ المبارزة الأربع، وخياراتُها.
///
/// الحلباتُ نفسها في `duel_game_arenas.dart`: سباقُ الحواجز وبستانُ الأرقام
/// ومغامرةُ الفضاء وأبراجُ التحدي. وهنا ما يختارها ويُلبسها الخيارات.
///
/// ── لماذا الشكلُ وحده هنا ──
/// الألعابُ الأربع مباراةٌ واحدة في جوهرها: الأسئلةُ نفسها ببذرةٍ واحدة،
/// وخمسةُ أشواط، ونتيجةٌ يحسمها الخادم. ولو نُسخ ذلك أربعَ مرّات لاختلفت
/// الأربعُ عند أوّل تعديل بلا خطأٍ يظهر.
///
/// فالمحرّكُ واحدٌ في `StudentDuelGameScreen`، وهذه تلبسه: حلبةٌ تُرى فيها
/// المنافسة، وخياراتٌ تُلمس. وكلُّها تقرأ الشيءَ نفسه — نتيجتي ونتيجته من
/// خمسة — فلا تُخترع لعبةٌ حساباً خاصّاً بها.

/// الحلبة: كيف تُرى المنافسةُ في هذه اللعبة — انظر `duel_game_arenas.dart`.
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
    this.finished = false,
    this.players,
    super.key,
  });

  /// انتهت المباراة: الحلبةُ تُري الحسم — التاجُ لمن تقدّم.
  final bool finished;

  final DuelGame game;
  final int mine;
  final int theirs;
  final int total;
  final bool live;
  final Map<String, dynamic>? myAppearance;
  final Map<String, dynamic>? theirAppearance;
  final String opponentName;

  /// التحدي الجماعي: كلُّ اللاعبين بمساراتهم المرقّمة ١، ٢، ٣… وإن غاب
  /// فاللاعبان: أنا والمتقدّم من خصومي.
  final List<ArenaRacer>? players;

  String get _rival => opponentName.isEmpty ? tr('duel.rival') : opponentName;

  /// نقطةٌ تقول إن كان الخصم يلعب الآن أو لعب من قبل.
  String? get _badge => live ? tr('duel.liveNow') : null;

  List<ArenaRacer> get _racers =>
      players ??
      [
        ArenaRacer(name: tr('duel.you'), at: mine, appearance: myAppearance, me: true),
        ArenaRacer(name: _rival, at: theirs, appearance: theirAppearance, badge: _badge),
      ];

  @override
  Widget build(BuildContext context) {
    final racers = _racers;
    return Card(
      color: StudentSurface.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: switch (game) {
          DuelGame.sprint => HurdleRaceArena(racers: racers, total: total, finished: finished),
          DuelGame.balloons => NumberOrchardArena(racers: racers, total: total, finished: finished),
          DuelGame.tug => SpaceVoyageArena(racers: racers, total: total, finished: finished),
          DuelGame.gems => ChallengeTowersArena(racers: racers, total: total, finished: finished),
        },
      ),
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
      return pickedCorrect == false
          ? AnswerTileState.wrong
          : AnswerTileState.picked;
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
      // سباقُ الحواجز ومغامرةُ الفضاء: بلاطاتٌ مجسّمةٌ على طراز Kahoot — لونٌ وشكلٌ لكل
      // موضع. والفرقُ بينهما في الحلبة لا في الخيار.
      DuelGame.sprint || DuelGame.tug => LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 2 : 1;
            const gap = 10.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
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

/// ثمارُ البستان: الجوابُ في واحدةٍ منها، تُقطف فتسقط في السلّة.
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
        color: neutral ? const Color(0xFFFFE4E6) : paint.fill,
        // ثمرةٌ بعُنقٍ صغير — الشكلُ نفسُه الذي كان بالونة، مقلوباً.
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
              shape: _BalloonBorder(
                  side: BorderSide(color: paint.border, width: 1.6)),
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
        color: neutral ? const Color(0xFFFFEDD5) : paint.fill,
        // مكعّبٌ بزوايا ناعمة: شكلُ قطعة البناء يُعرف قبل أن يُقرأ ما فيها.
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
                // مكعّبٌ يُختار فيسقط في البرج.
                const Text('🧱', style: TextStyle(fontSize: 20)),
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
