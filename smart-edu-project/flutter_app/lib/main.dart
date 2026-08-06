import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/role_select_screen.dart';
import 'screens/home_shell.dart';
import 'services/app_bootstrap.dart';
import 'services/supabase_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SupabaseManaraRepository? remoteRepository = await AppBootstrap.initializeSupabase();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(remoteRepository: remoteRepository),
      child: const ManaraApp(),
    ),
  );
}

class ManaraApp extends StatefulWidget {
  const ManaraApp({super.key});

  @override
  State<ManaraApp> createState() => _ManaraAppState();
}

class _ManaraAppState extends State<ManaraApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppState>().handleAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (_, state, __) => MaterialApp(
        title: 'منارة المعرفة',
        debugShowCheckedModeBanner: false,
        theme: buildManaraTheme(role: state.role ?? state.selectedRole),
        locale: const Locale('ar'),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: Builder(
          builder: (_) {
          if (!state.ready) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return state.role == null ? const RoleSelectScreen() : const HomeShell();
          },
        ),
      ),
    );
  }
}