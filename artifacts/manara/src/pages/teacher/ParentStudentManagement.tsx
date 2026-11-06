import { saveStudentConfirmed } from '../../db/confirmedSave';
import { gradesForOwner, readHierarchicalConfigs, subjectsForOwner } from '../../utils/academic';
import { markStudentDeleted } from '../../utils/students';
import React, { useState, useEffect, useMemo } from 'react';
import { StudentInfo, ParentInfo, HierarchicalConfig, ParentPermissions } from '../../types';
import { STORAGE_KEYS, DEFAULT_PASSWORD } from '../../constants';
import { ensureHashed } from '../../utils/password';
import { getTeacherPermissions, getEffectiveParentPermissions, getPermissionPackages, isLimitReached } from '../../permissions';
import { getTeacherParents, getTeacherStudents, getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import { resetGamificationForStudent } from '../../utils/gamification';
import { getStudentEmoji, STUDENT_GENDER_OPTIONS, StudentGender } from '../../utils/studentAppearance';
import { useRevealForm } from '../../hooks/useRevealForm';
import { filterAccounts } from '../../utils/accountFilters';
import { Badge, EmptyState, PageHeader, Panel, StatCard, relativeDay, ART, studentArt } from '../../components/portal/PortalUI';
import { initialOf } from '../../components/portal/PortalShell';
import { GraduationCap, Link2Off, Pencil, RotateCcw, Search, ShieldCheck, Trash2, UserPlus, UsersRound, X } from 'lucide-react';
import { X as IconX } from 'lucide-react';

interface ParentStudentManagementProps {
  teacherId: string;
  teacherName: string;
  permissionPackageId?: string;
}

const ParentStudentManagement: React.FC<ParentStudentManagementProps> = ({ teacherId, teacherName, permissionPackageId }) => {
  const [students, setStudents] = useState<StudentInfo[]>([]);
  const [parents, setParents] = useState<ParentInfo[]>([]);
  const [grades, setGrades] = useState<string[]>([]);
  const [subjects, setSubjects] = useState<string[]>([]);
  const [terms, setTerms] = useState<string[]>([]);
  const [units, setUnits] = useState<string[]>([]);
  const [hierarchicalConfigs, setHierarchicalConfigs] = useState<HierarchicalConfig[]>([]);

  const [parentPackages, setParentPackages] = useState<any[]>([]);
  const [studentPackages, setStudentPackages] = useState<any[]>([]);

  const [showParentForm, setShowParentForm] = useState(false);
  const [showStudentForm, setShowStudentForm] = useState(false);
  // ‏«تعديل» يُظهر النموذجَ ويضع المؤشّرَ فيه، ولو ضُغط من آخر القائمة — انظر hooks/useRevealForm.
  const studentFormView = useRevealForm();
  const parentFormView = useRevealForm();
  const [editingParent, setEditingParent] = useState<ParentInfo | null>(null);
  const [editingStudent, setEditingStudent] = useState<StudentInfo | null>(null);
  const [permissionsParent, setPermissionsParent] = useState<ParentInfo | null>(null);
  const [parentPermissionDraft, setParentPermissionDraft] = useState<ParentPermissions | null>(null);

  // الحصول على الصلاحيات
  const permissions = getTeacherPermissions({ permissionPackageId });
  
  const [parentForm, setParentForm] = useState({
    name: '',
    username: '',
    password: DEFAULT_PASSWORD,
    phoneNumber: '',
    nationalId: '',
    permissionPackageId: '',
  });

  const [searchQuery, setSearchQuery] = useState('');
  const [selectedParentId, setSelectedParentId] = useState<string>('all');
  const [selectedStudentId, setSelectedStudentId] = useState<string>('all');
  const [accountsView, setAccountsView] = useState<'students' | 'parents'>('students');

  const [studentForm, setStudentForm] = useState({
    name: '',
    gender: 'male' as StudentGender,
    username: '',
    password: DEFAULT_PASSWORD,
    parentPhoneNumber: '',
    parentId: '',
    studentIdNumber: '',
    nationalId: '',
    primaryGrade: '',
    gradeEnrollments: [] as { grade: string; enrollments: { id?: string; subject: string; term: string; unit: string }[] }[],
    /// المواد المسموح بها. فارغة = جميع مواد المعلم.
    assignedSubjects: [] as string[],
    permissionPackageId: '',
  });

  // مواد الصف المختار من شجرة هذا المعلم، مشتقّة من حالة النموذج: كانت
  // تُملأ في حدث قائمة الصف وحده، فتبقى فارغة عند فتح نافذة طالب مسجَّل
  // بينما حقل المادة إجباري — فيمتنع الحفظ.
  const availableSubjects = useMemo(
    () => subjectsForOwner(teacherId, studentForm.primaryGrade),
    [teacherId, studentForm.primaryGrade, hierarchicalConfigs],
  );

  /// المادة التي يُفتح عليها حساب الطالب — من المربّعات وحدها.
  const primarySubject = studentForm.assignedSubjects[0] || availableSubjects[0] || '';

  useEffect(() => {
    loadData();
    loadAcademicSettings();
  }, [teacherId]);

  const loadData = () => {
    const allParents: ParentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
    const allStudents: StudentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
    
    // فلترة أولياء الأمور المرتبطين بهذا المعلم
    const teacherParents = getTeacherParents(allParents, teacherId);
    const parentIds = teacherParents.map(p => p.id);
    
    // teacherId is authoritative; parent linkage remains a legacy fallback.
    const teacherStudents = getTeacherStudents(allStudents, teacherId, teacherParents);
    
    setParents(teacherParents);
    setStudents(teacherStudents);
    const packages = getPermissionPackages();
    setParentPackages(packages.filter(pkg => pkg.role === 'parent'));
    setStudentPackages(packages.filter(pkg => pkg.role === 'student'));
  };

  const loadAcademicSettings = () => {
    // ── من شجرة المعلم وحدها ──
    // القوائم المسطّحة (`smartEdu_grades`…) مشتركةٌ بين المعلمين كلّهم،
    // فالارتدادُ إليها كان يُظهر صفوفَ غيره ومواده. معلّمٌ بلا شجرة يرى
    // قائمةً فارغة تدلّه على «إعداداتي الأكاديمية»، لا صفوفَ معلّمٍ آخر.
    setGrades(gradesForOwner(teacherId));
    setSubjects(subjectsForOwner(teacherId));
    setTerms([]);
    setUnits([]);
    setHierarchicalConfigs(readHierarchicalConfigs());
  };

  const getSubjectsForGrade = (grade: string) => {
    if (!grade) return subjects;
    // مواد هذا المعلم في هذا الصف، من شجرته وحدها.
    return subjectsForOwner(teacherId, grade);
  };

  const handleSaveParent = () => {
    if (!parentForm.name || !parentForm.phoneNumber) {
      alert('الرجاء ملء الحقول المطلوبة');
      return;
    }

    const allParents: ParentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
    const changingParentPackage = editingParent
      ? parentForm.permissionPackageId !== (editingParent.permissionPackageId || '')
      : Boolean(parentForm.permissionPackageId);
    if (changingParentPackage && !permissions.canCreatePermissionPackages) {
      alert('ليس لديك صلاحية إسناد إدارة الصلاحيات');
      return;
    }

    if (!editingParent) {
      if (!permissions.canCreateParents) {
        alert('ليس لديك صلاحية إنشاء أولياء أمور');
        return;
      }
      const teacherParents = getTeacherParents(allParents, teacherId);
      if (isLimitReached(teacherParents.length, permissions.maxParents)) {
        alert(`وصلت إلى الحد الأقصى المسموح به (${permissions.maxParents}) من أولياء الأمور`);
        return;
      }
    } else if (!permissions.canEditParents) {
      alert('ليس لديك صلاحية تعديل أولياء الأمور');
      return;
    }
    
    // التحقق من عدم تكرار رقم الهوية عبر جميع المستخدمين
    if (parentForm.nationalId && parentForm.nationalId.trim()) {
      const nationalId = parentForm.nationalId.trim();
      
      // التحقق من أولياء الأمور
      const duplicateParent = allParents.find(p => 
        p.nationalId === nationalId && p.id !== editingParent?.id
      );
      if (duplicateParent) {
        alert(`رقم الهوية ${nationalId} مستخدم بالفعل من قبل ولي الأمر: ${duplicateParent.name}`);
        return;
      }
      
      // التحقق من المعلمين
      const allTeachers = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
      const duplicateTeacher = allTeachers.find((t: any) => t.nationalId === nationalId);
      if (duplicateTeacher) {
        alert(`رقم الهوية ${nationalId} مستخدم بالفعل من قبل المعلم: ${duplicateTeacher.name}`);
        return;
      }
      
      // التحقق من الطلاب
      const allStudents = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
      const duplicateStudent = allStudents.find((s: any) => s.nationalId === nationalId);
      if (duplicateStudent) {
        alert(`رقم الهوية ${nationalId} مستخدم بالفعل من قبل الطالب: ${duplicateStudent.name}`);
        return;
      }
    }
    
    if (editingParent) {
      // تعديل ولي أمر موجود
      const index = allParents.findIndex(p => p.id === editingParent.id);
      if (index >= 0) {
        allParents[index] = {
          ...allParents[index],
          name: parentForm.name,
          username: parentForm.username || allParents[index].username,
          phoneNumber: parentForm.phoneNumber,
          nationalId: parentForm.nationalId?.trim() || '',
          password: ensureHashed(parentForm.password || allParents[index].password),
          permissionPackageId: parentForm.permissionPackageId || allParents[index].permissionPackageId || undefined,
        };
      }
    } else {
      // إنشاء ولي أمر جديد
      const newParent: ParentInfo = {
        id: Date.now().toString(),
        name: parentForm.name,
        username: parentForm.username || `parent_${Date.now()}`,
        password: ensureHashed(parentForm.password || DEFAULT_PASSWORD),
        phoneNumber: parentForm.phoneNumber,
        nationalId: parentForm.nationalId?.trim() || '',
        children: [],
        mustChangePassword: true,
        createdAt: new Date().toISOString(),
        lastLogin: '',
        createdBy: teacherId, // ربط بالمعلم
        createdByName: teacherName,
        permissionPackageId: parentForm.permissionPackageId || undefined,
      };
      allParents.push(newParent);
    }

    localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(allParents));
    loadData();
    resetParentForm();
    alert('تم حفظ ولي الأمر بنجاح!');
  };

  const handleSaveStudent = async () => {
    if (!studentForm.name || !studentForm.parentId || !studentForm.primaryGrade || !studentForm.username) {
      alert('الرجاء ملء الحقول المطلوبة (الاسم، ولي الأمر، الصف، اسم المستخدم)');
      return;
    }

    const allStudents: StudentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
    const allParents: ParentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
    const changingStudentPackage = editingStudent
      ? studentForm.permissionPackageId !== (editingStudent.permissionPackageId || '')
      : Boolean(studentForm.permissionPackageId);
    if (changingStudentPackage && !permissions.canCreatePermissionPackages) {
      alert('ليس لديك صلاحية إسناد إدارة الصلاحيات');
      return;
    }

    if (!editingStudent) {
      if (!permissions.canCreateStudents) {
        alert('ليس لديك صلاحية إنشاء الطلاب');
        return;
      }
      const teacherParents = getTeacherParents(allParents, teacherId);
      const teacherStudents = getTeacherStudents(allStudents, teacherId, teacherParents);
      if (isLimitReached(teacherStudents.length, permissions.maxStudents)) {
        alert(`وصلت إلى الحد الأقصى المسموح به (${permissions.maxStudents}) من الطلاب`);
        return;
      }
    } else if (!permissions.canEditStudents) {
      alert('ليس لديك صلاحية تعديل الطلاب');
      return;
    }
    
    // التحقق من عدم تكرار رقم الهوية
    if (studentForm.nationalId && studentForm.nationalId.trim()) {
      const nationalId = studentForm.nationalId.trim();
      
      // التحقق من الطلاب
      const duplicateStudent = allStudents.find(s => 
        s.nationalId === nationalId && s.id !== editingStudent?.id
      );
      if (duplicateStudent) {
        alert(`رقم الهوية ${nationalId} مستخدم بالفعل من قبل الطالب: ${duplicateStudent.name}`);
        return;
      }
      
      // التحقق من أولياء الأمور
      const duplicateParent = allParents.find(p => p.nationalId === nationalId);
      if (duplicateParent) {
        alert(`رقم الهوية ${nationalId} مستخدم بالفعل من قبل ولي الأمر: ${duplicateParent.name}`);
        return;
      }
      
      // التحقق من المعلمين (استخدام teacherId)
      const allTeachers = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
      const duplicateTeacher = allTeachers.find((t: any) => t.teacherId === nationalId);
      if (duplicateTeacher) {
        alert(`رقم الهوية ${nationalId} مستخدم بالفعل من قبل المعلم: ${duplicateTeacher.name}`);
        return;
      }
    }
    
    let savedStudent: StudentInfo | undefined;

    if (editingStudent) {
      // تعديل طالب موجود
      const index = allStudents.findIndex(s => s.id === editingStudent.id);
      if (index >= 0) {
        allStudents[index] = {
          ...allStudents[index],
          name: studentForm.name,
          gender: studentForm.gender,
          username: studentForm.username || allStudents[index].username,
          password: ensureHashed(studentForm.password || allStudents[index].password),
          parentPhoneNumber: studentForm.parentPhoneNumber,
          parentId: studentForm.parentId,
          studentIdNumber: studentForm.studentIdNumber,
          nationalId: studentForm.nationalId?.trim() || '',
          primaryGrade: studentForm.primaryGrade,
          // و`grade` معه: شاشات الويب تقرأ هذا الحقل، ولا يكفي أن يُكتب
          // عند الإنشاء وحده.
          grade: studentForm.primaryGrade,
          gradeEnrollments: studentForm.gradeEnrollments,
          // ‏هذان كانا في فرع الإنشاء وحده.
          //
          // ‏فالمعلم يُنشئ الطالب فتُحفظ مواده المسندة، ثم يعدّلها فلا
          // ‏يُكتب شيء: الفرع الآخر لا يذكر الحقل، و`...` تُبقي القيمة
          // ‏القديمة كما هي. ولوحة المشرف تبني كائناً واحداً للإنشاء
          // ‏والتعديل معاً، فتكتبه دائماً — ولهذا نجح حفظ المشرف وحده
          // ‏على السجلّ نفسه.
          subject: primarySubject,
          assignedSubjects: studentForm.assignedSubjects,
          teacherId,
          createdBy: teacherId,
          permissionPackageId: studentForm.permissionPackageId || allStudents[index].permissionPackageId || undefined,
        };
        savedStudent = allStudents[index];
      }
    } else {
      // إنشاء طالب جديد
      const newStudent: StudentInfo = {
        id: Date.now().toString(),
        name: studentForm.name,
        gender: studentForm.gender,
        username: studentForm.username,
        password: ensureHashed(studentForm.password || DEFAULT_PASSWORD),
        parentPhoneNumber: studentForm.parentPhoneNumber,
        parentId: studentForm.parentId, // ربط بولي الأمر
        studentIdNumber: studentForm.studentIdNumber || Date.now().toString(),
        nationalId: studentForm.nationalId?.trim() || '',
        primaryGrade: studentForm.primaryGrade,
        // و`grade` معه: شاشات الويب تقرأ هذا الحقل، وكان يبقى على قيمته
        // القديمة بعد تغيير الصف من هنا.
        grade: studentForm.primaryGrade,
        gradeEnrollments: studentForm.gradeEnrollments,
        // ‏تُشتقّ من المواد المسندة: حقل المادة المفرد كان يجوز أن
        // ‏يناقضها، وتطبيق الطالب يقرأ هذه لا تلك.
        subject: primarySubject,
        assignedSubjects: studentForm.assignedSubjects,
        createdAt: new Date().toISOString(),
        lastActivity: new Date().toISOString(),
        canChangeGrade: false,
        teacherId,
        createdBy: teacherId, // ربط بالمعلم
        permissionPackageId: studentForm.permissionPackageId || undefined,
      };
      allStudents.push(newStudent);
      savedStudent = newStudent;
    }

    // Keep the embedded child record on every parent synchronized with the
    // canonical student record, including parent changes during an edit.
    if (savedStudent) {
      const updatedParents = allParents.map(parent => {
        const remainingChildren = (parent.children || []).filter(child => child.id !== savedStudent!.id);
        return parent.id === savedStudent!.parentId
          ? { ...parent, children: [...remainingChildren, savedStudent] }
          : { ...parent, children: remainingChildren };
      });
      localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(updatedParents));
    }

    localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(allStudents));

    // ولا يُعلَن النجاح حتى يصل إلى قاعدة البيانات: الإرسال الفاشل كان
    // يدخل الطابور بصمت فيظنّ المعلم أن الصفّ الجديد محفوظ.
    if (savedStudent) {
      const outcome = await saveStudentConfirmed(savedStudent);
      if (outcome.ok === false) {
        loadData();
        alert(`لم يُحفظ في قاعدة البيانات: ${outcome.reason}`);
        return;
      }
    }

    loadData();
    resetStudentForm();
    alert('تم حفظ الطالب في قاعدة البيانات');
  };

  const handleDeleteParent = (parentId: string) => {    if (!permissions.canDeleteParents) {
      alert('ليس لديك صلاحية حذف أولياء الأمور');
      return;
    }    if (!confirm('هل أنت متأكد من حذف ولي الأمر وجميع أبنائه؟')) return;
    
    let allParents: ParentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
    let allStudents: StudentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
    
    // حذف الطلاب المرتبطين
    allStudents = allStudents.filter(s => s.parentId !== parentId);
    allParents = allParents.filter(p => p.id !== parentId);
    
    localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(allParents));
    localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(allStudents));
    loadData();
    alert('تم حذف ولي الأمر والطلاب المرتبطين به');
  };

  const handleDeleteStudent = (studentId: string) => {    if (!permissions.canDeleteStudents) {
      alert('ليس لديك صلاحية حذف الطلاب');
      return;
    }    if (!confirm('هل أنت متأكد من حذف الطالب؟')) return;
    
    // العلامة قبل الإزالة، وإلا أعادته المزامنة من النسخة البعيدة.
    markStudentDeleted(studentId);
    let allStudents: StudentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
    allStudents = allStudents.filter(s => s.id !== studentId);
    
    localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(allStudents));
    loadData();
    alert('تم حذف الطالب بنجاح');
  };

  const handleResetStudentCounter = (student: StudentInfo) => {
    const studentIdentity = student.studentIdNumber || student.nationalId || student.username || student.id;
    if (!confirm(`تأكيد التصفير:\nالطالب: ${student.name}\nالهوية: ${studentIdentity}\n\nهل تريد المتابعة؟`)) return;
    resetGamificationForStudent(student);
    alert(`تم تصفير عداد الطالب ${student.name} (هوية: ${studentIdentity}) بنجاح`);
  };

  const openParentPermissions = (parent: ParentInfo) => {
    if (!permissions.canManageParentPermissions) {
      alert('ليس لديك صلاحية إدارة صلاحيات أولياء الأمور');
      return;
    }
    setPermissionsParent(parent);
    const globalParentPermissions = getEffectiveParentPermissions(parent);
    setParentPermissionDraft({
      ...globalParentPermissions,
      ...(parent.parentPermissions || {}),
      canCreateStudents: Boolean(globalParentPermissions.canCreateStudents && parent.parentPermissions?.canCreateStudents !== false),
      canEditStudents: Boolean(globalParentPermissions.canEditStudents && parent.parentPermissions?.canEditStudents !== false),
      canDeleteStudents: Boolean(globalParentPermissions.canDeleteStudents && parent.parentPermissions?.canDeleteStudents !== false),
      canResetStudentPassword: Boolean(globalParentPermissions.canResetStudentPassword && parent.parentPermissions?.canResetStudentPassword !== false),
      canViewReports: Boolean(globalParentPermissions.canViewReports && parent.parentPermissions?.canViewReports !== false),
      canChangeGrade: Boolean(globalParentPermissions.canChangeGrade && parent.parentPermissions?.canChangeGrade !== false),
      canChatWithSupport: Boolean(globalParentPermissions.canChatWithSupport && parent.parentPermissions?.canChatWithSupport !== false),
    });
  };

  const saveParentPermissions = () => {
    if (!permissionsParent || !parentPermissionDraft) return;
    const allParents: ParentInfo[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]',
    );
    const updatedParents = allParents.map(parent =>
      parent.id === permissionsParent.id
        ? { ...parent, parentPermissions: parentPermissionDraft }
        : parent,
    );
    localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(updatedParents));
    setPermissionsParent(null);
    setParentPermissionDraft(null);
    loadData();
    alert('تم حفظ صلاحيات ولي الأمر');
  };

  const resetParentForm = () => {
    setParentForm({
      name: '',
      username: '',
      password: DEFAULT_PASSWORD,
      phoneNumber: '',
      nationalId: '',
      permissionPackageId: '',
    });
    setShowParentForm(false);
    setEditingParent(null);
  };

  const resetStudentForm = () => {
    setStudentForm({
      name: '',
      gender: 'male',
      username: '',
      password: DEFAULT_PASSWORD,
      parentPhoneNumber: '',
      parentId: '',
      studentIdNumber: '',
      nationalId: '',
      primaryGrade: '',
      gradeEnrollments: [],
      assignedSubjects: [],
      permissionPackageId: '',
    });
    setShowStudentForm(false);
    setEditingStudent(null);
  };

  const getStudentCountForParent = (parentId: string) => {
    return students.filter(s => s.parentId === parentId).length;
  };

  const startEditStudent = (student: StudentInfo) => {
    setEditingStudent(student);
    setStudentForm({ name: student.name, gender: student.gender || 'male', username: student.username || '', password: '', parentPhoneNumber: student.parentPhoneNumber, parentId: student.parentId || '', studentIdNumber: student.studentIdNumber || '', nationalId: student.nationalId || '', primaryGrade: student.primaryGrade, gradeEnrollments: student.gradeEnrollments || [], assignedSubjects: student.assignedSubjects || [], permissionPackageId: student.permissionPackageId || '' });
    setShowStudentForm(true);
    studentFormView.reveal();
  };

  const startEditParent = (parent: ParentInfo) => {
    setEditingParent(parent);
    setParentForm({ name: parent.name, username: parent.username, password: '', phoneNumber: parent.phoneNumber, nationalId: parent.nationalId || '', permissionPackageId: parent.permissionPackageId || '' });
    setShowParentForm(true);
    parentFormView.reveal();
  };

  const visible = filterAccounts(students, parents, {
    query: searchQuery,
    parentId: selectedParentId,
    studentId: selectedStudentId,
  });
  const parentName = (parentId?: string) => parents.find(p => p.id === parentId)?.name;
  const hasFilter = selectedParentId !== 'all' || selectedStudentId !== 'all' || searchQuery.trim() !== '';
  const unlinkedCount = students.filter(s => !s.parentId || !parents.some(p => p.id === s.parentId)).length;

  return (
    <div className="portal-page">
      <PageHeader
        eyebrow="بوابة المعلم"
        title="الطلاب وأولياء الأمور"
        description="إنشاء حسابات أولياء الأمور والطلاب وربطها، وإدارتها من جدولٍ واحد."
        icon={UsersRound}
        art={ART.kids}
        actions={!showParentForm && !showStudentForm ? (
          <>
            {permissions.canCreateStudents && (
              <button type="button" onClick={() => setShowStudentForm(true)} className="portal-btn portal-btn-primary">
                <UserPlus aria-hidden="true" /> إضافة طالب
              </button>
            )}
            {permissions.canCreateParents && (
              <button type="button" onClick={() => setShowParentForm(true)} className="portal-btn portal-btn-secondary">
                <UserPlus aria-hidden="true" /> إضافة ولي أمر
              </button>
            )}
          </>
        ) : undefined}
      />

      <div className="portal-stats">
        <StatCard label="الطلاب" value={students.length} hint="مرتبطون بك" icon={GraduationCap} onClick={() => { setAccountsView('students'); setSelectedParentId('all'); setSelectedStudentId('all'); }} />
        <StatCard label="أولياء الأمور" value={parents.length} hint="حسابات أنشأتها" icon={UsersRound} tone="accent" onClick={() => { setAccountsView('parents'); setSelectedParentId('all'); setSelectedStudentId('all'); }} />
        <StatCard label="طلاب بلا ولي أمر" value={unlinkedCount} hint={unlinkedCount ? 'اربطهم من «تعديل»' : 'كل الطلاب مرتبطون'} icon={Link2Off} tone={unlinkedCount ? 'warning' : 'neutral'} />
      </div>

      {!permissions.canCreateStudents && !permissions.canCreateParents && (
        <p className="rounded-lg bg-amber-50 px-4 py-3 text-sm font-bold text-amber-800">ليس لديك صلاحيات لإضافة حسابات جديدة</p>
      )}

         {showParentForm && (
           <div ref={parentFormView.formRef} className="dashboard-surface dashboard-account-form bg-slate-50">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <h3 className="text-2xl font-black text-gray-800">
                  {editingParent ? 'تعديل بيانات ولي أمر' : 'إضافة ولي أمر جديد'}
                </h3>
              </div>
              <button
                onClick={resetParentForm}
                className="text-gray-500 hover:text-gray-700 text-2xl font-bold"
                title="إغلاق"
              >
                <IconX className="inline-block h-[1em] w-[1em] align-[-0.125em]" aria-hidden="true" />
              </button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">الاسم *</label>
                <input
                  type="text"
                  value={parentForm.name}
                  onChange={(e) => setParentForm({ ...parentForm, name: e.target.value })}
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">رقم الجوال *</label>
                <input
                  type="text"
                  value={parentForm.phoneNumber}
                  onChange={(e) => setParentForm({ ...parentForm, phoneNumber: e.target.value })}
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">رقم الهوية</label>
                <input
                  type="text"
                  value={parentForm.nationalId}
                  onChange={(e) => setParentForm({ ...parentForm, nationalId: e.target.value })}
                  placeholder="اختياري"
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">اسم المستخدم</label>
                <input
                  type="text"
                  value={parentForm.username}
                  onChange={(e) => setParentForm({ ...parentForm, username: e.target.value })}
                  placeholder="اختياري - سيتم إنشاؤه تلقائياً"
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">كلمة المرور</label>
                <input
                  type="text"
                  value={parentForm.password}
                  onChange={(e) => setParentForm({ ...parentForm, password: e.target.value })}
                  placeholder={editingParent ? 'اتركه فارغاً للإبقاء على الحالية' : 'كلمة المرور الافتراضية'}
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                />
              </div>
               <div>
                 <label className="block text-sm font-bold text-gray-700 mb-2">إدارة صلاحيات ولي الأمر</label>
                 <select
                   value={parentForm.permissionPackageId}
                   onChange={(e) => setParentForm({ ...parentForm, permissionPackageId: e.target.value })}
                   className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                 >
                   <option value="">الصلاحيات العامة الحالية</option>
                   {parentPackages.map(pkg => <option key={pkg.id} value={pkg.id}>{pkg.name}</option>)}
                 </select>
               </div>
            </div>
            <div className="flex gap-3 mt-6">
              <button
                onClick={handleSaveParent}
                className="flex-1 bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-700 hover:to-blue-800 text-white px-8 py-4 rounded-xl font-bold text-lg transition-all shadow-lg"
              >
                حفظ التغييرات
              </button>
              <button
                onClick={resetParentForm}
                className="px-8 py-4 bg-gray-300 hover:bg-gray-400 text-gray-800 rounded-xl font-bold text-lg transition-all"
              >
                إلغاء
              </button>
            </div>
          </div>
        )}

        {/* الجدولان: الطلاب وأولياء الأمور — يظهران حين لا نموذجَ مفتوح */}
        {!showParentForm && !showStudentForm && (
          <Panel flush>
            <div className="portal-directory-toolbar">
              <div className="portal-tabs" role="tablist" aria-label="نوع الحسابات">
                <button type="button" role="tab" aria-selected={accountsView === 'students'} className={accountsView === 'students' ? 'is-active' : ''} onClick={() => setAccountsView('students')}>
                  <GraduationCap aria-hidden="true" /> الطلاب <span>{visible.students.length}</span>
                </button>
                <button type="button" role="tab" aria-selected={accountsView === 'parents'} className={accountsView === 'parents' ? 'is-active' : ''} onClick={() => setAccountsView('parents')}>
                  <UsersRound aria-hidden="true" /> أولياء الأمور <span>{visible.parents.length}</span>
                </button>
              </div>
              <div className="portal-directory-filters">
                <label className="portal-search">
                  <Search aria-hidden="true" />
                  <input
                    type="search"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="بحث بالاسم أو اسم المستخدم أو الجوال أو الهوية"
                    aria-label="بحث"
                  />
                </label>
                <select
                  value={selectedParentId}
                  onChange={(e) => { setSelectedParentId(e.target.value); setSelectedStudentId('all'); if (e.target.value !== 'all') setAccountsView('parents'); }}
                  aria-label="ولي الأمر"
                >
                  <option value="all">جميع أولياء الأمور</option>
                  {parents.map(p => (
                    <option key={p.id} value={p.id}>{p.name} — {p.phoneNumber}</option>
                  ))}
                </select>
                <select
                  value={selectedStudentId}
                  onChange={(e) => { setSelectedStudentId(e.target.value); if (e.target.value !== 'all') setAccountsView('students'); }}
                  aria-label="الطالب"
                >
                  <option value="all">جميع الطلاب</option>
                  {(selectedParentId === 'all' ? students : students.filter(s => s.parentId === selectedParentId)).map(s => (
                    <option key={s.id} value={s.id}>{s.name} — {s.primaryGrade}</option>
                  ))}
                </select>
                {hasFilter && (
                  <button type="button" className="portal-btn portal-btn-ghost portal-btn-sm" onClick={() => { setSearchQuery(''); setSelectedParentId('all'); setSelectedStudentId('all'); }}>
                    <X aria-hidden="true" /> مسح الفلاتر
                  </button>
                )}
              </div>
            </div>

            {accountsView === 'students' ? (
              visible.students.length === 0 ? (
                <EmptyState title="لا طلاب مطابقين" description={hasFilter ? 'غيّر البحث أو الفلاتر.' : 'أضف طلابك من زر «إضافة طالب».'} icon={GraduationCap} />
              ) : (
                <div className="portal-table-wrap">
                  <table className="portal-table">
                    <thead>
                      <tr>
                        <th>الطالب</th>
                        <th>الصف</th>
                        <th>ولي الأمر</th>
                        <th>رقم الطالب</th>
                        <th>مرّات الدخول</th>
                        <th>آخر نشاط</th>
                        <th aria-label="إجراءات" />
                      </tr>
                    </thead>
                    <tbody>
                      {visible.students.map(student => {
                        const pName = parentName(student.parentId);
                        return (
                          <tr key={student.id}>
                            <td>
                              <div className="flex items-center gap-2.5">
                                <img className="portal-avatar-img" src={studentArt(student.gender)} alt="" aria-hidden="true" loading="lazy" />
                                <div className="min-w-0">
                                  <p className="font-bold text-slate-800">{student.name}</p>
                                  {student.username && <p className="text-xs text-slate-500" dir="ltr">{student.username}</p>}
                                </div>
                              </div>
                            </td>
                            <td>{student.primaryGrade || student.grade || '—'}</td>
                            <td>
                              {pName ? (
                                <button type="button" className="portal-link" onClick={() => { setSelectedParentId(student.parentId || 'all'); setSelectedStudentId('all'); setAccountsView('parents'); }}>{pName}</button>
                              ) : (
                                <Badge tone="warning">غير مرتبط</Badge>
                              )}
                            </td>
                            <td className="is-num">{student.studentIdNumber || '—'}</td>
                            <td className="is-num">{typeof student.loginCount === 'number' ? student.loginCount : '—'}</td>
                            <td className="is-num text-slate-500">{relativeDay(student.lastLoginAt || student.lastActivity)}</td>
                            <td>
                              <div className="flex justify-end gap-1">
                                <button type="button" onClick={() => handleResetStudentCounter(student)} className="portal-icon-btn" title="تصفير العدّاد" aria-label={`تصفير عدّاد ${student.name}`}><RotateCcw aria-hidden="true" /></button>
                                {permissions.canEditStudents && (
                                  <button type="button" onClick={() => startEditStudent(student)} className="portal-icon-btn" title="تعديل" aria-label={`تعديل ${student.name}`}><Pencil aria-hidden="true" /></button>
                                )}
                                {permissions.canDeleteStudents && (
                                  <button type="button" onClick={() => handleDeleteStudent(student.id)} className="portal-icon-btn is-danger" title="حذف" aria-label={`حذف ${student.name}`}><Trash2 aria-hidden="true" /></button>
                                )}
                              </div>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )
            ) : visible.parents.length === 0 ? (
              <EmptyState title="لا أولياء أمور مطابقين" description={hasFilter ? 'غيّر البحث أو الفلاتر.' : 'أضف ولي أمر من زر «إضافة ولي أمر».'} icon={UsersRound} />
            ) : (
              <div className="portal-table-wrap">
                <table className="portal-table">
                  <thead>
                    <tr>
                      <th>ولي الأمر</th>
                      <th>الجوال</th>
                      <th>رقم الهوية</th>
                      <th>الأبناء</th>
                      <th aria-label="إجراءات" />
                    </tr>
                  </thead>
                  <tbody>
                    {visible.parents.map(parent => {
                      const children = students.filter(s => s.parentId === parent.id);
                      return (
                        <tr key={parent.id}>
                          <td>
                            <div className="flex items-center gap-2.5">
                              <span className="portal-avatar" style={{ width: '2.1rem', height: '2.1rem', fontSize: '0.85rem', background: 'var(--pt-accent-soft)', color: 'var(--pt-accent)' }} aria-hidden="true">{initialOf(parent.name)}</span>
                              <div className="min-w-0">
                                <p className="font-bold text-slate-800">{parent.name}</p>
                                {parent.username && <p className="text-xs text-slate-500" dir="ltr">{parent.username}</p>}
                              </div>
                            </div>
                          </td>
                          <td className="is-num" dir="ltr">{parent.phoneNumber || '—'}</td>
                          <td className="is-num">{parent.nationalId || '—'}</td>
                          <td>
                            {children.length === 0 ? (
                              <span className="text-slate-400">لا أبناء</span>
                            ) : (
                              <div className="flex flex-wrap gap-1">
                                {children.map(child => (
                                  <button key={child.id} type="button" className="portal-chip" onClick={() => { setSelectedStudentId(child.id); setSelectedParentId(parent.id); setAccountsView('students'); }}>
                                    {child.name}
                                  </button>
                                ))}
                              </div>
                            )}
                          </td>
                          <td>
                            <div className="flex justify-end gap-1">
                              {permissions.canEditParents && (
                                <button type="button" onClick={() => startEditParent(parent)} className="portal-icon-btn" title="تعديل" aria-label={`تعديل ${parent.name}`}><Pencil aria-hidden="true" /></button>
                              )}
                              {permissions.canManageParentPermissions && (
                                <button type="button" onClick={() => openParentPermissions(parent)} className="portal-icon-btn" title="الصلاحيات" aria-label={`صلاحيات ${parent.name}`}><ShieldCheck aria-hidden="true" /></button>
                              )}
                              {permissions.canDeleteParents && (
                                <button type="button" onClick={() => handleDeleteParent(parent.id)} className="portal-icon-btn is-danger" title="حذف" aria-label={`حذف ${parent.name}`}><Trash2 aria-hidden="true" /></button>
                              )}
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </Panel>
        )}

      {/* نموذج إضافة/تعديل طالب */}
      {showStudentForm && (
          <div ref={studentFormView.formRef} className="dashboard-surface dashboard-account-form">
           <div className="dashboard-account-form-inner bg-slate-50 p-8 rounded-2xl border border-slate-200">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <div className="text-4xl">{getStudentEmoji(editingStudent)}</div>
                <h3 className="text-2xl font-black text-gray-800">
                  {editingStudent ? 'تعديل بيانات طالب' : 'إضافة طالب جديد'}
                </h3>
              </div>
              <button
                onClick={resetStudentForm}
                className="text-gray-500 hover:text-gray-700 text-2xl font-bold"
                title="إغلاق"
              >
                <IconX className="inline-block h-[1em] w-[1em] align-[-0.125em]" aria-hidden="true" />
              </button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">اسم الطالب *</label>
                <input
                  type="text"
                  value={studentForm.name}
                  onChange={(e) => setStudentForm({ ...studentForm, name: e.target.value })}
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                />
              </div>
               <div>
                 <label className="block text-sm font-bold text-gray-700 mb-2">جنس الطالب *</label>
                 <select value={studentForm.gender} onChange={e => setStudentForm({ ...studentForm, gender: e.target.value as StudentGender })} className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none" required>
                   {STUDENT_GENDER_OPTIONS.map(option => <option key={option.value} value={option.value}>{option.emoji} {option.label}</option>)}
                 </select>
               </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">ولي الأمر *</label>
                <select
                  value={studentForm.parentId}
                  onChange={(e) => {
                    const parent = parents.find(p => p.id === e.target.value);
                    setStudentForm({
                      ...studentForm,
                      parentId: e.target.value,
                      parentPhoneNumber: parent?.phoneNumber || ''
                    });
                  }}
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                >
                  <option value="">اختر ولي الأمر</option>
                  {parents.map((parent) => (
                    <option key={parent.id} value={parent.id}>
                      {parent.name} - {parent.phoneNumber}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">الصف الأساسي *</label>
                <select
                  value={studentForm.primaryGrade}
                  onChange={(e) => setStudentForm({ ...studentForm, primaryGrade: e.target.value, assignedSubjects: [] })}
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                >
                  <option value="">اختر الصف</option>
                  {grades.map((grade) => (
                    <option key={grade} value={grade}>
                      {grade}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                {/* المواد المتاحة للطالب.
                    لا شيء مؤشَّر = جميع مواد المعلم، وهي الحالة
                    الافتراضية لكل طالب مسجَّل قبل وجود هذا الحقل. */}
                <label className="block text-sm font-bold text-gray-700 mb-2">
                  المواد المتاحة للطالب
                  <span className="font-normal text-gray-500 text-xs">
                    {' '}— {studentForm.assignedSubjects.length === 0
                      ? 'جميع المواد'
                      : `${studentForm.assignedSubjects.length} مادة محددة`}
                  </span>
                </label>
                {availableSubjects.length === 0 ? (
                  <div className="text-gray-400 text-sm p-2">اختر الصف أولاً لعرض مواده.</div>
                ) : (
                  <div className="flex flex-wrap gap-2 rounded-lg border-2 border-gray-200 bg-gray-50 p-3">
                    <label className={`flex cursor-pointer items-center gap-2 rounded-full border px-3 py-1 font-bold ${
                      studentForm.assignedSubjects.length === 0
                        ? 'border-blue-200 bg-blue-100' : 'border-gray-300 bg-white'
                    }`}>
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
                        <label
                          key={subject}
                          className={`flex cursor-pointer items-center gap-2 rounded-full border px-3 py-1 font-bold ${
                            checked ? 'border-green-300 bg-green-100' : 'border-gray-300 bg-white'
                          }`}
                        >
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
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">رقم الطالب</label>
                <input
                  type="text"
                  value={studentForm.studentIdNumber}
                  onChange={(e) => setStudentForm({ ...studentForm, studentIdNumber: e.target.value })}
                  placeholder="اختياري"
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">رقم الهوية</label>
                <input
                  type="text"
                  value={studentForm.nationalId}
                  onChange={(e) => setStudentForm({ ...studentForm, nationalId: e.target.value })}
                  placeholder="اختياري"
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">اسم المستخدم *</label>
                <input
                  type="text"
                  value={studentForm.username}
                  onChange={(e) => setStudentForm({ ...studentForm, username: e.target.value })}
                  placeholder="أدخل اسم المستخدم"
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">كلمة المرور</label>
                <input
                  type="text"
                  value={studentForm.password}
                  onChange={(e) => setStudentForm({ ...studentForm, password: e.target.value })}
                  placeholder={editingStudent ? 'اتركه فارغاً للإبقاء على الحالية' : 'كلمة المرور الافتراضية'}
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                />
              </div>
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-2">إدارة صلاحيات الطالب</label>
                <select
                  value={studentForm.permissionPackageId}
                  onChange={(e) => setStudentForm({ ...studentForm, permissionPackageId: e.target.value })}
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                >
                  <option value="">الصلاحيات العامة الحالية</option>
                  {studentPackages.map(pkg => <option key={pkg.id} value={pkg.id}>{pkg.name}</option>)}
                </select>
              </div>
            </div>

            <div className="flex gap-4 mt-6">
              <button
                onClick={handleSaveStudent}
                className="flex-1 bg-gradient-to-r from-green-600 to-green-700 hover:from-green-700 hover:to-green-800 text-white px-8 py-4 rounded-xl font-bold shadow-lg transform hover:scale-105 transition-all text-lg"
              >
                حفظ التغييرات
              </button>
              <button
                onClick={resetStudentForm}
                className="px-8 py-4 bg-gray-300 hover:bg-gray-400 text-gray-800 rounded-xl font-bold shadow-md transform hover:scale-105 transition-all text-lg"
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}

      {permissionsParent && parentPermissionDraft && (
        <div className="fixed inset-0 z-50 bg-slate-950/60 flex items-center justify-center p-4" onClick={() => { setPermissionsParent(null); setParentPermissionDraft(null); }}>
          <div className="bg-white rounded-3xl shadow-2xl w-full max-w-2xl p-6" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-5">
              <div>
                <h2 className="text-2xl font-black text-slate-800">صلاحيات ولي الأمر</h2>
                <p className="text-slate-500 font-bold mt-1">{permissionsParent.name}</p>
              </div>
              <button onClick={() => { setPermissionsParent(null); setParentPermissionDraft(null); }} className="text-2xl text-slate-400 hover:text-slate-700">✕</button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {([
                ['canCreateStudents', 'إنشاء أبناء'],
                ['canEditStudents', 'تعديل بيانات الأبناء'],
                ['canDeleteStudents', 'حذف الأبناء'],
                ['canResetStudentPassword', 'إعادة تعيين كلمة مرور الأبناء'],
                ['canViewReports', 'عرض التقارير'],
                ['canChangeGrade', 'تغيير الصف'],
                ['canChatWithSupport', 'الدردشة مع الدعم'],
                 ['canCreatePermissionPackages', 'إنشاء بكجات صلاحيات'],
              ] as [keyof ParentPermissions, string][]).map(([key, label]) => (
                <label key={key} className="flex items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-slate-50 p-4 font-bold text-slate-700">
                  <span>{label}</span>
                  <input
                    type="checkbox"
                    checked={Boolean(parentPermissionDraft[key])}
                    onChange={e => setParentPermissionDraft({ ...parentPermissionDraft, [key]: e.target.checked })}
                    className="h-5 w-5 accent-indigo-600"
                  />
                </label>
              ))}
            </div>
            <div className="mt-4 rounded-2xl border border-indigo-100 bg-indigo-50 p-4">
              <label className="block font-black text-indigo-900 mb-2">الحد الأقصى لأبناء ولي الأمر</label>
              <p className="text-xs text-indigo-700 font-bold mb-3">اكتب -1 للسماح بعدد غير محدود.</p>
              <input
                type="number"
                min="-1"
                value={parentPermissionDraft.maxStudents}
                onChange={e => setParentPermissionDraft({ ...parentPermissionDraft, maxStudents: Math.max(-1, Number(e.target.value)) })}
                className="w-full rounded-xl border-2 border-indigo-200 bg-white p-3 font-black outline-none"
              />
            </div>
            <div className="flex gap-3 mt-6">
              <button onClick={saveParentPermissions} className="flex-1 rounded-xl bg-indigo-600 py-3 text-white font-black hover:bg-indigo-700">حفظ الصلاحيات</button>
              <button onClick={() => { setPermissionsParent(null); setParentPermissionDraft(null); }} className="rounded-xl bg-slate-200 px-6 py-3 font-black text-slate-700">إلغاء</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ParentStudentManagement;
