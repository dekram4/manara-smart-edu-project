import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../l10n/student_strings.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../services/subscription_plans.dart';
import '../theme/student_theme.dart';
import '../widgets/demo_ui.dart';

/// رقمُ واتساب المشرف: يُمرَّر عند البناء (`--dart-define=ADMIN_WHATSAPP=9665…`).
/// وبلا رقمٍ يفتح واتساب ليختار المستخدمُ المحادثة والرسالةُ مكتوبة.
const adminWhatsApp = String.fromEnvironment('ADMIN_WHATSAPP');

/// «احصل على حساب رسمي»: مقارنةُ الباقات بشفافية، ثم طلبٌ يصل المشرف.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key, required this.apiBaseUrl, this.httpClient, this.openUrl});

  final String apiBaseUrl;

  /// للاختبار.
  final http.Client? httpClient;
  final Future<bool> Function(Uri uri)? openUrl;

  @override
  State<PlansScreen> createState() => PlansScreenState();
}

class PlansScreenState extends State<PlansScreen> {
  String? _plan;
  final _name = TextEditingController();
  final _grade = TextEditingController();
  final _students = TextEditingController();
  final _phone = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;
  bool _sent = false;

  @visibleForTesting
  String? get plan => _plan;
  @visibleForTesting
  bool get sent => _sent;

  bool get _ar => StudentSettings.isArabic;

  @override
  void dispose() {
    for (final c in [_name, _grade, _students, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  SubscriptionPlan? get _selected => planById(_plan);

  void _choose(String id) {
    HapticFeedback.selectionClick();
    StudentSoundService.instance.playTap();
    final first = _plan == null;
    setState(() {
      _plan = id;
      _sent = false;
    });
    // ‏أوّلُ اختيار: تنزل الشاشةُ إلى نموذج الطلب بنعومة.
    if (first) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _formKey.currentContext;
        if (target == null || !mounted) return;
        Scrollable.ensureVisible(
          target,
          duration: Duration(milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 420),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      });
    }
  }

  String _message() {
    final plan = _selected;
    final lines = [
      tr('plans.whatsappIntro'),
      '${tr('plans.form.plan')}: ${plan == null ? '' : (_ar ? plan.nameAr : plan.nameEn)}',
      '${tr('plans.form.name')}: ${_name.text.trim()}',
      if (_grade.text.trim().isNotEmpty) '${tr('plans.form.grade')}: ${_grade.text.trim()}',
      if (_students.text.trim().isNotEmpty) '${tr('plans.form.students')}: ${_students.text.trim()}',
      '${tr('plans.form.phone')}: ${_phone.text.trim()}',
    ];
    return lines.join('\n');
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _plan == null) return;
    setState(() => _sending = true);
    try {
      final base = widget.apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
      final client = widget.httpClient ?? http.Client();
      final response = await client
          .post(
            Uri.parse('$base/api/join-requests'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'plan': _plan,
              'name': _name.text.trim(),
              'grade': _grade.text.trim(),
              'students': int.tryParse(_students.text.trim()),
              'phone': _phone.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() => _sent = true);
        StudentSoundService.instance.play(StudentSoundCue.loginSuccess);
      } else {
        final body = response.body.isEmpty ? null : jsonDecode(response.body);
        _offerWhatsApp(body is Map && body['error'] is String ? body['error'] as String : tr('plans.sendFailed'));
      }
    } catch (_) {
      if (mounted) _offerWhatsApp(tr('plans.sendFailed'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _whatsapp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final text = Uri.encodeComponent(_message());
    final number = adminWhatsApp.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse(number.isEmpty ? 'https://wa.me/?text=$text' : 'https://wa.me/$number?text=$text');
    final open = widget.openUrl ?? (Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);
    final ok = await open(uri).catchError((_) => false);
    if (!ok && mounted) _toast(tr('plans.whatsappFailed'));
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
  }

  /// تعذّر الإرسال (خادمٌ لم يُحدَّث أو بلا إنترنت): واتساب طريقٌ جاهز.
  void _offerWhatsApp(String message) {
    StudentSoundService.instance.play(StudentSoundCue.warning);
    showDemoDialog<void>(
      context: context,
      key: const ValueKey('plans-send-failed'),
      emoji: '📮',
      title: tr('plans.sendFailedTitle'),
      body: Text(message, textAlign: TextAlign.center),
      actions: [
        DemoGradientButton(
          key: const ValueKey('plans-failed-whatsapp'),
          label: tr('plans.whatsapp'),
          icon: Icons.chat_rounded,
          gradient: DemoPalette.whatsappGradient,
          foreground: Colors.white,
          onPressed: () {
            Navigator.of(context).pop();
            _whatsapp();
          },
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('demo.ok'))),
      ],
    );
  }

  static const _groupLook = {
    PlanGroup.individual: ('🎒', [Color(0xFF1D4ED8), Color(0xFF6366F1)]),
    PlanGroup.family: ('👨‍👩‍👧', [Color(0xFF15803D), Color(0xFF14B8A6)]),
    PlanGroup.school: ('🏫', [DemoPalette.violetDeep, DemoPalette.magenta]),
  };

  @override
  Widget build(BuildContext context) {
    List<Widget> cardsFor({required bool tiersInRow}) => [
          _planCard(context, PlanGroup.individual, const ['individual']),
          _planCard(context, PlanGroup.family, const ['family']),
          _planCard(context, PlanGroup.school, const ['school_small', 'school_medium', 'school_large'],
              tiersInRow: tiersInRow),
        ];
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        // ‏صفحةٌ واحدةٌ تتمرّر — لا قائمةٌ كسولة: النموذجُ يُبنى مع الصفحة، فتنزل
        // ‏إليه الشاشةُ حين تُختار الباقة ولو كان آخرَها على جوالٍ صغير.
        body: SingleChildScrollView(
          key: const ValueKey('plans-list'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: 32 + MediaQuery.paddingOf(context).bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _hero(context),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: LayoutBuilder(builder: (context, box) {
                    final w = box.maxWidth;
                    // ‏الفئاتُ المؤسسيّة صفٌّ واحد حين تمتدّ بطاقتُها بعرض الشاشة.
                    final cards = cardsFor(tiersInRow: w >= 600 && w < 900);
                    // ‏ثلاثةُ أعمدةٍ على التابلت الأفقيّ والأيباد، واثنان على
                    // ‏التابلت العموديّ (والمؤسسيةُ تحتهما بعرضها)، وعمودٌ للجوال.
                    if (w >= 900) {
                      return IntrinsicHeight(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          for (final (i, c) in cards.indexed) ...[
                            if (i > 0) const SizedBox(width: 14),
                            Expanded(child: DemoEntrance(index: i, child: c)),
                          ],
                        ]),
                      );
                    }
                    if (w >= 600) {
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        IntrinsicHeight(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Expanded(child: DemoEntrance(index: 0, child: cards[0])),
                            const SizedBox(width: 14),
                            Expanded(child: DemoEntrance(index: 1, child: cards[1])),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        DemoEntrance(index: 2, child: cards[2]),
                      ]);
                    }
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final (i, c) in cards.indexed) ...[
                        if (i > 0) const SizedBox(height: 14),
                        DemoEntrance(index: i, child: c),
                      ],
                    ]);
                  }),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AnimatedSize(
                    duration: Duration(milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _plan == null ? const SizedBox(width: double.infinity) : _form(context),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// الرأس: تدرّجٌ بنفسجيّ بحوافَّ مستديرة، وشارةٌ ذهبيّة، والرجوع.
  Widget _hero(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: DemoPalette.violetGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Color(0x554B267F), blurRadius: 24, offset: Offset(0, 10))],
      ),
      padding: EdgeInsets.fromLTRB(8, top + 4, 8, 22),
      child: Column(children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const BackButtonIcon(),
            color: Colors.white,
          ),
        ),
        const DemoHeaderBadge(emoji: '🏅', size: 66),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            tr('plans.title'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              tr('plans.subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15, fontWeight: FontWeight.w700, height: 1.5),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _planCard(BuildContext context, PlanGroup group, List<String> ids, {bool tiersInRow = false}) {
    final plans = ids.map(planById).whereType<SubscriptionPlan>().toList();
    final selectedHere = ids.contains(_plan);
    final (emoji, colors) = _groupLook[group]!;
    final color = colors.first;
    final title = switch (group) {
      PlanGroup.individual => tr('plans.group.individual'),
      PlanGroup.family => tr('plans.group.family'),
      _ => tr('plans.group.school'),
    };
    final still = MediaQuery.of(context).disableAnimations;
    return AnimatedContainer(
      key: ValueKey('plan-card-${group.name}'),
      duration: Duration(milliseconds: still ? 0 : 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: StudentSurface.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selectedHere ? DemoPalette.gold : StudentSurface.outline(context),
          width: selectedHere ? 3 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (selectedHere ? DemoPalette.gold : color).withValues(alpha: selectedHere ? 0.45 : 0.16),
            blurRadius: selectedHere ? 26 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        // ‏شريطُ الباقة: لونُها وشارتُها واسمُها.
        Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white, height: 1.3)),
            ),
            if (selectedHere)
              const Icon(Icons.verified_rounded, color: DemoPalette.goldLight, size: 28),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: DemoPalette.goldGradient,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(_ar ? planPricePlaceholderAr : planPricePlaceholderEn,
                    key: ValueKey('plan-price-${group.name}'),
                    style: const TextStyle(fontWeight: FontWeight.w900, color: DemoPalette.goldInk, fontSize: 13)),
              ),
            ),
            if (group != PlanGroup.school) ...[
              const SizedBox(height: 6),
              Text(_ar ? plans.first.seatsAr : plans.first.seatsEn,
                  style: TextStyle(color: StudentSurface.mutedInk(context), fontWeight: FontWeight.w700)),
            ],
            const Divider(height: 20),
            for (final f in planFeatures) _featureRow(context, f, group),
            const SizedBox(height: 12),
            if (group == PlanGroup.school) ...[
              Text(tr('plans.schoolTiers'), style: TextStyle(fontWeight: FontWeight.w900, color: StudentSurface.ink(context))),
              const SizedBox(height: 8),
              // ‏بلا LayoutBuilder: البطاقةُ داخل IntrinsicHeight على الشاشات العريضة.
              if (tiersInRow)
                IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final (i, p) in plans.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: _tierTile(context, p)),
                    ],
                  ]),
                )
              else
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (i, p) in plans.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _tierTile(context, p),
                  ],
                ]),
            ] else
              DemoGradientButton(
                key: ValueKey('plan-choose-${plans.first.id}'),
                label: _plan == plans.first.id ? '✓ ${tr('plans.chosen')}' : tr('plans.choose'),
                icon: _plan == plans.first.id ? null : Icons.touch_app_rounded,
                gradient: _plan == plans.first.id ? DemoPalette.goldGradient : LinearGradient(colors: colors),
                foreground: _plan == plans.first.id ? DemoPalette.goldInk : Colors.white,
                height: 50,
                onPressed: () => _choose(plans.first.id),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _featureRow(BuildContext context, PlanFeature f, PlanGroup group) {
    final on = f.includedIn(group);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? const Color(0xFF16A34A) : const Color(0xFFFEE2E2),
          ),
          child: Icon(on ? Icons.check_rounded : Icons.close_rounded,
              size: 14, color: on ? Colors.white : const Color(0xFFDC2626)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _ar ? f.ar : f.en,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: on ? StudentSurface.ink(context) : StudentSurface.mutedInk(context),
              decoration: on ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      ]),
    );
  }

  /// فئةٌ مؤسسيّة: مربّعٌ ينضغط، يتوهّج ذهباً حين يُختار.
  Widget _tierTile(BuildContext context, SubscriptionPlan p) {
    final chosen = _plan == p.id;
    return DemoPressable(
      key: ValueKey('plan-choose-${p.id}'),
      onTap: () => _choose(p.id),
      child: AnimatedContainer(
        duration: Duration(milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: chosen ? DemoPalette.goldGradient : null,
          color: chosen ? null : DemoPalette.violet.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: chosen ? Colors.white : DemoPalette.violet.withValues(alpha: 0.45), width: chosen ? 2 : 1.2),
          boxShadow: chosen ? [BoxShadow(color: DemoPalette.gold.withValues(alpha: 0.45), blurRadius: 14)] : const [],
        ),
        child: Row(children: [
          Icon(chosen ? Icons.check_circle_rounded : Icons.groups_rounded,
              color: chosen ? DemoPalette.goldInk : DemoPalette.violet),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_ar ? p.nameAr : p.nameEn,
                  style: TextStyle(fontWeight: FontWeight.w900, color: chosen ? DemoPalette.goldInk : DemoPalette.violet)),
              Text(_ar ? p.seatsAr : p.seatsEn,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: chosen ? DemoPalette.goldInk : StudentSurface.mutedInk(context))),
            ]),
          ),
        ]),
      ),
    );
  }

  InputDecoration _field(BuildContext context, String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: DemoPalette.violet),
        filled: true,
        fillColor: DemoPalette.violet.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: DemoPalette.violet.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DemoPalette.gold, width: 2.2),
        ),
      );

  Widget _form(BuildContext context) {
    final plan = _selected!;
    final needsCount = plan.group != PlanGroup.individual;
    final name = TextFormField(
      key: const ValueKey('plans-name'),
      controller: _name,
      textInputAction: TextInputAction.next,
      decoration: _field(context, tr('plans.form.name'), Icons.badge_rounded),
      validator: (v) => (v ?? '').trim().length < 2 ? tr('plans.form.required') : null,
    );
    final grade = TextFormField(
      key: const ValueKey('plans-grade'),
      controller: _grade,
      textInputAction: TextInputAction.next,
      decoration: _field(context, tr('plans.form.grade'), Icons.school_rounded),
    );
    final students = TextFormField(
      key: const ValueKey('plans-students'),
      controller: _students,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _field(context, tr('plans.form.students'), Icons.groups_rounded),
      validator: (v) {
        final n = int.tryParse((v ?? '').trim()) ?? 0;
        if (plan.group == PlanGroup.family && n < 3) return tr('plans.form.familyMin');
        if (plan.group == PlanGroup.school && n < 1) return tr('plans.form.required');
        return null;
      },
    );
    final phone = TextFormField(
      key: const ValueKey('plans-phone'),
      controller: _phone,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      decoration: _field(context, tr('plans.form.phone'), Icons.phone_iphone_rounded),
      validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 8 ? tr('plans.form.phoneInvalid') : null,
    );
    final fields = [name, grade, if (needsCount) students, phone];
    return Form(
      key: _formKey,
      child: Container(
        key: const ValueKey('plans-form'),
        decoration: BoxDecoration(
          gradient: DemoPalette.goldGradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: DemoPalette.gold.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: BoxDecoration(color: StudentSurface.card(context), borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const DemoHeaderBadge(emoji: '✍️', size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('plans.form.title'),
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: StudentSurface.ink(context))),
                  Text(_ar ? plan.nameAr : plan.nameEn,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: DemoPalette.violet)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, box) {
              // ‏حقلان في الصفّ على الشاشات العريضة، وحقلٌ واحد على الجوال.
              final two = box.maxWidth >= 600;
              if (!two) {
                return Column(children: [
                  for (final (i, f) in fields.indexed) ...[if (i > 0) const SizedBox(height: 12), f],
                ]);
              }
              return Column(children: [
                for (var i = 0; i < fields.length; i += 2) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: fields[i]),
                    const SizedBox(width: 12),
                    Expanded(child: i + 1 < fields.length ? fields[i + 1] : const SizedBox()),
                  ]),
                ],
              ]);
            }),
            const SizedBox(height: 16),
            if (_sent)
              DemoEntrance(
                index: 0,
                child: Container(
                  key: const ValueKey('plans-sent'),
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF34D399)),
                  ),
                  child: Text(tr('plans.sent'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
                ),
              ),
            LayoutBuilder(builder: (context, box) {
              final submit = DemoGradientButton(
                key: const ValueKey('plans-submit'),
                label: tr('plans.submit'),
                icon: Icons.send_rounded,
                shimmer: true,
                busy: _sending,
                onPressed: _sending || _sent ? null : _submit,
              );
              final whatsapp = DemoGradientButton(
                key: const ValueKey('plans-whatsapp'),
                label: tr('plans.whatsapp'),
                icon: Icons.chat_rounded,
                gradient: DemoPalette.whatsappGradient,
                foreground: Colors.white,
                onPressed: _whatsapp,
              );
              if (box.maxWidth >= 600) {
                return Row(children: [
                  Expanded(child: submit),
                  const SizedBox(width: 12),
                  Expanded(child: whatsapp),
                ]);
              }
              return Column(children: [submit, const SizedBox(height: 10), whatsapp]);
            }),
          ]),
        ),
      ),
    );
  }
}
