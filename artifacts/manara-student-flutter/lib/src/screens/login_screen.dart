import 'package:flutter/material.dart';

import '../services/student_auth_service.dart';
import '../services/student_sound_service.dart';
import '../widgets/manara_logo.dart';
import '../widgets/student_experience.dart';
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
      backgroundColor: const Color(0xFF16241B),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF16241B), Color(0xFF23140C), Color(0xFF12291D)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      const StudentEmbossedShell(
                        color: Color(0xFFF6B93B),
                        depth: 5,
                        borderRadius: 16,
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: ManaraLogo(size: 28),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'مَنارة',
                          style: TextStyle(
                            color: Color(0xFFFFF3DE),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x26FFFFFF),
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        child: StudentSoundToggle(),
                      ),
                    ],
                  ),
                ),
                // The board image is placed via BoxFit.contain over the full
                // remaining area, and the form is placed in a second
                // Positioned computed from the *same* rect math — so it
                // always lands exactly on the green writing surface no
                // matter the window's aspect ratio, never on the wood frame
                // or the books/globe beside it.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final areaSize = constraints.biggest;
                      final imageRect = _containRect(areaSize, 1.0);
                      final boardRect = _boardRectFromImageRect(imageRect);
                      final formRect = boardRect.deflate(boardRect.width * 0.055);
                      return Stack(
                        children: [
                          Positioned.fromRect(
                            rect: imageRect,
                            child: Image.asset(
                              'assets/images/board_login_bg.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                          Positioned.fromRect(
                            rect: formRect,
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
                              boardHeight: formRect.height,
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The rect an image with [aspectRatio] (width / height) actually renders
/// into under `BoxFit.contain` inside [container] — used to place the
/// login form precisely on top of the chalkboard's green surface, wherever
/// that ends up once the (square) `board_login_bg.png` is fit into
/// whatever the current landscape window's aspect ratio happens to be.
Rect _containRect(Size container, double aspectRatio) {
  final containerAspect = container.width / container.height;
  double width;
  double height;
  if (containerAspect > aspectRatio) {
    height = container.height;
    width = height * aspectRatio;
  } else {
    width = container.width;
    height = width / aspectRatio;
  }
  return Rect.fromLTWH(
    (container.width - width) / 2,
    (container.height - height) / 2,
    width,
    height,
  );
}

/// The green writing surface's bounding box within `board_login_bg.png`,
/// as fractions of the whole (square) source image — measured directly
/// against the asset. Converts [imageRect] (where that image actually
/// renders on screen) into the matching screen rect for the board itself.
Rect _boardRectFromImageRect(Rect imageRect) {
  const left = 0.24;
  const top = 0.27;
  const right = 0.865;
  const bottom = 0.605;
  return Rect.fromLTRB(
    imageRect.left + left * imageRect.width,
    imageRect.top + top * imageRect.height,
    imageRect.left + right * imageRect.width,
    imageRect.top + bottom * imageRect.height,
  );
}

/// The login form itself, chalk-on-blackboard styled (translucent white
/// fields, warm gold 3D button) and sized so it fits inside whatever the
/// computed board rect turns out to be — [boardHeight] drives a single
/// scale factor for every font size/padding, and the whole thing scrolls
/// as a safety net rather than ever hard-overflowing a short board.
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
    required this.boardHeight,
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
  final double boardHeight;
  final ValueChanged<String> onUsernameChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTogglePassword;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final double scale = (boardHeight / 260).clamp(0.6, 1.3).toDouble();
    return SingleChildScrollView(
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'أهلاً بك يا بطل! 🎒',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 19 * scale,
                fontWeight: FontWeight.w900,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 2))],
              ),
            ),
            SizedBox(height: 9 * scale),
            _ChalkField(
              controller: usernameController,
              hint: 'اسم المستخدم',
              icon: Icons.person_rounded,
              scale: scale,
              hasError: showValidationFeedback && usernameController.text.trim().isEmpty,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onChanged: onUsernameChanged,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'اكتب اسم المستخدم' : null,
            ),
            SizedBox(height: 8 * scale),
            _ChalkField(
              controller: passwordController,
              hint: 'كلمة المرور',
              icon: Icons.lock_rounded,
              scale: scale,
              obscureText: hidePassword,
              hasError: showValidationFeedback && passwordController.text.isEmpty,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onChanged: onPasswordChanged,
              onFieldSubmitted: (_) => onSubmit(),
              validator: (value) => value == null || value.isEmpty ? 'اكتب كلمة المرور' : null,
              suffixIcon: IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 30 * scale, minHeight: 30 * scale),
                tooltip: hidePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                onPressed: onTogglePassword,
                icon: Icon(
                  hidePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: Colors.white70,
                  size: 16 * scale,
                ),
              ),
            ),
            if (errorMessage != null)
              Padding(
                padding: EdgeInsets.only(top: 6 * scale),
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFFCA5A5),
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (!isConfigured && initializationError != null)
              Padding(
                padding: EdgeInsets.only(top: 6 * scale),
                child: Text(
                  initializationError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFFCD34D),
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            SizedBox(height: 10 * scale),
            StudentPressScale(
              child: StudentEmbossedShell(
                color: loginSucceeded ? const Color(0xFF3B9C70) : const Color(0xFFEA8A3D),
                depth: 5 * scale,
                borderRadius: 14,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onSubmit,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isLoading && !loginSucceeded
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            width: 15 * scale,
                            height: 15 * scale,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            loginSucceeded ? Icons.celebration_rounded : Icons.arrow_back_rounded,
                            key: ValueKey(loginSucceeded),
                            size: 16 * scale,
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
                    minimumSize: Size.fromHeight(38 * scale),
                    backgroundColor:
                        loginSucceeded ? const Color(0xFF3B9C70) : const Color(0xFFEA8A3D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    textStyle: TextStyle(fontSize: 12.5 * scale, fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

/// A compact, semi-transparent "written in chalk" input field — a light
/// wash over the board's own green rather than an opaque card, so the
/// board texture keeps showing through around the text.
class _ChalkField extends StatelessWidget {
  const _ChalkField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.scale,
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
  final double scale;
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
    final borderColor = hasError ? const Color(0xFFFCA5A5) : Colors.white.withOpacity(0.45);
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      cursorColor: Colors.white,
      style: TextStyle(color: Colors.white, fontSize: 13 * scale, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.62),
          fontSize: 12.5 * scale,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.14),
        contentPadding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 9 * scale),
        prefixIcon: Icon(icon, color: Colors.white70, size: 15 * scale),
        prefixIconConstraints: BoxConstraints(minWidth: 28 * scale, minHeight: 0),
        suffixIcon: suffixIcon,
        suffixIconConstraints: BoxConstraints(minWidth: 28 * scale, minHeight: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor, width: 1.2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFFF6B93B), width: 2),
        ),
        errorStyle: const TextStyle(height: 0, fontSize: 0),
      ),
    );
  }
}
