
import React, { useState, useEffect } from 'react';
import { readHierarchicalConfigs } from '../../utils/academic';
import { useSyncHydrating } from '../../hooks/useSyncHydrating';
import { QuizQuestion, QuizType, LessonConfig, CreatedQuiz } from '../../types';
import { STORAGE_KEYS, QUIZ_TYPES } from '../../constants';
import { getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import { getPeriodicQuizLabel, getQuizTypeLabel, normalizeCreatedQuiz, normalizeQuizType } from '../../utils/quizTypes';

interface QuizManagementProps {
  onUpdate: () => void;
  teacherId?: string;
  teacherName?: string;
}

const uniqueAcademicValues = (values: unknown[]): string[] => {
  const seen = new Set<string>();
  return values.reduce<string[]>((unique, value) => {
    const displayValue = String(value ?? '').trim();
    const normalizedValue = normalizeScopeValue(displayValue);
    if (!displayValue || seen.has(normalizedValue)) return unique;
    seen.add(normalizedValue);
    unique.push(displayValue);
    return unique;
  }, []);
};

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
  const [availableSubjects, setAvailableSubjects] = useState<string[]>([]);
  const [availableTerms, setAvailableTerms] = useState<string[]>([]);
  const [availableUnits, setAvailableUnits] = useState<string[]>([]);
  /// أسماء الدروس المعرّفة للوحدة المختارة في الإعدادات الأكاديمية.
  const [availableLessons, setAvailableLessons] = useState<string[]>([]);
  /// هل ما زالت الشجرة الأكاديمية في طريقها من الخادم؟
  const hydrating = useSyncHydrating();

  // 🔎 فلاتر قائمة الاختبارات المنشأة
  const [listSearch, setListSearch] = useState('');
  const [listSubject, setListSubject] = useState('all');
  const [listGrade, setListGrade] = useState('all');
  const [listTerm, setListTerm] = useState('all');
  const [listStatus, setListStatus] = useState<'all' | 'active' | 'locked'>('all');

  // 📝 محتوى الدرس المسحوب
  const [lessonContent, setLessonContent] = useState('');
  const [lessonFound, setLessonFound] = useState(false);
  /// كم درساً دُمجت نصوصه في الحقل — يعرف المعلم حجم ما يولّد منه.
  const [mergedLessons, setMergedLessons] = useState(0);

  const [quizFormData, setQuizFormData] = useState({
    title: '',
    grade: '',
    subject: '',
    term: '',
    unit: '',
    /// المستوى السادس. فارغ يعني اختباراً يغطي الوحدة كاملة.
    lesson: '',
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
    const deletedQuizIds = new Set<string>(
      JSON.parse(localStorage.getItem(STORAGE_KEYS.DELETED_QUIZZES) || '[]')
        .filter((value: unknown) => typeof value === 'string'),
    );
    const visible = (teacherId
      ? all.filter((quiz: CreatedQuiz) => getRecordTeacherId(quiz) === normalizeScopeValue(teacherId))
      : all
    ).filter((quiz: CreatedQuiz) => !quiz.deleted && !deletedQuizIds.has(String(quiz.id)));
    setCreatedQuizzes(visible);
    if (JSON.stringify(all) !== saved) {
      localStorage.setItem(STORAGE_KEYS.CREATED_QUIZZES, JSON.stringify(all));
    }
  };

  // 📚 تحميل الهيكل الأكاديمي
  const loadAcademicHierarchy = () => {
    const allHierarchicalConfigs = readHierarchicalConfigs(STORAGE_KEYS.HIERARCHICAL_CONFIGS);
    const teachersList = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
    setTeachers(teachersList);

    // فلترة الإعدادات الأكاديمية حسب المعلم المختار
    let filtered = allHierarchicalConfigs;
    if (selectedTeacherId && selectedTeacherId !== 'admin') {
      filtered = allHierarchicalConfigs.filter((c: any) => getRecordTeacherId(c) === normalizeScopeValue(selectedTeacherId));
    }
    const grades = uniqueAcademicValues(filtered.map((c: any) => c.grade));
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
      subject: '',
      term: '',
      unit: '',
      lesson: '',
       quizType: QuizType.PERIODIC,
      questionCount: 10,
      isActive: true
    });
    setLessonContent('');
    setLessonFound(false);
    setAvailableGrades([]);
    setAvailableSubjects([]);
    setAvailableTerms([]);
    setAvailableUnits([]);
    setAvailableLessons([]);

    setTimeout(loadAcademicHierarchy, 0);
  };

  // 🔗 الحصول على الإعدادات الأكاديمية حسب المعلم المختار
  const getFilteredConfigs = () => {
    const all = readHierarchicalConfigs(STORAGE_KEYS.HIERARCHICAL_CONFIGS);
    if (selectedTeacherId && selectedTeacherId !== 'admin') {
      return all.filter((c: any) => getRecordTeacherId(c) === normalizeScopeValue(selectedTeacherId));
    }
    return all;
  };

  // 🔄 تحديث الخيارات المتاحة
  const handleGradeChange = (newGrade: string) => {
    setQuizFormData({ ...quizFormData, grade: newGrade, subject: '', term: '', unit: '', lesson: '' });
    setLessonContent('');
    setLessonFound(false);

    const hierarchicalConfigs = getFilteredConfigs();
    const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === newGrade);

    setAvailableSubjects(
      gradeConfig ? uniqueAcademicValues(gradeConfig.subjects.map((s: any) => s.subject)) : [],
    );
    setAvailableTerms([]);
    setAvailableUnits([]);
    setAvailableLessons([]);

  };


  const handleSubjectChange = (newSubject: string) => {
    setQuizFormData({ ...quizFormData, subject: newSubject, term: '', unit: '', lesson: '' });
    setLessonContent('');
    setLessonFound(false);

    const hierarchicalConfigs = getFilteredConfigs();
    const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === quizFormData.grade);

    if (gradeConfig) {
        const subjectConfig = gradeConfig.subjects.find((s: any) => s.subject === newSubject);
        if (subjectConfig) {
          setAvailableTerms(
            uniqueAcademicValues(subjectConfig.terms.map((t: any) => t.term)),
          );
        } else {
          setAvailableTerms([]);
        }
      }
    setAvailableUnits([]);
    setAvailableLessons([]);

  };

  const handleTermChange = (newTerm: string) => {
    setQuizFormData({ ...quizFormData, term: newTerm, unit: '', lesson: '' });
    setLessonContent('');
    setLessonFound(false);

    const hierarchicalConfigs = getFilteredConfigs();
    const gradeConfig = hierarchicalConfigs.find((c: any) => c.grade === quizFormData.grade);

    if (gradeConfig) {
        const subjectConfig = gradeConfig.subjects.find((s: any) => s.subject === quizFormData.subject);
        if (subjectConfig) {
          const termConfig = subjectConfig.terms.find((t: any) => t.term === newTerm);
          if (termConfig) {
            setAvailableUnits(uniqueAcademicValues(termConfig.units));
          } else {
            setAvailableUnits([]);
            setAvailableLessons([]);

          }
        }
      }
  };

  /// دروس وحدة من الشجرة الهرمية — نفس عقد `term.lessons` المستعمل في إدارة
  /// المحتوى والسينما، فمصدر الدروس واحد عبر المنصة كلها.
  const getLessonsFor = (unit: string): string[] => {
    if (!unit) return [];
    const all = readHierarchicalConfigs(STORAGE_KEYS.HIERARCHICAL_CONFIGS);
    const scoped = selectedTeacherId && selectedTeacherId !== 'admin'
      ? all.filter((c: any) => getRecordTeacherId(c) === normalizeScopeValue(selectedTeacherId))
      : all;
    const grade = scoped.find((c: any) => c.grade === quizFormData.grade);
    const subject = grade?.subjects?.find((s: any) => s.subject === quizFormData.subject);
    const term = subject?.terms?.find((t: any) => t.term === quizFormData.term);
    const lessons = term?.lessons?.[unit];
    return Array.isArray(lessons) ? uniqueAcademicValues(lessons) : [];
  };

  /**
   * نصّ الدروس على هذا المسار، ومعه عددها.
   *
   * ‏بدرسٍ محدَّد: نصّ ذلك الدرس وحده. وبلا درس: نصوص دروس الوحدة كلها
   * ‏مجموعة، كلٌّ تحت عنوانه — فاختبار الوحدة يُولَّد من الوحدة كلها، لا
   * ‏من أوّل درس يصادفه البحث كما كان.
   *
   * ‏وكان `find` يأخذ أوّل سجلّ يطابق الوحدة ويتجاهل أيّ درس هو، فيُبنى
   * ‏اختبار «الوحدة» من درس واحد منها.
   */
  const collectLessonContent = (
    path: { grade: string; subject: string; term: string; unit: string; lesson?: string },
  ): { text: string; lessonCount: number } => {
    const lessonConfigs: LessonConfig[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.LESSON_CONFIGS) || '[]',
    );
    const normalize = (value: any) => (value || '').toString().trim().toLowerCase();
    const ownerId = selectedTeacherId && selectedTeacherId !== 'admin'
      ? normalizeScopeValue(selectedTeacherId)
      : '';

    const inUnit = lessonConfigs.filter((item: LessonConfig) =>
      (!ownerId || getRecordTeacherId(item) === ownerId) &&
      normalize(item.grade) === normalize(path.grade) &&
      normalize(item.subject) === normalize(path.subject) &&
      normalize(item.term) === normalize(path.term) &&
      normalize(item.unit) === normalize(path.unit),
    );

    const wanted = path.lesson
      ? inUnit.filter((item) => normalize(item.lesson) === normalize(path.lesson))
      : inUnit;

    const withText = wanted.filter((item) => (item.lessonContent || '').trim());
    if (withText.length === 0) return { text: '', lessonCount: 0 };
    if (withText.length === 1) {
      return { text: withText[0].lessonContent.trim(), lessonCount: 1 };
    }
    // ‏كل درس تحت عنوانه: النموذج المولِّد يقرأ نصّاً واحداً، والعناوين
    // ‏هي ما يبقي حدود الدروس ظاهرة فيه.
    return {
      text: withText
        .map((item) => `## ${item.lesson || item.unit}\n${item.lessonContent.trim()}`)
        .join('\n\n'),
      lessonCount: withText.length,
    };
  };

  /// يملأ حقل النصّ من المسار الحالي، ويضبط نوع الاختبار على مستواه.
  const applyScope = (next: typeof quizFormData) => {
    const found = collectLessonContent(next);
    setLessonContent(found.text);
    setLessonFound(found.lessonCount > 0);
    setMergedLessons(found.lessonCount);
    // ‏المستوى يحدّد النوع: درسٌ بعينه اختبار دوري تدريبي يُعاد، والوحدة
    // ‏كاملةً اختبار شامل يُؤدّى مرة. وتطبيق الطالب يمنع إعادة اختبار
    // ‏المعلم ويسمح بإعادة الدوري، فالنوع هو ما ينفَّذ فعلاً لا الرايتان.
    setQuizFormData({
      ...next,
      quizType: next.lesson.trim() ? QuizType.PERIODIC : QuizType.TEACHER,
    });
  };

  const handleUnitChange = (newUnit: string) => {
    setAvailableLessons(getLessonsFor(newUnit));
    applyScope({ ...quizFormData, unit: newUnit, lesson: '' });
  };

  const handleLessonChange = (newLesson: string) => {
    applyScope({ ...quizFormData, lesson: newLesson });
  };

  /// هل يقع هذا الاختبار على المسار المعروض في النموذج الآن؟
  ///
  /// ‏يشمل الدرس. فبدونه كان درسان في وحدة واحدة يُعدّان مساراً واحداً،
  /// ‏فيمنع «أُنشئ الاختبار الدوري لهذا المسار مسبقاً» إنشاء اختبار
  /// ‏للدرس الثاني، ويختلّ ترقيم الاختبارات الدورية بينهما. واختبارات
  /// ‏الوحدة تبقى مجموعة معاً، فالدرس فيها فارغ عند الطرفين.
  const isSameQuizScope = (quiz: CreatedQuiz, formData = quizFormData) =>
    getRecordTeacherId(quiz) === normalizeScopeValue(selectedTeacherId) &&
    normalizeScopeValue(quiz.grade) === normalizeScopeValue(formData.grade) &&
    normalizeScopeValue(quiz.subject) === normalizeScopeValue(formData.subject) &&
    normalizeScopeValue(quiz.term) === normalizeScopeValue(formData.term) &&
    normalizeScopeValue(quiz.unit) === normalizeScopeValue(formData.unit) &&
    normalizeScopeValue(quiz.lesson) === normalizeScopeValue(formData.lesson);

  const getSavedQuizzes = (): CreatedQuiz[] => {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEYS.CREATED_QUIZZES) || '[]')
        .map(normalizeCreatedQuiz)
        .filter((quiz: CreatedQuiz) => !quiz.deleted);
    } catch {
      return [];
    }
  };

  const hasGeneratedPeriodicQuiz = () =>
    getSavedQuizzes().some((quiz) =>
      quiz.id !== editingQuiz?.id &&
      normalizeQuizType(quiz.quizType) === QuizType.PERIODIC &&
      quiz.creationMode === 'ai' &&
      isSameQuizScope(quiz),
    );

  const getNextManualPeriodicNumber = (saved: CreatedQuiz[], quizId?: string) => {
    const matchingManualQuizzes = saved
      .filter((quiz) =>
        quiz.id !== quizId &&
        normalizeQuizType(quiz.quizType) === QuizType.PERIODIC &&
        quiz.creationMode === 'manual' &&
        isSameQuizScope(quiz),
      );
    const numbers = matchingManualQuizzes.map((quiz) => Number(quiz.periodicNumber) || 0);
    return Math.max(matchingManualQuizzes.length, ...numbers) + 1;
  };

  // 🤖 توليد اختبار ذكي باحترافية عالية
  const generateSmartQuiz = async () => {
    if (!lessonContent.trim()) {
      alert('⚠️ لم يتم العثور على محتوى درس! تأكد من إضافة الدرس في إدارة المحتوى.');
      return;
    }
    
    if (!quizFormData.title.trim()) {
      alert('⚠️ يرجى إدخال عنوان الاختبار');
      return;
    }

    if (normalizeQuizType(quizFormData.quizType) === QuizType.PERIODIC && hasGeneratedPeriodicQuiz()) {
      alert('⚠️ تم إنشاء الاختبار الدوري بالذكاء الاصطناعي لهذا المسار مسبقاً. يمكنك تعديله من قائمة الاختبارات.');
      return;
    }
    
    setIsGenerating(true);
    
    try {
      console.log('🤖 بدء توليد اختبار من Gemini AI...');
      
      // تقصير المحتوى إذا كان طويلاً جداً (حد أقصى 2000 حرف)
      const contentSummary = lessonContent.length > 2000 
        ? lessonContent.substring(0, 2000) + '...' 
        : lessonContent;
      
      // 🎯 Prompt مختصر وفعّال
      const requestedQuestionCount = Math.max(1, Math.min(quizFormData.questionCount, 30));
      // The selected number is the number shown to each student. Generate a
      // larger bank so student-specific selection can produce different sets.
      const bankSize = Math.min(Math.max(requestedQuestionCount * 3, requestedQuestionCount + 10), 60);
      const prompt = `ولّد بالضبط ${bankSize} سؤال اختيار من متعدد من هذا المحتوى التعليمي.
هذا بنك أسئلة مشترك سيختار منه النظام ${requestedQuestionCount} أسئلة مختلفة وثابتة لكل طالب. لا تنشئ أقل من العدد المطلوب ولا تضف أي نص خارج JSON:

${contentSummary}

متطلبات:
- أسئلة متنوعة تغطي المحتوى
- 4 خيارات لكل سؤال
- إجابة واحدة صحيحة (A أو B أو C أو D)
- خيارات معقولة ومتشابهة

أجب بصيغة JSON فقط:
[{"question":"السؤال","options":["خيار1","خيار2","خيار3","خيار4"],"correctAnswer":"A"}]`;

      const response = await fetch('/api/gemini/generate-quiz', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          prompt,
          temperature: 0.7,
          maxOutputTokens: 9000,
        })
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        console.error('❌ خطأ في API:', errorData);
        console.error('❌ رمز الخطأ:', response.status);
        
        let errorMessage = '❌ فشل الاتصال بـ Gemini AI:\n\n';
        
        if (
          response.status === 401 &&
          typeof errorData?.error === 'string' &&
          /تسجيل الدخول|جلسة/i.test(errorData.error)
        ) {
          errorMessage += '🔐 انتهت جلسة المعلم أو المشرف. سجّل الخروج ثم سجّل الدخول مرة أخرى، وبعدها أعد التوليد.';
        } else if (response.status === 400) {
          errorMessage += '⚠️ طلب غير صحيح. قد يكون المحتوى طويلاً جداً.';
        } else if (response.status === 403) {
          errorMessage += errorData?.error || '🔒 لا تملك صلاحية توليد هذا الاختبار.';
        } else if (response.status === 429) {
          errorMessage += '⏳ تجاوزت حد الاستخدام. انتظر قليلاً وحاول مرة أخرى.';
        } else if (response.status === 500 || response.status === 502) {
          errorMessage += '🔧 خطأ في خادم Google. حاول مرة أخرى بعد قليل.';
        } else if (response.status === 503) {
          errorMessage += '⚠️ لا يوجد نموذج Gemini متاح حاليًا لهذا المفتاح. حاول مرة أخرى لاحقًا أو حدّد GEMINI_MODEL في Secrets.';
        } else {
          errorMessage += `رمز الخطأ: ${response.status}\n\nتحقق من:\n1️⃣ صلاحية API Key\n2️⃣ الاتصال بالإنترنت\n3️⃣ حدود الاستخدام`;
        }
        
        alert(errorMessage);
        setIsGenerating(false);
        return;
      }

      const data = await response.json();
      const aiResponse = data.text || data.candidates?.[0]?.content?.parts
        ?.map((part: { text?: string }) => part?.text || '')
        .join('')
        .trim();
      
      if (!aiResponse) {
        alert('❌ لم يتم الحصول على رد من الذكاء الاصطناعي. حاول مرة أخرى.');
        setIsGenerating(false);
        return;
      }

      console.log('✅ تم استلام رد من Gemini AI');
      
      try {
        // Gemini may wrap JSON in a markdown fence even when JSON mode is
        // requested. Remove the fence and parse the complete array safely.
        const cleanedResponse = aiResponse
          .replace(/^```(?:json)?\s*/i, '')
          .replace(/\s*```$/i, '')
          .trim();
        const arrayStart = cleanedResponse.indexOf('[');
        const arrayEnd = cleanedResponse.lastIndexOf(']');
        const jsonText = arrayStart >= 0 && arrayEnd > arrayStart
          ? cleanedResponse.slice(arrayStart, arrayEnd + 1)
          : cleanedResponse;
        const parsedQuestions = JSON.parse(jsonText);
        const generatedQuestions = Array.isArray(parsedQuestions)
          ? parsedQuestions
              .filter((question: any) =>
                question &&
                typeof question.question === 'string' &&
                Array.isArray(question.options) &&
                question.options.length >= 4 &&
                typeof question.correctAnswer === 'string',
              )
              .slice(0, bankSize)
          : [];
        if (!generatedQuestions || generatedQuestions.length === 0) {
          console.error('❌ لم يتم العثور على أسئلة صالحة في رد AI:', {
            finishReason: data.candidates?.[0]?.finishReason,
            responseLength: aiResponse.length,
            responsePreview: aiResponse.slice(0, 500),
          });
          alert('❌ لم يتم توليد أسئلة صالحة. حاول مرة أخرى.');
          setIsGenerating(false);
          return;
        }
        
        if (saveQuiz(generatedQuestions)) {
          alert(`✅ تم إنشاء بنك احترافي بـ ${generatedQuestions.length} سؤالًا، وسيظهر لكل طالب ${requestedQuestionCount} أسئلة مختلفة.`);
        }
      } catch (parseError) {
        console.error('❌ خطأ في تحليل JSON:', {
          error: parseError,
          finishReason: data.candidates?.[0]?.finishReason,
          responseLength: aiResponse.length,
          responsePreview: aiResponse.slice(-500),
        });
        alert(
          data.candidates?.[0]?.finishReason === 'MAX_TOKENS'
            ? '❌ الرد كان طويلًا ولم يكتمل. قلّل عدد الأسئلة أو حاول مرة أخرى.'
            : '❌ فشل تحليل الأسئلة. حاول مرة أخرى.',
        );
      }
      
    } catch (error) {
      console.error('❌ خطأ في الاتصال بـ Gemini API:', error);
      alert('❌ حدث خطأ في الاتصال بالذكاء الاصطناعي. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.');
    } finally {
      setIsGenerating(false);
    }
  };



  // 💾 حفظ الاختبار
  const saveQuiz = (generatedQuestions: any[]): boolean => {
    const quizId = editingQuiz?.id || `quiz_${Date.now()}`;
    const requestedQuestionCount = Math.max(1, Math.min(quizFormData.questionCount, 30));
    const quizQuestions: QuizQuestion[] = generatedQuestions.map((q, index) => ({
      id: `q_${Date.now()}_${index}_${Math.random()}`,
      question: q.question,
      options: q.options,
      correctAnswer: q.correctAnswer,
      lessonId: 'generated',
      grade: quizFormData.grade,
      subject: quizFormData.subject,
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
      term: quizFormData.term,
      unit: quizFormData.unit,
      lesson: quizFormData.lesson.trim() || undefined,
      quizType: normalizeQuizType(quizFormData.quizType),
      // ‏الرايتان مكتوبتان صراحةً ليقرأهما التقرير والخادم بلا أن يستنتجا
      // ‏النوع. والتنفيذ يبقى على `quizType`: تطبيق الطالب يمنع إعادة
      // ‏اختبار المعلم ويسمح بإعادة الدوري، وهو ما يعمل اليوم.
      isRepeatable: Boolean(quizFormData.lesson.trim()),
      allowRetake: Boolean(quizFormData.lesson.trim()),
      questionCount: quizQuestions.length,
      isActive: quizFormData.isActive,
      questions: quizQuestions,
      creationMode: 'ai',
      periodicNumber: editingQuiz?.periodicNumber,
      questionsPerAttempt: Math.min(requestedQuestionCount, quizQuestions.length),
      createdAt: editingQuiz?.createdAt || new Date().toISOString(),
      createdBy: selectedTeacherId,
      createdByName: selectedTeacherName,
      lastModified: new Date().toISOString()
    };

    let updated: CreatedQuiz[];
    const allSaved: CreatedQuiz[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.CREATED_QUIZZES) || '[]',
    ).map(normalizeCreatedQuiz);
    if (
      normalizeQuizType(quizFormData.quizType) === QuizType.PERIODIC &&
      hasGeneratedPeriodicQuiz()
    ) {
      alert('⚠️ يوجد اختبار دوري مولّد بالذكاء الاصطناعي لهذا المسار بالفعل.');
      return false;
    }
    updated = editingQuiz
      ? allSaved.map(q => q.id === editingQuiz.id ? newQuiz : q)
      : [...allSaved, newQuiz];

    localStorage.setItem(STORAGE_KEYS.CREATED_QUIZZES, JSON.stringify(updated));
    setCreatedQuizzes(updated.filter(q => !teacherId || getRecordTeacherId(q) === normalizeScopeValue(teacherId)));
    setShowCreateForm(false);
    setEditingQuiz(null);
    resetForm();
    return true;
  };

  const resetForm = () => {
    setQuizFormData({
      title: '',
      grade: '',
      subject: '',
      term: '',
      unit: '',
      lesson: '',
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
    const allSaved: CreatedQuiz[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.CREATED_QUIZZES) || '[]',
    ).map(normalizeCreatedQuiz);
    const quizType = normalizeQuizType(quizFormData.quizType);
    const periodicNumber = quizType === QuizType.PERIODIC
      ? (editingQuiz?.periodicNumber || getNextManualPeriodicNumber(allSaved, editingQuiz?.id))
      : undefined;
    const newQuiz: CreatedQuiz = {
      id: quizId,
      title: quizFormData.title,
      grade: quizFormData.grade,
      subject: quizFormData.subject,
      term: quizFormData.term,
      unit: quizFormData.unit,
      lesson: quizFormData.lesson.trim() || undefined,
      quizType: normalizeQuizType(quizFormData.quizType),
      // ‏الرايتان مكتوبتان صراحةً ليقرأهما التقرير والخادم بلا أن يستنتجا
      // ‏النوع. والتنفيذ يبقى على `quizType`: تطبيق الطالب يمنع إعادة
      // ‏اختبار المعلم ويسمح بإعادة الدوري، وهو ما يعمل اليوم.
      isRepeatable: Boolean(quizFormData.lesson.trim()),
      allowRetake: Boolean(quizFormData.lesson.trim()),
      questionCount: normalizedQuestions.length,
      isActive: quizFormData.isActive,
      questions: normalizedQuestions,
      creationMode: 'manual',
      periodicNumber,
      questionsPerAttempt: Math.min(quizFormData.questionCount, normalizedQuestions.length),
      createdAt: editingQuiz?.createdAt || new Date().toISOString(),
      createdBy: selectedTeacherId,
      createdByName: selectedTeacherName,
      lastModified: new Date().toISOString()
    };

    let updated: CreatedQuiz[];
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

  /// خيارات الفلاتر مشتقّة من الاختبارات الموجودة فعلاً، لا من قوائم ثابتة:
  /// فلا يعرض الفلتر صفاً أو مادة لا اختبار فيها.
  const listFilterOptions = {
    subjects: uniqueAcademicValues(createdQuizzes.map(q => q.subject)),
    grades: uniqueAcademicValues(createdQuizzes.map(q => q.grade)),
    // ‏أسماء الفصول تأتي من شجرة المعلم لا من قائمة ثابتة: هو من يسمّيها
    // ‏حين ينشئها، فقد تكون «الفصل الدراسي الأول» أو «الفصل الأول» أو
    // ‏«الترم الثاني». خياران مكتوبان في الشيفرة كانا سيُظهران فلتراً لا
    // ‏يطابق شيئاً عند من سمّاها على غير ما توقّعناه.
    terms: uniqueAcademicValues(createdQuizzes.map(q => q.term)),
  };

  const visibleQuizzes = createdQuizzes.filter(quiz => {
    const needle = listSearch.trim().toLowerCase();
    if (needle) {
      const haystack = [quiz.title, quiz.unit, quiz.lesson, quiz.createdByName]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      if (!haystack.includes(needle)) return false;
    }
    if (listSubject !== 'all' && quiz.subject !== listSubject) return false;
    if (listGrade !== 'all' && quiz.grade !== listGrade) return false;
    if (listTerm !== 'all' && quiz.term !== listTerm) return false;
    if (listStatus === 'active' && !quiz.isActive) return false;
    if (listStatus === 'locked' && quiz.isActive) return false;
    return true;
  });

  const listFiltersActive =
    Boolean(listSearch.trim()) || listSubject !== 'all' || listGrade !== 'all'
    || listTerm !== 'all' || listStatus !== 'all';

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
          setAvailableSubjects(gradeConfig.subjects.map((s: any) => s.subject));
          const subjectConfig = gradeConfig.subjects.find((s: any) => s.subject === quiz.subject);
          if (subjectConfig) {
            setAvailableTerms(subjectConfig.terms.map((t: any) => t.term));
            const termConfig = subjectConfig.terms.find((t: any) => t.term === quiz.term);
            if (termConfig) {
              setAvailableUnits(termConfig.units || []);
              // دروس الوحدة، مع ضمّ درس الاختبار المحفوظ إن حُذف لاحقاً من
              // الشجرة — وإلا فُتح النموذج على قائمة فارغة فبدا أن الدرس ضاع،
              // وأي حفظ يمحوه فعلاً.
              const saved = Array.isArray(termConfig.lessons?.[quiz.unit])
                ? termConfig.lessons[quiz.unit]
                : [];
              const withCurrent = quiz.lesson && !saved.includes(quiz.lesson)
                ? [quiz.lesson, ...saved]
                : saved;
              setAvailableLessons(uniqueAcademicValues(withCurrent));
            }
          }
        }
    }, 0);

    setQuizFormData({
      title: quiz.title,
      grade: quiz.grade,
      subject: quiz.subject,
      term: quiz.term,
      unit: quiz.unit,
      lesson: quiz.lesson || '',
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
    // Keep a synced tombstone instead of physically removing the row. A
    // different device may still have the old quiz locally; the tombstone
    // prevents hydration from uploading that stale record again.
    const deletedQuizIds = new Set<string>(
      JSON.parse(localStorage.getItem(STORAGE_KEYS.DELETED_QUIZZES) || '[]')
        .filter((value: unknown) => typeof value === 'string')
        .map((value: string) => value),
    );
    deletedQuizIds.add(String(id));
    localStorage.setItem(
      STORAGE_KEYS.DELETED_QUIZZES,
      JSON.stringify(Array.from(deletedQuizIds)),
    );
    const updated = allSaved.filter(q => q.id !== id);
    localStorage.setItem(STORAGE_KEYS.CREATED_QUIZZES, JSON.stringify(updated));
    setCreatedQuizzes(updated.filter(q =>
      !q.deleted &&
      (!teacherId || getRecordTeacherId(q) === normalizeScopeValue(teacherId)),
    ));
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
    <div className="dashboard-page dashboard-consistent-page animate-fadeIn">
      {/* 📊 Header */}
       <div className="dashboard-section-header">
        <div className="min-w-0">
          <h1 className="text-2xl font-black text-purple-900 sm:text-3xl">🎯 إدارة الاختبارات</h1>
          <p className="text-purple-500 font-medium">إنشاء وإدارة الاختبارات للطلاب</p>
        </div>
        <button
          onClick={() => {
            setShowCreateForm(!showCreateForm);
            setEditingQuiz(null);
            resetForm();
          }}
          className="min-h-11 bg-gradient-to-r from-purple-500 to-violet-500 text-white px-5 py-3 rounded-[20px] font-black text-base hover:shadow-2xl transition-all sm:px-8 sm:py-4 sm:rounded-[25px] sm:text-lg"
        >
          {showCreateForm ? '❌ إلغاء' : '➕ إنشاء اختبار جديد'}
        </button>
      </div>

      {/* 📝 نموذج إنشاء/تعديل اختبار */}
      {showCreateForm && (
         <div className="dashboard-surface mobile-modal-panel bg-gradient-to-br from-purple-50 to-violet-50 border-purple-300 animate-fadeIn">
          <h2 className="text-2xl font-black text-purple-900 mb-8">
            {editingQuiz ? '📝 تعديل اختبار' : '✨ إنشاء اختبار جديد'}
          </h2>

          {/* اختيار نوع الإنشاء */}
          <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:gap-4">
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

          <div className="space-y-6">
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
           <div className="dashboard-filter-grid dashboard-filter-grid-wide">
              {/* الصف */}
              <select
                value={quizFormData.grade}
                onChange={e => handleGradeChange(e.target.value)}
                className="p-4 border-2 border-purple-300 rounded-2xl outline-none focus:border-purple-600 bg-white font-bold"
                required
              >
                <option value="">🎓 الصف</option>
                {availableGrades.map(g => <option key={g} value={g}>{g}</option>)}
              </select>


              {/* المادة */}
              <select
                value={quizFormData.subject}
                onChange={e => handleSubjectChange(e.target.value)}
                className="p-4 border-2 border-purple-300 rounded-2xl outline-none focus:border-purple-600 bg-white font-bold"
                disabled={!quizFormData.grade}
                required
              >
                <option value="">📖 المادة</option>
                {availableSubjects.map(s => <option key={s} value={s}>{s}</option>)}
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
                {availableTerms.map(t => <option key={t} value={t}>{t}</option>)}
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
                {availableUnits.map(u => <option key={u} value={u}>{u}</option>)}
              </select>

              {/* الدرس — المستوى السادس.
                  اختياري هنا خلافاً لإدارة المحتوى والسينما: الاختبار قد يكون
                  دورياً يغطّي الوحدة كلها لا درساً بعينه، فإلزامه يمنع حالة
                  مشروعة. ومن يختار درساً يُقيَّد الاختبار به. */}
              <select
                value={quizFormData.lesson}
                onChange={e => handleLessonChange(e.target.value)}
                className="p-4 border-2 border-purple-300 rounded-2xl outline-none focus:border-purple-600 bg-white font-bold"
                disabled={!quizFormData.unit}
              >
                <option value="">{hydrating && availableLessons.length === 0 ? '⏳ جارٍ تحميل الدروس…' : '📘 الدرس (اختياري — اتركه فارغاً لاختبار الوحدة)'}</option>
                {availableLessons.map(l => <option key={l} value={l}>{l}</option>)}
              </select>
            </div>

            {/* معلومات المحتوى */}
            {quizFormData.unit && (
              <div className="p-6 bg-white rounded-[30px] border-2 border-purple-200">
                {/* طبيعة الاختبار كما اشتُقّت من المسار، قبل المحتوى:
                    المعلم يعرف ما يصنعه وهو يصنعه، لا بعد الحفظ. */}
                <div
                  className={`mb-4 flex flex-wrap items-center gap-2 rounded-2xl border-2 p-4 font-black ${
                    quizFormData.lesson
                      ? 'border-emerald-300 bg-emerald-50 text-emerald-800'
                      : 'border-amber-300 bg-amber-50 text-amber-800'
                  }`}
                >
                  <span className="text-2xl">{quizFormData.lesson ? '🔁' : '📋'}</span>
                  <span>
                    {quizFormData.lesson
                      ? `اختبار دوري للدرس «${quizFormData.lesson}» — قابل للإعادة`
                      : `اختبار شامل لوحدة «${quizFormData.unit}» — يُؤدّى مرة واحدة`}
                  </span>
                  <span className="text-sm font-bold opacity-80">
                    {quizFormData.lesson
                      ? 'يعيده الطالب ليحسّن درجته'
                      : 'لا يُعاد بعد تسليمه'}
                  </span>
                </div>

                {lessonFound ? (
                  <div className="space-y-3">
                    <div className="flex items-center gap-2 text-green-700 font-black">
                      <span className="text-2xl">✅</span>
                      <span>
                        {mergedLessons > 1
                          ? `دُمجت نصوص ${mergedLessons} دروس من هذه الوحدة`
                          : 'تم العثور على محتوى الدرس'}
                      </span>
                      <span className="text-sm font-bold text-purple-500">
                        ({lessonContent.length.toLocaleString('ar-EG')} حرفاً)
                      </span>
                    </div>
                    <div className="bg-green-50 p-4 rounded-2xl text-sm text-purple-700">
                      {lessonContent.substring(0, 300)}...
                    </div>
                  </div>
                ) : (
                  <div className="flex items-center gap-2 text-orange-600 font-bold">
                    <span className="text-2xl">⚠️</span>
                    <span>
                      {quizFormData.lesson
                        ? 'لا يوجد نصّ مكتوب لهذا الدرس! أضفه في إدارة المحتوى أولاً'
                        : 'لا يوجد نصّ لأي درس في هذه الوحدة! أضفه في إدارة المحتوى أولاً'}
                    </span>
                  </div>
                )}
              </div>
            )}

            {/* إعدادات الاختبار */}
            <div className="grid min-w-0 grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-5">
              {/* نوع الاختبار */}
              <div>
                <label className="block font-black text-purple-900 mb-2">🎯 نوع الاختبار</label>
                {/* النوع يتبع المسار ولا يُختار: اختيار «دوري» لاختبار
                    وحدة كان يجعله قابلاً للإعادة، واختيار «اختبار المعلم»
                    لدرس يمنع إعادته — فيتناقض ما يراه المعلم في الشارة مع
                    ما يجده الطالب. مصدر واحد أصدق من حقلين يختلفان. */}
                <div className="w-full p-4 border-2 border-purple-200 rounded-2xl bg-purple-50 font-bold text-purple-800">
                  {quizFormData.lesson ? '🔁 الاختبار الدوري (للدرس)' : '📋 اختبار الوحدة الشامل'}
                  <span className="block text-xs font-bold text-purple-500 mt-1">
                    يُحدَّد تلقائياً: باختيار درس يصير دورياً، وبتركه فارغاً يصير شاملاً للوحدة.
                  </span>
                </div>
              </div>

              {/* عدد الأسئلة */}
              <div>
                <label className="block font-black text-purple-900 mb-2">📊 عدد الأسئلة لكل طالب</label>
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
                    <li>✅ بنك أكبر مع مجموعة مختلفة وثابتة لكل طالب</li>
                    <li>✅ تغطية شاملة لمحتوى الدرس</li>
                    <li>✅ صياغة احترافية بدون أخطاء</li>
                  </ul>
                </div>
              </div>
            </div>

            {/* زر التوليد الذكي أو واجهة الأسئلة اليدوية */}
            {creationMode === 'ai' ? (
              <button
                type="button"
                onClick={generateSmartQuiz}
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
       <div className="dashboard-surface dashboard-content-records space-y-4">
                {/* عرض الأسئلة اليدوية */}
                {manualQuestions.length > 0 && (
                  <div className="bg-white p-6 rounded-[25px] border-2 border-green-300">
                    <h3 className="font-black text-green-900 text-lg mb-4">
                      📝 الأسئلة المضافة ({manualQuestions.length})
                    </h3>
                    <div className="space-y-3">
                      {manualQuestions.map((q, idx) => (
                        <div key={q.id} className="bg-purple-50 p-4 rounded-2xl border-2 border-purple-200 flex justify-between items-start">
                          <div className="flex-1">
                            <p className="font-bold text-purple-800 mb-2">{idx + 1}. {q.question}</p>
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm">
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
                    type="button"
                    onClick={saveManualQuiz}
                    className="w-full py-6 rounded-[30px] font-black text-2xl bg-gradient-to-r from-green-600 to-emerald-600 text-white hover:shadow-2xl shadow-green-300 transition-all"
                  >
                    💾 حفظ الاختبار ({manualQuestions.length} سؤال)
                  </button>
                )}
              </div>
            )}
          </div>
        </div>
      )}

      {/* 📋 قائمة الاختبارات المنشأة */}
      <div className="space-y-4">
        <h2 className="text-2xl font-black text-purple-900">
          📚 الاختبارات المنشأة ({visibleQuizzes.length}
          {listFiltersActive ? ` من ${createdQuizzes.length}` : ''})
        </h2>

        {/* 🔎 شريط الفلاتر — يظهر فقط حين يوجد ما يُفلتَر. */}
        {createdQuizzes.length > 0 && (
          <div className="dashboard-filter-surface">
            <div className="dashboard-filter-grid dashboard-filter-grid-wide">
              <input
                type="search"
                value={listSearch}
                onChange={e => setListSearch(e.target.value)}
                placeholder="🔎 ابحث بالاسم أو الوحدة أو الدرس"
                className="dashboard-form-control rounded-xl border-2 border-slate-200 px-4 font-bold outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
              />
              <select
                value={listSubject}
                onChange={e => setListSubject(e.target.value)}
                className="dashboard-form-control rounded-xl border-2 border-slate-200 px-4 font-bold outline-none focus:border-blue-500"
              >
                <option value="all">📖 كل المواد</option>
                {listFilterOptions.subjects.map(v => <option key={v} value={v}>{v}</option>)}
              </select>
              <select
                value={listGrade}
                onChange={e => setListGrade(e.target.value)}
                className="dashboard-form-control rounded-xl border-2 border-slate-200 px-4 font-bold outline-none focus:border-blue-500"
              >
                <option value="all">🎓 كل الصفوف</option>
                {listFilterOptions.grades.map(v => <option key={v} value={v}>{v}</option>)}
              </select>
              <select
                value={listTerm}
                onChange={e => setListTerm(e.target.value)}
                className="dashboard-form-control rounded-xl border-2 border-slate-200 px-4 font-bold outline-none focus:border-blue-500"
              >
                <option value="all">📅 كل الفصول الدراسية</option>
                {listFilterOptions.terms.map(v => <option key={v} value={v}>{v}</option>)}
              </select>
              <select
                value={listStatus}
                onChange={e => setListStatus(e.target.value as 'all' | 'active' | 'locked')}
                className="dashboard-form-control rounded-xl border-2 border-slate-200 px-4 font-bold outline-none focus:border-blue-500"
              >
                <option value="all">🔁 كل الحالات</option>
                <option value="active">✅ نشط</option>
                <option value="locked">🔒 مقفل</option>
              </select>
            </div>
            {listFiltersActive && (
              <button
                type="button"
                onClick={() => {
                  setListSearch(''); setListSubject('all'); setListGrade('all');
                  setListTerm('all'); setListStatus('all');
                }}
                className="mt-3 rounded-xl bg-slate-100 px-5 py-2.5 text-sm font-bold text-slate-700 hover:bg-slate-200"
              >
                مسح الفلاتر
              </button>
            )}
          </div>
        )}

        {createdQuizzes.length === 0 ? (
          <div className="p-32 text-center bg-white rounded-[40px] border-2 border-dashed border-purple-200">
            <div className="text-6xl mb-4">📝</div>
            <h3 className="text-2xl font-black text-purple-300 mb-2">لا توجد اختبارات حتى الآن</h3>
            <p className="text-purple-400">ابدأ بإنشاء اختبار جديد</p>
          </div>
        ) : (
          visibleQuizzes.length === 0 ? (
           <div className="dashboard-record-card text-center font-bold italic text-slate-400">
             لا توجد اختبارات مطابقة للفلاتر المحددة
           </div>
         ) : (
           <div className="dashboard-record-grid">
            {visibleQuizzes.map(quiz => (
               <article key={quiz.id} className="dashboard-record-card">
                {/* ===== الترويسة: العنوان والحالة في جهة، الإجراءات في جهة =====
                    كان الاثنان في صفّ `justify-between` واحد مع عمود الأزرار،
                    فيُعصر عمود المعلومات كلما ضاقت البطاقة. فصلهما إلى صفّين
                    يعطي العنوان العرض كاملاً ويُبعد الأزرار عن حافة البطاقة. */}
                <header className="dashboard-record-head">
                  <div className="min-w-0 flex-1">
                    <h3 className="dashboard-record-title">{quiz.title}</h3>
                    <span className={`dashboard-record-status ${
                      quiz.isActive
                        ? 'dashboard-record-status-on'
                        : 'dashboard-record-status-off'
                    }`}>
                      {quiz.isActive ? '✅ مفعّل' : '❌ غير مفعّل'}
                    </span>
                  </div>

                  <div className="dashboard-record-actions">
                    <button
                      onClick={() => toggleActive(quiz.id)}
                      className={`dashboard-icon-button ${
                        quiz.isActive
                          ? 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                          : 'bg-emerald-50 text-emerald-700 hover:bg-emerald-100'
                      }`}
                      title={quiz.isActive ? 'تعطيل' : 'تفعيل'}
                      aria-label={quiz.isActive ? 'تعطيل الاختبار' : 'تفعيل الاختبار'}
                    >
                      {quiz.isActive ? '🔴' : '🟢'}
                    </button>
                    <button
                      onClick={() => handleEdit(quiz)}
                      className="dashboard-icon-button bg-blue-50 text-blue-700 hover:bg-blue-100"
                      title="تعديل"
                      aria-label="تعديل الاختبار"
                    >
                      ✏️
                    </button>
                    <button
                      onClick={() => handleDelete(quiz.id)}
                      className="dashboard-icon-button bg-red-50 text-red-700 hover:bg-red-100"
                      title="حذف"
                      aria-label="حذف الاختبار"
                    >
                      🗑️
                    </button>
                  </div>
                </header>

                {/* ===== شارات الهيكل الأكاديمي الستة ===== */}
                <div className="dashboard-record-badges">
                  <span className="dashboard-badge">{quiz.grade}</span>
                  <span className="dashboard-badge">{quiz.subject}</span>
                  <span className="dashboard-badge">{quiz.term}</span>
                  <span className="dashboard-badge">{quiz.unit}</span>
                  {/* الدرس: يظهر صريحاً حين يكون الاختبار مقيّداً بدرس، وإلا
                      يُعلَن أنه يغطي الوحدة كاملة — فلا يبقى المستوى السادس
                      غامضاً على من يقرأ البطاقة. */}
                  <span className="dashboard-badge">
                    {quiz.lesson ? `📘 ${quiz.lesson}` : '📘 كل دروس الوحدة'}
                  </span>
                  <span className="dashboard-badge dashboard-badge-accent">
                    {normalizeQuizType(quiz.quizType) === QuizType.PERIODIC
                      ? getPeriodicQuizLabel(quiz)
                      : getQuizTypeLabel(quiz.quizType)}
                  </span>
                </div>

                {/* ===== التفاصيل =====
                    كان هذا صفّاً `flex gap-6` بلا `flex-wrap` إطلاقاً، فالعناصر
                    الثلاثة تُحشر في سطر واحد داخل عمود عرضه ~300 بكسل فتتداخل
                    فوق بعضها. صار شبكة تلتف من تلقائها. */}
                <dl className="dashboard-record-meta">
                  <div>
                    <dt>📊 الأسئلة</dt>
                    <dd>{quiz.questions.length}</dd>
                  </div>
                  <div>
                    <dt>📅 الإنشاء</dt>
                    <dd>{new Date(quiz.createdAt).toLocaleDateString('ar-SA')}</dd>
                  </div>
                  {quiz.lastModified && (
                    <div>
                      <dt>🔄 آخر تعديل</dt>
                      <dd>{new Date(quiz.lastModified).toLocaleDateString('ar-SA')}</dd>
                    </div>
                  )}
                  {quiz.createdByName && (
                    <div>
                      <dt>👨‍🏫 المعلم</dt>
                      <dd>{quiz.createdByName}</dd>
                    </div>
                  )}
                </dl>

                {/* ===== الأسفل: عرض الأسئلة ===== */}
                {quiz.questions.length > 0 && (
                  <details className="dashboard-record-footer">
                    <summary className="dashboard-record-reveal">
                      👁️ عرض الأسئلة ({quiz.questions.length})
                    </summary>
                    <div className="mt-4 space-y-3">
                      {quiz.questions.map((q, idx) => (
                        <div key={idx} className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
                          <p className="mb-2 font-bold text-slate-800">{idx + 1}. {q.question}</p>
                          <div className="grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
                            {q.options.map((opt, i) => (
                              <div
                                key={i}
                                className={`rounded-lg p-2 ${
                                  opt === q.correctAnswer
                                    ? 'bg-emerald-100 font-bold text-emerald-800'
                                    : 'bg-white text-slate-600'
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
              </article>
            ))}
          </div>
         )
        )}
      </div>
    </div>
  );
};

export default QuizManagement;