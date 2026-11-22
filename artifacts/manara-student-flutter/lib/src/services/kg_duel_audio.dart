import '../models/duel_question.dart';

/// «تحدَّ زملاءك» لصفّ «روضة منارة المعرفة» وحده: مئةُ سؤالٍ مسموع.
///
/// الخادمُ يبني حزمةَ مباراة الروضة من هذه الأسئلة (`kgDuelBank.ts`)، ومعرّفُ
/// كلّ سؤالٍ `kg_NNN`. ومقطعُه في أصول التطبيق `assets/audio/kg_duel/question_NNN.mp3`
/// (منسوخةً من `Kindergarten_100_Questions` كما أُعطيت).
///
/// والصفوفُ الأخرى أسئلتُها بلا هذه المعرّفات، فلا مقطعَ ولا تغيير.
final _kgId = RegExp(r'^kg_(\d{3})$');

/// مقطعُ سؤال الروضة، أو `null` لسؤالٍ ليس منها.
String? kgDuelClipFor(DuelQuestion question) {
  final match = _kgId.firstMatch(question.id);
  return match == null ? null : 'audio/kg_duel/question_${match[1]}.mp3';
}

/// حزمةُ روضة: كلُّ أسئلتها من الأسئلة المسموعة.
bool isKgDuelPack(List<DuelQuestion> questions) =>
    questions.isNotEmpty && questions.every((q) => kgDuelClipFor(q) != null);
