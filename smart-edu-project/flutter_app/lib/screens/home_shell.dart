import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'student_dashboard.dart';
import 'role_dashboard.dart';
import 'management_hub.dart';
import 'account_screen.dart';
import 'achievements_screen.dart';
import 'parent_setup_screen.dart';
import 'teacher_setup_screen.dart';
import 'reports_screen.dart';
import 'student_tools_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  bool _setupPrompted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (!_setupPrompted &&
        state.role == UserRole.guardian &&
        state.guardian?.mustChangePassword == true) {
      _setupPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ParentSetupScreen()),
        );
      });
    }
    if (!_setupPrompted &&
        state.role == UserRole.teacher &&
        state.teacher?.mustChangePassword == true) {
      _setupPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TeacherSetupScreen()),
        );
      });
    }
  }

  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final isStudent = state.role == UserRole.student;
        final pages = isStudent
            ? [
                const StudentDashboard(),
                const StudentToolsScreen(),
                const AchievementsScreen(),
                const AccountScreen(),
              ]
            : [
                RoleDashboard(role: state.role!),
                ManagementHub(role: state.role!, section: 'القوائم'),
                const ReportsScreen(),
                const AccountScreen(),
              ];
        final selectedTab = state.selectedTab >= 0 &&
                state.selectedTab < pages.length
            ? state.selectedTab
            : 0;
        return Scaffold(
          body: SafeArea(child: pages[selectedTab]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedTab,
            onDestinationSelected: state.setTab,
            backgroundColor: Colors.white,
            indicatorColor: ManaraColors.lavender,
            destinations: [
              NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: 'الرئيسية'),
              NavigationDestination(icon: const Icon(Icons.auto_awesome_outlined), selectedIcon: const Icon(Icons.auto_awesome), label: isStudent ? 'أدوات التعلم' : 'القوائم'),
              NavigationDestination(icon: const Icon(Icons.emoji_events_outlined), selectedIcon: const Icon(Icons.emoji_events), label: isStudent ? 'الإنجازات' : 'التقارير'),
              const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
            ],
          ),
        );
      },
    );
  }
}