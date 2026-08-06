import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/gamification_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class AvatarInteractionScreen extends StatefulWidget {
  const AvatarInteractionScreen({super.key});

  @override
  State<AvatarInteractionScreen> createState() =>
      _AvatarInteractionScreenState();
}

class _AvatarInteractionScreenState extends State<AvatarInteractionScreen>
    with SingleTickerProviderStateMixin {
  static const _encouragements = [
    'أحسنت! أنت بطل محترف!',
    'رائع! أنت الأفضل!',
    'ممتاز! كم أنت ذكي!',
    'عظيم! واصل التميز!',
    'أنت نجم! اعتز بنفسك!',
  ];

  static const _greetings = [
    'مرحباً! هل أنت جاهز للتعلم؟',
    'يا هلا! أهلاً وسهلاً في منصتنا!',
    'أهلاً! اليوم رائع للتعلم!',
  ];

  static const _topics = [
    _AvatarTopic(
      id: 'math',
      label: 'الرياضيات',
      icon: '🔢',
      color: ManaraColors.blue,
      response: 'الرياضيات رائعة! الجمع والطرح والضرب تصبح سهلة مع التدريب.',
    ),
    _AvatarTopic(
      id: 'science',
      label: 'العلوم',
      icon: '🔬',
      color: ManaraColors.green,
      response: 'العلوم مجال رائع! من النباتات إلى الفضاء، العالم مليء بالأسرار.',
    ),
    _AvatarTopic(
      id: 'arabic',
      label: 'العربية',
      icon: '✍️',
      color: ManaraColors.secondary,
      response: 'اللغة العربية جميلة! القراءة والتدريب يجعلانك أكثر طلاقة.',
    ),
    _AvatarTopic(
      id: 'history',
      label: 'التاريخ',
      icon: '📚',
      color: ManaraColors.admin,
      response: 'التاريخ يعلمنا دروس الماضي ويساعدنا على بناء مستقبل أفضل.',
    ),
  ];

  final inputController = TextEditingController();
  final scrollController = ScrollController();
  final messages = <_AvatarMessage>[];
  late final AnimationController animationController;
  bool speaking = false;
  bool thinking = false;
  bool encouraging = false;
  Timer? responseTimer;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addAvatarMessage(
        _greetings[0],
        type: _AvatarMessageType.greeting,
        speak: true,
      );
    });
  }

  @override
  void dispose() {
    responseTimer?.cancel();
    inputController.dispose();
    scrollController.dispose();
    animationController.dispose();
    super.dispose();
  }

  void _addUserMessage(String text) {
    setState(() {
      messages.add(_AvatarMessage(text: text, fromUser: true));
    });
    _scrollToLatest();
  }

  void _addAvatarMessage(
    String text, {
    _AvatarMessageType type = _AvatarMessageType.answer,
    bool speak = false,
  }) {
    if (!mounted) return;
    setState(() {
      messages.add(_AvatarMessage(text: text, type: type));
    });
    _scrollToLatest();
    if (speak) _speak(text);
  }

  Future<void> _speak(String text) async {
    if (!mounted) return;
    setState(() => speaking = true);
    await context.read<AppState>().speech.speak(text);
    if (mounted) setState(() => speaking = false);
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = inputController.text.trim();
    if (text.isEmpty || thinking) return;
    inputController.clear();
    _addUserMessage(text);
    setState(() => thinking = true);
    context.read<AppState>().recordInteraction(action: 'avatar_message');

    responseTimer = Timer(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      final responses = [
        'يا له من سؤال جميل! دعني أفكر فيه معك.',
        'أحسنت السؤال! التعلم يبدأ دائماً بالفضول.',
        'واو! أنت تسأل مثل العلماء. لنبحث عن الإجابة خطوة بخطوة.',
        'سؤال رائع! راجع الدرس وجرب تطبيق الفكرة بنفسك.',
      ];
      final response = responses[messages.length % responses.length];
      setState(() => thinking = false);
      _addAvatarMessage(response, speak: true);
      context.read<AppState>().awardReward(
            const RewardAmount(10, 0),
          );
      context.read<AppState>().speech.encouragement();
    });
  }

  Future<void> _encourage() async {
    if (encouraging) return;
    setState(() => encouraging = true);
    final message =
        _encouragements[messages.length % _encouragements.length];
    _addAvatarMessage(message, type: _AvatarMessageType.encouragement, speak: true);
    final state = context.read<AppState>();
    state.awardReward(const RewardAmount(5, 1));
    state.unlockAchievement('صديق الأفاتار');
    state.recordInteraction(action: 'avatar_encouragement');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (mounted) setState(() => encouraging = false);
  }

  void _selectTopic(_AvatarTopic topic) {
    _addAvatarMessage(topic.response, speak: true);
    context.read<AppState>().recordInteraction(
          action: 'avatar_topic',
          subject: topic.label,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🤖 صديقي الذكي',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'إيقاف الصوت',
            onPressed: () {
              state.speech.stop();
              setState(() => speaking = false);
            },
            icon: Icon(speaking ? Icons.volume_up : Icons.volume_off),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _AvatarHeader(
              avatar: state.avatar,
              speaking: speaking,
              thinking: thinking,
              encouraging: encouraging,
              animation: animationController,
              onEncourage: _encourage,
            ),
            SizedBox(
              height: 58,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _topics.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final topic = _topics[index];
                  return ActionChip(
                    avatar: Text(topic.icon),
                    label: Text(topic.label),
                    labelStyle: TextStyle(
                      color: topic.color,
                      fontWeight: FontWeight.w800,
                    ),
                    onPressed: () => _selectTopic(topic),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                itemCount: messages.length + (thinking ? 1 : 0),
                itemBuilder: (_, index) {
                  if (index == messages.length) {
                    return const _MessageBubble(
                      text: 'يفكر في إجابة مناسبة لك...',
                      fromUser: false,
                      type: _AvatarMessageType.thinking,
                    );
                  }
                  final message = messages[index];
                  return _MessageBubble(
                    text: message.text,
                    fromUser: message.fromUser,
                    type: message.type,
                  );
                },
              ),
            ),
            _Composer(
              controller: inputController,
              enabled: !thinking,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarHeader extends StatelessWidget {
  const _AvatarHeader({
    required this.avatar,
    required this.speaking,
    required this.thinking,
    required this.encouraging,
    required this.animation,
    required this.onEncourage,
  });

  final String avatar;
  final bool speaking;
  final bool thinking;
  final bool encouraging;
  final Animation<double> animation;
  final VoidCallback onEncourage;

  @override
  Widget build(BuildContext context) {
    final color = thinking
        ? ManaraColors.secondary
        : speaking
            ? ManaraColors.green
            : ManaraColors.admin;
    final status = speaking
        ? 'يتكلم...'
        : thinking
            ? 'يفكر...'
            : 'جاهز!';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: animation,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, animation.value * 8),
              child: child,
            ),
            child: AnimatedScale(
              scale: encouraging ? 1.18 : 1,
              duration: const Duration(milliseconds: 220),
              child: CircleAvatar(
                radius: 52,
                backgroundColor: color.withOpacity(.2),
                child: Text(avatar, style: const TextStyle(fontSize: 58)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Chip(
            avatar: CircleAvatar(radius: 5, backgroundColor: color),
            label: Text(status),
            backgroundColor: Colors.white,
          ),
          FilledButton.icon(
            onPressed: onEncourage,
            icon: const Icon(Icons.celebration_outlined),
            label: const Text('شجعني!'),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'اكتب سؤالك للصديق الذكي...',
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send),
            tooltip: 'إرسال',
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.fromUser,
    required this.type,
  });

  final String text;
  final bool fromUser;
  final _AvatarMessageType type;

  @override
  Widget build(BuildContext context) {
    final special = type == _AvatarMessageType.encouragement;
    return Align(
      alignment: fromUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fromUser
              ? ManaraColors.primary
              : special
                  ? const Color(0xFFFFFBEE)
                  : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: fromUser
              ? null
              : Border.all(
                  color: special ? ManaraColors.secondary : ManaraColors.border,
                  width: special ? 2 : 1,
                ),
        ),
        child: Column(
          crossAxisAlignment:
              fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!fromUser)
              const Text(
                '🤖 صديقك الذكي',
                style: TextStyle(
                  color: ManaraColors.purple,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            Text(
              text,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: fromUser ? Colors.white : ManaraColors.ink,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarTopic {
  const _AvatarTopic({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.response,
  });

  final String id;
  final String label;
  final String icon;
  final Color color;
  final String response;
}

class _AvatarMessage {
  const _AvatarMessage({
    required this.text,
    this.fromUser = false,
    this.type = _AvatarMessageType.answer,
  });

  final String text;
  final bool fromUser;
  final _AvatarMessageType type;
}

enum _AvatarMessageType { greeting, answer, encouragement, thinking }