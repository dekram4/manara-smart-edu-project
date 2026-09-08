import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/student_auth_service.dart';
import '../services/student_sound_service.dart';
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
      backgroundColor: const Color(0xFFEFF3F6),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE3EEF7), Color(0xFFF7F1E6), Color(0xFFE9F1F5)],
                ),
              ),
            ),
          ),
          // The chalkboard is now purely a faint watermark behind
          // everything — never a layout surface the form sits inside.
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: 0.2,
                  child: Image.asset(
                    'assets/images/board_login_bg.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 420, maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: ManaraLogo(size: 52)),
                      const SizedBox(height: 6),
                      const Center(
                        child: _FloatingHeroes(height: 200),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'أهلاً بك يا بطل! 🎒',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF22303A),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      StudentAnimatedCard(
                        child: _LoginCard(
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
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 12,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x14000000),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const StudentSoundToggle(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two sitting-heroes, floating gently, centered directly above the
/// login card — the app's real welcome to the student, not a decoration
/// tucked in a corner.
class _FloatingHeroes extends StatelessWidget {
  const _FloatingHeroes({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final mascot = StudentMascot(size: height / 1.05);
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return mascot;
    return mascot
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(begin: 0, end: -10, duration: 1900.ms, curve: Curves.easeInOut);
  }
}

/// The big, clearly-visible login card: solid white fields with embossed
/// borders and prominent icons, and a chunky 3D orange submit button.
class _LoginCard extends StatelessWidget {
  const _LoginCard({
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

  static const _ink = Color(0xFF22303A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7ECEF), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 28, offset: const Offset(0, 16)),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LoginField(
              controller: usernameController,
              hint: 'اسم المستخدم',
              icon: Icons.person_rounded,
              hasError: showValidationFeedback && usernameController.text.trim().isEmpty,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onChanged: onUsernameChanged,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'اكتب اسم المستخدم' : null,
            ),
            const SizedBox(height: 16),
            _LoginField(
              controller: passwordController,
              hint: 'كلمة المرور',
              icon: Icons.lock_rounded,
              obscureText: hidePassword,
              hasError: showValidationFeedback && passwordController.text.isEmpty,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onChanged: onPasswordChanged,
              onFieldSubmitted: (_) => onSubmit(),
              validator: (value) => value == null || value.isEmpty ? 'اكتب كلمة المرور' : null,
              suffixIcon: IconButton(
                tooltip: hidePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                onPressed: onTogglePassword,
                icon: Icon(
                  hidePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: _ink,
                ),
              ),
            ),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            if (!isConfigured && initializationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  initializationError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            const SizedBox(height: 22),
            StudentPressScale(
              child: StudentEmbossedShell(
                color: loginSucceeded ? const Color(0xFF3B9C70) : const Color(0xFFFF9F1C),
                depth: 6,
                borderRadius: 18,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onSubmit,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isLoading && !loginSucceeded
                        ? const SizedBox(
                            key: ValueKey('loading'),
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : Icon(
                            loginSucceeded ? Icons.celebration_rounded : Icons.arrow_back_rounded,
                            key: ValueKey(loginSucceeded),
                          ),
                  ),
                  label: Text(
                    loginSucceeded
                        ? 'أحسنت! لنبدأ'
                        : isLoading
                            ? 'جاري التحقق...'
                            : 'تسجيل الدخول',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor:
                        loginSucceeded ? const Color(0xFF3B9C70) : const Color(0xFFFF9F1C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'هذا التطبيق مخصص للطلاب فقط',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8A97A0), fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// A wide, unmistakably clear field: solid white, a thick embossed border,
/// and a prominent icon badge — sized generously for a child to tap
/// comfortably.
class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.hasError = false,
    this.textInputAction,
    this.autofillHints,
    this.suffixIcon,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final bool hasError;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;

  static const _ink = Color(0xFF22303A);

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1);
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      cursorColor: _ink,
      style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _ink.withOpacity(0.45), fontSize: 15, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: const BoxDecoration(color: Color(0xFFFFF0DC), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFFC2650A), size: 20),
          ),
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor, width: 2.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor, width: 2.4),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Color(0xFFFF9F1C), width: 2.8),
        ),
        errorStyle: const TextStyle(height: 0, fontSize: 0),
      ),
    );
  }
}
