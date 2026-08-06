import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class MathSolverScreen extends StatefulWidget {
  const MathSolverScreen({super.key});

  @override
  State<MathSolverScreen> createState() => _MathSolverScreenState();
}

class _MathSolverScreenState extends State<MathSolverScreen> {
  static const samples = [
    '12 + 7 × 3 - 5 = ?',
    'اجمع 5, 8, 12, 3, 9',
    'ما ناتج 25% من 200 ؟',
    '2³ + 3² = ?',
  ];

  final problemController = TextEditingController();
  final history = <_MathHistoryItem>[];
  String? solution;
  bool solving = false;

  @override
  void dispose() {
    problemController.dispose();
    super.dispose();
  }

  Future<void> solve() async {
    final problem = problemController.text.trim();
    if (problem.isEmpty || solving) return;
    setState(() {
      solving = true;
      solution = null;
    });
    final result = await context.read<AppState>().learningAssistant.solveMathProblem(
          problem: problem,
        );
    if (!mounted) return;
    setState(() {
      solving = false;
      solution = result ??
          'لم أتمكن من فهم هذه المسألة. جرّب كتابة عملية مثل: 12 + 7 × 3';
      if (result != null) {
        history.insert(
          0,
          _MathHistoryItem(problem: problem, solution: result),
        );
        if (history.length > 10) history.removeLast();
      }
    });
    if (result != null) {
      context.read<AppState>().awardProblemSolved();
      context.read<AppState>().speech.encouragement();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ حل المسائل', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ManaraColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'اكتب المسألة الرياضية:',
                  style: TextStyle(
                    color: ManaraColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: problemController,
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    hintText: 'مثال: 12 + 7 × 3 = ؟',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: problemController.text.trim().isEmpty || solving
                      ? null
                      : solve,
                  icon: solving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.flash_on),
                  label: Text(solving ? 'جاري الحل...' : 'حل المسألة (+15 XP)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '📝 أمثلة جاهزة',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...samples.map(
            (sample) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: ManaraColors.border),
                ),
                title: Text(sample, textAlign: TextAlign.right),
                trailing: const Icon(
                  Icons.arrow_back,
                  color: ManaraColors.primary,
                ),
                onTap: () {
                  problemController.text = sample;
                  setState(() {});
                },
              ),
            ),
          ),
          if (solution != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ManaraColors.green, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'الحل',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(solution!, style: const TextStyle(height: 1.7)),
                ],
              ),
            ),
          ],
          if (history.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              '📋 سجل المسائل',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ...history.map(
              (item) => Card(
                elevation: 0,
                child: ListTile(
                  title: Text(item.problem, textAlign: TextAlign.right),
                  subtitle: const Text('تم الحل بنجاح'),
                  onTap: () {
                    problemController.text = item.problem;
                    setState(() => solution = item.solution);
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MathHistoryItem {
  const _MathHistoryItem({required this.problem, required this.solution});

  final String problem;
  final String solution;
}