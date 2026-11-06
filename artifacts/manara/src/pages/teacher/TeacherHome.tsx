import React, { useMemo } from 'react';
import {
  Activity,
  AlertTriangle,
  BookOpenCheck,
  ChartColumn,
  ClipboardList,
  GraduationCap,
  Layers,
  RefreshCw,
  School,
  Settings2,
  Trophy,
  UserPlus,
  UsersRound,
} from 'lucide-react';
import { LessonConfig, ParentInfo, QuizResult, StudentInfo, TeacherInfo, TeacherMenuType } from '../../types';
import { STORAGE_KEYS } from '../../constants';
import { readStorageArray } from '../../utils/storage';
import { getRecordTeacherId, getTeacherParents, getTeacherStudents, normalizeScopeValue } from '../../utils/scope';
import { getQuizResultPercentage } from '../../utils/quizScoring';
import { getStudentProgressSummary } from '../../utils/studentProgress';
import { Badge, EmptyState, PageHeader, Panel, ProgressBar, StatCard, relativeDay, scoreLabel, scoreTone, ART } from '../../components/portal/PortalUI';
import { ActivityArea, ScoreDonut } from '../../components/portal/PortalCharts';

interface TeacherHomeProps {
  teacher: TeacherInfo;
  /** يتغيّر كلما أُعيدت قراءة البيانات، فتُحسب الصفحة من جديد. */
  refreshToken: number;
  hydrating: boolean;
  academic: { grades: number; subjects: number };
  canOpen: (menu: TeacherMenuType) => boolean;
  onNavigate: (menu: TeacherMenuType) => void;
  onRefresh: () => void;
}

const DAY = 86400000;

const studentGrade = (student: StudentInfo) => (student.primaryGrade || student.grade || 'بلا صف').trim();

/**
 * الصفحةُ الرئيسية للمعلم: نظرةٌ واحدة على فصوله وطلابه.
 *
 * كانت أربعة أرقام وستة أزرار ملوّنة ونصائح بداية. والمعلم يفتح لوحته ليعرف
 * أمرين: كيف حالُ فصوله، ومن يحتاج منه شيئاً اليوم. فصارت الصفحة تقول ذلك:
 * كلُّ صفٍّ بطلابه ومعدّله ونشاطه، ومن تراجع أداؤه أو غاب، وآخرُ النتائج.
 */
const TeacherHome: React.FC<TeacherHomeProps> = ({
  teacher,
  refreshToken,
  hydrating,
  academic,
  canOpen,
  onNavigate,
  onRefresh,
}) => {
  const data = useMemo(() => {
    const parents = getTeacherParents(readStorageArray<ParentInfo>(STORAGE_KEYS.PARENTS), teacher.id);
    const students = getTeacherStudents(readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS), teacher.id, parents);
    const studentIds = new Set(students.map((student) => student.id));
    const results = readStorageArray<QuizResult>(STORAGE_KEYS.QUIZ_RESULTS)
      .filter((result) => studentIds.has(result.studentId))
      .map((result) => ({ ...result, percentage: getQuizResultPercentage(result) }));
    const lessons = readStorageArray<LessonConfig>(STORAGE_KEYS.LESSON_CONFIGS).filter(
      (lesson) => getRecordTeacherId(lesson) === normalizeScopeValue(teacher.id),
    );

    const now = Date.now();
    const lastSeen = (student: StudentInfo) => {
      const times = [student.lastLoginAt, student.lastActivity, student.gamification?.updatedAt]
        .map((value) => (value ? new Date(value).getTime() : NaN))
        .filter(Number.isFinite);
      return times.length ? Math.max(...times) : NaN;
    };

    const rows = students.map((student) => {
      const progress = getStudentProgressSummary(student, results);
      const seen = lastSeen(student);
      return {
        student,
        progress,
        average: progress.averageScore,
        quizzes: results.filter((result) => result.studentId === student.id).length,
        seen,
        activeThisWeek: Number.isFinite(seen) && now - seen <= 7 * DAY,
      };
    });

    const byGrade = new Map<string, typeof rows>();
    rows.forEach((row) => {
      const grade = studentGrade(row.student);
      byGrade.set(grade, [...(byGrade.get(grade) || []), row]);
    });
    const classes = Array.from(byGrade.entries())
      .map(([grade, members]) => {
        const scored = members.filter((member) => member.quizzes > 0);
        return {
          grade,
          count: members.length,
          active: members.filter((member) => member.activeThisWeek).length,
          average: scored.length ? Math.round(scored.reduce((sum, member) => sum + member.average, 0) / scored.length) : null,
          gems: members.reduce((sum, member) => sum + member.progress.gems, 0),
        };
      })
      .sort((a, b) => a.grade.localeCompare(b.grade, 'ar'));

    const scoredRows = rows.filter((row) => row.quizzes > 0);
    const average = scoredRows.length
      ? Math.round(scoredRows.reduce((sum, row) => sum + row.average, 0) / scoredRows.length)
      : null;

    const attention = rows
      .map((row) => {
        const reasons: string[] = [];
        if (row.quizzes > 0 && row.average < 60) reasons.push(`المعدل ${row.average}%`);
        if (!Number.isFinite(row.seen)) reasons.push('لم يدخل بعد');
        else if (now - row.seen > 7 * DAY) reasons.push(`غائب ${relativeDay(new Date(row.seen).toISOString())}`);
        return { ...row, reasons };
      })
      .filter((row) => row.reasons.length > 0)
      .sort((a, b) => b.reasons.length - a.reasons.length || a.average - b.average)
      .slice(0, 6);

    const top = [...scoredRows].sort((a, b) => b.average - a.average || b.progress.xp - a.progress.xp).slice(0, 5);
    const recent = [...results]
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, 7);

    return {
      parents: parents.length,
      students: students.length,
      lessons: lessons.length,
      quizzes: results.length,
      activeThisWeek: rows.filter((row) => row.activeThisWeek).length,
      average,
      classes,
      attention,
      top,
      recent,
      averages: scoredRows.map((row) => row.average),
      resultDates: results.map((result) => result.createdAt),
    };
    // ‏refreshToken يُعيد القراءة عمداً: البيانات في التخزين لا في الحالة.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [teacher.id, refreshToken]);

  const today = new Date().toLocaleDateString('ar-SA', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
  const go = (menu: TeacherMenuType) => (canOpen(menu) ? () => onNavigate(menu) : undefined);

  const actions: { menu: TeacherMenuType; label: string; hint: string; icon: typeof UserPlus }[] = [
    { menu: TeacherMenuType.ACCOUNT_MANAGEMENT, label: 'الطلاب وأولياء الأمور', hint: 'إضافة الحسابات وربطها', icon: UserPlus },
    { menu: TeacherMenuType.CONTENT_MANAGEMENT, label: 'المحتوى التعليمي', hint: 'الدروس والوسائط', icon: BookOpenCheck },
    { menu: TeacherMenuType.QUIZ_MANAGEMENT, label: 'الاختبارات', hint: 'إنشاء الاختبارات ومراجعتها', icon: ClipboardList },
    { menu: TeacherMenuType.ACADEMIC_SETTINGS, label: 'الإعدادات الأكاديمية', hint: 'الصفوف والمواد والفصول', icon: Settings2 },
    { menu: TeacherMenuType.REPORTS, label: 'التقارير', hint: 'أداء الطلاب وتقارير أولياء الأمور', icon: ChartColumn },
    { menu: TeacherMenuType.CERTIFICATES, label: 'الشهادات', hint: 'إصدار الشهادات وطباعتها', icon: Trophy },
  ];

  return (
    <div className="portal-page">
      <PageHeader
        eyebrow={today}
        title={`مرحباً، ${teacher.name}`}
        description="ملخّص فصولك وطلابك اليوم، ومن يحتاج متابعتك."
        icon={School}
        art={ART.board}
        actions={
          <>
            {canOpen(TeacherMenuType.ACCOUNT_MANAGEMENT) && (
              <button type="button" className="portal-btn portal-btn-primary" onClick={() => onNavigate(TeacherMenuType.ACCOUNT_MANAGEMENT)}>
                <UserPlus aria-hidden="true" /> إضافة طالب
              </button>
            )}
            <button type="button" className="portal-btn portal-btn-secondary" onClick={onRefresh}>
              <RefreshCw aria-hidden="true" /> تحديث
            </button>
          </>
        }
      />

      <div className="portal-stats">
        <StatCard label="الطلاب" value={data.students} hint={`${data.activeThisWeek} نشطون هذا الأسبوع`} icon={GraduationCap} onClick={go(TeacherMenuType.ACCOUNT_MANAGEMENT)} />
        <StatCard label="أولياء الأمور" value={data.parents} hint="حسابات مرتبطة بك" icon={UsersRound} tone="accent" onClick={go(TeacherMenuType.ACCOUNT_MANAGEMENT)} />
        <StatCard
          label="متوسط الأداء"
          value={data.average === null ? '—' : `${data.average}%`}
          hint={data.average === null ? 'لا نتائج بعد' : scoreLabel(data.average)}
          icon={Activity}
          tone={data.average === null ? 'neutral' : scoreTone(data.average)}
          onClick={go(TeacherMenuType.REPORTS)}
        />
        <StatCard label="الاختبارات المنجزة" value={data.quizzes} hint="محاولات طلابك" icon={ClipboardList} tone="gold" onClick={go(TeacherMenuType.REPORTS)} />
        <StatCard label="الدروس" value={data.lessons} hint="في المحتوى التعليمي" icon={BookOpenCheck} tone="success" onClick={go(TeacherMenuType.CONTENT_MANAGEMENT)} />
        <StatCard
          label="الصفوف والمواد"
          value={hydrating ? '…' : academic.grades}
          hint={hydrating ? 'جارٍ التحميل من الخادم' : `${academic.subjects} مادة`}
          icon={Layers}
          tone="neutral"
          onClick={go(TeacherMenuType.ACADEMIC_SETTINGS)}
        />
      </div>

      <div className="portal-grid-2">
        <Panel title="توزيع مستوى الطلاب" subtitle="معدّل كل طالبٍ في اختباراته" icon={Activity}>
          <ScoreDonut averages={data.averages} />
        </Panel>
        <Panel title="نشاط الاختبارات" subtitle="عدد الاختبارات المنجزة في آخر ١٤ يوماً" icon={ChartColumn}>
          <ActivityArea dates={data.resultDates} />
        </Panel>
      </div>

      <div className="portal-grid-2">
        <Panel title="فصولي" subtitle="الطلاب والمعدّل والنشاط في كل صف" icon={School} flush>
          {data.classes.length === 0 ? (
            <EmptyState title="لا طلاب بعد" description="أضف طلابك من «الطلاب وأولياء الأمور»." />
          ) : (
            <div className="portal-table-wrap">
              <table className="portal-table">
                <thead>
                  <tr>
                    <th>الصف</th>
                    <th>الطلاب</th>
                    <th>نشطون (٧ أيام)</th>
                    <th style={{ minWidth: '9rem' }}>المعدل</th>
                  </tr>
                </thead>
                <tbody>
                  {data.classes.map((row) => (
                    <tr key={row.grade}>
                      <td className="font-bold text-slate-800">{row.grade}</td>
                      <td className="is-num">{row.count}</td>
                      <td className="is-num">
                        {row.active} <span className="text-slate-400">/ {row.count}</span>
                      </td>
                      <td>
                        {row.average === null ? (
                          <span className="text-slate-400">لا نتائج</span>
                        ) : (
                          <div className="flex items-center gap-2">
                            <div className="flex-1">
                              <ProgressBar value={row.average} tone={scoreTone(row.average)} label={`معدل ${row.grade}`} />
                            </div>
                            <span className="is-num text-xs font-bold text-slate-600">{row.average}%</span>
                          </div>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Panel>

        <Panel title="يحتاجون متابعة" subtitle="معدّلٌ دون ٦٠٪ أو غيابٌ أكثر من أسبوع" icon={AlertTriangle} flush>
          {data.attention.length === 0 ? (
            <EmptyState title="لا أحد يحتاج متابعة الآن" description="كل طلابك نشطون وأداؤهم مقبول." />
          ) : (
            <div className="portal-list">
              {data.attention.map((row) => (
                <div key={row.student.id} className="portal-list-item">
                  <div className="portal-list-main">
                    <strong>{row.student.name}</strong>
                    <span>{studentGrade(row.student)}</span>
                  </div>
                  <div className="flex flex-wrap justify-end gap-1">
                    {row.reasons.map((reason) => (
                      <Badge key={reason} tone={reason.startsWith('المعدل') ? 'danger' : 'warning'}>
                        {reason}
                      </Badge>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}
        </Panel>
      </div>

      <div className="portal-grid-2">
        <Panel
          title="آخر نتائج الاختبارات"
          icon={ClipboardList}
          flush
          actions={
            canOpen(TeacherMenuType.REPORTS) ? (
              <button type="button" className="portal-btn portal-btn-ghost portal-btn-sm" onClick={() => onNavigate(TeacherMenuType.REPORTS)}>
                كل التقارير
              </button>
            ) : undefined
          }
        >
          {data.recent.length === 0 ? (
            <EmptyState title="لا نتائج بعد" description="تظهر هنا نتائج طلابك فور حلّهم الاختبارات." />
          ) : (
            <div className="portal-table-wrap">
              <table className="portal-table">
                <thead>
                  <tr>
                    <th>الطالب</th>
                    <th>المادة</th>
                    <th>الدرجة</th>
                    <th>التاريخ</th>
                  </tr>
                </thead>
                <tbody>
                  {data.recent.map((result) => (
                    <tr key={result.id}>
                      <td className="font-bold text-slate-800">{result.studentName}</td>
                      <td>{result.subject || '—'}</td>
                      <td>
                        <Badge tone={scoreTone(result.percentage)}>{Math.round(result.percentage)}%</Badge>
                      </td>
                      <td className="is-num text-slate-500">{relativeDay(result.createdAt)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Panel>

        <Panel title="المتفوقون" subtitle="الأعلى معدّلاً بين طلابك" icon={Trophy} flush>
          {data.top.length === 0 ? (
            <EmptyState title="لا نتائج بعد" />
          ) : (
            <div className="portal-list">
              {data.top.map((row, index) => (
                <div key={row.student.id} className="portal-list-item">
                  <span className={`portal-badge ${index === 0 ? 'tone-gold' : 'tone-neutral'}`}>{index + 1}</span>
                  <div className="portal-list-main">
                    <strong>{row.student.name}</strong>
                    <span>
                      {studentGrade(row.student)} · المستوى {row.progress.level} · {row.progress.gems} جوهرة
                    </span>
                  </div>
                  <Badge tone={scoreTone(row.average)}>{row.average}%</Badge>
                </div>
              ))}
            </div>
          )}
        </Panel>
      </div>

      <Panel title="الوصول السريع" icon={Layers}>
        <div className="portal-grid-3">
          {actions.filter((action) => canOpen(action.menu)).map((action) => {
            const Icon = action.icon;
            return (
              <button
                key={action.menu}
                type="button"
                onClick={() => onNavigate(action.menu)}
                className="portal-stat tone-primary"
                style={{ flexDirection: 'row', alignItems: 'center' }}
              >
                <span className="portal-stat-icon" aria-hidden="true">
                  <Icon />
                </span>
                <span className="min-w-0">
                  <span className="block font-extrabold text-slate-800">{action.label}</span>
                  <span className="block text-xs text-slate-500">{action.hint}</span>
                </span>
              </button>
            );
          })}
        </div>
      </Panel>
    </div>
  );
};

export default TeacherHome;
