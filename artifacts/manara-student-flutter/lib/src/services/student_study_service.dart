import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../l10n/student_strings.dart';
import '../models/interactive_study.dart';
import 'student_auth_service.dart';

/// سببُ تعذُّر تحضير المذاكرة، بمفتاحِ نصٍّ يُعرض للطفل.
class StudyFailure implements Exception {
  const StudyFailure(this.key);

  final String key;

  String get message => tr('study.error.$key');

  @override
  String toString() => 'StudyFailure($key)';
}

/// يطلب حزمةَ المذاكرة الذكية لدرس من الخادم.
///
/// ── والخادمُ يخزّنها مع الدرس ──
/// فالنداءُ الأول لدرسٍ يولّدها، وما بعده يقرؤها في جزءٍ من الثانية. ولا
/// يُخزَّن شيءٌ هنا: نسخةٌ في التطبيق تعني حزمةً قديمة تبقى بعد أن يُحدّث
/// المعلمُ نصَّ الدرس، ولا سبيلَ للطفل إلى إفراغها.
class StudentStudyService {
  StudentStudyService({
    required this.apiBaseUrl,
    required this.authService,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final StudentAuthService authService;
  final http.Client _client;

  /// التوليدُ نداءٌ كبير — خريطةٌ وثلاثُ مغامرات — وللخادم ميزانيةُ أربعين
  /// ثانية. فقطعُ الخيط قبلها يُسقط حزمةً كانت في طريقها.
  static const _timeout = Duration(seconds: 95);

  /// عنوانُ المسار، أو `null` إن لم يكن لهذا البناء خادم.
  ///
  /// `Uri.base` تصلح للويب وحده: في APK ليست أصلَ موقعٍ بل مسارَ ملف.
  Uri? get endpoint {
    var base = apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty && kIsWeb) {
      final current = Uri.base;
      if (current.scheme == 'http' || current.scheme == 'https') {
        base = current.host == 'localhost' || current.host == '127.0.0.1'
            ? 'http://localhost:8080'
            : current.origin;
      }
    }
    return base.isEmpty
        ? null
        : Uri.tryParse('$base/api/ai/interactive-study');
  }

  Future<StudyPack> fetch({required String lessonId}) async {
    final target = endpoint;
    if (target == null) throw const StudyFailure('noService');
    final token = await authService.ensureApiSession();
    if (token == null || token.isEmpty) {
      // و`apiSessionError` رسالةٌ جاهزة لا مفتاحُ نصّ: لو بُحث عنها في
      // جدول النصوص لعاد المفتاحُ نفسه فظهرت الرسالةُ خاماً في الشاشة.
      final detail = authService.apiSessionError?.trim() ?? '';
      if (detail.isNotEmpty) throw StudyServerFailure(detail);
      throw const StudyFailure('sessionFailed');
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            target,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'lessonId': lessonId}),
          )
          .timeout(_timeout);
    } catch (_) {
      throw const StudyFailure('network');
    }

    Object? payload;
    try {
      payload = jsonDecode(response.body);
    } catch (_) {
      payload = null;
    }
    final map = payload is Map ? payload : const {};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // ورسالةُ الخادم تُقدَّم على رسالتنا حين يرسلها: هو يعرف السبب —
      // درسٌ بلا نصّ، أو درسٌ خارج مسار الحساب — ونحن لا نعرف إلا أنه ردّ.
      final error = map['error'];
      if (error is String && error.trim().isNotEmpty) {
        throw StudyServerFailure(error.trim());
      }
      throw const StudyFailure('failed');
    }

    final pack = StudyPack.fromMap(map['pack']);
    if (pack == null) throw const StudyFailure('badPack');
    return pack;
  }
}

/// فشلٌ برسالةٍ جاءت من الخادم نفسه.
///
/// صنفٌ منفصل لأن [StudyFailure] تحمل مفتاحَ نصٍّ محليّاً، وهذه تحمل
/// كلاماً جاهزاً — فلا يُبحث عنه في جدول النصوص ولا يُعرض المفتاح خاماً.
class StudyServerFailure implements Exception {
  const StudyServerFailure(this.message);

  final String message;

  @override
  String toString() => 'StudyFailure(server: $message)';
}
