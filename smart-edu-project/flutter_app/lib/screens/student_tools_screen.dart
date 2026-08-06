import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'achievements_screen.dart';
import 'avatar_interaction_screen.dart';
import 'avatar_screen.dart';
import 'chat_screen.dart';
import 'games_hub.dart';
import 'lesson_library.dart';
import 'live_meetings_screen.dart';
import 'math_solver_screen.dart';
import 'student_quizzes_screen.dart';
import 'video_hub.dart';

class StudentToolsScreen extends StatelessWidget {
  const StudentToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = [
      _StudentTool(
        title: 'شرح الدرس',
        subtitle: 'اقرأ الدروس وشاهد موارد الشرح',
        icon: '📚',
        color: ManaraColors.purple,
        page: const LessonLibrary(),
      ),
      _StudentTool(
        title: 'التفاعل مع المعلم الذكي',
        subtitle: 'اسأل الشخصية التعليمية وتحدث معها',
        icon: '🤖',
        color: ManaraColors.blue,
        page: const AvatarInteractionScreen(),
      ),
      _StudentTool(
        title: 'حل المسائل',
        subtitle: 'خطوات رياضية مبسطة مع حل محلي',
        icon: '🔢',
        color: ManaraColors.yellow,
        page: const MathSolverScreen(),
      ),
      _StudentTool(
        title: 'الاختبارات',
        subtitle: 'اختبر فهمك وسجل تقدمك',
        icon: '🧠',
        color: ManaraColors.mint,
        page: const StudentQuizzesScreen(),
      ),
      _StudentTool(
        title: 'الدردشة',
        subtitle: state.unreadMessagesForCurrentRole == 0
            ? 'تواصل مع المعلمين والصف'
            : '${state.unreadMessagesForCurrentRole} رسائل جديدة',
        icon: '💬',
        color: ManaraColors.orange,
        page: const ChatScreen(),
      ),
      _StudentTool(
        title: 'الألعاب',
        subtitle: 'ذاكرة وسرعة وصح أو خطأ',
        icon: '🎮',
        color: ManaraColors.orange,
        page: const GamesHub(),
      ),
      _StudentTool(
        title: 'فيديوهات المعلم',
        subtitle: 'شاهد الدروس المرئية وتعلم',
        icon: '🎬',
        color: ManaraColors.blue,
        page: const VideoHub(),
      ),
      _StudentTool(
        title: 'الاجتماعات المباشرة',
        subtitle: 'انضم إلى شرح معلمك مباشرة',
        icon: '📡',
        color: ManaraColors.purple,
        page: const LiveMeetingsScreen(),
      ),
      _StudentTool(
        title: 'الإنجازات والجواهر',
        subtitle: 'تابع XP والمستوى والمكافآت',
        icon: '🏆',
        color: ManaraColors.orange,
        page: const AchievementsScreen(),
      ),
      _StudentTool(
        title: 'تخصيص الشخصية',
        subtitle: 'افتح Avatar جديداً باستخدام الجواهر',
        icon: '🎨',
        color: ManaraColors.mint,
        page: const AvatarScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'أدوات التعلم',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ManaraColors.deepPurple, ManaraColors.purple],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Text(state.avatar, style: const TextStyle(fontSize: 46)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'اختر مغامرتك التعليمية',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${state.xp} XP • ${state.gems} 💎 • المستوى ${state.level}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: _StudentToolTile(
                item: item,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => item.page),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentTool {
  const _StudentTool({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.page,
  });

  final String title;
  final String subtitle;
  final String icon;
  final Color color;
  final Widget page;
}

class _StudentToolTile extends StatefulWidget {
  const _StudentToolTile({required this.item, required this.onTap});

  final _StudentTool item;
  final VoidCallback onTap;

  @override
  State<_StudentToolTile> createState() => _StudentToolTileState();
}

class _StudentToolTileState extends State<_StudentToolTile> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AnimatedScale(
      scale: pressed ? .98 : 1,
      duration: const Duration(milliseconds: 120),
      child: InkWell(
        onTapDown: (_) => setState(() => pressed = true),
        onTapCancel: () => setState(() => pressed = false),
        onTap: () {
          setState(() => pressed = false);
          widget.onTap();
        },
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: item.color.withOpacity(.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 57,
                height: 57,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(.13),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: Text(item.icon, style: const TextStyle(fontSize: 30)),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        color: ManaraColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_back_ios_new_rounded, color: item.color),
            ],
          ),
        ),
      ),
    );
  }
}