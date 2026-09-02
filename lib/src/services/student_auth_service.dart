import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/student_profile.dart';

const studentOnlyMessage = 'هذا التطبيق مخصص للطلاب فقط، يرجى تسجيل الدخول عبر منصة الويب';

class StudentAuthException implements Exception {
  const StudentAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StudentAuthService {
  StudentAuthService(this.client);

  final SupabaseClient client;

  Future<StudentProfile> signIn({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty || password.isEmpty) {
      throw const StudentAuthException('اكتب اسم المستخدم وكلمة المرور أولًا.');
    }

    try {
      final student = await _findStudent(cleanUsername);
      if (student != null) {
        final data = _asMap(student['data']);
        final storedPassword = data['password']?.toString();
        if (!_passwordsMatch(password, storedPassword)) {
          throw const StudentAuthException('اسم المستخدم أو كلمة المرور غير صحيحة.');
        }

        final profile = StudentProfile.fromStudentRow(student);
        if (!profile.isStudent) {
          throw const StudentAuthException(studentOnlyMessage);
        }
        return profile;
      }

      if (cleanUsername.contains('@')) {
        return _signInWithSupabaseAuth(cleanUsername, password);
      }

      throw const StudentAuthException('اسم المستخدم أو كلمة المرور غير صحيحة.');
    } on StudentAuthException {
      rethrow;
    } on AuthException catch (error) {
      throw StudentAuthException(_authErrorMessage(error));
    } on PostgrestException catch (error) {
      throw StudentAuthException('تعذر الاتصال ببيانات الطلاب: ${error.message}');
    } catch (error) {
      throw StudentAuthException('حدث خطأ أثناء تسجيل الدخول: $error');
    }
  }

  Future<Map<String, dynamic>?> _findStudent(String username) async {
    final rows = await client
        .from('students')
        .select('id,data')
        .eq('data->>username', username)
        .limit(1);

    if (rows.isEmpty) return null;
    return _asMap(rows.first);
  }

  Future<StudentProfile> _signInWithSupabaseAuth(
    String email,
    String password,
  ) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const StudentAuthException('اسم المستخدم أو كلمة المرور غير صحيحة.');
    }

    final profileRow = await client
        .from('profiles')
        .select('id,role,full_name,name,grade,student_id_number')
        .eq('id', user.id)
        .maybeSingle();
    final profile = StudentProfile.fromAuthProfile(
      id: user.id,
      profile: _asMap(profileRow),
      username: email,
    );

    if (!profile.isStudent) {
      await client.auth.signOut();
      throw const StudentAuthException(studentOnlyMessage);
    }
    return profile;
  }

  bool _passwordsMatch(String input, String? stored) {
    if (stored == null || stored.isEmpty) return false;
    final normalized = stored.toLowerCase();
    final isSha256 = RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized);
    if (isSha256) {
      final digest = sha256.convert(utf8.encode(input)).toString();
      return digest == normalized;
    }
    return input == stored;
  }

  String _authErrorMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'اسم المستخدم أو كلمة المرور غير صحيحة.';
    }
    if (message.contains('email not confirmed')) {
      return 'يجب تأكيد البريد الإلكتروني قبل الدخول.';
    }
    return 'تعذر تسجيل الدخول عبر Supabase: ${error.message}';
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}