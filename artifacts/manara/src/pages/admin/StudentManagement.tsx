
import { saveStudentConfirmed } from '../../db/confirmedSave';
import { gradesForOwner, readHierarchicalConfigs, subjectsForOwner, subjectsOfConfig } from '../../utils/academic';
import { markStudentDeleted } from '../../utils/students';
import React, { useState, useEffect, useMemo } from 'react';
import { StudentInfo, ParentInfo, HierarchicalConfig } from '../../types';
import { STORAGE_KEYS, COLORS, DEFAULT_PASSWORD } from '../../constants';
import { ensureHashed } from '../../utils/password';
import { getParentChildren, getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import { resetGamificationForStudent } from '../../utils/gamification';
import { getStudentEmoji, STUDENT_GENDER_OPTIONS, StudentGender } from '../../utils/studentAppearance';
import { getPermissionPackages } from '../../permissions';
import { useRevealForm } from '../../hooks/useRevealForm';
import { GraduationCap, Link2Off, Pencil, RotateCcw, Search, Trash2, UserPlus, UsersRound, X } from 'lucide-react';
import { ART, Badge, EmptyState, PageHeader, Panel, StatCard, studentArt } from '../../components/portal/PortalUI';

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
  const [gradeConfigs, setGradeConfigs] = useState<any[]>([]);
  const [hierarchicalConfigs, setHierarchicalConfigs] = useState<HierarchicalConfig[]>([]);
  const [parentPackages, setParentPackages] = useState<any[]>([]);
  const [studentPackages, setStudentPackages] = useState<any[]>([]);
  
  const [showStudentForm, setShowStudentForm] = useState(false);
  const [showParentForm, setShowParentForm] = useState(false);
  // ‏«تعديل» يُظهر النموذجَ أعلى الصفحة ويضع المؤشّرَ فيه — انظر hooks/useRevealForm.
  const studentFormView = useRevealForm();
  const parentFormView = useRevealForm();
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
    gradeEnrollments: [] as { grade: string; enrollments: { id?: string; subject: string; term: string; unit: string }[] }[],
    currentGradeForEnrollment: '',
    /// المواد المسموح بها. فارغة = جميع مواد المعلم.
    assignedSubjects: [] as string[],
    canChangeGrade: false,
    permissionPackageId: '',
  });

  // مواد الصف المختار، مشتقّة من حالة النموذج لا من حدث القائمة.
  //
  // كانت تُملأ داخل `onChange` الخاص بالصف وحده، فتبقى فارغة عند فتح
  // النافذة لطالب مسجَّل، وعند تغيير المعلم بعد اختيار الصف — وحقل
  // المادة إجباري، فيمتنع الحفظ كلّه.
  const availableSubjects = useMemo(
    () => subjectsForOwner(studentForm.teacherId, studentForm.primaryGrade),
    [studentForm.teacherId, studentForm.primaryGrade, hierarchicalConfigs],
  );

  /// المادة التي يُفتح عليها حساب الطالب.
  ///
  /// كان يختارها المشرف من قائمة مفردة إلى جانب مربّعات المواد المتاحة،
  /// فحقلان يقولان الشيء نفسه ويجوز أن يتناقضا: مادة مفردة ليست من
  /// المواد المؤشَّرة. صارت تُشتقّ من المربّعات وحدها.
  const primarySubject = studentForm.assignedSubjects[0] || availableSubjects[0] || '';

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
    // من الشجرة الأكاديمية مباشرةً. القائمة المسطّحة تبقى احتياطاً وحدها:
    // هي نسخة جانبية لا تُكتب إلا حين يفتح المشرف شاشة الإعدادات، فصفوف
    // المعلم الذي بناها في شاشته الخاصة كانت تغيب عن هذا النموذج.
    const fromTree = gradesForOwner();
    setGrades(
      fromTree.length > 0
        ? fromTree
        : JSON.parse(localStorage.getItem(STORAGE_KEYS.GRADES) || '[]'),
    );
    setSubjects(JSON.parse(localStorage.getItem(STORAGE_KEYS.SUBJECTS) || '[]'));
    setTerms(JSON.parse(localStorage.getItem(STORAGE_KEYS.TERMS) || '[]'));
    setUnits(JSON.parse(localStorage.getItem(STORAGE_KEYS.UNITS) || '[]'));
    const raw = JSON.parse(localStorage.getItem(STORAGE_KEYS.GRADE_CONFIGS) || '[]');
    const normalized = (raw || []).map((cfg: any) => {
      if (cfg.subjects) return cfg;
      const grouped: Record<string, any[]> = {};
      (cfg.enrollments || []).forEach((en: any) => {
        const subj = en.subject || 'غير محدد';
        if (!grouped[subj]) grouped[subj] = [];
        grouped[subj].push({ term: en.term || '', unit: en.unit || '', id: en.id || Date.now().toString() });
      });
      return { grade: cfg.grade, subjects: Object.keys(grouped).map(sub => ({ subject: sub, enrollments: grouped[sub] })) };
    });
    setGradeConfigs(normalized);
    // مدموجة ومسطّحة عند القراءة: نفس ما تراه شاشة الإعدادات.
    setHierarchicalConfigs(readHierarchicalConfigs());
  };

  const getSubjectsForGrade = (grade: string, teacherId?: string) => {
    if (!grade) return subjects;
    const fromTree = subjectsForOwner(teacherId, grade);
    return fromTree.length > 0 ? fromTree : subjects;
  };

  

  const flattenGradeConfig = (cfg: any) => {
    if (!cfg) return [] as any[];
    if (cfg.subjects) {
      return (cfg.subjects || []).flatMap((s: any) => (s.enrollments || []).map((en: any, idx: number) => ({
        id: en.id || `gcfg-${Date.now()}-${idx}`,
        subject: s.subject,
        term: en.term || '',
        unit: en.unit || ''
      })));
    }
    // legacy
    return (cfg.enrollments || []).map((en: any, idx: number) => ({
      id: en.id || `gcfg-${Date.now()}-${idx}`,
      subject: en.subject,
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
      existing.forEach((ex: any) => map.set(`${ex.subject}|${ex.term}|${ex.unit}`, ex));
      foundEnrollments.forEach((fe: any) => {
        const key = `${fe.subject}|${fe.term}|${fe.unit}`;
        if (!map.has(key)) map.set(key, fe);
      });
      updated[existingIdx].enrollments = Array.from(map.values());
    } else {
      const map = new Map<string, any>();
      foundEnrollments.forEach((fe: any) => map.set(`${fe.subject}|${fe.term}|${fe.unit}`, fe));
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

  const handleAddStudent = async (e: React.FormEvent) => {
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
    let resolvedParentId = studentForm.parentId;
    if (studentForm.parentId) {
      const selectedParent = parents.find(p => p.id === studentForm.parentId);
      if (selectedParent) {
        parentPhoneNumber = selectedParent.phoneNumber;
      }
    } else if (normalizeScopeValue(parentPhoneNumber)) {
      // أُدخل رقم جوال بلا اختيار وليّ من القائمة. الربط صار عبر `parentId`
      // وحده، فطالب بلا معرّف ينقطع عن وليّه. يُحسم الرقم هنا حين يطابق وليّاً
      // واحداً لا غير — وعند التعدّد لا يُخمَّن، وهو نفس مبدأ حملة الترحيل.
      const matches = parents.filter(
        p => normalizeScopeValue(p.phoneNumber) === normalizeScopeValue(parentPhoneNumber),
      );
      if (matches.length === 1) {
        resolvedParentId = matches[0].id;
      } else if (matches.length > 1) {
        alert(
          'رقم الجوال هذا مسجّل لأكثر من وليّ أمر. اختر وليّ الأمر من القائمة ' +
            'لتحديد الرابط بدقة.',
        );
        return;
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
      parentId: resolvedParentId,
      studentIdNumber: studentForm.studentIdNumber,
      primaryGrade: studentForm.primaryGrade,
      gradeEnrollments: finalGradeEnrollments,
      // keep legacy fields in sync for existing components
      grade: studentForm.primaryGrade,
      // ‏مادة الطالب الافتراضية: أولى المواد المسندة إليه، أو أولى مواد
      // ‏صفّه حين تكون كلها متاحة له. حقلها اختفى من النموذج، ولم يختفِ
      // ‏الحقل نفسه من السجلّ: تطبيق الطالب يفتح عليها شاشة المسار
      // ‏ويسندها إلى نتائج الاختبارات حين لا يكون قد اختار مساراً بعد.
      subject: primarySubject || finalGradeEnrollments?.[0]?.enrollments?.[0]?.subject || '',
      assignedSubjects: studentForm.assignedSubjects,
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

    // الحفظ ليس كاملاً حتى يصل إلى قاعدة البيانات.
    //
    // المزامنة ترسل من تلقاء نفسها، وإن فشل الإرسال دخل الطابور بصمت
    // وظنّ المستخدم أن الصف الجديد محفوظ — وهذا ما جعل السكربت يقرأ الصفّ
    // القديم. النافذة تُغلق عند نجاح الكتابة، وتبقى مفتوحة مع سبب الفشل.
    const outcome = await saveStudentConfirmed(student);
    if (outcome.ok === false) {
      alert(`لم يُحفظ في قاعدة البيانات: ${outcome.reason}
التعديل محفوظ في هذا المتصفّح وسيُعاد إرساله.`);
      onUpdate();
      return;
    }

    resetStudentForm();
    onUpdate();
    alert(
      (editingStudent ? 'تم التحديث' : 'تمت الإضافة') +
        (outcome.verified
          ? ' والحفظ في قاعدة البيانات'
          : ' — أُرسل وتعذّر التحقّق من القراءة'),
    );
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
      assignedSubjects: [],
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
    // العلامة قبل الإزالة، وإلا أعادته المزامنة من النسخة البعيدة وظهر
    // عند المعلم وولي الأمر وفي التقارير بعد حذفه.
    markStudentDeleted(id);
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
    parentFormView.reveal();
  };

  const handleEditStudent = (s: StudentInfo) => {
    // ‏لم تعد تُقرأ مادةٌ مفردة لتُعرَض: النافذة تفتح على المواد المسندة
    // ‏نفسها، وهي المحفوظة في السجلّ.
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
      assignedSubjects: s.assignedSubjects || [],
      canChangeGrade: s.canChangeGrade || false,
      permissionPackageId: s.permissionPackageId || '',
    });
    setEditingStudent(s);
    setShowStudentForm(true);
    setActiveTab('students');
    studentFormView.reveal();
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

  // ——— بحثات مشتركة بين عرض الجدول وعرض البطاقات ———
  //
  // العرض الهجين يرسم نفس البيانات مرّتين: جدولاً على الشاشات الكبيرة
  // وبطاقات على الجوال والتابلت. استخراج المنطق هنا يمنع أن ينحرف العرضان
  // عن بعضهما مع أول تعديل مستقبلي.
  // الربط عبر `parentId` وحده. مطابقة رقم الجوال أُسقطت: رقم واحد لوليَّي
  // أمر كان يعرض أبناء أحدهما تحت الآخر.
  const parentOf = (student: any) =>
    student?.parentId ? parents.find(p => p.id === student.parentId) : undefined;

  const teacherOf = (record: any) => teachers.find(t => t.id === record.createdBy);

  const childrenOf = (parent: any) => getParentChildren(students, parent);

  const visibleRecords: any[] = activeTab === 'students' ? filteredStudents : filteredParents;
  const hasFilter = Boolean(searchTerm.trim()) || filterTeacherId !== 'all' || filterParentId !== 'all' || filterGrade !== 'all';
  const unlinkedCount = students.filter(s => !parentOf(s)).length;

  return (
    <div className="portal-page">
      <PageHeader
        eyebrow="لوحة المشرف"
        title="إدارة الحسابات"
        description="حسابات الطلاب وأولياء الأمور لكل المعلمين: الإضافة والتعديل والربط والتصفية."
        icon={UsersRound}
        art={ART.kids}
        actions={
          <>
            <button type="button" onClick={() => quickAddAccount('student')} className="portal-btn portal-btn-primary">
              <UserPlus aria-hidden="true" /> إضافة طالب
            </button>
            <button type="button" onClick={() => quickAddAccount('parent')} className="portal-btn portal-btn-secondary">
              <UserPlus aria-hidden="true" /> إضافة ولي أمر
            </button>
          </>
        }
      />

      <div className="portal-stats">
        <StatCard label="الطلاب" value={students.length} hint="في كل الفصول" icon={GraduationCap} onClick={() => setActiveTab('students')} />
        <StatCard label="أولياء الأمور" value={parents.length} hint="حسابات مسجّلة" icon={UsersRound} tone="accent" onClick={() => setActiveTab('parents')} />
        <StatCard
          label="طلاب بلا ولي أمر"
          value={unlinkedCount}
          hint={unlinkedCount ? 'اربطهم من «تعديل»' : 'كل الطلاب مرتبطون'}
          icon={Link2Off}
          tone={unlinkedCount ? 'warning' : 'neutral'}
        />
      </div>

      {showStudentForm && (
         <div ref={studentFormView.formRef} className="dashboard-surface dashboard-account-form" style={styles.formCard}>
          <h3 style={styles.formTitle}>{editingStudent ? 'تعديل الطالب' : 'إضافة طالب جديد'}</h3>
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
                  <label style={styles.label}>المعلم *</label>
                  <select value={studentForm.teacherId} onChange={e => setStudentForm({...studentForm, teacherId: e.target.value})} style={styles.select} required>
                    <option value="">اختر المعلم</option>
                    {teachers.map((t) => <option key={t.id} value={t.id}>{t.name} - {t.subject || 'معلم'}</option>)}
                  </select>
               </div>
               <div style={styles.formGroup}>
                  <label style={styles.label}>الصف الأساسي *</label>
                  <select value={studentForm.primaryGrade} onChange={e => setStudentForm({...studentForm, primaryGrade: e.target.value, assignedSubjects: []})} style={styles.select} required>
                    <option value="">اختر الصف الأساسي</option>
                    {grades.map((g,i) => <option key={i} value={g}>{g}</option>)}
                  </select>
               </div>
                <div style={styles.formGroup}>
                  {/* المواد المتاحة للطالب.
                      لا شيء مؤشَّر = جميع مواد المعلم، وهي الحالة
                      الافتراضية لكل طالب مسجَّل قبل وجود هذا الحقل. */}
                  <label style={styles.label}>
                    المواد المتاحة للطالب
                    <span style={{ fontWeight: 'normal', color: '#6b7280', fontSize: '0.8rem' }}>
                      {' '}— {studentForm.assignedSubjects.length === 0
                        ? 'جميع المواد'
                        : `${studentForm.assignedSubjects.length} مادة محددة`}
                    </span>
                  </label>
                  {availableSubjects.length === 0 ? (
                    <div style={{ color: '#9ca3af', fontSize: '0.85rem', padding: '8px' }}>
                      اختر الصف أولاً لعرض مواده.
                    </div>
                  ) : (
                    <div style={{
                      display: 'flex', flexWrap: 'wrap', gap: '8px', padding: '10px',
                      border: '2px solid #e5e7eb', borderRadius: '10px', backgroundColor: '#f9fafb',
                    }}>
                      <label style={{
                        display: 'flex', alignItems: 'center', gap: '6px', fontWeight: 'bold',
                        cursor: 'pointer', padding: '4px 10px', borderRadius: '999px',
                        backgroundColor: studentForm.assignedSubjects.length === 0 ? '#dbeafe' : 'white',
                        border: '1px solid #bfdbfe',
                      }}>
                        <input
                          type="checkbox"
                          checked={studentForm.assignedSubjects.length === 0}
                          onChange={() => setStudentForm({ ...studentForm, assignedSubjects: [] })}
                        />
                        جميع المواد
                      </label>
                      {availableSubjects.map((subject) => {
                        const checked = studentForm.assignedSubjects.includes(subject);
                        return (
                          <label key={subject} style={{
                            display: 'flex', alignItems: 'center', gap: '6px', fontWeight: 'bold',
                            cursor: 'pointer', padding: '4px 10px', borderRadius: '999px',
                            backgroundColor: checked ? '#dcfce7' : 'white',
                            border: '1px solid #d1d5db',
                          }}>
                            <input
                              type="checkbox"
                              checked={checked}
                              onChange={() => setStudentForm({
                                ...studentForm,
                                assignedSubjects: checked
                                  ? studentForm.assignedSubjects.filter(item => item !== subject)
                                  : [...studentForm.assignedSubjects, subject],
                              })}
                            />
                            {subject}
                          </label>
                        );
                      })}
                    </div>
                  )}
                </div>
                <div style={styles.formGroup}>
                    <label style={styles.label}>إدارة صلاحيات الطالب</label>
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
         <div ref={parentFormView.formRef} className="dashboard-surface dashboard-account-form" style={styles.formCard}>
           <h3 style={styles.formTitle}>{editingParent ? 'تعديل ولي أمر' : 'إضافة ولي أمر جديد'}</h3>
           <form onSubmit={handleAddParent} style={styles.form}>
             <div style={styles.formGrid}>
               <div style={styles.formGroup}><label style={styles.label}>اسم ولي الأمر *</label><input type="text" value={parentForm.name} onChange={e => setParentForm({...parentForm, name: e.target.value})} style={styles.input} required /></div>
               <div style={styles.formGroup}><label style={styles.label}>اسم المستخدم *</label><input type="text" value={parentForm.username} onChange={e => setParentForm({...parentForm, username: e.target.value})} style={styles.input} required /></div>
               <div style={styles.formGroup}><label style={styles.label}>كلمة المرور {editingParent ? '' : '*'}</label><input type="text" value={parentForm.password} onChange={e => setParentForm({...parentForm, password: e.target.value})} style={styles.input} placeholder={editingParent ? 'اتركه فارغاً للإبقاء على الحالية' : ''} required={!editingParent} /></div>
               <div style={styles.formGroup}><label style={styles.label}>رقم الجوال</label><input type="text" value={parentForm.phoneNumber} onChange={e => setParentForm({...parentForm, phoneNumber: e.target.value})} style={styles.input} /></div>
               <div style={styles.formGroup}>
                  <label style={styles.label}>المعلم *</label>
                  <select value={parentForm.teacherId} onChange={e => setParentForm({...parentForm, teacherId: e.target.value})} style={styles.select} required>
                    <option value="">اختر المعلم</option>
                    {teachers.map((t) => <option key={t.id} value={t.id}>{t.name} - {t.subject || 'معلم'}</option>)}
                  </select>
               </div>
                <div style={styles.formGroup}>
                    <label style={styles.label}>إدارة صلاحيات ولي الأمر</label>
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

      {/* ‏شريطُ التصفية داخل لوحة الجدول نفسها: التبويبان ثم البحثُ والقوائم
          في صفٍّ واحد يلتفّ على الشاشات الضيّقة — لا بطاقةَ عائمة تتداخل مع
          ما فوقها. */}
      <Panel flush>
        <div className="portal-directory-toolbar">
          <div className="portal-tabs" role="tablist" aria-label="نوع الحسابات">
            <button type="button" role="tab" aria-selected={activeTab === 'students'} className={activeTab === 'students' ? 'is-active' : ''} onClick={() => setActiveTab('students')}>
              <GraduationCap aria-hidden="true" /> الطلاب <span>{filteredStudents.length}</span>
            </button>
            <button type="button" role="tab" aria-selected={activeTab === 'parents'} className={activeTab === 'parents' ? 'is-active' : ''} onClick={() => setActiveTab('parents')}>
              <UsersRound aria-hidden="true" /> أولياء الأمور <span>{filteredParents.length}</span>
            </button>
          </div>
          <div className="portal-directory-filters">
            <label className="portal-search">
              <Search aria-hidden="true" />
              <input
                type="search"
                value={searchTerm}
                onChange={e => setSearchTerm(e.target.value)}
                placeholder="بحث بالاسم أو اسم المستخدم أو الهوية"
                aria-label="بحث"
              />
            </label>
            <select value={filterTeacherId} onChange={e => setFilterTeacherId(e.target.value)} aria-label="تصفية بحسب المعلم">
              <option value="all">كل المعلمين</option>
              {teachers.map((t) => (
                <option key={t.id} value={t.id}>{t.name}{t.subject ? ` — ${t.subject}` : ''}</option>
              ))}
            </select>
            {activeTab === 'students' && (
              <>
                <select value={filterParentId} onChange={e => setFilterParentId(e.target.value)} aria-label="تصفية بحسب ولي الأمر">
                  <option value="all">كل أولياء الأمور</option>
                  {parents.map((p) => (
                    <option key={p.id} value={p.id}>{p.name}{p.phoneNumber ? ` — ${p.phoneNumber}` : ''}</option>
                  ))}
                </select>
                <select value={filterGrade} onChange={e => setFilterGrade(e.target.value)} aria-label="تصفية بحسب الصف">
                  <option value="all">كل الصفوف</option>
                  {grades.map((g) => (
                    <option key={g} value={g}>{g}</option>
                  ))}
                </select>
              </>
            )}
            {hasFilter && (
              <button
                type="button"
                className="portal-btn portal-btn-ghost portal-btn-sm"
                onClick={() => { setSearchTerm(''); setFilterTeacherId('all'); setFilterParentId('all'); setFilterGrade('all'); }}
              >
                <X aria-hidden="true" /> مسح الفلاتر
              </button>
            )}
          </div>
        </div>

        {/* ‏الجدول للشاشات الكبيرة، والبطاقات أسفلُ للجوال والتابلت (CSS عند 1024). */}
        <div className="dashboard-hybrid-table">
          {visibleRecords.length === 0 ? (
            <EmptyState title="لا نتائج مطابقة" description={hasFilter ? 'غيّر البحث أو الفلاتر.' : 'أضف الحسابات من الأزرار في الأعلى.'} />
          ) : (
            <div className="portal-table-wrap">
              <table className="portal-table">
                <thead>
                  <tr>
                    <th>{activeTab === 'students' ? 'الطالب' : 'ولي الأمر'}</th>
                    <th>{activeTab === 'students' ? 'رقم الهوية' : 'المعرّف'}</th>
                    <th>{activeTab === 'students' ? 'الصف' : 'رقم الجوال'}</th>
                    {activeTab === 'students' && <th>ولي الأمر</th>}
                    <th>المعلم</th>
                    {activeTab === 'parents' && <th>الأبناء</th>}
                    <th className="portal-actions-head">الإجراءات</th>
                  </tr>
                </thead>
                <tbody>
                  {visibleRecords.map((item: any) => {
                    const teacher = teacherOf(item);
                    const parent = activeTab === 'students' ? parentOf(item) : undefined;
                    const kids = activeTab === 'parents' ? childrenOf(item) : [];
                    return (
                      <tr key={item.id}>
                        <td>
                          <div className="flex items-center gap-2.5">
                            {activeTab === 'students' ? (
                              <img className="portal-avatar-img" src={studentArt(item.gender)} alt="" aria-hidden="true" loading="lazy" />
                            ) : (
                              <span className="portal-avatar-img portal-avatar-letter" aria-hidden="true">{Array.from(String(item.name || '•'))[0]}</span>
                            )}
                            <div className="min-w-0">
                              <p className="font-bold text-slate-800">{item.name}</p>
                              {item.username && <p className="text-xs text-slate-500" dir="ltr">{item.username}</p>}
                            </div>
                          </div>
                        </td>
                        <td className="is-num">{activeTab === 'students' ? (item.studentIdNumber || '—') : (item.id || '—')}</td>
                        <td className="is-num">{activeTab === 'students' ? (item.primaryGrade || item.grade || '—') : (item.phoneNumber || '—')}</td>
                        {activeTab === 'students' && (
                          <td>{parent ? <Badge tone="success">{parent.name}</Badge> : <Badge tone="warning">غير مرتبط</Badge>}</td>
                        )}
                        <td>
                          {teacher ? (
                            <Badge tone="primary">{teacher.name}</Badge>
                          ) : item.createdBy ? (
                            <Badge tone="neutral">{item.createdByName || item.createdBy}</Badge>
                          ) : (
                            <span className="text-slate-400">غير محدّد</span>
                          )}
                        </td>
                        {activeTab === 'parents' && (
                          <td>
                            {kids.length > 0 ? (
                              <div className="flex flex-wrap gap-1.5">
                                {kids.map(student => <Badge key={student.id} tone="neutral">{student.name}</Badge>)}
                              </div>
                            ) : (
                              <span className="text-slate-400">لا أبناء مرتبطون</span>
                            )}
                          </td>
                        )}
                        <td>
                          <div className="portal-row-actions">
                            {activeTab === 'students' && (
                              <button type="button" onClick={() => handleResetStudentCounter(item as StudentInfo)} className="portal-icon-btn" title="تصفير العدّاد" aria-label={`تصفير عدّاد ${item.name}`}>
                                <RotateCcw aria-hidden="true" />
                              </button>
                            )}
                            <button type="button" onClick={() => activeTab === 'students' ? handleEditStudent(item) : handleEditParent(item)} className="portal-icon-btn" title="تعديل" aria-label={`تعديل ${item.name}`}>
                              <Pencil aria-hidden="true" />
                            </button>
                            <button type="button" onClick={() => activeTab === 'students' ? handleDeleteStudent(item.id) : handleDeleteParent(item.id)} className="portal-icon-btn is-danger" title="حذف" aria-label={`حذف ${item.name}`}>
                              <Trash2 aria-hidden="true" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </Panel>

      {/* ===== عرض البطاقات — الجوال والتابلت ===== */}
      <div className="dashboard-hybrid-cards">
        {visibleRecords.length === 0 ? (
          <div className="dashboard-record-card text-center font-bold italic text-slate-400">
            لا توجد نتائج بحث
          </div>
        ) : (
          <div className="dashboard-record-grid">
            {visibleRecords.map((item: any) => {
              const teacher = teacherOf(item);
              const parent = activeTab === 'students' ? parentOf(item) : undefined;
              const children = activeTab === 'parents' ? childrenOf(item) : [];
              return (
                <article key={item.id} className="dashboard-record-card">
                  <header className="dashboard-record-head">
                    <div className="min-w-0 flex-1">
                      <h3 className="dashboard-record-title">{item.name}</h3>
                      <span className="dashboard-badge">
                        {activeTab === 'students' ? 'طالب' : 'ولي أمر'}
                      </span>
                    </div>
                  </header>

                  <dl className="dashboard-record-meta">
                    <div>
                      <dt>اسم المستخدم</dt>
                      <dd>{item.username || '-'}</dd>
                    </div>
                    <div>
                      <dt>{activeTab === 'students' ? 'رقم الهوية' : 'المعرّف'}</dt>
                      <dd>{activeTab === 'students' ? (item.studentIdNumber || '-') : (item.id || '-')}</dd>
                    </div>
                    <div>
                      <dt>{activeTab === 'students' ? 'الصف الأساسي' : 'رقم الجوال'}</dt>
                      <dd>
                        {activeTab === 'students'
                          ? (item.primaryGrade || item.grade || '-')
                          : (item.phoneNumber || '-')}
                      </dd>
                    </div>
                    <div>
                      <dt>المعلم</dt>
                      <dd>{teacher?.name || item.createdByName || item.createdBy || 'غير محدد'}</dd>
                    </div>
                    {activeTab === 'students' && (
                      <div>
                        <dt>ولي الأمر</dt>
                        <dd>{parent?.name || 'غير مرتبط'}</dd>
                      </div>
                    )}
                  </dl>

                  {activeTab === 'parents' && (
                    <div className="dashboard-record-badges">
                      {children.length > 0 ? (
                        children.map(student => (
                          <span key={student.id} className="dashboard-badge">
                            {getStudentEmoji(student)} {student.name}
                          </span>
                        ))
                      ) : (
                        <span className="dashboard-badge">لا يوجد طلاب مرتبطون</span>
                      )}
                    </div>
                  )}

                  <footer className="dashboard-record-footer dashboard-record-buttons">
                    {activeTab === 'students' && (
                      <button
                        onClick={() => handleResetStudentCounter(item as StudentInfo)}
                        className="dashboard-record-action bg-slate-100 text-slate-700 hover:bg-slate-200"
                      >
                        <RotateCcw className="h-4 w-4" aria-hidden="true" /> تصفير العداد
                      </button>
                    )}
                    <button
                      onClick={() => activeTab === 'students' ? handleEditStudent(item) : handleEditParent(item)}
                      className="dashboard-record-action bg-blue-50 text-blue-700 hover:bg-blue-100"
                    >
                      <Pencil className="h-4 w-4" aria-hidden="true" /> تعديل
                    </button>
                    <button
                      onClick={() => activeTab === 'students' ? handleDeleteStudent(item.id) : handleDeleteParent(item.id)}
                      className="dashboard-record-action bg-red-50 text-red-700 hover:bg-red-100"
                    >
                      <Trash2 className="h-4 w-4" aria-hidden="true" /> حذف
                    </button>
                  </footer>
                </article>
              );
            })}
          </div>
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
   quickAddStats: { display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: '15px' },
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
