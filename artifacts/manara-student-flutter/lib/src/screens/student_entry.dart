import 'dart:async';

import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../widgets/login_backdrop.dart';
import '../widgets/student_experience.dart';
import 'login_screen.dart';
import 'student_home_screen.dart';

/// مدخلُ التطبيق: شاشةُ الدخول من أوّل إطار، بلا افتتاحيةٍ ولا انتظار.
///
/// ── لماذا لا شاشةَ بداية ──
/// كانت هنا افتتاحيةٌ بفيلمٍ وشعارٍ وشخصيتين تطير، تبقى سبعَ ثوانٍ على الأقلّ
/// قبل أن يرى الطفلُ ما فتح التطبيقَ له. والآن يُفتح على شاشة الدخول فوراً.
///
/// ── والعائدُ بجلسته ──
/// من بقيت جلستُه على الجهاز يُقرأ ملفُّه من الخادم ويُفتح على لوحة البطاقات.
/// وفي أثناء القراءة خلفيةُ الدخول ودائرةُ انتظارٍ صغيرة — لا شعارٌ ولا
/// شخصيات — فإن لم تصحّ الجلسةُ فشاشةُ الدخول.
class StudentEntry extends StatefulWidget {
  const StudentEntry({
    required this.authService,
    required this.initializationError,
    required this.apiBaseUrl,
    super.key,
  });

  final StudentAuthService? authService;
  final String? initializationError;
  final String apiBaseUrl;

  @override
  State<StudentEntry> createState() => _StudentEntryState();
}

class _StudentEntryState extends State<StudentEntry> {
  /// جلسةٌ محفوظةٌ لم تنتهِ: يُقرأ ملفُّها قبل أن يُقرَّر إلى أين.
  late final bool _restoring = () {
    final session = widget.authService?.client.auth.currentSession;
    return session != null && !session.isExpired;
  }();

  @override
  void initState() {
    super.initState();
    if (_restoring) unawaited(_restore());
  }

  Future<void> _restore() async {
    StudentProfile? profile;
    try {
      profile = await widget.authService!.restoreActiveStudentSession();
    } catch (_) {
      profile = null;
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      StudentPageRoute<void>(
        builder: (_) => profile == null ? _login() : _hub(profile),
      ),
    );
  }

  Widget _login() => LoginScreen(
        authService: widget.authService,
        initializationError: widget.initializationError,
        apiBaseUrl: widget.apiBaseUrl,
      );

  Widget _hub(StudentProfile profile) => StudentHomeScreen(
        profile: profile,
        authService: widget.authService!,
        apiBaseUrl: widget.apiBaseUrl,
      );

  @override
  Widget build(BuildContext context) {
    if (!_restoring) return _login();
    return const Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          LoginBackdrop(),
          Center(child: CircularProgressIndicator(key: ValueKey('entry-restoring'))),
        ],
      ),
    );
  }
}
