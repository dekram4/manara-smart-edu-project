import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';
import 'demo_ui.dart';

/// التواصلُ مع المشرف من وضع الزائر — بدل شاشات الباقات والاشتراك.
///
/// ── لماذا لا باقاتٌ ولا أسعار ──
/// متجرا Google Play وApp Store لا يقبلان أن يدعو التطبيقُ إلى دفعٍ خارجهما.
/// والحسابُ الرسمي تفعّله الإدارة، فالزائرُ يُدلّ على المشرف وحده: واتساب
/// برسالةٍ ترحيبية عامّة، أو اتصالٌ هاتفيّ — بلا ذكرٍ لدفعٍ ولا باقة.
abstract final class GuestContact {
  /// الرقمُ المعتمد للإدارة.
  static const phone = '+966567502785';

  static Uri get whatsappUri => Uri.https('wa.me', '/966567502785', {'text': tr('guest.contact.greeting')});

  static final telUri = Uri(scheme: 'tel', path: phone);

  /// يفتح الرابط في تطبيقه (واتساب أو الهاتف)، ويقول إن تعذّر.
  static Future<bool> open(BuildContext context, Uri uri) async {
    StudentSoundService.instance.playTap();
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          key: const ValueKey('guest-contact-failed'),
          behavior: SnackBarBehavior.floating,
          content: Text(trf('guest.contact.failed', {'phone': phone})),
        ));
    }
    return opened;
  }
}

/// زرّا التواصل: واتساب، واتصالٌ هاتفيّ بالإدارة.
class GuestContactButtons extends StatelessWidget {
  const GuestContactButtons({super.key, this.height = 50});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DemoGradientButton(
        key: const ValueKey('guest-contact-whatsapp'),
        label: tr('guest.contact.whatsapp'),
        icon: Icons.chat_rounded,
        gradient: const LinearGradient(colors: [Color(0xFF25D366), Color(0xFF128C7E)]),
        foreground: Colors.white,
        height: height,
        onPressed: () => GuestContact.open(context, GuestContact.whatsappUri),
      ),
      const SizedBox(height: 10),
      DemoGradientButton(
        key: const ValueKey('guest-contact-call'),
        label: tr('guest.contact.call'),
        icon: Icons.call_rounded,
        height: height,
        onPressed: () => GuestContact.open(context, GuestContact.telUri),
      ),
    ]);
  }
}

/// «مخصص للطلاب المسجلين»: العنوان والوصف الإداريّ وزرّا التواصل، على خلفيةٍ
/// داكنة (داخل بطاقات الزائر البنفسجية).
class GuestContactPanel extends StatelessWidget {
  const GuestContactPanel({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('guest-contact-panel'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle)
          Text(
            tr('guest.registeredOnly.title'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: DemoPalette.goldLight, fontWeight: FontWeight.w900, fontSize: 17),
          ),
        if (showTitle) const SizedBox(height: 6),
        Text(
          tr('guest.registeredOnly.body'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.6),
        ),
        const SizedBox(height: 12),
        const GuestContactButtons(),
      ],
    );
  }
}

/// نافذةُ «مخصص للطلاب المسجلين»: ما يراه الزائر حين يلمس خدمةً مقفلة أو
/// يتجاوز حدّه. و[note] سطرٌ اختياريّ يقول ما انتهى هنا («انتهى سؤالا اليوم»).
Future<void> showGuestRegisteredOnly(BuildContext context, {String? note, Key? key}) {
  return showDemoDialog<void>(
    context: context,
    key: key ?? const ValueKey('guest-registered-only'),
    emoji: '🎓',
    title: tr('guest.registeredOnly.title'),
    body: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (note != null) ...[
        Text(note, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
      ],
      Text(tr('guest.registeredOnly.body'), textAlign: TextAlign.center, style: const TextStyle(height: 1.6)),
    ]),
    actions: [
      const GuestContactButtons(),
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('demo.ok')),
        ),
      ),
    ],
  );
}
