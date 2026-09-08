import 'package:flutter/material.dart';

import '../services/student_auth_service.dart';
import '../services/student_sound_service.dart';
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
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final areaSize = constraints.biggest;
                // A fixed, literal size — screen height * 0.85 — capped so
                // it never exceeds the available width either. The (square)
                // board is centered in the remaining space.
                final boardSize = (areaSize.height * 0.95).clamp(0.0, areaSize.width * 0.92);
                final imageRect = Rect.fromCenter(
                  center: areaSize.center(Offset.zero),
                  width: boardSize,
                  height: boardSize,
                );
                final boardRect = _boardRectFromImageRect(imageRect);
                const logoSize = 88.0;
                const mascotSize = 140.0;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fromRect(
                      rect: imageRect,
                      child: Image.asset(
                        'assets/images/board_login_bg.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    // The mark in its true official colors (no tint) —
                    // just a soft drop shadow behind its circular
                    // silhouette — centered directly above the board.
                    Positioned(
                      left: imageRect.center.dx - logoSize / 2,
                      top: (boardRect.top - logoSize - 8).clamp(0.0, double.infinity),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 12, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/manara-logo-mark-transparent.png',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    // The form is centered *inside* the green rect at a
                    // hard-capped 320px width — never stretched to fill
                    // it — so it can never reach the wooden frame even if
                    // the green rect's measured bounds are slightly off.
                    Positioned.fromRect(
                      rect: boardRect,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 320,
                            maxHeight: boardRect.height - 20,
                          ),
                          child: _BoardLoginForm(
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
                    ),
                    // The two heroes now sit centered at the foot of the
                    // easel, as if in front of the classroom board —
                    // overlapping the bottom of the board image slightly
                    // (where its own stand is) rather than needing extra
                    // screen space below it, which a board this large
                    // rarely has.
                    Positioned(
                      left: imageRect.center.dx - mascotSize / 2,
                      top: imageRect.bottom - mascotSize * 0.62,
                      child: const StudentInteractiveMascot(size: mascotSize),
                    ),
                    Positioned(
                      top: 4,
                      right: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x14000000),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const StudentSoundToggle(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The green writing surface's bounding box within `board_login_bg.png`,
/// as fractions of the whole (square) source image — measured directly
/// against the asset. Converts [imageRect] (where that image actually
/// renders on screen) into the matching screen rect for the board itself.
Rect _boardRectFromImageRect(Rect imageRect) {
  const left = 0.230;
  const top = 0.2725;
  const right = 0.8675;
  // Kept a bit shy of the measured 0.605 on purpose — a small safety
  // margin so the form's content never reaches the wooden frame even
  // where it's tallest (the button), confirmed against a live screenshot.
  const bottom = 0.585;
  return Rect.fromLTRB(
    imageRect.left + left * imageRect.width,
    imageRect.top + top * imageRect.height,
    imageRect.left + right * imageRect.width,
    imageRect.top + bottom * imageRect.height,
  );
}

/// The login form: solid, unmistakably readable white fields (never
/// translucent) with dark text/icons, and a chunky 3D orange button — all
/// fixed at the literal sizes specified (340px wide, 48px button), so it
/// reads clearly regardless of the mottled green board behind it.
class _BoardLoginForm extends StatelessWidget {
  const _BoardLoginForm({
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
    return SingleChildScrollView(
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'أهلاً بك يا بطل! 🎒',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 2))],
              ),
            ),
            const SizedBox(height: 6),
            _SolidField(
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
            const SizedBox(height: 6),
            _SolidField(
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
                  color: Colors.black54,
                  size: 18,
                ),
              ),
            ),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            if (!isConfigured && initializationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  initializationError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            const SizedBox(height: 8),
            StudentPressScale(
              child: StudentEmbossedShell(
                color: loginSucceeded ? const Color(0xFF3B9C70) : const Color(0xFFFF9F1C),
                depth: 4,
                borderRadius: 24,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onSubmit,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isLoading && !loginSucceeded
                        ? const SizedBox(
                            key: ValueKey('loading'),
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
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
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor:
                        loginSucceeded ? const Color(0xFF3B9C70) : const Color(0xFFFF9F1C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A solid, unmistakably-white field with a light gray border and a soft
/// drop shadow — dark, clearly-readable text and a colored icon badge, so
/// it never blends into the mottled green board behind it.
class _SolidField extends StatelessWidget {
  const _SolidField({
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

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError ? const Color(0xFFDC2626) : const Color(0xFFD8DEE3);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        cursorColor: Colors.black54,
        style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black54, fontSize: 13.5, fontWeight: FontWeight.w600),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFFFFE9CC), shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFFC2650A), size: 16),
            ),
          ),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: borderColor, width: 1.3),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: borderColor, width: 1.3),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFFFF9F1C), width: 2),
          ),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
      ),
    );
  }
}
