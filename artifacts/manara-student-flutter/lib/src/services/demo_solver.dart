/// «حلّ المسائل» للزائر: جوابٌ على الجهاز من شرح الدرس نفسه.
///
/// المساعدُ الذكيّ يحتاج جلسةً على الخادم، والزائرُ بلا جلسة. فيُجاب سؤالاه
/// ([DemoMode.solverQuestions]) هنا: أقربُ جمل الشرح إلى ما سأل، وخطواتٌ
/// تدلّه على الحلّ — مكتوباً كان السؤالُ أو بالصوت أو بالصورة. وما بعدهما
/// تحت قفل الحساب الرسمي.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/student_content.dart';
import 'demo_mode.dart';

/// عدّادُ أسئلة الزائر في «حل المسائل»: سؤالان في اليوم كلِّه
/// ([DemoMode.solverQuestions]) — لا في كل فتحةٍ للبطاقة.
///
/// ‏كان العدّادُ في ذاكرة الشاشة، فيعود صفراً كلّما أُغلقت البطاقةُ أو
/// ‏التطبيق. فصار على الجهاز بمفتاح تاريخ اليوم (`YYYY-MM-DD`): الخروجُ
/// ‏والرجوع لا يُعيدانه، وغداً يبدأ من جديد. ولا يُقرأ ولا يُكتب إلا في وضع
/// ‏الزائر: الحسابُ الرسمي حصّتُه على الخادم وحده، ولا يمسّه هذا.
abstract final class DemoSolverQuota {
  static const _prefix = 'demo.solver.asked.';

  /// تاريخُ اليوم بالتقويم المحلّي: `2026-11-17`.
  static String dayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// كم سأل الزائرُ اليوم. صفرٌ للحساب الرسمي دائماً.
  static Future<int> used({DateTime? now}) async {
    if (!DemoMode.active) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$_prefix${dayKey(now)}') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// يسجّل سؤالاً اليوم ويعيد العددَ بعده، ويمحو أيّامَ ما قبله.
  static Future<int> record({DateTime? now}) async {
    if (!DemoMode.active) return 0;
    final key = '$_prefix${dayKey(now)}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = (prefs.getInt(key) ?? 0) + 1;
      await prefs.setInt(key, next);
      for (final old in prefs.getKeys().where((k) => k.startsWith(_prefix) && k != key).toList()) {
        await prefs.remove(old);
      }
      return next;
    } catch (_) {
      return DemoMode.solverQuestions;
    }
  }
}

abstract final class DemoSolver {
  static String answer({
    required String question,
    required LessonContent lesson,
    bool photo = false,
    bool voice = false,
  }) {
    final name = lesson.lessonName.trim().isEmpty ? lesson.subject : lesson.lessonName.trim();
    final excerpt = _excerpt(question, lesson.lessonText ?? '');
    final asked = question.trim();
    return [
      if (photo) '📷 وصلتني صورةُ سؤالك.',
      if (voice) '🎤 سمعتُ سؤالك.',
      if (excerpt.isNotEmpty) ...['💡 من درس «$name»:', excerpt, ''] else '💡 سؤالٌ جميل عن «$name»!\n',
      '🧭 خطوات الحل:',
      '١. حدِّد المطلوب${asked.isEmpty || photo ? '' : ': «${_short(asked)}»'}.',
      '٢. ارجع إلى فكرة الدرس وطبّقها على سؤالك.',
      '٣. تحقّق من إجابتك بمثالٍ بسيط.',
      '',
      '✨ هذه إجابةُ التجربة. في الحساب الرسمي يحلّ المساعدُ الذكي سؤالك خطوةً بخطوة.',
    ].join('\n');
  }

  static String _short(String s) => s.length <= 80 ? s : '${s.substring(0, 80)}…';

  /// أقربُ جملتين من الشرح إلى السؤال (بالكلمات المشتركة)، أو أوّلُ جملتين.
  static String _excerpt(String question, String text) {
    final plain = text
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'[#*_`>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plain.isEmpty) return '';
    final sentences = plain
        .split(RegExp(r'(?<=[.!؟?،:])\s+|\n'))
        .map((s) => s.trim())
        .where((s) => s.length > 3)
        .toList();
    if (sentences.isEmpty) return _short(plain);
    final words = _words(question);
    final ranked = [for (var i = 0; i < sentences.length; i++) (i, _words(sentences[i]).intersection(words).length)]
      ..sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.compareTo(b.$1));
    final picked = (ranked.first.$2 == 0 ? [0, 1] : ranked.take(2).map((r) => r.$1).toList()..sort())
        .where((i) => i < sentences.length);
    final out = picked.map((i) => sentences[i]).join(' ');
    return out.length <= 420 ? out : '${out.substring(0, 420)}…';
  }

  static Set<String> _words(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[\\u064B-\\u0652]'), '')
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .map((w) => w.startsWith('ال') && w.length > 4 ? w.substring(2) : w)
      .where((w) => w.length > 2)
      .toSet();
}
