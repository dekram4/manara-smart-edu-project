import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ParentSetupScreen extends StatefulWidget {
  const ParentSetupScreen({super.key});

  @override
  State<ParentSetupScreen> createState() => _ParentSetupScreenState();
}

class _ParentSetupScreenState extends State<ParentSetupScreen> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  String? error;

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (password.text.length < 6) {
      setState(() => error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (password.text != confirmation.text) {
      setState(() => error = 'تأكيد كلمة المرور غير مطابق');
      return;
    }
    final state = context.read<AppState>();
    final guardian = state.guardian;
    if (guardian == null) return;
    final changed = await state.completeGuardianSetup(
      guardianId: guardian.id,
      newPassword: password.text,
    );
    if (!mounted) return;
    if (!changed) {
      setState(() => error = 'تعذر حفظ كلمة المرور، حاول مرة أخرى');
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('إعداد الحساب', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ManaraColors.deepPurple, ManaraColors.purple],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرحباً بك في منارة المعرفة',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('غيّر كلمة المرور المؤقتة قبل متابعة حساب أبنائك.',
                    style: TextStyle(color: Colors.white70, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: confirmation,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'تأكيد كلمة المرور',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('حفظ ومتابعة'),
          ),
        ],
      ),
    );
  }
}