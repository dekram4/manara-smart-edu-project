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
import '../widgets/voice_mic_button.dart';
import 'academic_selection_screen.dart';

/// بابُ «النسخة المفتوحة»: الطالبُ يكتب اسمه (أو يقوله) فيدخل.
///
/// ── بلا اسم مستخدمٍ ولا كلمة مرور ──
/// الخادمُ يُنشئ له حساباً في صفّ المعلم الوحيد، والتطبيقُ يحفظه في مخزنه
/// المشفّر ([SavedAccounts]) فيعود إليه في كل فتحٍ بلمسةٍ — أو وحده إن كان
/// على الجهاز حسابٌ واحد ([autoContinue]). وما بعد الدخول مسارُ أيّ طالب:
/// الشاشاتُ والصوتُ والألعابُ والتحدّي كما هي.
class OpenEntryScreen extends StatefulWidget {
  const OpenEntryScreen({
    required this.authService,
    required this.apiBaseUrl,
    this.initializationError,
    this.autoContinue = false,
    this.service,
    this.savedAccounts,
    this.voiceListen,
    super.key,
  });

  final StudentAuthService? authService;
  final String apiBaseUrl;
  final String? initializationError;

  /// يدخل وحده بالحساب المحفوظ إن كان واحداً — عند فتح التطبيق، لا بعد خروج.
  final bool autoContinue;

  /// للاختبار؛ وبلا قيمةٍ خادمُ [apiBaseUrl].
  final OpenEditionService? service;
  final SavedAccounts? savedAccounts;
  final VoiceListen? voiceListen;

  /// حساباتُ النسخة المفتوحة وحدها تبدأ بهذا (`lib/edition.ts` في الخادم).
  static const usernamePrefix = 'open_';

  @override
  State<OpenEntryScreen> createState() => _OpenEntryScreenState();
}

class _OpenEntryScreenState extends State<OpenEntryScreen> {
  final _name = TextEditingController();
  late final OpenEditionService _service = widget.service ?? OpenEditionService(apiBaseUrl: widget.apiBaseUrl);
  SavedAccounts get _saved => widget.savedAccounts ?? SavedAccounts.instance;

  OpenEditionInfo? _info;
  List<SavedAccount> _accounts = const [];
  String? _grade;
  String _gender = 'male';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    List<SavedAccount> accounts = const [];
    try {
      accounts = [
        for (final account in await _saved.load())
          if (account.username.startsWith(OpenEntryScreen.usernamePrefix)) account,
      ];
    } catch (_) {
      // ‏المخزنُ المشفّر غيرُ متاح: يُسجَّل الطالبُ من جديد.
    }
    if (!mounted) return;
    setState(() => _accounts = accounts);
    if (widget.autoContinue && accounts.length == 1 && widget.authService != null) {
      unawaited(_continueAs(accounts.single));
    }
    final info = await _service.info();
    if (!mounted) return;
    setState(() {
      _info = info;
      _grade ??= info.grades.isNotEmpty ? info.grades.first : null;
    });
  }

  Future<void> _enter(StudentProfile profile) async {
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

  Future<void> _continueAs(SavedAccount account) async {
    final auth = widget.authService;
    if (auth == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final password = await _saved.passwordFor(account.username);
      if (password == null) throw StudentAuthException(tr('open.accountMissing'));
      final profile = await auth.signIn(username: account.username, password: password);
      await _enter(profile);
    } on StudentAuthException catch (error) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final auth = widget.authService;
    if (auth == null) {
      setState(() => _error = widget.initializationError ?? tr('open.joinFailed'));
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      setState(() => _error = tr('open.nameRequired'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final credentials = await _service.join(
        name: name,
        grade: _grade,
        gender: _gender,
        fallbackError: tr('open.joinFailed'),
      );
      final profile = await auth.signIn(username: credentials.username, password: credentials.password);
      try {
        await _saved.save(
          SavedAccount(username: credentials.username, displayName: profile.name, appearance: profile.appearance),
          credentials.password,
        );
      } catch (_) {
        // ‏لا مخزنَ مشفّراً: يدخل الآن، ويُسجَّل من جديد في المرّة القادمة.
      }
      await _enter(profile);
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
    final grades = info?.grades ?? const <String>[];
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
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/images/manara_logo_full.png',
                          height: 96,
                          errorBuilder: (_, __, ___) => const Text('🌟', textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr('open.welcome'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF4C1D95)),
                        ),
                        if (teacher != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            trf('open.withTeacher', {'name': teacher}),
                            key: const ValueKey('open-teacher-name'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9)),
                          ),
                        ],
                        if (_accounts.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(tr('open.continueAs'), style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          for (final account in _accounts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: FilledButton.tonalIcon(
                                key: ValueKey('open-continue-${account.username}'),
                                onPressed: _busy ? null : () => _continueAs(account),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: Text(account.displayName, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          const Divider(height: 24),
                          Text(tr('open.newStudent'), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey('open-name'),
                                controller: _name,
                                enabled: !_busy,
                                maxLength: 40,
                                textInputAction: TextInputAction.go,
                                onSubmitted: (_) => _start(),
                                decoration: InputDecoration(
                                  labelText: tr('open.nameLabel'),
                                  hintText: tr('open.nameHint'),
                                  counterText: '',
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            VoiceMicButton(
                              key: const ValueKey('open-name-mic'),
                              listen: widget.voiceListen,
                              size: 52,
                              onHeard: (heard) async {
                                final words = heard.trim();
                                if (words.isEmpty || !mounted) return;
                                setState(() => _name.text = words);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          key: const ValueKey('open-gender'),
                          segments: [
                            ButtonSegment(value: 'male', label: Text(tr('open.boy')), icon: const Text('👦')),
                            ButtonSegment(value: 'female', label: Text(tr('open.girl')), icon: const Text('👧')),
                          ],
                          selected: {_gender},
                          onSelectionChanged: _busy ? null : (value) => setState(() => _gender = value.first),
                        ),
                        if (grades.length > 1) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: const ValueKey('open-grade'),
                            initialValue: _grade,
                            decoration: InputDecoration(
                              labelText: tr('open.grade'),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            items: [for (final g in grades) DropdownMenuItem(value: g, child: Text(g))],
                            onChanged: _busy ? null : (value) => setState(() => _grade = value),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
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
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const ValueKey('open-start'),
                          onPressed: _busy ? null : _start,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            backgroundColor: const Color(0xFF7C3AED),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          child: _busy
                              ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                              : Text(tr('open.start')),
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
