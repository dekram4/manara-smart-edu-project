import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/student_auth_service.dart';
import '../services/student_sound_service.dart';
import '../widgets/student_experience.dart';
import '../widgets/manara_logo.dart';
import 'academic_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.authService,
    required this.initializationError,
    required this.apiBaseUrl,
    super.key,
  });

  final StudentAuthService? authService;
  final String? initializationError;
  final String apiBaseUrl;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _hidePassword = true;
  bool _showValidationFeedback = false;
  bool _loginSucceeded = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      setState(() => _showValidationFeedback = true);
      return;
    }
    if (widget.authService == null) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      setState(() => _errorMessage = widget.initializationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _loginSucceeded = false;
      _showValidationFeedback = false;
      _errorMessage = null;
    });

    try {
      final student = await widget.authService!.signIn(
        username: _usernameController.text,
        password: _passwordController.text,
      );
      StudentSoundService.instance.play(StudentSoundCue.loginSuccess);
      if (!mounted) return;
      setState(() => _loginSucceeded = true);
      await Future<void>.delayed(const Duration(milliseconds: 360));
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        StudentPageRoute<void>(
          builder: (_) => AcademicSelectionScreen(
            profile: student,
            authService: widget.authService!,
            apiBaseUrl: widget.apiBaseUrl,
          ),
        ),
      );
    } on StudentAuthException catch (error) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      if (mounted) {
        setState(() {
          _loginSucceeded = false;
          _errorMessage = error.message;
        });
      }
    } catch (_) {
      StudentSoundService.instance.play(StudentSoundCue.warning);
      if (mounted) {
        setState(() {
          _loginSucceeded = false;
          _errorMessage = 'تعذر إكمال تسجيل الدخول. حاول مرة أخرى.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = widget.authService != null;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: StudentLearningWorld()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xB3FFFCF3),
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          child: StudentSoundToggle(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 720;
                          final credentials = _LoginCredentials(
                            formKey: _formKey,
                            isConfigured: isConfigured,
                            initializationError: widget.initializationError,
                            usernameController: _usernameController,
                            passwordController: _passwordController,
                            hidePassword: _hidePassword,
                            isLoading: _isLoading,
                            loginSucceeded: _loginSucceeded,
                            showValidationFeedback: _showValidationFeedback,
                            errorMessage: _errorMessage,
                            onUsernameChanged: (_) {
                              if (_showValidationFeedback) {
                                setState(() => _showValidationFeedback = false);
                              }
                            },
                            onPasswordChanged: (_) {
                              if (_showValidationFeedback) {
                                setState(() => _showValidationFeedback = false);
                              }
                            },
                            onTogglePassword: () {
                              StudentSoundService.instance.play(
                                StudentSoundCue.navigation,
                              );
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            onSubmit: _submit,
                          );

                          final content = isWide
                              ? Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: SizedBox(
                                    height: 590,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        const Expanded(
                                          flex: 9,
                                          child: _LoginStoryPanel(compact: false),
                                        ),
                                        Expanded(
                                          flex: 11,
                                          child: Directionality(
                                            textDirection: TextDirection.rtl,
                                            child: credentials,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _LoginStoryPanel(compact: true),
                                    credentials,
                                  ],
                                );

                          final shell = DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFDF7),
                              borderRadius: BorderRadius.circular(34),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.9),
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x2D183047),
                                  blurRadius: 40,
                                  offset: Offset(0, 22),
                                ),
                                BoxShadow(
                                  color: Color(0x1F147D83),
                                  blurRadius: 4,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: content,
                            ),
                          );

                          if (reduceMotion) return shell;
                          return shell
                              .animate()
                              .fadeIn(duration: 420.ms)
                              .slideY(
                                begin: 0.035,
                                end: 0,
                                duration: 520.ms,
                                curve: Curves.easeOutCubic,
                              );
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'مساحة مخصصة للطلاب • كل خطوة تقرّبك من إنجاز جديد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF647A7B),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginStoryPanel extends StatelessWidget {
  const _LoginStoryPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = compact ? 24.0 : 36.0;
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 260 : 590),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        compact ? 22 : 34,
        horizontalPadding,
        compact ? 18 : 34,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF183B50), Color(0xFF174B5A), Color(0xFF0E3248)],
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            bottom: -96,
            start: -92,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF75C8C5).withOpacity(0.25),
                  width: 24,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 86,
            end: -70,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF1C664).withOpacity(0.10),
              ),
            ),
          ),
          Positioned.fill(
            child: StudentSubjectOrbit(compact: compact),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ManaraLogo(size: 48),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'منارة المعرفة',
                          style: TextStyle(
                            color: Color(0xFFFFF9E9),
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'تعليم ذكي، معرفة، ومستقبل مشرق',
                          style: TextStyle(
                            color: Color(0xFFAEDBD6),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!compact) const Spacer(),
              const SizedBox(height: 20),
              const Text(
                'بوابتك تبدأ من هنا',
                style: TextStyle(
                  color: Color(0xFF9BE0D8),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                compact ? 'افتح بابك للتعلّم' : 'افتح بابك\nللتعلّم',
                style: const TextStyle(
                  color: Color(0xFFFFF9E9),
                  fontSize: 37,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'كل يوم في منارة يحمل سؤالًا جديدًا ومهارة تجعلك أقوى.',
                style: TextStyle(
                  color: Color(0xFFC5DEDA),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.6,
                ),
              ),
              if (!compact) const Spacer(),
              Align(
                alignment: AlignmentDirectional.center,
                child: StudentCompanion(size: compact ? 132 : 176),
              ),
              if (!compact) const SizedBox(height: 4),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginCredentials extends StatelessWidget {
  const _LoginCredentials({
    required this.formKey,
    required this.isConfigured,
    required this.initializationError,
    required this.usernameController,
    required this.passwordController,
    required this.hidePassword,
    required this.isLoading,
    required this.loginSucceeded,
    required this.showValidationFeedback,
    required this.errorMessage,
    required this.onUsernameChanged,
    required this.onPasswordChanged,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final bool isConfigured;
  final String? initializationError;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool hidePassword;
  final bool isLoading;
  final bool loginSucceeded;
  final bool showValidationFeedback;
  final String? errorMessage;
  final ValueChanged<String> onUsernameChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTogglePassword;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 138,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4EF),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 9, color: Color(0xFFE9AC3E)),
                  SizedBox(width: 6),
                  Text(
                    'دخول الطالب',
                    style: TextStyle(
                      color: Color(0xFF147D83),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'أهلًا يا بطل!',
              style: TextStyle(
                color: Color(0xFF183047),
                fontSize: 31,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'سجّل دخولك إلى بوابة الطالب واستعد لرحلتك.',
              style: TextStyle(
                color: Color(0xFF6C7D81),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 28),
            StudentFocusGlow(
              hasError:
                  showValidationFeedback && usernameController.text.trim().isEmpty,
              child: TextFormField(
                controller: usernameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                onChanged: onUsernameChanged,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
                  hintText: 'اكتب اسم المستخدم',
                  prefixIcon: Icon(Icons.person_rounded, color: Color(0xFF147D83)),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'اكتب اسم المستخدم'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            StudentFocusGlow(
              hasError: showValidationFeedback && passwordController.text.isEmpty,
              child: TextFormField(
                controller: passwordController,
                obscureText: hidePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onSubmit(),
                autofillHints: const [AutofillHints.password],
                onChanged: onPasswordChanged,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  hintText: 'اكتب كلمة المرور',
                  prefixIcon: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFF147D83),
                  ),
                  suffixIcon: IconButton(
                    tooltip: hidePassword
                        ? 'إظهار كلمة المرور'
                        : 'إخفاء كلمة المرور',
                    onPressed: onTogglePassword,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        hidePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        key: ValueKey(hidePassword),
                      ),
                    ),
                  ),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'اكتب كلمة المرور' : null,
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 14),
              StudentEntrance(
                offset: 0.02,
                child: _LoginFeedback(
                  message: errorMessage!,
                  color: const Color(0xFF9F1239),
                  surface: const Color(0xFFFFF1F2),
                  border: const Color(0xFFFDA4AF),
                  icon: Icons.info_outline_rounded,
                ),
              ),
            ],
            if (!isConfigured && initializationError != null) ...[
              const SizedBox(height: 12),
              _LoginFeedback(
                message: initializationError!,
                color: const Color(0xFF92400E),
                surface: const Color(0xFFFFFBEB),
                border: const Color(0xFFFCD34D),
                icon: Icons.cloud_off_rounded,
              ),
            ],
            const SizedBox(height: 24),
            StudentPressScale(
              child: FilledButton.icon(
                onPressed: isLoading ? null : onSubmit,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: isLoading && !loginSucceeded
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          loginSucceeded
                              ? Icons.celebration_rounded
                              : Icons.arrow_back_rounded,
                          key: ValueKey(loginSucceeded),
                        ),
                ),
                label: Text(
                  loginSucceeded
                      ? 'أحسنت! لنبدأ'
                      : isLoading
                          ? 'جاري التحقق...'
                          : 'ابدأ رحلة التعلّم',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(58),
                  backgroundColor: loginSucceeded
                      ? const Color(0xFF3B9C70)
                      : const Color(0xFF147D83),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(19),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'هذا التطبيق مخصص للطلاب فقط',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF879694),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginFeedback extends StatelessWidget {
  const _LoginFeedback({
    required this.message,
    required this.color,
    required this.surface,
    required this.border,
    required this.icon,
  });

  final String message;
  final Color color;
  final Color surface;
  final Color border;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}