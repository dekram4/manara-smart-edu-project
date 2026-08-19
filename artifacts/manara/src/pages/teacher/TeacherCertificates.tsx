import React, { useState, useEffect } from 'react';
import { StudentInfo, QuizResult, ParentInfo, HierarchicalConfig, CertificateRecord, QuizType } from '../../types';
import { STORAGE_KEYS } from '../../constants';
import { getRecordTeacherId, getTeacherParents, getTeacherStudents, normalizeScopeValue } from '../../utils/scope';
import { getQuizResultPercentage } from '../../utils/quizScoring';
import { normalizeQuizType } from '../../utils/quizTypes';

interface TeacherCertificatesProps {
  teacherId: string;
  teacherName: string;
}

const CERT_KEY = 'smartEdu_certificates';

const TeacherCertificates: React.FC<TeacherCertificatesProps> = ({ teacherId, teacherName }) => {
  const [students, setStudents] = useState<StudentInfo[]>([]);
  const [parents, setParents] = useState<ParentInfo[]>([]);
  const [allQuizzes, setAllQuizzes] = useState<QuizResult[]>([]);
  const [certificates, setCertificates] = useState<CertificateRecord[]>([]);
  const [academicConfigs, setAcademicConfigs] = useState<HierarchicalConfig[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedParentId, setSelectedParentId] = useState<string>('all');

  /* issue modal */
  const [issueModalOpen, setIssueModalOpen] = useState(false);
  const [issueStudent, setIssueStudent] = useState<StudentInfo | null>(null);
  const [issueType, setIssueType] = useState<CertificateRecord['type'] | null>(null);
  const [issueSubject, setIssueSubject] = useState('');
  const [issueAtram, setIssueAtram] = useState('');
  const [issueGrade, setIssueGrade] = useState('');

  /* edit modal */
  const [editCert, setEditCert] = useState<CertificateRecord | null>(null);
  const [editType, setEditType] = useState<'excellence' | 'appreciation' | 'participation'>('excellence');
  const [editNote, setEditNote] = useState('');

  useEffect(() => {
    loadData();
  }, [teacherId]);

  const loadData = () => {
    const allParents: ParentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
    const teacherParents = getTeacherParents(allParents, teacherId);

    const allStudents: StudentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
    const teacherStudents = getTeacherStudents(allStudents, teacherId, teacherParents);
    const teacherStudentIds = new Set(teacherStudents.map(student => student.id));

    setParents(teacherParents);
    setStudents(teacherStudents);
    setAllQuizzes(
      JSON.parse(localStorage.getItem(STORAGE_KEYS.QUIZ_RESULTS) || '[]')
        .map((quiz: QuizResult) => ({ ...quiz, percentage: getQuizResultPercentage(quiz) })),
    );
    const allCertificates: CertificateRecord[] = JSON.parse(
      localStorage.getItem(CERT_KEY) || '[]',
    );
    setCertificates(allCertificates.filter(cert =>
      cert.teacherId
        ? cert.teacherId === teacherId
        : teacherStudentIds.has(cert.studentId),
    ));

    const allConfigs: HierarchicalConfig[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    setAcademicConfigs(allConfigs.filter((c: HierarchicalConfig) =>
      getRecordTeacherId(c) === normalizeScopeValue(teacherId),
    ));
  };

  const getStudentAverage = (studentId: string) => {
    const studentQuizzes = allQuizzes.filter(q =>
      q.studentId === studentId && normalizeQuizType(q.quizType) === QuizType.TEACHER,
    );
    if (studentQuizzes.length === 0) return 0;
    return Math.round(studentQuizzes.reduce((acc, q) => acc + getQuizResultPercentage(q), 0) / studentQuizzes.length);
  };

  const getTeacherSubjectAverage = (studentId: string, subject: string, grade?: string) => {
    const normalizedSubject = normalizeScopeValue(subject);
    const normalizedGrade = normalizeScopeValue(grade);
    const studentQuizzes = allQuizzes.filter(q =>
      q.studentId === studentId &&
      normalizeQuizType(q.quizType) === QuizType.TEACHER &&
      normalizeScopeValue(q.subject) === normalizedSubject &&
      (!normalizedGrade || !q.grade || normalizeScopeValue(q.grade) === normalizedGrade),
    );
    if (studentQuizzes.length === 0) return 0;
    return Math.round(
      studentQuizzes.reduce((sum, quiz) => sum + getQuizResultPercentage(quiz), 0) / studentQuizzes.length,
    );
  };

  const hasDuplicate = (studentId: string, type: CertificateRecord['type'], grade: string, subject: string, term: string) => {
    return certificates.some(
      c => c.studentId === studentId && c.type === type && c.grade === grade && c.subject === subject && c.term === term
    );
  };

  const getStudentCerts = (studentId: string) => certificates.filter(c => c.studentId === studentId);

  const deleteCertificate = (certId: string) => {
    if (!window.confirm('هل أنت متأكد من حذف هذه الشهادة؟')) return;
    const updated = certificates.filter(c => c.id !== certId);
    localStorage.setItem(CERT_KEY, JSON.stringify(updated));
    setCertificates(updated);
  };

  const openEdit = (cert: CertificateRecord) => {
    setEditCert(cert);
    setEditType(cert.type);
    setEditNote(cert.note || '');
  };

  const saveEdit = () => {
    if (!editCert) return;
    const updated = certificates.map(c =>
      c.id === editCert.id ? { ...c, type: editType, note: editNote, date: new Date().toISOString() } : c
    );
    localStorage.setItem(CERT_KEY, JSON.stringify(updated));
    setCertificates(updated);
    setEditCert(null);
  };

  /* ===== Issue Modal helpers (Grade → Subject → Atram) ===== */
  const openIssueModal = (student: StudentInfo, type: CertificateRecord['type']) => {
    setIssueStudent(student);
    setIssueType(type);
    setIssueGrade('');
    setIssueSubject('');
    setIssueAtram('');
    setIssueModalOpen(true);
  };

  const getGradeOptions = () => academicConfigs.map(c => c.grade);

  const getSubjectsForGrade = (grade: string) => {
    const set = new Set<string>();
    for (const cfg of academicConfigs.filter(c => c.grade === grade)) {
      for (const a of cfg.atrams || []) {
        for (const s of a.subjects || []) set.add(s.subject);
      }
    }
    return Array.from(set);
  };

  const getAtramsForSubject = (grade: string, subject: string) => {
    const set = new Set<string>();
    for (const cfg of academicConfigs.filter(c => c.grade === grade)) {
      for (const a of cfg.atrams || []) {
        if (a.subjects?.some(s => s.subject === subject)) set.add(a.atram);
      }
    }
    return Array.from(set);
  };

  const resolveTerm = (grade: string, subject: string, atram: string) => {
    for (const cfg of academicConfigs.filter(c => c.grade === grade)) {
      const a = cfg.atrams?.find(x => x.atram === atram);
      if (!a) continue;
      const s = a.subjects?.find(x => x.subject === subject);
      if (!s) continue;
      return s.terms?.[0]?.term || '';
    }
    return '';
  };

  const confirmIssue = () => {
    if (!issueStudent || !issueType || !issueGrade || !issueSubject || !issueAtram) {
      alert('الرجاء تحديد الصف والمادة والترم');
      return;
    }
    const term = resolveTerm(issueGrade, issueSubject, issueAtram);
    if (!term) {
      alert('لم يتم العثور على بيانات مرتبطة بهذا الصف والمادة والترم في إعداداتك');
      return;
    }
    if (hasDuplicate(issueStudent.id, issueType, issueGrade, issueSubject, term)) {
      alert(`تم إصدار شهادة ${issueType === 'excellence' ? 'تفوق' : issueType === 'appreciation' ? 'شكر' : 'مشاركة'} مسبقاً للطالب ${issueStudent.name} في نفس المادة والترم.`);
      return;
    }
    setIssueModalOpen(false);
    doPrintCertificate(issueStudent, issueType, issueGrade, issueAtram, issueSubject, term);
  };

  /* ===== Print / Save Certificate ===== */
  const doPrintCertificate = (
    student: StudentInfo,
    type: 'excellence' | 'appreciation' | 'participation',
    grade: string,
    atram: string,
    subject: string,
    term: string
  ) => {
    const average = getTeacherSubjectAverage(student.id, subject, grade);
    const date = new Date().toLocaleDateString('ar-SA', { year: 'numeric', month: 'long', day: 'numeric' });

    const saved: CertificateRecord[] = JSON.parse(localStorage.getItem(CERT_KEY) || '[]');
    const newCertificate: CertificateRecord = {
      id: Date.now().toString(),
      studentId: student.id,
      studentName: student.name,
      teacherId,
      teacherName,
      type,
      subject,
      grade,
      atram,
      term,
      date: new Date().toISOString(),
      average,
    };
    saved.push(newCertificate);
    localStorage.setItem(CERT_KEY, JSON.stringify(saved));
    setCertificates(saved.filter(cert =>
      cert.teacherId
        ? cert.teacherId === teacherId
        : students.some(teacherStudent => teacherStudent.id === cert.studentId),
    ));

    const certificates_data = {
      excellence: {
        title: 'شهادة تفوق وامتياز',
        emoji: '🏆',
        color: '#FFD700',
        gradient: 'linear-gradient(135deg, #FFD700 0%, #FFA500 100%)',
        message: `يسرنا أن نشهد بأن الطالب/ة <strong>${student.name}</strong> قد أظهر/ت تفوقاً ملحوظاً وأداءً متميزاً في دراسة مادة <strong>${subject}</strong> للترم <strong>${atram}</strong>، حيث حقق/ت في اختبارات المعلم لهذه المادة نسبة <strong>${average}%</strong>. نفخر بإنجازاتك المتميزة ونتمنى لك مزيداً من التقدم والنجاح في مسيرتك التعليمية.`,
      },
      appreciation: {
        title: 'شهادة شكر وتقدير',
        emoji: '⭐',
        color: '#4169E1',
        gradient: 'linear-gradient(135deg, #4169E1 0%, #1E90FF 100%)',
        message: `نتقدم بجزيل الشكر والتقدير للطالب/ة <strong>${student.name}</strong> لجهوده/ها الدؤوبة في دراسة مادة <strong>${subject}</strong> للترم <strong>${atram}</strong>، حيث حقق/ت في اختبارات المعلم لهذه المادة نسبة <strong>${average}%</strong>. نثمن عالياً اجتهادك ونتمنى لك المزيد من النجاح والتوفيق.`,
      },
      participation: {
        title: 'شهادة مشاركة فعالة',
        emoji: '🌟',
        color: '#32CD32',
        gradient: 'linear-gradient(135deg, #32CD32 0%, #228B22 100%)',
        message: `نشهد بأن الطالب/ة <strong>${student.name}</strong> قد أبدى/ت مشاركة فعالة ونشاطاً ملحوظاً في دراسة مادة <strong>${subject}</strong> للترم <strong>${atram}</strong>، وحقق/ت في اختبارات المعلم لهذه المادة نسبة <strong>${average}%</strong>. نقدر حماسك واهتمامك ونشجعك على الاستمرار في هذا النهج الإيجابي.`,
      },
    };

    const cert = certificates_data[type];

    const printWindow = window.open('', '_blank');
    if (!printWindow) return;

    printWindow.document.write(`
      <!DOCTYPE html>
      <html dir="rtl" lang="ar">
        <head>
          <meta charset="UTF-8">
          <title>${cert.title} - ${student.name}</title>
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
              background: ${cert.gradient};
            }
            .certificate::after {
              content: '${cert.emoji}'; position: absolute; font-size: 200px; opacity: 0.05;
              top: 50%; left: 50%; transform: translate(-50%, -50%);
            }
            .header { text-align: center; margin-bottom: 40px; position: relative; }
            .logo { font-size: 80px; margin-bottom: 20px; }
            .title { font-size: 42px; font-weight: 900; background: ${cert.gradient}; -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 10px; }
            .subtitle { font-size: 18px; color: #666; font-weight: 700; }
            .content { text-align: center; line-height: 2.5; font-size: 20px; color: #333; margin: 40px 0; position: relative; }
            .student-name { font-size: 32px; font-weight: 900; color: ${cert.color}; margin: 20px 0; }
            .footer { margin-top: 60px; display: flex; justify-content: space-between; align-items: center; border-top: 3px solid #f0f0f0; padding-top: 30px; }
            .signature { text-align: center; }
            .signature-line { width: 200px; height: 2px; background: #333; margin: 10px auto; }
            .signature-label { font-weight: 700; color: #666; font-size: 16px; }
            .date { text-align: center; color: #666; font-size: 16px; font-weight: 700; }
            .seal { position: absolute; bottom: 40px; left: 40px; width: 120px; height: 120px; border: 5px solid ${cert.color}; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 60px; opacity: 0.3; transform: rotate(-15deg); }
            .border-decoration { position: absolute; top: 20px; right: 20px; width: 60px; height: 60px; border-top: 5px solid ${cert.color}; border-right: 5px solid ${cert.color}; }
            .border-decoration-bottom { position: absolute; bottom: 20px; left: 20px; width: 60px; height: 60px; border-bottom: 5px solid ${cert.color}; border-left: 5px solid ${cert.color}; }
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
            <div class="seal">${cert.emoji}</div>

            <div class="header">
              <div class="logo">${cert.emoji}</div>
              <h1 class="title">${cert.title}</h1>
              <p class="subtitle">منصة التعليم الذكي</p>
            </div>

            <div class="content">
              <p>${cert.message}</p>
              <div class="academic-info">
                <p>المادة: <strong>${subject}</strong> · الصف: <strong>${grade}</strong> · الترم: <strong>${atram}</strong></p>
                <p>نسبة نتائج اختبارات المعلم للمادة: <strong style="font-size:22px;color:${cert.color};">${average}%</strong></p>
              </div>
            </div>

            <div class="footer">
              <div class="signature">
                <div class="signature-line"></div>
                <p class="signature-label">إدارة المنصة</p>
              </div>
              <div class="date"><p>التاريخ: ${date}</p></div>
              <div class="signature">
                <p style="font-weight:900;font-size:18px;color:#333;margin-bottom:10px;">${teacherName}</p>
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

    printWindow.document.close();
  };

  const filteredStudents = students.filter(student => {
    const matchesParent = selectedParentId === 'all' || student.parentId === selectedParentId;
    const search = searchQuery.toLowerCase();
    const matchesSearch = student.name.toLowerCase().includes(search) ||
           (student.username || '').toLowerCase().includes(search) ||
           (student.studentIdNumber || '').includes(search);
    return matchesParent && matchesSearch;
  });

  return (
    <div className="dashboard-page animate-fadeIn">
      {/* Header */}
      <div className="bg-gradient-to-r from-purple-600 to-pink-600 p-8 rounded-[40px] shadow-2xl text-white">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-4xl font-black mb-2">🏆 شهادات التقدير</h1>
            <p className="text-purple-100 text-lg font-medium">
              اطبع شهادات شكر وتقدير للطلاب المتميزين
            </p>
          </div>
          <div className="text-7xl opacity-30">📜</div>
        </div>

        {/* Parent Filter + Search */}
        <div className="mt-6 flex flex-col md:flex-row gap-4">
          <div className="md:w-1/3">
            <select
              value={selectedParentId}
              onChange={(e) => setSelectedParentId(e.target.value)}
              className="w-full p-4 rounded-xl border-2 border-white/30 bg-white/10 text-white font-bold text-lg backdrop-blur outline-none focus:bg-white/20 focus:border-white cursor-pointer"
            >
              <option value="all" className="text-amber-800">👨‍👧 جميع أولياء الأمور</option>
              {parents.map((parent) => (
                <option key={parent.id} value={parent.id} className="text-amber-800">
                  {parent.name} ({students.filter(s => s.parentId === parent.id).length} طالب)
                </option>
              ))}
            </select>
          </div>
          <div className="md:w-2/3 relative">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="🔍 ابحث عن طالب بالاسم أو اسم المستخدم..."
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
      </div>

      {/* Statistics */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <div className="bg-gradient-to-br from-yellow-50 to-yellow-100 p-6 rounded-[30px] shadow-lg border-2 border-yellow-200">
          <div className="text-5xl mb-3">🏆</div>
          <div className="text-3xl font-black text-yellow-900">{students.filter(s => getStudentAverage(s.id) >= 90).length}</div>
          <div className="text-yellow-700 font-bold">طالب متفوق (90%+)</div>
        </div>
        <div className="bg-gradient-to-br from-blue-50 to-blue-100 p-6 rounded-[30px] shadow-lg border-2 border-amber-200">
          <div className="text-5xl mb-3">⭐</div>
          <div className="text-3xl font-black text-blue-900">{students.filter(s => getStudentAverage(s.id) >= 70 && getStudentAverage(s.id) < 90).length}</div>
          <div className="text-blue-700 font-bold">طالب مجتهد (70-89%)</div>
        </div>
        <div className="bg-gradient-to-br from-green-50 to-green-100 p-6 rounded-[30px] shadow-lg border-2 border-green-200">
          <div className="text-5xl mb-3">👨‍🎓</div>
          <div className="text-3xl font-black text-green-900">{students.length}</div>
          <div className="text-green-700 font-bold">إجمالي الطلاب</div>
        </div>
      </div>

      {/* Students List */}
      <div className="bg-white p-8 rounded-[40px] shadow-lg border-2 border-amber-200">
        <h2 className="text-2xl font-black text-amber-900 mb-6">📋 قائمة الطلاب</h2>

        {filteredStudents.length === 0 ? (
          <div className="text-center py-20">
            <div className="text-6xl mb-4">🔍</div>
            <p className="text-gray-500 font-bold text-xl">لا توجد نتائج</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
            {filteredStudents.map((student) => {
              const average = getStudentAverage(student.id);
              const quizCount = allQuizzes.filter(q => q.studentId === student.id).length;
              return (
                <div key={student.id} className="bg-gradient-to-br from-amber-50 to-orange-50 p-6 rounded-[30px] border-2 border-amber-200 hover:shadow-xl transition-all">
                  <div className="flex items-start gap-4 mb-4">
                    <div className="text-5xl">👤</div>
                    <div className="flex-1">
                      <h3 className="text-xl font-black text-amber-900">{student.name}</h3>
                      <p className="text-sm text-amber-600 font-medium">{student.primaryGrade || student.grade}</p>
                      <div className="mt-2 flex gap-2">
                        <span className={`px-3 py-1 rounded-full text-xs font-bold ${average >= 90 ? 'bg-yellow-500 text-white' : average >= 70 ? 'bg-amber-500 text-white' : 'bg-gray-400 text-white'}`}>
                          {average}%
                        </span>
                        <span className="px-3 py-1 rounded-full text-xs font-bold bg-purple-100 text-purple-700">
                          {quizCount} اختبار
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Issued certificates log */}
                  {(() => {
                    const sc = getStudentCerts(student.id);
                    if (sc.length === 0) return null;
                    return (
                      <div className="mt-4 pt-4 border-t border-amber-100">
                        <p className="text-xs font-black text-amber-500 mb-2 uppercase tracking-wider">📜 شهادات مصدّرة</p>
                        <div className="space-y-2">
                          {sc.map(cert => (
                            <div key={cert.id} className="bg-white p-3 rounded-[16px] border border-amber-100 flex items-center justify-between">
                              <div className="flex items-center gap-2">
                                <span className="text-lg">{cert.type === 'excellence' ? '🏆' : cert.type === 'appreciation' ? '⭐' : '🌟'}</span>
                                <div>
                                  <p className="text-sm font-bold text-amber-800">{cert.type === 'excellence' ? 'تفوق' : cert.type === 'appreciation' ? 'شكر' : 'مشاركة'}</p>
                                  <p className="text-[10px] text-amber-500">{cert.grade} · {cert.subject} · {cert.term}</p>
                                </div>
                              </div>
                              <div className="flex gap-1">
                                <button
                                  onClick={() => openEdit(cert)}
                                  className="p-1.5 bg-amber-50 text-amber-500 rounded-lg hover:bg-amber-100 transition-all text-xs font-bold"
                                  title="تعديل"
                                >✏️</button>
                                <button
                                  onClick={() => deleteCertificate(cert.id)}
                                  className="p-1.5 bg-red-50 text-red-500 rounded-lg hover:bg-red-100 transition-all text-xs font-bold"
                                  title="حذف"
                                >🗑️</button>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    );
                  })()}

                  <div className="space-y-2 mt-2">
                    <button
                      onClick={() => openIssueModal(student, 'excellence')}
                      className="w-full bg-gradient-to-r from-yellow-500 to-orange-500 hover:from-yellow-600 hover:to-orange-600 text-white py-3 rounded-[20px] font-bold transition-all shadow-md hover:shadow-lg flex items-center justify-center gap-2 hover:scale-[1.02] active:scale-95"
                    >
                      <span>🏆</span>
                      <span>اصدار شهادة تفوق</span>
                    </button>
                    <button
                      onClick={() => openIssueModal(student, 'appreciation')}
                      className="w-full bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 text-white py-3 rounded-[20px] font-bold transition-all shadow-md hover:shadow-lg flex items-center justify-center gap-2 hover:scale-[1.02] active:scale-95"
                    >
                      <span>⭐</span>
                      <span>اصدار شهادة شكر</span>
                    </button>
                    <button
                      onClick={() => openIssueModal(student, 'participation')}
                      className="w-full bg-gradient-to-r from-green-500 to-teal-500 hover:from-green-600 hover:to-teal-600 text-white py-3 rounded-[20px] font-bold transition-all shadow-md hover:shadow-lg flex items-center justify-center gap-2 hover:scale-[1.02] active:scale-95"
                    >
                      <span>🌟</span>
                      <span>اصدار شهادة مشاركة</span>
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Issue Modal */}
      {issueModalOpen && issueStudent && issueType && (
        <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4 animate-fadeIn" onClick={() => setIssueModalOpen(false)}>
          <div className="mobile-modal-panel bg-white p-5 sm:p-8 rounded-[28px] sm:rounded-[40px] shadow-2xl max-w-lg w-full animate-slideUp" onClick={e => e.stopPropagation()}>
            <h3 className="text-2xl font-black text-amber-900 mb-2">
              {issueType === 'excellence' ? '🏆 إصدار شهادة تفوق' : issueType === 'appreciation' ? '⭐ إصدار شهادة شكر' : '🌟 إصدار شهادة مشاركة'}
            </h3>
            <p className="text-amber-500 text-sm mb-6">{issueStudent.name} — اختر المادة والترم من إعداداتك الأكاديمية</p>

            <div className="space-y-4 text-right">
              <div>
                <label className="block text-sm font-bold text-amber-700 mb-2">🎓 الصف</label>
                <select
                  value={issueGrade}
                  onChange={e => { setIssueGrade(e.target.value); setIssueSubject(''); setIssueAtram(''); }}
                  className="w-full p-4 rounded-xl border-2 border-amber-200 focus:border-amber-500 outline-none font-bold text-lg"
                >
                  <option value="">اختر الصف...</option>
                  {getGradeOptions().map(g => <option key={g} value={g}>{g}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm font-bold text-amber-700 mb-2">📖 المادة</label>
                <select
                  value={issueSubject}
                  onChange={e => { setIssueSubject(e.target.value); setIssueAtram(''); }}
                  className="w-full p-4 rounded-xl border-2 border-amber-200 focus:border-amber-500 outline-none font-bold text-lg"
                  disabled={!issueGrade}
                >
                  <option value="">اختر المادة...</option>
                  {getSubjectsForGrade(issueGrade).map(s => <option key={s} value={s}>{s}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm font-bold text-amber-700 mb-2">📅 الترم</label>
                <select
                  value={issueAtram}
                  onChange={e => setIssueAtram(e.target.value)}
                  className="w-full p-4 rounded-xl border-2 border-amber-200 focus:border-amber-500 outline-none font-bold text-lg"
                  disabled={!issueSubject}
                >
                  <option value="">اختر الترم...</option>
                  {getAtramsForSubject(issueGrade, issueSubject).map(a => <option key={a} value={a}>{a}</option>)}
                </select>
              </div>
            </div>

            <div className="flex flex-col sm:flex-row gap-3 mt-8">
              <button
                onClick={confirmIssue}
                className="flex-1 bg-amber-500 text-white py-4 rounded-[20px] font-black text-lg hover:bg-amber-600 shadow-lg transition-all hover:scale-[1.02] active:scale-95"
              >
                🖨️ إصدار وطباعة
              </button>
              <button
                onClick={() => setIssueModalOpen(false)}
                className="px-6 py-4 bg-amber-100 text-amber-700 rounded-[20px] font-bold hover:bg-amber-200 transition-all"
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {editCert && (
        <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4 animate-fadeIn" onClick={() => setEditCert(null)}>
          <div className="mobile-modal-panel bg-white p-5 sm:p-8 rounded-[28px] sm:rounded-[40px] shadow-2xl max-w-md w-full animate-slideUp" onClick={e => e.stopPropagation()}>
            <h3 className="text-2xl font-black text-amber-900 mb-2">✏️ تعديل الشهادة</h3>
            <p className="text-amber-500 text-sm mb-6">{editCert.studentName} — {editCert.grade} · {editCert.subject}</p>

            <div className="space-y-4 text-right">
              <div>
                <label className="block text-sm font-bold text-amber-700 mb-2">نوع الشهادة</label>
                <select
                  value={editType}
                  onChange={e => setEditType(e.target.value as CertificateRecord['type'])}
                  className="w-full p-4 rounded-xl border-2 border-amber-200 focus:border-amber-500 outline-none font-bold text-lg"
                >
                  <option value="excellence">🏆 شهادة تفوق</option>
                  <option value="appreciation">⭐ شهادة شكر</option>
                  <option value="participation">🌟 شهادة مشاركة</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-bold text-amber-700 mb-2">ملاحظة (اختياري)</label>
                <textarea
                  value={editNote}
                  onChange={e => setEditNote(e.target.value)}
                  className="w-full p-4 rounded-xl border-2 border-amber-200 focus:border-amber-500 outline-none font-bold text-sm resize-none"
                  rows={3}
                  placeholder="اكتب ملاحظة إضافية..."
                />
              </div>
            </div>

            <div className="flex flex-col sm:flex-row gap-3 mt-8">
              <button
                onClick={saveEdit}
                className="flex-1 bg-amber-500 text-white py-4 rounded-[20px] font-black text-lg hover:bg-amber-600 shadow-lg transition-all hover:scale-[1.02] active:scale-95"
              >
                💾 حفظ التعديل
              </button>
              <button
                onClick={() => setEditCert(null)}
                className="px-6 py-4 bg-amber-100 text-amber-700 rounded-[20px] font-bold hover:bg-amber-200 transition-all"
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default TeacherCertificates;
