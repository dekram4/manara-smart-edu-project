import 'package:flutter/material.dart';

import '../models/student_profile.dart';

/// The legacy web chat is backed by permissive shared message tables.
///
/// This screen intentionally does not query those tables from a student device:
/// client-side filtering would still let an attacker read another student's
/// messages. It provides a clear, honest state until server-side authorization
/// is available.
class StudentChatScreen extends StatelessWidget {
  const StudentChatScreen({required this.profile, super.key});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    final accountDisabled = !profile.canAccessChat;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        appBar: AppBar(title: const Text('دردشة منارة')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      accountDisabled
                          ? Icons.lock_outline_rounded
                          : Icons.privacy_tip_outlined,
                      size: 62,
                      color: const Color(0xFF0B8693),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      accountDisabled
                          ? 'الدردشة غير مفعلة لحسابك'
                          : 'الدردشة محمية قبل تفعيلها',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      accountDisabled
                          ? 'يمكن للمعلم أو المشرف تفعيل الدردشة لحسابك عند الحاجة.'
                          : 'لن نعرض رسائل أو زملاء من جهاز الطالب قبل تفعيل وصول آمن يضمن خصوصية كل محادثة.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        height: 1.6,
                        color: Color(0xFF49617C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('العودة للبوابة'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}