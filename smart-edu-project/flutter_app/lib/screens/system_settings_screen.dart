import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  bool chatEnabled = true;
  bool allowGradeChange = false;
  double passingScore = 60;
  final maxChildren = TextEditingController(text: '5');
  final contact = TextEditingController();
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    maxChildren.dispose();
    contact.dispose();
    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    if (!mounted) return;
    setState(() {
      chatEnabled = state.chatEnabled;
      allowGradeChange = state.allowGradeChange;
      passingScore = state.passingScore;
      maxChildren.text = '${state.maxChildren}';
      contact.text = state.adminContact;
    });
  }

  Future<void> _save() async {
    await context.read<AppState>().saveSystemSettings(
          chatEnabled: chatEnabled,
          allowGradeChange: allowGradeChange,
          passingScore: passingScore,
          maxChildren: int.tryParse(maxChildren.text) ?? 5,
          adminContact: contact.text,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات النظام')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('إعدادات النظام', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('تحكم في الخصائص العامة للمنصة', style: TextStyle(color: ManaraColors.muted, fontSize: 16)),
            const SizedBox(height: 18),
            _settingSwitch('تفعيل الدردشة الجماعية', 'السماح للطلاب بالتواصل في غرف الدردشة', chatEnabled, (value) => setState(() => chatEnabled = value)),
            _settingSwitch('السماح بتغيير الصف', 'تمكين الطلاب من تغيير صفهم الدراسي', allowGradeChange, (value) => setState(() => allowGradeChange = value)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('درجة النجاح (%)', style: TextStyle(fontWeight: FontWeight.w900)),
                Slider(value: passingScore, min: 0, max: 100, divisions: 20, label: '${passingScore.round()}%', onChanged: (value) => setState(() => passingScore = value)),
                Center(child: Text('${passingScore.round()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ManaraColors.purple))),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(controller: maxChildren, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الحد الأقصى لأبناء ولي الأمر')),
            const SizedBox(height: 12),
            TextField(controller: contact, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم تواصل المشرف')),
            const SizedBox(height: 22),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('حفظ التغييرات')),
            const SizedBox(height: 28),
            const Text('أمان حساب المشرف',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('غيّر كلمة المرور بعد تسجيل الدخول. لا يتم حفظها كنص صريح.',
                style: TextStyle(color: ManaraColors.muted)),
            const SizedBox(height: 12),
            TextField(
              controller: currentPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور الحالية'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة (6 أحرف على الأقل)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور الجديدة'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _changeAdminPassword,
              icon: const Icon(Icons.lock_reset),
              label: const Text('تغيير كلمة المرور'),
            ),
          ],
        ),
      );

  Future<void> _changeAdminPassword() async {
    final state = context.read<AppState>();
    final changed = await state.changeAdminPassword(
      currentPassword: currentPassword.text,
      newPassword: newPassword.text,
      confirmation: confirmPassword.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(changed
            ? 'تم تغيير كلمة مرور المشرف'
            : 'تعذر تغيير كلمة المرور: تحقق من الحالية والتطابق وطول الجديدة'),
      ),
    );
    if (changed) {
      currentPassword.clear();
      newPassword.clear();
      confirmPassword.clear();
    }
  }

  Widget _settingSwitch(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          activeColor: ManaraColors.purple,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle, style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
        ),
      );
}