import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role});
  final UserRole role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (username.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'أدخل اسم المستخدم وكلمة المرور');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    final ok = await context.read<AppState>().signIn(widget.role, username.text, password.text);
    if (!mounted) return;
    setState(() => loading = false);
    if (!ok) {
      setState(() => error = 'تعذر تسجيل الدخول، تحقق من البيانات');
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = ManaraColors.rolePrimary(widget.role);
    final gradient = ManaraColors.roleGradient(widget.role);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('تغيير نوع الحساب'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: gradient),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(.28),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo-badge.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('بوابة ${widget.role.label}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('سجّل الدخول لمتابعة رحلتك في منارة المعرفة', textAlign: TextAlign.center, style: TextStyle(color: ManaraColors.muted)),
                  const SizedBox(height: 30),
                  TextField(controller: username, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 14),
                  TextField(controller: password, obscureText: true, onSubmitted: (_) => submit(), decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline))),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                  const SizedBox(height: 22),
                   SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : submit,
                       style: FilledButton.styleFrom(
                         backgroundColor: color,
                         padding: const EdgeInsets.symmetric(vertical: 17),
                       ),
                      child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white)) : const Text('دخول إلى حسابي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (widget.role == UserRole.admin)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text('يمكن للمشرف تغيير كلمة المرور من إعدادات النظام.',
                          style: TextStyle(color: ManaraColors.muted, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}