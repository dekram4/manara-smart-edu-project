import React from 'react';
import {
  Award,
  BookOpenCheck,
  CalendarCheck,
  ChartColumn,
  ClipboardList,
  Eye,
  KeyRound,
  Printer,
  TrendingDown,
  TrendingUp,
  Minus,
  UsersRound,
} from 'lucide-react';
import { CartesianGrid, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import type { CertificateRecord, QuizResult, StudentInfo } from '../../types';
import { getQuizResultPercentage, getQuizResultScore } from '../../utils/quizScoring';
import { CERTIFICATE_TYPES, certificateNumber } from '../../utils/officialDocuments';
import {
  ART,
  Badge,
  EmptyState,
  PageHeader,
  Panel,
  ProgressBar,
  StatCard,
  relativeDay,
  scoreLabel,
  scoreTone,
  studentArt,
  subjectArt,
} from '../../components/portal/PortalUI';

const average = (values: number[]) =>
  values.length ? Math.round(values.reduce((sum, value) => sum + value, 0) / values.length) : null;

const byNewest = (a: QuizResult, b: QuizResult) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();

const fullDate = (value: string) =>
  new Date(value).toLocaleDateString('ar-SA-u-ca-gregory-nu-latn', { day: 'numeric', month: 'short', year: 'numeric' });

/** حلقةُ المعدّل في بطاقة المادة: نسبةٌ تُقرأ من بعيد. */
const ScoreRing: React.FC<{ value: number | null }> = ({ value }) => (
  <span
    className={`portal-ring tone-${value === null ? 'neutral' : scoreTone(value)}`}
    style={{ '--ring': `${value ?? 0}%` } as React.CSSProperties}
    aria-label={value === null ? 'لم يبدأ' : `المعدل ${value}%`}
  >
    <span className="is-num">{value === null ? '—' : `${value}%`}</span>
  </span>
);

interface ParentChildrenProps {
  children: StudentInfo[];
  results: QuizResult[];
  certificates: CertificateRecord[];
  selected: StudentInfo | null;
  onSelect: (child: StudentInfo) => void;
  getChildSubjects: (child: StudentInfo) => string[];
  teacherName?: string;
  onOpenChild: (child: StudentInfo) => void;
  onOpenSubject: (child: StudentInfo, subject: string) => void;
  onPrintSubject: (child: StudentInfo, subject: string) => void;
  onResetPassword?: (child: StudentInfo) => void;
}

/**
 * «الأبناء والمواد»: بطاقاتُ الأبناء في الأعلى، ولمن يُختار منهم ملخّصٌ
 * وبطاقةٌ لكلّ مادة. و«التفاصيل» — للابن أو للمادة — تفتح صفحةً مستقلّة
 * (`PortalDialog`) فيها الدرجاتُ والنسبُ والتقارير كاملة.
 */
const ParentChildren: React.FC<ParentChildrenProps> = ({
  children,
  results,
  certificates,
  selected,
  onSelect,
  getChildSubjects,
  teacherName,
  onOpenChild,
  onOpenSubject,
  onPrintSubject,
  onResetPassword,
}) => {
  const child = selected ?? children[0] ?? null;
  const own = child ? results.filter((result) => result.studentId === child.id) : [];
  const ownCerts = child ? certificates.filter((cert) => cert.studentId === child.id) : [];
  const childAverage = average(own.map(getQuizResultPercentage));
  const subjects = child
    ? Array.from(new Set([...getChildSubjects(child), ...own.map((result) => result.subject).filter(Boolean)]))
    : [];
  const subjectRows = subjects.map((subject) => {
    const scores = own.filter((result) => result.subject === subject).sort(byNewest);
    return {
      subject,
      count: scores.length,
      average: average(scores.map(getQuizResultPercentage)),
      last: scores[0]?.createdAt,
      certificates: ownCerts.filter((cert) => cert.subject === subject).length,
    };
  });

  return (
    <div className="portal-page">
      <PageHeader
        eyebrow="بوابة ولي الأمر"
        title="الأبناء والمواد"
        description="اختر ابناً لعرض مواده وتحصيله، وافتح «التفاصيل» لأيّ ابنٍ أو مادة لعرض الدرجات والنسب والتقارير كاملة."
        icon={UsersRound}
        art={ART.family}
      />

      {children.length === 0 ? (
        <Panel>
          <EmptyState title="لا أبناء مرتبطين بحسابك بعد" description="يربط المعلم حساب ابنك بحسابك، أو أضفه من «إضافة ابن»." />
        </Panel>
      ) : (
        <>
          <div className="portal-kid-tabs" role="tablist" aria-label="الأبناء">
            {children.map((item) => {
              const scores = results.filter((result) => result.studentId === item.id).map(getQuizResultPercentage);
              const avg = average(scores);
              const isActive = child?.id === item.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  role="tab"
                  aria-selected={isActive}
                  className={`portal-kid-tab${isActive ? ' is-active' : ''}`}
                  onClick={() => onSelect(item)}
                >
                  <img src={studentArt(item.gender)} alt="" aria-hidden="true" />
                  <span className="min-w-0 flex-1">
                    <strong>{item.name}</strong>
                    <small>{item.primaryGrade || item.grade || 'بلا صف'}</small>
                  </span>
                  {avg !== null && <Badge tone={scoreTone(avg)}>{avg}%</Badge>}
                </button>
              );
            })}
          </div>

          {child && (
            <>
              <section className="portal-panel portal-kid-summary">
                <img className="portal-kid-summary-art" src={studentArt(child.gender)} alt="" aria-hidden="true" />
                <div className="min-w-0 flex-1">
                  <h2>{child.name}</h2>
                  <p>
                    {child.primaryGrade || child.grade || 'بلا صف'}
                    {teacherName ? ` · المعلم: ${teacherName}` : ''}
                  </p>
                  <dl className="portal-kid-summary-stats">
                    <div><dt>المواد</dt><dd>{subjects.length}</dd></div>
                    <div><dt>الاختبارات</dt><dd>{own.length}</dd></div>
                    <div>
                      <dt>المعدل</dt>
                      <dd style={{ color: childAverage === null ? undefined : `var(--pt-${scoreTone(childAverage)})` }}>
                        {childAverage === null ? '—' : `${childAverage}%`}
                      </dd>
                    </div>
                    <div><dt>الشهادات</dt><dd>{ownCerts.length}</dd></div>
                  </dl>
                </div>
                <div className="portal-kid-summary-actions">
                  <button type="button" className="portal-btn portal-btn-primary" onClick={() => onOpenChild(child)}>
                    <ChartColumn aria-hidden="true" /> تفاصيل {child.name.split(' ')[0]}
                  </button>
                  {onResetPassword && (
                    <button type="button" className="portal-btn portal-btn-secondary" onClick={() => onResetPassword(child)}>
                      <KeyRound aria-hidden="true" /> تغيير كلمة المرور
                    </button>
                  )}
                </div>
              </section>

              <div className="portal-section-title">
                <BookOpenCheck aria-hidden="true" />
                <h3>المواد والتحصيل</h3>
                <span>{subjectRows.length} مادة</span>
              </div>

              {subjectRows.length === 0 ? (
                <Panel>
                  <EmptyState title="لا مواد مسجّلة بعد" description="تظهر المواد بعد أن يحدّدها المعلم لصف ابنك أو بعد أول اختبار." />
                </Panel>
              ) : (
                <div className="portal-subject-grid">
                  {subjectRows.map((item) => (
                    <article key={item.subject} className="portal-subject-card">
                      <div className="portal-subject-card-head">
                        <img src={subjectArt(item.subject)} alt="" aria-hidden="true" loading="lazy" />
                        <div className="min-w-0 flex-1">
                          <h4>{item.subject}</h4>
                          {item.average === null ? (
                            <Badge tone="neutral">لم يبدأ</Badge>
                          ) : (
                            <Badge tone={scoreTone(item.average)}>{scoreLabel(item.average)}</Badge>
                          )}
                        </div>
                        <ScoreRing value={item.average} />
                      </div>
                      <ProgressBar
                        value={item.average ?? 0}
                        tone={item.average === null ? undefined : scoreTone(item.average)}
                        label={`معدل ${item.subject}`}
                      />
                      <dl className="portal-subject-card-facts">
                        <div><dt>الاختبارات</dt><dd>{item.count}</dd></div>
                        <div><dt>الشهادات</dt><dd>{item.certificates}</dd></div>
                        <div><dt>آخر اختبار</dt><dd>{relativeDay(item.last)}</dd></div>
                      </dl>
                      <div className="portal-subject-card-actions">
                        <button type="button" className="portal-btn portal-btn-primary flex-1" onClick={() => onOpenSubject(child, item.subject)}>
                          <Eye aria-hidden="true" /> التفاصيل
                        </button>
                        {item.count > 0 && (
                          <button
                            type="button"
                            className="portal-btn portal-btn-secondary"
                            onClick={() => onPrintSubject(child, item.subject)}
                            aria-label={`طباعة تقرير ${item.subject}`}
                            title="طباعة تقرير المادة"
                          >
                            <Printer aria-hidden="true" />
                          </button>
                        )}
                      </div>
                    </article>
                  ))}
                </div>
              )}
            </>
          )}
        </>
      )}
    </div>
  );
};

export default ParentChildren;

/* ───────────────────────── تفاصيل المادة ───────────────────────── */

interface SubjectDetailsProps {
  child: StudentInfo;
  subject: string;
  results: QuizResult[];
  certificates: CertificateRecord[];
  quizTypeLabel: (quizType: string | undefined) => string;
  isTeacherQuiz: (quizType: string | undefined) => boolean;
  pathOf: (result: QuizResult) => string;
  onPreviewCertificate: (cert: CertificateRecord) => void;
}

/** محتوى صفحة المادة: المؤشّرات، وتطوّر الدرجات، وكلُّ الاختبارات، والشهادات. */
export const SubjectDetails: React.FC<SubjectDetailsProps> = ({
  child,
  subject,
  results,
  certificates,
  quizTypeLabel,
  isTeacherQuiz,
  pathOf,
  onPreviewCertificate,
}) => {
  const own = results.filter((result) => result.studentId === child.id && result.subject === subject).sort(byNewest);
  const scores = own.map(getQuizResultPercentage);
  const avg = average(scores);
  const teacherAvg = average(own.filter((result) => isTeacherQuiz(result.quizType)).map(getQuizResultPercentage));
  const otherAvg = average(own.filter((result) => !isTeacherQuiz(result.quizType)).map(getQuizResultPercentage));
  const certs = certificates.filter((cert) => cert.studentId === child.id && cert.subject === subject);
  const trend = [...own].reverse().map((result, index) => ({
    name: `${index + 1}`,
    الدرجة: getQuizResultPercentage(result),
    title: result.quizTitle || quizTypeLabel(result.quizType),
  }));
  const direction =
    trend.length < 2 ? null : trend[trend.length - 1].الدرجة > trend[0].الدرجة ? 'up' : trend[trend.length - 1].الدرجة < trend[0].الدرجة ? 'down' : 'flat';

  return (
    <div className="portal-page">
      <div className="portal-stats">
        <StatCard
          label="معدّل المادة"
          value={avg === null ? '—' : `${avg}%`}
          hint={avg === null ? 'لم يبدأ بعد' : scoreLabel(avg)}
          icon={ChartColumn}
          tone={avg === null ? 'neutral' : scoreTone(avg)}
        />
        <StatCard label="أعلى درجة" value={scores.length ? `${Math.max(...scores)}%` : '—'} icon={TrendingUp} tone="success" />
        <StatCard label="أدنى درجة" value={scores.length ? `${Math.min(...scores)}%` : '—'} icon={TrendingDown} tone="warning" />
        <StatCard label="الاختبارات" value={own.length} hint={own[0] ? `آخرها ${relativeDay(own[0].createdAt)}` : undefined} icon={ClipboardList} tone="accent" />
        <StatCard label="اختبارات المعلم" value={teacherAvg === null ? '—' : `${teacherAvg}%`} hint="المعدّل" icon={BookOpenCheck} tone="primary" />
        <StatCard label="الاختبارات الدورية" value={otherAvg === null ? '—' : `${otherAvg}%`} hint="المعدّل" icon={CalendarCheck} tone="neutral" />
      </div>

      <div className="portal-grid-2">
        <Panel title="تطوّر الدرجات" subtitle="الدرجة في كل اختبار بترتيبه" icon={TrendingUp}>
          {trend.length < 2 ? (
            <EmptyState title="يحتاج اختبارين على الأقل" description="يظهر الرسم بعد اختبارين في المادة." icon={TrendingUp} />
          ) : (
            <ResponsiveContainer width="100%" height={230}>
              <LineChart data={trend} margin={{ top: 8, right: 8, left: 8, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#e3e8ef" vertical={false} />
                <XAxis dataKey="name" tick={{ fontSize: 11, fill: '#94a3b8' }} axisLine={false} tickLine={false} reversed />
                <YAxis domain={[0, 100]} tick={{ fontSize: 11, fill: '#94a3b8' }} width={34} axisLine={false} tickLine={false} orientation="right" />
                <Tooltip formatter={(value: number, _name, item: any) => [`${value}%`, item?.payload?.title || 'الدرجة']} />
                <Line type="monotone" dataKey="الدرجة" stroke="#0f766e" strokeWidth={2.5} dot={{ r: 3.5, fill: '#0f766e' }} />
              </LineChart>
            </ResponsiveContainer>
          )}
        </Panel>
        <Panel title="تحليل المستوى" subtitle="قراءةٌ سريعة لأداء المادة" icon={ChartColumn}>
          <div className="portal-analysis">
            <div className="portal-analysis-row">
              <span>المستوى العام</span>
              {avg === null ? <Badge tone="neutral">لم يبدأ</Badge> : <Badge tone={scoreTone(avg)}>{scoreLabel(avg)}</Badge>}
            </div>
            <div className="portal-analysis-row">
              <span>اتّجاه الدرجات</span>
              {direction === null ? (
                <span className="text-slate-400">يحتاج اختبارين</span>
              ) : direction === 'up' ? (
                <Badge tone="success"><TrendingUp className="inline h-3.5 w-3.5" aria-hidden="true" /> تحسّنٌ مستمر</Badge>
              ) : direction === 'down' ? (
                <Badge tone="danger"><TrendingDown className="inline h-3.5 w-3.5" aria-hidden="true" /> تراجعٌ ملحوظ</Badge>
              ) : (
                <Badge tone="warning"><Minus className="inline h-3.5 w-3.5" aria-hidden="true" /> مستوى مستقر</Badge>
              )}
            </div>
            <div className="portal-analysis-row">
              <span>نسبة الاختبارات الناجحة (٦٠٪ فأكثر)</span>
              <strong className="is-num">
                {scores.length ? `${Math.round((scores.filter((value) => value >= 60).length / scores.length) * 100)}%` : '—'}
              </strong>
            </div>
            <ProgressBar value={avg ?? 0} tone={avg === null ? undefined : scoreTone(avg)} label={`معدل ${subject}`} />
          </div>
        </Panel>
      </div>

      <Panel title="نتائج الاختبارات" subtitle="كل اختبارات المادة، الأحدث أولاً" icon={ClipboardList} flush>
        {own.length === 0 ? (
          <EmptyState title="لا نتائج بعد" description="تظهر النتائج فور حلّ ابنك اختبارات هذه المادة." />
        ) : (
          <div className="portal-table-wrap">
            <table className="portal-table">
              <thead>
                <tr>
                  <th>الاختبار</th>
                  <th>النوع</th>
                  <th>المسار</th>
                  <th>الدرجة</th>
                  <th>النسبة</th>
                  <th>التقدير</th>
                  <th>التاريخ</th>
                </tr>
              </thead>
              <tbody>
                {own.map((result) => {
                  const percentage = getQuizResultPercentage(result);
                  return (
                    <tr key={result.id}>
                      <td className="font-bold text-slate-800">{result.quizTitle || quizTypeLabel(result.quizType)}</td>
                      <td>{quizTypeLabel(result.quizType)}</td>
                      <td className="text-slate-500">{pathOf(result) || '—'}</td>
                      <td className="is-num">{getQuizResultScore(result)} / {result.total || 0}</td>
                      <td><Badge tone={scoreTone(percentage)}>{percentage}%</Badge></td>
                      <td>{scoreLabel(percentage)}</td>
                      <td className="is-num text-slate-500">{fullDate(result.createdAt)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Panel>

      <Panel title="الشهادات في هذه المادة" icon={Award} flush>
        {certs.length === 0 ? (
          <EmptyState title="لا شهادات في هذه المادة بعد" icon={Award} art={ART.reader} />
        ) : (
          <div className="portal-list">
            {certs.map((cert) => (
              <div key={cert.id} className="portal-list-item">
                <span className="portal-stat-icon tone-gold" aria-hidden="true"><Award /></span>
                <div className="portal-list-main">
                  <strong>{(CERTIFICATE_TYPES[cert.type] ?? CERTIFICATE_TYPES.participation).title}</strong>
                  <span>{cert.term} · {certificateNumber(cert)} · {fullDate(cert.date)}</span>
                </div>
                <button type="button" className="portal-btn portal-btn-secondary portal-btn-sm" onClick={() => onPreviewCertificate(cert)}>
                  <Eye aria-hidden="true" /> معاينة
                </button>
              </div>
            ))}
          </div>
        )}
      </Panel>
    </div>
  );
};
