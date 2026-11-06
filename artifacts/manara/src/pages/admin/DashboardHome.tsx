import React, { useMemo } from 'react';
import {
  Activity,
  BookOpenCheck,
  ClipboardList,
  Clock,
  GraduationCap,
  Layers,
  RefreshCw,
  School,
  UsersRound,
} from 'lucide-react';
import { ParentInfo, QuizResult, StudentInfo, SystemStats, TeacherInfo } from '../../types';
import { STORAGE_KEYS } from '../../constants';
import { readStorageArray } from '../../utils/storage';
import { getTeacherParents, getTeacherStudents } from '../../utils/scope';
import { getQuizResultPercentage } from '../../utils/quizScoring';
import {
  Badge,
  EmptyState,
  PageHeader,
  Panel,
  ProgressBar,
  StatCard,
  relativeDay,
  scoreLabel,
  scoreTone,
} from '../../components/portal/PortalUI';

interface DashboardHomeProps {
  stats: SystemStats;
  onRefresh: () => void;
}

/**
 * الصفحةُ الرئيسية للمشرف: أرقامُ المنصّة، ثم المعلمون بطلابهم ومعدّلاتهم،
 * ثم آخرُ نشاط. والمعلمون يُقرؤون هنا من التخزين نفسه الذي تقرأ منه
 * `refreshStats`، ويُعاد حسابهم كلما تغيّرت [stats] (كل خمس ثوانٍ).
 */
const DashboardHome: React.FC<DashboardHomeProps> = ({ stats, onRefresh }) => {
  const teachers = useMemo(() => {
    const allStudents = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
    const allParents = readStorageArray<ParentInfo>(STORAGE_KEYS.PARENTS);
    const results = readStorageArray<QuizResult>(STORAGE_KEYS.QUIZ_RESULTS);
    return readStorageArray<TeacherInfo>(STORAGE_KEYS.TEACHERS).map((teacher) => {
      const parents = getTeacherParents(allParents, teacher.id);
      const students = getTeacherStudents(allStudents, teacher.id, parents);
      const ids = new Set(students.map((student) => student.id));
      const own = results.filter((result) => ids.has(result.studentId));
      const average = own.length
        ? Math.round(own.reduce((sum, result) => sum + getQuizResultPercentage(result), 0) / own.length)
        : null;
      return { teacher, students: students.length, parents: parents.length, quizzes: own.length, average };
    });
  }, [stats]);

  const average = Math.round(stats.averageQuizScore);
  const hasResults = stats.totalQuizzesTaken > 0;

  return (
    <div className="portal-page">
      <PageHeader
        eyebrow="لوحة المشرف"
        title="نظرة عامة على المنصّة"
        description="أرقام المنصّة التعليمية وأداء المعلمين وطلابهم."
        icon={Layers}
        actions={
          <button type="button" className="portal-btn portal-btn-secondary" onClick={onRefresh}>
            <RefreshCw aria-hidden="true" /> تحديث البيانات
          </button>
        }
      />

      <div className="portal-stats">
        <StatCard label="الطلاب" value={stats.totalStudents} hint={`${stats.activeStudents} نشطون خلال ٧ أيام`} icon={GraduationCap} />
        <StatCard label="المعلمون" value={teachers.length} hint="حسابات المعلمين" icon={School} tone="accent" />
        <StatCard label="أولياء الأمور" value={stats.totalParents} hint="حسابات مرتبطة" icon={UsersRound} tone="neutral" />
        <StatCard label="الدروس" value={stats.lessonsCount} hint={`${stats.gradesCount} صف · ${stats.subjectsCount} مادة`} icon={BookOpenCheck} tone="success" />
        <StatCard label="الاختبارات المنجزة" value={stats.totalQuizzesTaken} hint="كل المحاولات" icon={ClipboardList} tone="gold" />
        <StatCard
          label="متوسط النتائج"
          value={hasResults ? `${average}%` : '—'}
          hint={hasResults ? scoreLabel(average) : 'لا نتائج بعد'}
          icon={Activity}
          tone={hasResults ? scoreTone(average) : 'neutral'}
        />
      </div>

      <Panel title="المعلمون" subtitle="الطلاب وأولياء الأمور والمعدّل لكل معلم" icon={School} flush>
        {teachers.length === 0 ? (
          <EmptyState title="لا معلمين بعد" description="أضف المعلمين من «إدارة المعلمين»." />
        ) : (
          <div className="portal-table-wrap">
            <table className="portal-table">
              <thead>
                <tr>
                  <th>المعلم</th>
                  <th>المادة</th>
                  <th>الطلاب</th>
                  <th>أولياء الأمور</th>
                  <th>الاختبارات</th>
                  <th style={{ minWidth: '10rem' }}>معدّل الطلاب</th>
                  <th>آخر نشاط</th>
                </tr>
              </thead>
              <tbody>
                {teachers.map((row) => (
                  <tr key={row.teacher.id}>
                    <td className="font-bold text-slate-800">{row.teacher.name}</td>
                    <td>{row.teacher.subject || '—'}</td>
                    <td className="is-num">{row.students}</td>
                    <td className="is-num">{row.parents}</td>
                    <td className="is-num">{row.quizzes}</td>
                    <td>
                      {row.average === null ? (
                        <span className="text-slate-400">لا نتائج</span>
                      ) : (
                        <div className="flex items-center gap-2">
                          <div className="flex-1">
                            <ProgressBar value={row.average} tone={scoreTone(row.average)} label={`معدل طلاب ${row.teacher.name}`} />
                          </div>
                          <span className="is-num text-xs font-bold text-slate-600">{row.average}%</span>
                        </div>
                      )}
                    </td>
                    <td className="is-num text-slate-500">{relativeDay(row.teacher.lastActivity)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Panel>

      <Panel title="آخر نشاط للطلاب" subtitle="آخر ستة طلاب استخدموا المنصّة" icon={Clock} flush>
        {stats.recentActivities.length === 0 ? (
          <EmptyState title="لا أنشطة مسجّلة بعد" />
        ) : (
          <div className="portal-table-wrap">
            <table className="portal-table">
              <thead>
                <tr>
                  <th>الطالب</th>
                  <th>الصف</th>
                  <th>النشاط</th>
                  <th>التاريخ</th>
                </tr>
              </thead>
              <tbody>
                {stats.recentActivities.map((activity, index) => (
                  <tr key={`${activity.studentName}-${activity.time}-${index}`}>
                    <td className="font-bold text-slate-800">{activity.studentName}</td>
                    <td>{activity.grade}</td>
                    <td>
                      <Badge tone="accent">{activity.activity}</Badge>
                    </td>
                    <td className="is-num text-slate-500">
                      <time dateTime={activity.time}>{relativeDay(activity.time)}</time>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Panel>
    </div>
  );
};

export default DashboardHome;
