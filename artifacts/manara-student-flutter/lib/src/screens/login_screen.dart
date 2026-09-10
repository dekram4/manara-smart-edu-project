import 'dart:math' as math;


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
      // The scene is sized to the window, so letting the soft keyboard
      // shrink that window would shrink the board with it. Overlaying the
      // keyboard instead keeps the board steady on phones and tablets.
      resizeToAvoidBottomInset: false,
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

                // The board asset is a 3000x3000 square, but the drawing
                // inside it is not: tracing its alpha shows the artwork
                // spans x 0.025-0.967 and y 0.220-0.859 of that canvas, so
                // 36% of the square's height is transparent padding.
                // Sizing the *square* to 92% of the screen — which is what
                // this did — therefore drew a board only 59% as tall as the
                // screen, surrounded by the empty margins that were
                // reported. Everything below sizes the drawing itself.
                final artW = _artRightF - _artLeftF; // 0.942

                // The composition is a single centred stack in every
                // orientation: logo above the frame, board, heroes at the
                // easel's foot. So the board is grown until that whole
                // stack fills the screen — not until the board alone does.
                //
                // The stack runs from the top of the logo block down to the
                // bottom of the drawing, which is
                //   logoBlock + gap + (artBottom - frameTop) * boardSize
                // and `frameTop` (0.235) is just below the drawing's own top
                // (0.220), so that span is 0.624 of the square.
                const stackSpan = _artBottomF - _frameTopFraction; // 0.624
                const logoNameGap = 2.0;
                const logoGap = 6.0;

                // logoBlock depends on boardSize and boardSize depends on
                // logoBlock, and both are clamped — so solve it by
                // iterating a few times rather than algebraically, which
                // the clamps would make wrong at the extremes.
                double boardSize = math.min(
                  areaSize.height * 0.97 / (stackSpan + 0.19),
                  areaSize.width * 0.96 / artW,
                );
                double logoSize = 0;
                double logoNameHeight = 0;
                double logoBlockHeight = 0;
                for (var pass = 0; pass < 3; pass++) {
                  logoSize = (boardSize * 0.145).clamp(44.0, 130.0).toDouble();
                  logoNameHeight =
                      (boardSize * 0.045).clamp(14.0, 34.0).toDouble();
                  logoBlockHeight = logoSize + logoNameGap + logoNameHeight;
                  boardSize = math.min(
                    (areaSize.height * 0.97 - logoBlockHeight - logoGap) /
                        stackSpan,
                    areaSize.width * 0.96 / artW,
                  );
                }
                boardSize = math.max(boardSize, 1.0);

                final artworkWidth = boardSize * artW;
                // Centre the whole stack vertically, and the drawing
                // horizontally — the square's own padding is lopsided
                // (22% above the drawing, 14% below), so centring the
                // square would not centre what the student sees.
                final stackHeight =
                    logoBlockHeight + logoGap + stackSpan * boardSize;
                final stackTop = (areaSize.height - stackHeight) / 2;
                final imageRect = Rect.fromLTWH(
                  (areaSize.width - artworkWidth) / 2 - _artLeftF * boardSize,
                  stackTop +
                      logoBlockHeight +
                      logoGap -
                      _frameTopFraction * boardSize,
                  boardSize,
                  boardSize,
                );
                final boardRect = _boardRectFromImageRect(imageRect);

                final mascotSize =
                    (boardSize * 0.212).clamp(60.0, 200.0).toDouble();
                final brandWidth = math.min(areaSize.width * 0.92, 380.0);

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
                    // The mark, recoloured to a single deep teal so it
                    // reads crisply on the light backdrop instead of the
                    // washed-out original gradient, with the app's full
                    // name beneath it in the same colour. The pair rests
                    // on top of the board's wooden frame, lifted by a soft
                    // white glow.
                    // Centred directly above the board's top frame, in
                    // every orientation. The vertical budget above already
                    // reserved this block's height, so it always has its
                    // band and never needs to be moved aside.
                    Positioned(
                      left: imageRect.center.dx - brandWidth / 2,
                      width: brandWidth,
                      top: imageRect.top +
                          _frameTopFraction * imageRect.height -
                          logoBlockHeight -
                          logoGap,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DecoratedBox(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.white, blurRadius: 18, spreadRadius: 2),
                                BoxShadow(color: Colors.white70, blurRadius: 30, spreadRadius: 6),
                              ],
                            ),
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.mode(_brandInk, BlendMode.srcIn),
                              child: Image.asset(
                                'assets/images/manara-logo-mark-transparent.png',
                                width: logoSize,
                                height: logoSize,
                                fit: BoxFit.contain,
                                errorBuilder: _emptyImageFallback,
                              ),
                            ),
                          ),
                          const SizedBox(height: logoNameGap),
                          SizedBox(
                            height: logoNameHeight,
                            // Scales itself down rather than overflowing if
                            // the window ever gets narrow.
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'منارة المعرفة التعليمية',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _brandInk,
                                  fontSize: 21,
                                  height: 1.15,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(color: Colors.white, blurRadius: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // The form block is centered on the green area and can
                    // never be wider than that area actually is — see
                    // formWidth above.
                    Positioned.fromRect(
                      rect: boardRect,
                      child: Padding(
                        // A margin proportional to the green area, so the
                        // block keeps the same visual inset at any size.
                        padding: EdgeInsets.symmetric(
                          horizontal: boardRect.width * 0.05,
                          vertical: boardRect.height * 0.06,
                        ),
                        // The block is authored once at its 280px design
                        // size and then scaled to whatever the green area
                        // actually is. That is what removes the scroll
                        // view: the form can no longer be taller than its
                        // box, so there is nothing left to scroll, and it
                        // cannot overflow at any resolution either.
                        // The block is authored at a width taken from the
                        // green area itself — 70% of it, bounded so it
                        // neither crowds the wooden frame on a big tablet
                        // nor shrinks to a ribbon on a phone. It used to be
                        // a flat 280 regardless, which looked stranded now
                        // that the board is much larger.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: (boardRect.width * 0.70)
                                .clamp(240.0, 340.0)
                                .toDouble(),
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
                    ),
                    // The heroes sit right at the foot of the easel. They
                    // are anchored to where the *artwork* actually ends
                    // (its legs/books line), NOT to the square PNG's
                    // bottom edge — that edge is ~20% transparent padding,
                    // which is what pushed them far down the screen.
                    Positioned(
                      // Centred under the easel in every orientation,
                      // nudged left of the image's centre so the pair reads
                      // as centred under the *board* itself — the drawn
                      // board leans left of the square PNG's midpoint.
                      left: imageRect.center.dx -
                          mascotSize / 2 -
                          imageRect.width * _mascotLeftNudgeFraction,
                      top: imageRect.top +
                          _artworkBottomFraction * imageRect.height -
                          mascotSize,
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

/// The green writing surface's bounding box within `board_login_bg.png`,
/// as fractions of the whole (square) source image — measured directly
/// against the asset. Converts [imageRect] (where that image actually
/// renders on screen) into the matching screen rect for the board itself.
/// Where the board's wooden frame starts, and where the drawn artwork
/// (easel legs, books, globe) actually ends — both as fractions of the
/// square source image's height. The PNG has roughly 20% transparent
/// padding below the artwork, so anything anchored to `imageRect.bottom`
/// lands far below the scene; these fractions anchor to the art itself.
/// The brand teal both the logo mark and the app name are painted in — a
/// deeper, fully saturated version of the mark's own gradient, so it holds
/// up against the light blue/cream backdrop instead of washing into it.
/// The brand lockup — the mark and the name under it — is drawn in flat
/// black so it reads at a glance against the classroom scene behind it.
/// The white glow around both is what keeps it legible where the artwork
/// underneath goes dark.
const Color _brandInk = Color(0xFF000000);

const double _frameTopFraction = 0.235;
const double _artworkBottomFraction = 0.80;

/// The drawing's own bounds inside the square canvas, traced from the
/// asset's alpha channel. The square is 3000x3000 but the art only fills
/// x 0.025-0.967 and y 0.220-0.859 of it, so sizing the square is not the
/// same as sizing the board — see the layout builder.
///
/// The measured top (0.220) has no constant of its own because the stack
/// is anchored to [_frameTopFraction] (0.235) instead, which sits just
/// below it and is where the logo actually has to clear.
const double _artLeftF = 0.025;
const double _artRightF = 0.967;
const double _artBottomF = 0.859;

/// How far left of the square image's centre the heroes sit, as a fraction
/// of the image width — the drawn board leans left of that midpoint, so
/// centring on the raw image centre reads as slightly right of the board.
const double _mascotLeftNudgeFraction = 0.045;

Widget _emptyImageFallback(BuildContext _, Object __, StackTrace? ___) =>
    const SizedBox.shrink();

Rect _boardRectFromImageRect(Rect imageRect) {
  // Re-measured against a live render, not eyeballed from the raw asset:
  // the board is drawn in perspective, so its right edge sits far closer
  // to the middle than the flat artwork suggests. The old 0.8675 right
  // fraction was ~13% too wide, which is precisely what pushed the whole
  // input block rightwards and over the wooden frame.
  const left = 0.245;
  const top = 0.275;
  const right = 0.735;
  const bottom = 0.590;
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
    // Deliberately not wrapped in a scroll view: the caller scales this
    // block to fit its box, so a scroll view would only ever produce the
    // stray vertical drag that showed up on tablets.
    return Form(
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
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
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
                // Default IconButton wants 48x48, which would blow past a
                // 42px field — constrain it explicitly.
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                visualDensity: VisualDensity.compact,
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
                    minimumSize: const Size.fromHeight(40),
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
      // An exact 42px field, so the whole block's height is predictable
      // and provably fits inside the green area.
      height: 42,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(6),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: Color(0xFFFFE9CC), shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFFC2650A), size: 15),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 0),
          suffixIcon: suffixIcon,
          suffixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 0),
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
