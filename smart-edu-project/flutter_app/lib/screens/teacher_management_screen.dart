import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class TeacherManagementScreen extends StatelessWidget {
  const TeacherManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المعلمين', style: TextStyle(fontWeight: FontWeight.w900))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherEditorScreen())),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة معلم'),
        backgroundColor: ManaraColors.purple,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
          itemCount: state.teachers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            final teacher = state.teachers[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(radius: 28, backgroundColor: ManaraColors.lavender, child: Text('👩‍🏫', style: TextStyle(fontSize: 24))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      const SizedBox(height: 5),
                      Text('اسم المستخدم: ${teacher.username}', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
                      Text('رقم الهوية: ${teacher.teacherId}', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
                      Text('التخصص: ${teacher.subject ?? 'غير محدد'}', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
                      Text('المنشئ: ${teacher.createdBy}', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
                    ]),
                  ),
                  Column(children: [
                    IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherEditorScreen(teacher: teacher))), icon: const Icon(Icons.edit_outlined, color: ManaraColors.blue)),
                    IconButton(onPressed: () => _resetPassword(context, state, teacher), icon: const Icon(Icons.lock_reset_outlined, color: ManaraColors.orange)),
                    IconButton(
                      onPressed: () => _delete(context, state, teacher.id),
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                  ]),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _resetPassword(BuildContext context, AppState state, TeacherProfile teacher) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إعادة تعيين كلمة المرور'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل')),
                );
                return;
              }
              state.resetTeacherPassword(teacher.id, controller.text);
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _delete(BuildContext context, AppState state, String id) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المعلم؟'),
        content: const Text('سيتم حذف الحساب من قائمة المعلمين.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              state.removeTeacher(id);
              Navigator.pop(context);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class TeacherEditorScreen extends StatefulWidget {
  const TeacherEditorScreen({super.key, this.teacher});
  final TeacherProfile? teacher;

  @override
  State<TeacherEditorScreen> createState() => _TeacherEditorScreenState();
}

class _TeacherEditorScreenState extends State<TeacherEditorScreen> {
  late final TextEditingController name;
  late final TextEditingController username;
  late final TextEditingController password;
  late final TextEditingController teacherId;
  late final TextEditingController subject;

  @override
  void initState() {
    super.initState();
    final teacher = widget.teacher;
    name = TextEditingController(text: teacher?.name ?? '');
    username = TextEditingController(text: teacher?.username ?? '');
    password = TextEditingController();
    teacherId = TextEditingController(text: teacher?.teacherId ?? '');
    subject = TextEditingController(text: teacher?.subject ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    password.dispose();
    teacherId.dispose();
    subject.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.teacher == null ? 'إضافة معلم جديد' : 'تعديل بيانات المعلم', style: const TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _field(name, 'اسم المعلم *', Icons.person_outline),
            _field(username, 'اسم المستخدم *', Icons.account_circle_outlined),
            _field(password, widget.teacher == null ? 'كلمة المرور *' : 'كلمة مرور جديدة (اختياري)', Icons.lock_outline, obscure: true),
            _field(teacherId, 'رقم الهوية / رقم المعلم *', Icons.badge_outlined),
            _field(subject, 'التخصص أو المادة', Icons.menu_book_outlined),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: ManaraColors.lavender, borderRadius: BorderRadius.circular(18)),
              child: const Text('سيتم ربط محتوى المعلم وإعداداته الأكاديمية بحسابه تلقائياً.', style: TextStyle(color: ManaraColors.deepPurple, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('حفظ بيانات المعلم')),
          ],
        ),
      );

  Widget _field(TextEditingController controller, String label, IconData icon, {bool obscure = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: TextField(controller: controller, obscureText: obscure, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon))),
      );

  void _save() {
    if ([name, username, teacherId].any((item) => item.text.trim().isEmpty) || (widget.teacher == null && password.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل الحقول المطلوبة')));
      return;
    }
    if (password.text.isNotEmpty && password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل')),
      );
      return;
    }
    final state = context.read<AppState>();
    if (!state.usernameAvailable(username.text, exceptId: widget.teacher?.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اسم المستخدم مستخدم مسبقاً')));
      return;
    }
    if (!state.identityAvailable(teacherId.text, exceptId: widget.teacher?.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم الهوية أو رقم المعلم مستخدم مسبقاً')));
      return;
    }
    if (widget.teacher == null) {
      state.addTeacher(
        name: name.text.trim(),
        username: username.text.trim(),
        subject: subject.text.trim(),
        password: password.text,
        teacherId: teacherId.text.trim(),
      );
    } else {
      state.updateTeacher(
        id: widget.teacher!.id,
        name: name.text.trim(),
        username: username.text.trim(),
        subject: subject.text.trim(),
        teacherId: teacherId.text.trim(),
        password: password.text,
      );
    }
    Navigator.pop(context);
  }
}