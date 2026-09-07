import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/student_auth_service.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/manara_logo.dart';
import '../widgets/student_experience.dart';
import '../widgets/student_mascot.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFF2E1065),
      body: Stack(
        children: [
          const Positioned.fill(child: _LoginGameBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const ManaraLogo(size: 44),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مَنارة',
                                  style: TextStyle(
                                    color: Color(0xFFFFF9E9),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'MANARA SMART EDU',
                                  textDirection: TextDirection.ltr,
                                  style: TextStyle(
                                    color: Color(0xFFBFE8FF),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x33FFFFFF),
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                            ),
                            child: StudentSoundToggle(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      StudentEntrance(
                        child: Column(
                          children: [
                            StudentInteractiveMascot(
                              size: 168,
                              outfitColor: const Color(0xFF16A085),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'أهلًا يا بطل! 👋',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFFFF9E9),
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'سجّل دخولك إلى بوابة الطالب واستعد لرحلتك',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFDCD3F7),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      StudentAnimatedCard(
                        child: Student3DCard(
                          maxTilt: 0.045,
                          child: _LoginCredentialsCard(
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
                              StudentSoundService.instance.playTap();
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            onSubmit: _submit,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'مساحة مخصصة للطلاب • كل خطوة تقرّبك من إنجاز جديد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFC9BEF0),
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

/// A rich, colorful game-menu backdrop — a warm diagonal gradient with a few
/// large, soft glowing color blobs breathing slowly, instead of the flat
/// pale background and scattered empty circles/icon chips this screen used
/// to have.
class _LoginGameBackground extends StatelessWidget {
  const _LoginGameBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2E1065),
                Color(0xFF4F46E5),
                Color(0xFF0B8693),
              ],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -70,
          child: _GlowBlob(size: 260, color: const Color(0xFFF6C95D), delay: 0.ms),
        ),
        Positioned(
          bottom: -110,
          left: -90,
          child: _GlowBlob(size: 300, color: const Color(0xFFEC4899), delay: 600.ms),
        ),
        Positioned(
          top: 260,
          left: -70,
          child: _GlowBlob(size: 190, color: const Color(0xFF5EEAD4), delay: 300.ms),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color, required this.delay});

  final double size;
  final Color color;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final blob = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.30)),
    );
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return IgnorePointer(child: blob);
    }
    return IgnorePointer(
      child: blob
          .animate(delay: delay, onPlay: (controller) => controller.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.08, duration: 4200.ms, curve: Curves.easeInOut)
          .fade(begin: 0.75, end: 1, duration: 4200.ms),
    );
  }
}

class _LoginCredentialsCard extends StatelessWidget {
  const _LoginCredentialsCard({
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
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF5),
        borderRadius: StudentShapes.playfulCard,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StudentFocusGlow(
              hasError:
                  showValidationFeedback && usernameController.text.trim().isEmpty,
              borderRadius: BorderRadius.circular(30),
              child: TextFormField(
                controller: usernameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                onChanged: onUsernameChanged,
                decoration: _pillDecoration(
                  label: 'اسم المستخدم',
                  hint: 'اكتب اسم المستخدم',
                  icon: Icons.person_rounded,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'اكتب اسم المستخدم'
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            StudentFocusGlow(
              hasError: showValidationFeedback && passwordController.text.isEmpty,
              borderRadius: BorderRadius.circular(30),
              child: TextFormField(
                controller: passwordController,
                obscureText: hidePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onSubmit(),
                autofillHints: const [AutofillHints.password],
                onChanged: onPasswordChanged,
                decoration: _pillDecoration(
                  label: 'كلمة المرور',
                  hint: 'اكتب كلمة المرور',
                  icon: Icons.lock_rounded,
                  suffixIcon: IconButton(
                    tooltip: hidePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                    onPressed: onTogglePassword,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        hidePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        key: ValueKey(hidePassword),
                        color: const Color(0xFFB45309),
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
            const SizedBox(height: 22),
            StudentPressScale(
              child: StudentEmbossedShell(
                color: loginSucceeded ? const Color(0xFF3B9C70) : const Color(0xFF147D83),
                borderRadius: 26,
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
                    backgroundColor:
                        loginSucceeded ? const Color(0xFF3B9C70) : const Color(0xFF147D83),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'هذا التطبيق مخصص للطلاب فقط',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9A8F86),
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

/// A warm, soft-rounded "gaming pill" input decoration — no sharp corners,
/// a cream fill, and a circular icon badge instead of a bare Material icon.
InputDecoration _pillDecoration({
  required String label,
  required String hint,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFFFF3DE),
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    prefixIcon: Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(color: Color(0xFFFFE0A6), shape: BoxShape.circle),
        child: Icon(icon, color: const Color(0xFFB45309), size: 18),
      ),
    ),
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: Color(0xFFFFDFA0), width: 2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2.5),
    ),
  );
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
