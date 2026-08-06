import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import '../services/audio_service.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roles = <_RoleOption>[
      const _RoleOption(UserRole.student, 'طالب', 'تعلم، تفاعل، واختبر', ManaraColors.primary),
      const _RoleOption(UserRole.guardian, 'ولي أمر', 'تابع مستوى أبنائك', ManaraColors.accent),
      const _RoleOption(UserRole.teacher, 'معلم', 'أدر طلابك ومحتواك', ManaraColors.secondary),
      const _RoleOption(UserRole.admin, 'مشرف', 'إدارة النظام والمحتوى', ManaraColors.admin),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Column(
                children: [
                  ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(.0, .5, curve: Curves.elasticOut),
                    ),
                    child: Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [ManaraColors.primary, ManaraColors.pink],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ManaraColors.primary.withOpacity(.28),
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
                  ),
                  const SizedBox(height: 18),
                  const Text('منارة المعرفة', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: ManaraColors.ink)),
                  const SizedBox(height: 6),
                  const Text('نتعلم، نلعب، ونكبر معاً', style: TextStyle(fontSize: 16, color: ManaraColors.muted)),
                  const SizedBox(height: 36),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('اختر مساحتك للبدء', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 14),
                  ...roles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final start = (.18 + index * .14).clamp(0.0, .72).toDouble();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, .24),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _controller,
                          curve: Interval(
                            start,
                            (start + .28).clamp(0.0, 1.0).toDouble(),
                            curve: Curves.easeOutBack,
                          ),
                        )),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _controller,
                            curve: Interval(
                              start,
                              (start + .25).clamp(0.0, 1.0).toDouble(),
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: _RoleCard(
                            role: item.role,
                            title: item.title,
                            subtitle: item.subtitle,
                            color: item.color,
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const Text('تطبيق أصلي لأندرويد و iPhone و iPad', style: TextStyle(color: ManaraColors.muted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption {
  const _RoleOption(this.role, this.title, this.subtitle, this.color);
  final UserRole role;
  final String title;
  final String subtitle;
  final Color color;
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.title, required this.subtitle, required this.color});
  final UserRole role;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () async {
        await ManaraAudioService.instance.playTap();
        await context.read<AppState>().chooseRole(role);
        if (context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen(role: role)));
        }
      },
      child: Ink(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(.72)],
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: color.withOpacity(.93),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Hero(
                tag: 'role-icon-${role.name}',
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.2),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Text(
                      role.icon,
                      style: const TextStyle(fontSize: 34),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 21,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}