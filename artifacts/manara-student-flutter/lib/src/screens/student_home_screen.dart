import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/student_profile.dart';
import '../services/student_auth_service.dart';
import '../widgets/manara_logo.dart';
import 'login_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    required this.profile,
    required this.authService,
    super.key,
  });

  final StudentProfile profile;
  final StudentAuthService authService;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final _audioPlayer = AudioPlayer();
  bool _showGamePreview = false;

  @override
  void initState() {
    super.initState();
    _playWelcome();
  }

  Future<void> _playWelcome() async {
    try {
      await _audioPlayer.play(
        AssetSource('audio/manara-arabic-student-welcome.mp3'),
      );
    } catch (_) {
      // Audio is optional; the home screen remains usable if a platform blocks it.
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await widget.authService.client.auth.signOut();
    } catch (_) {
      // Custom student records do not always create an Auth session.
    }
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          authService: widget.authService,
          initializationError: null,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.isStudent) {
      return const _StudentOnlyGuard();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'بوابة الطالب',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _signOut,
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WelcomeCard(profile: widget.profile)
                  .animate()
                  .fadeIn(duration: 450.ms)
                  .slideY(begin: 0.12),
              const SizedBox(height: 16),
              const Text(
                'ماذا تريد أن تفعل اليوم؟',
                style: TextStyle(
                  color: Color(0xFF0E1B2A),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.play_lesson_rounded,
                      title: 'شرح الدرس',
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.emoji_events_rounded,
                      title: 'إنجازاتي',
                      color: Color(0xFF0B8693),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _GameCard(
                onPressed: () => setState(() => _showGamePreview = !_showGamePreview),
              ),
              if (_showGamePreview) ...[
                const SizedBox(height: 12),
                const _InteractiveGamePreview(),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFD7E3EF)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF0B8693)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'تم التحقق من دور الحساب: طالب. هذه البوابة لا تسمح بدخول الأدوار الأخرى.',
                        style: TextStyle(
                          color: Color(0xFF274E76),
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B8693), Color(0xFF274E76)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330B8693),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const ManaraLogo(size: 72),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أهلًا بك في منارة المعرفة',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (profile.grade != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'الصف: ${profile.grade}',
                    style: const TextStyle(
                      color: Color(0xFFCDF6F5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withAlpha(55)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E1B2A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0E1B2A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1B2A),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(
          children: [
            Icon(Icons.sports_esports_rounded, color: Color(0xFF63D9DA), size: 38),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'عالم الترفيه',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'اضغط لعرض مساحة الألعاب التفاعلية',
                    style: TextStyle(
                      color: Color(0xFF9EEBEA),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}

class _InteractiveGamePreview extends StatelessWidget {
  const _InteractiveGamePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF081426),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF63D9DA).withAlpha(90)),
      ),
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('about:blank')),
        initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          javaScriptEnabled: false,
        ),
        onWebViewCreated: (controller) {
          controller.loadData(
            data: '''
              <html dir="rtl"><body style="margin:0;background:#081426;color:#cdf6f5;font-family:Arial;text-align:center;padding:45px 18px">
              <h2>مساحة الألعاب التفاعلية</h2><p>سيتم تحميل الألعاب المرتبطة بالدرس هنا.</p>
              </body></html>
            ''',
          );
        },
      ),
    );
  }
}

class _StudentOnlyGuard extends StatelessWidget {
  const _StudentOnlyGuard();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            studentOnlyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF9F1239),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}