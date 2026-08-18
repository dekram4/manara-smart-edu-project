
import React, { useState, useEffect, useMemo } from 'react';
import { ParentInfo, StudentInfo, TeacherInfo, QuizResult, ParentMenuType, CertificateRecord, HierarchicalConfig, QuizType } from '../../types';
import { STORAGE_KEYS, DEFAULT_PASSWORD } from '../../constants';
import { hashPassword, passwordsMatch } from '../../utils/password';
import ParentLogin from './ParentLogin';
import ParentAccountSetup from './ParentAccountSetup';
import { getEffectiveParentPermissions, getStudentPermissions, isLimitReached } from '../../permissions';
import PrivateChat from '../shared/PrivateChat';
import { playWelcomeAdult } from '../../utils/sounds';
import { getParentChildren, getParentTeacherId, getRecordTeacherId, getStudentTeacherScope } from '../../utils/scope';
import ManaraBrand from '../../components/ManaraBrand';
import PermissionPackageManagement from '../shared/PermissionPackageManagement';
import { getStudentEmoji, STUDENT_GENDER_OPTIONS, StudentGender } from '../../utils/studentAppearance';
import { getStudentProgressSummary } from '../../utils/studentProgress';
import { getQuizTypeLabel as formatQuizTypeLabel, normalizeQuizType as normalizeAssessmentType } from '../../utils/quizTypes';
import { getQuizResultPercentage, getQuizResultScore } from '../../utils/quizScoring';
import { readActiveSession, readStorageArray, removeActiveSession, writeActiveSession } from '../../utils/storage';
import { writeAuthSession } from '../../utils/authSession';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LineChart, Line,
  PieChart, Pie, Cell, Legend, RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis, Radar
} from 'recharts';

const CERT_KEY = 'smartEdu_certificates';

const ParentDashboard: React.FC<{ onLogout: () => void }> = ({ onLogout }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [parent, setParent] = useState<ParentInfo | null>(null);
  const [activeChild, setActiveChild] = useState<StudentInfo | null>(null);
  const [activeSubject, setActiveSubject] = useState<string | null>(null);
  const [menuType, setMenuType] = useState<ParentMenuType>(ParentMenuType.DASHBOARD);
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const [children, setChildren] = useState<StudentInfo[]>([]);
  const [allQuizzes, setAllQuizzes] = useState<QuizResult[]>([]);
  const [needsPasswordChange, setNeedsPasswordChange] = useState(false);
  const [showChat, setShowChat] = useState(false);
  const [showChangeGradeModal, setShowChangeGradeModal] = useState(false);
  const [studentToChangeGrade, setStudentToChangeGrade] = useState<StudentInfo | null>(null);
  const [availableGrades, setAvailableGrades] = useState<string[]>([]);
  const [selectedNewGrade, setSelectedNewGrade] = useState('');
  const [currentPasswordDraft, setCurrentPasswordDraft] = useState('');
  const [newPasswordDraft, setNewPasswordDraft] = useState('');
  const [confirmPasswordDraft, setConfirmPasswordDraft] = useState('');
  const [passwordSaveError, setPasswordSaveError] = useState('');

  const permissions = getEffectiveParentPermissions(parent);

  /* Dashboard filter */
  const [dashFilter, setDashFilter] = useState('');
  const [teacherResultStudentFilter, setTeacherResultStudentFilter] = useState('all');
  const [teacherResultQuizFilter, setTeacherResultQuizFilter] = useState('all');
  const [teacherResultParentFilter, setTeacherResultParentFilter] = useState('all');
  const [teacherResultSubjectFilter, setTeacherResultSubjectFilter] = useState('all');

  /* Certificates state */
  const [certSearch, setCertSearch] = useState('');
  const [certFilterType, setCertFilterType] = useState<'all' | 'excellence' | 'appreciation' | 'participation'>('all');
  const [certSelectedChild, setCertSelectedChild] = useState<StudentInfo | null>(null);
  const [previewCert, setPreviewCert] = useState<CertificateRecord | null>(null);

  const [showAddChildForm, setShowAddChildForm] = useState(false);
  const [newChild, setNewChild] = useState({
    name: '',
    gender: 'male' as StudentGender,
    username: '',
    password: '',
    studentIdNumber: '',
    primaryGrade: '',
    gradeEnrollments: [] as { grade: string; enrollments: { id?: string; subject: string; atram: string; term: string; unit: string }[] }[],
    currentGradeForEnrollment: '',
    enrollmentSubject: '',
    enrollmentAtram: '',
    enrollmentTerm: '',
    enrollmentUnit: '',
  });

  const [grades, setGrades] = useState<string[]>([]);
  const [subjects, setSubjects] = useState<string[]>([]);
  const [atrams, setAtrams] = useState<string[]>([]);
  const [terms, setTerms] = useState<string[]>([]);
  const [units, setUnits] = useState<string[]>([]);
  const [gradeConfigs, setGradeConfigs] = useState<any[]>([]);
  const [hierarchicalConfigs, setHierarchicalConfigs] = useState<HierarchicalConfig[]>([]);
  const [availableSubjects, setAvailableSubjects] = useState<string[]>([]);

  useEffect(() => {
    loadAcademicSettings();
    loadData();
  }, []);

  useEffect(() => {
    const interval = window.setInterval(() => {
      if (isAuthenticated) loadChildrenOnly();
    }, 5000);
    return () => window.clearInterval(interval);
  }, [isAuthenticated, activeChild]);

  const loadChildrenOnly = () => {
    const activeUser = readActiveSession<ParentInfo>(STORAGE_KEYS.ACTIVE_PARENT);
    if (activeUser) {
      const allStudents = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
      const myChildren = getParentChildren(allStudents, activeUser);
      setChildren(myChildren);
      const childIds = new Set(myChildren.map(child => child.id));
      const allQuizzes = readStorageArray<QuizResult>(STORAGE_KEYS.QUIZ_RESULTS);
       setAllQuizzes(allQuizzes
         .filter((quiz: QuizResult) => childIds.has(quiz.studentId))
         .map((quiz: QuizResult) => ({ ...quiz, percentage: getQuizResultPercentage(quiz) })));
      setActiveChild(current =>
        current ? myChildren.find(child => child.id === current.id) || null : null,
      );
    }
  };

  const loadAcademicSettings = () => {
    setGrades(readStorageArray<string>(STORAGE_KEYS.GRADES));
    setSubjects(readStorageArray<string>(STORAGE_KEYS.SUBJECTS));
    setAtrams(readStorageArray<string>(STORAGE_KEYS.ATRAMS));
    setTerms(readStorageArray<string>(STORAGE_KEYS.TERMS));
    setUnits(readStorageArray<string>(STORAGE_KEYS.UNITS));
    setGradeConfigs(readStorageArray(STORAGE_KEYS.GRADE_CONFIGS));
    setHierarchicalConfigs(readStorageArray<HierarchicalConfig>(STORAGE_KEYS.HIERARCHICAL_CONFIGS));
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
    return (cfg.enrollments || []).map((en: any, idx: number) => ({
      id: en.id || `gcfg-${Date.now()}-${idx}`,
      subject: en.subject,
      atram: en.atram || '',
      term: en.term || '',
      unit: en.unit || ''
    }));
  };

  const getSubjectsForGrade = (grade: string, teacherId?: string) => {
    if (!grade || !hierarchicalConfigs.length) return subjects;
    const configs = teacherId
      ? hierarchicalConfigs.filter((c: HierarchicalConfig) => getRecordTeacherId(c) === teacherId.toLowerCase())
      : hierarchicalConfigs;
    const cfg = configs.find((c: HierarchicalConfig) => c.grade === grade);
    if (!cfg) return subjects;
    const subs = new Set<string>();
    cfg.atrams?.forEach((a: any) => a.subjects?.forEach((s: any) => { if (s.subject) subs.add(s.subject); }));
    return subs.size > 0 ? Array.from(subs) : subjects;
  };

  const loadData = () => {
      const activeUser = readActiveSession<ParentInfo>(STORAGE_KEYS.ACTIVE_PARENT);
    if (activeUser) {
      setParent(activeUser);
      setIsAuthenticated(true);
      const allStudents = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
       const myChildren = getParentChildren(allStudents, activeUser);
      setChildren(myChildren);
      const childIds = new Set(myChildren.map(child => child.id));
      const allQuizzes = readStorageArray<QuizResult>(STORAGE_KEYS.QUIZ_RESULTS);
       setAllQuizzes(allQuizzes
         .filter((quiz: QuizResult) => childIds.has(quiz.studentId))
         .map((quiz: QuizResult) => ({ ...quiz, percentage: getQuizResultPercentage(quiz) })));
      setActiveChild(null);
    }
  };

  const handleLogin = (username: string, pass: string) => {
    const parents = readStorageArray<ParentInfo>(STORAGE_KEYS.PARENTS);
    const found = parents.find((p: ParentInfo) => p.username === username && passwordsMatch(pass, p.password));
    if (found) {
      if (found.mustChangePassword === true) {
        setParent(found);
        setNeedsPasswordChange(true);
      } else {
        writeActiveSession(STORAGE_KEYS.ACTIVE_PARENT, found);
        writeAuthSession('parent', found.id);
        loadData();
        playWelcomeAdult();
      }
    } else {
      alert('خطأ في البيانات');
    }
  };

  const handleAccountPasswordChange = (newPass: string) => {
    if (!parent) return;
    const parents = readStorageArray<ParentInfo>(STORAGE_KEYS.PARENTS);
    const updated = parents.map((p: ParentInfo) => p.id === parent.id ? { ...p, password: hashPassword(newPass), mustChangePassword: false } : p);
    localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(updated));
    const finalParent = updated.find((p: any) => p.id === parent.id);
    writeActiveSession(STORAGE_KEYS.ACTIVE_PARENT, finalParent);
    setNeedsPasswordChange(false);
    loadData();
  };

  const handleSavePassword = (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordSaveError('');

    if (!parent || !passwordsMatch(currentPasswordDraft, parent.password)) {
      setPasswordSaveError('كلمة المرور الحالية غير صحيحة');
      return;
    }
    if (newPasswordDraft.length < 6) {
      setPasswordSaveError('كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (newPasswordDraft === currentPasswordDraft) {
      setPasswordSaveError('كلمة المرور الجديدة يجب أن تكون مختلفة عن الحالية');
      return;
    }
    if (newPasswordDraft !== confirmPasswordDraft) {
      setPasswordSaveError('تأكيد كلمة المرور غير متطابق');
      return;
    }

    handleAccountPasswordChange(newPasswordDraft);
    setCurrentPasswordDraft('');
    setNewPasswordDraft('');
    setConfirmPasswordDraft('');
    alert('✅ تم حفظ تعديلات الحساب بنجاح');
  };

  const handleAddChild = (e: React.FormEvent) => {
    e.preventDefault();
    if (!permissions.canCreateStudents) {
      alert('⚠️ ليس لديك صلاحية إضافة أبناء جدد');
      return;
    }
    if (!newChild.name || !newChild.password || !newChild.studentIdNumber || !newChild.primaryGrade) {
      alert('يرجى ملء الحقول المطلوبة');
      return;
    }
    if (newChild.password.length < 6) {
      alert('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    const studentsList = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
    const currentChildren = parent ? getParentChildren(studentsList, parent) : [];
    if (isLimitReached(currentChildren.length, permissions.maxStudents)) {
      alert(`⚠️ وصلت إلى الحد الأقصى المسموح به (${permissions.maxStudents}) من الأبناء`);
      return;
    }
    if (studentsList.some((s: any) => s.studentIdNumber === newChild.studentIdNumber)) {
      alert('رقم الهوية موجود بالفعل');
      return;
    }
    if (newChild.username && studentsList.some((s: any) => s.username === newChild.username)) {
      alert('اسم المستخدم موجود بالفعل');
      return;
    }

    const parentTeacherId = parent
      ? getParentTeacherId(parent, studentsList)
      : '';
    let gradeEnrollments = newChild.gradeEnrollments.length > 0 ? newChild.gradeEnrollments : [];
    if (gradeEnrollments.length === 0) {
      try {
        const configs = readStorageArray(STORAGE_KEYS.GRADE_CONFIGS);
        const found = configs.find((c: any) => c.grade === newChild.primaryGrade);
        const flattened = flattenGradeConfig(found);
        if (flattened.length > 0) gradeEnrollments = [{ grade: newChild.primaryGrade, enrollments: flattened }];
      } catch (e) { /* ignore */ }
    }
    if (gradeEnrollments.length === 0) {
      gradeEnrollments = [{ grade: newChild.primaryGrade, enrollments: [{ id: Date.now().toString(), subject: newChild.enrollmentSubject || subjects[0] || '', atram: atrams[0] || '', term: terms[0] || '', unit: units[0] || '' }] }];
    }

    const child: StudentInfo = {
      id: Date.now().toString(),
      name: newChild.name,
      gender: newChild.gender,
      password: hashPassword(newChild.password),
      username: newChild.username && newChild.username.trim() ? newChild.username.trim() : (newChild.studentIdNumber ? `stu_${newChild.studentIdNumber}` : `stu_${Date.now().toString().slice(-5)}`),
      parentPhoneNumber: parent?.phoneNumber || '',
      parentId: parent?.id || undefined,
      studentIdNumber: newChild.studentIdNumber,
      primaryGrade: newChild.primaryGrade,
      gradeEnrollments: gradeEnrollments,
      grade: newChild.primaryGrade,
      subject: newChild.enrollmentSubject || gradeEnrollments[0]?.enrollments[0]?.subject || '',
      atram: gradeEnrollments[0]?.enrollments[0]?.atram || '',
      term: gradeEnrollments[0]?.enrollments[0]?.term || '',
      unit: gradeEnrollments[0]?.enrollments[0]?.unit || '',
      canChangeGrade: false,
      createdAt: new Date().toISOString(),
      lastActivity: new Date().toISOString(),
       ...(parentTeacherId ? {
         teacherId: parentTeacherId,
         createdBy: parentTeacherId,
       } : {}),
    };

    const updatedStudents = [...studentsList, child];
    localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(updatedStudents));
    const parentsList = readStorageArray<ParentInfo>(STORAGE_KEYS.PARENTS);
    const updatedParents = parentsList.map((p: ParentInfo) => p.id === parent?.id ? { ...p, children: [...(p.children || []), child] } : p);
    localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(updatedParents));
    const refreshedParent = updatedParents.find((p: ParentInfo) => p.id === parent?.id);
    writeActiveSession(STORAGE_KEYS.ACTIVE_PARENT, refreshedParent);
    setParent(refreshedParent);
     if (parent) setChildren(getParentChildren(updatedStudents, parent));
    setNewChild({ name: '', gender: 'male', username: '', password: '', studentIdNumber: '', primaryGrade: '', gradeEnrollments: [], currentGradeForEnrollment: '', enrollmentSubject: '', enrollmentAtram: '', enrollmentTerm: '', enrollmentUnit: '' });
    setShowAddChildForm(false);
    alert(`تمت إضافة ${newChild.name} بنجاح!`);
  };

  const handleResetStudentPassword = (child: StudentInfo) => {
    if (!permissions.canResetStudentPassword) {
      alert('⚠️ ليس لديك صلاحية إعادة تعيين كلمة مرور الأبناء');
      return;
    }
    const newPass = prompt(`أدخل كلمة مرور جديدة لـ ${child.name}:`, DEFAULT_PASSWORD);
    if (newPass) {
      if (newPass.length < 6) { alert('كلمة المرور قصيرة جداً'); return; }
      const students = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
      const updated = students.map((s: StudentInfo) => s.id === child.id ? { ...s, password: hashPassword(newPass) } : s);
      localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(updated));
      alert('تم تغيير كلمة المرور بنجاح');
      loadData();
    }
  };

  const handleChangeStudentGrade = (child: StudentInfo) => {
    if (!permissions.canChangeGrade) { alert('❌ ليس لديك صلاحية تغيير الصف'); return; }
    const students = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
    const teacherId = parent ? getParentTeacherId(parent, students) : '';
    if (!teacherId) { alert('⚠️ لم يتم العثور على معلم مرتبط بحسابك'); return; }
    const hierarchicalConfigs = readStorageArray(STORAGE_KEYS.HIERARCHICAL_CONFIGS);
     const teacherConfigs = hierarchicalConfigs.filter((config: any) => getRecordTeacherId(config) === teacherId);
    const gradesSet = new Set<string>();
    teacherConfigs.forEach((config: any) => { if (config.grade) gradesSet.add(config.grade); });
    const grades = Array.from(gradesSet).sort();
    if (grades.length === 0) { alert('⚠️ لم يتم العثور على صفوف متاحة'); return; }
    setAvailableGrades(grades);
    setStudentToChangeGrade(child);
    setSelectedNewGrade(child.primaryGrade || child.grade || grades[0]);
    setShowChangeGradeModal(true);
  };

  const handleConfirmGradeChange = () => {
    if (!studentToChangeGrade || !selectedNewGrade) return;
    const students = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
    const updated = students.map((s: StudentInfo) => s.id === studentToChangeGrade.id ? { ...s, primaryGrade: selectedNewGrade, grade: selectedNewGrade } : s);
    localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(updated));
    alert('✅ تم تغيير الصف بنجاح');
    setShowChangeGradeModal(false);
    setStudentToChangeGrade(null);
    setSelectedNewGrade('');
    loadData();
    loadChildrenOnly();
  };

  /* ===== Helpers ===== */
  const getChildQuizzes = (childId: string) => allQuizzes.filter(q => q.studentId === childId);
  const normalizeQuizType = (quizType: string | undefined) => normalizeAssessmentType(quizType);
  const getQuizTypeLabel = (quizType: string | undefined) => {
    return formatQuizTypeLabel(quizType);
  };
  const getChildAverage = (childId: string) => {
    const qs = getChildQuizzes(childId);
    return qs.length > 0 ? (qs.reduce((a, q) => a + q.percentage, 0) / qs.length).toFixed(0) : '0';
  };
  const getChildSubjects = (child: StudentInfo) => {
    const set = new Set<string>();
    try {
      const allConfigs = readStorageArray(STORAGE_KEYS.HIERARCHICAL_CONFIGS);
      const studentScope = getStudentTeacherScope(child);
      const teacherId = studentScope.teacherId || (
        studentScope.explicit
          ? ''
          : parent
            ? getParentTeacherId(parent, children)
            : ''
      );
      const configs = teacherId
        ? allConfigs.filter((c: any) => getRecordTeacherId(c) === teacherId)
        : studentScope.explicit ? [] : allConfigs;
      configs.filter((c: any) => c.grade === child.primaryGrade || c.grade === child.grade).forEach((cfg: any) => {
        if (cfg.atrams?.forEach) cfg.atrams.forEach((a: any) => a.subjects?.forEach((s: any) => { if (s.subject) set.add(s.subject); }));
      });
    } catch (e) { /* ignore */ }
    if (set.size === 0) {
      getChildQuizzes(child.id).forEach(q => set.add(q.subject));
    }
    return Array.from(set);
  };

  const getAllCertificates = (): CertificateRecord[] => {
    try { return JSON.parse(localStorage.getItem(CERT_KEY) || '[]'); } catch { return []; }
  };

  const filteredCertificates = useMemo(() => {
    let certs = getAllCertificates().filter((c: CertificateRecord) => children.some(ch => ch.id === c.studentId));
    if (certSelectedChild) certs = certs.filter(c => c.studentId === certSelectedChild.id);
    if (certFilterType !== 'all') certs = certs.filter(c => c.type === certFilterType);
    if (certSearch.trim()) {
      const q = certSearch.trim().toLowerCase();
      certs = certs.filter(c =>
        c.studentName.toLowerCase().includes(q) ||
        c.subject.toLowerCase().includes(q) ||
        c.grade.toLowerCase().includes(q) ||
        (c.type === 'excellence' && 'تفوق'.includes(q)) ||
        (c.type === 'appreciation' && 'شكر تقدير'.includes(q)) ||
        (c.type === 'participation' && 'مشاركة'.includes(q))
      );
    }
    return certs.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  }, [children, certSelectedChild, certFilterType, certSearch]);

  const printCertificate = (cert: CertificateRecord) => {
    const date = new Date(cert.date).toLocaleDateString('ar-SA', { year: 'numeric', month: 'long', day: 'numeric' });
    const typeMap: Record<string, { title: string; emoji: string; color: string; grad: string; message: string }> = {
      excellence: { title: 'شهادة تفوق وامتياز', emoji: '🏆', color: '#FFD700', grad: 'linear-gradient(135deg, #FFD700 0%, #FFA500 100%)',
        message: `يسرنا أن نشهد بأن الطالب/ة <strong>${cert.studentName}</strong> قد أظهر/ت تفوقاً ملحوظاً وأداءً متميزاً في دراسة مادة <strong>${cert.subject}</strong> للترم <strong>${cert.atram}</strong>، حيث حقق/ت معدلاً عاماً قدره <strong>${cert.average !== undefined ? cert.average + '%' : 'ممتاز'}</strong>. نفخر بإنجازاتك المتميزة ونتمنى لك مزيداً من التقدم والنجاح في مسيرتك التعليمية.` },
      appreciation: { title: 'شهادة شكر وتقدير', emoji: '⭐', color: '#4169E1', grad: 'linear-gradient(135deg, #4169E1 0%, #1E90FF 100%)',
        message: `نتقدم بجزيل الشكر والتقدير للطالب/ة <strong>${cert.studentName}</strong> لجهوده/ها الدؤوبة في دراسة مادة <strong>${cert.subject}</strong> للترم <strong>${cert.atram}</strong>، ولالتزامه/ها المتواصل في أداء واجباته/ها الدراسية. نثمن عالياً اجتهادك ونتمنى لك المزيد من النجاح والتوفيق.` },
      participation: { title: 'شهادة مشاركة فعالة', emoji: '🌟', color: '#32CD32', grad: 'linear-gradient(135deg, #32CD32 0%, #228B22 100%)',
        message: `نشهد بأن الطالب/ة <strong>${cert.studentName}</strong> قد أبدى/ت مشاركة فعالة ونشاطاً ملحوظاً في دراسة مادة <strong>${cert.subject}</strong> للترم <strong>${cert.atram}</strong>. نقدر حماسك واهتمامك ونشجعك على الاستمرار في هذا النهج الإيجابي.` },
    };
    const t = typeMap[cert.type];
    const w = window.open('', '_blank');
    if (!w) return;
    w.document.write(`
      <!DOCTYPE html>
      <html dir="rtl" lang="ar">
        <head>
          <meta charset="UTF-8">
          <title>${t.title} - ${cert.studentName}</title>
          <style>
            @import url('https://fonts.googleapis.com/css2?family=Tajawal:wght@400;700;900&display=swap');
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
              font-family: 'Tajawal', sans-serif;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px;
            }
            .certificate {
              background: white; width: 800px; padding: 60px; border-radius: 20px;
              box-shadow: 0 20px 60px rgba(0,0,0,0.3); position: relative; overflow: hidden;
            }
            .certificate::before {
              content: ''; position: absolute; top: 0; left: 0; right: 0; height: 10px;
              background: ${t.grad};
            }
            .certificate::after {
              content: '${t.emoji}'; position: absolute; font-size: 200px; opacity: 0.05;
              top: 50%; left: 50%; transform: translate(-50%, -50%);
            }
            .header { text-align: center; margin-bottom: 40px; position: relative; }
            .logo { font-size: 80px; margin-bottom: 20px; }
            .title { font-size: 42px; font-weight: 900; background: ${t.grad}; -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 10px; }
            .subtitle { font-size: 18px; color: #666; font-weight: 700; }
            .content { text-align: center; line-height: 2.5; font-size: 20px; color: #333; margin: 40px 0; position: relative; }
            .student-name { font-size: 32px; font-weight: 900; color: ${t.color}; margin: 20px 0; }
            .footer { margin-top: 60px; display: flex; justify-content: space-between; align-items: center; border-top: 3px solid #f0f0f0; padding-top: 30px; }
            .signature { text-align: center; }
            .signature-line { width: 200px; height: 2px; background: #333; margin: 10px auto; }
            .signature-label { font-weight: 700; color: #666; font-size: 16px; }
            .date { text-align: center; color: #666; font-size: 16px; font-weight: 700; }
            .seal { position: absolute; bottom: 40px; left: 40px; width: 120px; height: 120px; border: 5px solid ${t.color}; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 60px; opacity: 0.3; transform: rotate(-15deg); }
            .border-decoration { position: absolute; top: 20px; right: 20px; width: 60px; height: 60px; border-top: 5px solid ${t.color}; border-right: 5px solid ${t.color}; }
            .border-decoration-bottom { position: absolute; bottom: 20px; left: 20px; width: 60px; height: 60px; border-bottom: 5px solid ${t.color}; border-left: 5px solid ${t.color}; }
            .academic-info { margin-top: 16px; padding: 12px 20px; background: #f8f9ff; border-radius: 12px; display: inline-block; }
            .academic-info p { font-size: 15px; color: #555; margin: 4px 0; font-weight: 700; }
            @media print {
              body { background: white; padding: 0; }
              .certificate { box-shadow: none; margin: 0; width: 100%; }
            }
          </style>
        </head>
        <body>
          <div class="certificate">
            <div class="border-decoration"></div>
            <div class="border-decoration-bottom"></div>
            <div class="seal">${t.emoji}</div>

            <div class="header">
              <div class="logo">${t.emoji}</div>
              <h1 class="title">${t.title}</h1>
              <p class="subtitle">منصة التعليم الذكي</p>
            </div>

            <div class="content">
              <p>${t.message}</p>
            </div>

            <div class="footer">
              <div class="signature">
                <div class="signature-line"></div>
                <p class="signature-label">إدارة المنصة</p>
              </div>
              <div class="date"><p>التاريخ: ${date}</p></div>
              <div class="signature">
                <p style="font-weight:900;font-size:18px;color:#333;margin-bottom:10px;">${cert.teacherName || ''}</p>
                <div class="signature-line"></div>
                <p class="signature-label">المعلم/ة</p>
              </div>
            </div>
          </div>
          <script>
            window.onload = function() { setTimeout(() => { window.print(); }, 500); };
          </script>
        </body>
      </html>
    `);
    w.document.close();
  };

  const printSubjectReport = (child: StudentInfo, subject: string) => {
    const childQuizzes = allQuizzes.filter(q => q.studentId === child.id && q.subject === subject);
    const avg = childQuizzes.length > 0 ? (childQuizzes.reduce((acc, q) => acc + q.percentage, 0) / childQuizzes.length).toFixed(1) : '0';
    const periodicQuizzes = childQuizzes.filter(q => normalizeQuizType(q.quizType) === QuizType.PERIODIC);
    const teacherQuizzes = childQuizzes.filter(q => normalizeQuizType(q.quizType) === QuizType.TEACHER);
    const periodicAvg = periodicQuizzes.length > 0 ? (periodicQuizzes.reduce((acc, q) => acc + q.percentage, 0) / periodicQuizzes.length).toFixed(1) : '0';
    const teacherAvg = teacherQuizzes.length > 0 ? (teacherQuizzes.reduce((acc, q) => acc + q.percentage, 0) / teacherQuizzes.length).toFixed(1) : '0';
      const certificates = readStorageArray<CertificateRecord>(CERT_KEY);
    const studentCertificates = certificates.filter((c: any) => c.studentId === child.id && c.subject === subject);
    const printWindow = window.open('', '_blank');
    if (!printWindow) return;
    printWindow.document.write(`
      <html dir="rtl" lang="ar"><head><title>تقرير مادة ${subject} - ${child.name}</title>
      <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 40px; background: linear-gradient(to bottom, #f8fafc, #e2e8f0); }
        .header { text-align: center; border-bottom: 4px solid #3b82f6; padding-bottom: 20px; margin-bottom: 30px; background: white; padding: 30px; border-radius: 20px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .info { display: flex; justify-content: space-between; margin-bottom: 30px; background: white; padding: 25px; border-radius: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .stats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: white; padding: 25px; border-radius: 20px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); border: 2px solid; }
        .stat-card.unit { border-color: #3b82f6; } .stat-card.term { border-color: #8b5cf6; } .stat-card.grade { border-color: #10b981; }
        .stat-card h3 { font-size: 14px; margin-bottom: 10px; color: #64748b; } .stat-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .stat-card.unit .value { color: #3b82f6; } .stat-card.term .value { color: #8b5cf6; } .stat-card.grade .value { color: #10b981; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; background: white; border-radius: 20px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th, td { border: 1px solid #e2e8f0; padding: 15px; text-align: right; }
        th { background: #3b82f6; color: white; font-weight: bold; }
        tr:nth-child(even) { background: #f8fafc; }
        .summary { margin-top: 30px; text-align: center; font-size: 28px; font-weight: bold; color: #1e40af; background: white; padding: 30px; border-radius: 20px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .certificates { margin-top: 30px; background: white; padding: 30px; border-radius: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .cert-item { display: inline-block; margin: 10px; padding: 20px; border-radius: 15px; border: 2px solid; text-align: center; min-width: 200px; }
        .cert-item.excellence { background: #fef3c7; border-color: #f59e0b; } .cert-item.appreciation { background: #dbeafe; border-color: #3b82f6; } .cert-item.participation { background: #d1fae5; border-color: #10b981; }
        .section-title { background: #3b82f6; color: white; padding: 15px 25px; border-radius: 15px; margin: 30px 0 20px 0; font-size: 20px; font-weight: bold; }
      </style></head><body>
      <div class="header"><h1 style="margin:0;color:#1e40af;font-size:32px;">📊 تقرير الأداء التعليمي الشامل</h1><h3 style="margin:10px 0 0 0;color:#64748b;">مادة ${subject}</h3></div>
      <div class="info"><div><strong style="color:#64748b;">الاسم:</strong> <span style="font-size:18px;font-weight:bold;">${child.name}</span></div><div><strong style="color:#64748b;">الصف:</strong> <span style="font-size:18px;font-weight:bold;">${child.grade}</span></div><div><strong style="color:#64748b;">الترم:</strong> <span style="font-size:18px;font-weight:bold;">${child.atram}</span></div><div><strong style="color:#64748b;">التاريخ:</strong> <span style="font-size:18px;font-weight:bold;">${new Date().toLocaleDateString('ar-SA')}</span></div></div>
      <div class="section-title">📈 ملخص الأداء حسب نوع الاختبار</div>
      <div class="stats-grid">
         <div class="stat-card unit"><h3>📘 الاختبار الدوري</h3><div class="value">${periodicAvg}%</div><p style="color:#64748b;margin:5px 0;">عدد المحاولات: ${periodicQuizzes.length}</p></div>
         <div class="stat-card grade"><h3>📕 اختبار المعلم</h3><div class="value">${teacherAvg}%</div><p style="color:#64748b;margin:5px 0;">عدد الاختبارات: ${teacherQuizzes.length}</p></div>
      </div>
      ${studentCertificates.length > 0 ? `<div class="certificates"><h2>🏆 الشهادات الممنوحة</h2><div style="text-align:center;">${studentCertificates.map((cert: any) => `<div class="cert-item ${cert.type}"><div style="font-size:40px;margin-bottom:10px;">${cert.type === 'excellence' ? '🏆' : cert.type === 'appreciation' ? '⭐' : '🌟'}</div><strong style="font-size:16px;">${cert.type === 'excellence' ? 'شهادة تميز' : cert.type === 'appreciation' ? 'شهادة تقدير' : 'شهادة مشاركة'}</strong><p style="margin:10px 0 5px 0;font-size:14px;">المعلم: ${cert.teacherName || 'غير محدد'}</p><p style="margin:0;font-size:12px;color:#64748b;">${new Date(cert.date).toLocaleDateString('ar-SA')}</p></div>`).join('')}</div></div>` : ''}
       <div class="section-title">📋 تفاصيل جميع الاختبارات</div>
       <table><thead><tr><th>نوع الاختبار</th><th>الوحدة</th><th>الصف</th><th>النتيجة</th><th>المستوى</th><th>التاريخ</th></tr></thead><tbody>${childQuizzes.map(q => `<tr><td style="font-weight:bold;">${getQuizTypeLabel(q.quizType)}</td><td>${q.unit || '-'}</td><td>${q.grade}</td><td style="font-weight:bold;font-size:18px;color:${q.percentage >= 80 ? '#10b981' : q.percentage >= 60 ? '#f59e0b' : '#ef4444'};">${q.percentage}%</td><td style="font-weight:bold;color:${q.percentage >= 60 ? '#10b981' : '#ef4444'};">${q.level}</td><td style="font-size:12px;color:#64748b;">${new Date(q.createdAt).toLocaleDateString('ar-SA')}</td></tr>`).join('')}</tbody></table>
       <div class="summary"><div style="color:#64748b;font-size:16px;margin-bottom:10px;">📊 المعدل العام للمادة</div><div style="font-size:48px;color:${parseFloat(avg) >= 80 ? '#10b981' : parseFloat(avg) >= 60 ? '#f59e0b' : '#ef4444'};">${avg}%</div><div style="margin-top:15px;font-size:14px;color:#64748b;">إجمالي النتائج: ${childQuizzes.length} | أعلى درجة: ${childQuizzes.length > 0 ? Math.max(...childQuizzes.map(q => q.percentage)) : 0}% | أقل درجة: ${childQuizzes.length > 0 ? Math.min(...childQuizzes.map(q => q.percentage)) : 0}%</div></div>
      <div style="text-align:center;margin-top:40px;padding:20px;background:#f8fafc;border-radius:15px;color:#64748b;font-size:12px;"><p style="margin:0;">تم إنشاء هذا التقرير بواسطة منصة SmartEdu التعليمية</p><p style="margin:5px 0 0 0;">${new Date().toLocaleString('ar-SA')}</p></div>
      </body></html>
    `);
    printWindow.document.close();
    printWindow.print();
  };

  const printTeacherResultsReport = (child: StudentInfo) => {
      const teacherQuizzes = allQuizzes
      .filter(q => q.studentId === child.id && normalizeQuizType(q.quizType) === QuizType.TEACHER)
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    if (teacherQuizzes.length === 0) return;

    const average = Math.round(
      teacherQuizzes.reduce((sum, quiz) => sum + getQuizResultPercentage(quiz), 0) / teacherQuizzes.length,
    );
    const level = average >= 90 ? 'ممتاز' : average >= 70 ? 'جيد جداً' : average >= 50 ? 'جيد' : 'يحتاج تحسين';
    const printWindow = window.open('', '_blank');
    if (!printWindow) return;

    printWindow.document.write(`
      <!DOCTYPE html>
      <html dir="rtl" lang="ar">
        <head>
          <meta charset="UTF-8">
          <title>نتائج اختبارات المعلم - ${child.name}</title>
          <style>
            body { font-family: 'Segoe UI', Tahoma, sans-serif; padding: 32px; color: #172033; background: #f8fafc; }
            .header { text-align: center; background: linear-gradient(135deg, #be123c, #f97316); color: white; padding: 28px; border-radius: 18px; margin-bottom: 20px; }
            .header h1 { margin: 0 0 8px; font-size: 30px; }
            .info, .summary, .result { background: white; border-radius: 16px; padding: 18px; margin-bottom: 18px; box-shadow: 0 2px 8px rgba(15,23,42,.08); }
            .info { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; }
            .info strong, .summary strong { display: block; color: #64748b; font-size: 12px; margin-bottom: 5px; }
            .summary { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; text-align: center; }
            .summary .value { font-size: 25px; font-weight: 900; color: #be123c; }
            .result h2 { margin: 0 0 12px; color: #9f1239; font-size: 20px; }
            .result-meta { display: flex; flex-wrap: wrap; gap: 14px; color: #475569; font-size: 13px; margin-bottom: 12px; }
            table { width: 100%; border-collapse: collapse; margin-top: 12px; }
            th, td { border: 1px solid #e2e8f0; padding: 9px; text-align: right; font-size: 12px; }
            th { background: #be123c; color: white; }
            .score { font-size: 24px; font-weight: 900; color: #be123c; }
            .correct { color: #047857; font-weight: 800; }
            .wrong { color: #b91c1c; font-weight: 800; }
            .footer { text-align: center; color: #64748b; font-size: 11px; margin-top: 24px; }
            @media print { body { background: white; padding: 12px; } .result { break-inside: avoid; box-shadow: none; border: 1px solid #e2e8f0; } }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>📝 نتائج اختبارات المعلم</h1>
            <p>تقرير مستقل لأداء الطالب في تقييمات المعلم</p>
          </div>
          <div class="info">
            <div><strong>اسم الطالب</strong>${child.name}</div>
            <div><strong>الصف</strong>${child.primaryGrade || child.grade || '—'}</div>
            <div><strong>ولي الأمر</strong>${parent?.name || '—'}</div>
            <div><strong>تاريخ التقرير</strong>${new Date().toLocaleDateString('ar-SA')}</div>
          </div>
          <div class="summary">
            <div><strong>عدد اختبارات المعلم</strong><div class="value">${teacherQuizzes.length}</div></div>
            <div><strong>المعدل</strong><div class="value">${average}%</div></div>
            <div><strong>أعلى نتيجة</strong><div class="value">${Math.max(...teacherQuizzes.map(getQuizResultPercentage))}%</div></div>
            <div><strong>التقدير العام</strong><div class="value">${level}</div></div>
          </div>
          ${teacherQuizzes.map((quiz) => `
            <section class="result">
              <h2>${quiz.quizTitle || 'اختبار المعلم'}</h2>
              <div class="result-meta">
                <span><b>المادة:</b> ${quiz.subject || '—'}</span>
                <span><b>الوحدة:</b> ${quiz.unit || '—'}</span>
                <span><b>الصف:</b> ${quiz.grade || '—'}</span>
                <span><b>التاريخ:</b> ${new Date(quiz.createdAt).toLocaleString('ar-SA')}</span>
              </div>
              <div class="score">النتيجة: ${getQuizResultScore(quiz)} / ${quiz.total || 0} — ${getQuizResultPercentage(quiz)}% — ${quiz.level || '—'}</div>
              ${Array.isArray(quiz.details) && quiz.details.length > 0 ? `
                <table>
                  <thead><tr><th>#</th><th>السؤال</th><th>إجابة الطالب</th><th>الإجابة الصحيحة</th><th>الحالة</th></tr></thead>
                  <tbody>${quiz.details.map((detail, index) => `
                    <tr>
                      <td>${index + 1}</td>
                      <td>${detail.question}</td>
                      <td>${detail.userAnswer || '—'}</td>
                      <td>${detail.correctAnswer || '—'}</td>
                      <td class="${detail.isCorrect ? 'correct' : 'wrong'}">${detail.isCorrect ? 'صحيحة' : 'خاطئة'}</td>
                    </tr>
                  `).join('')}</tbody>
                </table>
              ` : ''}
            </section>
          `).join('')}
          <div class="footer">تم إنشاء التقرير بواسطة منصة التعليم الذكي — ${new Date().toLocaleString('ar-SA')}</div>
          <script>window.onload = function() { setTimeout(() => window.print(), 400); };</script>
        </body>
      </html>
    `);
    printWindow.document.close();
  };

  if (!isAuthenticated) {
    return needsPasswordChange ?
      <ParentAccountSetup parent={parent!} onPasswordChange={handleAccountPasswordChange} /> :
      <ParentLogin onLogin={handleLogin} onBack={onLogout} />;
  }

  /* ===== Derived data ===== */
  const myChildQuizzes = activeChild ? allQuizzes.filter(q => q.studentId === activeChild.id) : [];
  const subjectsOfChild = activeChild ? getChildSubjects(activeChild).map(s => ({ subject: s, atram: activeChild.atram || '' })) : [];

  /* ===== Render ===== */
  return (
    <div dir="rtl" className="flex min-h-screen w-full flex-row bg-gradient-to-br from-rose-50 to-pink-50 animate-fadeIn overflow-visible">
      {/* ===== SIDEBAR ===== */}
      {mobileNavOpen && (
        <button type="button" aria-label="إغلاق القائمة" onClick={() => setMobileNavOpen(false)} className="fixed inset-0 z-40 bg-slate-950/60 md:hidden" />
      )}
      <aside className={`fixed inset-y-0 right-0 z-50 flex w-[min(20rem,88vw)] shrink-0 transform flex-col bg-gradient-to-b from-rose-900 to-rose-800 pb-[calc(1rem+env(safe-area-inset-bottom))] pt-[calc(1rem+env(safe-area-inset-top))] text-white shadow-2xl transition-transform duration-300 md:sticky md:top-0 md:h-screen md:z-auto md:w-80 md:translate-x-0 ${mobileNavOpen ? 'translate-x-0' : 'translate-x-full'}`}>
        {/* Header */}
        <div className="p-4 sm:p-6 border-b border-rose-800">
          <button type="button" onClick={() => setMobileNavOpen(false)} className="mb-3 rounded-xl bg-white/10 px-3 py-2 text-sm font-bold md:hidden">✕ إغلاق</button>
          <ManaraBrand variant="sidebar" className="justify-center text-white" />
          <h2 className="text-2xl font-black text-center mb-1">بوابة المتابعة</h2>
          <p className="text-rose-300 text-center text-xs font-bold">تابع تقدم أبنائك</p>
          <div className="mt-3 p-3 bg-rose-800 rounded-[16px] text-center border border-rose-700">
            <p className="text-rose-200 text-[10px] font-bold uppercase tracking-widest mb-1">ولي الأمر</p>
            <p className="text-white font-black text-base">{parent?.name}</p>
          </div>
        </div>

        {/* Menu buttons */}
        <div className="p-3 space-y-1 border-t border-rose-800">
          {[
            { key: ParentMenuType.DASHBOARD, icon: '🏠', label: 'الرئيسية' },
            { key: ParentMenuType.CHILDREN, icon: '👨‍👧', label: 'الأبناء' },
             ...(permissions.canCreateStudents && !isLimitReached(children.length, permissions.maxStudents)
               ? [{ key: ParentMenuType.ADD_CHILDREN, icon: '➕', label: 'إضافة ابن' }]
               : []),
            { key: ParentMenuType.CERTIFICATES, icon: '🏆', label: 'الشهادات' },
             ...(permissions.canEditStudents
               && permissions.canCreatePermissionPackages
               ? [{ key: ParentMenuType.PERMISSION_PACKAGES, icon: '🔐', label: 'إدارة صلاحيات الأبناء' }]
               : []),
            ...(permissions.canChatWithSupport ? [{ key: ParentMenuType.CHAT, icon: '💬', label: 'الدردشة' }] : []),
            { key: ParentMenuType.SETTINGS, icon: '⚙️', label: 'الإعدادات' },
          ].map(item => (
            <button
              key={item.key}
              onClick={() => {
                if (item.key === ParentMenuType.CHAT) { setShowChat(true); setMobileNavOpen(false); }
                else {
                   setMenuType(item.key as ParentMenuType);
                   setMobileNavOpen(false);
                  if (item.key === ParentMenuType.DASHBOARD) {
                    setActiveChild(null);
                    setActiveSubject(null);
                    setDashFilter('');
                  }
                }
              }}
              className={`w-full text-right p-3 rounded-xl transition-all font-bold text-sm hover:translate-x-[-2px] active:scale-95 ${
                menuType === item.key ? 'bg-rose-700 shadow-lg' : 'hover:bg-rose-800'
              }`}
            >
              {item.icon} {item.label}
            </button>
          ))}
          <button
            onClick={() => { removeActiveSession(STORAGE_KEYS.ACTIVE_PARENT); onLogout(); }}
            className="w-full text-right p-3 rounded-xl text-red-400 hover:bg-red-950 font-bold text-sm transition-all hover:scale-[1.02] active:scale-95"
          >
            🚪 تسجيل الخروج
          </button>
        </div>
      </aside>

      {/* ===== MAIN CONTENT ===== */}
      <main className="min-w-0 flex-1 min-h-screen px-4 py-6 sm:px-6 md:px-10 overflow-visible safe-area-x safe-area-bottom">
        <button type="button" onClick={() => setMobileNavOpen(true)} className="mb-4 rounded-xl bg-rose-800 px-3 py-2 text-white font-black md:hidden" aria-label="فتح القائمة">☰ القائمة</button>
        <div className="w-full max-w-7xl mx-auto">

        {/* ---------- DASHBOARD ---------- */}
        {menuType === ParentMenuType.DASHBOARD && (
          <div className="space-y-6 animate-fadeIn">
            {/* Welcome header — tighter, cleaner */}
            <div className="bg-gradient-to-r from-rose-500 via-pink-500 to-rose-600 p-5 rounded-2xl shadow-xl text-white">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <h1 className="text-2xl font-black">
                    {activeChild ? `${getStudentEmoji(activeChild)} ${activeChild.name}` : '🏠 لوحة المتابعة'}
                  </h1>
                  <p className="text-rose-200 font-bold text-xs mt-1">
                    {activeChild ? 'تفاصيل الأداء والتحصيل الدراسي' : 'نظرة شاملة على تقدم جميع أبنائك'}
                  </p>
                </div>
                {activeChild && (
                  <button onClick={() => { setActiveChild(null); setActiveSubject(null); setDashFilter(''); }} className="bg-white/20 backdrop-blur text-white px-4 py-2 rounded-xl font-black text-xs hover:bg-white/30 transition-all shrink-0">
                    ← رجوع
                  </button>
                )}
              </div>
            </div>

            {activeChild ? (
              /* ── Single child detail ── */
              <div className="space-y-6">
                {/* Quick Stats — compact, aligned */}
                {(() => {
                  const qs = getChildQuizzes(activeChild.id);
                  const subjs = getChildSubjects(activeChild);
                   const progress = getStudentProgressSummary(activeChild, allQuizzes);
                  const avg = qs.length > 0 ? (qs.reduce((a,b) => a + b.percentage, 0) / qs.length).toFixed(0) : '0';
                  const lastScore = qs.length > 0 ? qs.sort((a,b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())[0].percentage : null;
                    const stats = [
                    { label: 'المواد', value: subjs.length, color: 'text-blue-700', bg: 'border-l-4 border-blue-500', icon: '📚' },
                    { label: 'الاختبارات', value: qs.length, color: 'text-purple-700', bg: 'border-l-4 border-purple-500', icon: '📝' },
                    { label: 'المعدل', value: `${avg}%`, color: 'text-green-700', bg: 'border-l-4 border-green-500', icon: '📊' },
                    { label: 'آخر درجة', value: lastScore !== null ? `${lastScore}%` : '—', color: 'text-orange-700', bg: 'border-l-4 border-orange-500', icon: '🎯' },
                     { label: 'المستوى', value: progress.level, color: 'text-indigo-700', bg: 'border-l-4 border-indigo-500', icon: '🏅' },
                     { label: 'الجواهر', value: progress.gems, color: 'text-amber-700', bg: 'border-l-4 border-amber-500', icon: '💎' },
                     { label: 'الخبرة', value: progress.xp, color: 'text-cyan-700', bg: 'border-l-4 border-cyan-500', icon: '⚡' },
                  ];
                  return (
                    <div className="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-7 gap-3">
                      {stats.map((s, i) => (
                        <div key={i} className={`bg-white p-4 rounded-2xl shadow-md ${s.bg} flex items-center gap-3 hover:shadow-lg transition-shadow`}>
                          <div className="text-2xl shrink-0">{s.icon}</div>
                          <div>
                            <p className="text-[10px] font-bold text-rose-400 uppercase">{s.label}</p>
                            <p className={`text-2xl font-black ${s.color}`}>{s.value}</p>
                          </div>
                        </div>
                      ))}
                    </div>
                  );
                })()}

                {/* Charts row — side by side */}
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
                  {/* Quiz History Line Chart */}
                  {(() => {
                    const qs = getChildQuizzes(activeChild.id);
                    if (qs.length < 2) return null;
                    const chartData = [...qs].sort((a,b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()).map((q, i) => ({
                      name: `${q.quizType.slice(0, 4)}${i + 1}`,
                      percentage: q.percentage,
                    }));
                    return (
                      <div className="bg-white p-5 rounded-2xl shadow-md border border-rose-100">
                        <h3 className="text-base font-black text-rose-800 mb-3 flex items-center gap-2">
                          <span className="w-1.5 h-5 bg-rose-500 rounded-full"></span> 📈 تطور الأداء
                        </h3>
                        <ResponsiveContainer width="100%" height={220}>
                          <LineChart data={chartData}>
                            <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
                            <XAxis dataKey="name" tick={{fontSize: 10}} />
                            <YAxis domain={[0, 100]} tick={{fontSize: 11}} width={30} />
                            <Tooltip formatter={(v: any) => [`${v}%`, 'الدرجة']} />
                            <Line type="monotone" dataKey="percentage" stroke="#6366f1" strokeWidth={2.5} dot={{fill: '#6366f1', r: 3}} />
                          </LineChart>
                        </ResponsiveContainer>
                      </div>
                    );
                  })()}

                  {/* Subject Radar Chart */}
                  {(() => {
                    const qs = getChildQuizzes(activeChild.id);
                    if (subjectsOfChild.length < 3) return null;
                    const radarData = subjectsOfChild.map(s => {
                      const sq = qs.filter(q => q.subject === s.subject);
                      const a = sq.length > 0 ? sq.reduce((ac, q) => ac + q.percentage, 0) / sq.length : 0;
                      return { subject: s.subject.slice(0, 8), fullMark: 100, score: Math.round(a) };
                    });
                    return (
                      <div className="bg-white p-5 rounded-2xl shadow-md border border-rose-100">
                        <h3 className="text-base font-black text-rose-800 mb-3 flex items-center gap-2">
                          <span className="w-1.5 h-5 bg-violet-600 rounded-full"></span> 🎯 توزيع المواد
                        </h3>
                        <div className="flex justify-center">
                          <ResponsiveContainer width="100%" height={220}>
                            <RadarChart data={radarData}>
                              <PolarGrid />
                              <PolarAngleAxis dataKey="subject" tick={{fontSize: 10}} />
                              <PolarRadiusAxis angle={30} domain={[0, 100]} tick={false} />
                              <Radar name="الأداء" dataKey="score" stroke="#8b5cf6" fill="#8b5cf6" fillOpacity={0.25} />
                            </RadarChart>
                          </ResponsiveContainer>
                        </div>
                      </div>
                    );
                  })()}
                </div>

                {/* Subject Cards — compact grid */}
                    {(() => {
                      const teacherQuizzes = myChildQuizzes
                        .filter(q => normalizeQuizType(q.quizType) === QuizType.TEACHER)
                        .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
                      const average = teacherQuizzes.length > 0
                        ? Math.round(teacherQuizzes.reduce((sum, quiz) => sum + getQuizResultPercentage(quiz), 0) / teacherQuizzes.length)
                        : 0;
                      return (
                        <div className="bg-gradient-to-br from-rose-50 to-orange-50 p-4 rounded-2xl border-2 border-rose-200 shadow-sm">
                          <div className="flex items-center justify-between gap-3 mb-3">
                            <div>
                              <h3 className="text-base font-black text-rose-800">📝 تفاصيل نتائج اختبارات الطالب</h3>
                              <p className="text-xs text-rose-500 font-bold mt-1">نتائج منفصلة عن الاختبارات الدورية</p>
                            </div>
                            {teacherQuizzes.length > 0 && (
                              <button onClick={() => printTeacherResultsReport(activeChild)} className="bg-rose-500 text-white px-4 py-2 rounded-xl font-black text-xs hover:bg-rose-600 transition-all">
                                🖨️ طباعة النتائج
                              </button>
                            )}
                          </div>
                          {teacherQuizzes.length > 0 ? (
                            <>
                              <div className="grid grid-cols-3 gap-2 mb-3 text-center">
                                <div className="bg-white rounded-xl p-2"><p className="text-[10px] text-rose-400 font-bold">الاختبارات</p><p className="text-xl text-rose-700 font-black">{teacherQuizzes.length}</p></div>
                                <div className="bg-white rounded-xl p-2"><p className="text-[10px] text-rose-400 font-bold">المعدل</p><p className="text-xl text-rose-700 font-black">{average}%</p></div>
                                <div className="bg-white rounded-xl p-2"><p className="text-[10px] text-rose-400 font-bold">التقدير</p><p className="text-base text-rose-700 font-black">{average >= 90 ? 'ممتاز' : average >= 70 ? 'جيد جداً' : average >= 50 ? 'جيد' : 'يحتاج تحسين'}</p></div>
                              </div>
                              <div className="space-y-2">
                                {teacherQuizzes.map((quiz) => (
                                  <div key={quiz.id} className="bg-white p-3 rounded-xl border border-rose-100 flex items-center justify-between gap-3">
                                    <div className="min-w-0">
                                      <p className="font-black text-sm text-rose-800 truncate">{quiz.quizTitle || 'اختبار المعلم'}</p>
                                      <p className="text-[10px] text-rose-400 font-bold">{quiz.subject || '—'} • {quiz.unit || '—'} • {new Date(quiz.createdAt).toLocaleDateString('ar-SA')}</p>
                                    </div>
                                    <div className="text-left shrink-0">
                                      <p className="font-black text-rose-700">{getQuizResultScore(quiz)} / {quiz.total || 0}</p>
                                      <p className="text-xs font-black text-rose-500">{getQuizResultPercentage(quiz)}% • {quiz.level || '—'}</p>
                                    </div>
                                  </div>
                                ))}
                              </div>
                            </>
                          ) : (
                            <p className="bg-white/70 rounded-xl p-4 text-center text-rose-400 font-bold text-sm">لم ينجز الطالب اختبار معلم بعد</p>
                          )}
                        </div>
                      );
                    })()}

                    {/* Subject Cards — compact grid */}
                <div>
                  <h3 className="text-lg font-black mb-4 text-rose-800 flex items-center gap-2">
                    <span className="w-1.5 h-5 bg-rose-500 rounded-full"></span> 📚 المواد والتحصيل
                  </h3>
                  {(() => {
                    const qs = getChildQuizzes(activeChild.id);
                    if (subjectsOfChild.length === 0) return (
                       <div className="rounded-2xl border-2 border-dashed border-rose-200 bg-rose-50 p-5 text-center sm:p-12">
                        <p className="text-4xl mb-2">📚</p>
                        <p className="text-rose-500 font-bold text-sm">لم يتم رصد نتائج اختبارات بعد</p>
                      </div>
                    );
                    return (
                      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
                        {subjectsOfChild.map(subObj => {
                          const subQuizzes = qs.filter(q => q.subject === subObj.subject);
                          const avg = subQuizzes.length > 0 ? (subQuizzes.reduce((acc, q) => acc + q.percentage, 0) / subQuizzes.length).toFixed(0) : '0';
                          const lastQuiz = subQuizzes.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())[0];
                          const level = subQuizzes.length === 0 ? 'لم يبدأ 📚' : parseInt(avg) >= 90 ? 'ممتاز 🌟' : parseInt(avg) >= 70 ? 'جيد جداً ⭐' : parseInt(avg) >= 60 ? 'جيد 👍' : 'يحتاج تحسين 📖';
                          const barColor = subQuizzes.length === 0 ? 'bg-rose-200' : parseInt(avg) >= 90 ? 'bg-gradient-to-r from-emerald-400 to-emerald-600' : parseInt(avg) >= 70 ? 'bg-gradient-to-r from-blue-400 to-blue-600' : parseInt(avg) >= 60 ? 'bg-gradient-to-r from-amber-400 to-amber-600' : 'bg-gradient-to-r from-red-400 to-red-600';
                          return (
                            <div key={`${subObj.subject}-${subObj.atram}`} className="bg-white p-5 rounded-2xl shadow-md border border-rose-100 hover:shadow-lg hover:border-rose-300 transition-all">
                              <div className="flex items-start justify-between mb-3">
                                <div className="flex-1 min-w-0">
                                  <h4 className="text-base font-black text-rose-800 truncate">{subObj.subject}</h4>
                                  {subObj.atram && <span className="inline-block mt-1 text-[10px] font-bold bg-rose-50 text-rose-500 px-2 py-0.5 rounded-full">{subObj.atram}</span>}
                                </div>
                                <div className={`text-white px-3 py-1.5 rounded-xl text-center shadow-md text-sm font-black ${subQuizzes.length === 0 ? 'bg-rose-300' : 'bg-rose-500'}`}>
                                  {avg}%
                                </div>
                              </div>
                              <div className="flex items-center justify-between text-xs font-bold text-rose-500 mb-2">
                                <span>{subQuizzes.length} اختبار</span>
                                <span className={parseInt(avg) >= 70 ? 'text-emerald-600' : parseInt(avg) >= 60 ? 'text-amber-600' : 'text-red-500'}>{level}</span>
                              </div>
                              <div className="w-full bg-rose-100 rounded-full h-2 mb-3">
                                <div className={`h-full rounded-full transition-all ${barColor}`} style={{width: subQuizzes.length === 0 ? '0%' : `${avg}%`}}></div>
                              </div>
                              <div className="flex gap-2">
                                <button onClick={() => { setActiveSubject(subObj.subject); setMenuType(ParentMenuType.CHILDREN); }} className="flex-1 bg-rose-500 text-white py-2 rounded-xl font-bold hover:bg-rose-600 transition-all text-xs">التفاصيل</button>
                                {subQuizzes.length > 0 && <button onClick={() => printSubjectReport(activeChild, subObj.subject)} className="px-3 bg-rose-100 text-rose-600 py-2 rounded-xl font-bold hover:bg-rose-500 hover:text-white transition-all text-xs">🖨️</button>}
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    );
                  })()}
                </div>
              </div>
            ) : (
              /* ── All children overview ── */
              <>
                {/* Stats row — compact */}
                {(() => {
                  const filtered = dashFilter.trim()
                    ? children.filter(c => c.name.toLowerCase().includes(dashFilter.toLowerCase()) || (c.primaryGrade || c.grade || '').includes(dashFilter))
                    : children;
                  const totalQuizzes = filtered.reduce((sum, c) => sum + getChildQuizzes(c.id).length, 0);
                  const allAvgs = filtered.map(c => parseFloat(getChildAverage(c.id))).filter(v => v > 0);
                  const overallAvg = allAvgs.length > 0 ? (allAvgs.reduce((a, b) => a + b, 0) / allAvgs.length).toFixed(0) : '0';
                   const totalGems = filtered.reduce((sum, child) => sum + getStudentProgressSummary(child, allQuizzes).gems, 0);
                   const stats = [
                    { label: 'الأبناء', value: filtered.length, sub: dashFilter.trim() ? 'نتائج البحث' : 'إجمالي', icon: '👨‍👧', color: 'text-blue-700', bar: 'border-l-4 border-blue-500' },
                    { label: 'الاختبارات', value: totalQuizzes, sub: 'منجزة', icon: '📝', color: 'text-purple-700', bar: 'border-l-4 border-purple-500' },
                    { label: 'المعدل', value: `${overallAvg}%`, sub: 'متوسط', icon: '📊', color: 'text-green-700', bar: 'border-l-4 border-green-500' },
                     { label: 'الجواهر', value: totalGems, sub: 'مجموع الأبناء', icon: '💎', color: 'text-amber-700', bar: 'border-l-4 border-amber-500' },
                     { label: 'الخبرة', value: filtered.reduce((sum, child) => sum + getStudentProgressSummary(child, allQuizzes).xp, 0), sub: 'مجموع الأبناء', icon: '⚡', color: 'text-cyan-700', bar: 'border-l-4 border-cyan-500' },
                    { label: 'الشهادات', value: filteredCertificates.length, sub: 'مصدرة', icon: '🏆', color: 'text-orange-700', bar: 'border-l-4 border-orange-500' },
                  ];
                  return (
                     <div className="grid grid-cols-2 md:grid-cols-6 gap-3">
                      {stats.map((s, i) => (
                        <div key={i} className={`bg-white p-4 rounded-2xl shadow-md ${s.bar} hover:shadow-lg transition-shadow`}>
                          <div className="flex items-center gap-2 mb-1">
                            <span className="text-lg">{s.icon}</span>
                            <span className="text-[10px] font-bold text-rose-400 uppercase">{s.label}</span>
                          </div>
                          <p className={`text-2xl font-black ${s.color}`}>{s.value}</p>
                          <p className="text-[10px] text-rose-400 font-bold mt-0.5">{s.sub}</p>
                        </div>
                      ))}
                    </div>
                  );
                })()}

                {/* Charts + Activity row */}
                <div className="grid grid-cols-1 lg:grid-cols-5 gap-5">
                  {/* Comparison chart */}
                  {children.length > 1 && (
                    <div className="lg:col-span-3 bg-white p-5 rounded-2xl shadow-md border border-rose-100">
                      <h3 className="text-base font-black text-rose-800 mb-3 flex items-center gap-2">
                        <span className="w-1.5 h-5 bg-rose-500 rounded-full"></span> 📊 مقارنة الأبناء
                      </h3>
                      {(() => {
                        const data = children.map(c => ({
                          name: c.name.split(' ')[0],
                          avg: parseFloat(getChildAverage(c.id)),
                          quizzes: getChildQuizzes(c.id).length,
                        }));
                        return (
                          <ResponsiveContainer width="100%" height={220}>
                            <BarChart data={data} margin={{top: 5, right: 10, left: 0, bottom: 5}}>
                              <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
                              <XAxis dataKey="name" tick={{fontSize: 11}} />
                              <YAxis domain={[0, 100]} tick={{fontSize: 11}} width={30} />
                              <Tooltip formatter={(v: any, n: any) => [n === 'avg' ? `${v}%` : v, n === 'avg' ? 'المعدل' : 'الاختبارات']} />
                              <Legend iconSize={10} wrapperStyle={{fontSize: 11}} />
                              <Bar dataKey="avg" name="المعدل %" fill="#6366f1" radius={[6, 6, 0, 0]} />
                              <Bar dataKey="quizzes" name="الاختبارات" fill="#10b981" radius={[6, 6, 0, 0]} />
                            </BarChart>
                          </ResponsiveContainer>
                        );
                      })()}
                    </div>
                  )}

                  {/* Activity feed */}
                  {(() => {
                    const allChildIds = children.map(c => c.id);
                    const recentQuizzes = allQuizzes
                      .filter(q => allChildIds.includes(q.studentId))
                      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
                      .slice(0, 5);
                    const recentCerts = getAllCertificates()
                      .filter(c => allChildIds.includes(c.studentId))
                      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
                      .slice(0, 2);
                    if (recentQuizzes.length === 0 && recentCerts.length === 0) return null;
                    return (
                      <div className={`${children.length > 1 ? 'lg:col-span-2' : 'lg:col-span-3'} bg-white p-5 rounded-2xl shadow-md border border-rose-100 flex flex-col`}>
                        <h3 className="text-base font-black text-rose-800 mb-3 flex items-center gap-2">
                          <span className="w-1.5 h-5 bg-orange-500 rounded-full"></span> 🔔 آخر الأنشطة
                        </h3>
                        <div className="flex-1 overflow-y-auto space-y-2 max-h-[220px]">
                          {recentQuizzes.map((q, i) => (
                            <div key={`q-${i}`} className="flex items-center gap-3 p-3 bg-rose-50 rounded-xl border border-rose-100 hover:border-rose-200 transition-all">
                              <div className="text-xl shrink-0">{q.percentage >= 80 ? '🎉' : q.percentage >= 60 ? '👍' : '📖'}</div>
                              <div className="flex-1 min-w-0">
                                <p className="font-bold text-rose-800 text-xs truncate">{children.find(c => c.id === q.studentId)?.name || ''} — {q.subject}</p>
                                <p className="text-rose-400 text-[10px] font-bold">{new Date(q.createdAt).toLocaleDateString('ar-SA', {month:'short', day:'numeric'})}</p>
                              </div>
                              <div className={`text-sm font-black px-2 py-1 rounded-lg shrink-0 ${q.percentage >= 80 ? 'bg-emerald-100 text-emerald-700' : q.percentage >= 60 ? 'bg-amber-100 text-amber-700' : 'bg-red-100 text-red-700'}`}>{q.percentage}%</div>
                            </div>
                          ))}
                          {recentCerts.map((c, i) => (
                            <div key={`c-${i}`} className="flex items-center gap-3 p-3 bg-amber-50 rounded-xl border border-amber-100 hover:border-amber-300 transition-all">
                              <div className="text-xl shrink-0">{c.type === 'excellence' ? '🏆' : c.type === 'appreciation' ? '⭐' : '🌟'}</div>
                              <div className="flex-1 min-w-0">
                                <p className="font-bold text-rose-800 text-xs truncate">{c.studentName} — {c.type === 'excellence' ? 'تفوق' : c.type === 'appreciation' ? 'شكر' : 'مشاركة'}</p>
                                <p className="text-rose-400 text-[10px] font-bold">{new Date(c.date).toLocaleDateString('ar-SA', {month:'short', day:'numeric'})}</p>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    );
                  })()}
                </div>

                {/* Filter + Children grid */}
                <div className="bg-white p-5 rounded-2xl shadow-md border border-rose-100">
                  <div className="flex items-center justify-between gap-3 mb-3">
                    <div>
                      <h3 className="text-base font-black text-rose-800">📝 نتائج اختبارات الطلاب</h3>
                      <p className="text-xs text-rose-500 font-bold mt-1">فلترة النتائج حسب الطالب أو الاختبار أو ولي الأمر أو المادة</p>
                    </div>
                    <span className="text-2xl">📋</span>
                  </div>
                  {(() => {
                    const teacherResultStudents = children
                      .map(child => ({
                        child,
                        results: getChildQuizzes(child.id)
                          .filter(q => normalizeQuizType(q.quizType) === QuizType.TEACHER),
                      }))
                      .filter(({ results }) => results.length > 0);
                    const quizOptions = Array.from(new Set(
                      teacherResultStudents.flatMap(({ results }) => results.map(result => result.quizTitle || 'اختبار المعلم')),
                    ));
                    const subjectOptions = Array.from(new Set(
                      teacherResultStudents.flatMap(({ results }) => results.map(result => result.subject || 'غير محدد')),
                    ));
                    const filteredResultStudents = teacherResultStudents
                      .map(({ child, results }) => ({
                        child,
                        results: results
                          .filter(result =>
                            (teacherResultQuizFilter === 'all' || (result.quizTitle || 'اختبار المعلم') === teacherResultQuizFilter) &&
                            (teacherResultSubjectFilter === 'all' || (result.subject || 'غير محدد') === teacherResultSubjectFilter),
                          )
                          .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()),
                      }))
                      .filter(({ child, results }) =>
                        results.length > 0 &&
                        (teacherResultStudentFilter === 'all' || child.id === teacherResultStudentFilter) &&
                        (teacherResultParentFilter === 'all' || (parent?.id || '') === teacherResultParentFilter),
                      );
                    const hasActiveFilter = [teacherResultStudentFilter, teacherResultQuizFilter, teacherResultParentFilter, teacherResultSubjectFilter]
                      .some(filter => filter !== 'all');
                    return (
                      <>
                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 mb-4">
                          <label className="text-xs font-black text-rose-700">
                            الطالب
                            <select value={teacherResultStudentFilter} onChange={e => setTeacherResultStudentFilter(e.target.value)} className="mt-1 w-full p-3 rounded-xl border-2 border-rose-100 bg-white text-sm font-bold text-gray-700 focus:border-rose-400 outline-none">
                              <option value="all">كل الطلاب</option>
                              {teacherResultStudents.map(({ child }) => <option key={child.id} value={child.id}>{child.name}</option>)}
                            </select>
                          </label>
                          <label className="text-xs font-black text-rose-700">
                            الاختبار
                            <select value={teacherResultQuizFilter} onChange={e => setTeacherResultQuizFilter(e.target.value)} className="mt-1 w-full p-3 rounded-xl border-2 border-rose-100 bg-white text-sm font-bold text-gray-700 focus:border-rose-400 outline-none">
                              <option value="all">كل الاختبارات</option>
                              {quizOptions.map(quiz => <option key={quiz} value={quiz}>{quiz}</option>)}
                            </select>
                          </label>
                          <label className="text-xs font-black text-rose-700">
                            ولي الأمر
                            <select value={teacherResultParentFilter} onChange={e => setTeacherResultParentFilter(e.target.value)} className="mt-1 w-full p-3 rounded-xl border-2 border-rose-100 bg-white text-sm font-bold text-gray-700 focus:border-rose-400 outline-none">
                              <option value="all">ولي الأمر الحالي</option>
                              {parent && <option value={parent.id}>{parent.name}</option>}
                            </select>
                          </label>
                          <label className="text-xs font-black text-rose-700">
                            المادة
                            <select value={teacherResultSubjectFilter} onChange={e => setTeacherResultSubjectFilter(e.target.value)} className="mt-1 w-full p-3 rounded-xl border-2 border-rose-100 bg-white text-sm font-bold text-gray-700 focus:border-rose-400 outline-none">
                              <option value="all">كل المواد</option>
                              {subjectOptions.map(subject => <option key={subject} value={subject}>{subject}</option>)}
                            </select>
                          </label>
                        </div>
                        {hasActiveFilter && (
                          <button
                            onClick={() => {
                              setTeacherResultStudentFilter('all');
                              setTeacherResultQuizFilter('all');
                              setTeacherResultParentFilter('all');
                              setTeacherResultSubjectFilter('all');
                            }}
                            className="mb-4 px-3 py-2 rounded-xl bg-rose-50 text-rose-600 font-bold text-xs hover:bg-rose-100"
                          >
                            مسح الفلاتر
                          </button>
                        )}
                    {filteredResultStudents.length > 0 ? (
                      <div className="grid grid-cols-1 lg:grid-cols-2 gap-3">
                        {filteredResultStudents.map(({ child, results }) => {
                          const average = Math.round(results.reduce((sum, result) => sum + getQuizResultPercentage(result), 0) / results.length);
                          return (
                            <div key={child.id} className="border border-rose-100 rounded-xl p-3 bg-rose-50/60">
                              <div className="flex items-center justify-between gap-3 mb-2">
                                <div className="min-w-0">
                                  <p className="font-black text-sm text-rose-800 truncate">{child.name}</p>
                                  <p className="text-[10px] text-rose-500 font-bold">{parent?.name || 'ولي الأمر'} • {results.length} اختبار</p>
                                </div>
                                <button
                                  onClick={() => printTeacherResultsReport(child)}
                                  className="shrink-0 bg-rose-500 text-white px-3 py-1.5 rounded-lg font-black text-xs hover:bg-rose-600"
                                >
                                  🖨️ طباعة
                                </button>
                              </div>
                              <div className="grid grid-cols-3 gap-2 mb-2 text-center">
                                <div className="bg-white rounded-lg p-2"><p className="text-[9px] text-rose-400 font-bold">المعدل</p><p className="text-base text-rose-700 font-black">{average}%</p></div>
                                <div className="bg-white rounded-lg p-2"><p className="text-[9px] text-rose-400 font-bold">أعلى</p><p className="text-base text-rose-700 font-black">{Math.max(...results.map(getQuizResultPercentage))}%</p></div>
                                <div className="bg-white rounded-lg p-2"><p className="text-[9px] text-rose-400 font-bold">التقدير</p><p className="text-[11px] text-rose-700 font-black">{average >= 90 ? 'ممتاز' : average >= 70 ? 'جيد جداً' : average >= 50 ? 'جيد' : 'يحتاج تحسين'}</p></div>
                              </div>
                              <div className="space-y-1.5">
                                {results.map((result) => (
                                  <div key={result.id} className="bg-white rounded-lg px-2.5 py-2 flex items-center justify-between gap-2">
                                    <p className="text-xs font-black text-rose-800 truncate">{result.quizTitle || 'اختبار المعلم'} <span className="text-[10px] text-rose-400">• {result.subject || '—'}</span></p>
                                    <span className="shrink-0 text-xs font-black text-rose-600">{getQuizResultPercentage(result)}%</span>
                                  </div>
                                ))}
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    ) : (
                      <div className="p-6 text-center bg-rose-50 rounded-xl border-2 border-dashed border-rose-200 text-rose-500 font-bold text-sm">
                         {hasActiveFilter ? 'لا توجد نتائج مطابقة للفلاتر المحددة' : 'لا توجد نتائج اختبارات معلم حتى الآن'}
                      </div>
                    )}
                        </>
                    );
                  })()}
                </div>

                {/* Filter + Children grid */}
                <div className="bg-white p-4 rounded-2xl shadow-md border border-rose-100">
                  <div className="flex gap-3 items-center mb-5">
                    <div className="flex-1 relative">
                      <span className="absolute right-3 top-1/2 -translate-y-1/2 text-rose-400 text-sm">🔍</span>
                      <input type="text" placeholder="ابحث باسم الابن أو الصف..." value={dashFilter} onChange={e => setDashFilter(e.target.value)} className="w-full p-2.5 pr-9 rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm" />
                    </div>
                    {dashFilter && <button onClick={() => setDashFilter('')} className="px-3 py-2 bg-rose-100 text-rose-500 rounded-xl font-bold text-xs hover:bg-rose-200 transition-all">إلغاء</button>}
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
                    {(() => {
                      const filtered = dashFilter.trim()
                        ? children.filter(c => c.name.toLowerCase().includes(dashFilter.toLowerCase()) || (c.primaryGrade || c.grade || '').includes(dashFilter))
                        : children;
                      if (filtered.length === 0) return (
                        <div className="col-span-full rounded-2xl border-2 border-dashed border-rose-200 bg-rose-50 p-5 text-center sm:p-10">
                          <p className="text-3xl mb-2">🔍</p>
                          <p className="text-rose-500 font-bold text-sm">لا توجد نتائج مطابقة</p>
                        </div>
                      );
                      return filtered.map(child => {
                        const qs = getChildQuizzes(child.id);
                        const avg = getChildAverage(child.id);
                         const progress = getStudentProgressSummary(child, allQuizzes);
                        const subjs = getChildSubjects(child);
                        const studentPermissions = getStudentPermissions(child);
                        const studentPermissionLabels: Record<string, string> = {
                          canChangeGrade: 'تغيير الصف',
                          canAccessChat: 'الوصول للدردشة',
                          canAccessLiveMeeting: 'الوصول للقاءات المباشرة',
                          canRetakeQuiz: 'إعادة الاختبار',
                          canViewSolutions: 'عرض الحلول',
                          canDownloadCertificates: 'تحميل الشهادات',
                        };
                        const activeStudentPermissionLabels = Object.entries(studentPermissions)
                          .filter(([, value]) => value === true)
                          .map(([key]) => studentPermissionLabels[key] || key);
                        const lastQuiz = qs.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())[0];
                        const colors = ['from-rose-400 to-orange-400', 'from-emerald-400 to-teal-400', 'from-sky-400 to-rose-400', 'from-violet-400 to-purple-400', 'from-amber-400 to-yellow-400'];
                        const avatarGrad = colors[child.name.length % colors.length];
                        return (
                          <div key={child.id} className="bg-white p-5 rounded-2xl shadow-sm border border-rose-100 hover:shadow-md hover:border-rose-300 transition-all">
                            <div className="flex items-center gap-3 mb-3">
                               <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${avatarGrad} flex items-center justify-center text-3xl shrink-0`}>{getStudentEmoji(child)}</div>
                              <div className="flex-1 min-w-0">
                                <h4 className="text-base font-black text-rose-800 truncate">{child.name}</h4>
                                <p className="text-rose-400 text-xs font-bold truncate">{child.primaryGrade || child.grade || 'غير محدد'}</p>
                              </div>
                            </div>
                             <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2 mb-3">
                              <div className="bg-blue-50 p-2 rounded-xl text-center"><p className="text-blue-900 font-black text-sm">{subjs.length}</p><p className="text-blue-500 text-[9px] font-bold">مواد</p></div>
                              <div className="bg-purple-50 p-2 rounded-xl text-center"><p className="text-purple-900 font-black text-sm">{qs.length}</p><p className="text-purple-500 text-[9px] font-bold">اختبارات</p></div>
                              <div className="bg-green-50 p-2 rounded-xl text-center"><p className="text-green-900 font-black text-sm">{avg}%</p><p className="text-green-500 text-[9px] font-bold">معدل</p></div>
                               <div className="bg-indigo-50 p-2 rounded-xl text-center"><p className="text-indigo-900 font-black text-sm">{progress.level}</p><p className="text-indigo-500 text-[9px] font-bold">مستوى</p></div>
                               <div className="bg-amber-50 p-2 rounded-xl text-center"><p className="text-amber-900 font-black text-sm">{progress.gems}</p><p className="text-amber-500 text-[9px] font-bold">جواهر</p></div>
                                <div className="bg-cyan-50 p-2 rounded-xl text-center"><p className="text-cyan-900 font-black text-sm">{progress.xp}</p><p className="text-cyan-500 text-[9px] font-bold">خبرة</p></div>
                            </div>
                            {lastQuiz && <p className="text-rose-400 text-[10px] font-bold mb-3">آخر نشاط: {new Date(lastQuiz.createdAt).toLocaleDateString('ar-SA', {month:'short', day:'numeric'})}</p>}
                            <div className="mb-3 rounded-xl border border-indigo-100 bg-indigo-50 p-2.5">
                              <p className="mb-1 text-[10px] font-black text-indigo-700">🔐 صلاحيات الطالب الفعالة</p>
                              <div className="flex flex-wrap gap-1">
                                {activeStudentPermissionLabels.length > 0 ? activeStudentPermissionLabels.map(label => (
                                  <span key={label} className="rounded-full bg-white px-2 py-1 text-[9px] font-black text-indigo-700">
                                    ✓ {label}
                                  </span>
                                )) : (
                                  <span className="text-[9px] font-bold text-indigo-400">لا توجد صلاحيات مفعلة</span>
                                )}
                              </div>
                            </div>
                            <button onClick={() => { setActiveChild(child); setActiveSubject(null); setMenuType(ParentMenuType.CHILDREN); }} className="w-full bg-rose-500 text-white py-2 rounded-xl font-bold hover:bg-rose-600 transition-all text-xs">عرض التفاصيل</button>
                          </div>
                        );
                      });
                    })()}
                  </div>
                </div>
              </>
            )}
          </div>
        )}

        {/* ---------- CHILDREN (dropdown + detail) ---------- */}
        {menuType === ParentMenuType.CHILDREN && (
          <div className="flex flex-col lg:flex-row gap-4 lg:gap-5 animate-fadeIn min-h-[calc(100dvh-8rem)]">
            {/* Left sidebar — dropdown selector */}
            <div className="w-full lg:w-72 bg-white rounded-2xl shadow-md border border-rose-100 p-4 flex flex-col shrink-0 overflow-hidden">
              <h3 className="text-xs font-black text-rose-700 mb-3 border-b border-rose-100 pb-2 flex items-center gap-2">
                <span className="text-base">👨‍👧</span> اختيار الابن
              </h3>
              <div className="space-y-3">
                <select
                  value={activeChild?.id || ''}
                  onChange={e => {
                    const selectedId = e.target.value;
                    const ch = children.find(c => c.id === selectedId);
                    if (ch) { setActiveChild(ch); setActiveSubject(null); }
                  }}
                  className="w-full p-3 bg-rose-50 border border-rose-200 rounded-xl font-bold text-sm text-rose-800 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 focus:ring-2 focus:ring-rose-100 outline-none transition-all cursor-pointer"
                >
                  <option value="" disabled>اختر الابن</option>
                  {children.map(child => (
                    <option key={child.id} value={child.id}>{child.name}</option>
                  ))}
                </select>

                {/* Mini summary of selected child */}
                {activeChild && (() => {
                  const qs = getChildQuizzes(activeChild.id);
                  const avg = getChildAverage(activeChild.id);
                  const initials = activeChild.name.split(' ').map(n => n[0]).join('').slice(0, 2);
                  const colors = [
                    {bg: 'from-rose-400 to-orange-400', ring: 'ring-rose-200'},
                    {bg: 'from-emerald-400 to-teal-400', ring: 'ring-emerald-200'},
                    {bg: 'from-sky-400 to-rose-400', ring: 'ring-sky-200'},
                    {bg: 'from-violet-400 to-purple-400', ring: 'ring-violet-200'},
                    {bg: 'from-amber-400 to-yellow-400', ring: 'ring-amber-200'},
                  ];
                  const c = colors[activeChild.name.length % colors.length];
                  return (
                    <div className="bg-rose-500 text-white p-4 rounded-2xl shadow-md animate-fadeIn">
                      <div className="flex items-center gap-3 mb-3">
                        <div className={`w-12 h-12 rounded-xl bg-gradient-to-br ${c.bg} flex items-center justify-center text-white font-black text-lg ring-2 ${c.ring}`}>{initials}</div>
                        <div>
                          <p className="font-black text-sm">{activeChild.name}</p>
                          <p className="text-rose-200 text-[10px] font-bold">{activeChild.primaryGrade || activeChild.grade}</p>
                        </div>
                      </div>
                      <div className="grid grid-cols-3 gap-2 text-center">
                        <div className="bg-white/10 rounded-lg p-2"><p className="font-black text-sm">{subjectsOfChild.length}</p><p className="text-[9px] text-rose-200 font-bold">مواد</p></div>
                        <div className="bg-white/10 rounded-lg p-2"><p className="font-black text-sm">{qs.length}</p><p className="text-[9px] text-rose-200 font-bold">اختبارات</p></div>
                        <div className="bg-white/10 rounded-lg p-2"><p className="font-black text-sm">{avg}%</p><p className="text-[9px] text-rose-200 font-bold">معدل</p></div>
                      </div>
                    </div>
                  );
                })()}
              </div>
            </div>

            {/* Main detail area */}
            <div className="min-w-0 flex-1 flex flex-col overflow-hidden">
              <div className="flex-1 overflow-y-auto pr-1 min-h-0">
                {activeChild ? (
                  <div className="space-y-5 pb-4">
                    {/* Profile Card — compact */}
                    <div className="bg-gradient-to-r from-rose-500 to-rose-600 p-5 rounded-2xl shadow-xl text-white">
                      <div className="flex items-center justify-between gap-3">
                        <div className="flex items-center gap-3">
                          <div className="text-4xl">👤</div>
                          <div>
                            <h1 className="text-xl font-black">{activeChild.name}</h1>
                            <div className="flex gap-2 flex-wrap mt-1">
                              <span className="bg-white/20 text-white px-2 py-0.5 rounded-full font-bold text-xs">🎓 {activeChild.primaryGrade || activeChild.grade}</span>
                              <span className="bg-white/20 text-white px-2 py-0.5 rounded-full font-bold text-xs">👨‍🏫 {parent?.name}</span>
                            </div>
                          </div>
                        </div>
                         {permissions.canResetStudentPassword && (
                           <button onClick={() => handleResetStudentPassword(activeChild)} className="bg-white text-rose-500 px-4 py-2 rounded-xl font-black hover:bg-rose-100 shadow-lg transition-all text-xs shrink-0">
                             🔑 تغيير المرور
                           </button>
                         )}
                      </div>
                    </div>

                    {/* Quick Stats — compact 3-col */}
                    <div className="grid grid-cols-3 gap-3">
                      <div className="bg-blue-50 p-3 rounded-xl border border-blue-100 text-center">
                        <p className="text-blue-900 font-black text-lg">{subjectsOfChild.length}</p>
                        <p className="text-blue-500 text-[10px] font-bold">مواد</p>
                      </div>
                      <div className="bg-purple-50 p-3 rounded-xl border border-purple-100 text-center">
                        <p className="text-purple-900 font-black text-lg">{myChildQuizzes.length}</p>
                        <p className="text-purple-500 text-[10px] font-bold">اختبارات</p>
                      </div>
                      <div className="bg-green-50 p-3 rounded-xl border border-green-100 text-center">
                        <p className="text-green-900 font-black text-lg">{myChildQuizzes.length > 0 ? (myChildQuizzes.reduce((acc, q) => acc + q.percentage, 0) / myChildQuizzes.length).toFixed(0) : '0'}%</p>
                        <p className="text-green-500 text-[10px] font-bold">معدل</p>
                      </div>
                    </div>

                    {/* Subject Cards — compact grid */}
                    <div>
                      <h3 className="text-base font-black mb-3 text-rose-800 flex items-center gap-2">
                        <span className="w-1 h-4 bg-rose-500 rounded-full"></span> 📚 المواد والتحصيل
                      </h3>
                      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3">
                        {subjectsOfChild.length > 0 ? subjectsOfChild.map(subObj => {
                          const subQuizzes = myChildQuizzes.filter(q => q.subject === subObj.subject);
                          const avg = subQuizzes.length > 0 ? (subQuizzes.reduce((acc, q) => acc + q.percentage, 0) / subQuizzes.length).toFixed(0) : '0';
                          const lastQuiz = subQuizzes.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())[0];
                          const level = subQuizzes.length === 0 ? 'لم يبدأ 📚' : parseInt(avg as string) >= 90 ? 'ممتاز 🌟' : parseInt(avg as string) >= 70 ? 'جيد جداً ⭐' : parseInt(avg as string) >= 60 ? 'جيد 👍' : 'يحتاج تحسين 📖';
                          const barColor = subQuizzes.length === 0 ? 'bg-rose-200' : parseInt(avg as string) >= 90 ? 'bg-gradient-to-r from-emerald-400 to-emerald-600' : parseInt(avg as string) >= 70 ? 'bg-gradient-to-r from-blue-400 to-blue-600' : parseInt(avg as string) >= 60 ? 'bg-gradient-to-r from-amber-400 to-amber-600' : 'bg-gradient-to-r from-red-400 to-red-600';
                          return (
                            <div key={`${subObj.subject}-${subObj.atram}`} className="bg-white p-4 rounded-2xl shadow-sm border border-rose-100 hover:shadow-md hover:border-rose-300 transition-all">
                              <div className="flex items-start justify-between mb-2">
                                <div className="flex-1 min-w-0">
                                  <h4 className="text-sm font-black text-rose-800 truncate">{subObj.subject}</h4>
                                  {subObj.atram && <span className="inline-block mt-0.5 text-[10px] font-bold bg-rose-50 text-rose-500 px-1.5 py-0.5 rounded-full">{subObj.atram}</span>}
                                </div>
                                <div className={`text-white px-2 py-1 rounded-lg text-center shadow-md text-sm font-black ${subQuizzes.length === 0 ? 'bg-rose-300' : 'bg-rose-500'}`}>
                                  {avg}%
                                </div>
                              </div>
                              <div className="flex items-center justify-between text-[10px] font-bold text-rose-400 mb-1.5">
                                <span>{subQuizzes.length} اختبار</span>
                                <span className={parseInt(avg as string) >= 70 ? 'text-emerald-600' : parseInt(avg as string) >= 60 ? 'text-amber-600' : 'text-red-500'}>{level}</span>
                              </div>
                              <div className="w-full bg-rose-100 rounded-full h-1.5 mb-2.5">
                                <div className={`h-full rounded-full ${barColor}`} style={{width: subQuizzes.length === 0 ? '0%' : `${avg}%`}}></div>
                              </div>
                              <div className="flex gap-2">
                                <button onClick={() => { setActiveSubject(subObj.subject); setMenuType(ParentMenuType.CHILDREN); }} className="flex-1 bg-rose-500 text-white py-1.5 rounded-xl font-bold hover:bg-rose-600 transition-all text-xs">التفاصيل</button>
                                {subQuizzes.length > 0 && <button onClick={() => printSubjectReport(activeChild, subObj.subject)} className="px-2.5 bg-rose-100 text-rose-500 py-1.5 rounded-xl font-bold hover:bg-rose-500 hover:text-white transition-all text-xs">🖨️</button>}
                              </div>
                            </div>
                          );
                        }) : (
                          <div className="col-span-full rounded-2xl border-2 border-dashed border-rose-200 bg-rose-50 p-5 text-center sm:p-10">
                            <p className="text-3xl mb-2">📚</p>
                            <p className="text-rose-500 font-bold text-sm">لم يتم رصد نتائج بعد</p>
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Active subject detail */}
                    {activeSubject && (
                      <div className="space-y-5 animate-fadeIn">
                        <button onClick={() => setActiveSubject(null)} className="bg-white px-4 py-1.5 rounded-full font-black text-rose-500 border border-rose-200 shadow-sm hover:bg-rose-50 transition-all text-xs">← جميع المواد</button>
                        <div className="bg-gradient-to-r from-rose-500 to-rose-600 p-4 rounded-2xl shadow-xl text-white">
                          <div className="flex items-center justify-between gap-3">
                            <div>
                              <h2 className="text-lg font-black">📚 {activeSubject}</h2>
                              <div className="flex gap-3 text-rose-200 font-bold text-xs mt-1"><span>{activeChild.name}</span><span>• {activeChild.grade}</span><span>• {activeChild.atram}</span></div>
                            </div>
                            {myChildQuizzes.filter(q => q.subject === activeSubject).length > 0 && (
                              <button onClick={() => printSubjectReport(activeChild, activeSubject)} className="bg-white text-rose-500 px-4 py-2 rounded-xl font-black shadow-lg hover:shadow-xl transition-all text-xs shrink-0">🖨️ طباعة</button>
                            )}
                          </div>
                        </div>
                        {(() => {
                          const subQuizzes = myChildQuizzes.filter(q => q.subject === activeSubject);
                          const avg = subQuizzes.length > 0 ? (subQuizzes.reduce((acc, q) => acc + q.percentage, 0) / subQuizzes.length).toFixed(0) : '0';
                          return (
                            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                              <div className="bg-emerald-50 p-3 rounded-xl border border-emerald-100 text-center"><p className="text-emerald-600 text-[10px] font-bold">المعدل</p><p className="text-xl font-black text-emerald-700">{avg}%</p></div>
                              <div className="bg-blue-50 p-3 rounded-xl border border-blue-100 text-center"><p className="text-blue-600 text-[10px] font-bold">أعلى</p><p className="text-xl font-black text-blue-700">{subQuizzes.length > 0 ? Math.max(...subQuizzes.map(q => q.percentage)) : 0}%</p></div>
                              <div className="bg-purple-50 p-3 rounded-xl border border-purple-100 text-center"><p className="text-purple-600 text-[10px] font-bold">أقل</p><p className="text-xl font-black text-purple-700">{subQuizzes.length > 0 ? Math.min(...subQuizzes.map(q => q.percentage)) : 0}%</p></div>
                              <div className="bg-orange-50 p-3 rounded-xl border border-orange-100 text-center"><p className="text-orange-600 text-[10px] font-bold">العدد</p><p className="text-xl font-black text-orange-700">{subQuizzes.length}</p></div>
                            </div>
                          );
                        })()}
                        {/* Quiz results list */}
                        <div className="bg-white p-4 rounded-2xl shadow-sm border border-rose-100">
                          <h3 className="text-sm font-black text-rose-800 mb-3">📋 نتائج الاختبارات</h3>
                          <div className="space-y-2">
                            {myChildQuizzes.filter(q => q.subject === activeSubject).reverse().length > 0 ?
                              myChildQuizzes.filter(q => q.subject === activeSubject).reverse().map((q, i) => (
                                <div key={i} className="flex items-center justify-between p-3 bg-rose-50 rounded-xl border border-rose-100 hover:border-rose-300 transition-all">
                                  <div className="flex-1 min-w-0">
                                    <h5 className="font-bold text-sm text-rose-800">{getQuizTypeLabel(q.quizType)} {q.unit ? '- ' + q.unit : ''}</h5>
                                    <p className="text-rose-400 font-bold text-[10px]">{new Date(q.createdAt).toLocaleDateString('ar-SA', { month: 'short', day: 'numeric' })}</p>
                                  </div>
                                  <div className="text-center mr-3 shrink-0">
                                    <div className={`text-lg font-black rounded-lg px-3 py-1 ${q.percentage >= 80 ? 'bg-emerald-100 text-emerald-700' : q.percentage >= 60 ? 'bg-amber-100 text-amber-700' : 'bg-red-100 text-red-700'}`}>{q.percentage}%</div>
                                  </div>
                                </div>
                              )) :
                              <div className="p-6 text-center bg-rose-50 rounded-xl border border-dashed border-rose-200"><p className="text-rose-400 font-bold text-sm">لا توجد نتائج بعد</p></div>
                            }
                          </div>
                        </div>

                        {/* Certificates for this subject */}
                        {(() => {
                          const subCerts = getAllCertificates().filter((c: CertificateRecord) => c.studentId === activeChild.id && c.subject === activeSubject);
                          if (subCerts.length === 0) return null;
                          return (
                            <div className="bg-white p-4 rounded-2xl shadow-sm border border-rose-100">
                              <h3 className="text-sm font-black text-rose-800 mb-3">🏆 الشهادات في هذه المادة</h3>
                              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                                {subCerts.map((cert, i) => (
                                  <div key={i} className={`p-3 rounded-xl border ${cert.type === 'excellence' ? 'bg-amber-50 border-amber-200' : cert.type === 'appreciation' ? 'bg-blue-50 border-blue-200' : 'bg-emerald-50 border-emerald-200'} flex items-center gap-3`}>
                                    <div className="text-2xl shrink-0">{cert.type === 'excellence' ? '🏆' : cert.type === 'appreciation' ? '⭐' : '🌟'}</div>
                                    <div className="flex-1 min-w-0">
                                      <p className="font-bold text-xs text-rose-800 truncate">{cert.type === 'excellence' ? 'شهادة تفوق' : cert.type === 'appreciation' ? 'شهادة شكر' : 'شهادة مشاركة'}</p>
                                      <p className="text-[10px] text-rose-400 font-bold">{new Date(cert.date).toLocaleDateString('ar-SA', {month:'short', day:'numeric', year:'numeric'})}</p>
                                    </div>
                                    <button onClick={() => setPreviewCert(cert)} className="text-xs font-bold text-rose-500 hover:text-rose-800 shrink-0">معاينة</button>
                                  </div>
                                ))}
                              </div>
                            </div>
                          );
                        })()}

                        {/* Level analysis */}
                        {(() => {
                          const subQuizzes = myChildQuizzes.filter(q => q.subject === activeSubject);
                          const avg = subQuizzes.length > 0 ? (subQuizzes.reduce((acc, q) => acc + q.percentage, 0) / subQuizzes.length).toFixed(0) : '0';
                          const trend = subQuizzes.length >= 2 ? subQuizzes.sort((a,b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()).map(q => q.percentage) : [];
                          const improving = trend.length >= 2 && trend[trend.length - 1] > trend[0];
                          const declining = trend.length >= 2 && trend[trend.length - 1] < trend[0];
                          return (
                            <div className="bg-rose-50 p-4 rounded-2xl border border-rose-100">
                              <h3 className="text-sm font-black text-rose-800 mb-2">📊 تحليل المستوى</h3>
                              <div className="flex flex-wrap gap-2">
                                <span className="px-3 py-1.5 rounded-full bg-white text-xs font-bold text-rose-700 border border-rose-200">🎯 المعدل: {avg}%</span>
                                {improving && <span className="px-3 py-1.5 rounded-full bg-emerald-100 text-xs font-bold text-emerald-700 border border-emerald-200">📈 تحسن مستمر</span>}
                                {declining && <span className="px-3 py-1.5 rounded-full bg-red-100 text-xs font-bold text-red-700 border border-red-200">📉 تراجع ملاحظ</span>}
                                {!improving && !declining && trend.length >= 2 && <span className="px-3 py-1.5 rounded-full bg-amber-100 text-xs font-bold text-amber-700 border border-amber-200">➖ مستوى مستقر</span>}
                              </div>
                            </div>
                          );
                        })()}
                      </div>
                    )}
                  </div>
                ) : (
                  <div className="flex flex-col items-center justify-center h-full text-center">
                    <div className="text-5xl mb-3">👨‍👧</div>
                    <p className="text-rose-500 font-black text-base mb-1">اختر الابن من الشريط الأيسر</p>
                    <p className="text-rose-400 text-xs font-bold">انقر على أي ابن لعرض تفاصيله</p>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* ---------- ADD CHILDREN ---------- */}
        {menuType === ParentMenuType.ADD_CHILDREN && (
          <div className="max-w-xl mx-auto animate-fadeIn space-y-5">
            <div className="bg-gradient-to-r from-rose-500 to-rose-600 p-5 rounded-2xl shadow-xl text-white">
              <h1 className="text-xl font-black">➕ إضافة ابن/ابنة جديد</h1>
              <p className="text-rose-200 font-bold text-xs mt-1">قم بملء بيانات الابن</p>
            </div>
            <div className="bg-white p-6 rounded-2xl shadow-md border border-rose-100">
              <form onSubmit={handleAddChild} className="space-y-4 text-right">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">الاسم الكامل *</label><input type="text" placeholder="أدخل اسم الابن" value={newChild.name} onChange={e => setNewChild({...newChild, name: e.target.value})} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" required /></div>
                   <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">جنس الطالب *</label><select value={newChild.gender} onChange={e => setNewChild({...newChild, gender: e.target.value as StudentGender})} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" required>{STUDENT_GENDER_OPTIONS.map(option => <option key={option.value} value={option.value}>{option.emoji} {option.label}</option>)}</select></div>
                  <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">اسم المستخدم (اختياري)</label><input type="text" placeholder="مثال: ali123" value={newChild.username} onChange={e => setNewChild({...newChild, username: e.target.value})} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" /></div>
                  <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">رقم الهوية *</label><input type="text" placeholder="رقم الهوية الفريد" value={newChild.studentIdNumber} onChange={e => setNewChild({...newChild, studentIdNumber: e.target.value})} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" required /></div>
                  <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">كلمة المرور *</label><input type="password" placeholder="كلمة المرور (6+ رموز)" value={newChild.password} onChange={e => setNewChild({...newChild, password: e.target.value})} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" required /></div>
                  <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">الصف الأساسي *</label><select value={newChild.primaryGrade} onChange={e => { setNewChild({...newChild, primaryGrade: e.target.value}); const subs = getSubjectsForGrade(e.target.value, parent ? getParentTeacherId(parent, children) : ''); setAvailableSubjects(subs); }} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" required><option value="">اختر الصف الأساسي</option>{grades.map((g, i) => <option key={i} value={g}>{g}</option>)}</select></div>
                  <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">المادة *</label><select value={newChild.enrollmentSubject} onChange={e => setNewChild({...newChild, enrollmentSubject: e.target.value})} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" required><option value="">اختر المادة</option>{availableSubjects.map((s, i) => <option key={i} value={s}>{s}</option>)}</select></div>
                </div>
                <div className="flex gap-3 pt-2">
                  <button type="submit" className="flex-1 bg-rose-500 text-white px-5 py-2.5 rounded-xl font-black text-sm hover:bg-rose-600 shadow-md transition-all">✅ حفظ البيانات</button>
                   <button type="button" onClick={() => setNewChild({ name: '', gender: 'male', username: '', password: '', studentIdNumber: '', primaryGrade: '', gradeEnrollments: [], currentGradeForEnrollment: '', enrollmentSubject: '', enrollmentAtram: '', enrollmentTerm: '', enrollmentUnit: '' })} className="px-5 py-2.5 bg-rose-100 text-rose-600 rounded-xl font-bold text-sm hover:bg-rose-200 transition-all">إلغاء</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {menuType === ParentMenuType.PERMISSION_PACKAGES && parent && (
          <PermissionPackageManagement
            managerRole="parent"
            parent={parent}
          />
        )}

        {/* ---------- CERTIFICATES ---------- */}
        {menuType === ParentMenuType.CERTIFICATES && (
          <div className="flex flex-col lg:flex-row gap-4 animate-fadeIn min-h-[calc(100dvh-8rem)]">
            {/* Inner sidebar — children list */}
            <div className="w-full lg:w-56 bg-white rounded-2xl shadow-md border border-rose-100 p-3 flex flex-col shrink-0 overflow-hidden">
              <h3 className="text-xs font-black text-rose-700 mb-2 border-b border-rose-100 pb-2">👨‍👧 الأبناء</h3>
              <div className="flex-1 overflow-y-auto space-y-2">
                <button
                  onClick={() => setCertSelectedChild(null)}
                  className={`w-full text-right p-2 rounded-xl transition-all text-xs font-bold ${!certSelectedChild ? 'bg-rose-500 text-white shadow-sm' : 'hover:bg-rose-50 text-rose-700'}`}
                >
                  📋 جميع الأبناء
                </button>
                {children.map(child => (
                  <button
                    key={child.id}
                    onClick={() => setCertSelectedChild(child)}
                    className={`w-full text-right p-2 rounded-xl transition-all text-xs font-bold ${
                      certSelectedChild?.id === child.id ? 'bg-rose-500 text-white shadow-sm' : 'hover:bg-rose-50 text-rose-700'
                    }`}
                  >
                    {getStudentEmoji(child)} {child.name}
                  </button>
                ))}
              </div>
            </div>

            {/* Main certificates area */}
            <div className="min-w-0 flex-1 flex flex-col overflow-hidden">
              {/* Filter bar */}
              <div className="bg-white p-3 rounded-2xl shadow-md border border-rose-100 mb-3 shrink-0">
                <div className="flex flex-col md:flex-row gap-2 items-stretch md:items-center">
                  <div className="flex-1 relative">
                    <span className="absolute right-3 top-1/2 -translate-y-1/2 text-rose-400 text-sm">🔍</span>
                    <input
                      type="text"
                      placeholder="ابحث باسم الابن أو المادة..."
                      value={certSearch}
                      onChange={e => setCertSearch(e.target.value)}
                      className="w-full p-2 pr-9 rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm"
                    />
                  </div>
                  <select
                    value={certFilterType}
                    onChange={e => setCertFilterType(e.target.value as any)}
                    className="p-2 rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm bg-white"
                  >
                    <option value="all">🏆 جميع الأنواع</option>
                    <option value="excellence">🏆 تفوق</option>
                    <option value="appreciation">⭐ شكر وتقدير</option>
                    <option value="participation">🌟 مشاركة</option>
                  </select>
                </div>
                <div className="mt-2 flex gap-2 flex-wrap">
                  <span className="text-[10px] font-bold text-rose-400">{filteredCertificates.length} شهادة</span>
                  {certSelectedChild && <span className="text-[10px] font-bold text-rose-500 bg-rose-50 px-2 py-0.5 rounded-full">👤 {certSelectedChild.name}</span>}
                </div>
              </div>

              {/* Certificates grid */}
              <div className="flex-1 overflow-y-auto">
                {filteredCertificates.length > 0 ? (
                  <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-3 pb-2">
                    {filteredCertificates.map((cert, idx) => (
                      <div key={idx} className={`bg-white p-4 rounded-2xl shadow-sm border transform hover:scale-[1.01] transition-all ${
                        cert.type === 'excellence' ? 'border-amber-200' : cert.type === 'appreciation' ? 'border-blue-200' : 'border-emerald-200'
                      }`}>
                        <div className="flex items-start gap-3 mb-3">
                          <div className="text-3xl shrink-0">{cert.type === 'excellence' ? '🏆' : cert.type === 'appreciation' ? '⭐' : '🌟'}</div>
                          <div className="flex-1 min-w-0">
                            <h4 className="font-black text-sm">{cert.type === 'excellence' ? 'شهادة تفوق' : cert.type === 'appreciation' ? 'شهادة شكر' : 'شهادة مشاركة'}</h4>
                            <p className="text-rose-400 text-[10px] font-bold mt-0.5">{cert.studentName}</p>
                          </div>
                        </div>
                        <div className="space-y-0.5 text-[11px] font-bold text-rose-500 mb-3">
                          <p className="truncate">📚 <span className="text-rose-700">{cert.subject}</span> · 📅 <span className="text-rose-700">{cert.atram}</span></p>
                          <p className="truncate">🎓 <span className="text-rose-700">{cert.grade}</span> · 👨‍🏫 <span className="text-rose-700">{cert.teacherName || 'غير محدد'}</span></p>
                          <p>📅 <span className="text-rose-700">{new Date(cert.date).toLocaleDateString('ar-SA', {month:'short', day:'numeric'})}</span></p>
                        </div>
                        <div className="flex gap-2">
                          <button onClick={() => setPreviewCert(cert)} className="flex-1 bg-rose-500 text-white py-1.5 rounded-xl font-bold hover:bg-rose-600 transition-all text-xs">معاينة</button>
                          <button onClick={() => printCertificate(cert)} className="px-3 bg-rose-100 text-rose-600 py-1.5 rounded-xl font-bold hover:bg-rose-500 hover:text-white transition-all text-xs">🖨️</button>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="flex flex-col items-center justify-center h-full text-center">
                    <div className="text-5xl mb-3">🏆</div>
                    <p className="text-rose-500 font-black text-base mb-1">لا توجد شهادات</p>
                    <p className="text-rose-400 text-xs font-bold">ستظهر هنا جميع الشهادات المصدرة</p>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* ---------- SETTINGS ---------- */}
        {menuType === ParentMenuType.SETTINGS && (
          <div className="max-w-lg bg-white p-6 rounded-2xl shadow-md border border-rose-100 mx-auto animate-fadeIn space-y-5">
            <h1 className="text-xl font-black text-rose-800 flex items-center gap-2">
              <span className="w-1 h-5 bg-rose-500 rounded-full"></span> إعدادات الحساب
            </h1>
            <div className="space-y-4 text-right">
              <div className="border-b border-rose-100 pb-3"><p className="text-rose-400 text-[10px] font-bold uppercase">الاسم الكامل</p><p className="text-rose-800 font-black text-lg">{parent?.name}</p></div>
              <div className="border-b border-rose-100 pb-3"><p className="text-rose-400 text-[10px] font-bold uppercase">اسم المستخدم</p><p className="text-rose-800 font-black text-lg">{parent?.username}</p></div>
            </div>
            <form onSubmit={handleSavePassword} className="space-y-3 text-right border-t border-rose-100 pt-5">
              <h2 className="text-sm font-black text-rose-800">🔐 تعديل كلمة المرور</h2>
              <input
                type="password"
                value={currentPasswordDraft}
                onChange={e => setCurrentPasswordDraft(e.target.value)}
                placeholder="كلمة المرور الحالية"
                className="w-full p-3 rounded-xl border border-rose-200 bg-rose-50 outline-none focus:border-rose-400 font-bold text-sm"
                required
              />
              <input
                type="password"
                value={newPasswordDraft}
                onChange={e => setNewPasswordDraft(e.target.value)}
                placeholder="كلمة المرور الجديدة (6 أحرف على الأقل)"
                className="w-full p-3 rounded-xl border border-rose-200 bg-rose-50 outline-none focus:border-rose-400 font-bold text-sm"
                required
              />
              <input
                type="password"
                value={confirmPasswordDraft}
                onChange={e => setConfirmPasswordDraft(e.target.value)}
                placeholder="تأكيد كلمة المرور الجديدة"
                className="w-full p-3 rounded-xl border border-rose-200 bg-rose-50 outline-none focus:border-rose-400 font-bold text-sm"
                required
              />
              {passwordSaveError && (
                <p className="rounded-xl bg-red-50 p-3 text-center text-xs font-bold text-red-600">
                  ⚠️ {passwordSaveError}
                </p>
              )}
              <button type="submit" className="w-full bg-rose-700 text-white py-3 rounded-xl font-black text-sm hover:bg-black transition-all">
                💾 حفظ تعديلات الحساب
              </button>
            </form>
          </div>
        )}
        </div>
      </main>

      {/* ===== Preview Modal ===== */}
      {previewCert && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-3 safe-area-x safe-area-top safe-area-bottom" onClick={() => setPreviewCert(null)}>
          <div className="mobile-modal-panel w-full max-w-md rounded-2xl bg-white p-5 shadow-2xl animate-slideUp" onClick={e => e.stopPropagation()}>
            <div className="text-center mb-4">
              <div className="text-5xl mb-2">{previewCert.type === 'excellence' ? '🏆' : previewCert.type === 'appreciation' ? '⭐' : '🌟'}</div>
              <h3 className="text-xl font-black text-rose-800">{previewCert.type === 'excellence' ? 'شهادة تفوق' : previewCert.type === 'appreciation' ? 'شهادة شكر' : 'شهادة مشاركة'}</h3>
            </div>
            <div className="space-y-2 text-right font-bold text-rose-700 mb-4 text-sm">
              <p className="bg-rose-50 p-2.5 rounded-xl">👤 الطالب: <span className="text-rose-700">{previewCert.studentName}</span></p>
              <p className="bg-rose-50 p-2.5 rounded-xl">📚 المادة: <span className="text-rose-700">{previewCert.subject}</span> · 📅 <span className="text-rose-700">{previewCert.atram}</span></p>
              <p className="bg-rose-50 p-2.5 rounded-xl">🎓 الصف: <span className="text-rose-700">{previewCert.grade}</span> · 👨‍🏫 <span className="text-rose-700">{previewCert.teacherName || 'غير محدد'}</span></p>
              <p className="bg-rose-50 p-2.5 rounded-xl">📅 التاريخ: <span className="text-rose-700">{new Date(previewCert.date).toLocaleDateString('ar-SA')}</span></p>
            </div>
            <div className="flex gap-2">
              <button onClick={() => { printCertificate(previewCert); setPreviewCert(null); }} className="flex-1 bg-rose-500 text-white py-2.5 rounded-xl font-black hover:bg-rose-600 transition-all text-sm">🖨️ طباعة</button>
              <button onClick={() => setPreviewCert(null)} className="px-5 py-2.5 bg-rose-100 text-rose-600 rounded-xl font-bold hover:bg-rose-200 transition-all text-sm">إغلاق</button>
            </div>
          </div>
        </div>
      )}

      {/* ===== Chat ===== */}
      {showChat && parent && (
        <PrivateChat currentUserId={parent.id} currentUserName={parent.name} currentUserRole="parent" onClose={() => setShowChat(false)} />
      )}

      {/* ===== Change Grade Modal ===== */}
      {showChangeGradeModal && studentToChangeGrade && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-3 safe-area-x safe-area-top safe-area-bottom">
          <div className="mobile-modal-panel w-full max-w-sm rounded-2xl bg-white p-5 shadow-2xl sm:p-6">
            <div className="text-center mb-4"><div className="text-4xl mb-2">📚</div><h2 className="text-lg font-black text-rose-900 mb-1">تغيير الصف</h2><p className="text-rose-400 font-bold text-xs">{studentToChangeGrade.name}</p></div>
            <div className="mb-4 space-y-2">
              <label className="block text-xs font-bold text-rose-600">الصف الحالي: <span className="text-rose-500">{studentToChangeGrade.primaryGrade || studentToChangeGrade.grade}</span></label>
              <select value={selectedNewGrade} onChange={e => setSelectedNewGrade(e.target.value)} className="w-full p-3 rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm bg-rose-50">
                {availableGrades.map(grade => <option key={grade} value={grade}>{grade}</option>)}
              </select>
            </div>
            <div className="flex gap-2">
              <button onClick={() => { setShowChangeGradeModal(false); setStudentToChangeGrade(null); }} className="flex-1 py-2.5 rounded-xl border border-rose-200 text-rose-600 font-bold text-sm hover:bg-rose-50 transition-all">إلغاء</button>
              <button onClick={handleConfirmGradeChange} className="flex-1 py-2.5 rounded-xl bg-rose-500 text-white font-bold text-sm hover:bg-rose-600 transition-all">✅ تأكيد</button>
            </div>
          </div>
        </div>
      )}

      {/* ===== Teacher Info ===== */}
      {parent && (
        <div className="fixed bottom-[calc(1rem+env(safe-area-inset-bottom))] left-[calc(1rem+env(safe-area-inset-left))] z-40">
          {(() => {
            const parents = readStorageArray<ParentInfo>(STORAGE_KEYS.PARENTS);
            const myParent = parents.find((p: any) => p.id === parent.id);
            const parentTeacherId = myParent
              ? getParentTeacherId(myParent, children)
              : '';
            if (parentTeacherId) {
              const teachers = readStorageArray<TeacherInfo>(STORAGE_KEYS.TEACHERS);
              const teacher = teachers.find((t: TeacherInfo) =>
                getRecordTeacherId({ teacherId: t.id }) === parentTeacherId,
              );
              if (teacher) return <div className="bg-white/90 backdrop-blur px-4 py-2 rounded-[12px] shadow-lg border border-rose-100 text-xs font-bold text-rose-700">👨‍🏫 المعلم: <span className="text-rose-800">{teacher.name}</span></div>;
            }
            return null;
          })()}
        </div>
      )}
    </div>
  );
};

export default ParentDashboard;
