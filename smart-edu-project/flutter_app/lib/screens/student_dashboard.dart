import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'video_hub.dart';
import 'lesson_library.dart';
import 'student_quizzes_screen.dart';
import 'chat_screen.dart';
import 'achievements_screen.dart';
import 'games_hub.dart';
import 'avatar_interaction_screen.dart';
import 'live_meetings_screen.dart';
import 'math_solver_screen.dart';
import 'student_tools_screen.dart';
import '../widgets/academic_scope_selector.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AvatarInteractionScreen())),
                child: CircleAvatar(radius: 28, backgroundColor: ManaraColors.lavender, child: Text(state.avatar, style: const TextStyle(fontSize: 28))),
              ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                   GestureDetector(
                     onTap: () => state.speech.greeting(),
                     child: const Text('مرحباً يا بطل!', style: TextStyle(color: ManaraColors.muted)),
                   ),
                  Text(state.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ])),
                _Pill(icon: '💎', text: '${state.gems}'),
                const SizedBox(width: 8),
                _Pill(icon: '🔥', text: '${state.streak}'),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [ManaraColors.deepPurple, ManaraColors.purple]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('رحلتك مستمرة يا بطل 🌟', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
                  Text('المستوى ${state.level}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: state.levelProgress, minHeight: 10, backgroundColor: Colors.white24, color: ManaraColors.orange),
                ),
                const SizedBox(height: 8),
                Text(
                  '${state.xp - ((state.level - 1) * 500)} / 500 XP للمستوى التالي',
                  style: const TextStyle(color: Colors.white70),
                ),
              ]),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
           sliver: SliverToBoxAdapter(
             child: _SectionTitle(
               title: 'ماذا ستتعلم اليوم؟',
               action: 'عرض الكل',
               onTap: () => Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (_) => const StudentToolsScreen(),
                 ),
               ),
             ),
           ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _ActionCard(title: 'دروسي', subtitle: 'تعلم خطوة بخطوة', icon: '📚', color: ManaraColors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LessonLibrary()))),
              _ActionCard(title: 'الألعاب', subtitle: 'ثلاث مغامرات تفاعلية', icon: '🎮', color: ManaraColors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GamesHub()))),
              _ActionCard(title: 'الفيديوهات', subtitle: 'شاهد وتعلم', icon: '🎬', color: ManaraColors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoHub()))),
              _ActionCard(title: 'الاختبارات', subtitle: 'اختبر معلوماتك', icon: '🧠', color: ManaraColors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentQuizzesScreen()))),
               _ActionCard(title: 'مساعد الدرس', subtitle: 'اسأل عن أي فكرة', icon: '✨', color: ManaraColors.deepPurple, onTap: () => _showLearningAssistant(context)),
               _ActionCard(title: 'حل المسائل', subtitle: 'خطوات رياضية مبسطة', icon: '🔢', color: ManaraColors.yellow, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MathSolverScreen()))),
              _ActionCard(title: 'التحديات', subtitle: 'اربح نقاطاً', icon: '⚡', color: ManaraColors.mint, onTap: () => _showQuests(context)),
              _ActionCard(
                title: 'المحادثة',
                subtitle: state.unreadMessagesForCurrentRole == 0
                    ? 'تحدث مع صفك'
                    : '${state.unreadMessagesForCurrentRole} رسائل جديدة',
                icon: '💬',
                color: ManaraColors.orange,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChatScreen())),
              ),
              _ActionCard(title: 'الاجتماعات', subtitle: 'تعلم مباشرة مع معلمك', icon: '📡', color: ManaraColors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveMeetingsScreen()))),
            ],
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _StudentAcademicPathCard(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
           sliver: SliverToBoxAdapter(
             child: _SectionTitle(
               title: 'تحديات اليوم',
               action: 'كل التحديات',
               onTap: () => _showQuests(context),
             ),
           ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: state.quests.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _QuestTile(quest: state.quests[i], completed: state.completedQuests.contains('quest-$i'), onTap: () => state.completeQuest(i)),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
           sliver: SliverToBoxAdapter(
             child: _SectionTitle(
               title: 'إنجازاتك',
               action: 'المعرض',
               onTap: () => Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (_) => const AchievementsScreen(),
                 ),
               ),
             ),
           ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          sliver: SliverToBoxAdapter(
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
              borderRadius: BorderRadius.circular(18),
               child: Row(
                 children: state.achievements.take(4).map((achievement) => Expanded(
                   child: Padding(
                     padding: const EdgeInsetsDirectional.only(end: 8),
                     child: Container(
                       padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                       decoration: BoxDecoration(
                         color: achievement.unlocked ? ManaraColors.lavender : Colors.grey.shade100,
                         borderRadius: BorderRadius.circular(18),
                       ),
                       child: Column(children: [
                         Text(achievement.icon, style: TextStyle(fontSize: 28, color: achievement.unlocked ? null : Colors.grey)),
                         const SizedBox(height: 5),
                         Text(achievement.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                       ]),
                     ),
                   ),
                 )).toList(),
              ),
             ),
           ),
        ),
      ],
    );
  }
}

class _StudentAcademicPathCard extends StatefulWidget {
  const _StudentAcademicPathCard();

  @override
  State<_StudentAcademicPathCard> createState() =>
      _StudentAcademicPathCardState();
}

class _StudentAcademicPathCardState extends State<_StudentAcademicPathCard> {
  AcademicScopeSelection selection = const AcademicScopeSelection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final paths = state.academicPathsForCurrentRole;
    final canOpen = selection.subject.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'اختر مسارك الدراسي',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ),
              const Text('🎓', style: TextStyle(fontSize: 28)),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'اختر المادة والفصل والترم والوحدة لتظهر لك موارد معلمك.',
            style: TextStyle(color: ManaraColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          AcademicScopeSelector(
            paths: paths,
            initialGrade: state.student?.primaryGrade ?? '',
            initialSelection: selection,
            onChanged: (next) => setState(() => selection = next),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canOpen
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LessonLibrary(initialSelection: selection),
                      ),
                    )
                : null,
            icon: const Icon(Icons.menu_book_rounded),
            label: const Text('عرض الدروس بهذا المسار'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: canOpen
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoHub(initialSelection: selection),
                      ),
                    )
                : null,
            icon: const Icon(Icons.video_library_outlined),
            label: const Text('عرض الفيديوهات بهذا المسار'),
          ),
        ],
      ),
    );
  }
}

void _showLearningAssistant(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _LearningAssistantSheet(),
  );
}

class _LearningAssistantSheet extends StatefulWidget {
  const _LearningAssistantSheet();

  @override
  State<_LearningAssistantSheet> createState() =>
      _LearningAssistantSheetState();
}

class _LearningAssistantSheetState extends State<_LearningAssistantSheet> {
  late final TextEditingController question;
  bool solving = false;
  String answer = '';

  @override
  void initState() {
    super.initState();
    question = TextEditingController();
  }

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  Future<void> _solve(AppState state, String lessonContent) async {
    setState(() => solving = true);
    final result = await state.learningAssistant.solveProblem(
      lesson: lessonContent,
      question: question.text,
    );
    if (!mounted) return;
    setState(() {
      solving = false;
      answer = result ??
          'لا يتوفر مساعد ذكي الآن. حاول مراجعة الفكرة في الدرس أو الاتصال بالإنترنت.';
    });
    if (result != null) {
      state.awardProblemSolved();
      state.speech.encouragement();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scopedLessons = state.lessonsForCurrentRole;
    final lesson = scopedLessons.isNotEmpty ? scopedLessons.first : null;
    final canSolve =
        lesson != null && question.text.trim().isNotEmpty && !solving;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'مساعد الدرس ✨',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              lesson == null
                  ? 'لا يوجد درس متاح حالياً'
                  : 'اسأل عن: ${lesson.title}',
              style: const TextStyle(color: ManaraColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: question,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'ما الذي تريد فهمه؟',
                hintText: 'اكتب سؤالك هنا...',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: canSolve
                  ? () => _solve(state, lesson!.content)
                  : null,
              icon: solving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(solving ? 'جاري التفكير...' : 'احصل على شرح'),
            ),
            if (answer.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ManaraColors.lavender,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(answer, style: const TextStyle(height: 1.6)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final String icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Text('$icon $text', style: const TextStyle(fontWeight: FontWeight.bold)));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              action,
              style: const TextStyle(
                color: ManaraColors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
  final String title, subtitle, icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: pressed ? .96 : 1,
        duration: const Duration(milliseconds: 120),
        child: InkWell(
          onTapDown: (_) => setState(() => pressed = true),
          onTapCancel: () => setState(() => pressed = false),
          onTap: () {
            setState(() => pressed = false);
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(color: widget.color.withOpacity(.12), borderRadius: BorderRadius.circular(22)),
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(widget.icon, key: ValueKey(widget.icon), style: const TextStyle(fontSize: 31)),
              ),
              const Spacer(),
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text(widget.subtitle, style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
            ]),
          ),
        ),
      );
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest, required this.completed, required this.onTap});
  final dynamic quest;
  final bool completed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: completed ? null : onTap, borderRadius: BorderRadius.circular(18), child: Ink(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: completed ? ManaraColors.lavender : Colors.white, borderRadius: BorderRadius.circular(18)), child: Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: ManaraColors.lavender, borderRadius: BorderRadius.circular(14)), child: Center(child: Text(completed ? '✅' : quest.icon, style: const TextStyle(fontSize: 24)))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(quest.title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 3), Text(completed ? 'تم الإنجاز' : quest.subtitle, style: const TextStyle(color: ManaraColors.muted, fontSize: 12))])), Text(completed ? 'مكتمل' : '+${quest.reward} XP', style: TextStyle(color: completed ? Colors.green : ManaraColors.purple, fontWeight: FontWeight.bold))])));
}

void _showQuests(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Consumer<AppState>(
      builder: (context, state, _) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Text(
                'تحديات اليوم',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'أنجز المهام واجمع XP وجواهر لفتح إنجازات جديدة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ManaraColors.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              ...state.quests.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _QuestTile(
                        quest: entry.value,
                        completed: state.completedQuests
                            .contains('quest-${entry.key}'),
                        onTap: () => state.completeQuest(entry.key),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}