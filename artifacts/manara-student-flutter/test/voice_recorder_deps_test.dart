import 'package:flutter_test/flutter_test.dart';

// ── تُستورَد حزمةُ لينكس بقصد، وهذا سببُها ──
//
// بناءُ APK سقط مرّةً على هذا بعينه: `record` حلّ إلى `record_linux 0.7.2`
// بينما حُلّت واجهةُ المنصّة إلى 1.6.0 — وذاك الإصدارُ لا يُنفّذها: ينقصه
// أعضاءٌ، ولدالّةٍ فيه معاملاتٌ أقلّ من المنقوضة.
//
// وسقط بها بناءُ **أندرويد** لا لينكس: مُترجِمُ Dart يقرأ شيفرةَ كلِّ حزمةٍ في
// الشجرة، وحزمةُ لينكس هي الوحيدةُ في عائلة `record` التي تحمل شيفرةَ Dart —
// البقيّةُ تُنفَّذ أصليّاً (أندرويد وiOS وويندوز بلا `lib/` أصلاً). فعُطبُها
// يصل كلَّ منصّة.
//
// ولم يمسكه شيءٌ ممّا نُشغّله: `flutter pub get` مرّ، و`flutter analyze` مرّ —
// لا يفحص مصادرَ التبعيات — و٤٥٥ اختباراً مرّت، لأنّ لا اختبارَ كان يستورد
// المسجّل فلم تدخل الحزمةُ شجرةَ الترجمة.
//
// فاستيرادُها هنا يُدخلها الشجرة: عدمُ تطابقٍ كذاك يصير **فشلَ ترجمةٍ في
// `flutter test`** لا مفاجأةً في بناءٍ بعد عشر دقائق.
//
// و`record_web` ليست هنا: شيفرتُها تخاطب JS فلا تُترجَم على الآلة الافتراضية
// أصلاً، وعُطبُها يظهر في بناء الويب لا في بناء APK.
import 'package:record/record.dart';
import 'package:record_linux/record_linux.dart';
import 'package:record_platform_interface/record_platform_interface.dart';

import 'package:manara_student/src/models/duel_chat.dart';
import 'package:manara_student/src/services/duel_voice_recorder.dart';

/// يحرس تماسكَ حزم التسجيل، وإعدادَ الترميز الذي يقوم عليه بثُّ المقطع.
void main() {
  test('حزمةُ المنصّة تُنفّذ الواجهةَ التي حُلّ إليها', () {
    // ── والحرسُ في الاستيراد لا في التأكيد ──
    // لو كان فيها نقصٌ لما تُرجم هذا الملفُّ أصلاً، فلم يصل التأكيدُ. وهو
    // يبقى ليُمسك تبديلَ صنفٍ لا يَرِث الواجهةَ، وليكون للملفِّ معنىً يُقرأ.
    expect(RecordLinux(), isA<RecordPlatform>());
  });

  test('والمسجّلُ يُنشأ بلا لمسِ منصّة', () {
    // إنشاؤه وحده لا يفتح ميكروفوناً: الشاشةُ تبنيه في `initState`، فلو لمس
    // المنصّةَ هنا لسقطت كلُّ مباراةٍ على جهازٍ بلا إضافةِ تسجيل.
    expect(() => DuelVoiceRecorder(), returnsNormally);
  });

  test('وإعدادُ الترميز هو ما يجعل المقطعَ يصل', () {
    // ── وليست هذه أرقاماً اعتباطية ──
    // المقطعُ يُبثّ في رسالةٍ على قناة Realtime ولها سقفُ حجم. فخمسُ ثوانٍ عند
    // ١٦ كيلوبت/ث ≈ عشرةُ كيلوبايت، وهي دون السقف بأضعاف. ورفعُ المعدّل إلى
    // جودة الموسيقى يُضاعفه عشراً فلا يصل المقطعُ أصلاً — ولا يُفيد فهمَ كلام
    // طفلٍ شيئاً.
    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 16000,
      sampleRate: 16000,
      numChannels: 1,
    );
    expect(config.encoder, AudioEncoder.aacLc);
    expect(config.numChannels, 1);

    final fiveSeconds = duelVoiceMaxDuration.inSeconds * config.bitRate ~/ 8;
    expect(fiveSeconds, lessThan(duelVoiceMaxBytes));
  });
}
