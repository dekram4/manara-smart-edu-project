
import React, { useState, useEffect } from 'react';
import { StudentInfo, ParentInfo, HierarchicalConfig } from '../../types';
import { STORAGE_KEYS, COLORS, DEFAULT_PASSWORD } from '../../constants';
import { ensureHashed } from '../../utils/password';
import { getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import { resetGamificationForStudent } from '../../utils/gamification';
import { getStudentEmoji, STUDENT_GENDER_OPTIONS, StudentGender } from '../../utils/studentAppearance';
import { getPermissionPackages } from '../../permissions';

interface StudentManagementProps {
  onUpdate: () => void;
}

const StudentManagement: React.FC<StudentManagementProps> = ({ onUpdate }) => {
  const [students, setStudents] = useState<StudentInfo[]>([]);
  const [parents, setParents] = useState<ParentInfo[]>([]);
  const [teachers, setTeachers] = useState<any[]>([]);
  const [grades, setGrades] = useState<string[]>([]);
  const [subjects, setSubjects] = useState<string[]>([]);
  const [terms, setTerms] = useState<string[]>([]);
  const [units, setUnits] = useState<string[]>([]);
  const [atrams, setAtrams] = useState<string[]>([]);
  const [gradeConfigs, setGradeConfigs] = useState<any[]>([]);
  const [hierarchicalConfigs, setHierarchicalConfigs] = useState<HierarchicalConfig[]>([]);
  const [availableSubjects, setAvailableSubjects] = useState<string[]>([]);
  const [parentPackages, setParentPackages] = useState<any[]>([]);
  const [studentPackages, setStudentPackages] = useState<any[]>([]);
  
  const [showStudentForm, setShowStudentForm] = useState(false);
  const [showParentForm, setShowParentForm] = useState(false);
  const [editingStudent, setEditingStudent] = useState<StudentInfo | null>(null);
  const [editingParent, setEditingParent] = useState<ParentInfo | null>(null);
  
  const [studentForm, setStudentForm] = useState({
    name: '',
    gender: 'male' as StudentGender,
    username: '',
    password: DEFAULT_PASSWORD,
    parentPhoneNumber: '',
    parentId: '',
    teacherId: '',
    studentIdNumber: '',
    primaryGrade: '',
    gradeEnrollments: [] as { grade: string; enrollments: { id?: string; subject: string; atram: string; term: string; unit: string }[] }[],
    currentGradeForEnrollment: '',
    enrollmentSubject: '',
    enrollmentAtram: '',
    enrollmentTerm: '',
    enrollmentUnit: '',
    canChangeGrade: false,
    permissionPackageId: '',
  });

  const [parentForm, setParentForm] = useState({
    name: '',
    username: '',
    password: DEFAULT_PASSWORD,
    phoneNumber: '',
    teacherId: '',
    permissionPackageId: '',
  });

  const [searchTerm, setSearchTerm] = useState('');
  const [activeTab, setActiveTab] = useState('students' as 'students' | 'parents');
  const [filterTeacherId, setFilterTeacherId] = useState('all');
  const [filterParentId, setFilterParentId] = useState('all');
  const [filterGrade, setFilterGrade] = useState('all');

  useEffect(() => {
    loadData();
    loadAcademicSettings();
  }, []);

  const loadData = () => {
    setStudents(JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]'));
    setParents(JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]'));
    setTeachers(JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]'));
    const packages = getPermissionPackages();
    setParentPackages(packages.filter(pkg => pkg.role === 'parent'));
    setStudentPackages(packages.filter(pkg => pkg.role === 'student'));
  };

  const loadAcademicSettings = () => {
    setGrades(JSON.parse(localStorage.getItem(STORAGE_KEYS.GRADES) || '[]'));
    setSubjects(JSON.parse(localStorage.getItem(STORAGE_KEYS.SUBJECTS) || '[]'));
    setTerms(JSON.parse(localStorage.getItem(STORAGE_KEYS.TERMS) || '[]'));
    setUnits(JSON.parse(localStorage.getItem(STORAGE_KEYS.UNITS) || '[]'));
    setAtrams(JSON.parse(localStorage.getItem(STORAGE_KEYS.ATRAMS) || '[]'));
    const raw = JSON.parse(localStorage.getItem(STORAGE_KEYS.GRADE_CONFIGS) || '[]');
    const normalized = (raw || []).map((cfg: any) => {
      if (cfg.subjects) return cfg;
      const grouped: Record<string, any[]> = {};
      (cfg.enrollments || []).forEach((en: any) => {
        const subj = en.subject || 'غير محدد';
        if (!grouped[subj]) grouped[subj] = [];
        grouped[subj].push({ atram: en.atram || '', term: en.term || '', unit: en.unit || '', id: en.id || Date.now().toString() });
      });
      return { grade: cfg.grade, subjects: Object.keys(grouped).map(sub => ({ subject: sub, enrollments: grouped[sub] })) };
    });
    setGradeConfigs(normalized);
    setHierarchicalConfigs(JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]'));
  };

  const getSubjectsForGrade = (grade: string, teacherId?: string) => {
    if (!grade || !hierarchicalConfigs.length) return subjects;
    const configs = teacherId
      ? hierarchicalConfigs.filter((c: HierarchicalConfig) =>
          getRecordTeacherId(c) === normalizeScopeValue(teacherId)
        )
      : hierarchicalConfigs;
    const cfg = configs.find((c: HierarchicalConfig) => c.grade === grade);
    if (!cfg) return subjects;
    const subs = new Set<string>();
    cfg.atrams?.forEach((a: any) => a.subjects?.forEach((s: any) => { if (s.subject) subs.add(s.subject); }));
    return subs.size > 0 ? Array.from(subs) : subjects;
  };

  

  const handleAddEnrollmentToGrade = () => {
    if (!studentForm.currentGradeForEnrollment || !studentForm.enrollmentSubject) {
      alert('اختر الصف والمادة أولاً');
      return;
    }
    
    const gradeIndex = studentForm.gradeEnrollments.findIndex(g => g.grade === studentForm.currentGradeForEnrollment);
    const newEnrollment = {
      id: Date.now().toString(),
      subject: studentForm.enrollmentSubject,
      atram: studentForm.enrollmentAtram || '',
      term: studentForm.enrollmentTerm || '',
      unit: studentForm.enrollmentUnit || ''
    };
    
    if (gradeIndex >= 0) {
      // Add to existing grade
      const updated = [...studentForm.gradeEnrollments];
      updated[gradeIndex].enrollments.push(newEnrollment);
      setStudentForm({...studentForm, gradeEnrollments: updated, enrollmentSubject: '', enrollmentAtram: '', enrollmentTerm: '', enrollmentUnit: ''});
    } else {
      // Create new grade entry
      const updated = [...studentForm.gradeEnrollments, { grade: studentForm.currentGradeForEnrollment, enrollments: [newEnrollment] }];
      setStudentForm({...studentForm, gradeEnrollments: updated, enrollmentSubject: '', enrollmentAtram: '', enrollmentTerm: '', enrollmentUnit: ''});
    }
  };

  const flattenGradeConfig = (cfg: any) => {
    if (!cfg) return [] as any[];
    if (cfg.subjects) {
      return (cfg.subjects || []).flatMap((s: any) => (s.enrollments || []).map((en: any, idx: number) => ({
        id: en.id || `gcfg-${Date.now()}-${idx}`,
        subject: s.subject,
        atram: en.atram || '',
        term: en.term || '',
        unit: en.unit || ''
      })));
    }
    // legacy
    return (cfg.enrollments || []).map((en: any, idx: number) => ({
      id: en.id || `gcfg-${Date.now()}-${idx}`,
      subject: en.subject,
      atram: en.atram || '',
      term: en.term || '',
      unit: en.unit || ''
    }));
  };

  const handleImportGradeConfig = () => {
    if (!studentForm.currentGradeForEnrollment) { alert('اختر الصف أولاً'); return; }
    const configs = JSON.parse(localStorage.getItem(STORAGE_KEYS.GRADE_CONFIGS) || '[]');
    const found = configs.find((c: any) => c.grade === studentForm.currentGradeForEnrollment);
    const foundEnrollments = flattenGradeConfig(found);
    if (!found || foundEnrollments.length === 0) { alert('لا يوجد تكوينات لهذا الصف'); return; }
    const updated = [...studentForm.gradeEnrollments];
    const existingIdx = updated.findIndex(g => g.grade === studentForm.currentGradeForEnrollment);

    if (existingIdx >= 0) {
      const existing = updated[existingIdx].enrollments || [];
      const map = new Map<string, any>();
      existing.forEach((ex: any) => map.set(`${ex.subject}|${ex.atram}|${ex.term}|${ex.unit}`, ex));
      foundEnrollments.forEach((fe: any) => {
        const key = `${fe.subject}|${fe.atram}|${fe.term}|${fe.unit}`;
        if (!map.has(key)) map.set(key, fe);
      });
      updated[existingIdx].enrollments = Array.from(map.values());
    } else {
      const map = new Map<string, any>();
      foundEnrollments.forEach((fe: any) => map.set(`${fe.subject}|${fe.atram}|${fe.term}|${fe.unit}`, fe));
      updated.push({ grade: studentForm.currentGradeForEnrollment, enrollments: Array.from(map.values()) });
    }

    setStudentForm({ ...studentForm, gradeEnrollments: updated });
    alert('تم استيراد تسجيلات الصف إلى نموذج الطالب (مع إزالة التكرار)');
  };

  const handleRemoveEnrollment = (gradeIdx: number, enrollIdx: number) => {
    const updated = [...studentForm.gradeEnrollments];
    updated[gradeIdx].enrollments.splice(enrollIdx, 1);
    if (updated[gradeIdx].enrollments.length === 0) {
      updated.splice(gradeIdx, 1);
    }
    setStudentForm({...studentForm, gradeEnrollments: updated});
  };

  const handleAddStudent = (e: React.FormEvent) => {
    e.preventDefault();
    if (!studentForm.name || !studentForm.studentIdNumber || !studentForm.primaryGrade) {
      alert('يرجى ملء الاسم والهوية والصف الأساسي');
      return;
    }
    if (students.some(s => s.studentIdNumber === studentForm.studentIdNumber && (!editingStudent || s.id !== editingStudent.id))) {
      alert('رقم الهوية موجود بالفعل!');
      return;
    }

    const username = studentForm.username || `student_${studentForm.studentIdNumber}`;

    let parentPhoneNumber = studentForm.parentPhoneNumber;
    if (studentForm.parentId) {
      const selectedParent = parents.find(p => p.id === studentForm.parentId);
      if (selectedParent) {
        parentPhoneNumber = selectedParent.phoneNumber;
      }
    }

    // if no explicit gradeEnrollments provided, try to copy from grade configs
    let finalGradeEnrollments = studentForm.gradeEnrollments;
    if ((!finalGradeEnrollments || finalGradeEnrollments.length === 0) && studentForm.primaryGrade) {
      try {
        const configs = JSON.parse(localStorage.getItem(STORAGE_KEYS.GRADE_CONFIGS) || '[]');
        const found = configs.find((c: any) => c.grade === studentForm.primaryGrade);
        const flattened = flattenGradeConfig(found);
        if (flattened.length > 0) {
          finalGradeEnrollments = [{ grade: studentForm.primaryGrade, enrollments: flattened }];
        }
      } catch (e) {
        // ignore parsing errors
      }
    }

    const student: StudentInfo = {
      id: editingStudent?.id || Date.now().toString(),
      name: studentForm.name,
      gender: studentForm.gender,
      username: username,
      password: ensureHashed(studentForm.password || editingStudent?.password || DEFAULT_PASSWORD),
      parentPhoneNumber: parentPhoneNumber,
      parentId: studentForm.parentId,
      studentIdNumber: studentForm.studentIdNumber,
      primaryGrade: studentForm.primaryGrade,
      gradeEnrollments: finalGradeEnrollments,
      // keep legacy fields in sync for existing components
      grade: studentForm.primaryGrade,
      subject: studentForm.enrollmentSubject || finalGradeEnrollments?.[0]?.enrollments?.[0]?.subject || '',
      atram: finalGradeEnrollments?.[0]?.enrollments?.[0]?.atram || '',
      term: finalGradeEnrollments?.[0]?.enrollments?.[0]?.term || '',
      unit: finalGradeEnrollments?.[0]?.enrollments?.[0]?.unit || '',
      canChangeGrade: studentForm.canChangeGrade,
      permissionPackageId: studentForm.permissionPackageId || editingStudent?.permissionPackageId || undefined,
      teacherId: studentForm.teacherId || '',
      createdAt: editingStudent?.createdAt || new Date().toISOString(),
      lastActivity: new Date().toISOString(),
      createdBy: studentForm.teacherId || 'admin',
      createdByName: studentForm.teacherId ? teachers.find(t => t.id === studentForm.teacherId)?.name : 'المشرف',
    };

    let updatedStudents = editingStudent ? students.map(s => s.id === editingStudent.id ? student : s) : [...students, student];
    setStudents(updatedStudents);
    localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(updatedStudents));

    if (student) {
      const updatedParents = parents.map(p => {
        const childrenList = (p.children || []).filter((c: any) => c.id !== student.id);
        if (p.id === student.parentId) {
          return { ...p, children: [...childrenList, student] };
        }
        return { ...p, children: childrenList };
      });
      setParents(updatedParents);
      localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(updatedParents));
    }

    resetStudentForm();
    onUpdate();
    alert(editingStudent ? 'تم التحديث بنجاح' : 'تمت إضافة الطالب بنجاح');
  };

  const handleAddParent = (e: React.FormEvent) => {
    e.preventDefault();
    if (!parentForm.name || !parentForm.username || (!editingParent && !parentForm.password)) {
      alert('يرجى ملء الحقول المطلوبة');
      return;
    }
    if (!editingParent && parents.some(p => p.username === parentForm.username)) {
      alert('اسم المستخدم موجود بالفعل');
      return;
    }

    const parent: ParentInfo = {
      id: editingParent?.id || Date.now().toString(),
      ...parentForm,
      password: ensureHashed(parentForm.password || editingParent?.password || DEFAULT_PASSWORD),
      children: editingParent?.children || [],
      mustChangePassword: true,
      createdAt: editingParent?.createdAt || new Date().toISOString(),
      lastLogin: new Date().toISOString(),
      createdBy: parentForm.teacherId || 'admin',
      createdByName: parentForm.teacherId ? teachers.find(t => t.id === parentForm.teacherId)?.name : 'المشرف',
      permissionPackageId: parentForm.permissionPackageId || editingParent?.permissionPackageId || undefined,
    };

    let updatedParents = editingParent ? parents.map(p => p.id === editingParent.id ? parent : p) : [...parents, parent];
    setParents(updatedParents);
    localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(updatedParents));
    resetParentForm();
    onUpdate();
    alert(editingParent ? 'تم التحديث بنجاح' : 'تمت إضافة ولي الأمر بنجاح');
  };

  const resetStudentForm = () => {
    setStudentForm({ 
      name: '', 
      gender: 'male',
      username: '', 
      password: DEFAULT_PASSWORD, 
      parentPhoneNumber: '', 
      parentId: '',
      teacherId: '',
      studentIdNumber: '', 
      primaryGrade: '',
      gradeEnrollments: [],
      currentGradeForEnrollment: '',
      enrollmentSubject: '',
      enrollmentAtram: '',
      enrollmentTerm: '',
      enrollmentUnit: '',
      canChangeGrade: false 
      ,permissionPackageId: ''
    });
    setShowStudentForm(false);
    setEditingStudent(null);
  };

  const resetParentForm = () => {
    setParentForm({ name: '', username: '', password: DEFAULT_PASSWORD, phoneNumber: '', teacherId: '', permissionPackageId: '' });
    setShowParentForm(false);
    setEditingParent(null);
  };

  const quickAddAccount = (type: 'student' | 'parent') => {
    if (type === 'student') {
      setShowStudentForm(true);
      setShowParentForm(false);
      setActiveTab('students');
    } else {
      setShowParentForm(true);
      setShowStudentForm(false);
      setActiveTab('parents');
    }
  };

  const handleDeleteStudent = (id: string) => {
    if (!confirm('حذف الطالب؟')) return;
    const updated = students.filter(s => s.id !== id);
    setStudents(updated);
    localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(updated));
    onUpdate();
  };

  const handleDeleteParent = (id: string) => {
    if (!confirm('حذف ولي الأمر؟')) return;
    const updated = parents.filter(p => p.id !== id);
    setParents(updated);
    localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(updated));
    onUpdate();
  };

  const handleResetStudentCounter = (student: StudentInfo) => {
    const studentIdentity = student.studentIdNumber || student.nationalId || student.username || student.id;
    if (!confirm(`تأكيد التصفير:\nالطالب: ${student.name}\nالهوية: ${studentIdentity}\n\nهل تريد المتابعة؟`)) return;
    resetGamificationForStudent(student);
    alert(`تم تصفير عداد الطالب ${student.name} (هوية: ${studentIdentity}) بنجاح`);
  };

  const handleEditParent = (p: ParentInfo) => {
    setParentForm({
      name: p.name,
      username: p.username,
      password: '',
      phoneNumber: p.phoneNumber,
      teacherId: p.createdBy || '',
      permissionPackageId: p.permissionPackageId || '',
    });
    setEditingParent(p);
    setShowParentForm(true);
    setActiveTab('parents');
  };

  const handleEditStudent = (s: StudentInfo) => {
    setStudentForm({
      name: s.name,
      gender: s.gender || 'male',
      username: s.username || '',
      password: '',
      parentPhoneNumber: s.parentPhoneNumber,
      parentId: s.parentId || '',
      teacherId: s.teacherId ?? s.createdBy ?? '',
      studentIdNumber: s.studentIdNumber || '',
      primaryGrade: s.primaryGrade,
      gradeEnrollments: s.gradeEnrollments || [],
      currentGradeForEnrollment: '',
      enrollmentSubject: '',
      enrollmentAtram: '',
      enrollmentTerm: '',
      enrollmentUnit: '',
      canChangeGrade: s.canChangeGrade || false,
      permissionPackageId: s.permissionPackageId || '',
    });
    setEditingStudent(s);
    setShowStudentForm(true);
    setActiveTab('students');
  };

  const filteredStudents = students.filter(s => {
    // البحث النصي
    const matchesSearch = s.name.includes(searchTerm) || 
      s.username?.includes(searchTerm) ||
      s.studentIdNumber?.includes(searchTerm);
    
    // التصفية بحسب المعلم
    const matchesTeacher = filterTeacherId === 'all' ||
      getRecordTeacherId(s) === normalizeScopeValue(filterTeacherId);
    
    // التصفية بحسب ولي الأمر
    const matchesParent = filterParentId === 'all' || s.parentId === filterParentId;
    
    // التصفية بحسب الصف
    const matchesGrade = filterGrade === 'all' || s.primaryGrade === filterGrade;
    
    return matchesSearch && matchesTeacher && matchesParent && matchesGrade;
  });

  const filteredParents = parents.filter(p => {
    // البحث النصي
    const matchesSearch = p.name.includes(searchTerm) || 
      p.username.includes(searchTerm) || 
      p.phoneNumber?.includes(searchTerm) ||
      p.id?.includes(searchTerm);
    
    // التصفية بحسب المعلم
    const matchesTeacher = filterTeacherId === 'all' ||
      normalizeScopeValue(p.createdBy) === normalizeScopeValue(filterTeacherId);
    
    return matchesSearch && matchesTeacher;
  });

  return (
    <div className="space-y-8 animate-fadeIn">
      <div style={styles.header}>
        <h1 style={styles.title}>إدارة الحسابات</h1>
        <p style={styles.subtitle}>إدارة حسابات الطلاب وأولياء الأمور</p>
      </div>

      <div style={styles.quickAddContainer}>
        <div style={styles.quickAddHeader}>
          <h3 style={styles.quickAddTitle}>إضافة حساب جديد</h3>
          <div style={styles.quickAddButtons}>
            <button onClick={() => quickAddAccount('student')} style={styles.quickAddButton}>👨‍🎓 إضافة طالب</button>
            <button onClick={() => quickAddAccount('parent')} style={{...styles.quickAddButton, backgroundColor: COLORS.secondary}}>👨‍👦 إضافة ولي أمر</button>
          </div>
        </div>
        <div style={styles.quickAddStats}>
          <div style={styles.statCard}>
             <div style={styles.statIcon}>👨‍🎓</div>
             <div style={styles.statContent}><div style={styles.statValue}>{students.length}</div><div style={styles.statLabel}>طالب</div></div>
          </div>
          <div style={styles.statCard}>
             <div style={styles.statIcon}>👨‍👦</div>
             <div style={styles.statContent}><div style={styles.statValue}>{parents.length}</div><div style={styles.statLabel}>ولي أمر</div></div>
          </div>
        </div>
      </div>

      {showStudentForm && (
        <div style={styles.formCard}>
          <h3 style={styles.formTitle}>{editingStudent ? '✏️ تعديل الطالب' : '➕ إضافة طالب جديد'}</h3>
          <form onSubmit={handleAddStudent} style={styles.form}>
            <div style={styles.formGrid}>
               <div style={styles.formGroup}><label style={styles.label}>الاسم *</label><input type="text" value={studentForm.name} onChange={e => setStudentForm({...studentForm, name: e.target.value})} style={styles.input} required /></div>
                <div style={styles.formGroup}><label style={styles.label}>اسم المستخدم</label><input type="text" value={studentForm.username} onChange={e => setStudentForm({...studentForm, username: e.target.value})} style={styles.input} placeholder="سيتم توليده تلقائياً" /></div>
                <div style={styles.formGroup}>
                  <label style={styles.label}>جنس الطالب *</label>
                  <select value={studentForm.gender} onChange={e => setStudentForm({...studentForm, gender: e.target.value as StudentGender})} style={styles.select} required>
                    {STUDENT_GENDER_OPTIONS.map(option => <option key={option.value} value={option.value}>{option.emoji} {option.label}</option>)}
                  </select>
                </div>
               <div style={styles.formGroup}><label style={styles.label}>رقم الهوية *</label><input type="text" value={studentForm.studentIdNumber} onChange={e => setStudentForm({...studentForm, studentIdNumber: e.target.value})} style={styles.input} required /></div>
               <div style={styles.formGroup}><label style={styles.label}>كلمة المرور {editingStudent ? '' : '*'}</label><input type="text" value={studentForm.password} onChange={e => setStudentForm({...studentForm, password: e.target.value})} style={styles.input} placeholder={editingStudent ? 'اتركه فارغاً للإبقاء على الحالية' : ''} required={!editingStudent} /></div>
               <div style={styles.formGroup}>
                  <label style={styles.label}>ولي الأمر</label>
                  <select value={studentForm.parentId} onChange={e => setStudentForm({...studentForm, parentId: e.target.value})} style={styles.select}>
                    <option value="">اختر ولي أمر</option>
                    {parents.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
                  </select>
               </div>
               <div style={styles.formGroup}>
                  <label style={styles.label}>👨‍🏫 المعلم *</label>
                  <select value={studentForm.teacherId} onChange={e => setStudentForm({...studentForm, teacherId: e.target.value})} style={styles.select} required>
                    <option value="">اختر المعلم</option>
                    {teachers.map((t) => <option key={t.id} value={t.id}>👨‍🏫 {t.name} - {t.subject || 'معلم'}</option>)}
                  </select>
               </div>
               <div style={styles.formGroup}>
                  <label style={styles.label}>الصف الأساسي *</label>
                  <select value={studentForm.primaryGrade} onChange={e => { setStudentForm({...studentForm, primaryGrade: e.target.value}); const subs = getSubjectsForGrade(e.target.value, studentForm.teacherId); setAvailableSubjects(subs); }} style={styles.select} required>
                    <option value="">اختر الصف الأساسي</option>
                    {grades.map((g,i) => <option key={i} value={g}>{g}</option>)}
                  </select>
               </div>
               <div style={styles.formGroup}>
                  <label style={styles.label}>المادة *</label>
                  <select value={studentForm.enrollmentSubject} onChange={e => setStudentForm({...studentForm, enrollmentSubject: e.target.value})} style={styles.select} required>
                    <option value="">اختر المادة</option>
                    {availableSubjects.map((s, i) => <option key={i} value={s}>{s}</option>)}
                  </select>
               </div>
                <div style={styles.formGroup}>
                    <label style={styles.label}>🔐 إدارة صلاحيات الطالب</label>
                   <select value={studentForm.permissionPackageId} onChange={e => setStudentForm({...studentForm, permissionPackageId: e.target.value})} style={styles.select}>
                     <option value="">الصلاحيات العامة الحالية</option>
                     {studentPackages.map(pkg => <option key={pkg.id} value={pkg.id}>{pkg.name}</option>)}
                   </select>
                </div>
            </div>

            <div style={styles.formActions}>
               <button type="button" onClick={resetStudentForm} style={styles.cancelButton}>إلغاء</button>
               <button type="submit" style={styles.submitButton}>حفظ البيانات</button>
            </div>
          </form>
        </div>
      )}

      {showParentForm && (
        <div style={styles.formCard}>
           <h3 style={styles.formTitle}>{editingParent ? '✏️ تعديل ولي أمر' : '➕ إضافة ولي أمر جديد'}</h3>
           <form onSubmit={handleAddParent} style={styles.form}>
             <div style={styles.formGrid}>
               <div style={styles.formGroup}><label style={styles.label}>اسم ولي الأمر *</label><input type="text" value={parentForm.name} onChange={e => setParentForm({...parentForm, name: e.target.value})} style={styles.input} required /></div>
               <div style={styles.formGroup}><label style={styles.label}>اسم المستخدم *</label><input type="text" value={parentForm.username} onChange={e => setParentForm({...parentForm, username: e.target.value})} style={styles.input} required /></div>
               <div style={styles.formGroup}><label style={styles.label}>كلمة المرور {editingParent ? '' : '*'}</label><input type="text" value={parentForm.password} onChange={e => setParentForm({...parentForm, password: e.target.value})} style={styles.input} placeholder={editingParent ? 'اتركه فارغاً للإبقاء على الحالية' : ''} required={!editingParent} /></div>
               <div style={styles.formGroup}><label style={styles.label}>رقم الجوال</label><input type="text" value={parentForm.phoneNumber} onChange={e => setParentForm({...parentForm, phoneNumber: e.target.value})} style={styles.input} /></div>
               <div style={styles.formGroup}>
                  <label style={styles.label}>👨‍🏫 المعلم *</label>
                  <select value={parentForm.teacherId} onChange={e => setParentForm({...parentForm, teacherId: e.target.value})} style={styles.select} required>
                    <option value="">اختر المعلم</option>
                    {teachers.map((t) => <option key={t.id} value={t.id}>👨‍🏫 {t.name} - {t.subject || 'معلم'}</option>)}
                  </select>
               </div>
                <div style={styles.formGroup}>
                    <label style={styles.label}>🔐 إدارة صلاحيات ولي الأمر</label>
                   <select value={parentForm.permissionPackageId} onChange={e => setParentForm({...parentForm, permissionPackageId: e.target.value})} style={styles.select}>
                     <option value="">الصلاحيات العامة الحالية</option>
                     {parentPackages.map(pkg => <option key={pkg.id} value={pkg.id}>{pkg.name}</option>)}
                   </select>
                </div>
             </div>
             <div style={styles.formActions}>
                <button type="button" onClick={resetParentForm} style={styles.cancelButton}>إلغاء</button>
                <button type="submit" style={styles.submitButton}>حفظ البيانات</button>
             </div>
           </form>
        </div>
      )}

      <div style={styles.controlsCard}>
        <div style={styles.controlsHeader}>
          <div style={styles.searchContainer}>
            <input 
              type="text" 
              value={searchTerm} 
              onChange={e => setSearchTerm(e.target.value)} 
              style={styles.searchInput} 
              placeholder="بحث عن اسم أو هوية..." 
            />
          </div>
          <div style={styles.tabButtons}>
            <button onClick={() => setActiveTab('students')} style={{...styles.tabButton, backgroundColor: activeTab === 'students' ? COLORS.primary : '#f3f4f6', color: activeTab === 'students' ? 'white' : COLORS.dark }}>الطلاب</button>
            <button onClick={() => setActiveTab('parents')} style={{...styles.tabButton, backgroundColor: activeTab === 'parents' ? COLORS.primary : '#f3f4f6', color: activeTab === 'parents' ? 'white' : COLORS.dark }}>أولياء الأمور</button>
          </div>
        </div>
        
        {/* خيارات التصفية */}
        <div style={{display: 'flex', gap: '15px', marginTop: '20px', flexWrap: 'wrap'}}>
          <div style={{flex: '1', minWidth: '200px'}}>
            <label style={{display: 'block', marginBottom: '5px', fontSize: '14px', fontWeight: 'bold', color: '#475569'}}>👨‍🏫 تصفية بحسب المعلم</label>
            <select 
              value={filterTeacherId} 
              onChange={e => setFilterTeacherId(e.target.value)}
              style={{...styles.select, width: '100%'}}
            >
              <option value="all">كل المعلمين</option>
              {teachers.map((t) => (
                <option key={t.id} value={t.id}>{t.name} - {t.subject || 'معلم'}</option>
              ))}
            </select>
          </div>
          
          {activeTab === 'students' && (
            <>
              <div style={{flex: '1', minWidth: '200px'}}>
                <label style={{display: 'block', marginBottom: '5px', fontSize: '14px', fontWeight: 'bold', color: '#475569'}}>👨‍👧‍👦 تصفية بحسب ولي الأمر</label>
                <select 
                  value={filterParentId} 
                  onChange={e => setFilterParentId(e.target.value)}
                  style={{...styles.select, width: '100%'}}
                >
                  <option value="all">كل أولياء الأمور</option>
                  {parents.map((p) => (
                    <option key={p.id} value={p.id}>{p.name} - {p.phoneNumber}</option>
                  ))}
                </select>
              </div>
              
              <div style={{flex: '1', minWidth: '200px'}}>
                <label style={{display: 'block', marginBottom: '5px', fontSize: '14px', fontWeight: 'bold', color: '#475569'}}>📚 تصفية بحسب الصف</label>
                <select 
                  value={filterGrade} 
                  onChange={e => setFilterGrade(e.target.value)}
                  style={{...styles.select, width: '100%'}}
                >
                  <option value="all">كل الصفوف</option>
                  {grades.map((g) => (
                    <option key={g} value={g}>{g}</option>
                  ))}
                </select>
              </div>
            </>
          )}
        </div>
      </div>

      <div className="bg-white rounded-3xl border shadow-sm overflow-x-auto">
         <table className="w-full min-w-[900px] text-right">
           <thead className="bg-purple-50 border-b">
              <tr>
                <th className="p-4">الاسم</th>
                <th className="p-4">اسم المستخدم</th>
                <th className="p-4">رقم الهوية</th>
                <th className="p-4">{activeTab === 'students' ? 'الصف الأساسي' : 'رقم الجوال'}</th>
                {activeTab === 'students' && <th className="p-4">👨‍👧‍👦 ولي الأمر</th>}
                {activeTab === 'students' && <th className="p-4">👨‍🏫 المعلم</th>}
                {activeTab === 'parents' && <th className="p-4">👨‍🏫 المعلم</th>}
                {activeTab === 'parents' && <th className="p-4">الطلاب المرتبطين</th>}
                <th className="p-4">الإجراءات</th>
              </tr>
           </thead>
           <tbody>
              {(activeTab === 'students' ? filteredStudents : filteredParents).map((item: any) => (
                <tr key={item.id} className="border-b hover:bg-purple-50 transition-colors">
                  <td className="p-4 font-bold text-purple-800">{item.name}</td>
                  <td className="p-4 text-purple-600">{item.username || '-'}</td>
                  <td className="p-4 text-purple-600 font-mono">{activeTab === 'students' ? (item.studentIdNumber || '-') : (item.id || '-')}</td>
                  <td className="p-4 text-purple-600">{activeTab === 'students' ? (item.primaryGrade || item.grade || '-') : (item.phoneNumber || '-')}</td>
                  {activeTab === 'students' && (
                    <td className="p-4">
                      {(() => {
                        const parent = parents.find(p => p.id === item.parentId || p.phoneNumber === item.parentPhoneNumber);
                        return parent ? (
                          <span className="inline-flex items-center gap-1 bg-green-50 text-green-700 px-3 py-1 rounded-full text-xs font-bold">
                            👨‍👧‍👦 {parent.name}
                          </span>
                        ) : (
                          <span className="text-purple-400 text-sm italic">غير مرتبط</span>
                        );
                      })()}
                    </td>
                  )}
                  {activeTab === 'students' && (
                    <td className="p-4">
                      {(() => {
                        const teacher = teachers.find(t => t.id === item.createdBy);
                        return teacher ? (
                          <span className="inline-flex items-center gap-1 bg-gradient-to-r from-purple-500 to-purple-500 text-white px-3 py-1 rounded-full text-xs font-bold">
                            👨‍🏫 {teacher.name}
                          </span>
                        ) : item.createdBy ? (
                          <span className="inline-flex items-center gap-1 bg-purple-100 text-purple-600 px-3 py-1 rounded-full text-xs font-bold">
                            👨‍🏫 {item.createdByName || item.createdBy}
                          </span>
                        ) : (
                          <span className="text-purple-400 text-sm italic">غير محدد</span>
                        );
                      })()}
                    </td>
                  )}
                  {activeTab === 'parents' && (
                    <td className="p-4">
                      {(() => {
                        const teacher = teachers.find(t => t.id === item.createdBy);
                        return teacher ? (
                          <span className="inline-flex items-center gap-1 bg-gradient-to-r from-purple-500 to-purple-500 text-white px-3 py-1 rounded-full text-xs font-bold">
                            👨‍🏫 {teacher.name}
                          </span>
                        ) : item.createdBy ? (
                          <span className="inline-flex items-center gap-1 bg-purple-100 text-purple-600 px-3 py-1 rounded-full text-xs font-bold">
                            👨‍🏫 {item.createdByName || item.createdBy}
                          </span>
                        ) : (
                          <span className="text-purple-400 text-sm italic">غير محدد</span>
                        );
                      })()}
                    </td>
                  )}
                  {activeTab === 'parents' && (
                    <td className="p-4">
                      {students.filter(s => {
                        // Priority: Use parentId if exists, fallback to phoneNumber match only if parentId is not set
                        if (s.parentId && s.parentId.trim() !== '') {
                          return s.parentId === item.id;
                        }
                        // If no parentId, match by phone number (legacy support)
                        return s.parentPhoneNumber === item.phoneNumber;
                      }).length > 0 ? (
                        <div className="flex flex-wrap gap-2">
                          {students.filter(s => {
                            // Priority: Use parentId if exists, fallback to phoneNumber match only if parentId is not set
                            if (s.parentId && s.parentId.trim() !== '') {
                              return s.parentId === item.id;
                            }
                            // If no parentId, match by phone number (legacy support)
                            return s.parentPhoneNumber === item.phoneNumber;
                          }).map(student => (
                            <span key={student.id} className="inline-flex items-center gap-1 bg-purple-50 text-purple-700 px-3 py-1 rounded-full text-xs font-bold">
                             {getStudentEmoji(student)} {student.name}
                            </span>
                          ))}
                        </div>
                      ) : (
                        <span className="text-purple-400 text-sm italic">لا يوجد طلاب مرتبطين</span>
                      )}
                    </td>
                  )}
                  <td className="p-4 space-x-2 space-x-reverse">
                    {activeTab === 'students' && (
                      <button onClick={() => handleResetStudentCounter(item as StudentInfo)} className="bg-indigo-50 text-indigo-600 px-3 py-1 rounded-lg font-bold text-xs">تصفير العداد</button>
                    )}
                    <button onClick={() => activeTab === 'students' ? handleEditStudent(item) : handleEditParent(item)} className="bg-yellow-50 text-yellow-600 px-3 py-1 rounded-lg font-bold text-xs">تعديل</button>
                    <button onClick={() => activeTab === 'students' ? handleDeleteStudent(item.id) : handleDeleteParent(item.id)} className="bg-red-50 text-red-600 px-3 py-1 rounded-lg font-bold text-xs">حذف</button>
                  </td>
                </tr>
              ))}
           </tbody>
         </table>
         {(activeTab === 'students' ? filteredStudents : filteredParents).length === 0 && (
           <div className="p-20 text-center text-purple-400 font-bold italic">لا توجد نتائج بحث</div>
         )}
      </div>
    </div>
  );
};

  
const styles = {
  header: { marginBottom: '20px' },
  title: { fontSize: '2rem', fontWeight: 'bold', color: '#111827' },
  subtitle: { color: '#6B7280' },
  quickAddContainer: { backgroundColor: 'white', borderRadius: '12px', padding: '25px', marginBottom: '30px', boxShadow: '0 2px 8px rgba(0,0,0,0.05)', border: '1px solid #e5e7eb' },
  quickAddHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' },
  quickAddTitle: { fontSize: '1.2rem', fontWeight: 'bold' },
  quickAddButtons: { display: 'flex', gap: '15px' },
  quickAddButton: { padding: '10px 20px', backgroundColor: COLORS.primary, color: 'white', border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: 'bold', display: 'flex', alignItems: 'center', gap: '8px' },
  quickAddStats: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '15px' },
  statCard: { display: 'flex', alignItems: 'center', gap: '15px', padding: '15px', backgroundColor: '#f8fafc', borderRadius: '12px', border: '1px solid #e5e7eb' },
  statIcon: { fontSize: '1.5rem' },
  statContent: { flex: 1 },
  statValue: { fontSize: '1.5rem', fontWeight: 'bold', color: '#111827' },
  statLabel: { fontSize: '0.8rem', color: '#6B7280' },
  formCard: { backgroundColor: 'white', borderRadius: '20px', padding: '30px', marginBottom: '30px', boxShadow: '0 10px 25px rgba(0,0,0,0.05)', border: '1px solid #e5e7eb' },
  formTitle: { marginBottom: '25px', fontSize: '1.4rem', fontWeight: 'bold', color: '#111827' },
  form: { display: 'flex', flexDirection: 'column' as const, gap: '20px' },
  formGrid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '20px' },
  formGroup: { display: 'flex', flexDirection: 'column' as const, gap: '8px' },
  label: { fontWeight: '600', fontSize: '0.9rem', color: '#374151' },
  input: { padding: '12px 16px', border: '2px solid #e5e7eb', borderRadius: '10px', outline: 'none', transition: 'border-color 0.2s' },
  select: { padding: '12px 16px', border: '2px solid #e5e7eb', borderRadius: '10px', backgroundColor: 'white', outline: 'none' },
  helpText: { fontSize: '0.75rem', color: '#9CA3AF' },
  checkboxGroup: { padding: '15px', backgroundColor: '#f9fafb', borderRadius: '12px', border: '1px solid #e5e7eb' },
  checkboxLabel: { display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer', fontSize: '0.9rem', fontWeight: 'bold' },
  checkbox: { width: '18px', height: '18px' },
  formActions: { display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '10px' },
  submitButton: { padding: '12px 30px', backgroundColor: COLORS.primary, color: 'white', border: 'none', borderRadius: '10px', cursor: 'pointer', fontWeight: 'bold' },
  cancelButton: { padding: '12px 30px', backgroundColor: '#f3f4f6', color: '#4B5563', border: 'none', borderRadius: '10px', cursor: 'pointer', fontWeight: 'bold' },
  controlsCard: { backgroundColor: 'white', borderRadius: '12px', padding: '20px', marginBottom: '20px', border: '1px solid #e5e7eb' },
  controlsHeader: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '20px' },
  searchContainer: { flex: 1 },
  searchInput: { width: '100%', padding: '12px 16px', border: '2px solid #e5e7eb', borderRadius: '10px', outline: 'none' },
  tabButtons: { display: 'flex', gap: '8px' },
  tabButton: { padding: '10px 20px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: 'bold', fontSize: '0.9rem' },
};

export default StudentManagement;
