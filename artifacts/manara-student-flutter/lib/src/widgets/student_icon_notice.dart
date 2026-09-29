import 'package:flutter/material.dart';

/// ملاحظةٌ للطفل، رمزاً بلا نصّ.
///
/// ── لماذا رمزٌ وحده ──
/// الملاحظاتُ كانت جُملاً كاملة فوق اللعب: «هذا الدرس مُنجَز مسبقاً —
/// اللعب للتدريب ولن تُمنح جواهر جديدة». وهي صحيحةٌ ولا تُقرأ: طفلُ
/// الابتدائية يفتح الشاشة ليلعب، فيمرّ عليها بعينه ولا يقف عندها،
/// وتأخذ من الشاشة سطرين تأخذهما من اللعب نفسه.
///
/// والرمزُ يُقرأ في لمحة: دورةٌ تعني إعادةً، وألماسةٌ تعني كسباً،
/// وألماسةٌ مشطوبة تعني أن لا كسبَ في هذه الجولة.
///
/// ── والنصُّ لم يُحذف ──
/// انتقل إلى [Tooltip] و[Semantics]: يظهر بضغطةٍ مطوّلة لمن سأل، ويُنطق
/// لقارئ الشاشة. فما يُقال للعين رمزٌ، وما يُقال لمن استوقفه كلام. وهو
/// الفرقُ بين اختصارٍ وإخفاء.
class StudentIconNotice extends StatelessWidget {
  const StudentIconNotice({
    required this.emoji,
    required this.label,
    this.tone = StudentNoticeTone.neutral,
    super.key,
  });

  /// الرمزُ المعروض، وهو كلُّ ما يُرى.
  final String emoji;

  /// الجملةُ التي كانت تُعرض: تبقى للمسةٍ مطوّلة ولقارئ الشاشة.
  final String label;

  final StudentNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final (from, to, edge) = switch (tone) {
      StudentNoticeTone.earning => (
          const Color(0xFFECFDF5),
          const Color(0xFFD1FAE5),
          const Color(0xFF16A34A),
        ),
      StudentNoticeTone.practice => (
          const Color(0xFFFFFBEB),
          const Color(0xFFFEF3C7),
          const Color(0xFFF59E0B),
        ),
      StudentNoticeTone.neutral => (
          const Color(0xFFF1F5F9),
          const Color(0xFFE2E8F0),
          const Color(0xFF64748B),
        ),
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [from, to],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: edge.withValues(alpha: 0.55), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: edge.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 17)),
        ),
      ),
    );
  }
}

/// لونُ الملاحظة. واللونُ يتبع الرمز ولا يحلّ محلَّه: من لا يميّز
/// الأخضرَ من الكهرمانيّ يقرأ الرمز.
enum StudentNoticeTone { earning, practice, neutral }
