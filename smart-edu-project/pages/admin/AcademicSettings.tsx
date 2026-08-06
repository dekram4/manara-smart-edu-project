
import React, { useState, useEffect } from 'react';
import { STORAGE_KEYS, COLORS } from '../../constants';
import { HierarchicalConfig } from '../../types';
import { getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';

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
  
  // للتكوين الهرمي الجديد: صف → ترم → مادة → فصل → وحدة
  const [selectedGrade, setSelectedGrade] = useState('');
  const [newGrade, setNewGrade] = useState('');
  const [selectedAtram, setSelectedAtram] = useState('');
  const [newAtram, setNewAtram] = useState('');
  const [selectedSubject, setSelectedSubject] = useState('');
  const [newSubject, setNewSubject] = useState('');
  const [selectedTerm, setSelectedTerm] = useState('');
  const [newTerm, setNewTerm] = useState('');
  const [newUnit, setNewUnit] = useState('');

  // دالة للحصول على المعلمين الذين لديهم إعدادات أكاديمية
  const getTeachersWithSettings = () => {
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const teachersWithSettings: any[] = [];
    
    // جمع المعلمين الفريدين الذين لديهم إعدادات
    const uniqueTeacherIds = new Set<string>();
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
      const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
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
      const gradesList = configs.map((c: HierarchicalConfig) => c.grade);
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
    setSelectedAtram('');
    setSelectedSubject('');
    setSelectedTerm('');
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
    const exists = allConfigs.some((c: HierarchicalConfig) => c.grade === newGrade.trim());
    if (exists) {
      alert('هذا الصف موجود مسبقاً');
      return;
    }

    const newConfig: HierarchicalConfig = {
      grade: newGrade.trim(),
      atrams: [],
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
    
    if (!confirm('هل أنت متأكد من حذف هذا الصف وجميع محتوياته؟')) return;
    
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

  // 3. إضافة ترم لصف محدد
  const handleAddAtram = () => {
    if (!selectedGrade) {
      alert('الرجاء اختيار الصف أولاً');
      return;
    }
    
    if (!newAtram.trim()) {
      alert('الرجاء إدخال اسم الترم');
      return;
    }
    
    const gradeIndex = hierarchicalConfigs.findIndex(c => c.grade === selectedGrade);
    if (gradeIndex === -1) return;
    
    const grade = hierarchicalConfigs[gradeIndex];
    
    // إذا كان معلم آخر، منع التعديل
    if (teacherId && !isGeneralConfig(grade) && !belongsToTeacher(grade, teacherId)) {
      alert('⚠️ لا يمكنك تعديل إعدادات معلم آخر.');
      return;
    }
    
    // التأكد من وجود مصفوفة atrams
    if (!grade.atrams) {
      grade.atrams = [];
    }
    
    const atramExists = grade.atrams.some(a => a.atram === newAtram.trim());
    if (atramExists) {
      alert('هذا الترم موجود مسبقاً في هذا الصف');
      return;
    }
    
    // إذا كان إعداد عام (admin): استخدم Copy-on-Write
    // إذا كان إعداد خاص بالمعلم نفسه: عدل مباشرة
    const isGeneralSetting = isGeneralConfig(grade);
    const isOwnSetting = belongsToTeacher(grade, teacherId);
    
    if (teacherId && isGeneralSetting) {
      // محاولة إنشاء نسخة للإعداد العام
      const copied = createTeacherCopy(grade, (config) => {
        if (!config.atrams) config.atrams = [];
        config.atrams.push({
          atram: newAtram.trim(),
          subjects: []
        });
      });
      
      if (copied) {
        setNewAtram('');
        loadSettings();
        onUpdate();
        alert('✅ تم إضافة الترم إلى نسختك الخاصة (لن يظهر عند المشرف)');
        return;
      }
    }

    // التعديل المباشر (للمشرف أو للمعلم على إعداداته الخاصة)
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const configIndexInAll = allConfigs.findIndex((c: HierarchicalConfig) => 
      c.grade === grade.grade && ownerOf(c) === ownerOf(grade)
    );
    
    if (configIndexInAll !== -1) {
      allConfigs[configIndexInAll].atrams.push({
        atram: newAtram.trim(),
        subjects: []
      });
      localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
    }

    setNewAtram('');
    loadSettings();
    onUpdate();
    
    // رسائل مختلفة حسب نوع الإعداد
    if (isOwnSetting) {
      alert('✅ تم إضافة الترم بنجاح (سيظهر عند المشرف)');
    } else {
      alert('تم إضافة الترم بنجاح');
    }
  };

  // 4. حذف ترم
  const handleDeleteAtram = (gradeIndex: number, atramIndex: number) => {
    const grade = hierarchicalConfigs[gradeIndex];
    
    // منع المعلم من حذف إعدادات ليست له
    if (teacherId && !belongsToTeacher(grade, teacherId)) {
      alert('⚠️ لا يمكنك حذف هذا الإعداد. يمكنك فقط حذف الإعدادات التي أنشأتها بنفسك.');
      return;
    }
    
    if (!confirm('هل أنت متأكد من حذف هذا الترم وجميع محتوياته؟')) return;
    
    const updatedConfigs = [...hierarchicalConfigs];
    updatedConfigs[gradeIndex].atrams.splice(atramIndex, 1);
    
    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
    alert('تم الحذف بنجاح');
  };

  // 5. إضافة مادة لترم محدد
  const handleAddSubject = () => {
    if (!selectedGrade || !selectedAtram) {
      alert('الرجاء اختيار الصف والترم أولاً');
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

    if (!grade.atrams) grade.atrams = [];
    const atramIndex = grade.atrams.findIndex(a => a.atram === selectedAtram);
    if (atramIndex === -1) return;

    const atram = grade.atrams[atramIndex];
    if (!atram.subjects) atram.subjects = [];
    
    const subjectExists = atram.subjects.some(s => s.subject === newSubject.trim());
    if (subjectExists) {
      alert('هذه المادة موجودة مسبقاً في هذا الترم');
      return;
    }
    
    // تحديد نوع الإعداد
    const isGeneralSetting = isGeneralConfig(grade);
    const isOwnSetting = belongsToTeacher(grade, teacherId);
    
    // إذا كان إعداد عام والمستخدم معلم: استخدم Copy-on-Write
    if (teacherId && isGeneralSetting) {
      const copied = createTeacherCopy(grade, (config) => {
        const atramIdx = config.atrams.findIndex(a => a.atram === selectedAtram);
        if (atramIdx !== -1) {
          if (!config.atrams[atramIdx].subjects) config.atrams[atramIdx].subjects = [];
          config.atrams[atramIdx].subjects.push({
            subject: newSubject.trim(),
            terms: []
          });
        }
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
      const atramIdx = allConfigs[configIndexInAll].atrams.findIndex((a: any) => a.atram === selectedAtram);
      if (atramIdx !== -1) {
        allConfigs[configIndexInAll].atrams[atramIdx].subjects.push({
          subject: newSubject.trim(),
          terms: []
        });
        localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
      }
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
  const handleDeleteSubject = (gradeIndex: number, atramIndex: number, subjectIndex: number) => {
    if (!confirm('هل أنت متأكد من حذف هذه المادة وجميع محتوياتها؟')) return;
    
    const updatedConfigs = [...hierarchicalConfigs];
    updatedConfigs[gradeIndex].atrams[atramIndex].subjects.splice(subjectIndex, 1);
    
    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
    alert('تم الحذف بنجاح');
  };

  // 7. إضافة فصل لمادة محددة
  const handleAddTerm = () => {
    if (!selectedGrade || !selectedAtram || !selectedSubject) {
      alert('الرجاء اختيار الصف والترم والمادة أولاً');
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

    if (!grade.atrams) return;

    const atramIndex = grade.atrams.findIndex(a => a.atram === selectedAtram);
    if (atramIndex === -1) return;

    if (!grade.atrams[atramIndex].subjects) return;

    const subjectIndex = grade.atrams[atramIndex].subjects.findIndex(s => s.subject === selectedSubject);
    if (subjectIndex === -1) return;

    const subject = grade.atrams[atramIndex].subjects[subjectIndex];
    
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
        const aIdx = config.atrams.findIndex(a => a.atram === selectedAtram);
        if (aIdx !== -1) {
          const sIdx = config.atrams[aIdx].subjects.findIndex(s => s.subject === selectedSubject);
          if (sIdx !== -1) {
            if (!config.atrams[aIdx].subjects[sIdx].terms) config.atrams[aIdx].subjects[sIdx].terms = [];
            config.atrams[aIdx].subjects[sIdx].terms.push({
              term: newTerm.trim(),
              units: []
            });
          }
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
      const aIdx = allConfigs[configIndexInAll].atrams.findIndex((a: any) => a.atram === selectedAtram);
      if (aIdx !== -1) {
        const sIdx = allConfigs[configIndexInAll].atrams[aIdx].subjects.findIndex((s: any) => s.subject === selectedSubject);
        if (sIdx !== -1) {
          if (!allConfigs[configIndexInAll].atrams[aIdx].subjects[sIdx].terms) {
            allConfigs[configIndexInAll].atrams[aIdx].subjects[sIdx].terms = [];
          }
          allConfigs[configIndexInAll].atrams[aIdx].subjects[sIdx].terms.push({
            term: newTerm.trim(),
            units: []
          });
          localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
        }
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
  const handleDeleteTerm = (gradeIndex: number, atramIndex: number, subjectIndex: number, termIndex: number) => {
    if (!confirm('هل أنت متأكد من حذف هذا الفصل وجميع محتوياته؟')) return;
    
    const updatedConfigs = [...hierarchicalConfigs];
    updatedConfigs[gradeIndex].atrams[atramIndex].subjects[subjectIndex].terms.splice(termIndex, 1);
    
    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
    alert('تم الحذف بنجاح');
  };

  // 9. إضافة وحدة لفصل محدد
  const handleAddUnit = () => {
    if (!selectedGrade || !selectedAtram || !selectedSubject || !selectedTerm) {
      alert('الرجاء اختيار الصف والترم والمادة والفصل أولاً');
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

    if (!grade.atrams) return;

    const atramIndex = grade.atrams.findIndex(a => a.atram === selectedAtram);
    if (atramIndex === -1) return;

    if (!grade.atrams[atramIndex].subjects) return;

    const subjectIndex = grade.atrams[atramIndex].subjects.findIndex(s => s.subject === selectedSubject);
    if (subjectIndex === -1) return;

    if (!grade.atrams[atramIndex].subjects[subjectIndex].terms) return;

    const termIndex = grade.atrams[atramIndex].subjects[subjectIndex].terms.findIndex(t => t.term === selectedTerm);
    if (termIndex === -1) return;

    const term = grade.atrams[atramIndex].subjects[subjectIndex].terms[termIndex];
    
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
        const aIdx = config.atrams.findIndex(a => a.atram === selectedAtram);
        if (aIdx !== -1) {
          const sIdx = config.atrams[aIdx].subjects.findIndex(s => s.subject === selectedSubject);
          if (sIdx !== -1) {
            const tIdx = config.atrams[aIdx].subjects[sIdx].terms.findIndex(t => t.term === selectedTerm);
            if (tIdx !== -1) {
              if (!config.atrams[aIdx].subjects[sIdx].terms[tIdx].units) {
                config.atrams[aIdx].subjects[sIdx].terms[tIdx].units = [];
              }
              config.atrams[aIdx].subjects[sIdx].terms[tIdx].units.push(newUnit.trim());
            }
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
      const aIdx = allConfigs[configIndexInAll].atrams.findIndex((a: any) => a.atram === selectedAtram);
      if (aIdx !== -1) {
        const sIdx = allConfigs[configIndexInAll].atrams[aIdx].subjects.findIndex((s: any) => s.subject === selectedSubject);
        if (sIdx !== -1) {
          const tIdx = allConfigs[configIndexInAll].atrams[aIdx].subjects[sIdx].terms.findIndex((t: any) => t.term === selectedTerm);
          if (tIdx !== -1) {
            if (!allConfigs[configIndexInAll].atrams[aIdx].subjects[sIdx].terms[tIdx].units) {
              allConfigs[configIndexInAll].atrams[aIdx].subjects[sIdx].terms[tIdx].units = [];
            }
            allConfigs[configIndexInAll].atrams[aIdx].subjects[sIdx].terms[tIdx].units.push(newUnit.trim());
            localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
          }
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
  const handleDeleteUnit = (gradeIndex: number, atramIndex: number, subjectIndex: number, termIndex: number, unitIndex: number) => {
    if (!confirm('هل أنت متأكد من حذف هذه الوحدة؟')) return;
    
    const updatedConfigs = [...hierarchicalConfigs];
    updatedConfigs[gradeIndex].atrams[atramIndex].subjects[subjectIndex].terms[termIndex].units.splice(unitIndex, 1);
    
    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
    alert('تم الحذف بنجاح');
  };

  // ============ دوال التعديل ============
  
  const handleEditGrade = (gradeIndex: number) => {
    const oldName = hierarchicalConfigs[gradeIndex].grade;
    const newName = prompt('تعديل اسم الصف:', oldName);
    if (!newName || newName.trim() === '' || newName === oldName) return;
    
    const updatedConfigs = [...hierarchicalConfigs];
    updatedConfigs[gradeIndex].grade = newName.trim();
    
    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
    alert('تم التعديل بنجاح');
  };

  const handleEditAtram = (gradeIndex: number, atramIndex: number) => {
    const oldName = hierarchicalConfigs[gradeIndex].atrams[atramIndex].atram;
    const newName = prompt('تعديل اسم الترم:', oldName);
    if (!newName || newName.trim() === '' || newName === oldName) return;
    
    const updatedConfigs = [...hierarchicalConfigs];
    updatedConfigs[gradeIndex].atrams[atramIndex].atram = newName.trim();
    
    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
    alert('تم التعديل بنجاح');
  };

  const handleEditSubject = (gradeIndex: number, atramIndex: number, subjectIndex: number) => {
    const oldName = hierarchicalConfigs[gradeIndex].atrams[atramIndex].subjects[subjectIndex].subject;
    const newName = prompt('تعديل اسم المادة:', oldName);
    if (!newName || newName.trim() === '' || newName === oldName) return;
    
    const updatedConfigs = [...hierarchicalConfigs];
    updatedConfigs[gradeIndex].atrams[atramIndex].subjects[subjectIndex].subject = newName.trim();
    
    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
    alert('تم التعديل بنجاح');
  };

  const handleEditTerm = (gradeIndex: number, atramIndex: number, subjectIndex: number, termIndex: number) => {
    const oldName = hierarchicalConfigs[gradeIndex].atrams[atramIndex].subjects[subjectIndex].terms[termIndex].term;
    const newName = prompt('تعديل اسم الفصل:', oldName);
    if (!newName || newName.trim() === '' || newName === oldName) return;
    
    const updatedConfigs = [...hierarchicalConfigs];
    updatedConfigs[gradeIndex].atrams[atramIndex].subjects[subjectIndex].terms[termIndex].term = newName.trim();
    
    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
    alert('تم التعديل بنجاح');
  };

  const handleEditUnit = (gradeIndex: number, atramIndex: number, subjectIndex: number, termIndex: number, unitIndex: number) => {
    const oldName = hierarchicalConfigs[gradeIndex].atrams[atramIndex].subjects[subjectIndex].terms[termIndex].units[unitIndex];
    const newName = prompt('تعديل اسم الوحدة:', oldName);
    if (!newName || newName.trim() === '' || newName === oldName) return;
    
    const updatedConfigs = [...hierarchicalConfigs];
    updatedConfigs[gradeIndex].atrams[atramIndex].subjects[subjectIndex].terms[termIndex].units[unitIndex] = newName.trim();
    
    setHierarchicalConfigs(updatedConfigs);
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    onUpdate();
    alert('تم التعديل بنجاح');
  };

  // ============ دوال الحصول على القوائم ============

  // الحصول على الأترام للصف المحدد
  const getAtramsForGrade = () => {
    const grade = hierarchicalConfigs.find(c => c.grade === selectedGrade);
    return grade && grade.atrams ? grade.atrams : [];
  };

  // الحصول على المواد للترم المحدد
  const getSubjectsForAtram = () => {
    const grade = hierarchicalConfigs.find(c => c.grade === selectedGrade);
    if (!grade || !grade.atrams) return [];
    const atram = grade.atrams.find(a => a.atram === selectedAtram);
    return atram && atram.subjects ? atram.subjects : [];
  };

  // الحصول على الفصول للمادة المحددة
  const getTermsForSubject = () => {
    const grade = hierarchicalConfigs.find(c => c.grade === selectedGrade);
    if (!grade || !grade.atrams) return [];
    const atram = grade.atrams.find(a => a.atram === selectedAtram);
    if (!atram || !atram.subjects) return [];
    const subject = atram.subjects.find(s => s.subject === selectedSubject);
    return subject && subject.terms ? subject.terms : [];
  };

  // الحصول على الوحدات للفصل المحدد
  const getUnitsForTerm = () => {
    const grade = hierarchicalConfigs.find(c => c.grade === selectedGrade);
    if (!grade || !grade.atrams) return [];
    const atram = grade.atrams.find(a => a.atram === selectedAtram);
    if (!atram || !atram.subjects) return [];
    const subject = atram.subjects.find(s => s.subject === selectedSubject);
    if (!subject || !subject.terms) return [];
    const term = subject.terms.find(t => t.term === selectedTerm);
    return term && term.units ? term.units : [];
  };

  return (
    <div style={styles.container} className="animate-fadeIn">
      <div style={styles.header}>
        <h1 style={styles.title}>الإعدادات الأكاديمية - النظام الهرمي</h1>
        <p style={styles.subtitle}>إدارة البنية الهرمية: صف → ترم → مادة → فصل → وحدة</p>
      </div>

      {/* للمشرف فقط: قائمة المعلمين */}
      {!teacherId && (
        <div style={{ display: 'grid', gridTemplateColumns: '300px 1fr', gap: '25px', marginBottom: '25px' }}>
          {/* القائمة الجانبية */}
          <div style={{ 
            backgroundColor: 'white', 
            padding: '20px', 
            borderRadius: '16px', 
            border: '2px solid #818cf8',
            maxHeight: '600px',
            overflowY: 'auto'
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

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '25px' }}>
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
            <label style={{ fontWeight: 'bold', display: 'block', marginBottom: '8px' }}>2️⃣ اختر صف وأضف ترم</label>
            <select 
              value={selectedGrade} 
              onChange={e => {
                setSelectedGrade(e.target.value);
                setSelectedAtram('');
                setSelectedSubject('');
                setSelectedTerm('');
              }}
              style={{ ...styles.addInput, marginBottom: '8px' }}
            >
              <option value="">-- اختر الصف --</option>
              {grades.map((g, i) => <option key={i} value={g}>{g}</option>)}
            </select>
            <div style={{ display: 'flex', gap: '8px' }}>
              <input
                type="text"
                value={newAtram}
                onChange={e => setNewAtram(e.target.value)}
                onKeyPress={e => e.key === 'Enter' && !e.currentTarget.disabled && handleAddAtram()}
                placeholder="مثال: الترم الأول"
                style={{ ...styles.addInput, flex: 1 }}
                disabled={!selectedGrade}
              />
              <button onClick={handleAddAtram} style={styles.addButton} disabled={!selectedGrade}>➕</button>
            </div>
          </div>

          {/* 3. اختيار ترم وإضافة مادة */}
          <div style={{ marginBottom: '20px', padding: '15px', backgroundColor: '#f9fafb', borderRadius: '8px' }}>
            <label style={{ fontWeight: 'bold', display: 'block', marginBottom: '8px' }}>3️⃣ اختر ترم وأضف مادة</label>
            <select 
              value={selectedAtram} 
              onChange={e => {
                setSelectedAtram(e.target.value);
                setSelectedSubject('');
                setSelectedTerm('');
              }}
              style={{ ...styles.addInput, marginBottom: '8px' }}
              disabled={!selectedGrade}
            >
              <option value="">-- اختر الترم --</option>
              {getAtramsForGrade().map((a, i) => <option key={i} value={a.atram}>{a.atram}</option>)}
            </select>
            <div style={{ display: 'flex', gap: '8px' }}>
              <input
                type="text"
                value={newSubject}
                onChange={e => setNewSubject(e.target.value)}
                onKeyPress={e => e.key === 'Enter' && !e.currentTarget.disabled && handleAddSubject()}
                placeholder="مثال: الرياضيات"
                style={{ ...styles.addInput, flex: 1 }}
                disabled={!selectedAtram}
              />
              <button onClick={handleAddSubject} style={styles.addButton} disabled={!selectedAtram}>➕</button>
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
              }}
              style={{ ...styles.addInput, marginBottom: '8px' }}
              disabled={!selectedAtram}
            >
              <option value="">-- اختر المادة --</option>
              {getSubjectsForAtram().map((s, i) => <option key={i} value={s.subject}>{s.subject}</option>)}
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
              onChange={e => setSelectedTerm(e.target.value)}
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
        </div>


        {/* قسم العرض */}
        <div style={{ backgroundColor: 'white', padding: '20px', borderRadius: '12px', border: '1px solid #e5e7eb', maxHeight: '800px', overflowY: 'auto' }}>
          <h3 style={{ fontWeight: 'bold', fontSize: '1.2rem', marginBottom: '20px', color: '#111827' }}>الهيكل الحالي</h3>
          
          {hierarchicalConfigs.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '40px', color: '#9ca3af' }}>
              <div style={{ fontSize: '3rem', marginBottom: '10px' }}>📚</div>
              <p>لا يوجد تكوين هرمي بعد. ابدأ بإضافة صف من القسم الأيسر</p>
            </div>
          ) : (
            hierarchicalConfigs.map((gradeConfig, gradeIndex) => (
              <div key={gradeIndex} style={{ marginBottom: '20px', padding: '15px', backgroundColor: '#f0f9ff', borderRadius: '10px', border: '2px solid #3b82f6' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '15px' }}>
                  <div>
                    <h4 style={{ fontWeight: 'bold', fontSize: '1.1rem', color: '#1e40af', marginBottom: '4px' }}>🏫 {gradeConfig.grade}</h4>
                    <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                      {gradeConfig.createdByName && (
                        <span style={{ backgroundColor: '#fef3c7', color: '#92400e', padding: '2px 8px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 'bold' }}>
                          👨‍🏫 {gradeConfig.createdByName}
                        </span>
                      )}
                      {teacherId && isGeneralConfig(gradeConfig) && (
                        <span style={{ backgroundColor: '#dbeafe', color: '#1e40af', padding: '2px 8px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 'bold' }}>
                          ✏️ يمكن التعديل (سينشئ نسخة)
                        </span>
                      )}
                    </div>
                  </div>
                </div>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button 
                    onClick={() => handleEditGrade(gradeIndex)} 
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
                    disabled={teacherId && !isGeneralConfig(gradeConfig) && !belongsToTeacher(gradeConfig, teacherId)}
                  >
                    🗑️
                  </button>
                </div>

                {!gradeConfig.atrams || gradeConfig.atrams.length === 0 ? (
                  <div style={{ color: '#9ca3af', fontSize: '0.9rem', padding: '10px' }}>لا توجد أترام</div>
                ) : (
                  gradeConfig.atrams.map((atram, atramIndex) => (
                    <div key={atramIndex} style={{ marginBottom: '12px', padding: '12px', backgroundColor: 'white', borderRadius: '8px', border: '1px solid #e5e7eb' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
                        <h5 style={{ fontWeight: 'bold', color: '#7c3aed' }}>🏷️ {atram.atram}</h5>
                        <div style={{ display: 'flex', gap: '8px' }}>
                          <button onClick={() => handleEditAtram(gradeIndex, atramIndex)} style={{ ...styles.iconButton, color: COLORS.primary }}>✏️</button>
                          <button onClick={() => handleDeleteAtram(gradeIndex, atramIndex)} style={{ ...styles.iconButton, color: COLORS.danger }}>✖</button>
                        </div>
                      </div>

                      {!atram.subjects || atram.subjects.length === 0 ? (
                        <div style={{ color: '#9ca3af', fontSize: '0.85rem', padding: '8px' }}>لا توجد مواد</div>
                      ) : (
                        atram.subjects.map((subject, subjectIndex) => (
                          <div key={subjectIndex} style={{ marginBottom: '10px', padding: '10px', backgroundColor: '#fef3c7', borderRadius: '6px' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                              <h6 style={{ fontWeight: 'bold', fontSize: '0.95rem', color: '#059669' }}>📚 {subject.subject}</h6>
                              <div style={{ display: 'flex', gap: '8px' }}>
                                <button onClick={() => handleEditSubject(gradeIndex, atramIndex, subjectIndex)} style={{ ...styles.iconButton, color: COLORS.primary, fontSize: '0.8rem' }}>✏️</button>
                                <button onClick={() => handleDeleteSubject(gradeIndex, atramIndex, subjectIndex)} style={{ ...styles.iconButton, color: COLORS.danger, fontSize: '0.8rem' }}>✖</button>
                              </div>
                            </div>

                            {!subject.terms || subject.terms.length === 0 ? (
                              <div style={{ color: '#9ca3af', fontSize: '0.8rem', padding: '6px' }}>لا توجد فصول</div>
                            ) : (
                              subject.terms.map((term, termIndex) => (
                                <div key={termIndex} style={{ marginBottom: '8px', padding: '8px', backgroundColor: 'white', borderRadius: '4px', border: '1px solid #e5e7eb' }}>
                                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                                    <span style={{ fontWeight: 'bold', fontSize: '0.9rem', color: '#92400e' }}>📅 {term.term}</span>
                                    <div style={{ display: 'flex', gap: '6px' }}>
                                      <button onClick={() => handleEditTerm(gradeIndex, atramIndex, subjectIndex, termIndex)} style={{ ...styles.iconButton, color: COLORS.primary, fontSize: '0.75rem' }}>✏️</button>
                                      <button onClick={() => handleDeleteTerm(gradeIndex, atramIndex, subjectIndex, termIndex)} style={{ ...styles.iconButton, color: COLORS.danger, fontSize: '0.75rem' }}>✖</button>
                                    </div>
                                  </div>

                                  {!term.units || term.units.length === 0 ? (
                                    <div style={{ color: '#9ca3af', fontSize: '0.75rem', padding: '4px' }}>لا توجد وحدات</div>
                                  ) : (
                                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
                                      {term.units.map((unit, unitIndex) => (
                                        <div key={unitIndex} style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', padding: '4px 8px', backgroundColor: '#dbeafe', borderRadius: '4px', fontSize: '0.85rem' }}>
                                          <span>📖 {unit}</span>
                                          <button onClick={() => handleEditUnit(gradeIndex, atramIndex, subjectIndex, termIndex, unitIndex)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: COLORS.primary, padding: '0 2px' }}>✏️</button>
                                          <button onClick={() => handleDeleteUnit(gradeIndex, atramIndex, subjectIndex, termIndex, unitIndex)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: COLORS.danger, padding: '0 2px' }}>✖</button>
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
                  ))
                )}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};


const styles = {
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
  iconButton: { padding: '6px 10px', backgroundColor: 'white', border: '1px solid #d1d5db', borderRadius: '6px', cursor: 'pointer', fontSize: '0.8rem' },
  saveButton: { padding: '8px 12px', backgroundColor: '#10B981', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer', whiteSpace: 'nowrap' as const },
  cancelButton: { padding: '8px 12px', backgroundColor: '#EF4444', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer' },
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
