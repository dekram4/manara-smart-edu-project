require('dotenv').config();
console.log('🔑 مفتاح من env:', process.env.GEMINI_API_KEY);
const express = require('express');
const fetch = require('node-fetch');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 4000;

app.use(cors());
app.use(express.json());

app.post('/api/gemini/answer', async (req, res) => {
  console.log('📥 تم استقبال طلب من الواجهة الأمامية');
  const { lesson, question } = req.body;
  const apiKey = process.env.GEMINI_API_KEY;

  console.log('📝 الدرس:', lesson && lesson.substring ? lesson.substring(0, 60) + '...' : lesson);
  console.log('❓ السؤال:', question);
  if (!lesson || !question) {
    console.error('❌ lesson أو question غير موجود');
    return res.status(400).json({ error: 'lesson and question are required' });
  }
  if (!apiKey) {
    console.error('❌ مفتاح Gemini غير موجود في .env');
    return res.status(500).json({ error: 'Gemini API key not set in server .env' });
  }

  const prompt = `أنت مساعد تعليمي ذكي. اقرأ النص التالي:\n\n${lesson}\n\nالسؤال: ${question}\n\nأجب إجابة مباشرة، ذكية، مفصلة، وبدون مقدمات أو تكرار للسؤال. إذا لم تجد الإجابة في نص الدرس، قل بوضوح: "هذا السؤال ليس من ضمن الدرس ولا أستطيع الإجابة عليه" ولا تستخدم معرفتك العامة. فقط أعطِ الجواب النهائي للطالب.\n`;

  try {
    // جلب قائمة النماذج المتاحة
    let modelName = null;
    const listUrl = `https://generativelanguage.googleapis.com/v1/models?key=${apiKey}`;
    try {
      const listRes = await fetch(listUrl);
      const listData = await listRes.json();
      if (listData.models && Array.isArray(listData.models)) {
        // ابحث عن أول نموذج يدعم generateContent
        const found = listData.models.find(m => m.supportedGenerationMethods && m.supportedGenerationMethods.includes('generateContent'));
        if (found) {
          modelName = found.name;
          console.log('✅ تم اختيار النموذج تلقائياً:', modelName);
        }
      }
    } catch (e) {
      console.warn('⚠️ تعذر جلب قائمة النماذج، سيتم استخدام النموذج الافتراضي gemini-1.5-pro-latest');
    }
    if (!modelName) {
      modelName = 'models/gemini-1.5-flash-latest';
    }
    const apiUrl = `https://generativelanguage.googleapis.com/v1/${modelName}:generateContent?key=${apiKey}`;
    console.log('🔗 إرسال طلب إلى Gemini:', apiUrl);
    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.2,
          maxOutputTokens: 2048,
          topP: 0.8,
        }
      })
    });
    const data = await response.json();
    console.log('📤 رد Gemini:', JSON.stringify(data));
    const answer = data?.candidates?.[0]?.content?.parts?.[0]?.text || null;
    res.json({ answer, raw: data });
  } catch (err) {
    console.error('❌ خطأ أثناء الاتصال بـ Gemini:', err);
    res.status(500).json({ error: 'Failed to connect to Gemini', details: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`Gemini proxy server running on http://localhost:${PORT}`);
});
