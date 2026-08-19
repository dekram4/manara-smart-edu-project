import React, { useState, useEffect } from 'react';
import { STORAGE_KEYS, COLORS } from '../../constants';
import { HierarchicalConfig, TeacherInfo, TeacherPermissions } from '../../types';
import { getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import { getTeacherPermissionDetails } from '../../permissions';
import { dedupeHierarchicalConfigs } from '../../utils/academic';
import { readActiveSession } from '../../utils/storage';

interface MyAcademicSettingsProps {
  teacher?: TeacherInfo | null;
}

const MyAcademicSettings: React.FC<MyAcademicSettingsProps> = ({ teacher: teacherProp }) => {
  const [teacherId, setTeacherId] = useState('');
  const [teacherName, setTeacherName] = useState('');
  const [activeTab, setActiveTab] = useState<'my' | 'general'>('my');
  
  // My Settings States
  const [myConfigs, setMyConfigs] = useState<HierarchicalConfig[]>([]);
  const [myGrades, setMyGrades] = useState<string[]>([]);
  
  // General Settings States
  const [generalConfigs, setGeneralConfigs] = useState<HierarchicalConfig[]>([]);
  const [selectedConfig, setSelectedConfig] = useState<HierarchicalConfig | null>(null);
  
  // Form States for My Settings
  const [selectedGrade, setSelectedGrade] = useState('');
  const [newGrade, setNewGrade] = useState('');
  const [selectedAtram, setSelectedAtram] = useState('');
  const [newAtram, setNewAtram] = useState('');
  const [selectedSubject, setSelectedSubject] = useState('');
  const [newSubject, setNewSubject] = useState('');
  const [selectedTerm, setSelectedTerm] = useState('');
  const [newTerm, setNewTerm] = useState('');
  const [newUnit, setNewUnit] = useState('');

  useEffect(() => {
    const teacher = teacherProp || readActiveSession<TeacherInfo>(STORAGE_KEYS.CURRENT_TEACHER);
    setTeacherId(teacher?.id || '');
    setTeacherName(teacher?.name || '');
    loadSettings(teacher?.id);
  }, [teacherProp?.id, teacherProp?.name, teacherProp?.permissionPackageId]);

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
    setMyGrades(Array.from(new Map(
      mySettings.map((c: HierarchicalConfig) => [normalizeScopeValue(c.grade), c.grade]),
    ).values()));
    
    // General Settings: الإعدادات العامة أو الإعدادات الخاصة بهذا المعلم من المشرف
    const generalSettings = allConfigs.filter((c: HierarchicalConfig) =>
      (getRecordTeacherId(c) === 'admin' || !c.createdBy) ||
      (getRecordTeacherId(c) === normalizeScopeValue(tId) && c.createdByAdmin)
    );
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
      atrams: [],
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

  const handleAddAtram = () => {
    if (!newAtram.trim() || !selectedGrade || !teacherId) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const configIndex = allConfigs.findIndex((c: HierarchicalConfig) => 
      c.grade === selectedGrade && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (configIndex === -1) {
      alert('لم يتم العثور على الصف!');
      return;
    }
    
    if (!allConfigs[configIndex].atrams) allConfigs[configIndex].atrams = [];
    
    if (allConfigs[configIndex].atrams.some((a: any) => a.atram === newAtram.trim())) {
      alert('هذا الترم موجود بالفعل!');
      return;
    }
    
    allConfigs[configIndex].atrams.push({
      atram: newAtram.trim(),
      subjects: []
    });
    
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
    
    setNewAtram('');
    loadSettings(teacherId);
    alert('✅ تم إضافة الترم بنجاح');
  };

  const handleAddSubject = () => {
    if (!newSubject.trim() || !selectedGrade || !selectedAtram || !teacherId) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) => 
      c.grade === selectedGrade && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (!config) {
      alert('لم يتم العثور على الصف!');
      return;
    }
    
    const atram = config.atrams?.find((a: any) => a.atram === selectedAtram);
    if (!atram) {
      alert('لم يتم العثور على الترم!');
      return;
    }
    
    if (!atram.subjects) atram.subjects = [];
    
    if (atram.subjects.some((s: any) => s.subject === newSubject.trim())) {
      alert('هذه المادة موجودة بالفعل!');
      return;
    }
    
    atram.subjects.push({
      subject: newSubject.trim(),
      terms: []
    });
    
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
    
    setNewSubject('');
    loadSettings(teacherId);
    alert('✅ تم إضافة المادة بنجاح');
  };

  const handleAddTerm = () => {
    if (!newTerm.trim() || !selectedGrade || !selectedAtram || !selectedSubject || !teacherId) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) => 
      c.grade === selectedGrade && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (!config) return;
    
    const atram = config.atrams?.find((a: any) => a.atram === selectedAtram);
    if (!atram) return;
    
    const subject = atram.subjects?.find((s: any) => s.subject === selectedSubject);
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
    if (!newUnit.trim() || !selectedGrade || !selectedAtram || !selectedSubject || !selectedTerm || !teacherId) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) => 
      c.grade === selectedGrade && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (!config) return;
    
    const atram = config.atrams?.find((a: any) => a.atram === selectedAtram);
    if (!atram) return;
    
    const subject = atram.subjects?.find((s: any) => s.subject === selectedSubject);
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
    if (!confirm('هل أنت متأكد من حذف هذا الصف وجميع محتوياته؟')) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const updatedConfigs = allConfigs.filter((c: HierarchicalConfig) => 
      !(c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId))
    );
    
    localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(updatedConfigs));
    loadSettings(teacherId);
    alert('✅ تم حذف الصف بنجاح');
  };

  const handleDeleteAtram = (gradeName: string, atramName: string) => {
    if (!confirm('هل أنت متأكد من حذف هذا الترم وجميع محتوياته؟')) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) =>
      c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (config && config.atrams) {
      config.atrams = config.atrams.filter((a: any) => a.atram !== atramName);
      localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
      loadSettings(teacherId);
      alert('✅ تم حذف الترم بنجاح');
    }
  };

  const handleDeleteSubject = (gradeName: string, atramName: string, subjectName: string) => {
    if (!confirm('هل أنت متأكد من حذف هذه المادة وجميع محتوياتها؟')) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) =>
      c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (config && config.atrams) {
      const atram = config.atrams.find((a: any) => a.atram === atramName);
      if (atram && atram.subjects) {
        atram.subjects = atram.subjects.filter((s: any) => s.subject !== subjectName);
        localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
        loadSettings(teacherId);
        alert('✅ تم حذف المادة بنجاح');
      }
    }
  };

  const handleDeleteTerm = (gradeName: string, atramName: string, subjectName: string, termName: string) => {
    if (!confirm('هل أنت متأكد من حذف هذا الفصل وجميع وحداته؟')) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) =>
      c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (config && config.atrams) {
      const atram = config.atrams.find((a: any) => a.atram === atramName);
      if (atram && atram.subjects) {
        const subject = atram.subjects.find((s: any) => s.subject === subjectName);
        if (subject && subject.terms) {
          subject.terms = subject.terms.filter((t: any) => t.term !== termName);
          localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
          loadSettings(teacherId);
          alert('✅ تم حذف الفصل بنجاح');
        }
      }
    }
  };

  const handleDeleteUnit = (gradeName: string, atramName: string, subjectName: string, termName: string, unitName: string) => {
    if (!confirm('هل أنت متأكد من حذف هذه الوحدة؟')) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) =>
      c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (config && config.atrams) {
      const atram = config.atrams.find((a: any) => a.atram === atramName);
      if (atram && atram.subjects) {
        const subject = atram.subjects.find((s: any) => s.subject === subjectName);
        if (subject && subject.terms) {
          const term = subject.terms.find((t: any) => t.term === termName);
          if (term && term.units) {
            term.units = term.units.filter((u: string) => u !== unitName);
            localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
            loadSettings(teacherId);
            alert('✅ تم حذف الوحدة بنجاح');
          }
        }
      }
    }
  };

  // ========== EDIT FUNCTIONS ==========
  
  const handleEditGrade = (oldName: string) => {
    const newName = prompt('أدخل الاسم الجديد للصف:', oldName);
    if (!newName || newName.trim() === oldName) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) =>
      c.grade === oldName && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (config) {
      config.grade = newName.trim();
      localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
      loadSettings(teacherId);
      alert('✅ تم تعديل الصف بنجاح');
    }
  };

  const handleEditAtram = (gradeName: string, oldName: string) => {
    const newName = prompt('أدخل الاسم الجديد للترم:', oldName);
    if (!newName || newName.trim() === oldName) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) =>
      c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (config && config.atrams) {
      const atram = config.atrams.find((a: any) => a.atram === oldName);
      if (atram) {
        atram.atram = newName.trim();
        localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
        loadSettings(teacherId);
        alert('✅ تم تعديل الترم بنجاح');
      }
    }
  };

  const handleEditSubject = (gradeName: string, atramName: string, oldName: string) => {
    const newName = prompt('أدخل الاسم الجديد للمادة:', oldName);
    if (!newName || newName.trim() === oldName) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) =>
      c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (config && config.atrams) {
      const atram = config.atrams.find((a: any) => a.atram === atramName);
      if (atram && atram.subjects) {
        const subject = atram.subjects.find((s: any) => s.subject === oldName);
        if (subject) {
          subject.subject = newName.trim();
          localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
          loadSettings(teacherId);
          alert('✅ تم تعديل المادة بنجاح');
        }
      }
    }
  };

  const handleEditTerm = (gradeName: string, atramName: string, subjectName: string, oldName: string) => {
    const newName = prompt('أدخل الاسم الجديد للفصل:', oldName);
    if (!newName || newName.trim() === oldName) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) =>
      c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (config && config.atrams) {
      const atram = config.atrams.find((a: any) => a.atram === atramName);
      if (atram && atram.subjects) {
        const subject = atram.subjects.find((s: any) => s.subject === subjectName);
        if (subject && subject.terms) {
          const term = subject.terms.find((t: any) => t.term === oldName);
          if (term) {
            term.term = newName.trim();
            localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
            loadSettings(teacherId);
            alert('✅ تم تعديل الفصل بنجاح');
          }
        }
      }
    }
  };

  const handleEditUnit = (gradeName: string, atramName: string, subjectName: string, termName: string, oldName: string) => {
    const newName = prompt('أدخل الاسم الجديد للوحدة:', oldName);
    if (!newName || newName.trim() === oldName) return;
    
    const allConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const config = allConfigs.find((c: HierarchicalConfig) =>
      c.grade === gradeName && getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    
    if (config && config.atrams) {
      const atram = config.atrams.find((a: any) => a.atram === atramName);
      if (atram && atram.subjects) {
        const subject = atram.subjects.find((s: any) => s.subject === subjectName);
        if (subject && subject.terms) {
          const term = subject.terms.find((t: any) => t.term === termName);
          if (term && term.units) {
            const unitIndex = term.units.indexOf(oldName);
            if (unitIndex !== -1) {
              term.units[unitIndex] = newName.trim();
              localStorage.setItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS, JSON.stringify(allConfigs));
              loadSettings(teacherId);
              alert('✅ تم تعديل الوحدة بنجاح');
            }
          }
        }
      }
    }
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
  const getAtramsForGrade = () => {
    const config = myConfigs.find(c => c.grade === selectedGrade);
    return config?.atrams || [];
  };

  const getSubjectsForAtram = () => {
    const config = myConfigs.find(c => c.grade === selectedGrade);
    const atram = config?.atrams?.find(a => a.atram === selectedAtram);
    return atram?.subjects || [];
  };

  const getTermsForSubject = () => {
    const config = myConfigs.find(c => c.grade === selectedGrade);
    const atram = config?.atrams?.find(a => a.atram === selectedAtram);
    const subject = atram?.subjects?.find(s => s.subject === selectedSubject);
    return subject?.terms || [];
  };

  const getUnitsForTerm = () => {
    const config = myConfigs.find(c => c.grade === selectedGrade);
    const atram = config?.atrams?.find(a => a.atram === selectedAtram);
    const subject = atram?.subjects?.find(s => s.subject === selectedSubject);
    const term = subject?.terms?.find(t => t.term === selectedTerm);
    return term?.units || [];
  };

  return (
    <div style={styles.container} className="dashboard-page">
      <div style={styles.header}>
        <h1 style={styles.title}>إعداداتي الأكاديمية</h1>
        <p style={styles.subtitle}>إدارة الهيكل الأكاديمي الخاص بي</p>
      </div>

      {/* Tabs */}
      <div style={styles.tabs}>
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

            {/* Add Atram */}
            <div style={styles.formGroup}>
              <label style={styles.label}>2️⃣ اختر صف وأضف ترم</label>
              <select 
                value={selectedGrade}
                onChange={e => {
                  setSelectedGrade(e.target.value);
                  setSelectedAtram('');
                  setSelectedSubject('');
                  setSelectedTerm('');
                }}
                style={{ ...styles.input, marginBottom: '8px' }}
              >
                <option value="">-- اختر الصف --</option>
                {myGrades.map((g, i) => <option key={i} value={g}>{g}</option>)}
              </select>
              <div style={styles.inputGroup}>
                <input
                  type="text"
                  value={newAtram}
                  onChange={e => setNewAtram(e.target.value)}
                  onKeyPress={e => e.key === 'Enter' && !e.currentTarget.disabled && handleAddAtram()}
                  placeholder="مثال: الترم الأول"
                  style={styles.input}
                  disabled={!selectedGrade}
                />
                <button onClick={handleAddAtram} style={styles.addButton} disabled={!selectedGrade}>➕</button>
              </div>
            </div>

            {/* Add Subject */}
            <div style={styles.formGroup}>
              <label style={styles.label}>3️⃣ اختر ترم وأضف مادة</label>
              <select 
                value={selectedAtram}
                onChange={e => {
                  setSelectedAtram(e.target.value);
                  setSelectedSubject('');
                  setSelectedTerm('');
                }}
                style={{ ...styles.input, marginBottom: '8px' }}
                disabled={!selectedGrade}
              >
                <option value="">-- اختر الترم --</option>
                {getAtramsForGrade().map((a, i) => <option key={i} value={a.atram}>{a.atram}</option>)}
              </select>
              <div style={styles.inputGroup}>
                <input
                  type="text"
                  value={newSubject}
                  onChange={e => setNewSubject(e.target.value)}
                  onKeyPress={e => e.key === 'Enter' && !e.currentTarget.disabled && handleAddSubject()}
                  placeholder="مثال: الرياضيات"
                  style={styles.input}
                  disabled={!selectedAtram}
                />
                <button onClick={handleAddSubject} style={styles.addButton} disabled={!selectedAtram}>➕</button>
              </div>
            </div>

            {/* Add Term */}
            <div style={styles.formGroup}>
              <label style={styles.label}>4️⃣ اختر مادة وأضف فصل</label>
              <select 
                value={selectedSubject}
                onChange={e => {
                  setSelectedSubject(e.target.value);
                  setSelectedTerm('');
                }}
                style={{ ...styles.input, marginBottom: '8px' }}
                disabled={!selectedAtram}
              >
                <option value="">-- اختر المادة --</option>
                {getSubjectsForAtram().map((s, i) => <option key={i} value={s.subject}>{s.subject}</option>)}
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
              <label style={styles.label}>5️⃣ اختر فصل وأضف وحدة</label>
              <select 
                value={selectedTerm}
                onChange={e => setSelectedTerm(e.target.value)}
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
          </div>

          {/* Display Section */}
          <div className="teacher-academic-config-list" style={styles.card}>
            <h3 style={styles.cardTitle}>إعداداتي الحالية</h3>
            
            {myConfigs.length === 0 ? (
              <div style={styles.emptyState}>
                <div style={{ fontSize: '3rem', marginBottom: '10px' }}>📚</div>
                <p>لا يوجد إعدادات أكاديمية خاصة بك بعد</p>
                <p style={{ fontSize: '0.9rem', color: '#6b7280' }}>ابدأ بإنشاء هيكلك الأكاديمي أو انسخ من الإعدادات العامة</p>
              </div>
            ) : (
              myConfigs.map((config, idx) => (
                <div key={idx} style={styles.configCard}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
                    <h4 style={styles.configTitle}>🏫 {config.grade}</h4>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        onClick={() => handleEditGrade(config.grade)}
                        style={styles.editButton}
                        title="تعديل الصف"
                      >
                        ✏️
                      </button>
                      <button
                        onClick={() => handleDeleteGrade(config.grade)}
                        style={styles.deleteButton}
                        title="حذف الصف"
                      >
                        🗑️
                      </button>
                    </div>
                  </div>
                  {config.copiedFrom && (
                    <div style={styles.copiedBadge}>
                      📋 منسوخ من: {config.copiedFromName || 'المشرف'}
                    </div>
                  )}
                  {config.atrams && config.atrams.map((atram, aIdx) => (
                    <div key={aIdx} style={styles.atramCard}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                        <strong>📅 {atram.atram}</strong>
                        <div style={{ display: 'flex', gap: '6px' }}>
                          <button
                            onClick={() => handleEditAtram(config.grade, atram.atram)}
                            style={styles.smallEditButton}
                            title="تعديل الترم"
                          >
                            ✏️
                          </button>
                          <button
                            onClick={() => handleDeleteAtram(config.grade, atram.atram)}
                            style={styles.smallDeleteButton}
                            title="حذف الترم"
                          >
                            🗑️
                          </button>
                        </div>
                      </div>
                      {atram.subjects && atram.subjects.map((subject, sIdx) => (
                        <div key={sIdx} style={styles.subjectCard}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                            <span>📖 {subject.subject}</span>
                            <div style={{ display: 'flex', gap: '6px' }}>
                              <button
                                onClick={() => handleEditSubject(config.grade, atram.atram, subject.subject)}
                                style={styles.smallEditButton}
                                title="تعديل المادة"
                              >
                                ✏️
                              </button>
                              <button
                                onClick={() => handleDeleteSubject(config.grade, atram.atram, subject.subject)}
                                style={styles.smallDeleteButton}
                                title="حذف المادة"
                              >
                                🗑️
                              </button>
                            </div>
                          </div>
                          {subject.terms && subject.terms.map((term, tIdx) => (
                            <div key={tIdx} style={styles.termCard}>
                              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                                <span>📚 {term.term}</span>
                                <div style={{ display: 'flex', gap: '6px' }}>
                                  <button
                                    onClick={() => handleEditTerm(config.grade, atram.atram, subject.subject, term.term)}
                                    style={styles.smallEditButton}
                                    title="تعديل الفصل"
                                  >
                                    ✏️
                                  </button>
                                  <button
                                    onClick={() => handleDeleteTerm(config.grade, atram.atram, subject.subject, term.term)}
                                    style={styles.smallDeleteButton}
                                    title="حذف الفصل"
                                  >
                                    🗑️
                                  </button>
                                </div>
                              </div>
                              {term.units && term.units.length > 0 && (
                                <div style={styles.unitsContainer}>
                                  {term.units.map((unit, uIdx) => (
                                    <div key={uIdx} style={styles.unitBadgeWithButtons}>
                                      <span style={styles.unitBadge}>
                                        📄 {unit}
                                      </span>
                                      <button
                                        onClick={() => handleEditUnit(config.grade, atram.atram, subject.subject, term.term, unit)}
                                        style={styles.tinyEditButton}
                                        title="تعديل الوحدة"
                                      >
                                        ✏️
                                      </button>
                                      <button
                                        onClick={() => handleDeleteUnit(config.grade, atram.atram, subject.subject, term.term, unit)}
                                        style={styles.tinyDeleteButton}
                                        title="حذف الوحدة"
                                      >
                                        ❌
                                      </button>
                                    </div>
                                  ))}
                                </div>
                              )}
                            </div>
                          ))}
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
                        <span style={{ backgroundColor: '#fef3c7', color: '#92400e', padding: '2px 8px', borderRadius: '12px', fontSize: '0.75rem' }}>
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
                  
                  {config.atrams && config.atrams.map((atram, aIdx) => (
                    <div key={aIdx} style={styles.atramCard}>
                      <strong>📅 {atram.atram}</strong>
                      {atram.subjects && atram.subjects.map((subject, sIdx) => (
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
                  ))}
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
};

const styles: { [key: string]: React.CSSProperties } = {
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
    gap: '10px',
    marginBottom: '20px',
    borderBottom: '2px solid #e5e7eb'
  },
  tab: {
    padding: '15px 30px',
    fontSize: '1.1rem',
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
  atramCard: {
    marginTop: '10px',
    marginRight: '15px',
    padding: '10px',
    backgroundColor: 'white',
    borderRadius: '8px',
    border: '1px solid #e5e7eb'
  },
  subjectCard: {
    marginTop: '8px',
    marginRight: '15px',
    padding: '8px',
    backgroundColor: '#fef3c7',
    borderRadius: '6px'
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
    borderRadius: '6px',
    cursor: 'pointer',
    transition: 'background-color 0.3s'
  },
  smallDeleteButton: {
    padding: '4px 8px',
    fontSize: '0.8rem',
    backgroundColor: '#ef4444',
    color: 'white',
    border: 'none',
    borderRadius: '6px',
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
