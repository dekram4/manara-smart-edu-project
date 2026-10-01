import 'dart:convert';
import 'dart:typed_data';

/// دردشةُ المبارزة: ما يُرسل، وما يُقبل، ومتى يُسمح بالإرسال.
///
/// ── لماذا منطقٌ نقيٌّ خارج الشاشة ──
/// ما يصل من القناة كتبه جهازٌ آخر، فهو **بيانٌ لا يُصدَّق**: نصٌّ قد يكون
/// فارغاً أو ألفَ حرف، وصوتٌ قد يكون ضخماً أو ليس صوتاً. وفحصُ ذلك في بناءِ
/// ودجةٍ لا يُختبر إلا بتشغيلٍ على جهازين.
///
/// والفاصلُ الزمنيُّ كذلك: حرسٌ على الإزعاج يُقرأ في مكانٍ واحد ويُختبر بساعةٍ
/// مزيّفة، لا يُستنتج من مؤقّتاتٍ مبثوثةٍ في شاشة.
/// نوعُ الرسالة.
enum DuelChatKind { text, voice }

/// أقصى ما يُقبل من نصٍّ في رسالة.
///
/// جملةٌ تشجيعٍ لا خطاب: الفقاعةُ تظهر ثلاثَ ثوانٍ فوق الشخصية، ونصٌّ أطولُ
/// من هذا لا يُقرأ فيها — ويصير باباً إلى إغراق شاشة الخصم.
const duelChatMaxChars = 80;

/// أقصى حجمٍ للمقطع الصوتي بعد الترميز، بالبايت.
///
/// ── ولماذا سقفٌ صريح ──
/// المقطعُ يُبثّ عبر قناة Realtime، ولها سقفُ حجمٍ للرسالة. ومقطعٌ أكبر لا
/// يُرفض بخطأٍ مفهوم: يسقط البثُّ صامتاً فيظنّ الطفل أنه أرسل. فيُفحص الحجمُ
/// قبل الإرسال ويُقال له.
///
/// وخمسُ ثوانٍ بترميز AAC على ١٦ كيلوبت/ث ≈ ١٠ كيلوبايت، فهذا السقفُ أوسعُ
/// من الحاجة بأضعاف ويبقى دون سقف القناة.
const duelVoiceMaxBytes = 120 * 1024;

/// أقصى مدّةٍ للتسجيل.
///
/// ثلاثٌ إلى خمسٍ: جملةُ تشجيعٍ تُقال في ثلاث، والخمسُ حدٌّ يُوقف التسجيلَ
/// وحده. ومدّةٌ أطولُ تجعل الرسالةَ حديثاً يقطع تفكيرَ الخصم في سؤاله.
const duelVoiceMaxDuration = Duration(seconds: 5);

/// العباراتُ السريعة: ما يُرسل بضغطةٍ واحدة بلا كتابة.
///
/// وهي مفاتيحُ ترجمةٍ لا نصوص: الطفلُ قد يكون على الإنجليزية.
const duelQuickPhraseKeys = <String>[
  'duel.chat.quick.wellDone',
  'duel.chat.quick.focus',
  'duel.chat.quick.fast',
  'duel.chat.quick.luck',
];

/// الإيموجي المتاحة. قائمةٌ مغلقة: لوحةُ إيموجي كاملةٌ تفتح باباً إلى ما لا
/// يُراد في شاشة طفل.
const duelEmojis = <String>['🔥', '👏', '🎯', '💪', '😄', '⚡'];

/// رسالةٌ في الدردشة، كما تُعرض.
class DuelChatMessage {
  const DuelChatMessage({
    required this.senderId,
    required this.kind,
    this.text = '',
    this.audio,
    this.id = '',
    this.at,
  });

  final String senderId;
  final DuelChatKind kind;

  /// معرّفُ الصفّ في السجلّ، لما قُرئ منه. فارغٌ لما وصل بالبثّ.
  ///
  /// ── ويُستعمل لمنع التكرار ──
  /// الرسالةُ تُبثّ وتُحفظ معاً. فمن كان حاضراً يراها بالبثّ، ثم قد يُعاد
  /// قراءةُ السجلّ فتأتي ثانيةً — ويُعرف أنها هي بهذا المعرّف.
  final String id;

  /// وقتُ الحفظ، لترتيب السجلّ.
  final DateTime? at;

  /// نصُّ الرسالة أو الإيموجي. فارغٌ في الصوتية.
  final String text;

  /// بايتاتُ المقطع الصوتي، في الصوتية وحدها.
  final Uint8List? audio;

  bool get isVoice => kind == DuelChatKind.voice;

  /// ما يُبثّ على القناة.
  Map<String, Object?> toPayload() => {
        'id': senderId,
        'kind': kind.name,
        if (kind == DuelChatKind.text) 'text': text,
        if (kind == DuelChatKind.voice && audio != null)
          'audio': base64Encode(audio!),
      };

  /// جسمُ الرسالة كما يُحفظ في السجلّ: نصٌّ، أو الصوتُ بترميز base64.
  ///
  /// ── وجسمٌ واحدٌ للنوعين ──
  /// عمودان — نصٌّ وصوتٌ — أحدُهما فارغٌ دائماً، ويحتاج كلُّ قارئٍ أن يعرف
  /// أيَّهما يقرأ. والنوعُ مكتوبٌ في `kind`، فالجسمُ واحد.
  String get storedBody {
    if (kind == DuelChatKind.text) return text;
    final bytes = audio;
    return bytes == null ? '' : base64Encode(bytes);
  }

  /// رسالةٌ قُرئت من سجلّ المباراة.
  ///
  /// والفحصُ هو فحصُ البثّ نفسه: الصفُّ كتبه جهازٌ آخر عبر الخادم، ونصٌّ
  /// فارغٌ أو صوتٌ ضخمٌ أو ترميزٌ معطوبٌ تمرّ كلُّها بلا خطأٍ يظهر.
  static DuelChatMessage? fromStored(Object? raw) {
    if (raw is! Map) return null;
    final sender = raw['senderId'];
    if (sender is! String || sender.trim().isEmpty) return null;
    final voice = raw['kind'] == DuelChatKind.voice.name;
    final id = raw['id'] is String ? (raw['id'] as String).trim() : '';
    final at = DateTime.tryParse(
      raw['createdAt'] is String ? raw['createdAt'] as String : '',
    );

    if (!voice) {
      final clean = sanitizeChatText(raw['text'] is String ? raw['text'] as String : '');
      if (clean.isEmpty) return null;
      return DuelChatMessage(
        senderId: sender.trim(),
        kind: DuelChatKind.text,
        text: clean,
        id: id,
        at: at,
      );
    }

    final encoded = raw['audio'];
    if (encoded is! String || encoded.isEmpty) return null;
    final Uint8List bytes;
    try {
      bytes = base64Decode(encoded);
    } catch (_) {
      return null;
    }
    if (bytes.isEmpty || bytes.length > duelVoiceMaxBytes) return null;
    return DuelChatMessage(
      senderId: sender.trim(),
      kind: DuelChatKind.voice,
      audio: bytes,
      id: id,
      at: at,
    );
  }

  /// ما يُقرأ منها، أو `null` لما لا يصلح أن يُعرض.
  ///
  /// ── وكلُّ حقلٍ يُفحص ──
  /// ما يأتي من القناة كتبه جهازٌ آخر. ونصٌّ فارغٌ يرسم فقاعةً خاوية، ونصٌّ
  /// طويلٌ يغطّي الشاشة، وصوتٌ ضخمٌ يُجهد المشغّل — وكلُّها تمرّ بلا خطأ.
  static DuelChatMessage? fromPayload(Object? raw) {
    if (raw is! Map) return null;
    final sender = raw['id'];
    if (sender is! String || sender.trim().isEmpty) return null;

    final kind = raw['kind'] == DuelChatKind.voice.name
        ? DuelChatKind.voice
        : DuelChatKind.text;

    if (kind == DuelChatKind.text) {
      final text = raw['text'];
      if (text is! String) return null;
      final clean = sanitizeChatText(text);
      if (clean.isEmpty) return null;
      return DuelChatMessage(
        senderId: sender.trim(),
        kind: DuelChatKind.text,
        text: clean,
      );
    }

    final encoded = raw['audio'];
    if (encoded is! String || encoded.isEmpty) return null;
    final Uint8List bytes;
    try {
      bytes = base64Decode(encoded);
    } catch (_) {
      // نصٌّ ليس ترميزاً: يُترك ولا تُرفع رمية في مستمعِ قناة.
      return null;
    }
    if (bytes.isEmpty || bytes.length > duelVoiceMaxBytes) return null;
    return DuelChatMessage(
      senderId: sender.trim(),
      kind: DuelChatKind.voice,
      audio: bytes,
    );
  }
}

/// نصٌّ صالحٌ للعرض، أو فراغ.
///
/// يُقصّ الطولُ وتُجمَع الأسطرُ في سطر: فقاعةٌ فوق الشخصية سطرٌ أو سطران،
/// ونصٌّ بعشرين سطرٍ جديدٍ يطيلها حتى تغطّي اللعبة.
String sanitizeChatText(String raw) {
  final flat = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) return '';
  return flat.length <= duelChatMaxChars
      ? flat
      : flat.substring(0, duelChatMaxChars);
}

/// حالُ كتم الدردشة: كتمي أنا، وكتمُ الخصم.
///
/// ── لماذا قيمةٌ واحدةٌ تُقرأ منها كلُّ القرارات ──
/// الكتمُ يمنع أربعةَ أشياء: فقاعةً تُرسم، ومقطعاً يُشغَّل، ونصّاً يُرسل،
/// وصوتاً يُسجَّل. وأربعةُ شروطٍ مبثوثةٍ في شاشةٍ يُنسى واحدٌ منها — فيكتم
/// الطفلُ الدردشةَ ويظلّ يسمع صوتَ خصمه. وهو عطبٌ لا يرفع خطأً.
///
/// فكلُّ قرارٍ اسمٌ هنا، ويُختبر بلا شاشة.
class DuelChatMuteState {
  const DuelChatMuteState({
    this.isChatMuted = false,
    this.isRivalMuted = false,
  });

  /// أنا كتمتُ الدردشة.
  final bool isChatMuted;

  /// والخصمُ كتمها عنده.
  final bool isRivalMuted;

  /// هل يُسمح لي بالإرسال؟
  ///
  /// والكتمُ يمنعني من الإرسال لا من الاستقبال وحده: من كتم للتركيز لا يُراد
  /// منه أن يبقى يُرسل — ودردشةٌ في اتجاهٍ واحد تُربك الطرفَ الآخر.
  bool get canSend => !isChatMuted;

  /// هل تُعرض رسالةٌ وصلت؟
  bool get showsIncoming => !isChatMuted;

  /// هل يُشغَّل مقطعٌ صوتيٌّ وصل؟
  ///
  /// وهو القرارُ الذي يُنسى: الفقاعةُ تُحجب بالنظر فيُلاحَظ تركُها، والصوتُ
  /// يُشغَّل في مسلكٍ آخر فيبقى يُسمع.
  bool get playsIncomingVoice => !isChatMuted;

  /// هل أُنبّه أنّ الخصمَ أوقف الدردشة؟
  ///
  /// ولا يُنبَّه من كتم هو نفسه: هو يعرف أنه كاتم، والتنبيهُ عن حال الخصم
  /// في تلك اللحظة ضجيجٌ لا خبر.
  bool get warnsRivalMuted => isRivalMuted && !isChatMuted;

  DuelChatMuteState copyWith({bool? isChatMuted, bool? isRivalMuted}) =>
      DuelChatMuteState(
        isChatMuted: isChatMuted ?? this.isChatMuted,
        isRivalMuted: isRivalMuted ?? this.isRivalMuted,
      );

  @override
  bool operator ==(Object other) =>
      other is DuelChatMuteState &&
      other.isChatMuted == isChatMuted &&
      other.isRivalMuted == isRivalMuted;

  @override
  int get hashCode => Object.hash(isChatMuted, isRivalMuted);
}

/// حرسُ الإزعاج: لا رسالةَ قبل أن تمضي [gap] على التي قبلها.
///
/// ── ولماذا هنا لا مؤقّتٌ في الشاشة ──
/// طفلان يتبارزان يضغطان الإيموجي بلا توقّف، والشاشةُ التي تُغرق بالفقاعات
/// تُخفي السؤال. والمؤقّتُ في الشاشة يموت مع إعادة البناء ويُنسى عند إضافة
/// مسلك إرسالٍ ثانٍ — وقد صار للإرسال مسلكان: نصٌّ وصوت.
class DuelChatCooldown {
  DuelChatCooldown({
    this.gap = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration gap;
  final DateTime Function() _now;
  DateTime? _last;

  /// هل يُسمح بالإرسال الآن؟ ولا تُسجَّل محاولةٌ مرفوضة: الفاصلُ يُقاس من
  /// آخر ما أُرسل فعلاً، وإلا مدّت الضغطاتُ المرفوضةُ المنعَ إلى ما لا نهاية.
  bool get ready {
    final last = _last;
    return last == null || _now().difference(last) >= gap;
  }

  /// ما بقي من المنع، أو صفرٌ إن كان مسموحاً.
  Duration get remaining {
    final last = _last;
    if (last == null) return Duration.zero;
    final left = gap - _now().difference(last);
    return left.isNegative ? Duration.zero : left;
  }

  /// يُسجّل إرسالاً وقع. ويعود بـ`false` إن كان ممنوعاً، فيكون الفحصُ
  /// والتسجيلُ خطوةً واحدةً لا خطوتين يُنسى بينهما شيء.
  bool claim() {
    if (!ready) return false;
    _last = _now();
    return true;
  }
}
