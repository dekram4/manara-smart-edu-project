// ‏يكتب منهجَ الحساب الرسمي لوضع الزائر في `assets/demo/catalog_<track>.json`.
//
// ‏يُشغَّل في البناء قبل `flutter build apk`:
//
//   SUPABASE_URL=... SUPABASE_ANON_KEY=... dart run tool/snapshot_demo_catalog.dart
//
// ‏يقرأ بالمفتاح العام ما يقرؤه الحسابُ الرسمي — `app_kv` و`lesson_configs`
// ‏و`created_quizzes` — ويختار منه مدخلَ الروضة الرسمي ومدخلَ الصف الرابع
// ‏بالقاعدة نفسها التي يقرأ بها التطبيق ([DemoCatalogBuilder.build]). فالزائرُ
// ‏يرى المنهجَ كاملاً ولا يسأل الخادمَ عن شيءٍ منه.
//
// ‏ولا يُفشل البناء: إن غابت الأسرارُ أو تعذّر الاتصال بقي الملفُّ كما هو
// ‏(وفارغاً فالمنهجُ المدمج DemoContent بديلاً)، مع تنبيهٍ في سجلّ البناء.
// ‏ولا يقرأ جدولَ `cinema_videos`: سينما المعلم ليست من بيانات الزائر.
import 'dart:convert';
import 'dart:io';

import 'package:manara_student/src/services/demo_catalog_data.dart';

const _tracks = ['kg', 'grade4'];

Future<void> main() async {
  final url = (Platform.environment['SUPABASE_URL'] ?? '').trim().replaceFirst(RegExp(r'/$'), '');
  final key = (Platform.environment['SUPABASE_ANON_KEY'] ?? '').trim();
  if (url.isEmpty || key.isEmpty) {
    stdout.writeln('::warning::SUPABASE_URL أو SUPABASE_ANON_KEY غير مضبوط — يبقى منهجُ الزائر المدمج.');
    return;
  }
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    Future<Object?> get(String path) async {
      final request = await http.getUrl(Uri.parse('$url/rest/v1/$path'));
      request.headers
        ..set('apikey', key)
        ..set('Authorization', 'Bearer $key')
        ..set('Accept', 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 60));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 300) throw HttpException('$path → ${response.statusCode}: $body');
      return jsonDecode(body);
    }

    Future<Object?> kv(String name) async {
      final rows = await get('app_kv?select=value&key=eq.${Uri.encodeComponent(name)}&limit=1');
      return rows is List && rows.isNotEmpty && rows.first is Map ? (rows.first as Map)['value'] : null;
    }

    Future<Object?> optional(Future<Object?> f) => f.catchError((Object _) => null);

    final hierarchy = await kv('smartEdu_hierarchicalConfigs');
    final lessons = await get('lesson_configs?select=id,data&limit=500');
    final quizzes = await get('created_quizzes?select=id,data,updated_at&limit=300');
    final legacyQuestions = await optional(kv('smartEdu_quizQuestions'));
    final deletedQuizzes = await optional(kv('smartEdu_deletedQuizzes'));
    final videos = await optional(kv('smartEdu_videos'));
    final deletedVideos = await optional(kv('smartEdu_deletedVideos'));

    for (final track in _tracks) {
      final data = DemoCatalogBuilder.build(
        track: track,
        hierarchy: hierarchy,
        lessonRows: lessons,
        quizRows: quizzes,
        legacyQuestions: legacyQuestions,
        deletedQuizIds: deletedQuizzes,
        videos: videos,
        deletedVideoIds: deletedVideos,
      );
      if (data == null) {
        stdout.writeln('::warning::لا منهجَ رسمياً لمسار $track — يبقى منهجُه المدمج.');
        continue;
      }
      final file = File('assets/demo/catalog_$track.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(data.toJson()));
      stdout.writeln('$track: ${data.grade} · ${data.owner} · '
          '${data.lessonRows.length} درساً · ${data.quizRows.length} اختباراً · '
          '${(await file.length()) ~/ 1024} KB');
    }
  } catch (error) {
    stdout.writeln('::warning::تعذّر جلبُ منهج الزائر ($error) — يبقى منهجُه المدمج.');
  } finally {
    http.close(force: true);
  }
}
