import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../theme/student_theme.dart';
import '../widgets/manara_logo.dart';
import '../widgets/student_experience.dart';
import 'login_screen.dart';
import 'student_home_screen.dart';

class StudentStartupScreen extends StatefulWidget {
  const StudentStartupScreen({
    required this.authService,
    required this.initializationError,
    required this.apiBaseUrl,
    super.key,
  });

  final StudentAuthService? authService;
  final String? initializationError;
  final String apiBaseUrl;

  @override
  State<StudentStartupScreen> createState() => _StudentStartupScreenState();
}

class _StudentStartupScreenState extends State<StudentStartupScreen> {
  @override
  void initState() {
    super.initState();
    _resolveDestination();
  }

  Future<void> _resolveDestination() async {
    final minimumSplash = Future<void>.delayed(
      const Duration(milliseconds: 1200),
    );
    final authService = widget.authService;
    StudentProfile? profile;
    if (authService != null) {
      try {
        profile = await authService.restoreActiveStudentSession();
      } catch (_) {
        profile = null;
      }
    }
    await minimumSplash;
    if (!mounted) return;

    final destination = profile != null && authService != null
        ? StudentHomeScreen(
            profile: profile,
            authService: authService,
            apiBaseUrl: widget.apiBaseUrl,
          )
        : LoginScreen(
            authService: authService,
            initializationError: widget.initializationError,
            apiBaseUrl: widget.apiBaseUrl,
          );
    await Navigator.of(context).pushReplacement(
      StudentPageRoute<void>(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF312E81),
                  Color(0xFF4F46E5),
                  Color(0xFF0EA5E9),
                ],
              ),
            ),
          ),
          const StudentAmbientOrbs(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 390),
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.36)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55312E81),
                        blurRadius: 36,
                        offset: Offset(0, 18),
                      ),
                      BoxShadow(
                        color: Color(0x4422D3EE),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ManaraLogo(size: 118)
                          .animate()
                          .fadeIn(duration: 420.ms)
                          .scale(
                            begin: const Offset(0.72, 0.72),
                            duration: 780.ms,
                            curve: Curves.easeOutBack,
                          ),
                      const SizedBox(height: 22),
                      Text(
                        'مَنارة',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'MANARA SMART EDU',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: Color(0xFFDFF8FF),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const LinearProgressIndicator(
                        minHeight: 5,
                        color: StudentPalette.orange,
                        backgroundColor: Color(0x33FFFFFF),
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'استعد لرحلة تعلم ممتعة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}