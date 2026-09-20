
import AcademicSaveBar from '../../components/AcademicSaveBar';
import React, { useState, useEffect } from 'react';
import { markLessonsDeletedUnder, renameLessonsPath } from '../../utils/lessonCascade';
import { STORAGE_KEYS, COLORS } from '../../constants';
import { HierarchicalConfig } from '../../types';
import { getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import { dedupeHierarchicalConfigs } from '../../utils/academic';
import { saveKvConfirmed } from '../../db/confirmedSave';
import ConfirmDialog, { ConfirmRequest } from '../../components/ConfirmDialog';

interface AcademicSettingsProps {
  onUpdate: () => void;
  teacherId?: string;
  teacherName?: string;
}

const AcademicSettings: React.FC<AcademicSettingsProps> = ({ onUpdate, teacherId, teacherName }) => {
  console.log('AcademicSettings Component Rendering');

  const ownerOf = (config: HierarchicalConfig) => getRecordTeacherId(config);
  const isGeneralConfig = (config: HierarchicalConfig) => {
    const owner = ownerOf(config);
    return !owner || owner === 'admin';
  };
  const belongsToTeacher = (config: HierarchicalConfig, id?: string) =>
    Boolean(id) && ownerOf(config) === normalizeScopeValue(id);
  
  const [hierarchicalConfigs, setHierarchicalConfigs] = useState<HierarchicalConfig[]>([]);
  const [grades, setGrades] = useState<string[]>([]);
  
  // للمشرف: اختيار المعلم الذي سينشئ له الإعداد
  const [teachers, setTeachers] = useState<any[]>([]);
  const [selectedTeacherId, setSelectedTeacherId] = useState<string>(teacherId || '');
  const [selectedTeacherName, setSelectedTeacherName] = useState<string>(teacherName || '');
  
  // للتكوين الهرمي الجديد: صف → مادة → فصل → وحدة
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
  // الشجرة تُعرض كاملة، وصف واحد بمواده وفصوله ووحداته ودروسه يملأ الشاشة.
  // هذه الحقول تضيّق المعروض، ولا تمسّ البيانات: الفهارس المستعملة في
  // التعديل والحذف تبقى فهارس المصفوفة الأصلية، فالمخفيّ مخفيّ عن العين
  // وحدها.
  const [filterGrade, setFilterGrade] = useState('');
  const [filterSubject, setFilterSubject] = useState('');
  const [treeSearch, setTreeSearch] = useState('');

  /// الصفوف المطويّة، بمفتاح الصف واسمه. الافتراض مفتوح، فالمعلم صاحب صفّ
  /// واحد يرى شجرته كما كان، ومن له صفوف كثيرة يطوي ما لا يعمل عليه.
  const [collapsedGrades, setCollapsedGrades] = useState<Record<string, boolean>>({});

  // مسودة اسم الدرس لكل وحدة، ومفتاحها موضع الوحدة في الشجرة — فكل وحدة
  // لها حقلها الخاص ولا تتشارك عدة وحدات مربع إدخال واحداً.
  //
  // كانت الإضافة والتعديل تستدعيان window.prompt: لا يظهر في الصفحة حقل
  // ولا زر، والنافذة نفسها تُحجب صامتاً داخل إطار iframe فتبدو الضغطة بلا
  // أثر. الحقل الآن جزء من الواجهة.
  const [lessonDrafts, setLessonDrafts] = useState<Record<string, string>>({});
  const [editingLesson, setEditingLesson] = useState<
    { unitKey: string; index: number; value: string } | null
  >(null);

  // العقدة المفتوحة للتحرير في الشجرة (صف/ترم/مادة/فصل/وحدة)، واحدة في
  // كل مرة. مفتاحها نوعها وموضعها، فلا يلتبس فصلان يحملان الاسم نفسه في
  // مادتين مختلفتين.
  const [editingNode, setEditingNode] = useState<
    { key: string; value: string } | null
  >(null);

  // ما يُسأل عنه قبل الحذف. window.confirm كان يُحجب صامتاً داخل الإطار
  // ويُرجع false، فيبدو زر الحذف معطّلاً بلا سبب ظاهر.
  const [confirmRequest, setConfirmRequest] = useState<ConfirmRequest | null>(null);

  // نسخ شجرة معلم إلى معلم آخر: المعلم المستهدف، وطريقة النسخ.
  const [copyOpen, setCopyOpen] = useState(false);
  const [copyTargetId, setCopyTargetId] = useState('');
  const [copyMode, setCopyMode] = useState<'replace' | 'merge'>('merge');
  const [copyBusy, setCopyBusy] = useState(false);

  const nodeKey = (kind: string, ...indexes: number[]) =>
    `${kind}:${indexes.join('|')}`;

  /**
   * اسم العقدة: نصاً عادياً، أو مربع إدخال حين تكون هذه العقدة قيد التحرير.
   *
   * دالة تُعيد JSX لا مكوّناً متداخلاً عن قصد: المكوّن المعرَّف داخل الـ
   * render يكون نوعاً جديداً في كل تمريرة، فيُفكّك React المدخل ويعيد
   * تركيبه مع كل حرف ويضيع التركيز.
   */
  const renderNodeName = (
    key: string,
    name: string,
    labelStyle: React.CSSProperties,
    icon: string,
    onSave: () => void,
  ): React.ReactNode => {
    if (editingNode?.key !== key) {
      return <span style={labelStyle}>{icon} {name}</span>;
    }
    return (
      <span style={{ display: 'flex', alignItems: 'center', gap: '4px', flex: 1 }}>
        <input
          type="text"
          autoFocus
          value={editingNode.value}
          onChange={e =>
            setEditingNode(current =>
              current ? { ...current, value: e.target.value } : current,
            )
          }
          onKeyDown={e => {
            if (e.key === 'Enter') {
              e.preventDefault();
              onSave();
            }
            if (e.key === 'Escape') setEditingNode(null);
          }}
          style={{
            flex: 1,
            minWidth: '120px',
            padding: '5px 9px',
            fontSize: '0.85rem',
            borderRadius: '8px',
            border: `1px solid ${COLORS.primary}`,
            outline: 'none',
            fontFamily: 'inherit',
          }}
        />
        <button
          onClick={onSave}
          style={{ ...styles.iconButton, color: COLORS.primary }}
          title="حفظ"
        >
          ✅
        </button>
        <button
          onClick={() => setEditingNode(null)}
          style={{ ...styles.iconButton, color: COLORS.danger }}
          title="إلغاء"
        >
          ↩️
        </button>
      </span>
    );
  };

  const unitKeyOf = (
    gradeIndex: number,
    subjectIndex: number,
    termIndex: number,
    unit: string,
  ) => `${gradeIndex}|${subjectIndex}|${termIndex}|${unit}`;

  // دالة للحصول على المعلمين الذين لديهم إعدادات أكاديمية
  const getTeachersWithSettings = () => {
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const teachersWithSettings: any[] = [];
    
    // كل معلم، ومعه عدد إعداداته — والمعلم الذي لا شجرة له يُعرض بصفر
    // حتى يستطيع المشرف فتحه وإنشاءها أو نسخها إليه.
    const uniqueTeacherIds = new Set<string>(
      teachers.map(teacher => normalizeScopeValue(teacher.id)).filter(Boolean),
    );
    allConfigs.forEach((config: HierarchicalConfig) => {
      const owner = ownerOf(config);
      if (owner && owner !== 'admin') {
        uniqueTeacherIds.add(owner);
      }
    });
    
    // الحصول على معلومات كل معلم
    uniqueTeacherIds.forEach(teacherId => {
      const teacher = teachers.find(t => t.id === teacherId);
      if (teacher) {
        const teacherConfigs = allConfigs.filter((c: HierarchicalConfig) => ownerOf(c) === normalizeScopeValue(teacherId));
        teachersWithSettings.push({
          ...teacher,
          configsCount: teacherConfigs.length
        });
      }
    });
    
    return teachersWithSettings;
  };

  const loadSettings = () => {
    try {
      console.log('Loading settings...');
      const rawConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
      const allConfigs = dedupeHierarchicalConfigs(rawConfigs);
      if (JSON.stringify(allConfigs) !== JSON.stringify(rawConfigs)) {
        localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
      }
      console.log('Loaded configs:', allConfigs);
      
      // إذا كان معلم: إظهار إعداداته الخاصة + الإعدادات العامة (admin)
      // إذا كان مشرف واختار معلم: فلترة الإعدادات لإظهار فقط إعدادات هذا المعلم
      // إذا كان مشرف بدون اختيار: عرض الكل
      const effectiveTeacherId = teacherId || selectedTeacherId;
      
      let configs;
      if (effectiveTeacherId) {
        // للمعلم: إظهار إعداداته + الإعدادات العامة (ولكن تفضيل نسخته على النسخة العامة)
        if (teacherId) {
          // جمع الإعدادات: نسخ المعلم + العامة
          const teacherConfigs = allConfigs.filter((c: HierarchicalConfig) => ownerOf(c) === normalizeScopeValue(effectiveTeacherId));
          const adminConfigs = allConfigs.filter(isGeneralConfig);
          
          // دمج: إذا كان للمعلم نسخة من إعداد عام، نستخدم نسخة المعلم
          const mergedConfigs = [...teacherConfigs];
          adminConfigs.forEach(adminConfig => {
            const hasTeacherVersion = teacherConfigs.some(tc => tc.grade === adminConfig.grade);
            if (!hasTeacherVersion) {
              mergedConfigs.push(adminConfig);
            }
          });
          configs = mergedConfigs;
        } else {
          // للمشرف عند اختيار معلم: إظهار إعدادات هذا المعلم فقط
          configs = allConfigs.filter((c: HierarchicalConfig) => ownerOf(c) === normalizeScopeValue(effectiveTeacherId));
        }
      } else {
        configs = allConfigs;
      }
      
      setHierarchicalConfigs(configs);
      
      // استخراج قائمة الصفوف من الكونفيج
      const gradesList = Array.from(new Map(
        configs.map((c: HierarchicalConfig) => [normalizeScopeValue(c.grade), c.grade]),
      ).values());
      setGrades(gradesList);
      
      // حفظ الصفوف في localStorage للتوافقية
      localStorage.setItem(STORAGE_KEYS.GRADES, JSON.stringify(gradesList));
    } catch (error) {
      console.error('Error in loadSettings:', error);
    }
  };

  useEffect(() => {
    console.log('useEffect running');
    
    // تحميل المعلمين إذا كان المشرف (لا يوجد teacherId)
    if (!teacherId) {
      const savedTeachers = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
      setTeachers(savedTeachers);
    }
    
    loadSettings();
  }, [teacherId, selectedTeacherId]); // إعادة التحميل عند تغيير المعلم المختار

  // دالة مساعدة: نسخ إعداد عام لحساب المعلم (Copy-on-Write)
  const createTeacherCopy = (gradeConfig: HierarchicalConfig, modifyFn: (config: HierarchicalConfig) => void): boolean => {
    if (!teacherId) {
      return false; // ليس معلم
    }
    
    // فقط إذا كان الإعداد عام (admin أو فارغ)
    if (!isGeneralConfig(gradeConfig)) {
      return false; // ليس إعداد عام
    }
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    
    // التحقق من وجود نسخة للمعلم مسبقاً
    const existingCopy = allConfigs.find((c: HierarchicalConfig) => 
      c.grade === gradeConfig.grade && belongsToTeacher(c, teacherId)
    );
    
    if (existingCopy) {
      return false; // يوجد نسخة بالفعل، استخدم التعديل العادي
    }
    
    // إنشاء نسخة جديدة
    const newConfig = JSON.parse(JSON.stringify(gradeConfig));
    newConfig.createdBy = teacherId;
    newConfig.createdByName = teacherName;
    newConfig.createdAt = new Date().toISOString();
    
    // تطبيق التعديل
    modifyFn(newConfig);
    
    // حفظ
    const updatedConfigs = [...allConfigs, newConfig];
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    
    return true; // تم إنشاء النسخة
  };

  // دالة تغيير المعلم المختار (للمشرف فقط)
  const handleTeacherChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const newTeacherId = e.target.value;
    setSelectedTeacherId(newTeacherId);
    
    if (newTeacherId === 'admin') {
      setSelectedTeacherName('المشرف - إعدادات عامة');
    } else if (newTeacherId) {
      const teacher = teachers.find(t => t.id === newTeacherId);
      setSelectedTeacherName(teacher?.name || '');
    } else {
      setSelectedTeacherName('');
    }
    
    // إعادة تعيين الاختيارات
    setSelectedGrade('');
    setSelectedSubject('');
    setSelectedTerm('');
    setSelectedUnit('');
  };

  // ============ دوال الإضافة والحذف للهيكل الجديد ============

  // 1. إضافة صف جديد
  const handleAddGrade = () => {
    if (!newGrade.trim()) {
      alert('الرجاء إدخال اسم الصف');
      return;
    }
    
    // تحميل جميع الإعدادات للتحقق من التكرار
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const exists = allConfigs.some((c: HierarchicalConfig) =>
      normalizeScopeValue(c.grade) === normalizeScopeValue(newGrade),
    );
    if (exists) {
      alert('هذا الصف موجود مسبقاً');
      return;
    }

    const newConfig: HierarchicalConfig = {
      grade: newGrade.trim(),
      subjects: [],
      createdBy: teacherId || selectedTeacherId || 'admin',
      createdByName: teacherName || selectedTeacherName || 'المشرف',
      createdAt: new Date().toISOString(),
      createdByAdmin: !teacherId && selectedTeacherId && selectedTeacherId !== 'admin' ? true : undefined
    };

    const updatedConfigs = [...allConfigs, newConfig];
    
    setHierarchicalConfigs(teacherId ? [...hierarchicalConfigs, newConfig] : updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    setNewGrade('');
    loadSettings();
    onUpdate();
    alert('تم إضافة الصف بنجاح');
  };

  // 2. حذف صف
  const handleDeleteGrade = (gradeIndex: number) => {
    const gradeToDelete = hierarchicalConfigs[gradeIndex];
    
    // منع المعلم من حذف الإعدادات العامة أو إعدادات المعلمين الآخرين
    if (teacherId && !belongsToTeacher(gradeToDelete, teacherId)) {
      alert('⚠️ لا يمكنك حذف هذا الإعداد. يمكنك فقط حذف الإعدادات التي أنشأتها بنفسك.');
      return;
    }
    
    setConfirmRequest({
      title: 'حذف الصف',
      message: `سيُحذف «${gradeToDelete.grade}» وكل ما تحته من أترام ومواد وفصول ووحدات ودروس. لا يمكن التراجع عن هذا.`,
      onConfirm: () => performDeleteGrade(gradeIndex),
    });
  };

  const performDeleteGrade = (gradeIndex: number) => {
    const gradeToDelete = hierarchicalConfigs[gradeIndex];
    // ومعه دروسه: درس بلا عقدة في الشجرة لا يراه طالب ولا يظهر في
    // الإعدادات، فيبقى محجوباً إلى الأبد.
    markLessonsDeletedUnder({ grade: gradeToDelete.grade });

    // تحميل جميع الإعدادات للحذف الصحيح
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const updatedConfigs = allConfigs.filter((c: HierarchicalConfig) => 
      c.grade !== gradeToDelete.grade || ownerOf(c) !== ownerOf(gradeToDelete)
    );
    
    setHierarchicalConfigs(hierarchicalConfigs.filter((_, i) => i !== gradeIndex));
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    loadSettings();
    onUpdate();
    alert('تم الحذف بنجاح');
  };

  // 5. إضافة مادة لترم محدد
  const handleAddSubject = () => {
    if (!selectedGrade) {
      alert('الرجاء اختيار الصف أولاً');
      return;
    }
    
    if (!newSubject.trim()) {
      alert('الرجاء إدخال اسم المادة');
      return;
    }
    
    const gradeIndex = hierarchicalConfigs.findIndex(c => c.grade === selectedGrade);
    if (gradeIndex === -1) return;
    
    const grade = hierarchicalConfigs[gradeIndex];
    
    // منع التعديل على إعدادات معلمين آخرين
    if (teacherId && !isGeneralConfig(grade) && !belongsToTeacher(grade, teacherId)) {
      alert('⚠️ لا يمكنك تعديل إعدادات معلم آخر.');
      return;
    }

    if (!grade.subjects) grade.subjects = [];
    if (!grade.subjects) grade.subjects = [];
    
    const subjectExists = grade.subjects.some(s => s.subject === newSubject.trim());
    if (subjectExists) {
      alert('هذه المادة موجودة مسبقاً في هذا الصف');
      return;
    }
    
    // تحديد نوع الإعداد
    const isGeneralSetting = isGeneralConfig(grade);
    const isOwnSetting = belongsToTeacher(grade, teacherId);
    
    // إذا كان إعداد عام والمستخدم معلم: استخدم Copy-on-Write
    if (teacherId && isGeneralSetting) {
      const copied = createTeacherCopy(grade, (config) => {
        if (!config.subjects) config.subjects = [];
        config.subjects.push({
          subject: newSubject.trim(),
          terms: []
        });
      });
      
      if (copied) {
        setNewSubject('');
        loadSettings();
        onUpdate();
        alert('✅ تم إضافة المادة إلى نسختك الخاصة (لن تظهر عند المشرف)');
        return;
      }
    }

    // التعديل المباشر (للمشرف أو للمعلم على إعداداته الخاصة)
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const configIndexInAll = allConfigs.findIndex((c: HierarchicalConfig) => 
      c.grade === grade.grade && ownerOf(c) === ownerOf(grade)
    );
    
    if (configIndexInAll !== -1) {
      allConfigs[configIndexInAll].subjects.push({
        subject: newSubject.trim(),
        terms: []
      });
      localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
    }

    setNewSubject('');
    loadSettings();
    onUpdate();
    
    // رسائل مختلفة حسب نوع الإعداد
    if (isOwnSetting) {
      alert('✅ تم إضافة المادة بنجاح (ستظهر عند المشرف)');
    } else {
      alert('تم إضافة المادة بنجاح');
    }
  };

  // 6. حذف مادة
  const handleDeleteSubject = (gradeIndex: number, subjectIndex: number) => {
    const subject =
      hierarchicalConfigs[gradeIndex].subjects[subjectIndex];
    setConfirmRequest({
      title: 'حذف المادة',
      message: `ستُحذف «${subject.subject}» وكل ما تحتها من فصول ووحدات ودروس. لا يمكن التراجع عن هذا.`,
      onConfirm: () => performDeleteSubject(gradeIndex, subjectIndex),
    });
  };

  const performDeleteSubject = (gradeIndex: number, subjectIndex: number) => {
    const updatedConfigs = [...hierarchicalConfigs];
    const removed = updatedConfigs[gradeIndex].subjects[subjectIndex];
    markLessonsDeletedUnder({
      grade: updatedConfigs[gradeIndex].grade,
      subject: removed.subject,
    });
    updatedConfigs[gradeIndex].subjects.splice(subjectIndex, 1);
    
    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
    alert('تم الحذف بنجاح');
  };

  // 7. إضافة فصل لمادة محددة
  const handleAddTerm = () => {
    if (!selectedGrade || !selectedSubject) {
      alert('الرجاء اختيار الصف والمادة أولاً');
      return;
    }
    if (!newTerm.trim()) {
      alert('الرجاء إدخال اسم الفصل');
      return;
    }

    const gradeIndex = hierarchicalConfigs.findIndex(c => c.grade === selectedGrade);
    if (gradeIndex === -1) return;
    
    const grade = hierarchicalConfigs[gradeIndex];
    
    // منع التعديل على إعدادات معلمين آخرين
    if (teacherId && !isGeneralConfig(grade) && !belongsToTeacher(grade, teacherId)) {
      alert('⚠️ لا يمكنك تعديل إعدادات معلم آخر.');
      return;
    }

    if (!grade.subjects) return;


    if (!grade.subjects) return;

    const subjectIndex = grade.subjects.findIndex(s => s.subject === selectedSubject);
    if (subjectIndex === -1) return;

    const subject = grade.subjects[subjectIndex];
    
    // التأكد من وجود مصفوفة terms
    if (!subject.terms) {
      subject.terms = [];
    }
    
    const termExists = subject.terms.some(t => t.term === newTerm.trim());
    
    if (termExists) {
      alert('هذا الفصل موجود مسبقاً');
      return;
    }
    
    // تحديد نوع الإعداد
    const isGeneralSetting = isGeneralConfig(grade);
    const isOwnSetting = belongsToTeacher(grade, teacherId);
    
    // إذا كان إعداد عام والمستخدم معلم: استخدم Copy-on-Write
    if (teacherId && isGeneralSetting) {
      const copied = createTeacherCopy(grade, (config) => {
        const sIdx = config.subjects.findIndex(s => s.subject === selectedSubject);
        if (sIdx !== -1) {
          if (!config.subjects[sIdx].terms) config.subjects[sIdx].terms = [];
          config.subjects[sIdx].terms.push({
            term: newTerm.trim(),
            units: []
          });
        }
      });
      
      if (copied) {
        setNewTerm('');
        loadSettings();
        onUpdate();
        alert('✅ تم إضافة الفصل إلى نسختك الخاصة (لن يظهر عند المشرف)');
        return;
      }
    }

    // التعديل المباشر (للمشرف أو للمعلم على إعداداته الخاصة)
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const configIndexInAll = allConfigs.findIndex((c: HierarchicalConfig) => 
      c.grade === grade.grade && ownerOf(c) === ownerOf(grade)
    );
    
    if (configIndexInAll !== -1) {
      const sIdx = allConfigs[configIndexInAll].subjects.findIndex((s: any) => s.subject === selectedSubject);
      if (sIdx !== -1) {
        if (!allConfigs[configIndexInAll].subjects[sIdx].terms) {
          allConfigs[configIndexInAll].subjects[sIdx].terms = [];
        }
        allConfigs[configIndexInAll].subjects[sIdx].terms.push({
          term: newTerm.trim(),
          units: []
        });
        localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
      }
    }

    setNewTerm('');
    loadSettings();
    onUpdate();
    
    // رسائل مختلفة حسب نوع الإعداد
    if (isOwnSetting) {
      alert('✅ تم إضافة الفصل بنجاح (سيظهر عند المشرف)');
    } else {
      alert('تم إضافة الفصل بنجاح');
    }
  };

  // 8. حذف فصل
  const handleDeleteTerm = (gradeIndex: number, subjectIndex: number, termIndex: number) => {
    const term =
      hierarchicalConfigs[gradeIndex].subjects[subjectIndex].terms[termIndex];
    setConfirmRequest({
      title: 'حذف الفصل',
      message: `سيُحذف «${term.term}» وكل وحداته ودروسها. لا يمكن التراجع عن هذا.`,
      onConfirm: () => performDeleteTerm(gradeIndex, subjectIndex, termIndex),
    });
  };

  const performDeleteTerm = (gradeIndex: number, subjectIndex: number, termIndex: number) => {
    const updatedConfigs = [...hierarchicalConfigs];
    const subject = updatedConfigs[gradeIndex].subjects[subjectIndex];
    markLessonsDeletedUnder({
      grade: updatedConfigs[gradeIndex].grade,
      subject: subject.subject,
      term: subject.terms[termIndex].term,
    });
    updatedConfigs[gradeIndex].subjects[subjectIndex].terms.splice(termIndex, 1);
    
    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
    alert('تم الحذف بنجاح');
  };

  /**
   * 10. إضافة درس لوحدة محددة — الخطوة السادسة في عمود الإنشاء.
   *
   * الشجرة تُخاطَب بالفهارس في هذا الملف، والنموذج يحمل أسماء، فالأسماء
   * تُحلّ إلى فهارس هنا تماماً كما تفعل إضافة الوحدة فوقها.
   */
  const handleAddLessonFromForm = () => {
    if (!selectedGrade || !selectedSubject || !selectedTerm || !selectedUnit) {
      alert('الرجاء اختيار الصف والمادة والفصل والوحدة أولاً');
      return;
    }
    const name = newLesson.trim();
    if (!name) {
      alert('الرجاء إدخال اسم الدرس');
      return;
    }

    const gradeIndex = hierarchicalConfigs.findIndex(c => c.grade === selectedGrade);
    if (gradeIndex === -1) return;
    const grade = hierarchicalConfigs[gradeIndex];

    if (teacherId && !isGeneralConfig(grade) && !belongsToTeacher(grade, teacherId)) {
      alert('⚠️ لا يمكنك تعديل إعدادات معلم آخر.');
      return;
    }

    const subjectIndex =
      grade.subjects?.findIndex(s => s.subject === selectedSubject) ?? -1;
    if (subjectIndex === -1) return;
    const termIndex =
      grade.subjects[subjectIndex].terms
        ?.findIndex(t => t.term === selectedTerm) ?? -1;
    if (termIndex === -1) return;

    const term = grade.subjects[subjectIndex].terms[termIndex];
    const current = lessonsOf(term, selectedUnit);
    if (current.some(lesson => lesson === name)) {
      alert('هذا الدرس موجود مسبقاً في هذه الوحدة');
      return;
    }

    writeLessons(gradeIndex, subjectIndex, termIndex, selectedUnit, [
      ...current,
      name,
    ]);
    setNewLesson('');
    alert('✅ تم إضافة الدرس');
  };

  // 9. إضافة وحدة لفصل محدد
  const handleAddUnit = () => {
    if (!selectedGrade || !selectedSubject || !selectedTerm) {
      alert('الرجاء اختيار الصف والمادة والفصل أولاً');
      return;
    }
    if (!newUnit.trim()) {
      alert('الرجاء إدخال اسم الوحدة');
      return;
    }

    const gradeIndex = hierarchicalConfigs.findIndex(c => c.grade === selectedGrade);
    if (gradeIndex === -1) return;
    
    const grade = hierarchicalConfigs[gradeIndex];
    
    // منع التعديل على إعدادات معلمين آخرين
    if (teacherId && !isGeneralConfig(grade) && !belongsToTeacher(grade, teacherId)) {
      alert('⚠️ لا يمكنك تعديل إعدادات معلم آخر.');
      return;
    }

    if (!grade.subjects) return;


    if (!grade.subjects) return;

    const subjectIndex = grade.subjects.findIndex(s => s.subject === selectedSubject);
    if (subjectIndex === -1) return;

    if (!grade.subjects[subjectIndex].terms) return;

    const termIndex = grade.subjects[subjectIndex].terms.findIndex(t => t.term === selectedTerm);
    if (termIndex === -1) return;

    const term = grade.subjects[subjectIndex].terms[termIndex];
    
    // التأكد من وجود مصفوفة units
    if (!term.units) {
      term.units = [];
    }
    
    const unitExists = term.units.some(u => u === newUnit.trim());
    
    if (unitExists) {
      alert('هذه الوحدة موجودة مسبقاً');
      return;
    }
    
    // تحديد نوع الإعداد
    const isGeneralSetting = isGeneralConfig(grade);
    const isOwnSetting = belongsToTeacher(grade, teacherId);
    
    // إذا كان إعداد عام والمستخدم معلم: استخدم Copy-on-Write
    if (teacherId && isGeneralSetting) {
      const copied = createTeacherCopy(grade, (config) => {
        const sIdx = config.subjects.findIndex(s => s.subject === selectedSubject);
        if (sIdx !== -1) {
          const tIdx = config.subjects[sIdx].terms.findIndex(t => t.term === selectedTerm);
          if (tIdx !== -1) {
            if (!config.subjects[sIdx].terms[tIdx].units) {
              config.subjects[sIdx].terms[tIdx].units = [];
            }
            config.subjects[sIdx].terms[tIdx].units.push(newUnit.trim());
          }
        }
      });
      
      if (copied) {
        setNewUnit('');
        loadSettings();
        onUpdate();
        alert('✅ تم إضافة الوحدة إلى نسختك الخاصة (لن تظهر عند المشرف)');
        return;
      }
    }

    // التعديل المباشر (للمشرف أو للمعلم على إعداداته الخاصة)
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const configIndexInAll = allConfigs.findIndex((c: HierarchicalConfig) => 
      c.grade === grade.grade && ownerOf(c) === ownerOf(grade)
    );
    
    if (configIndexInAll !== -1) {
      const sIdx = allConfigs[configIndexInAll].subjects.findIndex((s: any) => s.subject === selectedSubject);
      if (sIdx !== -1) {
        const tIdx = allConfigs[configIndexInAll].subjects[sIdx].terms.findIndex((t: any) => t.term === selectedTerm);
        if (tIdx !== -1) {
          if (!allConfigs[configIndexInAll].subjects[sIdx].terms[tIdx].units) {
            allConfigs[configIndexInAll].subjects[sIdx].terms[tIdx].units = [];
          }
          allConfigs[configIndexInAll].subjects[sIdx].terms[tIdx].units.push(newUnit.trim());
          localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
        }
      }
    }

    setNewUnit('');
    loadSettings();
    onUpdate();
    
    // رسائل مختلفة حسب نوع الإعداد
    if (isOwnSetting) {
      alert('✅ تم إضافة الوحدة بنجاح (ستظهر عند المشرف)');
    } else {
      alert('تم إضافة الوحدة بنجاح');
    }
  };

  // 10. حذف وحدة
  const handleDeleteUnit = (gradeIndex: number, subjectIndex: number, termIndex: number, unitIndex: number) => {
    setConfirmRequest({
      title: 'حذف الوحدة',
      message: `ستُحذف «${hierarchicalConfigs[gradeIndex].subjects[subjectIndex].terms[termIndex].units[unitIndex]}» وكل دروسها. لا يمكن التراجع عن هذا.`,
      onConfirm: () =>
        performDeleteUnit(gradeIndex, subjectIndex, termIndex, unitIndex),
    });
  };

  const performDeleteUnit = (gradeIndex: number, subjectIndex: number, termIndex: number, unitIndex: number) => {
    const updatedConfigs = [...hierarchicalConfigs];
    const term =
      updatedConfigs[gradeIndex].subjects[subjectIndex].terms[termIndex];
    const removedUnit = term.units[unitIndex];
    markLessonsDeletedUnder({
      grade: updatedConfigs[gradeIndex].grade,
      subject: updatedConfigs[gradeIndex].subjects[subjectIndex].subject,
      term: term.term,
      unit: removedUnit,
    });
    term.units.splice(unitIndex, 1);
    // خريطة الدروس مفتاحها اسم الوحدة، فحذف الوحدة وحدها كان يترك دروسها
    // معلّقة في الإعداد إلى الأبد — غير مرئية، وتعود للظهور إذا أُنشئت وحدة
    // بالاسم نفسه لاحقاً.
    if (term.lessons && removedUnit in term.lessons) {
      const { [removedUnit]: _removed, ...rest } = term.lessons;
      term.lessons = rest;
    }

    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
    alert('تم الحذف بنجاح');
  };

  // ============ دوال التعديل ============
  //
  // كل مستويات الشجرة تُحرَّر داخل الصفحة: الاسم يتحول إلى مربع إدخال مع
  // زرَّي حفظ وإلغاء. النوافذ القديمة (window.prompt) لم تكن عنصراً مرئياً
  // في الصفحة، وتُحجب صامتة داخل إطار iframe فتبدو الضغطة بلا أثر.
  //
  // كل التعديلات تمرّ من هنا، ومنها إلى localStorage — ومفتاح
  // `smartEdu_hierarchicalConfigs` من مفاتيح المزامنة، فاعتراض الكتابة في
  // db/sync يرسل التغيير إلى Supabase فور حدوثه بلا استدعاء إضافي.

  /** يكتب الشجرة بعد تعديلها ويغلق محرّر السطر. */
  const commitTree = (updatedConfigs: HierarchicalConfig[]) => {
    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
    setEditingNode(null);
  };

  /** يحفظ الاسم المكتوب في محرّر السطر المفتوح على العقدة المحددة. */
  const saveNodeEdit = (
    kind: 'grade' | 'subject' | 'term' | 'unit',
    gradeIndex: number,
    subjectIndex = -1,
    termIndex = -1,
    unitIndex = -1,
  ) => {
    const editing = editingNode;
    if (!editing) return;
    const newName = editing.value.trim();
    if (!newName) return;

    const updatedConfigs = [...hierarchicalConfigs];
    const grade = updatedConfigs[gradeIndex];
    const subject = subjectIndex >= 0 ? grade.subjects[subjectIndex] : null;
    const term = termIndex >= 0 && subject ? subject.terms[termIndex] : null;

    // الدروس تحمل مسارها نصّاً، فإعادة تسمية عقدة تنتقل إليها أيضاً —
    // وإلا بقيت معلقة على الاسم القديم، فلا يراها الطالب ولا تظهر في الإعدادات.
    switch (kind) {
      case 'grade':
        if (grade.grade === newName) return setEditingNode(null);
        renameLessonsPath({ grade: grade.grade }, 'grade', newName);
        grade.grade = newName;
        break;
      case 'subject':
        if (!subject || subject.subject === newName) return setEditingNode(null);
        renameLessonsPath(
          { grade: grade.grade, subject: subject.subject },
          'subject',
          newName,
        );
        subject.subject = newName;
        break;
      case 'term':
        if (!term || term.term === newName) return setEditingNode(null);
        renameLessonsPath(
          { grade: grade.grade, subject: subject!.subject, term: term.term },
          'term',
          newName,
        );
        term.term = newName;
        break;
      case 'unit': {
        if (!term) return setEditingNode(null);
        const oldName = term.units[unitIndex];
        if (oldName === newName) return setEditingNode(null);
        renameLessonsPath(
          {
            grade: grade.grade,
            subject: subject!.subject,
            term: term.term,
            unit: oldName,
          },
          'unit',
          newName,
        );
        term.units[unitIndex] = newName;
        // الدروس مفهرسة باسم الوحدة، فلا بد أن تتبعها عند إعادة التسمية.
        if (term.lessons && oldName in term.lessons) {
          const { [oldName]: moved, ...rest } = term.lessons;
          term.lessons = { ...rest, [newName]: moved };
        }
        break;
      }
    }
    commitTree(updatedConfigs);
  };

  // ============ الدروس داخل الوحدة ============
  // الدروس مخزّنة في خريطة `term.lessons` مفتاحها اسم الوحدة، لا داخل
  // `units` نفسها. هذا يبقي كل إعداد قديم صالحاً بلا ترحيل: من لم يضف
  // دروساً لا يتغيّر عنده شيء، ومن أضاف تظهر دروسه في إدارة المحتوى.

  const lessonsOf = (
    term: { units: string[]; lessons?: Record<string, string[]> },
    unit: string,
  ): string[] => (term.lessons?.[unit] ?? []);

  /** يكتب خريطة الدروس ويحفظ، مع الحفاظ على بقية الشجرة كما هي. */
  const writeLessons = (
    gradeIndex: number,
    subjectIndex: number,
    termIndex: number,
    unit: string,
    next: string[],
  ) => {
    const updatedConfigs = [...hierarchicalConfigs];
    const term =
      updatedConfigs[gradeIndex].subjects[subjectIndex].terms[termIndex];
    term.lessons = { ...(term.lessons ?? {}), [unit]: next };
    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
  };

  /** يضيف الدرس المكتوب في حقل هذه الوحدة. */
  const handleAddLesson = (
    gradeIndex: number,
    subjectIndex: number,
    termIndex: number,
    unit: string,
  ) => {
    const unitKey = unitKeyOf(gradeIndex, subjectIndex, termIndex, unit);
    const name = (lessonDrafts[unitKey] ?? '').trim();
    if (!name) return;
    const term =
      hierarchicalConfigs[gradeIndex].subjects[subjectIndex].terms[termIndex];
    const current = lessonsOf(term, unit);
    if (current.some(lesson => lesson === name)) {
      alert('هذا الدرس موجود مسبقاً في هذه الوحدة');
      return;
    }
    writeLessons(gradeIndex, subjectIndex, termIndex, unit, [
      ...current,
      name,
    ]);
    // الحقل يُفرَّغ ليستقبل الدرس التالي مباشرة.
    setLessonDrafts(drafts => ({ ...drafts, [unitKey]: '' }));
  };

  /** يحفظ التعديل المكتوب في حقل التحرير الظاهر مكان الدرس. */
  const handleSaveLessonEdit = (
    gradeIndex: number,
    subjectIndex: number,
    termIndex: number,
    unit: string,
  ) => {
    const editing = editingLesson;
    if (!editing) return;
    const newName = editing.value.trim();
    if (!newName) return;
    const term =
      hierarchicalConfigs[gradeIndex].subjects[subjectIndex].terms[termIndex];
    const current = lessonsOf(term, unit);
    if (current[editing.index] === newName) {
      setEditingLesson(null);
      return;
    }
    if (current.some((lesson, index) => index !== editing.index && lesson === newName)) {
      alert('هذا الدرس موجود مسبقاً في هذه الوحدة');
      return;
    }
    const next = [...current];
    next[editing.index] = newName;
    writeLessons(gradeIndex, subjectIndex, termIndex, unit, next);
    setEditingLesson(null);
  };

  const handleDeleteLesson = (
    gradeIndex: number,
    subjectIndex: number,
    termIndex: number,
    unit: string,
    lessonIndex: number,
  ) => {
    const term =
      hierarchicalConfigs[gradeIndex].subjects[subjectIndex].terms[termIndex];
    const current = lessonsOf(term, unit);
    setConfirmRequest({
      title: 'حذف الدرس',
      message: `سيُحذف الدرس «${current[lessonIndex]}» من وحدة «${unit}».`,
      onConfirm: () =>
        writeLessons(
          gradeIndex,
          subjectIndex,
          termIndex,
          unit,
          current.filter((_, index) => index !== lessonIndex),
        ),
    });
  };

  /**
   * ينسخ شجرة المعلم المعروض إلى معلم آخر.
   *
   * النسخ يغيّر المالك: كل إعداد منسوخ يُكتب باسم المعلم المستهدف، فيراه
   * هو وطلابه — فالطالب لا يرى إلا إعدادات معلمه. و«الدمج» يمرّ على
   * `dedupeHierarchicalConfigs`، فالصف الموجود عند الاثنين يتّحد بمواده
   * وفصوله ووحداته ودروسه بدل أن يتكرّر.
   */
  const copySettingsToTeacher = async () => {
    const sourceId = normalizeScopeValue(selectedTeacherId);
    const targetId = normalizeScopeValue(copyTargetId);
    if (!sourceId || !targetId || sourceId === targetId) {
      alert('اختر معلماً مستهدفاً مختلفاً عن صاحب الإعدادات.');
      return;
    }
    const target = teachers.find(teacher => normalizeScopeValue(teacher.id) === targetId);
    if (!target) return;

    setCopyBusy(true);
    try {
      const all: HierarchicalConfig[] = JSON.parse(
        localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]',
      );
      const source = all.filter(config => ownerOf(config) === sourceId);
      if (source.length === 0) {
        alert('لا توجد إعدادات لنسخها.');
        return;
      }
      const sourceName = teachers.find(
        teacher => normalizeScopeValue(teacher.id) === sourceId,
      )?.name || 'معلم';

      const copies: HierarchicalConfig[] = source.map(config => ({
        ...JSON.parse(JSON.stringify(config)),
        createdBy: target.id,
        createdByName: target.name,
        createdByAdmin: true,
        copiedFrom: selectedTeacherId,
        copiedFromName: sourceName,
        createdAt: new Date().toISOString(),
      }));

      const others = all.filter(config => ownerOf(config) !== targetId);
      const targetExisting = copyMode === 'merge'
        ? all.filter(config => ownerOf(config) === targetId)
        : [];
      const next = dedupeHierarchicalConfigs([...others, ...targetExisting, ...copies]);

      localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(next));
      const outcome = await saveKvConfirmed(STORAGE_KEYS.HIERARCHICAL_CONFIGS, next);
      if (outcome.ok === false) {
        alert(`⚠️ نُسخت محلياً ولم تُحفظ على الخادم: ${outcome.reason}`);
      } else {
        alert(
          `✅ نُسخت ${copies.length} إعداداً إلى «${target.name}»` +
            (outcome.verified ? ' وحُفظت في قاعدة البيانات.' : ' وأُرسلت، وتعذّر التحقق.'),
        );
      }
      setCopyOpen(false);
      setCopyTargetId('');
      loadSettings();
      onUpdate();
    } finally {
      setCopyBusy(false);
    }
  };

  // ============ تصفية الشجرة ============

  const matchesFilter = (value: unknown, selected: string) =>
    !selected || normalizeScopeValue(value) === normalizeScopeValue(selected);

  /// كل نصّ داخل الصف: اسمه، ومواده، وفصولها، ووحداتها، ودروسها. البحث
  /// يطابق أيّها، فالمعلم الباحث عن وحدة لا يحتاج أن يتذكّر مادتها.
  const searchHaystack = (config: HierarchicalConfig): string => {
    const parts: string[] = [config.grade, config.createdByName ?? ''];
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

  const subjectsShown = (config: HierarchicalConfig) =>
    (config.subjects || []).filter(subject => matchesFilter(subject.subject, filterSubject));

  const gradeShown = (config: HierarchicalConfig) => {
    if (!matchesFilter(config.grade, filterGrade)) return false;
    if (filterSubject && subjectsShown(config).length === 0) return false;
    const query = normalizeScopeValue(treeSearch);
    return !query || searchHaystack(config).includes(query);
  };

  const shownConfigs = hierarchicalConfigs.filter(gradeShown);

  /// المواد المعروضة في قائمة التصفية: مواد الصف المختار وحده إن اختير.
  const filterSubjectOptions = Array.from(
    new Map(
      hierarchicalConfigs
        .filter(config => matchesFilter(config.grade, filterGrade))
        .flatMap(config => config.subjects || [])
        .map(subject => [normalizeScopeValue(subject.subject), subject.subject]),
    ).values(),
  );

  const isCollapsed = (config: HierarchicalConfig, index: number) =>
    collapsedGrades[`${index}:${normalizeScopeValue(config.grade)}`] === true;

  const toggleGrade = (config: HierarchicalConfig, index: number) =>
    setCollapsedGrades(current => {
      const key = `${index}:${normalizeScopeValue(config.grade)}`;
      return { ...current, [key]: !current[key] };
    });

  const setAllCollapsed = (collapsed: boolean) =>
    setCollapsedGrades(
      collapsed
        ? Object.fromEntries(
            hierarchicalConfigs.map((config, index) => [
              `${index}:${normalizeScopeValue(config.grade)}`,
              true,
            ]),
          )
        : {},
    );

  const countUnits = (config: HierarchicalConfig) =>
    (config.subjects || []).reduce(
      (total, subject) =>
        total + (subject.terms || []).reduce((sum, term) => sum + (term.units || []).length, 0),
      0,
    );

  // ============ دوال الحصول على القوائم ============

  // الحصول على المواد للصف المحدد
  const getSubjectsForGrade = () => {
    const grade = hierarchicalConfigs.find(c => c.grade === selectedGrade);
    return grade && grade.subjects ? grade.subjects : [];
  };

  // الحصول على الفصول للمادة المحددة
  const getTermsForSubject = () => {
    const subject = getSubjectsForGrade().find(s => s.subject === selectedSubject);
    return subject && subject.terms ? subject.terms : [];
  };

  // الحصول على الوحدات للفصل المحدد
  const getUnitsForTerm = () => {
    const term = getTermsForSubject().find(t => t.term === selectedTerm);
    return term && term.units ? term.units : [];
  };

  return (
    <div style={styles.container} className="dashboard-page animate-fadeIn">
      <div style={styles.header}>
        <h1 style={styles.title}>الإعدادات الأكاديمية - النظام الهرمي</h1>
        <p style={styles.subtitle}>إدارة البنية الهرمية: صف → مادة → فصل → وحدة → درس</p>
      </div>

      <AcademicSaveBar onSaved={loadSettings} />

      {!teacherId && selectedTeacherId && (
        <div style={styles.copyBar}>
          <span style={{ fontWeight: 'bold', color: '#3730a3' }}>
            📋 إعدادات «{selectedTeacherName || 'معلم'}»
          </span>
          <button onClick={() => setCopyOpen(true)} style={styles.copyButton}>
            نسخ هذه الإعدادات لمعلم آخر
          </button>
        </div>
      )}

      {copyOpen && (
        <div style={styles.copyOverlay} onClick={() => !copyBusy && setCopyOpen(false)}>
          <div style={styles.copyDialog} onClick={event => event.stopPropagation()}>
            <h3 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 'bold', color: '#111827' }}>
              نسخ إعدادات «{selectedTeacherName || 'معلم'}» إلى معلم آخر
            </h3>

            <label style={styles.copyLabel}>المعلم المستهدف</label>
            <select
              value={copyTargetId}
              onChange={event => setCopyTargetId(event.target.value)}
              style={styles.copySelect}
            >
              <option value="">— اختر معلماً —</option>
              {teachers
                .filter(teacher => normalizeScopeValue(teacher.id) !== normalizeScopeValue(selectedTeacherId))
                .map(teacher => (
                  <option key={teacher.id} value={teacher.id}>{teacher.name}</option>
                ))}
            </select>

            <label style={styles.copyLabel}>طريقة النسخ</label>
            <label style={styles.copyChoice}>
              <input
                type="radio"
                checked={copyMode === 'merge'}
                onChange={() => setCopyMode('merge')}
              />
              <span>
                <strong>دمج</strong> — تُضاف الصفوف والمواد إلى شجرته الحالية، والمكرّر يتّحد.
              </span>
            </label>
            <label style={styles.copyChoice}>
              <input
                type="radio"
                checked={copyMode === 'replace'}
                onChange={() => setCopyMode('replace')}
              />
              <span>
                <strong>استبدال</strong> — تُحذف شجرته الحالية وتحلّ هذه محلّها.
              </span>
            </label>

            <div style={{ display: 'flex', gap: '8px', marginTop: '14px' }}>
              <button
                onClick={() => void copySettingsToTeacher()}
                disabled={copyBusy || !copyTargetId}
                style={styles.copyConfirm}
              >
                {copyBusy ? '⏳ جارٍ النسخ…' : '✅ نسخ وحفظ'}
              </button>
              <button
                onClick={() => setCopyOpen(false)}
                disabled={copyBusy}
                style={styles.copyCancel}
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}

      {/* للمشرف فقط: قائمة المعلمين */}
      {!teacherId && (
        <div className="dashboard-academic-settings-grid">
          {/* القائمة الجانبية */}
          <div style={{ 
            backgroundColor: 'white', 
            padding: '20px', 
            borderRadius: '16px', 
            border: '2px solid #818cf8',
          }}>
            <h3 style={{ fontWeight: 'bold', fontSize: '1.2rem', color: '#4338ca', marginBottom: '15px' }}>
              👨‍🏫 المعلمون
            </h3>
            
            {/* خيار إنشاء إعدادات جديدة */}
            <button
              onClick={() => {
                setSelectedTeacherId('');
                setSelectedTeacherName('');
              }}
              style={{
                ...styles.teacherListItem,
                backgroundColor: selectedTeacherId === '' ? '#eef2ff' : 'white',
                borderRight: selectedTeacherId === '' ? '4px solid #4338ca' : '1px solid #e5e7eb'
              }}
            >
              <div style={{ fontSize: '1.5rem' }}>➕</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 'bold', color: '#4338ca' }}>إنشاء إعدادات جديدة</div>
                <div style={{ fontSize: '0.8rem', color: '#6b7280' }}>اختر معلم أو إنشاء عامة</div>
              </div>
            </button>

            {/* قائمة المعلمين الذين لديهم إعدادات */}
            <div style={{ marginTop: '15px' }}>
              <div style={{ fontSize: '0.9rem', color: '#6b7280', marginBottom: '10px', fontWeight: 'bold' }}>
                المعلمون الذين لديهم إعدادات:
              </div>
              {getTeachersWithSettings().map(teacher => (
                <button
                  key={teacher.id}
                  onClick={() => {
                    setSelectedTeacherId(teacher.id);
                    setSelectedTeacherName(teacher.name);
                  }}
                  style={{
                    ...styles.teacherListItem,
                    backgroundColor: selectedTeacherId === teacher.id ? '#eef2ff' : 'white',
                    borderRight: selectedTeacherId === teacher.id ? '4px solid #4338ca' : '1px solid #e5e7eb'
                  }}
                >
                  <div style={{ fontSize: '1.5rem' }}>👨‍🏫</div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 'bold', color: '#1f2937' }}>{teacher.name}</div>
                    <div style={{ fontSize: '0.8rem', color: '#6b7280' }}>
                      {teacher.configsCount} إعداد • {teacher.subject || 'معلم'}
                    </div>
                  </div>
                  <div style={{ fontSize: '1.2rem', color: '#10b981' }}>→</div>
                </button>
              ))}
              
              {getTeachersWithSettings().length === 0 && (
                <div style={{ 
                  padding: '20px', 
                  textAlign: 'center', 
                  color: '#9ca3af',
                  fontSize: '0.9rem'
                }}>
                  لا يوجد معلمون لديهم إعدادات بعد
                </div>
              )}
            </div>
          </div>

          {/* المحتوى الرئيسي */}
          <div style={{ 
            backgroundColor: 'white', 
            padding: '25px', 
            borderRadius: '16px', 
            border: '2px solid #818cf8'
          }}>
            {!selectedTeacherId && !selectedTeacherName ? (
              <div>
                <h3 style={{ fontWeight: 'bold', fontSize: '1.3rem', color: '#4338ca', marginBottom: '15px' }}>
                  اختر المعلم لإنشاء أو عرض الإعدادات
                </h3>
                <select 
                  value={selectedTeacherId} 
                  onChange={handleTeacherChange}
                  style={{ 
                    width: '100%', 
                    padding: '15px', 
                    fontSize: '1.1rem',
                    fontWeight: 'bold',
                    border: '2px solid #c7d2fe',
                    borderRadius: '12px',
                    backgroundColor: '#f5f3ff',
                    color: '#4338ca',
                    outline: 'none',
                    cursor: 'pointer',
                    marginBottom: '15px'
                  }}
                >
                  <option value="">اختر معلم...</option>
                  <option value="admin">📚 إعدادات عامة (تظهر لجميع المعلمين)</option>
                  {teachers.map(teacher => (
                    <option key={teacher.id} value={teacher.id}>
                      👨‍🏫 {teacher.name} - {teacher.subject || 'معلم'}
                    </option>
                  ))}
                </select>
              </div>
            ) : (
              <div>
                {selectedTeacherId === 'admin' && (
                  <div style={{ 
                    padding: '12px', 
                    backgroundColor: '#dcfce7',
                    borderRadius: '8px',
                    borderRight: '4px solid #22c55e',
                    marginBottom: '15px'
                  }}>
                    <span style={{ fontWeight: 'bold', color: '#15803d' }}>
                      ✅ إعدادات عامة - تظهر لجميع المعلمين
                    </span>
                  </div>
                )}
                {selectedTeacherName && selectedTeacherId !== 'admin' && (
                  <div style={{ 
                    padding: '12px', 
                    backgroundColor: '#eef2ff',
                    borderRadius: '8px',
                    borderRight: '4px solid #818cf8',
                    marginBottom: '15px'
                  }}>
                    <span style={{ fontWeight: 'bold', color: '#4338ca' }}>
                      👨‍🏫 إعدادات المعلم: {selectedTeacherName}
                    </span>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      )}

      <div className="dashboard-academic-editor-grid">
        {/* قسم التكوين */}
        <div style={{ backgroundColor: 'white', padding: '20px', borderRadius: '12px', border: '1px solid #e5e7eb', height: 'fit-content' }}>
          <h3 style={{ fontWeight: 'bold', fontSize: '1.2rem', marginBottom: '20px', color: '#111827' }}>بناء التكوين الهرمي</h3>
          
          {/* 1. إضافة صف */}
          <div style={{ marginBottom: '20px', padding: '15px', backgroundColor: '#f9fafb', borderRadius: '8px' }}>
            <label style={{ fontWeight: 'bold', display: 'block', marginBottom: '8px' }}>1️⃣ إضافة صف جديد</label>
            <div style={{ display: 'flex', gap: '8px' }}>
              <input
                type="text"
                value={newGrade}
                onChange={e => setNewGrade(e.target.value)}
                onKeyPress={e => e.key === 'Enter' && handleAddGrade()}
                placeholder="مثال: الصف الأول الابتدائي"
                style={{ ...styles.addInput, flex: 1 }}
              />
              <button onClick={handleAddGrade} style={styles.addButton}>➕</button>
            </div>
          </div>

          {/* 2. اختيار صف وإضافة ترم */}
          <div style={{ marginBottom: '20px', padding: '15px', backgroundColor: '#f9fafb', borderRadius: '8px' }}>
            <label style={{ fontWeight: 'bold', display: 'block', marginBottom: '8px' }}>2️⃣ اختر صف وأضف مادة</label>
            <select 
              value={selectedGrade} 
              onChange={e => {
                setSelectedGrade(e.target.value);
                setSelectedSubject('');
                setSelectedTerm('');
                setSelectedUnit('');
              }}
              style={{ ...styles.addInput, marginBottom: '8px' }}
            >
              <option value="">-- اختر الصف --</option>
              {grades.map((g, i) => <option key={i} value={g}>{g}</option>)}
            </select>
            <div style={{ display: 'flex', gap: '8px' }}>
              <input
                type="text"
                value={newSubject}
                onChange={e => setNewSubject(e.target.value)}
                onKeyPress={e => e.key === 'Enter' && !e.currentTarget.disabled && handleAddSubject()}
                placeholder="مثال: الرياضيات"
                style={{ ...styles.addInput, flex: 1 }}
                disabled={!selectedGrade}
              />
              <button onClick={handleAddSubject} style={styles.addButton} disabled={!selectedGrade}>➕</button>
            </div>
          </div>

          {/* 4. اختيار مادة وإضافة فصل */}
          <div style={{ marginBottom: '20px', padding: '15px', backgroundColor: '#f9fafb', borderRadius: '8px' }}>
            <label style={{ fontWeight: 'bold', display: 'block', marginBottom: '8px' }}>4️⃣ اختر مادة وأضف فصل</label>
            <select 
              value={selectedSubject} 
              onChange={e => {
                setSelectedSubject(e.target.value);
                setSelectedTerm('');
                setSelectedUnit('');
              }}
              style={{ ...styles.addInput, marginBottom: '8px' }}
              disabled={!selectedGrade}
            >
              <option value="">-- اختر المادة --</option>
              {getSubjectsForGrade().map((s, i) => <option key={i} value={s.subject}>{s.subject}</option>)}
            </select>
            <div style={{ display: 'flex', gap: '8px' }}>
              <input
                type="text"
                value={newTerm}
                onChange={e => setNewTerm(e.target.value)}
                onKeyPress={e => e.key === 'Enter' && !e.currentTarget.disabled && handleAddTerm()}
                placeholder="مثال: الفصل الدراسي الأول"
                style={{ ...styles.addInput, flex: 1 }}
                disabled={!selectedSubject}
              />
              <button onClick={handleAddTerm} style={styles.addButton} disabled={!selectedSubject}>➕</button>
            </div>
          </div>

          {/* 5. اختيار فصل وإضافة وحدة */}
          <div style={{ padding: '15px', backgroundColor: '#f9fafb', borderRadius: '8px' }}>
            <label style={{ fontWeight: 'bold', display: 'block', marginBottom: '8px' }}>5️⃣ اختر فصل وأضف وحدة</label>
            <select 
              value={selectedTerm} 
              onChange={e => {
                setSelectedTerm(e.target.value);
                // الوحدة تتبع فصلها: اختيار فصل آخر يجعل الوحدة المختارة
                // تخصّ شجرة أخرى.
                setSelectedUnit('');
              }}
              style={{ ...styles.addInput, marginBottom: '8px' }}
              disabled={!selectedSubject}
            >
              <option value="">-- اختر الفصل --</option>
              {getTermsForSubject().map((t, i) => <option key={i} value={t.term}>{t.term}</option>)}
            </select>
            <div style={{ display: 'flex', gap: '8px' }}>
              <input
                type="text"
                value={newUnit}
                onChange={e => setNewUnit(e.target.value)}
                onKeyPress={e => e.key === 'Enter' && !e.currentTarget.disabled && handleAddUnit()}
                placeholder="مثال: الأعداد الصحيحة"
                style={{ ...styles.addInput, flex: 1 }}
                disabled={!selectedTerm}
              />
              <button onClick={handleAddUnit} style={styles.addButton} disabled={!selectedTerm}>➕</button>
            </div>
          </div>

          {/* 6. اختيار وحدة وإضافة درس — آخر خطوة في التسلسل السداسي.
              الدرس يُضاف من هنا بنفس طريقة كل مستوى فوقه: اختر ما يحتويه،
              ثم اكتب الاسم. كان يُضاف من بطاقة الوحدة فقط في عمود العرض،
              فلم يكن جزءاً من خطوات الإنشاء. */}
          <div style={{ padding: '15px', backgroundColor: '#f9fafb', borderRadius: '8px' }}>
            <label style={{ fontWeight: 'bold', display: 'block', marginBottom: '8px' }}>6️⃣ اختر وحدة وأضف درس</label>
            <select
              value={selectedUnit}
              onChange={e => setSelectedUnit(e.target.value)}
              style={{ ...styles.addInput, marginBottom: '8px' }}
              disabled={!selectedTerm}
            >
              <option value="">-- اختر الوحدة --</option>
              {getUnitsForTerm().map((u: string, i: number) => <option key={i} value={u}>{u}</option>)}
            </select>
            <div style={{ display: 'flex', gap: '8px' }}>
              <input
                type="text"
                value={newLesson}
                onChange={e => setNewLesson(e.target.value)}
                onKeyPress={e => e.key === 'Enter' && !e.currentTarget.disabled && handleAddLessonFromForm()}
                placeholder="مثال: الخلية ووظائفها"
                style={{ ...styles.addInput, flex: 1 }}
                disabled={!selectedUnit}
              />
              <button onClick={handleAddLessonFromForm} style={styles.addButton} disabled={!selectedUnit}>➕</button>
            </div>
          </div>
        </div>


        {/* قسم العرض */}
        <div style={{ backgroundColor: 'white', padding: '20px', borderRadius: '12px', border: '1px solid #e5e7eb', maxHeight: '800px', overflowY: 'auto' }}>
          <h3 style={{ fontWeight: 'bold', fontSize: '1.2rem', marginBottom: '20px', color: '#111827' }}>الهيكل الحالي</h3>

          {hierarchicalConfigs.length > 0 && (
            <div style={styles.treeFilters}>
              <select
                value={filterGrade}
                onChange={e => {
                  setFilterGrade(e.target.value);
                  setFilterSubject('');
                }}
                style={styles.treeFilterControl}
              >
                <option value="">🏫 كل الصفوف</option>
                {Array.from(new Set(hierarchicalConfigs.map(config => config.grade))).map(grade => (
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
                style={{ ...styles.treeFilterControl, flex: '2 1 220px' }}
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

          {hierarchicalConfigs.length > 0 && shownConfigs.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '30px', color: '#9ca3af' }}>
              <div style={{ fontSize: '2rem', marginBottom: '8px' }}>🔍</div>
              <p>لا يطابق هذا البحث أي صف. جرّب كلمة أخرى أو امسح التصفية.</p>
            </div>
          ) : hierarchicalConfigs.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '40px', color: '#9ca3af' }}>
              <div style={{ fontSize: '3rem', marginBottom: '10px' }}>📚</div>
              <p>لا يوجد تكوين هرمي بعد. ابدأ بإضافة صف من القسم الأيسر</p>
            </div>
          ) : (
            hierarchicalConfigs.map((gradeConfig, gradeIndex) => {
              // الفهرس فهرس المصفوفة الأصلية دائماً، لا فهرس المعروض: كل
              // تعديل وحذف في هذه الشاشة يُخاطب الشجرة به.
              if (!gradeShown(gradeConfig)) return null;
              const collapsed = isCollapsed(gradeConfig, gradeIndex);
              const shownSubjectEntries = (gradeConfig.subjects || [])
                .map((subject, subjectIndex) => ({ subject, subjectIndex }))
                .filter(entry => matchesFilter(entry.subject.subject, filterSubject));
              return (
              <div key={gradeIndex} style={{ marginBottom: '20px', padding: '15px', backgroundColor: '#f0f9ff', borderRadius: '10px', border: '2px solid #3b82f6' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: collapsed ? '0' : '15px' }}>
                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: '10px' }}>
                    <button
                      onClick={() => toggleGrade(gradeConfig, gradeIndex)}
                      style={styles.treeToggle}
                      title={collapsed ? 'فتح الصف' : 'طيّ الصف'}
                      aria-expanded={!collapsed}
                    >
                      {collapsed ? '▶' : '▼'}
                    </button>
                  <div>
                    <div style={{ marginBottom: '4px' }}>
                      {renderNodeName(
                        nodeKey('grade', gradeIndex),
                        gradeConfig.grade,
                        { fontWeight: 'bold', fontSize: '1.1rem', color: '#1e40af' },
                        '🏫',
                        () => saveNodeEdit('grade', gradeIndex),
                      )}
                    </div>
                    <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                      {gradeConfig.createdByName && (
                        <span style={{ backgroundColor: '#f1f5f9', color: '#92400e', padding: '2px 8px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 'bold' }}>
                          👨‍🏫 {gradeConfig.createdByName}
                        </span>
                      )}
                      {teacherId && isGeneralConfig(gradeConfig) && (
                        <span style={{ backgroundColor: '#dbeafe', color: '#1e40af', padding: '2px 8px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 'bold' }}>
                          ✏️ يمكن التعديل (سينشئ نسخة)
                        </span>
                      )}
                      <span style={{ backgroundColor: '#e0f2fe', color: '#0369a1', padding: '2px 8px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 'bold' }}>
                        {(gradeConfig.subjects || []).length} مادة · {countUnits(gradeConfig)} وحدة
                      </span>
                    </div>
                  </div>
                  </div>
                </div>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button 
                    onClick={() => setEditingNode({ key: nodeKey('grade', gradeIndex), value: gradeConfig.grade })}
                    title="تعديل اسم الصف"
                    style={{ 
                      ...styles.iconButton, 
                      color: COLORS.primary
                    }}
                  >
                    ✏️
                  </button>
                  <button 
                    onClick={() => handleDeleteGrade(gradeIndex)} 
                    style={{ 
                      ...styles.iconButton, 
                      color: teacherId && !isGeneralConfig(gradeConfig) && !belongsToTeacher(gradeConfig, teacherId) ? '#d1d5db' : COLORS.danger,
                      cursor: teacherId && !isGeneralConfig(gradeConfig) && !belongsToTeacher(gradeConfig, teacherId) ? 'not-allowed' : 'pointer'
                    }}
                    disabled={Boolean(teacherId && !isGeneralConfig(gradeConfig) && !belongsToTeacher(gradeConfig, teacherId))}
                  >
                    🗑️
                  </button>
                </div>

                {collapsed ? null : shownSubjectEntries.length === 0 ? (
                  <div style={{ color: '#9ca3af', fontSize: '0.9rem', padding: '10px' }}>لا توجد مواد</div>
                ) : (
                  shownSubjectEntries.map(({ subject, subjectIndex }) => (
                          <div key={subjectIndex} style={{ marginBottom: '10px', padding: '10px', backgroundColor: '#f1f5f9', borderRadius: '8px' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                              {renderNodeName(
                                nodeKey('subject', gradeIndex, subjectIndex),
                                subject.subject,
                                { fontWeight: 'bold', fontSize: '0.95rem', color: '#059669' },
                                '📚',
                                () => saveNodeEdit('subject', gradeIndex, subjectIndex),
                              )}
                              <div style={{ display: 'flex', gap: '8px' }}>
                                <button onClick={() => setEditingNode({ key: nodeKey('subject', gradeIndex, subjectIndex), value: subject.subject })} style={{ ...styles.iconButton, color: COLORS.primary, fontSize: '0.8rem' }} title="تعديل اسم المادة">✏️</button>
                                <button onClick={() => handleDeleteSubject(gradeIndex, subjectIndex)} style={{ ...styles.iconButton, color: COLORS.danger, fontSize: '0.8rem' }}>✖</button>
                              </div>
                            </div>

                            {!subject.terms || subject.terms.length === 0 ? (
                              <div style={{ color: '#9ca3af', fontSize: '0.8rem', padding: '6px' }}>لا توجد فصول</div>
                            ) : (
                              subject.terms.map((term, termIndex) => (
                                <div key={termIndex} style={{ marginBottom: '8px', padding: '8px', backgroundColor: 'white', borderRadius: '8px', border: '1px solid #e5e7eb' }}>
                                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                                    {renderNodeName(
                                      nodeKey('term', gradeIndex, subjectIndex, termIndex),
                                      term.term,
                                      { fontWeight: 'bold', fontSize: '0.9rem', color: '#92400e' },
                                      '📅',
                                      () => saveNodeEdit('term', gradeIndex, subjectIndex, termIndex),
                                    )}
                                    <div style={{ display: 'flex', gap: '6px' }}>
                                      <button onClick={() => setEditingNode({ key: nodeKey('term', gradeIndex, subjectIndex, termIndex), value: term.term })} style={{ ...styles.iconButton, color: COLORS.primary, fontSize: '0.75rem' }} title="تعديل اسم الفصل">✏️</button>
                                      <button onClick={() => handleDeleteTerm(gradeIndex, subjectIndex, termIndex)} style={{ ...styles.iconButton, color: COLORS.danger, fontSize: '0.75rem' }}>✖</button>
                                    </div>
                                  </div>

                                  {!term.units || term.units.length === 0 ? (
                                    <div style={{ color: '#9ca3af', fontSize: '0.75rem', padding: '4px' }}>لا توجد وحدات</div>
                                  ) : (
                                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
                                      {term.units.map((unit, unitIndex) => (
                                        <div key={unitIndex} style={{ width: '100%', padding: '6px 8px', backgroundColor: '#dbeafe', borderRadius: '8px', fontSize: '0.85rem', marginBottom: '6px' }}>
                                          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                                            {renderNodeName(
                                              nodeKey('unit', gradeIndex, subjectIndex, termIndex, unitIndex),
                                              unit,
                                              { flex: 1 },
                                              '📖',
                                              () => saveNodeEdit('unit', gradeIndex, subjectIndex, termIndex, unitIndex),
                                            )}
                                            <button onClick={() => setEditingNode({ key: nodeKey('unit', gradeIndex, subjectIndex, termIndex, unitIndex), value: unit })} style={{ background: 'none', border: 'none', cursor: 'pointer', color: COLORS.primary, padding: '0 2px' }} title="تعديل اسم الوحدة">✏️</button>
                                            <button onClick={() => handleDeleteUnit(gradeIndex, subjectIndex, termIndex, unitIndex)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: COLORS.danger, padding: '0 2px' }}>✖</button>
                                          </div>

                                          {/* حقل إضافة الدرس: مربع إدخال ظاهر وزر صريح، لا نافذة prompt.
                                              لكل وحدة حقلها الخاص حتى يكون واضحاً أين سيُضاف الدرس. */}
                                          {(() => {
                                            const unitKey = unitKeyOf(gradeIndex, subjectIndex, termIndex, unit);
                                            const draft = lessonDrafts[unitKey] ?? '';
                                            return (
                                              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap', marginTop: '6px', padding: '7px 9px', borderRadius: '8px', backgroundColor: '#eef2ff', border: '1px dashed #a5b4fc' }}>
                                                <span style={{ fontSize: '0.78rem', fontWeight: 800, color: '#4338ca', whiteSpace: 'nowrap' }}>الدرس:</span>
                                                <input
                                                  type="text"
                                                  value={draft}
                                                  onChange={e => {
                                                    const value = e.target.value;
                                                    setLessonDrafts(drafts => ({ ...drafts, [unitKey]: value }));
                                                  }}
                                                  onKeyDown={e => {
                                                    if (e.key === 'Enter') {
                                                      e.preventDefault();
                                                      handleAddLesson(gradeIndex, subjectIndex, termIndex, unit);
                                                    }
                                                  }}
                                                  placeholder={`اسم الدرس داخل وحدة "${unit}"`}
                                                  style={{ flex: '1 1 180px', minWidth: '150px', padding: '6px 10px', fontSize: '0.82rem', borderRadius: '8px', border: '1px solid #c7d2fe', outline: 'none', fontFamily: 'inherit' }}
                                                />
                                                <button
                                                  onClick={() => handleAddLesson(gradeIndex, subjectIndex, termIndex, unit)}
                                                  disabled={!draft.trim()}
                                                  style={{ padding: '6px 12px', fontSize: '0.8rem', fontWeight: 800, backgroundColor: draft.trim() ? '#4f46e5' : '#c7d2fe', color: draft.trim() ? '#ffffff' : '#6366f1', border: 'none', borderRadius: '8px', cursor: draft.trim() ? 'pointer' : 'not-allowed', whiteSpace: 'nowrap' }}
                                                  title="إضافة درس إلى هذه الوحدة"
                                                >
                                                  ➕ إضافة درس
                                                </button>
                                              </div>
                                            );
                                          })()}

                                          {lessonsOf(term, unit).length === 0 ? (
                                            <div style={{ color: '#6b7280', fontSize: '0.72rem', paddingRight: '18px', marginTop: '4px' }}>لا توجد دروس في هذه الوحدة بعد — اكتب اسم الدرس أعلاه ثم اضغط «إضافة درس».</div>
                                          ) : (
                                            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px', paddingRight: '18px', marginTop: '5px' }}>
                                              {lessonsOf(term, unit).map((lesson, lessonIndex) => {
                                                const unitKey = unitKeyOf(gradeIndex, subjectIndex, termIndex, unit);
                                                const isEditing = editingLesson?.unitKey === unitKey && editingLesson?.index === lessonIndex;
                                                return isEditing ? (
                                                  <div key={lessonIndex} style={{ display: 'inline-flex', alignItems: 'center', gap: '3px', flex: '1 1 220px' }}>
                                                    <input
                                                      type="text"
                                                      autoFocus
                                                      value={editingLesson!.value}
                                                      onChange={e => setEditingLesson(current => (current ? { ...current, value: e.target.value } : current))}
                                                      onKeyDown={e => {
                                                        if (e.key === 'Enter') {
                                                          e.preventDefault();
                                                          handleSaveLessonEdit(gradeIndex, subjectIndex, termIndex, unit);
                                                        }
                                                        if (e.key === 'Escape') setEditingLesson(null);
                                                      }}
                                                      style={{ flex: 1, minWidth: '120px', padding: '5px 9px', fontSize: '0.78rem', borderRadius: '5px', border: '1px solid #93c5fd', outline: 'none', fontFamily: 'inherit' }}
                                                    />
                                                    <button onClick={() => handleSaveLessonEdit(gradeIndex, subjectIndex, termIndex, unit)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: COLORS.primary, padding: '0 2px' }} title="حفظ">✅</button>
                                                    <button onClick={() => setEditingLesson(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: COLORS.danger, padding: '0 2px' }} title="إلغاء">↩️</button>
                                                  </div>
                                                ) : (
                                                  <div key={lessonIndex} style={{ display: 'inline-flex', alignItems: 'center', gap: '3px', padding: '3px 7px', backgroundColor: '#ffffff', border: '1px solid #93c5fd', borderRadius: '8px', fontSize: '0.78rem' }}>
                                                    <span>📝 {lesson}</span>
                                                    <button onClick={() => setEditingLesson({ unitKey, index: lessonIndex, value: lesson })} style={{ background: 'none', border: 'none', cursor: 'pointer', color: COLORS.primary, padding: '0 2px' }} title="تعديل الدرس">✏️</button>
                                                    <button onClick={() => handleDeleteLesson(gradeIndex, subjectIndex, termIndex, unit, lessonIndex)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: COLORS.danger, padding: '0 2px' }} title="حذف الدرس">✖</button>
                                                  </div>
                                                );
                                              })}
                                            </div>
                                          )}
                                        </div>
                                      ))}
                                    </div>
                                  )}
                                </div>
                              ))
                            )}
                          </div>
                        ))
                      )}
              </div>
            );
            })
          )}
        </div>
      </div>

      <ConfirmDialog
        request={confirmRequest}
        onClose={() => setConfirmRequest(null)}
      />
    </div>
  );
};


const styles = {
  copyBar: {
    display: 'flex', flexWrap: 'wrap' as const, alignItems: 'center', justifyContent: 'space-between',
    gap: '10px', padding: '12px 14px', marginBottom: '16px',
    backgroundColor: '#eef2ff', border: '1px solid #c7d2fe', borderRadius: '12px',
  },
  copyButton: {
    padding: '9px 14px', backgroundColor: '#4338ca', color: 'white', border: 'none',
    borderRadius: '10px', cursor: 'pointer', fontWeight: 'bold', fontSize: '0.85rem',
  },
  copyOverlay: {
    position: 'fixed' as const, inset: 0, backgroundColor: 'rgba(15,23,42,0.45)',
    display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '16px', zIndex: 50,
  },
  copyDialog: {
    width: 'min(460px, 100%)', backgroundColor: 'white', borderRadius: '16px',
    padding: '20px', display: 'flex', flexDirection: 'column' as const, gap: '6px',
    boxShadow: '0 20px 45px rgba(0,0,0,0.25)',
  },
  copyLabel: { marginTop: '12px', fontWeight: 'bold', fontSize: '0.85rem', color: '#374151' },
  copySelect: {
    padding: '10px 12px', border: '2px solid #d1d5db', borderRadius: '10px',
    fontSize: '0.9rem', fontFamily: 'inherit',
  },
  copyChoice: {
    display: 'flex', gap: '8px', alignItems: 'flex-start', padding: '8px',
    fontSize: '0.85rem', color: '#374151', cursor: 'pointer',
  },
  copyConfirm: {
    flex: 1, padding: '11px', backgroundColor: '#059669', color: 'white', border: 'none',
    borderRadius: '10px', cursor: 'pointer', fontWeight: 'bold',
  },
  copyCancel: {
    padding: '11px 16px', backgroundColor: '#f1f5f9', color: '#334155', border: 'none',
    borderRadius: '10px', cursor: 'pointer', fontWeight: 'bold',
  },
  treeFilters: { display: 'flex', flexWrap: 'wrap' as const, gap: '8px', marginBottom: '16px', padding: '12px', backgroundColor: '#f8fafc', borderRadius: '10px', border: '1px solid #e2e8f0' },
  treeFilterControl: { flex: '1 1 150px', minWidth: '140px', padding: '9px 12px', border: '2px solid #d1d5db', borderRadius: '8px', fontSize: '0.9rem', fontFamily: 'inherit', backgroundColor: 'white' },
  treeToolButton: { padding: '8px 12px', backgroundColor: '#eef2ff', color: '#3730a3', border: '1px solid #c7d2fe', borderRadius: '8px', cursor: 'pointer', fontSize: '0.8rem', fontWeight: 'bold', whiteSpace: 'nowrap' as const },
  treeToggle: { background: 'none', border: 'none', cursor: 'pointer', color: '#1e40af', fontSize: '0.9rem', padding: '2px 4px', lineHeight: 1 },
  container: { padding: '20px', maxWidth: '1400px', margin: '0 auto' },
  header: { marginBottom: '30px', textAlign: 'center' as const },
  title: { marginBottom: '10px', color: '#1F2937', fontSize: '2rem', fontWeight: 'bold' },
  subtitle: { marginBottom: '0', color: '#6B7280', fontSize: '1.1rem' },
  card: { backgroundColor: 'white', borderRadius: '12px', padding: '20px', boxShadow: '0 2px 10px rgba(0,0,0,0.08)', border: '1px solid #e5e7eb' },
  cardHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingBottom: '15px', borderBottom: '2px solid #f3f4f6' },
  cardTitle: { fontSize: '1.1rem', fontWeight: 'bold', color: '#111827' },
  badge: { backgroundColor: COLORS.primary, color: 'white', padding: '6px 12px', borderRadius: '20px', fontSize: '0.8rem', fontWeight: 'bold' },
  addInput: { flex: 1, padding: '12px 15px', border: '2px solid #d1d5db', borderRadius: '8px', fontSize: '1rem', width: '100%' },
  addButton: { padding: '12px 20px', backgroundColor: COLORS.primary, color: 'white', border: 'none', borderRadius: '8px', cursor: 'pointer', fontSize: '0.9rem', fontWeight: 'bold', whiteSpace: 'nowrap' as const },
  listItem: { display: 'flex', alignItems: 'center', gap: '10px', padding: '12px', marginBottom: '8px', backgroundColor: '#f8fafc', borderRadius: '8px', border: '1px solid #e5e7eb' },
  iconButton: { padding: '6px 10px', backgroundColor: 'white', border: '1px solid #d1d5db', borderRadius: '8px', cursor: 'pointer', fontSize: '0.8rem' },
  saveButton: { padding: '8px 12px', backgroundColor: '#10B981', color: 'white', border: 'none', borderRadius: '8px', cursor: 'pointer', whiteSpace: 'nowrap' as const },
  cancelButton: { padding: '8px 12px', backgroundColor: '#EF4444', color: 'white', border: 'none', borderRadius: '8px', cursor: 'pointer' },
  emptyState: { textAlign: 'center' as const, padding: '20px', color: '#9CA3AF', fontSize: '0.9rem' },
  categoriesGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(350px, 1fr))', gap: '25px' },
  teacherListItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    padding: '15px',
    marginBottom: '10px',
    borderRadius: '12px',
    cursor: 'pointer',
    transition: 'all 0.3s',
    border: '1px solid #e5e7eb',
    width: '100%',
    textAlign: 'right' as const
  }
};

export default AcademicSettings;
