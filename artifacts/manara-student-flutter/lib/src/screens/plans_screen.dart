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
    setState(() {
      _plan = id;
      _sent = false;
    });
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
        _toast(body is Map && body['error'] is String ? body['error'] as String : tr('plans.sendFailed'));
      }
    } catch (_) {
      if (mounted) _toast(tr('plans.sendFailed'));
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        appBar: AppBar(title: Text('🏅 ${tr('plans.title')}')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
                key: const ValueKey('plans-list'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(tr('plans.subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: StudentSurface.mutedInk(context))),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (context, box) {
                    final wide = box.maxWidth >= 760;
                    final cards = [
                      _planCard(context, PlanGroup.individual, const ['individual'], const Color(0xFF2563EB)),
                      _planCard(context, PlanGroup.family, const ['family'], const Color(0xFF16A34A)),
                      _planCard(context, PlanGroup.school, const ['school_small', 'school_medium', 'school_large'],
                          const Color(0xFFB45309)),
                    ];
                    if (!wide) {
                      return Column(children: [
                        for (final c in cards) ...[c, const SizedBox(height: 12)],
                      ]);
                    }
                    return IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        for (final (i, c) in cards.indexed) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(child: c),
                        ],
                      ]),
                    );
                  }),
                  const SizedBox(height: 18),
                  if (_plan != null) _form(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _planCard(BuildContext context, PlanGroup group, List<String> ids, Color color) {
    final plans = ids.map(planById).whereType<SubscriptionPlan>().toList();
    final selectedHere = ids.contains(_plan);
    final title = switch (group) {
      PlanGroup.individual => tr('plans.group.individual'),
      PlanGroup.family => tr('plans.group.family'),
      _ => tr('plans.group.school'),
    };
    return AnimatedContainer(
      key: ValueKey('plan-card-${group.name}'),
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentSurface.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selectedHere ? color : StudentSurface.outline(context), width: selectedHere ? 3 : 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(_ar ? planPricePlaceholderAr : planPricePlaceholderEn,
            key: ValueKey('plan-price-${group.name}'),
            style: TextStyle(fontWeight: FontWeight.w800, color: StudentSurface.mutedInk(context))),
        if (group != PlanGroup.school)
          Text(_ar ? plans.first.seatsAr : plans.first.seatsEn, style: TextStyle(color: StudentSurface.mutedInk(context))),
        const Divider(height: 18),
        for (final f in planFeatures)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Icon(
                f.includedIn(group) ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 18,
                color: f.includedIn(group) ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _ar ? f.ar : f.en,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: f.includedIn(group) ? StudentSurface.ink(context) : StudentSurface.mutedInk(context),
                    decoration: f.includedIn(group) ? null : TextDecoration.lineThrough,
                  ),
                ),
              ),
            ]),
          ),
        const SizedBox(height: 10),
        if (group == PlanGroup.school) ...[
          Text(tr('plans.schoolTiers'), style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          for (final p in plans)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton(
                key: ValueKey('plan-choose-${p.id}'),
                onPressed: () => _choose(p.id),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _plan == p.id ? color.withValues(alpha: 0.12) : null,
                  side: BorderSide(color: color, width: _plan == p.id ? 2.5 : 1),
                ),
                child: Column(children: [
                  Text(_ar ? p.nameAr : p.nameEn, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
                  Text('${_ar ? p.seatsAr : p.seatsEn} · ${_ar ? planPricePlaceholderAr : planPricePlaceholderEn}',
                      style: const TextStyle(fontSize: 12)),
                ]),
              ),
            ),
        ] else
          FilledButton(
            key: ValueKey('plan-choose-${plans.first.id}'),
            onPressed: () => _choose(plans.first.id),
            style: FilledButton.styleFrom(backgroundColor: color),
            child: Text(_plan == plans.first.id ? '✓ ${tr('plans.chosen')}' : tr('plans.choose')),
          ),
      ]),
    );
  }

  Widget _form(BuildContext context) {
    final plan = _selected!;
    final needsCount = plan.group != PlanGroup.individual;
    return Form(
      key: _formKey,
      child: Container(
        key: const ValueKey('plans-form'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: StudentSurface.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF59E0B), width: 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${tr('plans.form.title')}: ${_ar ? plan.nameAr : plan.nameEn}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('plans-name'),
            controller: _name,
            decoration: InputDecoration(labelText: tr('plans.form.name'), border: const OutlineInputBorder()),
            validator: (v) => (v ?? '').trim().length < 2 ? tr('plans.form.required') : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('plans-grade'),
            controller: _grade,
            decoration: InputDecoration(labelText: tr('plans.form.grade'), border: const OutlineInputBorder()),
          ),
          if (needsCount) ...[
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey('plans-students'),
              controller: _students,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: tr('plans.form.students'), border: const OutlineInputBorder()),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim()) ?? 0;
                if (plan.group == PlanGroup.family && n < 3) return tr('plans.form.familyMin');
                if (plan.group == PlanGroup.school && n < 1) return tr('plans.form.required');
                return null;
              },
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('plans-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: tr('plans.form.phone'), border: const OutlineInputBorder()),
            validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 8 ? tr('plans.form.phoneInvalid') : null,
          ),
          const SizedBox(height: 14),
          if (_sent)
            Container(
              key: const ValueKey('plans-sent'),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(12)),
              child: Text(tr('plans.sent'),
                  textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
            ),
          FilledButton.icon(
            key: const ValueKey('plans-submit'),
            onPressed: _sending || _sent ? null : _submit,
            icon: const Icon(Icons.send_rounded),
            label: Text(tr('plans.submit')),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('plans-whatsapp'),
            onPressed: _whatsapp,
            icon: const Icon(Icons.chat_rounded),
            label: Text(tr('plans.whatsapp')),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: const Color(0xFF16A34A)),
          ),
        ]),
      ),
    );
  }
}
