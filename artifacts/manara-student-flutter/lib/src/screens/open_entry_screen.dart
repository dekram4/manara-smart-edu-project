import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/student_profile.dart';
import '../services/demo_mode.dart';
import '../services/open_edition_service.dart';
import '../services/saved_accounts.dart';
import '../services/student_auth_service.dart';
import '../services/student_sound_service.dart';
import '../widgets/student_experience.dart';
import 'academic_selection_screen.dart';

/// بابُ «النسخة المفتوحة»: زرٌّ واحد «الدخول إلى التطبيق»، بلا اسمٍ يُكتب.
///
/// ── حسابٌ تلقائيّ لكل جهاز ──
/// أوّلَ مرّة يُنشئ الخادمُ حساباً في صفّ المعلم الوحيد باسمٍ تلقائيّ
/// ([autoName]: «بطل الروضة»)، والتطبيقُ يحفظه في مخزنه المشفّر
/// ([SavedAccounts]). وكلَّ مرّةٍ بعدها يعود الزرُّ إلى الحساب نفسه — ووحده بلا
/// لمسة عند فتح التطبيق ([autoContinue]). ثم شاشةُ اختيار المسار والصف والمادة
/// والدرس، ومسارُ أيّ طالبٍ بعدها.
class OpenEntryScreen extends StatefulWidget {
  const OpenEntryScreen({
    required this.authService,
    required this.apiBaseUrl,
    this.initializationError,
    this.autoContinue = false,
    this.service,
    this.savedAccounts,
    super.key,
  });

  final StudentAuthService? authService;
  final String apiBaseUrl;
  final String? initializationError;

  /// يدخل وحده بالحساب المحفوظ — عند فتح التطبيق، لا بعد خروج.
  final bool autoContinue;

  /// للاختبار؛ وبلا قيمةٍ خادمُ [apiBaseUrl].
  final OpenEditionService? service;
  final SavedAccounts? savedAccounts;

  /// حساباتُ النسخة المفتوحة وحدها تبدأ بهذا (`lib/edition.ts` في الخادم).
  static const usernamePrefix = 'open_';

  /// الاسمُ التلقائيّ للطالب: لا يُطلب من الطفل أن يكتب شيئاً.
  static String get autoName => tr('open.autoName');

  @override
  State<OpenEntryScreen> createState() => _OpenEntryScreenState();
}

class _OpenEntryScreenState extends State<OpenEntryScreen> {
  late final OpenEditionService _service = widget.service ?? OpenEditionService(apiBaseUrl: widget.apiBaseUrl);
  SavedAccounts get _saved => widget.savedAccounts ?? SavedAccounts.instance;

  OpenEditionInfo? _info;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// حسابُ النسخة المفتوحة المحفوظُ على هذا الجهاز، إن كان.
  Future<SavedAccount?> _savedAccount() async {
    try {
      for (final account in await _saved.load()) {
        if (account.username.startsWith(OpenEntryScreen.usernamePrefix)) return account;
      }
    } catch (_) {
      // ‏المخزنُ المشفّر غيرُ متاح: يُنشأ حسابٌ جديد.
    }
    return null;
  }

  Future<void> _load() async {
    if (widget.autoContinue && widget.authService != null && await _savedAccount() != null) {
      unawaited(_enterApp());
    }
    final info = await _service.info();
    if (!mounted) return;
    setState(() => _info = info);
  }

  Future<void> _open(StudentProfile profile) async {
    DemoMode.enterFor(profile);
    StudentSoundService.instance.play(StudentSoundCue.loginSuccess);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      StudentPageRoute<void>(
        builder: (_) => AcademicSelectionScreen(
          profile: profile,
          authService: widget.authService!,
          apiBaseUrl: widget.apiBaseUrl,
        ),
      ),
    );
  }

  /// الحسابُ المحفوظ إن كان ودخل، وإلا حسابٌ تلقائيٌّ جديد يُحفظ.
  Future<StudentProfile> _signIn(StudentAuthService auth) async {
    final account = await _savedAccount();
    if (account != null) {
      final password = await _saved.passwordFor(account.username);
      if (password != null) {
        try {
          return await auth.signIn(username: account.username, password: password);
        } on StudentAuthException {
          // ‏حُذف الحسابُ من الخادم (أو تغيّر): يُنسى ويُنشأ غيرُه، لا أن يبقى الطفلُ عالقاً.
        }
      }
      try {
        await _saved.remove(account.username);
      } catch (_) {}
    }

    final info = _info;
    final credentials = await _service.join(
      name: OpenEntryScreen.autoName,
      grade: (info != null && info.grades.isNotEmpty) ? info.grades.first : null,
      fallbackError: tr('open.joinFailed'),
    );
    final profile = await auth.signIn(username: credentials.username, password: credentials.password);
    try {
      await _saved.save(
        SavedAccount(username: credentials.username, displayName: profile.name, appearance: profile.appearance),
        credentials.password,
      );
    } catch (_) {
      // ‏لا مخزنَ مشفّراً: يدخل الآن، ويُنشأ له حسابٌ آخر في المرّة القادمة.
    }
    return profile;
  }

  Future<void> _enterApp() async {
    if (_busy) return;
    final auth = widget.authService;
    if (auth == null) {
      setState(() => _error = widget.initializationError ?? tr('open.joinFailed'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _open(await _signIn(auth));
    } on OpenEditionException catch (error) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      if (mounted) setState(() => _error = error.message);
    } on StudentAuthException catch (error) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final teacher = info?.teacherName;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFFF59E0B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  key: const ValueKey('open-entry'),
                  elevation: 10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/images/manara_logo_full.png',
                          height: 110,
                          errorBuilder: (_, __, ___) => const Text('🌟', textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          tr('open.welcome'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF4C1D95)),
                        ),
                        if (teacher != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            trf('open.withTeacher', {'name': teacher}),
                            key: const ValueKey('open-teacher-name'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9)),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            key: const ValueKey('open-error'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700),
                          ),
                        ],
                        if (info != null && !info.ready) ...[
                          const SizedBox(height: 8),
                          Text(
                            tr('open.notReady'),
                            key: const ValueKey('open-not-ready'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF92400E)),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          key: const ValueKey('open-start'),
                          onPressed: _busy ? null : _enterApp,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(64),
                            backgroundColor: const Color(0xFF7C3AED),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                          icon: _busy
                              ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                              : const Icon(Icons.rocket_launch_rounded, size: 28),
                          label: Text(tr('open.enter')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
