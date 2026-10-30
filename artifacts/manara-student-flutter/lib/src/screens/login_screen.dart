import 'dart:async';
import 'dart:math' as math;


import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../services/saved_accounts.dart';
import '../services/student_auth_service.dart';
import '../theme/student_theme.dart';
import '../services/student_sound_service.dart';
import '../widgets/student_experience.dart';
import '../widgets/student_no_back.dart';
import '../l10n/student_strings.dart';
import '../widgets/student_display_toggles.dart';
import '../widgets/lively.dart';
import '../widgets/login_backdrop.dart';
import '../widgets/login_scene.dart';
import '../widgets/student_avatar_view.dart';
import '../widgets/student_mascot.dart';
import 'academic_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.authService,
    required this.initializationError,
    required this.apiBaseUrl,
    this.savedAccounts,
    super.key,
  });

  final StudentAuthService? authService;
  final String? initializationError;
  final String apiBaseUrl;

  /// الحساباتُ المحفوظة على الجهاز؛ وبلا قيمةٍ [SavedAccounts.instance].
  final SavedAccounts? savedAccounts;

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

  SavedAccounts get _saved => widget.savedAccounts ?? SavedAccounts.instance;

  /// الحساباتُ المحفوظة على هذا الجهاز، تُعرض حين يلمس الطفلُ حقلَ الاسم.
  List<SavedAccount> _accounts = const [];
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  /// اختار «حساب آخر»: يكتب بنفسه، فلا تُفتح القائمةُ ثانيةً فوق ما يكتب.
  bool _manualEntry = false;
  bool _pickerOpen = false;

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(_onUsernameFocus);
    unawaited(_loadAccounts());
    // خلفيةُ الشاشة تبدأ مع ظهورها. وتُؤجَّل إلى ما بعد أوّل إطار كي لا
    // يزاحم فكُّ المقطع رسمَ الشاشة الأول.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(StudentSoundService.instance.speakLogin()),
    );
  }

  @override
  void dispose() {
    unawaited(StudentSoundService.instance.stopLoginVoice());
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final accounts = await _saved.load();
    if (mounted) setState(() => _accounts = accounts);
  }

  void _onUsernameFocus() {
    if (!_usernameFocus.hasFocus || _accounts.isEmpty || _manualEntry || _pickerOpen) return;
    // ‏حساباتٌ محفوظة: تُعرض صورُها بدل لوحة المفاتيح.
    _usernameFocus.unfocus();
    unawaited(_pickAccount());
  }

  /// شبكةُ الحسابات المحفوظة: لمسةٌ على صورة الطفل تُدخله.
  Future<void> _pickAccount() async {
    _pickerOpen = true;
    StudentSoundService.instance.playTap();
    final shown = _AccountsNotifier(() => _accounts);
    final choice = await showDialog<_AccountChoice>(
      context: context,
      builder: (context) => _AccountPicker(
        onRemove: (account) async {
          await _saved.remove(account.username);
          await _loadAccounts();
        },
        accountsListenable: shown,
      ),
    );
    shown.dispose();
    _pickerOpen = false;
    if (!mounted) return;
    switch (choice) {
      case _PickedAccount(:final account):
        final password = await _saved.passwordFor(account.username);
        if (!mounted) return;
        _usernameController.text = account.username;
        _passwordController.text = password ?? '';
        if ((password ?? '').isEmpty) {
          // ‏كلمةُ المرور لم تُحفظ: يكتبها هو.
          _manualEntry = true;
          _passwordFocus.requestFocus();
          return;
        }
        await _submit();
      case _OtherAccount():
        _manualEntry = true;
        _usernameFocus.requestFocus();
      case null:
        break;
    }
  }

  /// بعد دخولٍ ناجح: يُسأل الطالبُ مرّةً أن يحفظ حسابه؛ ومحفوظٌ يُحدَّث بصمت
  /// (شخصيةٌ جديدة، كلمةُ مرورٍ تغيّرت).
  Future<void> _offerToSave(StudentProfile student, String username, String password) async {
    final account = SavedAccount(
      username: username,
      displayName: student.name,
      appearance: student.appearance,
    );
    try {
      if (await _saved.isSaved(username)) {
        await _saved.save(account, password);
        return;
      }
      if (!await _saved.shouldOffer(username) || !mounted) return;
      final keep = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _SaveAccountDialog(account: account),
      );
      if (keep == true) {
        await _saved.save(account, password);
      } else {
        await _saved.decline(username);
      }
    } catch (error) {
      // ‏المخزنُ المشفّر غيرُ متاح: يُكمل الدخولُ بلا حفظ.
      debugPrint('[accounts] could not save the account: $error');
    }
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
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      final student = await widget.authService!.signIn(
        username: username,
        password: password,
      );
      StudentSoundService.instance.play(StudentSoundCue.loginSuccess);
      if (!mounted) return;
      setState(() => _loginSucceeded = true);
      await _offerToSave(student, username, password);
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
          _errorMessage = tr('login.failed');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = widget.authService != null;
    // Read here, above the Scaffold, and deliberately not inside the
    // LayoutBuilder below: a Scaffold with resizeToAvoidBottomInset
    // subtracts the keyboard from its body's height and then reports zero
    // insets to it, having already dealt with them. Asking from inside
    // would always answer "no keyboard", which is exactly the trap that
    // made the first attempt at this do nothing at all.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final typing = keyboard > 0;

    return StudentNoBack(
      child: Scaffold(
      backgroundColor: StudentSurface.coolGround(context),
      // ‏النافذة تبقى بكامل ارتفاعها، والكيبورد يُرفع عنه المشهد رفعاً.
      //
      // ‏كانت `true`: يقتطع الكيبورد من ارتفاع الجسم، ويُعاد قياس المشهد
      // ‏على ما بقي — فتنكمش السبورة وما عليها إلى شريط مشوّه في الوضع
      // ‏الأفقي، وهو ما شُكي منه. ثم جُرّبت `false` قديماً فاختفت الحقول
      // ‏خلف المفاتيح، لأن لا شيء كان يرفع المشهد حينها.
      //
      // ‏فالآن الاثنان معاً: حجمٌ لا يتغيّر بظهور الكيبورد، ورفعٌ محسوب
      // ‏يُبقي الحقول فوقه. السبورة تعلو ويُقتطع من رأسها — وأعلاها إطار
      // ‏وخشب — ولا تُمسّ أبعادها.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ‏سماءٌ ومرجٌ وكتبٌ تنجرف ببطء، في الوضعين.
          const Positioned.fill(child: LoginBackdrop()),
          // ‏خلفيةٌ حيّة على طريقة «لمسة»: حروفٌ وأرقامٌ وفقاعاتٌ تطفو خلف
          // ‏السبورة. طبقةٌ مرسومة لا تستقبل لمسة ولا تمسّ تخطيط المشهد.
          const Positioned.fill(child: LoginAmbience()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final windowSize = constraints.biggest;

                // ‏أرضيةٌ لا ينزل المشهد تحتها، وما فاض عن النافذة
                // ‏يُمرَّر بالإصبع: في الوضع الأفقي على هاتف كان المشهد
                // ‏يُقاس على نافذة قصيرة فتخرج سبورة صغيرة محشورة.
                //
                // ‏والأرضية تتبع العرض لا رقماً ثابتاً: هي ما يلزم لتبدو
                // ‏السبورة بحجمها المعتاد، ولا تتجاوز ما يسعه العرض فلا
                // ‏يصير التمرير عادةً على الشاشات الواسعة.
                //
                // ‏وتسقط تماماً حين يكتب الطفل. جرّبتُ إبقاءها فسقط اختبار
                // ‏«الحقل يجب أن ينتهي فوق الكيبورد»: المشهد يعلو، فينزل
                // ‏الحقل تحت المفاتيح من جديد. وسبورةٌ أكبر لا يُرى ما
                // ‏يُكتب فيها أسوأ من سبورة صغيرة يُكتب فيها — وهي
                // ‏المفاضلة نفسها التي بُني عليها هذا التخطيط.
                // ‏المشهد بمقاس النافذة تماماً: ملء الشاشة بلا تمرير.
                //
                // ‏جُرّبت أرضيةٌ تعلو بالمشهد فوق النافذة ليتّسع، فكبرت
                // ‏السبورة ولزم النزول والطلوع لرؤيتها. والتمرير في شاشة
                // ‏دخولٍ لطفل ثمنٌ أغلى من بضع نقاط عرض — وقد نُزع بدله
                // ‏من مكان أصدق: كتلة الشعار أعلاه.
                final areaSize = windowSize;

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
                // ‏على التابلت والآيباد: سبورةٌ بمقاسٍ مريحٍ في الوسط، لا تملأ
                // ‏الشاشةَ كلَّها. كانت تُكبَّر حتى يبلغ المشهدُ حافّتَي الشاشة،
                // ‏فتخرج عملاقةً على لوحٍ كبير. والهاتفُ يبقى كما هو: هناك كلُّ
                // ‏نقطةٍ تلزم الحقول.
                final landscape = areaSize.width > areaSize.height;
                // ‏ولا يتبدّل بالكيبورد: السبورةُ لا يتغيّر حجمُها حين يكتب الطفل.
                final tablet = areaSize.shortestSide >= 600;
                double fit(double size) => !tablet
                    ? size
                    : math.min(
                        size,
                        landscape
                            ? math.min(areaSize.height * 0.72 / stackSpan, areaSize.width * 0.6 / artW)
                            : areaSize.width * 0.8 / artW,
                      );
                double boardSize = fit(math.min(
                  areaSize.height * 0.99 / (stackSpan + 0.19),
                  areaSize.width * 0.99 / artW,
                ));
                // While the keyboard is open the brand steps aside and
                // gives the board its height (see `typing`, read above the
                // Scaffold). On a phone in landscape only about 150px of
                // window survives the keyboard, and spending a third of
                // that on a logo leaves writing the student cannot read.
                // It comes straight back when the keyboard closes.
                double logoSize = 0;
                double logoNameHeight = 0;
                double logoBlockHeight = 0;
                for (var pass = 0; pass < 3; pass++) {
                  // ‏في الوضع الأفقي الارتفاع هو القيد، وكتلة الشعار
                  // ‏فوق السبورة تأكل نحو خُمسه — فتخرج السبورة ضيّقة.
                  // ‏فلا تُوضع فوقها هناك، بل في الفراغ الجانبي الذي
                  // ‏يفيض في ذلك الوضع: العرض واسعٌ والسبورة مربّعة.
                  //
                  // ‏وكان الشعار يُخفى هناك إخفاءً تامّاً، فيفتح الطفل
                  // ‏التطبيق أفقياً فلا يرى اسم المنصّة إطلاقاً. القيد
                  // ‏كان على الارتفاع وحده، والحلّ إخراجُه من عمود
                  // ‏الارتفاع لا حذفُه.
                  //
                  // ‏أما أثناء الكتابة فيتنحّى في الوضعين: الكيبورد لا
                  // ‏يُبقي إلا نحو مئةٍ وخمسين نقطة، وإنفاقُ شيءٍ منها
                  // ‏على شعارٍ يترك كتابةً لا تُقرأ.
                  final hideBrand = typing || landscape;
                  logoSize = hideBrand
                      ? 0.0
                      : (boardSize * 0.145).clamp(44.0, 130.0).toDouble();
                  logoNameHeight = hideBrand
                      ? 0.0
                      : (boardSize * 0.045).clamp(14.0, 34.0).toDouble();
                  logoBlockHeight = hideBrand
                      ? 0.0
                      : logoSize + logoNameGap + logoNameHeight;
                  boardSize = fit(math.min(
                    (areaSize.height * 0.99 -
                            logoBlockHeight -
                            (hideBrand ? 0.0 : logoGap)) /
                        stackSpan,
                    areaSize.width * 0.99 / artW,
                  ));
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

                // ‏الرفع: ما يلزم ليبقى أسفل السبورة فوق المفاتيح.
                //
                // ‏النافذة لم تُقتطع (`resizeToAvoidBottomInset: false`)،
                // ‏فالكيبورد يغطّي آخر `keyboard` نقطة منها. وأسفل
                // ‏السبورة يجب أن يعلو ذلك الحدّ.
                //
                // ‏ولا يُقيَّد الرفع بالفراغ فوق المشهد: في الوضع الأفقي
                // ‏لا فراغ يُذكر، وتقييده به كان يعني ألّا يرتفع شيء.
                // ‏فيُقتطع من رأس السبورة بدلاً منه — وأعلاها إطار وخشب،
                // ‏وأسفلها الحقول وزرّ الدخول.
                final visibleBottom = areaSize.height - keyboard;
                final lift = !typing
                    ? 0.0
                    : math.max(0.0, boardRect.bottom - visibleBottom + 12);

                return ClipRect(
                  child: SizedBox(
                    width: areaSize.width,
                    height: areaSize.height,
                    child: Transform.translate(
                  offset: Offset(0, -lift),
                  // ‏السبورةُ تطفو وتتأرجح بخفّة — المشهدُ والحقولُ والبطلان
                  // ‏كتلةً واحدة — وتسكن ما دام الطالب يكتب.
                  child: LivelyFloatScope(
                  enabled: !typing,
                  child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ‏المشهدُ حيّ: الكتبُ والكرةُ الأرضية تتمايل وتقفز عند اللمس،
                    // ‏والكرةُ تدور على محورها. وفي السكون الصورةُ الأصلية نفسها.
                    Positioned.fromRect(
                      rect: imageRect,
                      child: const LivelyFloating(child: LivingLoginScene()),
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
                    // band and never needs to be moved aside — except
                    // while the keyboard is open, when that budget goes to
                    // the board instead and this comes off the screen with
                    // it.
                    if (!typing && landscape)
                      // ‏الشعار في الوضع الأفقي: في الركن العلوي، مرسوماً
                      // ‏بمقياس الارتفاع لا العرض، فلا يخرج عن الشاشة
                      // ‏مهما ضاقت. ولا يزاحم السبورة لأنه خارج عمودها.
                      Positioned(
                        top: 10,
                        left: 14,
                        right: 14,
                        // ‏يساراً صريحاً: أزرارُ الصوت والعرض في اليمين بالجهة الفعلية،
                        // ‏فلو تبع اتجاهَ اللغة لجلس فوقها في العربية.
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: _LandscapeBrand(
                            // ‏نحو سُبع الارتفاع، وبحدّين: لا يتضخّم على
                            // ‏تابلت ولا يتلاشى على هاتف.
                            markSize:
                                (areaSize.height * 0.15).clamp(28.0, 64.0).toDouble(),
                            maxWidth: areaSize.width * 0.55,
                          ),
                        ),
                      ),
                    if (!typing && !landscape)
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
                          // ‏الشعارُ يتمايل بهدوء — تحويلٌ لا يغيّر موضعَه في الحساب.
                          LivelyBob(
                            amplitude: 3,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.white, blurRadius: 18, spreadRadius: 2),
                                  BoxShadow(color: Colors.white70, blurRadius: 30, spreadRadius: 6),
                                ],
                              ),
                              child: Image.asset(
                                  'assets/images/manara-logo-emblem.png',
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
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                tr('app.name'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _brandInk,
                                  fontSize: 30,
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
                      child: LivelyFloating(
                      child: Padding(
                        // A margin proportional to the green area, so the
                        // block keeps the same visual inset at any size.
                        padding: EdgeInsets.symmetric(
                          // Tightened from 0.05/0.06. The form is authored
                          // at a fixed height and then scaled to this box,
                          // so on a phone — where the box measures only
                          // about 177x111 — the rendered type size works
                          // out to boxHeight/formHeight and does not
                          // depend on the font sizes at all. The padding
                          // is the one lever that grows the box without
                          // moving anything in the scene.
                          horizontal: boardRect.width * 0.035,
                          vertical: boardRect.height * 0.035,
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
                                // Unchanged. Measuring showed 70% of the
                                // board tops out near 315 at every size
                                // shipped, so this ceiling is never the
                                // binding constraint and raising it moved
                                // nothing. The type sizes inside the block
                                // are what had to grow: on a tablet the
                                // FittedBox already sits at scale 1.0, so
                                // the form was rendering at its bare
                                // authored size — which is why the text
                                // was smallest on the screens with the
                                // most room.
                                .clamp(240.0, 340.0)
                                .toDouble(),
                            child: _BoardLoginForm(
                            formKey: _formKey,
                            isConfigured: isConfigured,
                            initializationError: widget.initializationError,
                            usernameController: _usernameController,
                            passwordController: _passwordController,
                            usernameFocus: _usernameFocus,
                            passwordFocus: _passwordFocus,
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
                      child: LivelyFloating(child: StudentInteractiveMascot(size: mascotSize)),
                    ),
                    Positioned(
                      top: 4,
                      right: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x14000000),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [StudentDisplayToggles(), StudentSoundToggle()]),
                      ),
                    ),
                  ],
                  ),
                  ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
    required this.usernameFocus,
    required this.passwordFocus,
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
  final FocusNode usernameFocus;
  final FocusNode passwordFocus;
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
            // One line, always.
            //
            // The whole block is scaled to fit the green board, so every
            // pixel of its height is taken out of the scale factor and
            // therefore out of the size of *everything else*. Letting this
            // greeting wrap to two lines cost ~29px of block height, which
            // on a phone shrank the fields and the button by more than the
            // larger type had gained them. Keeping it to one line is what
            // makes the rest of the form bigger.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
              tr('login.greeting'),
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 2))],
              ),
              ),
            ),
            const SizedBox(height: 8),
            _SolidField(
              key: const ValueKey('login-username'),
              controller: usernameController,
              focusNode: usernameFocus,
              hint: tr('login.username'),
              icon: Icons.person_rounded,
              hasError: showValidationFeedback && usernameController.text.trim().isEmpty,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onChanged: onUsernameChanged,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? tr('login.usernameRequired') : null,
            ),
            const SizedBox(height: 8),
            _SolidField(
              key: const ValueKey('login-password'),
              controller: passwordController,
              focusNode: passwordFocus,
              hint: tr('login.password'),
              icon: Icons.lock_rounded,
              obscureText: hidePassword,
              hasError: showValidationFeedback && passwordController.text.isEmpty,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onChanged: onPasswordChanged,
              onFieldSubmitted: (_) => onSubmit(),
              validator: (value) => value == null || value.isEmpty ? tr('login.passwordRequired') : null,
              suffixIcon: IconButton(
                // Default IconButton wants 48x48, which would blow past a
                // 42px field — constrain it explicitly.
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                visualDensity: VisualDensity.compact,
                tooltip: tr(
                    hidePassword ? 'login.showPassword' : 'login.hidePassword'),
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
                  style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            if (!isConfigured && initializationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  initializationError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            const SizedBox(height: 8),
            // ‏هالةٌ تنبض حول زرّ الدخول تدعو إليه — ظلٌّ لا يغيّر مقاسه.
            LivelyPulseGlow(
              radius: 28,
              color: loginSucceeded ? const Color(0xFF3B9C70) : const Color(0xFFFF9F1C),
              child: StudentPressScale(
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
                  // The label stays on one line and shrinks to fit if it
                  // has to. At the larger type the longest of these
                  // ("جاري التحقق...") wrapped to two lines inside the
                  // button on a portrait tablet, which pushed the pill out
                  // of shape. A button caption that wraps is never right.
                  label: Text(
                    loginSucceeded
                        ? tr('login.ready')
                        : isLoading
                            ? tr('login.checking')
                            : tr('login.submit'),
                    maxLines: 1,
                  ),
                  style: FilledButton.styleFrom(
                    // Grew with the type so the taller caption is not
                    // pressed against the pill's edges.
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor:
                        loginSucceeded ? const Color(0xFF3B9C70) : const Color(0xFFFF9F1C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                    shape: const StadiumBorder(),
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

/// A solid, unmistakably-white field with a light gray border and a soft
/// drop shadow — dark, clearly-readable text and a colored icon badge, so
/// it never blends into the mottled green board behind it.
class _SolidField extends StatelessWidget {
  const _SolidField({
    required this.controller,
    this.focusNode,
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
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
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
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        cursorColor: Colors.black54,
        style: const TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black54, fontSize: 19, fontWeight: FontWeight.w600),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

/// شعار المنصّة في الوضع الأفقي: العلامة واسمها جنباً إلى جنب.
///
/// أفقيٌّ لا رأسيّ لأن القيد هناك هو الارتفاع. والمقاس يُشتقّ من ارتفاع
/// الشاشة لا من عرضها، فالشاشة الأقصر تُعطي شعاراً أصغر بدل أن تدفعه
/// خارج حدّها — وهو ما كان يحدث حين كانت أبعاده ثابتة.
class _LandscapeBrand extends StatelessWidget {
  const _LandscapeBrand({required this.markSize, required this.maxWidth});

  final double markSize;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        // يتقلّص كاملاً بدل أن يفيض: نصٌّ عربيّ طويل في شاشةٍ ضيّقة
        // كان سيُقصّ من طرفه.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LivelyBob(
                amplitude: 2,
                child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.white, blurRadius: 14, spreadRadius: 2),
                    BoxShadow(color: Colors.white70, blurRadius: 22, spreadRadius: 4),
                  ],
                ),
                child: Image.asset(
                    'assets/images/manara-logo-emblem.png',
                    width: markSize,
                    height: markSize,
                    fit: BoxFit.contain,
                    errorBuilder: _emptyImageFallback,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                tr('app.name'),
                style: TextStyle(
                  color: _brandInk,
                  fontSize: markSize * 0.46,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Colors.white, blurRadius: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// ما اختاره الطفلُ من شبكة الحسابات.
sealed class _AccountChoice {
  const _AccountChoice();
}

class _PickedAccount extends _AccountChoice {
  const _PickedAccount(this.account);
  final SavedAccount account;
}

class _OtherAccount extends _AccountChoice {
  const _OtherAccount();
}

/// يُعيد بناءَ الشبكة حين يُزال منها حساب.
class _AccountsNotifier extends ChangeNotifier {
  _AccountsNotifier(this.read);
  final List<SavedAccount> Function() read;
  void changed() => notifyListeners();
}

/// «اختر حسابك»: صورُ الحسابات المحفوظة وأسماؤها؛ لمسةٌ تُدخل، والضغطُ
/// المطوّل يُزيل الحسابَ من هذا الجهاز بعد تأكيد.
class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.onRemove,
    required this.accountsListenable,
  });

  final Future<void> Function(SavedAccount account) onRemove;
  final _AccountsNotifier accountsListenable;

  Future<void> _confirmRemove(BuildContext context, SavedAccount account) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('login.removeAccount'), textAlign: TextAlign.center),
        content: Text(account.displayName, textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(tr('login.cancel'))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(tr('login.remove'))),
        ],
      ),
    );
    if (remove != true) return;
    await onRemove(account);
    accountsListenable.changed();
    if (context.mounted && accountsListenable.read().isEmpty) {
      Navigator.of(context).pop(const _OtherAccount());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey('login-account-picker'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: ListenableBuilder(
            listenable: accountsListenable,
            builder: (context, _) {
              final shown = accountsListenable.read();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('login.pickAccount'),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('login.savedHint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (final account in shown)
                            _AccountTile(
                              key: ValueKey('login-account-${account.username}'),
                              account: account,
                              onTap: () => Navigator.of(context).pop(_PickedAccount(account)),
                              onLongPress: () => _confirmRemove(context, account),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const ValueKey('login-other-account'),
                    onPressed: () => Navigator.of(context).pop(const _OtherAccount()),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(
                      tr('login.otherAccount'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final SavedAccount account;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: account.displayName,
      child: StudentPressScale(
        child: Material(
          color: const Color(0xFFFFF4E0),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              width: 128,
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFFF9F1C), width: 2),
              ),
              child: Column(
                children: [
                  StudentAvatarView(size: 84, appearance: account.appearance ?? const {}),
                  const SizedBox(height: 8),
                  Text(
                    account.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «هل تريد حفظ حسابك على هذا الجهاز لتسجيل الدخول السريع؟» — بعد أوّل
/// دخولٍ ناجح، وبصورة الطفل واسمه.
class _SaveAccountDialog extends StatelessWidget {
  const _SaveAccountDialog({required this.account});

  final SavedAccount account;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('login-save-dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Column(
        children: [
          StudentAvatarView(size: 88, appearance: account.appearance ?? const {}),
          const SizedBox(height: 10),
          Text(
            tr('login.saveTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.4),
          ),
        ],
      ),
      content: Text(
        account.displayName,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          key: const ValueKey('login-save-no'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(tr('login.saveNo'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        FilledButton.icon(
          key: const ValueKey('login-save-yes'),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.bookmark_add_rounded),
          label: Text(tr('login.saveYes'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF9F1C)),
        ),
      ],
    );
  }
}
