import 'dart:async';
import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'coloring_canvas.dart';
import 'image_compress.dart';
import 'student_auth_service.dart';

/// من يرسم: معرّفُه يفصل «لوحاتي» على الجهاز، و[cloud] يحفظ لوحاته على الخادم
/// فتصحبه إلى أيّ جهاز. بلا [cloud]: حفظٌ على الجهاز وفي الاستوديو وحدهما.
class ColoringAccount {
  const ColoringAccount({required this.studentId, this.cloud});

  final String studentId;
  final ColoringCloud? cloud;
}

/// لوحةٌ في السحابة كما تُسرد: بلا صورتها ولا خطواتها — تُجلبان عند فتحها.
class CloudArtwork {
  const CloudArtwork({required this.id, required this.title, required this.time});

  factory CloudArtwork.fromJson(Map<String, dynamic> json) => CloudArtwork(
        id: '${json['id'] ?? ''}',
        title: '${json['title'] ?? ''}',
        time: DateTime.tryParse('${json['time'] ?? ''}')?.toLocal(),
      );

  final String id;
  final String title;
  final DateTime? time;
}

/// لماذا لم يتمّ طلبٌ إلى السحابة.
enum CloudProblem {
  /// الخادمُ أقدمُ من التطبيق: المسارُ غيرُ منشورٍ عليه بعد.
  notDeployed,

  /// بلغ الطالبُ أقصى عدد اللوحات السحابية.
  full,

  /// لا جلسة، أو انتهت.
  session,

  /// الشبكة أو الخادم.
  unavailable,
}

class CloudException implements Exception {
  const CloudException(this.problem, [this.message]);

  final CloudProblem problem;
  final String? message;

  @override
  String toString() => 'CloudException($problem, $message)';
}

/// «لوحاتي في السحابة»: \`/api/student/artworks\` على خادم المنصّة.
///
/// ── ما يُرفع ──
/// صورةُ اللوحة مضغوطةً ([compressForUpload]) لتُعرض في القائمة على أيّ جهاز،
/// وخطواتُها (JSON مضغوطاً بـ gzip) لتُفتح من جديد وتُكمَل — لا صورةً جامدة.
class ColoringCloud {
  ColoringCloud({required this.baseUrl, required this.authService, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final StudentAuthService authService;
  final http.Client _client;

  /// أقصى ضلعٍ لصورة اللوحة في السحابة: تكفي القائمةَ والعرض، وتبقى خفيفة.
  static const imageSide = 512;

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.trim().replaceFirst(RegExp(r'/$'), '')}/api/student/artworks$path');

  /// ترويسةُ الجلسة الحالية — لصور القائمة (\`Image.network\`).
  Map<String, String> get imageHeaders {
    final token = authService.apiSessionToken;
    return token == null || token.isEmpty ? const {} : {'Authorization': 'Bearer $token'};
  }

  Uri imageUrl(String id) => _uri('/${Uri.encodeComponent(id)}/image');

  Future<Map<String, String>> _headers() async {
    final token = await authService.ensureApiSession();
    if (token == null || token.isEmpty) throw const CloudException(CloudProblem.session);
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  Never _fail(http.Response response) {
    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}
    final message = body['error']?.toString();
    if (response.statusCode == 404 && body['code'] == 'not_found') {
      throw CloudException(CloudProblem.notDeployed, message);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (response.statusCode == 401) authService.expireApiSession();
      throw CloudException(CloudProblem.session, message);
    }
    if (response.statusCode == 409) throw CloudException(CloudProblem.full, message);
    throw CloudException(CloudProblem.unavailable, message);
  }

  Future<List<CloudArtwork>> list() async {
    try {
      final response =
          await _client.get(_uri(''), headers: await _headers()).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) _fail(response);
      final data = jsonDecode(response.body);
      final items = data is Map && data['artworks'] is List ? data['artworks'] as List : const [];
      return [
        for (final item in items)
          if (item is Map<String, dynamic>) CloudArtwork.fromJson(item),
      ];
    } on CloudException {
      rethrow;
    } catch (error) {
      throw CloudException(CloudProblem.unavailable, '$error');
    }
  }

  /// يرفع [artwork] — صورتَها مضغوطةً وخطواتِها. و[replaces] لوحةٌ سحابيةٌ فُتحت
  /// فعُدّلت: تحلّ الجديدةُ محلَّها.
  Future<CloudArtwork> save(ColoringArtwork artwork, {required String title, String? replaces}) async {
    final png = await artwork.toPng(size: imageSide);
    if (png == null) throw const CloudException(CloudProblem.unavailable);
    final image = await compressForUpload(png, maxSide: imageSide, maxBytes: 200 * 1024);
    final doc = base64Encode(gzip.encode(utf8.encode(jsonEncode(artwork.toJson()))));
    try {
      final response = await _client
          .post(
            _uri(''),
            headers: await _headers(),
            body: jsonEncode({
              'title': title,
              'image': base64Encode(image),
              'doc': doc,
              if (replaces != null) 'replaces': replaces,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 201) _fail(response);
      final data = jsonDecode(response.body);
      return CloudArtwork.fromJson(data is Map<String, dynamic> && data['artwork'] is Map<String, dynamic>
          ? data['artwork'] as Map<String, dynamic>
          : const {});
    } on CloudException {
      rethrow;
    } catch (error) {
      throw CloudException(CloudProblem.unavailable, '$error');
    }
  }

  /// اللوحةُ نفسُها بخطواتها، لتُفتح وتُكمَل على هذا الجهاز.
  Future<ColoringArtwork?> open(String id) async {
    try {
      final response = await _client
          .get(_uri('/${Uri.encodeComponent(id)}/doc'), headers: await _headers())
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) _fail(response);
      final data = jsonDecode(response.body);
      final doc = data is Map ? data['doc'] : null;
      if (doc is! String || doc.isEmpty) return null;
      return ColoringArtwork.fromJson(jsonDecode(utf8.decode(gzip.decode(base64Decode(doc)))));
    } on CloudException {
      rethrow;
    } catch (error) {
      debugPrint('[coloring-cloud] open failed: $error');
      throw CloudException(CloudProblem.unavailable, '$error');
    }
  }

  Future<void> delete(String id) async {
    try {
      final response = await _client
          .delete(_uri('/${Uri.encodeComponent(id)}'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) _fail(response);
    } on CloudException {
      rethrow;
    } catch (error) {
      throw CloudException(CloudProblem.unavailable, '$error');
    }
  }
}
