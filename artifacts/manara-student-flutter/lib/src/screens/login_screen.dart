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
                // The (square) board image at full clarity/opacity — no
                // wash, no dimming — sized as large as the landscape
                // window allows. Everything else is positioned from this
                // exact same rect math, so it all always lines up with
                // wherever the board actually renders.
                final imageRect = _containRect(areaSize, 1.0);
                final boardRect = _boardRectFromImageRect(imageRect);
                final formRect = boardRect.deflate(boardRect.width * 0.055);
                final sideMargin = (areaSize.width - imageRect.width) / 2;
                final mascotSize = (sideMargin * 0.85).clamp(0.0, 150.0);
                final logoSize = (imageRect.width * 0.1).clamp(28.0, 46.0);

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
                    // The recolored mark alone (not ManaraLogo's own glow
                    // badge) — a clean gold silhouette, centered directly
                    // above the board, never overlapping it.
                    Positioned(
                      left: imageRect.center.dx - logoSize / 2,
                      top: (boardRect.top - logoSize - 10).clamp(4.0, double.infinity),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(Color(0xFFF6B93B), BlendMode.srcIn),
                        child: Image.asset(
                          'assets/images/manara-logo-mark-transparent.png',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
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
                    // The two heroes stand in the screen's own side margin
                    // beside the board — never over the logo above it or
                    // the fields on it.
                    if (mascotSize > 46)
                      Positioned(
                        right: 4,
                        bottom: 6,
                        child: StudentInteractiveMascot(size: mascotSize),
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

/// The rect an image with [aspectRatio] (width / height) actually renders
/// into under `BoxFit.contain` inside [container] — used to place every
/// other element precisely on top of the chalkboard's green surface,
/// wherever that ends up once the (square) `board_login_bg.png` is fit
/// into whatever the current landscape window's aspect ratio happens to be.
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

/// The login form, sitting directly on the chalkboard: a very light glassy
/// wash (not an opaque card) so the board keeps showing through clearly
/// behind the text, thin soft borders, and a chunky 3D orange button.
/// [boardHeight] drives a single scale factor for every font size/padding
/// so it always fits inside whatever the computed board rect turns out to
/// be, and the whole thing scrolls as a safety net rather than ever
/// hard-overflowing a short board.
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
            _GlassField(
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
            _GlassField(
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
                  color: Colors.white,
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
                color: loginSucceeded ? const Color(0xFF3B9C70) : const Color(0xFFFF9F1C),
                depth: (5.5 * scale).clamp(5.0, 6.0).toDouble(),
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
                        loginSucceeded ? const Color(0xFF3B9C70) : const Color(0xFFFF9F1C),
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

/// A very light glassy field — a soft 20%-white wash over the board's own
/// green, with a thin, soft border, so the chalkboard keeps showing
/// through clearly around and behind the text rather than being covered by
/// an opaque card.
class _GlassField extends StatelessWidget {
  const _GlassField({
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
    final borderColor = hasError ? const Color(0xFFFCA5A5) : Colors.white.withOpacity(0.55);
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
          color: Colors.white.withOpacity(0.7),
          fontSize: 12.5 * scale,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.20),
        contentPadding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 9 * scale),
        prefixIcon: Icon(icon, color: Colors.white, size: 15 * scale),
        prefixIconConstraints: BoxConstraints(minWidth: 28 * scale, minHeight: 0),
        suffixIcon: suffixIcon,
        suffixIconConstraints: BoxConstraints(minWidth: 28 * scale, minHeight: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor, width: 1.1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor, width: 1.1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFFFF9F1C), width: 1.8),
        ),
        errorStyle: const TextStyle(height: 0, fontSize: 0),
      ),
    );
  }
}
