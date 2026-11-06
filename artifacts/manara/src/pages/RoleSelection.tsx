import React, { useEffect, useState } from 'react';
import type { LucideIcon } from 'lucide-react';
import { ArrowLeft, Check, Cog, Download, Presentation, Settings, Smartphone, UsersRound } from 'lucide-react';
import { GameAudioEngine } from '../utils/gameAudioEngine';
import { fetchStudentApk } from '../utils/studentApk';
import { ART } from '../components/portal/PortalUI';

interface RoleSelectionProps {
  onSelectAdmin: () => void;
  onSelectTeacher: () => void;
  onSelectParent: () => void;
}

interface RoleCard {
  id: 'teacher' | 'parent' | 'admin';
  title: string;
  description: string;
  features: string[];
  icon: LucideIcon;
  tone: 'primary' | 'accent' | 'gold';
  /** شخصيةُ الدور من رسوم التطبيق؛ والمشرفُ بلا شخصية: ترسُ الإدارة. */
  art?: string;
}

const roles: RoleCard[] = [
  {
    id: 'teacher',
    title: 'بوابة المعلم',
    description: 'إدارة الفصول والمحتوى التعليمي ومتابعة أداء الطلاب.',
    features: ['الدروس والاختبارات', 'تقارير الطلاب وأولياء الأمور', 'إصدار الشهادات'],
    icon: Presentation,
    tone: 'primary',
    art: ART.teacher,
  },
  {
    id: 'parent',
    title: 'بوابة ولي الأمر',
    description: 'متابعة تحصيل الأبناء ونشاطهم وشهاداتهم أولاً بأول.',
    features: ['الدرجات ونتائج الاختبارات', 'المستوى والنشاط والجواهر', 'التقارير والشهادات للطباعة'],
    icon: UsersRound,
    tone: 'accent',
    art: ART.family,
  },
  {
    id: 'admin',
    title: 'لوحة المشرف',
    description: 'الإدارة الشاملة للمنصّة والحسابات والإعدادات الأكاديمية.',
    features: ['المعلمون والحسابات', 'الإعدادات الأكاديمية والمحتوى', 'الصلاحيات وإعدادات النظام'],
    icon: Settings,
    tone: 'gold',
  },
];

/**
 * صفحةُ الدخول الأولى: اختيارُ البوابة.
 *
 * خلفيتُها خلفيةُ شاشة الدخول في تطبيق الطالب نفسُها (سماءٌ ومرجٌ وكتب)،
 * والبرجُ — منارةُ المنصّة — قائمٌ في الجهة اليمنى كما في رئيسية التطبيق.
 * ولكلّ بوابةٍ شخصيتها: المعلمُ أمام سبورته، والعائلة، وترسُ الإدارة للمشرف.
 */
const RoleSelection: React.FC<RoleSelectionProps> = (props) => {
  // رابطُ تطبيق الطالب من إعدادات النظام في الخادم — يغيّره المشرف من لوحته.
  // وما لم يصل الرابط لا يظهر الزرّ: زرٌّ لا يفتح شيئاً أسوأ من غيابه.
  const [apkUrl, setApkUrl] = useState<string | null>(null);
  useEffect(() => {
    let alive = true;
    fetchStudentApk()
      .then((setting) => { if (alive && setting?.url) setApkUrl(setting.url); })
      .catch(() => { /* يبقى الزرّ مخفياً */ });
    return () => { alive = false; };
  }, []);

  const handlers: Record<RoleCard['id'], () => void> = {
    teacher: props.onSelectTeacher,
    parent: props.onSelectParent,
    admin: props.onSelectAdmin,
  };

  return (
    <div className="portal-auth portal-roles is-sky" dir="rtl">
      <div className="portal-roles-sky" aria-hidden="true" />
      <aside className="portal-roles-tower" aria-hidden="true">
        <img src={ART.lighthouse} alt="" />
      </aside>
      <div className="portal-roles-inner">
        <header className="portal-roles-header">
          <div className="portal-roles-brand">
            <img src="/manara-logo-emblem.png" alt="شعار منصة منارة المعرفة التعليمية" />
            <div>
              <strong>منصة منارة المعرفة التعليمية</strong>
              <span>تعليمٌ ذكي، معرفة، ومستقبلٌ مشرق</span>
            </div>
          </div>
          {apkUrl && (
            <a
              href={apkUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="portal-roles-apk-link"
              data-testid="student-apk-download"
              onClick={() => GameAudioEngine.play('uiSelect')}
            >
              <Smartphone aria-hidden="true" />
              تطبيق الطالب
            </a>
          )}
        </header>

        <section className="portal-roles-hero">
          <p>البوابة الإلكترونية</p>
          <h1>مرحباً بك، اختر بوابة الدخول</h1>
          <span>لكل مستخدمٍ بوابته الخاصة. اختر صفتك للمتابعة إلى صفحة تسجيل الدخول.</span>
        </section>

        <div className="portal-roles-grid">
          {roles.map((role) => {
            const Icon = role.icon;
            return (
              <button
                key={role.id}
                type="button"
                className={`portal-role-card tone-${role.tone}`}
                onClick={() => {
                  GameAudioEngine.play('uiSelect');
                  handlers[role.id]();
                }}
              >
                <span className="portal-role-stage" aria-hidden="true">
                  {role.art ? (
                    <img className="portal-role-art" src={role.art} alt="" />
                  ) : (
                    <span className="portal-role-gear">
                      <Settings className="is-big" />
                      <Cog className="is-small" />
                    </span>
                  )}
                </span>
                <span className="portal-role-icon" aria-hidden="true">
                  <Icon />
                </span>
                <span className="portal-role-title">{role.title}</span>
                <span className="portal-role-description">{role.description}</span>
                <span className="portal-role-features">
                  {role.features.map((feature) => (
                    <span key={feature}>
                      <Check aria-hidden="true" /> {feature}
                    </span>
                  ))}
                </span>
                <span className="portal-role-cta">
                  الدخول إلى البوابة <ArrowLeft aria-hidden="true" />
                </span>
              </button>
            );
          })}
        </div>

        {apkUrl && (
          <a href={apkUrl} target="_blank" rel="noopener noreferrer" className="portal-roles-apk" onClick={() => GameAudioEngine.play('uiSelect')}>
            <span className="portal-role-icon tone-success" aria-hidden="true">
              <Smartphone />
            </span>
            <span className="min-w-0 flex-1">
              <strong>تطبيق الطالب</strong>
              <span>يتعلّم الطالب من تطبيقه على الهاتف أو الجهاز اللوحي — أندرويد.</span>
            </span>
            <span className="portal-btn portal-btn-secondary">
              <Download aria-hidden="true" /> تحميل التطبيق
            </span>
          </a>
        )}

        <footer className="portal-roles-footer">
          © {new Date().getFullYear()} منصة منارة المعرفة التعليمية · جميع الحقوق محفوظة
        </footer>
      </div>
    </div>
  );
};

export default RoleSelection;
