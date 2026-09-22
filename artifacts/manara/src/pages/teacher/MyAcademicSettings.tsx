import AcademicSaveBar from '../../components/AcademicSaveBar';
import React, { useState, useEffect } from 'react';
import { markLessonsDeletedUnder, renameLessonsPath } from '../../utils/lessonCascade';
import { STORAGE_KEYS, COLORS } from '../../constants';
import AcademicTreeViewer, { GradeNode, SubjectNode, TermNode, UnitNode, LessonNode }
  from '../../components/AcademicTreeViewer';
import { HierarchicalConfig, TeacherInfo, TeacherPermissions } from '../../types';
import { getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import { getTeacherPermissionDetails } from '../../permissions';
import { dedupeHierarchicalConfigs } from '../../utils/academic';
import { useSyncHydrating } from '../../hooks/useSyncHydrating';
import { readActiveSession } from '../../utils/storage';
import ConfirmDialog, { ConfirmRequest } from '../../components/ConfirmDialog';

interface MyAcademicSettingsProps {
  teacher?: TeacherInfo | null;
}

const MyAcademicSettings: React.FC<MyAcademicSettingsProps> = ({ teacher: teacherProp }) => {
  const [teacherId, setTeacherId] = useState('');
  const [teacherName, setTeacherName] = useState('');
  // اسم المستخدم لإعادة فتح جلسة الحفظ عند انتهائها، بلا تسجيل خروج.
  const [teacherUsername, setTeacherUsername] = useState('');
  const [activeTab, setActiveTab] = useState<'my' | 'general'>('my');
  
  // My Settings States
  const [myConfigs, setMyConfigs] = useState<HierarchicalConfig[]>([]);
  const [myGrades, setMyGrades] = useState<string[]>([]);
  
  // General Settings States
  const [generalConfigs, setGeneralConfigs] = useState<HierarchicalConfig[]>([]);
  
  // Form States for My Settings
  const [selectedGrade, setSelectedGrade] = useState('');
  const [newGrade, setNewGrade] = useState('');
  const [selectedSubject, setSelectedSubject] = useState('');
  const [newSubject, setNewSubject] = useState('');
  const [selectedTerm, setSelectedTerm] = useState('');
  const [newTerm, setNewTerm] = useState('');
  const [newUnit, setNewUnit] = useState('');
  const [selectedUnit, setSelectedUnit] = useState('');
  const [newLesson, setNewLesson] = useState('');

  // ── تصفية الشجرة المعروضة ──
  //
  // صف واحد بمواده وفصوله ووحداته ودروسه يملأ الشاشة. هذه تضيّق
  // المعروض وحده، ولا تمسّ البيانات: التعديل والحذف يُخاطبان الشجرة
  // بالأسماء كما كانا.
  const [filterGrade, setFilterGrade] = useState('');
  const [filterSubject, setFilterSubject] = useState('');
  const [treeSearch, setTreeSearch] = useState('');
  const [collapsedGrades, setCollapsedGrades] = useState<Record<string, boolean>>({});

  // ما يُسأل عنه قبل الحذف. window.confirm كان يُحجب صامتاً داخل الإطار
  // ويُرجع false، فيبدو زر الحذف معطّلاً بلا سبب ظاهر.
  const [confirmRequest, setConfirmRequest] = useState<ConfirmRequest | null>(null);

  const hydrating = useSyncHydrating();

  // إعادة القراءة حين ينتهي التحميل الأوّل من الخادم.
  //
  // هذه الشاشة تقرأ الشجرة من التخزين المحليّ قراءةً متزامنةً مرّةً عند
  // الفتح. والتحميل من الخادم غير متزامن، ويسبقه محوُ النسخة القديمة
  // عند اختلاف ختم المحتوى. فمن فتحها في تلك الثواني قرأ فراغاً وبقي عليه:
  // شجرةٌ كاملة في قاعدة البيانات، وصفرٌ على الشاشة، حتى يُغادرها ويعود.
  // الراية في قائمة التبعيّات تجعل القراءة تُعاد مرّةً واحدة حين تصل البيانات.
  useEffect(() => {
    const teacher = teacherProp || readActiveSession<TeacherInfo>(STORAGE_KEYS.CURRENT_TEACHER);
    setTeacherId(teacher?.id || '');
    setTeacherName(teacher?.name || '');
    setTeacherUsername(teacher?.username || '');
    loadSettings(teacher?.id || '');
  }, [teacherProp?.id, teacherProp?.name, teacherProp?.permissionPackageId, hydrating]);

  const resolvedTeacher: TeacherInfo | null = (() => {
    const fallback = teacherProp || readActiveSession<TeacherInfo>(STORAGE_KEYS.CURRENT_TEACHER);
    if (!fallback?.id) return fallback;
    try {
      const teachers: TeacherInfo[] = JSON.parse(
        localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]',
      );
      return teachers.find(item => item.id === fallback.id) || fallback;
    } catch {
      return fallback;
    }
  })();
  const permissionDetails = getTeacherPermissionDetails(resolvedTeacher);
  const effectiveTeacherPermissions = permissionDetails.effective as TeacherPermissions;
  const canManageAcademicSettings = effectiveTeacherPermissions.canManageAcademicSettings;

  if (!canManageAcademicSettings) {
    const denialReason = !permissionDetails.global.canManageAcademicSettings
      ? 'سياسة المشرف العامة لا تسمح بهذه الصلاحية حاليًا.'
      : !permissionDetails.permissionPackage
        ? 'لا يوجد إعداد إدارة صلاحيات للمعلم مرتبط بهذا الحساب، أو أن الإعداد لم يعد موجودًا.'
        : (permissionDetails.permissionPackage.permissions as TeacherPermissions).canManageAcademicSettings === false
          ? `إعداد الصلاحيات المرتبط «${permissionDetails.permissionPackage.name}» لا يتضمن هذه الصلاحية.`
          : 'تم تعديل الصلاحيات مؤخرًا؛ سجّل الخروج ثم ادخل مرة أخرى لتحديث الحساب.';
    return (
      <div className="flex min-h-[60vh] flex-col items-center justify-center text-center">
        <div className="text-7xl opacity-50">🔒</div>
        <h2 className="mt-5 text-3xl font-black text-slate-800">لا توجد صلاحية</h2>
        <p className="mt-3 max-w-xl font-bold leading-8 text-slate-500">
          لا يملك هذا المعلم صلاحية إدارة الإعدادات الأكاديمية.
          <br />
          {denialReason}
        </p>
      </div>
    );
  }

  function loadSettings(tId: string) {
    if (!tId) return;
    
    const rawConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const allConfigs = dedupeHierarchicalConfigs(rawConfigs);
    if (JSON.stringify(allConfigs) !== JSON.stringify(rawConfigs)) {
      localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
    }
    
    // My Settings: فقط إعدادات المعلم الخاصة
    const mySettings = allConfigs.filter((c: HierarchicalConfig) =>
      getRecordTeacherId(c) === normalizeScopeValue(tId)
    );
    setMyConfigs(mySettings);
    const gradeNames = Array.from(new Map(
      mySettings.map((c: HierarchicalConfig) => [normalizeScopeValue(c.grade), c.grade]),
    ).values());
    setMyGrades(gradeNames);
    // والقائمة المسطّحة كذلك: شاشة المشرف تكتبها منذ البداية، وما كان
    // يكتبها أحد حين يبني المعلم شجرته هنا — فتبقى فارغة لكل شاشة قديمة
    // ما زالت تقرأها.
    const flat = JSON.parse(localStorage.getItem(STORAGE_KEYS.GRADES) || '[]');
    const merged = Array.from(new Map(
      [...(Array.isArray(flat) ? flat : []), ...gradeNames]
        .filter(Boolean)
        .map((grade: string) => [normalizeScopeValue(grade), grade]),
    ).values());
    if (JSON.stringify(merged) !== JSON.stringify(flat)) {
      localStorage.setItem(STORAGE_KEYS.GRADES, JSON.stringify(merged));
    }
    
    // «الإعدادات العامة» = ما يملكه المشرف. لا أكثر.
    //
    // كان الشرط يقبل أيضاً كل إعداد بلا `createdBy`. والمالك يُقرأ من
    // `teacher_id ?? teacherId ?? createdBy`، فسجلٌّ قديم مالكه اسمٌ
    // مكتوب — اسم المعلم قبل أن يُغيَّر — يمرّ من تلك الفتحة ويظهر للمعلم
    // في تبويب «العامة» كأنه من المشرف. وهو إعداده هو باسمه القديم.
    //
    // وكان يقبل إعدادات هذا المعلم الموسومة `createdByAdmin`، وهي تظهر
    // في تبويبه الخاص أصلاً لأنه مالكها — فتُعرض مرتين.
    const generalSettings = allConfigs.filter((c: HierarchicalConfig) => {
      const owner = getRecordTeacherId(c);
      return owner === 'admin' || owner === 'supervisor';
    });
    setGeneralConfigs(generalSettings);
  }

  // ========== MY SETTINGS FUNCTIONS ==========
  
  const handleAddGrade = () => {
    if (!newGrade.trim() || !teacherId) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    
    // التحقق من عدم التكرار
    if (myConfigs.some(c =>
      normalizeScopeValue(c.grade) === normalizeScopeValue(newGrade),
    )) {
      alert('هذا الصف موجود بالفعل!');
      return;
    }
    
    const newConfig: HierarchicalConfig = {
      grade: newGrade.trim(),
      subjects: [],
      createdBy: teacherId,
      createdByName: teacherName,
      createdAt: new Date().toISOString()
    };
    
    allConfigs.push(newConfig);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
    
    setNewGrade('');
    loadSettings(teacherId);
    alert('✅ تم إضافة الصف بنجاح');
  };

  const handleAddSubject = () => {
    if (!newSubject.trim() || !selectedGrade || !teacherId) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) => 
      c.grade === selectedGrade && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (!config) {
      alert('لم يتم العثور على الصف!');
      return;
    }
    
    
    if (!config.subjects) config.subjects = [];
    
    if (config.subjects.some((s: any) => s.subject === newSubject.trim())) {
      alert('هذه المادة موجودة بالفعل!');
      return;
    }
    
    config.subjects.push({
      subject: newSubject.trim(),
      terms: []
    });
    
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
    
    setNewSubject('');
    loadSettings(teacherId);
    alert('✅ تم إضافة المادة بنجاح');
  };

  const handleAddTerm = () => {
    if (!newTerm.trim() || !selectedGrade || !selectedSubject || !teacherId) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) => 
      c.grade === selectedGrade && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (!config) return;
    
    
    const subject = config.subjects?.find((s: any) => s.subject === selectedSubject);
    if (!subject) return;
    
    if (!subject.terms) subject.terms = [];
    
    if (subject.terms.some((t: any) => t.term === newTerm.trim())) {
      alert('هذا الفصل موجود بالفعل!');
      return;
    }
    
    subject.terms.push({
      term: newTerm.trim(),
      units: []
    });
    
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
    
    setNewTerm('');
    loadSettings(teacherId);
    alert('✅ تم إضافة الفصل بنجاح');
  };

  const handleAddUnit = () => {
    if (!newUnit.trim() || !selectedGrade || !selectedSubject || !selectedTerm || !teacherId) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) => 
      c.grade === selectedGrade && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (!config) return;
    
    
    const subject = config.subjects?.find((s: any) => s.subject === selectedSubject);
    if (!subject) return;
    
    const term = subject.terms?.find((t: any) => t.term === selectedTerm);
    if (!term) return;
    
    if (!term.units) term.units = [];
    
    if (term.units.includes(newUnit.trim())) {
      alert('هذه الوحدة موجودة بالفعل!');
      return;
    }
    
    term.units.push(newUnit.trim());
    
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
    
    setNewUnit('');
    loadSettings(teacherId);
    alert('✅ تم إضافة الوحدة بنجاح');
  };

  // ========== DELETE FUNCTIONS ==========
  
  const handleDeleteGrade = (gradeName: string) => {
    setConfirmRequest({
      title: 'حذف الصف',
      message: `سيُحذف «${gradeName}» وكل ما تحته من أترام ومواد وفصول ووحدات ودروس. لا يمكن التراجع عن هذا.`,
      onConfirm: () => performDeleteGrade(gradeName),
    });
  };

  const performDeleteGrade = (gradeName: string) => {
    // ودروسه معه: درس بلا عقدة في الشجرة لا يراه طالب ولا يظهر هنا.
    markLessonsDeletedUnder({ grade: gradeName });
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const updatedConfigs = allConfigs.filter((c: HierarchicalConfig) => 
      !(c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId))
    );
    
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    loadSettings(teacherId);
    alert('✅ تم حذف الصف بنجاح');
  };

  const handleDeleteSubject = (gradeName: string, subjectName: string) => {
    setConfirmRequest({
      title: 'حذف المادة',
      message: `ستُحذف «${subjectName}» وكل ما تحتها من فصول ووحدات ودروس. لا يمكن التراجع عن هذا.`,
      onConfirm: () => performDeleteSubject(gradeName, subjectName),
    });
  };

  const performDeleteSubject = (gradeName: string, subjectName: string) => {
    markLessonsDeletedUnder({ grade: gradeName, subject: subjectName });
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) =>
      c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (config && config.subjects) {
      {
        config.subjects = config.subjects.filter((s: any) => s.subject !== subjectName);
        localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
        loadSettings(teacherId);
        alert('✅ تم حذف المادة بنجاح');
      }
    }
  };

  const handleDeleteTerm = (gradeName: string, subjectName: string, termName: string) => {
    setConfirmRequest({
      title: 'حذف الفصل',
      message: `سيُحذف «${termName}» وكل وحداته ودروسها. لا يمكن التراجع عن هذا.`,
      onConfirm: () => performDeleteTerm(gradeName, subjectName, termName),
    });
  };

  const performDeleteTerm = (gradeName: string, subjectName: string, termName: string) => {
    markLessonsDeletedUnder({ grade: gradeName, subject: subjectName, term: termName });
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) =>
      c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (config && config.subjects) {
      {
        const subject = config.subjects.find((s: any) => s.subject === subjectName);
        if (subject && subject.terms) {
          subject.terms = subject.terms.filter((t: any) => t.term !== termName);
          localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
          loadSettings(teacherId);
          alert('✅ تم حذف الفصل بنجاح');
        }
      }
    }
  };

  const handleDeleteUnit = (gradeName: string, subjectName: string, termName: string, unitName: string) => {
    setConfirmRequest({
      title: 'حذف الوحدة',
      message: `ستُحذف «${unitName}» وكل دروسها. لا يمكن التراجع عن هذا.`,
      onConfirm: () => performDeleteUnit(gradeName, subjectName, termName, unitName),
    });
  };

  const performDeleteUnit = (gradeName: string, subjectName: string, termName: string, unitName: string) => {
    markLessonsDeletedUnder({
      grade: gradeName,
      subject: subjectName,
      term: termName,
      unit: unitName,
    });
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) =>
      c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (config && config.subjects) {
      {
        const subject = config.subjects.find((s: any) => s.subject === subjectName);
        if (subject && subject.terms) {
          const term = subject.terms.find((t: any) => t.term === termName);
          if (term && term.units) {
            term.units = term.units.filter((u: string) => u !== unitName);
            // خريطة الدروس مفتاحها اسم الوحدة، فحذف الوحدة وحدها كان يترك
            // دروسها معلّقة في الإعداد بلا واجهة تعرضها.
            if (term.lessons && unitName in term.lessons) {
              const { [unitName]: _removed, ...rest } = term.lessons;
              term.lessons = rest;
            }
            localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
            loadSettings(teacherId);
            alert('✅ تم حذف الوحدة بنجاح');
          }
        }
      }
    }
  };

  // ========== EDIT FUNCTIONS ==========
  //
  // كل مستويات الشجرة تُحرَّر داخل الصفحة: الاسم يتحول إلى مربع إدخال مع
  // زرَّي حفظ وإلغاء. النوافذ القديمة (window.prompt) لم تكن عنصراً مرئياً
  // في الصفحة، وتُحجب صامتة داخل إطار iframe فتبدو الضغطة بلا أثر.
  //
  // الكتابة إلى localStorage هي نفسها المزامنة: مفتاح
  // `smartEdu_hierarchicalConfigs` من مفاتيح المزامنة، فاعتراض الكتابة في
  // db/sync يرسل التغيير إلى Supabase فور حدوثه.

  /** يحفظ الاسم المكتوب في محرّر السطر المفتوح على العقدة المحددة. */
  const saveNodeEdit = (
    kind: 'grade' | 'subject' | 'term' | 'unit',
    newName: string,
    gradeName: string,
    subjectName = '',
    termName = '',
    unitName = '',
  ) => {
    if (!newName) return;

    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) =>
      c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    if (!config) return;

    const subject = subjectName ? config?.subjects?.find((s: any) => s.subject === subjectName) : null;
    const term = termName ? subject?.terms?.find((t: any) => t.term === termName) : null;

    // الدروس تحمل مسارها نصّاً، فإعادة التسمية تنتقل إليها أيضاً — وإلا
    // بقيت معلقة على الاسم القديم فلا يراها الطالب ولا تظهر في الإعدادات.
    switch (kind) {
      case 'grade':
        if (config.grade === newName) return;
        renameLessonsPath({ grade: config.grade }, 'grade', newName);
        config.grade = newName;
        break;
      case 'subject':
        if (!subject || subject.subject === newName) return;
        renameLessonsPath(
          { grade: config.grade, subject: subject.subject },
          'subject',
          newName,
        );
        subject.subject = newName;
        break;
      case 'term':
        if (!term || term.term === newName) return;
        renameLessonsPath(
          { grade: config.grade, subject: subjectName, term: term.term },
          'term',
          newName,
        );
        term.term = newName;
        break;
      case 'unit': {
        if (!term?.units) return;
        const unitIndex = term.units.indexOf(unitName);
        if (unitIndex === -1 || unitName === newName) return;
        renameLessonsPath(
          { grade: config.grade, subject: subjectName, term: termName, unit: unitName },
          'unit',
          newName,
        );
        term.units[unitIndex] = newName;
        // الدروس مفهرسة باسم الوحدة، فلا بد أن تتبعها عند إعادة التسمية.
        if (term.lessons && unitName in term.lessons) {
          const { [unitName]: moved, ...rest } = term.lessons;
          term.lessons = { ...rest, [newName]: moved };
        }
        break;
      }
    }

    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
    loadSettings(teacherId);
  };


  // ========== الدروس داخل الوحدة ==========
  // آخر مستوى في التسلسل الأكاديمي:
  // الصف ← الترم ← المادة ← الفصل ← الوحدة ← الدرس.
  //
  // الدروس مخزّنة في خريطة `term.lessons` مفتاحها اسم الوحدة، لا داخل
  // `units` نفسها — وهو الشكل الذي تستخدمه لوحة المشرف بالفعل، فتقرأ
  // الواجهتان وتطبيق الطالب البنية ذاتها. الحقل اختياري، فالإعدادات التي
  // أُنشئت قبل وجوده تبقى صالحة كما هي بلا ترحيل.
  //
  // الكتابة إلى localStorage هي نفسها المزامنة: مفتاح
  // `smartEdu_hierarchicalConfigs` من مفاتيح المزامنة، فاعتراض الكتابة في
  // db/sync يرسله إلى Supabase تلقائياً، ولا يحتاج هذا الملف إلى استدعاء
  // خاص به.

  const lessonsOf = (
    term: { units?: string[]; lessons?: Record<string, string[]> },
    unit: string,
  ): string[] => term.lessons?.[unit] ?? [];

  /** يحدّد الفصل داخل إعداد هذا المعلم، أو null إذا لم يُعثر عليه. */
  const findTerm = (
    allConfigs: any[],
    gradeName: string,
    subjectName: string,
    termName: string,
  ): any | null => {
    const config = allConfigs.find(
      (c: HierarchicalConfig) =>
        c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId),
    );
    const subject = config?.subjects?.find((s: any) => s.subject === subjectName);
    return subject?.terms?.find((t: any) => t.term === termName) ?? null;
  };

  const writeLessons = (
    gradeName: string,
    subjectName: string,
    termName: string,
    unit: string,
    next: string[],
  ) => {
    const allConfigs = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]',
    );
    const term = findTerm(allConfigs, gradeName, subjectName, termName);
    if (!term) return;
    const lessons = { ...(term.lessons ?? {}) };
    if (next.length === 0) {
      delete lessons[unit];
    } else {
      lessons[unit] = next;
    }
    term.lessons = lessons;
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
    loadSettings(teacherId);
  };

  /// يضيف الدرس المكتوب في حقل هذه الوحدة.
  /// الخطوة السادسة في عمود الإنشاء: تكتب اسم الدرس في الحقل هناك بعد
  /// اختيار الوحدة، بدل الحقل السريع داخل بطاقة الوحدة.
  const handleAddLessonFromForm = () => {
    const name = newLesson.trim();
    if (!name || !selectedGrade || !selectedSubject ||
        !selectedTerm || !selectedUnit) {
      return;
    }
    const allConfigs = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]',
    );
    const term = findTerm(
      allConfigs, selectedGrade, selectedSubject, selectedTerm,
    );
    if (!term) return;
    const current = lessonsOf(term, selectedUnit);
    if (current.some(lesson => lesson === name)) {
      alert('هذا الدرس موجود مسبقاً في هذه الوحدة');
      return;
    }
    writeLessons(
      selectedGrade, selectedSubject, selectedTerm, selectedUnit,
      [...current, name],
    );
    setNewLesson('');
    alert('✅ تم إضافة الدرس بنجاح');
  };

  /// يحفظ التعديل المكتوب في حقل التحرير الظاهر مكان الدرس.
  const handleSaveLessonEdit = (
    gradeName: string,
    subjectName: string,
    termName: string,
    unit: string,
    lessonIndex: number,
    newLesson: string,
  ) => {
    if (!newLesson) return;
    const allConfigs = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]',
    );
    const term = findTerm(allConfigs, gradeName, subjectName, termName);
    if (!term) return;
    const current = lessonsOf(term, unit);
    if (current[lessonIndex] === newLesson) return;
    if (current.some((lesson, index) => index !== lessonIndex && lesson === newLesson)) {
      alert('هذا الدرس موجود مسبقاً في هذه الوحدة');
      return;
    }
    const next = [...current];
    next[lessonIndex] = newLesson;
    writeLessons(gradeName, subjectName, termName, unit, next);
  };

  const handleDeleteLesson = (
    gradeName: string,
    subjectName: string,
    termName: string,
    unit: string,
    lessonIndex: number,
  ) => {
    const allConfigs = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]',
    );
    const term = findTerm(allConfigs, gradeName, subjectName, termName);
    if (!term) return;
    const current = lessonsOf(term, unit);
    setConfirmRequest({
      title: 'حذف الدرس',
      message: `سيُحذف الدرس «${current[lessonIndex]}» من وحدة «${unit}».`,
      onConfirm: () =>
        writeLessons(
          gradeName,
          subjectName,
          termName,
          unit,
          current.filter((_, index) => index !== lessonIndex),
        ),
    });
  };

  // ========== GENERAL SETTINGS FUNCTIONS ==========
  
  const handleCopyToMy = (config: HierarchicalConfig) => {
    if (!teacherId) return;
    
    // التحقق إذا كان المعلم لديه بالفعل صف بنفس الاسم
    if (myConfigs.some(c => c.grade === config.grade)) {
      alert('⚠️ لديك بالفعل صف بهذا الاسم في إعداداتك الخاصة!');
      return;
    }
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    
    // نسخ الإعداد
    const copiedConfig: HierarchicalConfig = {
      ...JSON.parse(JSON.stringify(config)), // Deep copy
      createdBy: teacherId,
      createdByName: teacherName,
      createdAt: new Date().toISOString(),
      copiedFrom: config.createdBy,
      copiedFromName: config.createdByName
    };
    
    allConfigs.push(copiedConfig);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
    
    loadSettings(teacherId);
    alert('✅ تم نسخ الإعداد إلى إعداداتك الخاصة! يمكنك الآن التعديل عليه');
    setActiveTab('my');
  };

  // Helper functions for displaying hierarchy
  const getSubjectsForGrade = () => {
    const config = myConfigs.find(c => c.grade === selectedGrade);
    return config?.subjects || [];
  };

  const getTermsForSubject = () => {
    const config = myConfigs.find(c => c.grade === selectedGrade);
    const subject = config?.subjects?.find(s => s.subject === selectedSubject);
    return subject?.terms || [];
  };

  const getUnitsForTerm = () => {
    const config = myConfigs.find(c => c.grade === selectedGrade);
    const subject = config?.subjects?.find(s => s.subject === selectedSubject);
    const term = subject?.terms?.find(t => t.term === selectedTerm);
    return term?.units || [];
  };

  // ============ تصفية الشجرة ============

  const matchesFilter = (value: unknown, selected: string) =>
    !selected || normalizeScopeValue(value) === normalizeScopeValue(selected);

  /// كل نصّ داخل الصف: اسمه، ومواده، وفصولها، ووحداتها، ودروسها.
  const searchHaystack = (config: HierarchicalConfig): string => {
    const parts: string[] = [config.grade];
    (config.subjects || []).forEach(subject => {
      parts.push(subject.subject);
      (subject.terms || []).forEach(term => {
        parts.push(term.term);
        (term.units || []).forEach(unit => parts.push(unit));
        Object.values(term.lessons || {}).forEach(names =>
          (names || []).forEach(name => parts.push(name)),
        );
      });
    });
    return parts.map(part => normalizeScopeValue(part)).join(' ');
  };

  const subjectEntries = (config: HierarchicalConfig) =>
    (config.subjects || []).filter(subject => matchesFilter(subject.subject, filterSubject));

  const gradeShown = (config: HierarchicalConfig) => {
    if (!matchesFilter(config.grade, filterGrade)) return false;
    if (filterSubject && subjectEntries(config).length === 0) return false;
    const query = normalizeScopeValue(treeSearch);
    return !query || searchHaystack(config).includes(query);
  };

  const filterSubjectOptions = Array.from(
    new Map(
      myConfigs
        .filter(config => matchesFilter(config.grade, filterGrade))
        .flatMap(config => config.subjects || [])
        .map(subject => [normalizeScopeValue(subject.subject), subject.subject]),
    ).values(),
  );

  const isCollapsed = (config: HierarchicalConfig) =>
    collapsedGrades[normalizeScopeValue(config.grade)] === true;

  const toggleGrade = (config: HierarchicalConfig) =>
    setCollapsedGrades(current => {
      const key = normalizeScopeValue(config.grade);
      return { ...current, [key]: !current[key] };
    });

  const setAllCollapsed = (collapsed: boolean) =>
    setCollapsedGrades(
      collapsed
        ? Object.fromEntries(myConfigs.map(config => [normalizeScopeValue(config.grade), true]))
        : {},
    );

  return (
    <div style={styles.container} className="dashboard-page dashboard-consistent-page">
       <div className="dashboard-section-header" style={styles.header}>
        <h1 style={styles.title}>إعداداتي الأكاديمية</h1>
        <p style={styles.subtitle}>إدارة الهيكل الأكاديمي الخاص بي</p>
      </div>

      <AcademicSaveBar
        onSaved={() => loadSettings(teacherId)}
        teacherUsername={teacherUsername}
        teacherId={teacherId}
      />

      {/* Tabs */}
       <div className="dashboard-filter-surface" style={styles.tabs}>
        <button
          onClick={() => setActiveTab('my')}
          style={{
            ...styles.tab,
            ...(activeTab === 'my' ? styles.activeTab : {})
          }}
        >
          📋 اعداداتي الأكاديمية
        </button>
        <button
          onClick={() => setActiveTab('general')}
          style={{
            ...styles.tab,
            ...(activeTab === 'general' ? styles.activeTab : {})
          }}
        >
          🌐 اعدادات أكاديمية عامة
        </button>
      </div>

      {/* My Settings Tab */}
      {activeTab === 'my' && (
        <div className="dashboard-academic-editor-grid" style={{ marginTop: '25px' }}>
          {/* Form Section */}
          <div style={styles.card}>
            <h3 style={styles.cardTitle}>إنشاء الهيكل الأكاديمي</h3>
            
            {/* Add Grade */}
            <div style={styles.formGroup}>
              <label style={styles.label}>1️⃣ إضافة صف جديد</label>
              <div style={styles.inputGroup}>
                <input
                  type="text"
                  value={newGrade}
                  onChange={e => setNewGrade(e.target.value)}
                  onKeyPress={e => e.key === 'Enter' && handleAddGrade()}
                  placeholder="مثال: الصف الأول الابتدائي"
                  style={styles.input}
                />
                <button onClick={handleAddGrade} style={styles.addButton}>➕</button>
              </div>
            </div>

            {/* Add Subject */}
            <div style={styles.formGroup}>
              <label style={styles.label}>2️⃣ اختر صف وأضف مادة</label>
              <select 
                value={selectedGrade}
                onChange={e => {
                  setSelectedGrade(e.target.value);
                  setSelectedSubject('');
                  setSelectedTerm('');
                  setSelectedUnit('');
                }}
                style={{ ...styles.input, marginBottom: '8px' }}
              >
                <option value="">-- اختر الصف --</option>
                {myGrades.map((g, i) => <option key={i} value={g}>{g}</option>)}
              </select>
              <div style={styles.inputGroup}>
                <input
                  type="text"
                  value={newSubject}
                  onChange={e => setNewSubject(e.target.value)}
                  onKeyPress={e => e.key === 'Enter' && !e.currentTarget.disabled && handleAddSubject()}
                  placeholder="مثال: الرياضيات"
                  style={styles.input}
                  disabled={!selectedGrade}
                />
                <button onClick={handleAddSubject} style={styles.addButton} disabled={!selectedGrade}>➕</button>
              </div>
            </div>

            {/* Add Term */}
            <div style={styles.formGroup}>
              <label style={styles.label}>3️⃣ اختر مادة وأضف فصل</label>
              <select 
                value={selectedSubject}
                onChange={e => {
                  setSelectedSubject(e.target.value);
                  setSelectedTerm('');
                  setSelectedUnit('');
                }}
                style={{ ...styles.input, marginBottom: '8px' }}
                disabled={!selectedGrade}
              >
                <option value="">-- اختر المادة --</option>
                {getSubjectsForGrade().map((s, i) => <option key={i} value={s.subject}>{s.subject}</option>)}
              </select>
              <div style={styles.inputGroup}>
                <input
                  type="text"
                  value={newTerm}
                  onChange={e => setNewTerm(e.target.value)}
                  onKeyPress={e => e.key === 'Enter' && !e.currentTarget.disabled && handleAddTerm()}
                  placeholder="مثال: الفصل الدراسي الأول"
                  style={styles.input}
                  disabled={!selectedSubject}
                />
                <button onClick={handleAddTerm} style={styles.addButton} disabled={!selectedSubject}>➕</button>
              </div>
            </div>

            {/* Add Unit */}
            <div style={styles.formGroup}>
              <label style={styles.label}>4️⃣ اختر فصل وأضف وحدة</label>
              <select 
                value={selectedTerm}
onChange={e => {
                  setSelectedTerm(e.target.value);
                  // الوحدة تتبع فصلها: اختيار فصل آخر يجعل الوحدة
                  // المختارة تخصّ شجرة أخرى.
                  setSelectedUnit('');
                }}
                style={{ ...styles.input, marginBottom: '8px' }}
                disabled={!selectedSubject}
              >
                <option value="">-- اختر الفصل --</option>
                {getTermsForSubject().map((t, i) => <option key={i} value={t.term}>{t.term}</option>)}
              </select>
              <div style={styles.inputGroup}>
                <input
                  type="text"
                  value={newUnit}
                  onChange={e => setNewUnit(e.target.value)}
                  onKeyPress={e => e.key === 'Enter' && !e.currentTarget.disabled && handleAddUnit()}
                  placeholder="مثال: الأعداد الصحيحة"
                  style={styles.input}
                  disabled={!selectedTerm}
                />
                <button onClick={handleAddUnit} style={styles.addButton} disabled={!selectedTerm}>➕</button>
              </div>
            </div>

            {/* Add Lesson — آخر خطوة في التسلسل السداسي. الدرس يُضاف من هنا
                بنفس طريقة كل مستوى فوقه: اختر ما يحتويه، ثم اكتب الاسم.
                كان يُضاف من بطاقة الوحدة فقط، فلم يكن جزءاً من الخطوات. */}
            <div style={styles.formGroup}>
              <label style={styles.label}>5️⃣ اختر وحدة وأضف درس</label>
              <select
                value={selectedUnit}
                onChange={e => setSelectedUnit(e.target.value)}
                style={{ ...styles.input, marginBottom: '8px' }}
                disabled={!selectedTerm}
              >
                <option value="">-- اختر الوحدة --</option>
                {getUnitsForTerm().map((u, i) => <option key={i} value={u}>{u}</option>)}
              </select>
              <div style={styles.inputGroup}>
                <input
                  type="text"
                  value={newLesson}
                  onChange={e => setNewLesson(e.target.value)}
                  onKeyPress={e => e.key === 'Enter' && !e.currentTarget.disabled && handleAddLessonFromForm()}
                  placeholder="مثال: الخلية ووظائفها"
                  style={styles.input}
                  disabled={!selectedUnit}
                />
                <button onClick={handleAddLessonFromForm} style={styles.addButton} disabled={!selectedUnit}>➕</button>
              </div>
            </div>
          </div>

          {/* Display Section */}
          <div className="teacher-academic-config-list" style={styles.card}>
            <h3 style={styles.cardTitle}>إعداداتي الحالية</h3>
            
            {myConfigs.length > 0 && (
              <div style={styles.treeFilters}>
                <select
                  value={filterGrade}
                  onChange={e => { setFilterGrade(e.target.value); setFilterSubject(''); }}
                  style={styles.treeFilterControl}
                >
                  <option value="">🏫 كل الصفوف</option>
                  {Array.from(new Set(myConfigs.map(config => config.grade))).map(grade => (
                    <option key={grade} value={grade}>{grade}</option>
                  ))}
                </select>
                <select
                  value={filterSubject}
                  onChange={e => setFilterSubject(e.target.value)}
                  style={styles.treeFilterControl}
                >
                  <option value="">📚 كل المواد</option>
                  {filterSubjectOptions.map(subject => (
                    <option key={subject} value={subject}>{subject}</option>
                  ))}
                </select>
                <input
                  type="search"
                  value={treeSearch}
                  onChange={e => setTreeSearch(e.target.value)}
                  placeholder="🔍 ابحث باسم صف أو مادة أو فصل أو وحدة أو درس"
                  style={{ ...styles.treeFilterControl, flex: '2 1 200px' }}
                />
                <button onClick={() => setAllCollapsed(true)} style={styles.treeToolButton}>⊖ طيّ الكل</button>
                <button onClick={() => setAllCollapsed(false)} style={styles.treeToolButton}>⊕ فتح الكل</button>
                {(filterGrade || filterSubject || treeSearch) && (
                  <button
                    onClick={() => { setFilterGrade(''); setFilterSubject(''); setTreeSearch(''); }}
                    style={styles.treeToolButton}
                  >
                    ✖ مسح
                  </button>
                )}
              </div>
            )}

            <AcademicTreeViewer
              configs={myConfigs}
              gradeShown={config => gradeShown(config)}
              subjectEntries={config => {
                const entries = subjectEntries(config);
                return entries.map((subject: any) => ({
                  subject,
                  subjectIndex: (config.subjects || []).indexOf(subject),
                }));
              }}
              isCollapsed={config => isCollapsed(config)}
              onToggleGrade={config => toggleGrade(config)}
              gradeBadges={config =>
                config.copiedFrom ? (
                  <span style={styles.copiedBadge}>
                    📋 منسوخ من: {config.copiedFromName || 'المشرف'}
                  </span>
                ) : null
              }
              onRenameGrade={(node: GradeNode, name: string) =>
                saveNodeEdit('grade', name, node.grade)}
              onRenameSubject={(node: SubjectNode, name: string) =>
                saveNodeEdit('subject', name, node.grade, node.subject)}
              onRenameTerm={(node: TermNode, name: string) =>
                saveNodeEdit('term', name, node.grade, node.subject, node.term)}
              onRenameUnit={(node: UnitNode, name: string) =>
                saveNodeEdit('unit', name, node.grade, node.subject, node.term, node.unit)}
              onRenameLesson={(node: LessonNode, name: string) =>
                handleSaveLessonEdit(
                  node.grade, node.subject, node.term, node.unit, node.lessonIndex, name,
                )}
              onDeleteGrade={(node: GradeNode) => handleDeleteGrade(node.grade)}
              onDeleteSubject={(node: SubjectNode) =>
                handleDeleteSubject(node.grade, node.subject)}
              onDeleteTerm={(node: TermNode) =>
                handleDeleteTerm(node.grade, node.subject, node.term)}
              onDeleteUnit={(node: UnitNode) =>
                handleDeleteUnit(node.grade, node.subject, node.term, node.unit)}
              onDeleteLesson={(node: LessonNode) =>
                handleDeleteLesson(
                  node.grade, node.subject, node.term, node.unit, node.lessonIndex,
                )}
              emptyState={
                <div style={styles.emptyState}>
                  <div style={{ fontSize: '3rem', marginBottom: '10px' }}>{hydrating ? '⏳' : '📚'}</div>
                  <p>
                    {hydrating
                      ? 'جارٍ تحميل إعداداتك من الخادم…'
                      : 'لا يوجد إعدادات أكاديمية خاصة بك بعد'}
                  </p>
                  {!hydrating && (
                    <p style={{ fontSize: '0.9rem', color: '#6b7280' }}>
                      ابدأ بإنشاء هيكلك الأكاديمي أو انسخ من الإعدادات العامة
                    </p>
                  )}
                </div>
              }
              noMatchState={
                <div style={styles.emptyState}>
                  <div style={{ fontSize: '2rem', marginBottom: '8px' }}>🔍</div>
                  <p>لا يطابق هذا البحث أي صف.</p>
                </div>
              }
            />
          </div>
        </div>
      )}

      {/* General Settings Tab */}
      {activeTab === 'general' && (
        <div style={{ marginTop: '25px' }}>
          <div style={styles.card}>
            <h3 style={styles.cardTitle}>الإعدادات الأكاديمية العامة</h3>
            <p style={{ color: '#6b7280', marginBottom: '20px' }}>
              هذه الإعدادات أنشأها المشرف. يمكنك نسخها إلى إعداداتك الخاصة والتعديل عليها
            </p>
            
            {generalConfigs.length === 0 ? (
              <div style={styles.emptyState}>
                <div style={{ fontSize: '3rem', marginBottom: '10px' }}>🌐</div>
                <p>لا توجد إعدادات عامة بعد</p>
              </div>
            ) : (
              generalConfigs.map((config, idx) => (
                <div key={idx} style={{ ...styles.configCard, backgroundColor: '#f0f9ff', border: '2px solid #3b82f6' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '15px' }}>
                    <div>
                      <h4 style={styles.configTitle}>🏫 {config.grade}</h4>
                      {config.createdByName && (
                        <span style={{ backgroundColor: '#f1f5f9', color: '#92400e', padding: '2px 8px', borderRadius: '12px', fontSize: '0.75rem' }}>
                          👨‍💼 {config.createdByName}
                        </span>
                      )}
                    </div>
                    <button
                      onClick={() => handleCopyToMy(config)}
                      style={styles.copyButton}
                    >
                      📋 نسخ إلى إعداداتي
                    </button>
                  </div>
                  
                  {config.subjects && config.subjects.map((subject, sIdx) => (
                        <div key={sIdx} style={styles.subjectCard}>
                          <span>📖 {subject.subject}</span>
                          {subject.terms && subject.terms.map((term, tIdx) => (
                            <div key={tIdx} style={styles.termCard}>
                              <span>📚 {term.term}</span>
                              {term.units && term.units.length > 0 && (
                                <div style={styles.unitsContainer}>
                                  {term.units.map((unit, uIdx) => (
                                    <span key={uIdx} style={styles.unitBadge}>
                                      📄 {unit}
                                    </span>
                                  ))}
                                </div>
                              )}
                            </div>
                          ))}
                        </div>
                      ))}
                </div>
              ))
            )}
          </div>
        </div>
      )}

      <ConfirmDialog
        request={confirmRequest}
        onClose={() => setConfirmRequest(null)}
      />
    </div>
  );
};

const styles: { [key: string]: React.CSSProperties } = {
  treeFilters: { display: 'flex', flexWrap: 'wrap', gap: '8px', marginBottom: '14px', padding: '12px', backgroundColor: '#f8fafc', borderRadius: '10px', border: '1px solid #e2e8f0' },
  treeFilterControl: { flex: '1 1 150px', minWidth: '140px', padding: '9px 12px', border: '2px solid #d1d5db', borderRadius: '8px', fontSize: '0.9rem', fontFamily: 'inherit', backgroundColor: 'white' },
  treeToolButton: { padding: '8px 12px', backgroundColor: '#fef3c7', color: '#92400e', border: '1px solid #fde68a', borderRadius: '8px', cursor: 'pointer', fontSize: '0.8rem', fontWeight: 'bold', whiteSpace: 'nowrap' },
  treeToggle: { background: 'none', border: 'none', cursor: 'pointer', color: '#92400e', fontSize: '0.9rem', padding: '2px 4px', lineHeight: 1 },
  treeCountBadge: { backgroundColor: '#fff7ed', color: '#9a3412', padding: '2px 8px', borderRadius: '12px', fontSize: '0.72rem', fontWeight: 'bold' },
  container: {
    padding: '30px',
    backgroundColor: '#f9fafb',
    minHeight: '100vh',
    fontFamily: 'Arial, sans-serif'
  },
  header: {
    textAlign: 'center',
    marginBottom: '30px'
  },
  title: {
    fontSize: '2rem',
    fontWeight: 'bold',
    color: '#1f2937',
    marginBottom: '8px'
  },
  subtitle: {
    color: '#6b7280',
    fontSize: '1rem'
  },
  tabs: {
    display: 'flex',
    // بدون الالتفاف كان التبويبان صفاً واحداً لا ينكسر، فيُقتطع الثاني
    // بمقدار 105 بكسل خلف حدّ المحتوى على شاشة 375 بكسل — الزر موجود
    // ولا يمكن الوصول إليه لأن الحاوية تخفي الفائض ولا تمرّره.
    flexWrap: 'wrap',
    gap: '10px',
    marginBottom: '20px',
    borderBottom: '2px solid #e5e7eb'
  },
  tab: {
    flex: '1 1 auto',
    minWidth: 0,
    padding: '15px clamp(12px, 4vw, 30px)',
    fontSize: 'clamp(0.95rem, 3.4vw, 1.1rem)',
    fontWeight: 'bold',
    backgroundColor: 'transparent',
    border: 'none',
    borderBottom: '3px solid transparent',
    cursor: 'pointer',
    transition: 'all 0.3s'
  },
  activeTab: {
    color: '#3b82f6',
    borderBottom: '3px solid #3b82f6'
  },
  card: {
    backgroundColor: 'white',
    padding: '20px',
    borderRadius: '12px',
    border: '1px solid #e5e7eb',
    boxShadow: '0 1px 3px rgba(0,0,0,0.1)'
  },
  cardTitle: {
    fontSize: '1.2rem',
    fontWeight: 'bold',
    marginBottom: '20px',
    color: '#111827'
  },
  formGroup: {
    marginBottom: '20px',
    padding: '15px',
    backgroundColor: '#f9fafb',
    borderRadius: '8px'
  },
  label: {
    fontWeight: 'bold',
    display: 'block',
    marginBottom: '8px',
    color: '#374151'
  },
  inputGroup: {
    display: 'flex',
    gap: '8px'
  },
  input: {
    flex: 1,
    padding: '12px',
    fontSize: '1rem',
    border: '2px solid #d1d5db',
    borderRadius: '8px',
    outline: 'none',
    transition: 'border-color 0.3s'
  },
  addButton: {
    padding: '12px 20px',
    fontSize: '1.2rem',
    backgroundColor: '#3b82f6',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    transition: 'background-color 0.3s'
  },
  copyButton: {
    padding: '10px 20px',
    fontSize: '0.9rem',
    fontWeight: 'bold',
    backgroundColor: '#10b981',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    transition: 'background-color 0.3s'
  },
  emptyState: {
    textAlign: 'center',
    padding: '40px',
    color: '#9ca3af'
  },
  configCard: {
    marginBottom: '20px',
    padding: '15px',
    backgroundColor: '#f0fdf4',
    borderRadius: '10px',
    border: '2px solid #22c55e'
  },
  configTitle: {
    fontSize: '1.1rem',
    fontWeight: 'bold',
    color: '#1e40af',
    marginBottom: '10px'
  },
  copiedBadge: {
    backgroundColor: '#dbeafe',
    color: '#1e40af',
    padding: '4px 12px',
    borderRadius: '12px',
    fontSize: '0.8rem',
    display: 'inline-block',
    marginBottom: '10px'
  },
  subjectCard: {
    marginTop: '8px',
    marginRight: '15px',
    padding: '8px',
    backgroundColor: '#f1f5f9',
    borderRadius: '8px'
  },
  termCard: {
    marginTop: '6px',
    marginRight: '15px',
    padding: '6px',
    backgroundColor: '#f3e8ff',
    borderRadius: '4px'
  },
  unitsContainer: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '6px',
    marginTop: '6px'
  },
  unitBadge: {
    backgroundColor: '#e0e7ff',
    color: '#4338ca',
    padding: '2px 8px',
    borderRadius: '12px',
    fontSize: '0.75rem'
  },
  unitBadgeWithButtons: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px'
  },
  // الوحدة ودروسها ككتلة واحدة: الدروس تحت وحدتها مباشرة وبإزاحة، حتى
  // يظل واضحاً أي درس يتبع أي وحدة عندما يحمل الفصل عدة وحدات.
  unitBlock: {
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '6px',
    width: '100%'
  },
  lessonsRow: {
    display: 'flex',
    flexWrap: 'wrap' as const,
    gap: '6px',
    paddingInlineStart: '22px'
  },
  lessonChip: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    padding: '4px 10px',
    borderRadius: '999px',
    backgroundColor: '#eef2ff',
    border: '1px solid #c7d2fe'
  },
  lessonName: {
    fontSize: '0.85rem',
    fontWeight: 700,
    color: '#3730a3'
  },
  // صف حقل الدرس: التسمية ثم مربع الإدخال ثم الزر، بخلفية فاتحة وإطار
  // متقطع حتى يُقرأ كمنطقة إدخال لا كجزء من قائمة الوحدات.
  lessonEditorRow: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    flexWrap: 'wrap' as const,
    marginInlineStart: '22px',
    marginTop: '2px',
    padding: '8px 10px',
    borderRadius: '10px',
    backgroundColor: '#f5f3ff',
    border: '1px dashed #a5b4fc'
  },
  lessonFieldLabel: {
    fontSize: '0.85rem',
    fontWeight: 800,
    color: '#4338ca',
    whiteSpace: 'nowrap' as const
  },
  // مربع تحرير اسم العقدة في الشجرة (صف/ترم/مادة/فصل/وحدة).
  nodeInput: {
    flex: 1,
    minWidth: '120px',
    padding: '5px 9px',
    fontSize: '0.9rem',
    borderRadius: '8px',
    border: `1px solid ${COLORS.primary}`,
    outline: 'none',
    fontFamily: 'inherit'
  },
  lessonInput: {
    flex: '1 1 200px',
    minWidth: '160px',
    padding: '7px 11px',
    fontSize: '0.88rem',
    borderRadius: '8px',
    border: '1px solid #c7d2fe',
    outline: 'none',
    fontFamily: 'inherit'
  },
  addLessonButton: {
    padding: '7px 14px',
    fontSize: '0.85rem',
    fontWeight: 800,
    backgroundColor: '#4f46e5',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    whiteSpace: 'nowrap' as const
  },
  addLessonButtonDisabled: {
    backgroundColor: '#c7d2fe',
    color: '#6366f1',
    cursor: 'not-allowed'
  },
  lessonEditChip: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    flex: '1 1 240px'
  },
  noLessonsHint: {
    marginInlineStart: '22px',
    fontSize: '0.78rem',
    color: '#6b7280'
  },
  noUnitsHint: {
    marginTop: '6px',
    fontSize: '0.8rem',
    color: '#92400e',
    backgroundColor: '#f8fafc',
    border: '1px dashed #fcd34d',
    borderRadius: '8px',
    padding: '8px 10px'
  },
  editButton: {
    padding: '8px 12px',
    fontSize: '1rem',
    backgroundColor: '#3b82f6',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    transition: 'background-color 0.3s'
  },
  deleteButton: {
    padding: '8px 12px',
    fontSize: '1rem',
    backgroundColor: '#ef4444',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    transition: 'background-color 0.3s'
  },
  smallEditButton: {
    padding: '4px 8px',
    fontSize: '0.8rem',
    backgroundColor: '#3b82f6',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    transition: 'background-color 0.3s'
  },
  smallDeleteButton: {
    padding: '4px 8px',
    fontSize: '0.8rem',
    backgroundColor: '#ef4444',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    transition: 'background-color 0.3s'
  },
  tinyEditButton: {
    padding: '2px 6px',
    fontSize: '0.7rem',
    backgroundColor: '#3b82f6',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    transition: 'background-color 0.3s'
  },
  tinyDeleteButton: {
    padding: '2px 6px',
    fontSize: '0.7rem',
    backgroundColor: '#ef4444',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    transition: 'background-color 0.3s'
  }
};

export default MyAcademicSettings;
