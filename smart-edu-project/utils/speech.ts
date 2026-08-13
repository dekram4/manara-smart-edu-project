// 🇸🇦 نظام الكلام العربي التشجيعي للأطفال

const ENCOURAGEMENT_MESSAGES = [
  'أحسنت! أنت بطل محترف!',
  'رائع! أنت الأفضل!',
  'ممتاز! كم أنت ذكي!',
  'برافو! أنت ستصبح عالماً يومما!',
  'رائع! إذا أنت فخور!',
  'عظيم! واصل في التميز!',
  'جيد جدا! العلم يجعلك أقوى!',
  'أنت بطل! استمر في النجاح!',
  'صح حلو! أنت أذكى من أمس!',
  'ما أجمل! أنت أسطورة!',
  'راوع! كل إجابة صحيحة تقربك الأمل!',
  'سائق المــــــتعلمين!',
  'تميم! عقلك رائع!',
  'عالم المستقبل بيدك!',
  'أنت نجم! اعتز بنفسك!',
];

const QUIZ_START_MESSAGES = [
  'حاول مختبرتك! أنت قدر!',
  'الاختبار يبدأ! كن بطلا!',
  'تمني لك التوفيق! ابدأ!',
  'أصبع أصبع راسك! أنت ذكي!',
];

const WIN_MESSAGES = [
  'إييييه! فوزت! أنت بطل!',
  '🎉 مبروك! أنت المفاوز!',
  'كلهن صح! معك في الـــاندية!',
  'أنت المفاوز! اشوش!',
  'رائع! أنت مـــحترف!',
];

let speechEnabled = true;

export function setSpeechEnabled(enabled: boolean) {
  speechEnabled = enabled;
}

export function speak(text: string, pitch = 1.2, rate = 0.9) {
  if (!speechEnabled || typeof window === 'undefined') return;
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = 'ar-SA';
  utterance.pitch = pitch;
  utterance.rate = rate;
  // Try to find Arabic voice
  const voices = window.speechSynthesis.getVoices();
  const arVoice = voices.find(v => v.lang.startsWith('ar'));
  if (arVoice) utterance.voice = arVoice;
  window.speechSynthesis.cancel();
  window.speechSynthesis.speak(utterance);
}

export function speakRandom(arr: string[]) {
  const msg = arr[Math.floor(Math.random() * arr.length)];
  speak(msg);
}

export function speakEncouragement() { speakRandom(ENCOURAGEMENT_MESSAGES); }
export function speakQuizStart() { speakRandom(QUIZ_START_MESSAGES); }
export function speakWin() { speakRandom(WIN_MESSAGES); }
export function speakError() { speak('لا تتراج! جرب مرة أخرى ✗', 0.9, 0.8); }
