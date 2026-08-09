
import React, { useState, useEffect } from 'react';
import { QuizQuestion, QuizType, LessonConfig, CreatedQuiz } from '../../types';
import { STORAGE_KEYS, QUIZ_TYPES } from '../../constants';
import { getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import { getQuizTypeLabel, normalizeCreatedQuiz, normalizeQuizType } from '../../utils/quizTypes';

interface QuizManagementProps {
  onUpdate: () => void;
  teacherId?: string;
  teacherName?: string;
}

// 📝 نموذج إضافة سؤال يدوي
const ManualQuestionForm: React.FC<{
  onAdd: (question: string, options: string[], correctAnswer: string) => void;
  onCancel: () => void;
}> = ({ onAdd, onCancel }) => {
  const [question, setQuestion] = useState('');
  const [options, setOptions] = useState(['', '', '', '']);
  const [correctIndex, setCorrectIndex] = useState(0);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!question.trim()) {
      alert('⚠️ يجب كتابة نص السؤال');
      return;
    }
    
    const filledOptions = options.filter(o => o.trim());
    if (filledOptions.length < 2) {
      alert('⚠️ يجب إضافة خيارين على الأقل');
      return;
    }
    
    onAdd(question, filledOptions, filledOptions[correctIndex]);
    setQuestion('');
    setOptions(['', '', '', '']);
    setCorrectIndex(0);
  };

  return (
    <div className="bg-white p-6 rounded-[25px] border-2 border-green-300">
      <h3 className="font-black text-green-900 text-lg mb-4">➕ إضافة سؤال جديد</h3>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block font-bold text-purple-700 mb-2">السؤال</label>
          <textarea
            value={question}
            onChange={e => setQuestion(e.target.value)}
            className="w-full p-3 border-2 border-purple-200 rounded-xl resize-none"
            rows={3}
            placeholder="اكتب نص السؤال..."
            required
          />
        </div>
        
        <div>
          <label className="block font-bold text-purple-700 mb-2">الخيارات</label>
          <div className="space-y-2">
            {options.map((opt, i) => (
              <div key={i} className="flex gap-2 items-center">
                <input
                  type="radio"
                  name="correct"
                  checked={correctIndex === i}
                  onChange={() => setCorrectIndex(i)}
                  className="w-5 h-5"
                />
                <input
                  type="text"
                  value={opt}
                  onChange={e => {
                    const newOpts = [...options];
                    newOpts[i] = e.target.value;
                    setOptions(newOpts);
                  }}
                  className="flex-1 p-3 border-2 border-purple-200 rounded-xl"
                  placeholder={`الخيار ${i + 1}`}
                />
              </div>
            ))}
          </div>
          <p className="text-xs text-purple-500 mt-2">💡 حدد الدائرة للإجابة الصحيحة</p>
        </div>
        
        <div className="flex gap-2">
          <button
            type="submit"
            className="flex-1 py-3 bg-gradient-to-r from-green-600 to-emerald-600 text-white rounded-xl font-bold hover:shadow-lg transition-all"
          >
            ✅ إضافة السؤال
          </button>
          <button
            type="button"
            onClick={onCancel}
            className="px-6 py-3 bg-red-100 text-red-600 rounded-xl font-bold hover:bg-red-200 transition-all"
          >
            ❌ إلغاء
          </button>
        </div>
      </form>
    </div>
  );
};

// ✏️ نموذج تعديل سؤال موجود
const EditQuestionForm: React.FC<{
  question: QuizQuestion;
  onUpdate: (id: string, question: string, options: string[], correctAnswer: string) => void;
  onCancel: () => void;
}> = ({ question, onUpdate, onCancel }) => {
  const [questionText, setQuestionText] = useState(question.question);
  const [options, setOptions] = useState([...question.options]);
  const [correctAnswer, setCorrectAnswer] = useState(question.correctAnswer);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!questionText.trim()) {
      alert('⚠️ يجب كتابة نص السؤال');
      return;
    }
    
    const filledOptions = options.filter(o => o.trim());
    if (filledOptions.length < 2) {
      alert('⚠️ يجب إضافة خيارين على الأقل');
      return;
    }
    
    onUpdate(question.id, questionText, filledOptions, correctAnswer);
  };

  return (
    <div className="bg-blue-50 p-6 rounded-[25px] border-2 border-blue-300 mb-4">
      <h3 className="font-black text-blue-900 text-lg mb-4">✏️ تعديل السؤال</h3>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block font-bold text-purple-700 mb-2">السؤال</label>
          <textarea
            value={questionText}
            onChange={e => setQuestionText(e.target.value)}
            className="w-full p-3 border-2 border-purple-200 rounded-xl resize-none"
            rows={3}
            placeholder="اكتب نص السؤال..."
            required
          />
        </div>

        <div>
          <label className="block font-bold text-purple-700 mb-2">الخيارات</label>
          <div className="space-y-2">
            {options.map((opt, index) => (
              <div key={index} className="flex gap-2 items-center">
                <input
                  type="radio"
                  name="correct"
                  checked={correctAnswer === opt}
                  onChange={() => setCorrectAnswer(opt)}
                  className="w-5 h-5"
                />
                <input
                  type="text"
                  value={opt}
                  onChange={e => {
                    const newOptions = [...options];
                    newOptions[index] = e.target.value;
                    setOptions(newOptions);
                    if (correctAnswer === opt) setCorrectAnswer(e.target.value);
                  }}
                  className="flex-1 p-3 border-2 border-purple-200 rounded-xl"
                  placeholder={`الخيار ${index + 1}`}
                />
              </div>
            ))}
          </div>
          <p className="text-xs text-purple-500 mt-2">✓ حدد الإجابة الصحيحة</p>
        </div>

        <div className="flex gap-3">
          <button
            type="submit"
            className="flex-1 bg-blue-600 text-white py-3 rounded-xl font-bold hover:bg-blue-700 transition-all"
          >
            💾 حفظ التعديلات
          </button>
          <button
            type="button"
            onClick={onCancel}
            className="px-6 bg-purple-100 text-purple-700 py-3 rounded-xl font-bold hover:bg-purple-200 transition-all"
          >
            ❌ إلغاء
          </button>
        </div>
      </form>
    </div>
  );
};

const QuizManagement: React.FC<QuizManagementProps> = ({ onUpdate, teacherId, teacherName }) => {
  const [createdQuizzes, setCreatedQuizzes] = useState<CreatedQuiz[]>([]);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [isGenerating, setIsGenerating] = useState(false);
  const [editingQuiz, setEditingQuiz] = useState<CreatedQuiz | null>(null);
  const [creationMode, setCreationMode] = useState<'ai' | 'manual'>('ai'); // وضع الإنشاء
  const [manualQuestions, setManualQuestions] = useState<QuizQuestion[]>([]); // الأسئلة اليدوية
  const [showAddQuestionForm, setShowAddQuestionForm] = useState(false);
  const [editingQuestion, setEditingQuestion] = useState<QuizQuestion | null>(null);

  // 👨‍🏫 اختيار المعلم
  const [teachers, setTeachers] = useState<any[]>([]);
  const [selectedTeacherId, setSelectedTeacherId] = useState<string>(teacherId || 'admin');
  const [selectedTeacherName, setSelectedTeacherName] = useState<string>(
    teacherName || 'المشرف - محتوى عام',
  );

  // 🔗 الإعدادات الأكاديمية الهرمية
  const [availableGrades, setAvailableGrades] = useState<string[]>([]);
  const [availableAtrams, setAvailableAtrams] = useState<string[]>([]);
  const [availableSubjects, setAvailableSubjects] = useState<string[]>([]);
  const [availableTerms, setAvailableTerms] = useState<string[]>([]);
  const [availableUnits, setAvailableUnits] = useState<string[]>([]);

  // 📝 محتوى الدرس المسحوب
  const [lessonContent, setLessonContent] = useState('');
  const [lessonFound, setLessonFound] = useState(false);

  const [quizFormData, setQuizFormData] = useState({
    title: '',
    grade: '',
    atram: '',
    subject: '',
    term: '',
    unit: '',
    quizType: QuizType.PERIODIC,
    questionCount: 10,
    isActive: true
  });

  useEffect(() => {
    loadQuizzes();
    loadAcademicHierarchy();
  }, [selectedTeacherId, teacherId]);

  const loadQuizzes = () => {
    const saved = localStorage.getItem(STORAGE_KEYS.CREATED_QUIZZES);
    if (!saved) return;
    const all = JSON.parse(saved).map(normalizeCreatedQuiz);
    const visible = teacherId
      ? all.filter((quiz: CreatedQuiz) => getRecordTeacherId(quiz) === normalizeScopeValue(teacherId))
      : all;
    setCreatedQuizzes(visible);
    if (JSON.stringify(all) !== saved) {
      localStorage.setItem(STORAGE_KEYS.CREATED_QUIZZES, JSON.stringify(all));
    }
  };

  // 📚 تحميل الهيكل الأكاديمي
  const loadAcademicHierarchy = () => {
    const allHierarchicalConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const teachersList = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
    setTeachers(teachersList);

    // فلترة الإعدادات الأكاديمية حسب المعلم المختار
    let filtered = allHierarchicalConfigs;
    if (selectedTeacherId && selectedTeacherId !== 'admin') {
      filtered = allHierarchicalConfigs.filter((c: any) => getRecordTeacherId(c) === normalizeScopeValue(selectedTeacherId));
    }
    const grades = filtered.map((c: any) => c.grade);
    setAvailableGrades(grades);
  };

  const handleTeacherChange = (newTeacherId: string) => {
    setSelectedTeacherId(newTeacherId);
    if (newTeacherId === 'admin') {
      setSelectedTeacherName('المشرف - محتوى عام');
    } else {
      const t = teachers.find((t: any) => t.id === newTeacherId);
      setSelectedTeacherName(t?.name || '');
    }
    // إعادة تعيين القائمة
    setQuizFormData({
      title: '',
      grade: '',
      atram: '',
      subject: '',
      term: '',
      unit: '',
       quizType: QuizType.PERIODIC,
      questionCount: 10,
      isActive: true
    });
    setLessonContent('');
    setLessonFound(false);
    setAvailableGrades([]);
    setAvailableAtrams([]);
    setAvailableSubjects([]);
    setAvailableTerms([]);
    setAvailableUnits([]);
    setTimeout(loadAcademicHierarchy, 0);
  };

  // 🔗 الحصول على الإعدادات الأكاديمية حسب المعلم المختار
  const getFilteredConfigs = () => {
    const all = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    if (selectedTeacherId && selectedTeacherId !== 'admin') {
      return all.filter((c: any) => getRecordTeacherId(c) === normalizeScopeValue(selectedTeacherId));
    }
    return all;
  };

  // 🔄 تحديث الخيارات المتاحة
  const handleGradeChange = (newGrade: string) => {
    setQuizFormData({ ...quizFormData, grade: newGrade, atram: '', subject: '', term: '', unit: '' });
    setLessonContent('');
    setLessonFound(false);

    const hierarchicalConfigs = getFilteredConfigs();
    const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === newGrade);

    if (gradeConfig) {
      setAvailableAtrams(gradeConfig.atrams.map((a: any) => a.atram));
    } else {
      setAvailableAtrams([]);
    }
    setAvailableSubjects([]);
    setAvailableTerms([]);
    setAvailableUnits([]);
  };

  const handleAtramChange = (newAtram: string) => {
    setQuizFormData({ ...quizFormData, atram: newAtram, subject: '', term: '', unit: '' });
    setLessonContent('');
    setLessonFound(false);

    const hierarchicalConfigs = getFilteredConfigs();
    const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === quizFormData.grade);

    if (gradeConfig) {
      const atramConfig = gradeConfig.atrams.find((a: any) => a.atram === newAtram);
      if (atramConfig) {
        setAvailableSubjects(atramConfig.subjects.map((s: any) => s.subject));
      } else {
        setAvailableSubjects([]);
      }
    }
    setAvailableTerms([]);
    setAvailableUnits([]);
  };

  const handleSubjectChange = (newSubject: string) => {
    setQuizFormData({ ...quizFormData, subject: newSubject, term: '', unit: '' });
    setLessonContent('');
    setLessonFound(false);

    const hierarchicalConfigs = getFilteredConfigs();
    const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === quizFormData.grade);

    if (gradeConfig) {
      const atramConfig = gradeConfig.atrams.find((a: any) => a.atram === quizFormData.atram);
      if (atramConfig) {
        const subjectConfig = atramConfig.subjects.find((s: any) => s.subject === newSubject);
        if (subjectConfig) {
          setAvailableTerms(subjectConfig.terms.map((t: any) => t.term));
        } else {
          setAvailableTerms([]);
        }
      }
    }
    setAvailableUnits([]);
  };

  const handleTermChange = (newTerm: string) => {
    setQuizFormData({ ...quizFormData, term: newTerm, unit: '' });
    setLessonContent('');
    setLessonFound(false);

    const hierarchicalConfigs = getFilteredConfigs();
    const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === quizFormData.grade);

    if (gradeConfig) {
      const atramConfig = gradeConfig.atrams.find((a: any) => a.atram === quizFormData.atram);
      if (atramConfig) {
        const subjectConfig = atramConfig.subjects.find((s: any) => s.subject === quizFormData.subject);
        if (subjectConfig) {
          const termConfig = subjectConfig.terms.find((t: any) => t.term === newTerm);
          if (termConfig) {
            setAvailableUnits(termConfig.units);
          } else {
            setAvailableUnits([]);
          }
        }
      }
    }
  };

  const handleUnitChange = (newUnit: string) => {
    setQuizFormData({ ...quizFormData, unit: newUnit });

    // 🔍 سحب محتوى الدرس
    const lessonConfigs: LessonConfig[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.LESSON_CONFIGS) || '[]');
    const normalize = (s: any) => (s || '').toString().trim().toLowerCase();

     const ownerId = selectedTeacherId && selectedTeacherId !== 'admin'
       ? normalizeScopeValue(selectedTeacherId)
       : '';
     const foundLesson = lessonConfigs.find((l: LessonConfig) =>
       (!ownerId || getRecordTeacherId(l) === ownerId) &&
      normalize(l.grade) === normalize(quizFormData.grade) &&
      normalize(l.atram) === normalize(quizFormData.atram) &&
      normalize(l.subject) === normalize(quizFormData.subject) &&
      normalize(l.term) === normalize(quizFormData.term) &&
      normalize(l.unit) === normalize(newUnit)
    );

    if (foundLesson && foundLesson.lessonContent) {
      setLessonContent(foundLesson.lessonContent);
      setLessonFound(true);
    } else {
      setLessonContent('');
      setLessonFound(false);
    }
  };

  // 🤖 توليد اختبار ذكي باحترافية عالية
  const generateSmartQuiz = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!lessonContent.trim()) {
      alert('⚠️ لم يتم العثور على محتوى درس! تأكد من إضافة الدرس في إدارة المحتوى.');
      return;
    }
    
    if (!quizFormData.title.trim()) {
      alert('⚠️ يرجى إدخال عنوان الاختبار');
      return;
    }
    
    setIsGenerating(true);
    
    try {
      const apiKey = import.meta.env.VITE_GEMINI_API_KEY;
      
      if (!apiKey || apiKey === 'your_gemini_api_key_here') {
        alert('❌ يرجى إضافة Gemini API Key في ملف .env\n\nاسم المتغير: VITE_GEMINI_API_KEY');
        setIsGenerating(false);
        return;
      }
      
      console.log('🤖 بدء توليد اختبار من Gemini AI...');
      
      // تقصير المحتوى إذا كان طويلاً جداً (حد أقصى 2000 حرف)
      const contentSummary = lessonContent.length > 2000 
        ? lessonContent.substring(0, 2000) + '...' 
        : lessonContent;
      
      // 🎯 Prompt مختصر وفعّال
      const prompt = `ولّد ${quizFormData.questionCount} أسئلة اختيار من متعدد من هذا المحتوى التعليمي:

${contentSummary}

متطلبات:
- أسئلة متنوعة تغطي المحتوى
- 4 خيارات لكل سؤال
- إجابة واحدة صحيحة (A أو B أو C أو D)
- خيارات معقولة ومتشابهة

أجب بصيغة JSON فقط:
[{"question":"السؤال","options":["خيار1","خيار2","خيار3","خيار4"],"correctAnswer":"A"}]`;

      // استخدام الصيغة الصحيحة المدعومة حالياً
      const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;
      
      console.log('🔗 API URL:', apiUrl.substring(0, 80) + '...');
      
      const response = await fetch(apiUrl, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [{
            parts: [{ text: prompt }]
          }],
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 3000,
          }
        })
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        console.error('❌ خطأ في API:', errorData);
        console.error('❌ رمز الخطأ:', response.status);
        
        let errorMessage = '❌ فشل الاتصال بـ Gemini AI:\n\n';
        
        if (response.status === 400) {
          errorMessage += '⚠️ طلب غير صحيح. قد يكون المحتوى طويلاً جداً.';
        } else if (response.status === 403) {
          errorMessage += '🔒 مفتاح API غير صالح أو منتهي الصلاحية.\n\nاحصل على مفتاح جديد من:\nhttps://aistudio.google.com/apikey';
        } else if (response.status === 429) {
          errorMessage += '⏳ تجاوزت حد الاستخدام. انتظر قليلاً وحاول مرة أخرى.';
        } else if (response.status === 500) {
          errorMessage += '🔧 خطأ في خادم Google. حاول مرة أخرى بعد قليل.';
        } else {
          errorMessage += `رمز الخطأ: ${response.status}\n\nتحقق من:\n1️⃣ صلاحية API Key\n2️⃣ الاتصال بالإنترنت\n3️⃣ حدود الاستخدام`;
        }
        
        alert(errorMessage);
        setIsGenerating(false);
        return;
      }

      const data = await response.json();
      const aiResponse = data.candidates?.[0]?.content?.parts?.[0]?.text;
      
      if (!aiResponse) {
        alert('❌ لم يتم الحصول على رد من الذكاء الاصطناعي. حاول مرة أخرى.');
        setIsGenerating(false);
        return;
      }

      console.log('✅ تم استلام رد من Gemini AI');
      
      // استخراج JSON من الرد
      const jsonMatch = aiResponse.match(/\[[\s\S]*\]/);
      if (!jsonMatch) {
        console.error('❌ فشل استخراج JSON من الرد:', aiResponse);
        alert('❌ فشل تحليل الأسئلة من AI. حاول مرة أخرى.');
        setIsGenerating(false);
        return;
      }

      try {
        const generatedQuestions = JSON.parse(jsonMatch[0]);
        if (!generatedQuestions || generatedQuestions.length === 0) {
          alert('❌ لم يتم توليد أي أسئلة. حاول مرة أخرى.');
          setIsGenerating(false);
          return;
        }
        
        saveQuiz(generatedQuestions);
        alert(`✅ تم إنشاء اختبار احترافي بـ ${generatedQuestions.length} سؤال من Gemini AI!`);
      } catch (parseError) {
        console.error('❌ خطأ في تحليل JSON:', parseError);
        alert('❌ فشل تحليل الأسئلة. حاول مرة أخرى.');
      }
      
    } catch (error) {
      console.error('❌ خطأ في الاتصال بـ Gemini API:', error);
      alert('❌ حدث خطأ في الاتصال بالذكاء الاصطناعي. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.');
    } finally {
      setIsGenerating(false);
    }
  };



  // 💾 حفظ الاختبار
  const saveQuiz = (generatedQuestions: any[]) => {
    const quizId = editingQuiz?.id || `quiz_${Date.now()}`;
    const quizQuestions: QuizQuestion[] = generatedQuestions.map((q, index) => ({
      id: `q_${Date.now()}_${index}_${Math.random()}`,
      question: q.question,
      options: q.options,
      correctAnswer: q.correctAnswer,
      lessonId: 'generated',
      grade: quizFormData.grade,
      subject: quizFormData.subject,
      atram: quizFormData.atram,
      term: quizFormData.term,
      unit: quizFormData.unit,
      quizType: normalizeQuizType(quizFormData.quizType),
      quizId,
      createdAt: new Date().toISOString(),
      source: 'ai-generated',
      variation: Math.floor(Math.random() * 100000)
    }));

    const newQuiz: CreatedQuiz = {
      id: quizId,
      title: quizFormData.title,
      grade: quizFormData.grade,
      subject: quizFormData.subject,
      atram: quizFormData.atram,
      term: quizFormData.term,
      unit: quizFormData.unit,
      quizType: normalizeQuizType(quizFormData.quizType),
      questionCount: quizQuestions.length,
      isActive: quizFormData.isActive,
      questions: quizQuestions,
      createdAt: editingQuiz?.createdAt || new Date().toISOString(),
      createdBy: selectedTeacherId,
      createdByName: selectedTeacherName,
      lastModified: new Date().toISOString()
    };

    let updated: CreatedQuiz[];
    const allSaved: CreatedQuiz[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.CREATED_QUIZZES) || '[]',
    ).map(normalizeCreatedQuiz);
    updated = editingQuiz
      ? allSaved.map(q => q.id === editingQuiz.id ? newQuiz : q)
      : [...allSaved, newQuiz];

    localStorage.setItem(STORAGE_KEYS.CREATED_QUIZZES, JSON.stringify(updated));
    setCreatedQuizzes(updated.filter(q => !teacherId || getRecordTeacherId(q) === normalizeScopeValue(teacherId)));
    setShowCreateForm(false);
    setEditingQuiz(null);
    resetForm();
  };

  const resetForm = () => {
    setQuizFormData({
      title: '',
      grade: '',
      atram: '',
      subject: '',
      term: '',
      unit: '',
      quizType: QuizType.PERIODIC,
      questionCount: 10,
      isActive: true
    });
    setLessonContent('');
    setLessonFound(false);
    setManualQuestions([]);
    setCreationMode('ai');
    setShowAddQuestionForm(false);
  };

  // 💾 حفظ اختبار يدوي
  const saveManualQuiz = () => {
    if (manualQuestions.length === 0) {
      alert('⚠️ يجب إضافة سؤال واحد على الأقل');
      return;
    }

    const quizId = editingQuiz?.id || `quiz_${Date.now()}`;
    const normalizedQuestions = manualQuestions.map(question => ({
      ...question,
      quizId,
      quizType: normalizeQuizType(quizFormData.quizType),
    }));
    const newQuiz: CreatedQuiz = {
      id: quizId,
      title: quizFormData.title,
      grade: quizFormData.grade,
      subject: quizFormData.subject,
      atram: quizFormData.atram,
      term: quizFormData.term,
      unit: quizFormData.unit,
      quizType: normalizeQuizType(quizFormData.quizType),
      questionCount: normalizedQuestions.length,
      isActive: quizFormData.isActive,
      questions: normalizedQuestions,
      createdAt: editingQuiz?.createdAt || new Date().toISOString(),
      createdBy: selectedTeacherId,
      createdByName: selectedTeacherName,
      lastModified: new Date().toISOString()
    };

    let updated: CreatedQuiz[];
    const allSaved: CreatedQuiz[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.CREATED_QUIZZES) || '[]',
    ).map(normalizeCreatedQuiz);
    updated = editingQuiz
      ? allSaved.map(q => q.id === editingQuiz.id ? newQuiz : q)
      : [...allSaved, newQuiz];

    localStorage.setItem(STORAGE_KEYS.CREATED_QUIZZES, JSON.stringify(updated));
    setCreatedQuizzes(updated.filter(q => !teacherId || getRecordTeacherId(q) === normalizeScopeValue(teacherId)));
    setShowCreateForm(false);
    setEditingQuiz(null);
    resetForm();
    alert(`✅ تم حفظ الاختبار اليدوي بنجاح (${manualQuestions.length} سؤال)`);
  };

  // ➕ إضافة سؤال يدوي
  const addManualQuestion = (question: string, options: string[], correctAnswer: string) => {
    const newQuestion: QuizQuestion = {
      id: `q_manual_${Date.now()}_${Math.random()}`,
      question,
      options,
      correctAnswer,
      lessonId: 'manual',
      grade: quizFormData.grade,
      subject: quizFormData.subject,
      atram: quizFormData.atram,
      term: quizFormData.term,
      unit: quizFormData.unit,
      quizType: normalizeQuizType(quizFormData.quizType),
      createdAt: new Date().toISOString(),
      source: 'manual',
      variation: Math.floor(Math.random() * 100000)
    };
    setManualQuestions([...manualQuestions, newQuestion]);
    setShowAddQuestionForm(false);
  };

  // 🗑️ حذف سؤال يدوي
  const deleteManualQuestion = (id: string) => {
    setManualQuestions(manualQuestions.filter(q => q.id !== id));
  };

  // ✏️ تعديل سؤال
  const updateManualQuestion = (id: string, question: string, options: string[], correctAnswer: string) => {
    setManualQuestions(manualQuestions.map(q => 
      q.id === id 
        ? { ...q, question, options, correctAnswer }
        : q
    ));
    setEditingQuestion(null);
  };

  const handleEdit = (quiz: CreatedQuiz) => {
    setEditingQuiz(quiz);
    // ربط المعلم الأصلي بالاختبار
    const tId = normalizeScopeValue(quiz.createdBy || 'admin') || 'admin';
    setSelectedTeacherId(tId);
    if (tId === 'admin') {
      setSelectedTeacherName('المشرف - محتوى عام');
    } else {
      const t = teachers.find((te: any) => te.id === tId);
      setSelectedTeacherName(t?.name || quiz.createdByName || '');
    }
    // إعادة تحميل الهيكل الأكاديمي للمعلم
    setTimeout(() => {
      loadAcademicHierarchy();
      // إعادة تملئة القائمات المترابطة
      const hierarchicalConfigs = getFilteredConfigs();
      const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === quiz.grade);
      if (gradeConfig) {
        setAvailableAtrams(gradeConfig.atrams.map((a: any) => a.atram));
        const atramConfig = gradeConfig.atrams.find((a: any) => a.atram === quiz.atram);
        if (atramConfig) {
          setAvailableSubjects(atramConfig.subjects.map((s: any) => s.subject));
          const subjectConfig = atramConfig.subjects.find((s: any) => s.subject === quiz.subject);
          if (subjectConfig) {
            setAvailableTerms(subjectConfig.terms.map((t: any) => t.term));
            const termConfig = subjectConfig.terms.find((t: any) => t.term === quiz.term);
            if (termConfig) {
              setAvailableUnits(termConfig.units || []);
            }
          }
        }
      }
    }, 0);

    setQuizFormData({
      title: quiz.title,
      grade: quiz.grade,
      atram: quiz.atram,
      subject: quiz.subject,
      term: quiz.term,
      unit: quiz.unit,
      quizType: quiz.quizType,
      questionCount: quiz.questionCount,
      isActive: quiz.isActive
    });

    // تحميل الأسئلة الموجودة
    setManualQuestions(quiz.questions || []);

    // تحديد نوع الإنشاء بناءً على مصدر الأسئلة
    const isManual = quiz.questions?.[0]?.source === 'manual';
    setCreationMode(isManual ? 'manual' : 'ai');

    setShowCreateForm(true);
  };

  const handleDelete = (id: string) => {
    if (!confirm('🗑️ حذف الاختبار نهائياً؟ سيتم حذف جميع الأسئلة المرتبطة به.')) return;
    const allSaved: CreatedQuiz[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.CREATED_QUIZZES) || '[]',
    ).map(normalizeCreatedQuiz);
    const updated = allSaved.filter(q => q.id !== id);
    localStorage.setItem(STORAGE_KEYS.CREATED_QUIZZES, JSON.stringify(updated));
    setCreatedQuizzes(updated.filter(q => !teacherId || getRecordTeacherId(q) === normalizeScopeValue(teacherId)));
  };

  const toggleActive = (id: string) => {
    const allSaved: CreatedQuiz[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.CREATED_QUIZZES) || '[]',
    ).map(normalizeCreatedQuiz);
    const updated = allSaved.map(q =>
      q.id === id ? { ...q, isActive: !q.isActive } : q
    );
    localStorage.setItem(STORAGE_KEYS.CREATED_QUIZZES, JSON.stringify(updated));
    setCreatedQuizzes(updated.filter(q => !teacherId || getRecordTeacherId(q) === normalizeScopeValue(teacherId)));
  };

  return (
    <div className="space-y-6">
      {/* 📊 Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-black text-purple-900">🎯 إدارة الاختبارات</h1>
          <p className="text-purple-500 font-medium">إنشاء وإدارة الاختبارات للطلاب</p>
        </div>
        <button
          onClick={() => {
            setShowCreateForm(!showCreateForm);
            setEditingQuiz(null);
            resetForm();
          }}
          className="bg-gradient-to-r from-purple-500 to-violet-500 text-white px-8 py-4 rounded-[25px] font-black text-lg hover:shadow-2xl transition-all"
        >
          {showCreateForm ? '❌ إلغاء' : '➕ إنشاء اختبار جديد'}
        </button>
      </div>

      {/* 📝 نموذج إنشاء/تعديل اختبار */}
      {showCreateForm && (
        <div className="bg-gradient-to-br from-purple-50 to-violet-50 p-10 rounded-[40px] border-2 border-purple-300 shadow-2xl animate-fadeIn">
          <h2 className="text-2xl font-black text-purple-900 mb-8">
            {editingQuiz ? '📝 تعديل اختبار' : '✨ إنشاء اختبار جديد'}
          </h2>

          {/* اختيار نوع الإنشاء */}
          <div className="mb-6 flex gap-4">
              <button
                type="button"
                onClick={() => setCreationMode('ai')}
                className={`flex-1 p-4 rounded-2xl font-bold transition-all ${
                  creationMode === 'ai'
                    ? 'bg-gradient-to-r from-purple-600 to-violet-600 text-white shadow-lg'
                    : 'bg-white border-2 border-purple-300 text-purple-600'
                }`}
              >
                🤖 توليد ذكي بالـ AI
              </button>
              <button
                type="button"
                onClick={() => setCreationMode('manual')}
                className={`flex-1 p-4 rounded-2xl font-bold transition-all ${
                  creationMode === 'manual'
                    ? 'bg-gradient-to-r from-green-600 to-emerald-600 text-white shadow-lg'
                    : 'bg-white border-2 border-green-300 text-green-600'
                }`}
              >
                ✍️ إنشاء يدوي
              </button>
            </div>

          <form onSubmit={creationMode === 'ai' ? generateSmartQuiz : (e) => { e.preventDefault(); saveManualQuiz(); }} className="space-y-6">
            {/* اختيار المعلم */}
            <div>
              <label className="block font-black text-purple-900 mb-2">👨‍🏫 اختيار المعلم</label>
              {teacherId ? (
                <div className="w-full p-4 border-2 border-purple-200 rounded-2xl bg-purple-50 font-bold text-lg text-purple-800">
                  👨‍🏫 {teacherName || selectedTeacherName}
                </div>
              ) : (
                <select
                  value={selectedTeacherId}
                  onChange={e => handleTeacherChange(e.target.value)}
                  className="w-full p-4 border-2 border-purple-300 rounded-2xl outline-none focus:border-purple-600 bg-white font-bold text-lg"
                  required
                >
                  <option value="admin">📚 محتوى عام (المشرف)</option>
                  {teachers.map((t: any) => (
                    <option key={t.id} value={t.id}>👨‍🏫 {t.name} - {t.subject || 'معلم'}</option>
                  ))}
                </select>
              )}
              {selectedTeacherId !== 'admin' && (
                <p className="text-sm text-purple-700 mt-2 font-bold">
                  ✅ الإعدادات الأكاديمية المتاحة للمعلم: {selectedTeacherName}
                </p>
              )}
            </div>

            {/* عنوان الاختبار */}
            <div>
              <label className="block font-black text-purple-900 mb-2">🏷️ عنوان الاختبار</label>
              <input
                type="text"
                value={quizFormData.title}
                onChange={e => setQuizFormData({ ...quizFormData, title: e.target.value })}
                className="w-full p-4 border-2 border-purple-300 rounded-2xl outline-none focus:border-purple-600 bg-white font-bold text-lg"
                placeholder="مثال: اختبار الوحدة الأولى - الرياضيات"
                required
              />
            </div>

            {/* الاختيارات الأكاديمية */}
            <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
              {/* الصف */}
              <select
                value={quizFormData.grade}
                onChange={e => handleGradeChange(e.target.value)}
                className="p-4 border-2 border-purple-300 rounded-2xl outline-none focus:border-purple-600 bg-white font-bold"
                required
              >
                <option value="">🎓 الصف</option>
                {availableGrades.map((g, i) => <option key={i} value={g}>{g}</option>)}
              </select>

              {/* الترم */}
              <select
                value={quizFormData.atram}
                onChange={e => handleAtramChange(e.target.value)}
                className="p-4 border-2 border-purple-300 rounded-2xl outline-none focus:border-purple-600 bg-white font-bold"
                disabled={!quizFormData.grade}
                required
              >
                <option value="">📅 الترم</option>
                {availableAtrams.map((a, i) => <option key={i} value={a}>{a}</option>)}
              </select>

              {/* المادة */}
              <select
                value={quizFormData.subject}
                onChange={e => handleSubjectChange(e.target.value)}
                className="p-4 border-2 border-purple-300 rounded-2xl outline-none focus:border-purple-600 bg-white font-bold"
                disabled={!quizFormData.atram}
                required
              >
                <option value="">📖 المادة</option>
                {availableSubjects.map((s, i) => <option key={i} value={s}>{s}</option>)}
              </select>

              {/* الفصل */}
              <select
                value={quizFormData.term}
                onChange={e => handleTermChange(e.target.value)}
                className="p-4 border-2 border-purple-300 rounded-2xl outline-none focus:border-purple-600 bg-white font-bold"
                disabled={!quizFormData.subject}
                required
              >
                <option value="">📑 الفصل</option>
                {availableTerms.map((t, i) => <option key={i} value={t}>{t}</option>)}
              </select>

              {/* الوحدة */}
              <select
                value={quizFormData.unit}
                onChange={e => handleUnitChange(e.target.value)}
                className="p-4 border-2 border-purple-300 rounded-2xl outline-none focus:border-purple-600 bg-white font-bold"
                disabled={!quizFormData.term}
                required
              >
                <option value="">📦 الوحدة</option>
                {availableUnits.map((u, i) => <option key={i} value={u}>{u}</option>)}
              </select>
            </div>

            {/* معلومات المحتوى */}
            {quizFormData.unit && (
              <div className="p-6 bg-white rounded-[30px] border-2 border-purple-200">
                {lessonFound ? (
                  <div className="space-y-3">
                    <div className="flex items-center gap-2 text-green-700 font-black">
                      <span className="text-2xl">✅</span>
                      <span>تم العثور على محتوى الدرس</span>
                    </div>
                    <div className="bg-green-50 p-4 rounded-2xl max-h-[150px] overflow-y-auto text-sm text-purple-700">
                      {lessonContent.substring(0, 300)}...
                    </div>
                  </div>
                ) : (
                  <div className="flex items-center gap-2 text-orange-600 font-bold">
                    <span className="text-2xl">⚠️</span>
                    <span>لم يتم العثور على محتوى! أضف الدرس في إدارة المحتوى أولاً</span>
                  </div>
                )}
              </div>
            )}

            {/* إعدادات الاختبار */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {/* نوع الاختبار */}
              <div>
                <label className="block font-black text-purple-900 mb-2">🎯 نوع الاختبار</label>
                <select
                  value={quizFormData.quizType}
                  onChange={e => setQuizFormData({ ...quizFormData, quizType: e.target.value as QuizType })}
                  className="w-full p-4 border-2 border-purple-300 rounded-2xl outline-none focus:border-purple-600 bg-white font-bold"
                >
                  <option value={QuizType.PERIODIC}>الاختبار الدوري</option>
                  <option value={QuizType.TEACHER}>اختبار المعلم</option>
                </select>
              </div>

              {/* عدد الأسئلة */}
              <div>
                <label className="block font-black text-purple-900 mb-2">📊 عدد الأسئلة</label>
                <select
                  value={quizFormData.questionCount}
                  onChange={e => setQuizFormData({ ...quizFormData, questionCount: parseInt(e.target.value) })}
                  className="w-full p-4 border-2 border-purple-300 rounded-2xl outline-none focus:border-purple-600 bg-white font-bold"
                >
                  <option value={5}>5 أسئلة</option>
                  <option value={10}>10 أسئلة</option>
                  <option value={15}>15 سؤال</option>
                  <option value={20}>20 سؤال</option>
                  <option value={25}>25 سؤال</option>
                  <option value={30}>30 سؤال</option>
                </select>
              </div>

              {/* الحالة */}
              <div>
                <label className="block font-black text-purple-900 mb-2">🔘 الحالة</label>
                <select
                  value={quizFormData.isActive ? 'active' : 'inactive'}
                  onChange={e => setQuizFormData({ ...quizFormData, isActive: e.target.value === 'active' })}
                  className="w-full p-4 border-2 border-purple-300 rounded-2xl outline-none focus:border-purple-600 bg-white font-bold"
                >
                  <option value="active">✅ مفعّل (يظهر للطلاب)</option>
                  <option value="inactive">❌ غير مفعّل</option>
                </select>
              </div>
            </div>

            {/* معلومات الاحترافية */}
            <div className="bg-gradient-to-r from-purple-100 to-violet-100 border-2 border-purple-300 p-6 rounded-[25px]">
              <div className="flex items-start gap-3">
                <span className="text-3xl">🎓</span>
                <div>
                  <h3 className="font-black text-purple-900 text-lg mb-2">نظام توليد احترافي</h3>
                  <ul className="text-purple-800 text-sm space-y-1">
                    <li>✅ أسئلة متنوعة (تعريف، فهم، تطبيق، تحليل، تقييم)</li>
                    <li>✅ مستويات صعوبة متدرجة (سهل، متوسط، صعب)</li>
                    <li>✅ خيارات ذكية ومقنعة لجميع الاحتمالات</li>
                    <li>✅ تغطية شاملة لمحتوى الدرس</li>
                    <li>✅ صياغة احترافية بدون أخطاء</li>
                  </ul>
                </div>
              </div>
            </div>

            {/* زر التوليد الذكي أو واجهة الأسئلة اليدوية */}
            {creationMode === 'ai' ? (
              <button
                type="submit"
                disabled={isGenerating || !lessonFound}
                className={`w-full py-6 rounded-[30px] font-black text-2xl transition-all ${
                  isGenerating || !lessonFound
                    ? 'bg-gray-400 cursor-not-allowed'
                    : 'bg-gradient-to-r from-purple-600 to-violet-600 hover:shadow-2xl shadow-purple-300'
                } text-white`}
              >
                {isGenerating ? '⏳ جاري التوليد الاحترافي...' : '✨ توليد الاختبار الآن'}
              </button>
            ) : (
              <div className="space-y-4">
                {/* عرض الأسئلة اليدوية */}
                {manualQuestions.length > 0 && (
                  <div className="bg-white p-6 rounded-[25px] border-2 border-green-300">
                    <h3 className="font-black text-green-900 text-lg mb-4">
                      📝 الأسئلة المضافة ({manualQuestions.length})
                    </h3>
                    <div className="space-y-3 max-h-[400px] overflow-y-auto">
                      {manualQuestions.map((q, idx) => (
                        <div key={q.id} className="bg-purple-50 p-4 rounded-2xl border-2 border-purple-200 flex justify-between items-start">
                          <div className="flex-1">
                            <p className="font-bold text-purple-800 mb-2">{idx + 1}. {q.question}</p>
                            <div className="grid grid-cols-2 gap-2 text-sm">
                              {q.options.map((opt, i) => (
                                <div 
                                  key={i}
                                  className={`p-2 rounded-lg ${
                                    opt === q.correctAnswer 
                                      ? 'bg-green-100 text-green-800 font-bold' 
                                      : 'bg-white text-purple-600'
                                  }`}
                                >
                                  {opt} {opt === q.correctAnswer && '✓'}
                                </div>
                              ))}
                            </div>
                          </div>
                          <div className="flex gap-2">
                            <button
                              type="button"
                              onClick={() => setEditingQuestion(q)}
                              className="p-2 bg-blue-100 text-blue-600 rounded-lg hover:bg-blue-200 transition-all"
                              title="تعديل السؤال"
                            >
                              ✏️
                            </button>
                            <button
                              type="button"
                              onClick={() => deleteManualQuestion(q.id)}
                              className="p-2 bg-red-100 text-red-600 rounded-lg hover:bg-red-200 transition-all"
                              title="حذف السؤال"
                            >
                              🗑️
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* نموذج تعديل سؤال */}
                {editingQuestion && (
                  <EditQuestionForm 
                    question={editingQuestion}
                    onUpdate={updateManualQuestion}
                    onCancel={() => setEditingQuestion(null)}
                  />
                )}

                {/* نموذج إضافة سؤال */}
                {showAddQuestionForm ? (
                  <ManualQuestionForm 
                    onAdd={addManualQuestion}
                    onCancel={() => setShowAddQuestionForm(false)}
                  />
                ) : (
                  <button
                    type="button"
                    onClick={() => setShowAddQuestionForm(true)}
                    className="w-full py-4 rounded-[25px] font-black text-lg bg-gradient-to-r from-green-600 to-emerald-600 text-white hover:shadow-xl transition-all"
                  >
                    ➕ إضافة سؤال جديد
                  </button>
                )}

                {/* زر حفظ الاختبار اليدوي */}
                {manualQuestions.length > 0 && (
                  <button
                    type="submit"
                    className="w-full py-6 rounded-[30px] font-black text-2xl bg-gradient-to-r from-green-600 to-emerald-600 text-white hover:shadow-2xl shadow-green-300 transition-all"
                  >
                    💾 حفظ الاختبار ({manualQuestions.length} سؤال)
                  </button>
                )}
              </div>
            )}
          </form>
        </div>
      )}

      {/* 📋 قائمة الاختبارات المنشأة */}
      <div className="space-y-4">
        <h2 className="text-2xl font-black text-purple-900">
          📚 الاختبارات المنشأة ({createdQuizzes.length})
        </h2>

        {createdQuizzes.length === 0 ? (
          <div className="p-32 text-center bg-white rounded-[40px] border-2 border-dashed border-purple-200">
            <div className="text-6xl mb-4">📝</div>
            <h3 className="text-2xl font-black text-purple-300 mb-2">لا توجد اختبارات حتى الآن</h3>
            <p className="text-purple-400">ابدأ بإنشاء اختبار جديد</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-4">
            {createdQuizzes.map(quiz => (
              <div key={quiz.id} className="bg-white p-6 rounded-[30px] border-2 border-purple-100 shadow-sm hover:shadow-lg transition-all">
                <div className="flex justify-between items-start gap-6">
                  {/* معلومات الاختبار */}
                  <div className="flex-1 space-y-3">
                    {/* العنوان */}
                    <div className="flex items-center gap-3">
                      <h3 className="text-2xl font-black text-purple-900">{quiz.title}</h3>
                      <span className={`px-4 py-1.5 rounded-full text-xs font-black ${
                        quiz.isActive
                          ? 'bg-green-100 text-green-700'
                          : 'bg-gray-100 text-gray-600'
                      }`}>
                        {quiz.isActive ? '✅ مفعّل' : '❌ غير مفعّل'}
                      </span>
                    </div>

                    {/* التصنيفات */}
                    <div className="flex gap-2 flex-wrap">
                      <span className="bg-purple-100 text-purple-700 px-3 py-1 rounded-full text-xs font-bold">{quiz.grade}</span>
                      <span className="bg-blue-100 text-blue-700 px-3 py-1 rounded-full text-xs font-bold">{quiz.subject}</span>
                      <span className="bg-emerald-100 text-emerald-700 px-3 py-1 rounded-full text-xs font-bold">{quiz.atram}</span>
                      <span className="bg-amber-100 text-amber-700 px-3 py-1 rounded-full text-xs font-bold">{quiz.term}</span>
                      <span className="bg-purple-100 text-purple-700 px-3 py-1 rounded-full text-xs font-bold">{quiz.unit}</span>
                      <span className="bg-orange-100 text-orange-700 px-3 py-1 rounded-full text-xs font-bold">
                        {getQuizTypeLabel(quiz.quizType)}
                      </span>
                      {quiz.createdByName && (
                        <span className="bg-purple-900 text-white px-3 py-1 rounded-full text-xs font-bold flex items-center gap-1">
                          <span>👨‍🏫</span>
                          {quiz.createdByName}
                        </span>
                      )}
                    </div>

                    {/* معلومات إضافية */}
                    <div className="flex gap-6 text-sm text-purple-500">
                      <span>📊 {quiz.questions.length} سؤال</span>
                      <span>📅 {new Date(quiz.createdAt).toLocaleDateString('ar-SA')}</span>
                      {quiz.lastModified && <span>🔄 آخر تعديل: {new Date(quiz.lastModified).toLocaleDateString('ar-SA')}</span>}
                    </div>

                    {/* عرض الأسئلة */}
                    {quiz.questions.length > 0 && (
                      <details className="mt-4">
                        <summary className="cursor-pointer font-bold text-purple-500 hover:text-purple-800">
                          👁️ عرض الأسئلة ({quiz.questions.length})
                        </summary>
                        <div className="mt-4 space-y-3 max-h-[400px] overflow-y-auto">
                          {quiz.questions.map((q, idx) => (
                            <div key={idx} className="bg-purple-50 p-4 rounded-2xl border-2 border-purple-200">
                              <p className="font-bold text-purple-800 mb-2">{idx + 1}. {q.question}</p>
                              <div className="grid grid-cols-2 gap-2 text-sm">
                                {q.options.map((opt, i) => (
                                  <div 
                                    key={i}
                                    className={`p-2 rounded-lg ${
                                      opt === q.correctAnswer 
                                        ? 'bg-green-100 text-green-800 font-bold' 
                                        : 'bg-white text-purple-600'
                                    }`}
                                  >
                                    {opt} {opt === q.correctAnswer && '✓'}
                                  </div>
                                ))}
                              </div>
                            </div>
                          ))}
                        </div>
                      </details>
                    )}
                  </div>

                  {/* الأزرار */}
                  <div className="flex gap-2">
                    <button
                      onClick={() => toggleActive(quiz.id)}
                      className={`px-4 py-2 rounded-xl font-bold transition-all ${
                        quiz.isActive
                          ? 'bg-orange-100 text-orange-600 hover:bg-orange-200'
                          : 'bg-green-100 text-green-600 hover:bg-green-200'
                      }`}
                      title={quiz.isActive ? 'تعطيل' : 'تفعيل'}
                    >
                      {quiz.isActive ? '🔴' : '🟢'}
                    </button>
                    <button
                      onClick={() => handleEdit(quiz)}
                      className="px-4 py-2 bg-blue-100 text-blue-600 rounded-xl font-bold hover:bg-blue-200 transition-all"
                      title="تعديل"
                    >
                      ✏️
                    </button>
                    <button
                      onClick={() => handleDelete(quiz.id)}
                      className="px-4 py-2 bg-red-100 text-red-600 rounded-xl font-bold hover:bg-red-200 transition-all"
                      title="حذف"
                    >
                      🗑️
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default QuizManagement;