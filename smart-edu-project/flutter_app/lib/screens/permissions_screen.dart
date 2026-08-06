import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final labels = <String, String>{
    'manageContent': 'إدارة المحتوى',
    'createStudents': 'إنشاء الطلاب',
    'editStudents': 'تعديل الطلاب',
    'deleteStudents': 'حذف الطلاب',
    'createGuardians': 'إنشاء أولياء الأمور',
    'manageTeachers': 'إدارة المعلمين',
    'manageQuizzes': 'إدارة الاختبارات',
    'viewReports': 'عرض التقارير',
    'issueCertificates': 'إصدار الشهادات',
    'privateChat': 'المحادثة الخاصة',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الصلاحيات', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('تحكم في صلاحيات المعلمين داخل المنصة', style: TextStyle(color: ManaraColors.muted, fontSize: 16)),
            const SizedBox(height: 20),
             ...labels.entries.map((entry) => SwitchListTile(
                   value: context.watch<AppState>().permissions[entry.key] ?? false,
                   onChanged: (value) => context.read<AppState>().setPermission(entry.key, value),
                   title: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                  activeColor: ManaraColors.purple,
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                )),
          ],
        ),
      );
}