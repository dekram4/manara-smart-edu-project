import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/widgets/demo_lock.dart';
import 'package:manara_student/src/widgets/guest_contact.dart';

/// وضعُ الزائر متوافقٌ مع المتجرين: «صلاحيات الحساب غير مفعّلة» وزرّا التواصل مع
/// المشرف بالرقم المعتمد — ولا باقةٌ ولا سعرٌ ولا دفع.
void main() {
  final forbidden = RegExp(r'اشتراك|باقة|الباقات|سعر|أسعار|ريال|دفع|تحويل|subscri|plan|price|pay', caseSensitive: false);

  test('رابطا التواصل: واتساب برسالةٍ ترحيبية عامّة، والاتصالُ بالرقم المعتمد', () {
    final wa = GuestContact.whatsappUri;
    expect(wa.scheme, 'https');
    expect(wa.host, 'wa.me');
    expect(wa.path, '/966567502785');
    expect(wa.queryParameters['text'], 'السلام عليكم، أرغب في الاستفسار عن تفعيل الحساب الرسمي في منصة منارة');
    expect(GuestContact.telUri.toString(), 'tel:+966567502785');
    expect(forbidden.hasMatch(wa.queryParameters['text']!), isFalse);
  });

  test('النصوصُ الإدارية كما اعتُمدت، وبلا إشارةٍ إلى دفع', () {
    expect(tr('guest.registeredOnly.title'), 'صلاحيات الحساب غير مفعّلة');
    expect(
      tr('guest.registeredOnly.body'),
      'هذه الخدمة تتطلب تفعيل الصلاحيات وامتلاك حساب رسمي لابنك أو ابنتك، علماً أن المحتوى المتاح حالياً عام لجميع الصفوف. يرجى التواصل مع المشرف لتحديد الصف والمواد والدروس المطلوبة، وإنشاء الحساب ومنح الصلاحيات اللازمة للوصول إلى جميع الدروس التي يحتاجها ابنك أو ابنتك.',
    );
    expect(tr('guest.contact.whatsapp'), 'التواصل مع المشرف عبر واتساب');
    expect(tr('guest.contact.call'), 'اتصال هاتفي بالإدارة');
    for (final key in [
      'demo.getAccount',
      'demo.lockedInDemo',
      'demo.localOnly',
      'demo.chat.textLimit',
      'demo.chat.voiceLimit',
      'demo.chat.imagesBody',
      'demo.solver.locked',
      'demo.duel.dailyDone',
      'demo.duel.more',
      'demo.teaser.solver',
      'demo.teaser.meeting',
      'demo.teaser.challenge',
      'demo.teaser.tutor',
    ]) {
      expect(forbidden.hasMatch(tr(key)), isFalse, reason: key);
    }
  });

  testWidgets('لمسُ المقفل: نافذةُ «صلاحيات الحساب غير مفعّلة» بزرّي واتساب والاتصال', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDemoLocked(context, message: tr('demo.solver.locked')),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('demo-locked')), findsOneWidget);
    expect(find.text('صلاحيات الحساب غير مفعّلة'), findsOneWidget);
    expect(find.text(tr('guest.registeredOnly.body')), findsOneWidget);
    expect(find.text(tr('demo.solver.locked')), findsOneWidget);
    expect(find.byKey(const ValueKey('guest-contact-whatsapp')), findsOneWidget);
    expect(find.byKey(const ValueKey('guest-contact-call')), findsOneWidget);
    expect(find.textContaining(forbidden), findsNothing);
  });

  testWidgets('بطاقةُ انتهاء التجربة: الرسالةُ ثم النصّ الإداريّ وزرّا التواصل', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: DemoLockedCard(message: tr('demo.duel.dailyDone'))),
      ),
    ));
    expect(find.byKey(const ValueKey('guest-contact-panel')), findsOneWidget);
    expect(find.text('صلاحيات الحساب غير مفعّلة'), findsOneWidget);
    expect(find.text('التواصل مع المشرف عبر واتساب'), findsOneWidget);
    expect(find.text('اتصال هاتفي بالإدارة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
