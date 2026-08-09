import React, { useState, useEffect } from 'react';
import { StudentInfo, ParentInfo, HierarchicalConfig, ParentPermissions } from '../../types';
import { STORAGE_KEYS, DEFAULT_PASSWORD } from '../../constants';
import { ensureHashed } from '../../utils/password';
import { getTeacherPermissions, getParentPermissions, isLimitReached } from '../../permissions';
import { getTeacherParents, getTeacherStudents, getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import { resetGamificationForStudent } from '../../utils/gamification';
import { getStudentEmoji, STUDENT_GENDER_OPTIONS, StudentGender } from '../../utils/studentAppearance';

interface ParentStudentManagementProps {
  teacherId: string;
  teacherName: string;
}

const ParentStudentManagement: React.FC<ParentStudentManagementProps> = ({ teacherId, teacherName }) => {
  const [students, setStudents] = useState<StudentInfo[]>([]);
  const [parents, setParents] = useState<ParentInfo[]>([]);
  const [grades, setGrades] = useState<string[]>([]);
  const [subjects, setSubjects] = useState<string[]>([]);
  const [atrams, setAtrams] = useState<string[]>([]);
  const [terms, setTerms] = useState<string[]>([]);
  const [units, setUnits] = useState<string[]>([]);
  const [hierarchicalConfigs, setHierarchicalConfigs] = useState<HierarchicalConfig[]>([]);
  const [availableSubjects, setAvailableSubjects] = useState<string[]>([]);

  const [showParentForm, setShowParentForm] = useState(false);
  const [showStudentForm, setShowStudentForm] = useState(false);
  const [editingParent, setEditingParent] = useState<ParentInfo | null>(null);
  const [editingStudent, setEditingStudent] = useState<StudentInfo | null>(null);
  const [permissionsParent, setPermissionsParent] = useState<ParentInfo | null>(null);
  const [parentPermissionDraft, setParentPermissionDraft] = useState<ParentPermissions | null>(null);

  // الحصول على الصلاحيات
  const permissions = getTeacherPermissions();
  
  const [parentForm, setParentForm] = useState({
    name: '',
    username: '',
    password: DEFAULT_PASSWORD,
    phoneNumber: '',
    nationalId: '',
  });

  const [searchQuery, setSearchQuery] = useState('');
  const [selectedParentId, setSelectedParentId] = useState<string>('all');
  const [selectedStudentId, setSelectedStudentId] = useState<string>('all');

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
    gradeEnrollments: [] as { grade: string; enrollments: { id?: string; subject: string; atram: string; term: string; unit: string }[] }[],
    enrollmentSubject: '',
  });

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
  };

  const loadAcademicSettings = () => {
    setGrades(JSON.parse(localStorage.getItem(STORAGE_KEYS.GRADES) || '[]'));
    setSubjects(JSON.parse(localStorage.getItem(STORAGE_KEYS.SUBJECTS) || '[]'));
    setAtrams(JSON.parse(localStorage.getItem(STORAGE_KEYS.ATRAMS) || '[]'));
    setTerms(JSON.parse(localStorage.getItem(STORAGE_KEYS.TERMS) || '[]'));
    setUnits(JSON.parse(localStorage.getItem(STORAGE_KEYS.UNITS) || '[]'));
    setHierarchicalConfigs(JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]'));
  };

  const getSubjectsForGrade = (grade: string) => {
    if (!grade || !hierarchicalConfigs.length) return subjects;
    const configs = hierarchicalConfigs.filter((c: HierarchicalConfig) =>
      getRecordTeacherId(c) === normalizeScopeValue(teacherId)
    );
    const cfg = configs.find((c: HierarchicalConfig) => c.grade === grade);
    if (!cfg) return subjects;
    const subs = new Set<string>();
    cfg.atrams?.forEach((a: any) => a.subjects?.forEach((s: any) => { if (s.subject) subs.add(s.subject); }));
    return subs.size > 0 ? Array.from(subs) : subjects;
  };

  const handleSaveParent = () => {
    if (!parentForm.name || !parentForm.phoneNumber) {
      alert('الرجاء ملء الحقول المطلوبة');
      return;
    }

    const allParents: ParentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');

    if (!editingParent) {
      if (!permissions.canCreateParents) {
        alert('⚠️ ليس لديك صلاحية إنشاء أولياء أمور');
        return;
      }
      const teacherParents = getTeacherParents(allParents, teacherId);
      if (isLimitReached(teacherParents.length, permissions.maxParents)) {
        alert(`⚠️ وصلت إلى الحد الأقصى المسموح به (${permissions.maxParents}) من أولياء الأمور`);
        return;
      }
    } else if (!permissions.canEditParents) {
      alert('⚠️ ليس لديك صلاحية تعديل أولياء الأمور');
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
        alert(`⚠️ رقم الهوية ${nationalId} مستخدم بالفعل من قبل ولي الأمر: ${duplicateParent.name}`);
        return;
      }
      
      // التحقق من المعلمين
      const allTeachers = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
      const duplicateTeacher = allTeachers.find((t: any) => t.nationalId === nationalId);
      if (duplicateTeacher) {
        alert(`⚠️ رقم الهوية ${nationalId} مستخدم بالفعل من قبل المعلم: ${duplicateTeacher.name}`);
        return;
      }
      
      // التحقق من الطلاب
      const allStudents = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
      const duplicateStudent = allStudents.find((s: any) => s.nationalId === nationalId);
      if (duplicateStudent) {
        alert(`⚠️ رقم الهوية ${nationalId} مستخدم بالفعل من قبل الطالب: ${duplicateStudent.name}`);
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
      };
      allParents.push(newParent);
    }

    localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(allParents));
    loadData();
    resetParentForm();
    alert('تم حفظ ولي الأمر بنجاح!');
  };

  const handleSaveStudent = () => {
    if (!studentForm.name || !studentForm.parentId || !studentForm.primaryGrade || !studentForm.username) {
      alert('الرجاء ملء الحقول المطلوبة (الاسم، ولي الأمر، الصف، اسم المستخدم)');
      return;
    }

    const allStudents: StudentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
    const allParents: ParentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');

    if (!editingStudent) {
      if (!permissions.canCreateStudents) {
        alert('⚠️ ليس لديك صلاحية إنشاء الطلاب');
        return;
      }
      const teacherParents = getTeacherParents(allParents, teacherId);
      const teacherStudents = getTeacherStudents(allStudents, teacherId, teacherParents);
      if (isLimitReached(teacherStudents.length, permissions.maxStudents)) {
        alert(`⚠️ وصلت إلى الحد الأقصى المسموح به (${permissions.maxStudents}) من الطلاب`);
        return;
      }
    } else if (!permissions.canEditStudents) {
      alert('⚠️ ليس لديك صلاحية تعديل الطلاب');
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
        alert(`⚠️ رقم الهوية ${nationalId} مستخدم بالفعل من قبل الطالب: ${duplicateStudent.name}`);
        return;
      }
      
      // التحقق من أولياء الأمور
      const duplicateParent = allParents.find(p => p.nationalId === nationalId);
      if (duplicateParent) {
        alert(`⚠️ رقم الهوية ${nationalId} مستخدم بالفعل من قبل ولي الأمر: ${duplicateParent.name}`);
        return;
      }
      
      // التحقق من المعلمين (استخدام teacherId)
      const allTeachers = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
      const duplicateTeacher = allTeachers.find((t: any) => t.teacherId === nationalId);
      if (duplicateTeacher) {
        alert(`⚠️ رقم الهوية ${nationalId} مستخدم بالفعل من قبل المعلم: ${duplicateTeacher.name}`);
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
          gradeEnrollments: studentForm.gradeEnrollments,
          teacherId,
          createdBy: teacherId,
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
        gradeEnrollments: studentForm.gradeEnrollments,
        subject: studentForm.enrollmentSubject || '',
        createdAt: new Date().toISOString(),
        lastActivity: new Date().toISOString(),
        canChangeGrade: false,
        teacherId,
        createdBy: teacherId, // ربط بالمعلم
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
    loadData();
    resetStudentForm();
    alert('تم حفظ الطالب بنجاح!');
  };

  const handleDeleteParent = (parentId: string) => {    if (!permissions.canDeleteParents) {
      alert('⚠️ ليس لديك صلاحية حذف أولياء الأمور');
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
      alert('⚠️ ليس لديك صلاحية حذف الطلاب');
      return;
    }    if (!confirm('هل أنت متأكد من حذف الطالب؟')) return;
    
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
      alert('⚠️ ليس لديك صلاحية إدارة صلاحيات أولياء الأمور');
      return;
    }
    setPermissionsParent(parent);
    const globalParentPermissions = getParentPermissions();
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
    alert('✅ تم حفظ صلاحيات ولي الأمر');
  };

  const resetParentForm = () => {
    setParentForm({
      name: '',
      username: '',
      password: DEFAULT_PASSWORD,
      phoneNumber: '',
      nationalId: '',
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
      enrollmentSubject: '',
    });
    setShowStudentForm(false);
    setEditingStudent(null);
  };

  const getStudentCountForParent = (parentId: string) => {
    return students.filter(s => s.parentId === parentId).length;
  };

  return (
    <div className="space-y-6">
      {/* العنوان والبحث */}
      <div className="bg-gradient-to-r from-amber-500 to-orange-500 p-6 rounded-2xl text-white shadow-lg">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h1 className="text-3xl font-black mb-2">👥 إدارة أولياء الأمور والطلاب</h1>
            <p className="text-blue-100 font-medium">
              يمكنك إنشاء حسابات أولياء الأمور وإضافة الطلاب لهم
            </p>
          </div>
        </div>
        {/* حقل البحث */}
        <div className="mt-4">
          <div className="relative">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="🔍 ابحث عن ولي أمر أو طالب بالاسم، اسم المستخدم، رقم الجوال، أو رقم الهوية..."
              className="w-full p-4 pr-12 rounded-xl border-2 border-white/30 bg-white/10 text-white placeholder-white/70 focus:bg-white/20 focus:border-white outline-none font-bold text-lg backdrop-blur"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute left-4 top-1/2 -translate-y-1/2 bg-white/20 hover:bg-white/30 text-white px-3 py-1 rounded-lg font-bold text-sm transition-all"
              >
                ✖ مسح
              </button>
            )}
          </div>
        </div>
        {/* قوائم منسدلة لأولياء الأمور والطلاب */}
        <div className="mt-4 grid grid-cols-1 md:grid-cols-2 gap-3">
          <div>
            <label className="text-white/70 text-xs font-bold mb-1 block">👨‍👩‍👧‍👦 ولي الأمر</label>
            <select
              value={selectedParentId}
              onChange={(e) => { setSelectedParentId(e.target.value); setSelectedStudentId('all'); }}
              className="w-full p-2.5 rounded-xl bg-white/10 text-white border border-white/30 font-bold text-sm focus:bg-white/20 focus:border-white outline-none backdrop-blur"
            >
              <option value="all" className="text-gray-800">جميع أولياء الأمور</option>
              {parents.map(p => (
                <option key={p.id} value={p.id} className="text-gray-800">{p.name} — {p.phoneNumber}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-white/70 text-xs font-bold mb-1 block">🎓 الطالب</label>
            <select
              value={selectedStudentId}
              onChange={(e) => { setSelectedStudentId(e.target.value); setSelectedParentId('all'); }}
              className="w-full p-2.5 rounded-xl bg-white/10 text-white border border-white/30 font-bold text-sm focus:bg-white/20 focus:border-white outline-none backdrop-blur"
            >
              <option value="all" className="text-gray-800">جميع الطلاب</option>
              {(selectedParentId === 'all' ? students : students.filter(s => s.parentId === selectedParentId)).map(s => (
                <option key={s.id} value={s.id} className="text-gray-800">{s.name} — {s.primaryGrade}</option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* إحصائيات */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-gradient-to-br from-green-500 to-green-600 p-6 rounded-2xl text-white shadow-lg">
          <div className="text-5xl mb-2">👨‍👩‍👧‍👦</div>
          <div className="text-3xl font-black">{parents.length}</div>
          <div className="text-green-100 font-medium">ولي أمر</div>
        </div>

        <div className="bg-gradient-to-br from-blue-500 to-blue-600 p-6 rounded-2xl text-white shadow-lg">
          <div className="text-5xl mb-2">🎓</div>
          <div className="text-3xl font-black">{students.length}</div>
          <div className="text-blue-100 font-medium">طالب</div>
        </div>
      </div>

      {/* قسم أولياء الأمور */}
      <div className="bg-white p-6 rounded-2xl shadow-lg">
        {/* إذا كان نموذج ولي الأمر مفتوحاً، اخفِ القائمة */}
        {!showParentForm && !showStudentForm && (
          <>
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-2xl font-black text-gray-800">👨‍👩‍👧‍👦 أولياء الأمور والطلاب</h2>
              <div className="flex gap-3">
                {permissions.canCreateStudents && (
                  <button
                    onClick={() => setShowStudentForm(true)}
                    className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-xl font-bold transition-all"
                  >
                    ➕ إضافة طالب
                  </button>
                )}
                {permissions.canCreateParents && (
                  <button
                    onClick={() => setShowParentForm(true)}
                    className="bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-xl font-bold transition-all"
                  >
                    ➕ إضافة ولي أمر
                  </button>
                )}
                {!permissions.canCreateStudents && !permissions.canCreateParents && (
                  <div className="text-amber-600 font-bold text-sm bg-amber-50 px-4 py-3 rounded-xl">
                    🔒 ليس لديك صلاحيات لإضافة حسابات جديدة
                  </div>
                )}
              </div>
            </div>
          </>
        )}

        {showParentForm && (
          <div className="bg-gradient-to-br from-amber-50 to-orange-50 p-8 rounded-2xl border-2 border-amber-300 shadow-2xl">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <div className="text-4xl">👤</div>
                <h3 className="text-2xl font-black text-gray-800">
                  {editingParent ? 'تعديل بيانات ولي أمر' : 'إضافة ولي أمر جديد'}
                </h3>
              </div>
              <button
                onClick={resetParentForm}
                className="text-gray-500 hover:text-gray-700 text-2xl font-bold"
                title="إغلاق"
              >
                ✖
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
            </div>
            <div className="flex gap-3 mt-6">
              <button
                onClick={handleSaveParent}
                className="flex-1 bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-700 hover:to-blue-800 text-white px-8 py-4 rounded-xl font-bold text-lg transition-all shadow-lg"
              >
                💾 حفظ التغييرات
              </button>
              <button
                onClick={resetParentForm}
                className="px-8 py-4 bg-gray-300 hover:bg-gray-400 text-gray-800 rounded-xl font-bold text-lg transition-all"
              >
                ❌ إلغاء
              </button>
            </div>
          </div>
        )}

        {/* عرض أولياء الأمور والطلاب بشكل هرمي - يظهر فقط عندما لا يكون هناك نموذج مفتوح */}
        {!showParentForm && !showStudentForm && (
        <div className="space-y-4">
          {(() => {
            const search = searchQuery.toLowerCase();

            // ── فلترة الطلاب المنفردة ──
            if (selectedStudentId !== 'all') {
              let filteredStudents = students.filter(s => {
                if (!searchQuery) return true;
                return s.name.toLowerCase().includes(search) ||
                  (s.username || '').toLowerCase().includes(search) ||
                  (s.nationalId || '').includes(search) ||
                  (s.studentIdNumber || '').includes(search);
              });
              if (selectedStudentId !== 'all') {
                filteredStudents = filteredStudents.filter(s => s.id === selectedStudentId);
              }
              if (filteredStudents.length === 0) return (
                <div className="text-center py-20">
                  <div className="text-6xl mb-4">🎓</div>
                  <p className="text-gray-600 font-bold text-xl mb-2">لا يوجد طلاب</p>
                </div>
              );
              return (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {filteredStudents.map(student => {
                    const parent = parents.find(p => p.id === student.parentId);
                    return (
                      <div key={student.id} className="bg-gradient-to-r from-amber-50 to-orange-50 p-4 rounded-xl border-2 border-amber-200">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-3">
                             <div className="w-12 h-12 bg-gradient-to-br from-amber-500 to-orange-600 rounded-full flex items-center justify-center text-white text-2xl">{getStudentEmoji(student)}</div>
                            <div>
                              <h3 className="text-lg font-black text-gray-800">{student.name}</h3>
                              <p className="text-xs text-gray-500">الصف: {student.primaryGrade} {parent && `· ولي الأمر: ${parent.name}`}</p>
                            </div>
                          </div>
                          <div className="flex gap-2">
                            <button onClick={() => handleResetStudentCounter(student)} className="bg-indigo-500 hover:bg-indigo-600 text-white px-3 py-1 rounded-lg font-bold text-sm">♻️</button>
                            {permissions.canEditStudents && (
                               <button onClick={() => { setEditingStudent(student); setStudentForm({ name: student.name, gender: student.gender || 'male', username: student.username || '', password: '', parentPhoneNumber: student.parentPhoneNumber, parentId: student.parentId || '', studentIdNumber: student.studentIdNumber || '', nationalId: student.nationalId || '', primaryGrade: student.primaryGrade, gradeEnrollments: student.gradeEnrollments || [], enrollmentSubject: student.subject || '' }); setShowStudentForm(true); }} className="bg-yellow-500 hover:bg-yellow-600 text-white px-3 py-1 rounded-lg font-bold text-sm">✏️</button>
                            )}
                            {permissions.canDeleteStudents && (
                              <button onClick={() => handleDeleteStudent(student.id)} className="bg-red-500 hover:bg-red-600 text-white px-3 py-1 rounded-lg font-bold text-sm">🗑️</button>
                            )}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              );
            }

            // ── فلترة أولياء الأمور ──
            let filteredParents = parents.filter(parent => {
              const parentMatches = parent.name.toLowerCase().includes(search) ||
                parent.phoneNumber.includes(search) ||
                (parent.nationalId || '').includes(search) ||
                (parent.username || '').toLowerCase().includes(search);
              if (parentMatches) return true;
              const parentStudents = students.filter(s => s.parentId === parent.id);
              const hasMatchingStudent = parentStudents.some(student =>
                student.name.toLowerCase().includes(search) ||
                (student.username || '').toLowerCase().includes(search) ||
                (student.nationalId || '').includes(search) ||
                (student.studentIdNumber || '').includes(search)
              );
              return hasMatchingStudent;
            });
            if (selectedParentId !== 'all') {
              filteredParents = filteredParents.filter(p => p.id === selectedParentId);
            }

            if (filteredParents.length === 0) return (
              <div className="text-center py-20">
                <div className="text-6xl mb-4">🔍</div>
                <p className="text-gray-600 font-bold text-xl mb-2">لا توجد نتائج</p>
              </div>
            );

            return filteredParents.map((parent) => {
              const parentStudents = students.filter(s => s.parentId === parent.id);
              return (
                <div key={parent.id} className="bg-gradient-to-r from-gray-50 to-orange-50 p-4 rounded-xl border-2 border-amber-200">
                  {/* معلومات ولي الأمر */}
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-3">
                      <div className="w-12 h-12 bg-gradient-to-br from-green-500 to-green-600 rounded-full flex items-center justify-center text-white text-2xl">👤</div>
                      <div>
                        <h3 className="text-xl font-black text-gray-800">{parent.name}</h3>
                        <p className="text-sm text-gray-600">📱 {parent.phoneNumber}</p>
                        {parent.nationalId && <p className="text-sm text-gray-600">🆔 {parent.nationalId}</p>}
                      </div>
                      <span className="bg-blue-600 text-white px-3 py-1 rounded-full font-bold text-sm">{parentStudents.length} طالب/طلاب</span>
                    </div>
                    <div className="flex gap-2">
                      {permissions.canEditParents && (
                        <button onClick={() => { setEditingParent(parent); setParentForm({ name: parent.name, username: parent.username, password: '', phoneNumber: parent.phoneNumber, nationalId: parent.nationalId || '' }); setShowParentForm(true); }} className="bg-yellow-500 hover:bg-yellow-600 text-white px-4 py-2 rounded-lg font-bold">✏️ تعديل</button>
                      )}
                      {permissions.canManageParentPermissions && (
                        <button
                          onClick={() => openParentPermissions(parent)}
                          className="bg-indigo-500 hover:bg-indigo-600 text-white px-4 py-2 rounded-lg font-bold"
                        >
                          🔐 الصلاحيات
                        </button>
                      )}
                      {permissions.canDeleteParents && (
                        <button onClick={() => handleDeleteParent(parent.id)} className="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg font-bold">🗑️ حذف</button>
                      )}
                    </div>
                  </div>

                  {/* قائمة الطلاب التابعين — تُعرض فقط في وضع الكل أو أولياء الأمور */}
                  {parentStudents.length > 0 && (
                    <div className="mt-3 mr-16 space-y-2">
                      <h4 className="text-sm font-bold text-gray-700 mb-2">🎓 الطلاب:</h4>
                      {parentStudents.map((student) => {
                        const studentMatches = searchQuery && (
                          student.name.toLowerCase().includes(search) ||
                          (student.username || '').toLowerCase().includes(search) ||
                          (student.nationalId || '').includes(search) ||
                          (student.studentIdNumber || '').includes(search)
                        );
                        return (
                        <div
                          key={student.id}
                          className={`bg-white p-3 rounded-lg border-2 flex items-center justify-between transition-all ${
                            studentMatches
                              ? 'border-yellow-400 bg-yellow-50 shadow-lg'
                              : 'border-gray-200'
                          }`}
                        >
                          <div className="flex items-center gap-3">
                            <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xl ${
                              studentMatches ? 'bg-yellow-200' : 'bg-blue-100'
                            }`}>
                              {getStudentEmoji(student)}
                            </div>
                            <div>
                              <p className="font-bold text-gray-800">
                                {student.name}
                                {studentMatches && <span className="mr-2 text-yellow-600">⭐</span>}
                              </p>
                              <p className="text-xs text-gray-500">الصف: {student.primaryGrade}</p>
                            </div>
                          </div>
                          <div className="flex gap-2">
                            <button onClick={() => handleResetStudentCounter(student)} className="bg-indigo-500 hover:bg-indigo-600 text-white px-3 py-1 rounded-lg font-bold text-sm">♻️</button>
                            {permissions.canEditStudents && (
                               <button onClick={() => { setEditingStudent(student); setStudentForm({ name: student.name, gender: student.gender || 'male', username: student.username || '', password: '', parentPhoneNumber: student.parentPhoneNumber, parentId: student.parentId || '', studentIdNumber: student.studentIdNumber || '', nationalId: student.nationalId || '', primaryGrade: student.primaryGrade, gradeEnrollments: student.gradeEnrollments || [], enrollmentSubject: student.subject || '' }); setShowStudentForm(true); }} className="bg-yellow-500 hover:bg-yellow-600 text-white px-3 py-1 rounded-lg font-bold text-sm">✏️</button>
                            )}
                            {permissions.canDeleteStudents && (
                              <button onClick={() => handleDeleteStudent(student.id)} className="bg-red-500 hover:bg-red-600 text-white px-3 py-1 rounded-lg font-bold text-sm">🗑️</button>
                            )}
                          </div>
                        </div>
                        );
                      })}
                    </div>
                  )}
                  {parentStudents.length === 0 && (
                    <div className="mt-3 mr-16 text-sm text-gray-500 italic">
                      لا يوجد طلاب لهذا ولي الأمر
                    </div>
                  )}
                </div>
              );
            });
          })()}
        </div>
      )}
      </div>

      {/* نموذج إضافة/تعديل طالب */}
      {showStudentForm && (
        <div className="bg-white p-6 rounded-2xl shadow-lg">
          <div className="bg-gradient-to-br from-green-50 to-orange-50 p-8 rounded-2xl border-2 border-green-300 shadow-2xl">
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
                ✖
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
                  onChange={(e) => { setStudentForm({ ...studentForm, primaryGrade: e.target.value }); const subs = getSubjectsForGrade(e.target.value); setAvailableSubjects(subs); }}
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
                <label className="block text-sm font-bold text-gray-700 mb-2">المادة *</label>
                <select
                  value={studentForm.enrollmentSubject || ''}
                  onChange={(e) => setStudentForm({ ...studentForm, enrollmentSubject: e.target.value })}
                  className="w-full p-3 border-2 border-gray-300 rounded-lg focus:border-blue-500 outline-none"
                  required
                >
                  <option value="">اختر المادة</option>
                  {availableSubjects.map((s, i) => (
                    <option key={i} value={s}>{s}</option>
                  ))}
                </select>
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
            </div>

            <div className="flex gap-4 mt-6">
              <button
                onClick={handleSaveStudent}
                className="flex-1 bg-gradient-to-r from-green-600 to-green-700 hover:from-green-700 hover:to-green-800 text-white px-8 py-4 rounded-xl font-bold shadow-lg transform hover:scale-105 transition-all text-lg"
              >
                💾 حفظ التغييرات
              </button>
              <button
                onClick={resetStudentForm}
                className="px-8 py-4 bg-gray-300 hover:bg-gray-400 text-gray-800 rounded-xl font-bold shadow-md transform hover:scale-105 transition-all text-lg"
              >
                ❌ إلغاء
              </button>
            </div>
          </div>
        </div>
      )}

      {permissionsParent && parentPermissionDraft && (
        <div className="fixed inset-0 z-50 bg-slate-950/60 flex items-center justify-center p-4" onClick={() => { setPermissionsParent(null); setParentPermissionDraft(null); }}>
          <div className="bg-white rounded-3xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto p-6" onClick={e => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-5">
              <div>
                <h2 className="text-2xl font-black text-slate-800">🔐 صلاحيات ولي الأمر</h2>
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
              <button onClick={saveParentPermissions} className="flex-1 rounded-xl bg-indigo-600 py-3 text-white font-black hover:bg-indigo-700">💾 حفظ الصلاحيات</button>
              <button onClick={() => { setPermissionsParent(null); setParentPermissionDraft(null); }} className="rounded-xl bg-slate-200 px-6 py-3 font-black text-slate-700">إلغاء</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ParentStudentManagement;
