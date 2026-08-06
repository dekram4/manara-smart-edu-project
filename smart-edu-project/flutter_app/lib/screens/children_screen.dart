import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'reports_screen.dart';

class ChildrenScreen extends StatelessWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final children = state.studentsForCurrentRole;
    return Scaffold(
      appBar: AppBar(title: const Text('أبنائي', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const Text('تابع الحسابات والتقدم الدراسي لأبنائك', style: TextStyle(color: ManaraColors.muted, fontSize: 16)),
          const SizedBox(height: 20),
          ...children.map((child) => Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 28, backgroundColor: ManaraColors.lavender, child: Text('🎒', style: TextStyle(fontSize: 25))),
                      const SizedBox(width: 13),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(child.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        const SizedBox(height: 4),
                        Text(child.primaryGrade, style: const TextStyle(color: ManaraColors.muted)),
                      ])),
                      OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportsScreen(studentId: child.id),
                          ),
                        ),
                        child: const Text('التقرير'),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => showAddChildDialog(context),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('إضافة ابن'),
          ),
        ],
      ),
    );
  }
}

Future<void> showAddChildDialog(BuildContext context) async {
  final name = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  final studentId = TextEditingController();
  final state = context.read<AppState>();
  final grades = {
    'الصف الرابع',
    ...state.academicUnits.map((item) => item.grade),
  }.where((grade) => grade.trim().isNotEmpty).toList()
    ..sort();
  var selectedGrade = grades.first;
  String? error;
  await showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setLocalState) => AlertDialog(
        title: const Text('إضافة ابن'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'اسم الطالب'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: username,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'اسم المستخدم'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: studentId,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'رقم الطالب / الهوية'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور (6 أحرف على الأقل)',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedGrade,
              decoration: const InputDecoration(labelText: 'الصف الدراسي'),
              items: grades
                  .map((grade) =>
                      DropdownMenuItem(value: grade, child: Text(grade)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setLocalState(() => selectedGrade = value);
              },
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  error!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final missingName = name.text.trim().isEmpty;
              final missingUsername = username.text.trim().isEmpty;
              final missingStudentId = studentId.text.trim().isEmpty;
              if (missingName ||
                  missingUsername ||
                  missingStudentId ||
                  password.text.length < 6) {
                setLocalState(() {
                  error = password.text.length < 6
                      ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
                      : 'أكمل اسم الطالب واسم المستخدم ورقم الطالب';
                });
                return;
              }
              state.addStudent(
                name: name.text.trim(),
                username: username.text.trim(),
                grade: selectedGrade,
                password: password.text,
                studentIdNumber: studentId.text.trim(),
                parentId: state.guardian?.id,
                parentPhoneNumber: state.guardian?.phoneNumber ?? '',
              );
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  username.dispose();
  password.dispose();
  studentId.dispose();
}