import { readHierarchicalConfigs, subjectsOfConfig } from '../../utils/academic';
import React, { useState, useEffect } from 'react';
import { StudentInfo, QuizResult, ParentInfo, HierarchicalConfig, CertificateRecord, QuizType } from '../../types';
import { STORAGE_KEYS } from '../../constants';
import { getRecordTeacherId, getTeacherParents, getTeacherStudents, normalizeScopeValue } from '../../utils/scope';
import { getQuizResultPercentage } from '../../utils/quizScoring';
import { normalizeQuizType } from '../../utils/quizTypes';
import { Award, Eye, GraduationCap, Pencil, Plus, Star, Trash2, Trophy } from 'lucide-react';
import { CERTIFICATE_TYPES, certificateDocument, certificateNumber, issuerOf } from '../../utils/officialDocuments';
import DocumentPreview from '../../components/portal/DocumentPreview';
import { Badge, EmptyState, PageHeader, Panel, StatCard, relativeDay, scoreTone, ART } from '../../components/portal/PortalUI';

interface TeacherCertificatesProps {
  /** معرّفُ المعلم — وفي وضع المشرف يُترك فارغاً. */
  teacherId: string;
  /** اسمُ المستخدم المسجّل الآن: يُكتب على الشهادة في خانة الاعتماد. */
  teacherName: string;
  /** المشرفُ يرى طلابَ المنصّة كلَّهم ويُصدر لهم. */
  issuerRole?: 'teacher' | 'admin';
}

const CERT_KEY = 'smartEdu_certificates';
const SIGNATORY_KEY = 'manara_admin_certificate_signatory';

const TeacherCertificates: React.FC<TeacherCertificatesProps> = ({ teacherId, teacherName, issuerRole = 'teacher' }) => {
  const isAdmin = issuerRole === 'admin';
  // ‏المشرفُ لا اسمَ له في النظام (يدخل باسم مستخدمٍ من إعدادات الخادم)، فيكتب
  // ‏الاسمَ الذي تُعتمد به الشهادات مرّةً، ويُحفظ في هذا المتصفّح.
  const [adminSignatory, setAdminSignatory] = useState(() => {
    try { return localStorage.getItem(SIGNATORY_KEY) || teacherName; } catch { return teacherName; }
  });
  const issuerName = isAdmin ? (adminSignatory.trim() || teacherName) : teacherName;
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
  const [issueTerm, setIssueTerm] = useState('');
  const [issueGrade, setIssueGrade] = useState('');

  /* edit modal */
  const [editCert, setEditCert] = useState<CertificateRecord | null>(null);
  const [editType, setEditType] = useState<'excellence' | 'appreciation' | 'participation'>('excellence');
  const [editNote, setEditNote] = useState('');
  const [previewCert, setPreviewCert] = useState<CertificateRecord | null>(null);

  useEffect(() => {
    loadData();
  }, [teacherId]);

  const loadData = () => {
    const allParents: ParentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
    const teacherParents = isAdmin ? allParents : getTeacherParents(allParents, teacherId);

    const allStudents: StudentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
    const teacherStudents = isAdmin ? allStudents : getTeacherStudents(allStudents, teacherId, teacherParents);
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
    setCertificates(isAdmin ? allCertificates : allCertificates.filter(cert =>
      cert.teacherId
        ? cert.teacherId === teacherId
        : teacherStudentIds.has(cert.studentId),
    ));

    setAcademicConfigs(
      readHierarchicalConfigs().filter((c: HierarchicalConfig) =>
        isAdmin || getRecordTeacherId(c) === normalizeScopeValue(teacherId),
      ),
    );
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

  /* ===== Issue Modal helpers (Grade → Subject → Term) ===== */
  const openIssueModal = (student: StudentInfo, type: CertificateRecord['type']) => {
    setIssueStudent(student);
    setIssueType(type);
    setIssueGrade('');
    setIssueSubject('');
    setIssueTerm('');
    setIssueModalOpen(true);
  };

  const getGradeOptions = () => academicConfigs.map(c => c.grade);

  const getSubjectsForGrade = (grade: string) => {
    const set = new Set<string>();
    for (const cfg of academicConfigs.filter(c => c.grade === grade)) {
      for (const s of subjectsOfConfig(cfg)) set.add(s.subject);
    }
    return Array.from(set);
  };

  const getTermsForSubject = (grade: string, subject: string) => {
    const set = new Set<string>();
    for (const cfg of academicConfigs.filter(c => c.grade === grade)) {
      const s = subjectsOfConfig(cfg).find((x: any) => x.subject === subject);
      for (const t of s?.terms || []) set.add(t.term);
    }
    return Array.from(set);
  };

  const confirmIssue = () => {
    if (!issueStudent || !issueType || !issueGrade || !issueSubject || !issueTerm) {
      alert('الرجاء تحديد الصف والمادة والفصل');
      return;
    }
    const term = issueTerm;
    if (hasDuplicate(issueStudent.id, issueType, issueGrade, issueSubject, term)) {
      alert(`تم إصدار شهادة ${issueType === 'excellence' ? 'تفوق' : issueType === 'appreciation' ? 'شكر' : 'مشاركة'} مسبقاً للطالب ${issueStudent.name} في نفس المادة والفصل.`);
      return;
    }
    setIssueModalOpen(false);
    doPrintCertificate(issueStudent, issueType, issueGrade, issueSubject, term);
  };

  /* ===== Print / Save Certificate ===== */
  const doPrintCertificate = (
    student: StudentInfo,
    type: 'excellence' | 'appreciation' | 'participation',
    grade: string,
    subject: string,
    term: string
  ) => {
    const average = getTeacherSubjectAverage(student.id, subject, grade);

    const saved: CertificateRecord[] = JSON.parse(localStorage.getItem(CERT_KEY) || '[]');
    // ‏شهادةُ المشرف تُنسب إلى معلّم الطالب، ويوقّعها المشرف.
    const studentTeacherId = isAdmin ? String(student.teacherId || student.createdBy || '') : teacherId;
    const studentTeacherName = isAdmin
      ? (JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]') as { id: string; name: string }[])
          .find(t => t.id === studentTeacherId)?.name || ''
      : teacherName;
    const newCertificate: CertificateRecord = {
      id: Date.now().toString(),
      studentId: student.id,
      studentName: student.name,
      teacherId: studentTeacherId,
      teacherName: studentTeacherName,
      issuedBy: issuerName,
      issuedByRole: issuerRole,
      type,
      subject,
      grade,
      term,
      date: new Date().toISOString(),
      average,
    };
    saved.push(newCertificate);
    localStorage.setItem(CERT_KEY, JSON.stringify(saved));
    setCertificates(isAdmin ? saved : saved.filter(cert =>
      cert.teacherId
        ? cert.teacherId === teacherId
        : students.some(teacherStudent => teacherStudent.id === cert.studentId),
    ));

    // ‏تُعرض الشهادةُ الصادرة بالقالب الرسمي، ومن المعاينة تُطبع.
    setPreviewCert(newCertificate);
  };

  const filteredStudents = students.filter(student => {
    const matchesParent = selectedParentId === 'all' || student.parentId === selectedParentId;
    const search = searchQuery.toLowerCase();
    const matchesSearch = student.name.toLowerCase().includes(search) ||
           (student.username || '').toLowerCase().includes(search) ||
           (student.studentIdNumber || '').includes(search);
    return matchesParent && matchesSearch;
  });

  const sortedCertificates = [...certificates].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  const typeTone = (type: CertificateRecord['type']) => (type === 'excellence' ? 'gold' : type === 'appreciation' ? 'primary' : 'accent');

  return (
    <div className="portal-page">
      <PageHeader
        eyebrow={isAdmin ? 'لوحة المشرف' : 'بوابة المعلم'}
        title="الشهادات"
        description={isAdmin
          ? 'إصدار الشهادات لطلاب المنصّة، ومعاينتها وطباعتها بتنسيقٍ رسمي.'
          : 'إصدار شهادات التفوّق والتقدير والمشاركة لطلابك، ومعاينتها وطباعتها بتنسيقٍ رسمي.'}
        icon={Award}
        art={ART.reader}
        actions={isAdmin ? (
          <label className="flex items-center gap-2 text-sm font-bold text-slate-600">
            يُوقَّع باسم
            <input
              type="text"
              value={adminSignatory}
              onChange={(e) => {
                setAdminSignatory(e.target.value);
                try { localStorage.setItem(SIGNATORY_KEY, e.target.value); } catch { /* تخزينٌ محجوب: يبقى للجلسة */ }
              }}
              className="rounded-lg border px-3 py-2 text-sm"
              style={{ minWidth: '12rem' }}
            />
          </label>
        ) : <Badge tone="accent">يُوقَّع باسم: {teacherName}</Badge>}
      />

      <div className="portal-stats">
        <StatCard label="متفوّقون (٩٠٪ فأكثر)" value={students.filter(s => getStudentAverage(s.id) >= 90).length} hint="في اختبارات المعلم" icon={Trophy} tone="gold" />
        <StatCard label="مجتهدون (٧٠–٨٩٪)" value={students.filter(s => getStudentAverage(s.id) >= 70 && getStudentAverage(s.id) < 90).length} hint="في اختبارات المعلم" icon={Star} />
        <StatCard label="الطلاب" value={students.length} hint={isAdmin ? 'طلاب المنصّة' : 'طلابك المرتبطون'} icon={GraduationCap} tone="accent" />
        <StatCard label="الشهادات الصادرة" value={certificates.length} hint={isAdmin ? 'لكل الطلاب' : 'منك لطلابك'} icon={Award} tone="success" />
      </div>

      <Panel
        title="إصدار شهادة"
        subtitle="اختر الطالب ثم نوع الشهادة والمادة والفصل"
        icon={GraduationCap}
        flush
        actions={
          <div className="flex flex-wrap gap-2">
            <select
              value={selectedParentId}
              onChange={(e) => setSelectedParentId(e.target.value)}
              className="rounded-lg border px-3 py-2 text-sm"
              aria-label="ولي الأمر"
            >
              <option value="all">كل أولياء الأمور</option>
              {parents.map((parent) => (
                <option key={parent.id} value={parent.id}>
                  {parent.name} ({students.filter(s => s.parentId === parent.id).length})
                </option>
              ))}
            </select>
            <input
              type="search"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="بحث باسم الطالب"
              className="rounded-lg border px-3 py-2 text-sm"
            />
          </div>
        }
      >
        {filteredStudents.length === 0 ? (
          <EmptyState title="لا نتائج" description="غيّر البحث أو ولي الأمر." />
        ) : (
          <div className="portal-table-wrap">
            <table className="portal-table">
              <thead>
                <tr>
                  <th>الطالب</th>
                  <th>الصف</th>
                  <th>معدّل اختبارات المعلم</th>
                  <th>الاختبارات</th>
                  <th>الشهادات</th>
                  <th aria-label="إجراءات" />
                </tr>
              </thead>
              <tbody>
                {filteredStudents.map((student) => {
                  const average = getStudentAverage(student.id);
                  const quizCount = allQuizzes.filter(q => q.studentId === student.id).length;
                  const teacherQuizCount = allQuizzes.filter(q => q.studentId === student.id && normalizeQuizType(q.quizType) === QuizType.TEACHER).length;
                  const issued = getStudentCerts(student.id);
                  return (
                    <tr key={student.id}>
                      <td className="font-bold text-slate-800">{student.name}</td>
                      <td>{student.primaryGrade || student.grade || '—'}</td>
                      <td>{teacherQuizCount === 0 ? <span className="text-slate-400">لا نتائج</span> : <Badge tone={scoreTone(average)}>{average}%</Badge>}</td>
                      <td className="is-num">{quizCount}</td>
                      <td>
                        {issued.length === 0 ? (
                          <span className="text-slate-400">—</span>
                        ) : (
                          <div className="flex flex-wrap gap-1">
                            {issued.map(cert => (
                              <Badge key={cert.id} tone={typeTone(cert.type)}>{CERTIFICATE_TYPES[cert.type]?.short ?? 'شهادة'}</Badge>
                            ))}
                          </div>
                        )}
                      </td>
                      <td>
                        <div className="flex justify-end">
                          <button type="button" className="portal-btn portal-btn-secondary portal-btn-sm" onClick={() => openIssueModal(student, average >= 90 ? 'excellence' : average >= 70 ? 'appreciation' : 'participation')}>
                            <Plus aria-hidden="true" /> إصدار شهادة
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
      </Panel>

      <Panel title="الشهادات الصادرة" subtitle="الأحدث أولاً" icon={Award} flush>
        {sortedCertificates.length === 0 ? (
          <EmptyState title="لم تُصدر شهادات بعد" icon={Award} />
        ) : (
          <div className="portal-table-wrap">
            <table className="portal-table">
              <thead>
                <tr>
                  <th>الشهادة</th>
                  <th>الطالب</th>
                  <th>المادة</th>
                  <th>الصف والفصل</th>
                  <th>المُصدِر</th>
                  <th>رقم الشهادة</th>
                  <th>التاريخ</th>
                  <th aria-label="إجراءات" />
                </tr>
              </thead>
              <tbody>
                {sortedCertificates.map(cert => (
                  <tr key={cert.id}>
                    <td><Badge tone={typeTone(cert.type)}>{CERTIFICATE_TYPES[cert.type]?.short ?? 'شهادة'}</Badge></td>
                    <td className="font-bold text-slate-800">{cert.studentName}</td>
                    <td>{cert.subject}</td>
                    <td>{cert.grade} · {cert.term}</td>
                    <td>{issuerOf(cert).name || '—'}</td>
                    <td className="is-num text-slate-500">{certificateNumber(cert)}</td>
                    <td className="is-num text-slate-500">{relativeDay(cert.date)}</td>
                    <td>
                      <div className="flex justify-end gap-1">
                        <button type="button" className="portal-btn portal-btn-secondary portal-btn-sm" onClick={() => setPreviewCert(cert)}>
                          <Eye aria-hidden="true" /> معاينة
                        </button>
                        <button type="button" className="portal-btn portal-btn-ghost portal-btn-sm" onClick={() => openEdit(cert)} aria-label={`تعديل شهادة ${cert.studentName}`} title="تعديل">
                          <Pencil aria-hidden="true" />
                        </button>
                        <button type="button" className="portal-btn portal-btn-ghost portal-btn-sm text-red-700" onClick={() => deleteCertificate(cert.id)} aria-label={`حذف شهادة ${cert.studentName}`} title="حذف">
                          <Trash2 aria-hidden="true" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Panel>

      {/* إصدار شهادة */}
      {issueModalOpen && issueStudent && issueType && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4" onClick={() => setIssueModalOpen(false)} role="dialog" aria-modal="true" aria-label="إصدار شهادة">
          <div className="portal-panel w-full max-w-lg" onClick={e => e.stopPropagation()}>
            <div className="portal-panel-head">
              <div>
                <h2><Award aria-hidden="true" /> إصدار شهادة</h2>
                <p>{issueStudent.name} — من إعداداتك الأكاديمية</p>
              </div>
            </div>
            <div className="portal-panel-body flex flex-col gap-4">
              <label className="flex flex-col gap-1 text-sm font-bold">
                نوع الشهادة
                <select value={issueType} onChange={e => setIssueType(e.target.value as CertificateRecord['type'])} className="rounded-lg border px-3 py-2.5">
                  <option value="excellence">{CERTIFICATE_TYPES.excellence.title}</option>
                  <option value="appreciation">{CERTIFICATE_TYPES.appreciation.title}</option>
                  <option value="participation">{CERTIFICATE_TYPES.participation.title}</option>
                </select>
              </label>
              <label className="flex flex-col gap-1 text-sm font-bold">
                الصف
                <select value={issueGrade} onChange={e => { setIssueGrade(e.target.value); setIssueSubject(''); setIssueTerm(''); }} className="rounded-lg border px-3 py-2.5">
                  <option value="">اختر الصف</option>
                  {getGradeOptions().map(g => <option key={g} value={g}>{g}</option>)}
                </select>
              </label>
              <label className="flex flex-col gap-1 text-sm font-bold">
                المادة
                <select value={issueSubject} onChange={e => { setIssueSubject(e.target.value); setIssueTerm(''); }} className="rounded-lg border px-3 py-2.5" disabled={!issueGrade}>
                  <option value="">اختر المادة</option>
                  {getSubjectsForGrade(issueGrade).map(s => <option key={s} value={s}>{s}</option>)}
                </select>
              </label>
              <label className="flex flex-col gap-1 text-sm font-bold">
                الفصل الدراسي
                <select value={issueTerm} onChange={e => setIssueTerm(e.target.value)} className="rounded-lg border px-3 py-2.5" disabled={!issueSubject}>
                  <option value="">اختر الفصل</option>
                  {getTermsForSubject(issueGrade, issueSubject).map(t => <option key={t} value={t}>{t}</option>)}
                </select>
              </label>
              <div className="flex flex-wrap gap-2 pt-2">
                <button type="button" onClick={confirmIssue} className="portal-btn portal-btn-primary">
                  <Award aria-hidden="true" /> إصدار ومعاينة
                </button>
                <button type="button" onClick={() => setIssueModalOpen(false)} className="portal-btn portal-btn-secondary">إلغاء</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* تعديل شهادة */}
      {editCert && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4" onClick={() => setEditCert(null)} role="dialog" aria-modal="true" aria-label="تعديل الشهادة">
          <div className="portal-panel w-full max-w-md" onClick={e => e.stopPropagation()}>
            <div className="portal-panel-head">
              <div>
                <h2><Pencil aria-hidden="true" /> تعديل الشهادة</h2>
                <p>{editCert.studentName} — {editCert.grade} · {editCert.subject}</p>
              </div>
            </div>
            <div className="portal-panel-body flex flex-col gap-4">
              <label className="flex flex-col gap-1 text-sm font-bold">
                نوع الشهادة
                <select value={editType} onChange={e => setEditType(e.target.value as CertificateRecord['type'])} className="rounded-lg border px-3 py-2.5">
                  <option value="excellence">{CERTIFICATE_TYPES.excellence.title}</option>
                  <option value="appreciation">{CERTIFICATE_TYPES.appreciation.title}</option>
                  <option value="participation">{CERTIFICATE_TYPES.participation.title}</option>
                </select>
              </label>
              <label className="flex flex-col gap-1 text-sm font-bold">
                ملاحظة تظهر على الشهادة (اختياري)
                <textarea value={editNote} onChange={e => setEditNote(e.target.value)} className="rounded-lg border px-3 py-2.5" rows={3} />
              </label>
              <div className="flex flex-wrap gap-2 pt-2">
                <button type="button" onClick={saveEdit} className="portal-btn portal-btn-primary">حفظ التعديل</button>
                <button type="button" onClick={() => setEditCert(null)} className="portal-btn portal-btn-secondary">إلغاء</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {previewCert && (
        <DocumentPreview
          title={`${CERTIFICATE_TYPES[previewCert.type]?.title ?? 'شهادة'} — ${previewCert.studentName}`}
          document={certificateDocument(previewCert)}
          pageWidth={1123}
          onClose={() => setPreviewCert(null)}
        />
      )}
    </div>
  );
};

export default TeacherCertificates;
