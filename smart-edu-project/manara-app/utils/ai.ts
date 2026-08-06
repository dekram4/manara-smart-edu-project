// Gemini AI utility for generating quiz questions from lesson content
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

// Check if Gemini API key is available
const getApiKey = async (): Promise<string | null> => {
  try {
    const settings = await AsyncStorage.getItem('manara_admin_settings');
    if (settings) {
      const parsed = JSON.parse(settings);
      return parsed.geminiApiKey || null;
    }
  } catch {}
  return null;
};

import AsyncStorage from '@react-native-async-storage/async-storage';

export const generateQuizQuestions = async (subject: string, content: string, count: number = 5): Promise<Array<{question: string; options: string[]; correct: number}>> => {
  const apiKey = await getApiKey();
  if (!apiKey) {
    // Fallback: generate local questions
    return generateLocalQuestions(subject, count);
  }

  try {
    const prompt = `أنشئ ${count} أسئلة اختيار متعدد في موضوع "${subject}" بناءً على المحتوى التالي: ${content.substring(0, 500)}
التنسيق المطلوب: أرد فقط بإرجاع JSON مصفوف مصفوفًا مع مفتاح JSON مبسط بدون شرح.
[
  {"question": "السؤال", "options": ["الخيار 1", "الخيار 2", "الخيار 3", "الخيار 4"], "correct": 0}
]`;

    const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.7, maxOutputTokens: 2048 }
      })
    });

    const data = await response.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
    
    // Extract JSON from response
    const jsonMatch = text.match(/\[.*\]/s);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]);
    }
    return generateLocalQuestions(subject, count);
  } catch {
    return generateLocalQuestions(subject, count);
  }
};

export const generateTrueFalseQuestions = async (subject: string, content: string, count: number = 5): Promise<Array<{statement: string; isTrue: boolean}>> => {
  const apiKey = await getApiKey();
  if (!apiKey) {
    return generateLocalTF(subject, count);
  }

  try {
    const prompt = `أنشئ ${count} أسئلة صح/خطأ في موضوع "${subject}" بناءً على: ${content.substring(0, 500)}
التنسيق المطلوب: أرد فقط بإرجاع JSON مصفوف مصفوفًا مع مفتاح JSON مبسط.
[
  {"statement": "الجملة", "isTrue": true}
]`;

    const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.7, maxOutputTokens: 1024 }
      })
    });

    const data = await response.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
    const jsonMatch = text.match(/\[.*\]/s);
    if (jsonMatch) return JSON.parse(jsonMatch[0]);
    return generateLocalTF(subject, count);
  } catch {
    return generateLocalTF(subject, count);
  }
};

export const solveMathProblem = async (problem: string): Promise<string> => {
  const apiKey = await getApiKey();
  if (!apiKey) {
    return `حل المسألة: ${problem}\n\nالإجابة الصحيحة: [يتم الحساب خارجيًا باستخدام math.js]\n\nللحصول على حل AI كامل، أدخل مفتاح API Gemini في إعدادات المشرف.`;
  }

  try {
    const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: `حل هذه المسألة الرياضية بخطوات مفصلة: ${problem}` }] }],
        generationConfig: { temperature: 0.3, maxOutputTokens: 1024 }
      })
    });
    const data = await response.json();
    return data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
  } catch {
    return 'حدث خطأ في الاتصال بالذكاء الاصطناعي.';
  }
};

// Local fallback generators
const generateLocalQuestions = (subject: string, count: number) => {
  const questions: Record<string, Array<{question: string; options: string[]; correct: number}>> = {
    'العلوم': [
      { question: 'ما هو الغذاء الرئيسي للنباتات ؟', options: ['البروتين', 'السكر', 'الدهون', 'الفيتامين'], correct: 0 },
      { question: 'كم صفحة في جسم الإنسان ؟', options: ['206', '208', '210', '212'], correct: 0 },
    ],
    'العربية': [
      { question: 'ما جمع "القلم الرشيد" ؟', options: ['الكرسي', 'البراعم', 'الفلسطين', 'المدينة'], correct: 0 },
    ],
    'التاريخ': [
      { question: 'في أي عام بدأ العصر الأموي ؟', options: ['610', '750', '800', '900'], correct: 0 },
    ],
    'الحاسب': [
      { question: 'ناتج 12 + 7 ؟', options: ['18', '19', '20', '21'], correct: 1 },
      { question: 'ناتج 5 × 6 ؟', options: ['25', '30', '35', '40'], correct: 1 },
    ],
  };
  
  const pool = questions[subject] || questions['العلوم'];
  return pool.slice(0, count).concat(
    Array.from({ length: Math.max(0, count - pool.length) }, (_, i) => ({
      question: `سؤال ${i + 1}: ما هي الإجابة الصحيحة لسؤال ${subject} ؟`,
      options: ['خيار أ', 'خيار ب', 'خيار ج', 'خيار د'],
      correct: 0
    }))
  ).slice(0, count);
};

const generateLocalTF = (subject: string, count: number) => {
  const pool = [
    { statement: `الشمس هي مركز المجموعة الشمسية.`, isTrue: true },
    { statement: `الماء يغلي اللون إلى الأحمر عند التجمد.`, isTrue: false },
    { statement: `2 + 2 = 5.`, isTrue: false },
    { statement: `الأرض مسطحة.`, isTrue: false },
    { statement: `النباتات تقوم بعملية البناء الضوئي.`, isTrue: true },
    { statement: `الأفروق هم يسبق البشر في التطور.`, isTrue: true },
    { statement: `الولد الصغير يأكل أول ما يولد.`, isTrue: false },
    { statement: `10 × 10 = 100.`, isTrue: true },
  ];
  return pool.slice(0, count);
};
