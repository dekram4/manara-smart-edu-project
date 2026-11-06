import React, { useEffect, useState } from 'react';
import type { LucideIcon } from 'lucide-react';
import { ArrowLeft, Check, Cog, Download, Info, Presentation, Settings, Smartphone, UsersRound } from 'lucide-react';
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
  /** سطرٌ واحد قصير على البطاقة. */
  tagline: string;
  /** الوصفُ الكامل والصلاحيات: في البطاقة المنبثقة عند المرور وحده. */
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
    tagline: 'الفصول والمحتوى والطلاب',
    description: 'إدارة الفصول والمحتوى التعليمي ومتابعة أداء الطلاب.',
    features: ['إنشاء الدروس والاختبارات', 'حسابات الطلاب وأولياء الأمور', 'التقارير ونتائج الاختبارات', 'إصدار الشهادات وطباعتها'],
    icon: Presentation,
    tone: 'primary',
    art: ART.teacher,
  },
  {
    id: 'parent',
    title: 'بوابة ولي الأمر',
    tagline: 'متابعة الأبناء أولاً بأول',
    description: 'متابعة تحصيل الأبناء ونشاطهم وشهاداتهم أولاً بأول.',
    features: ['الدرجات ونتائج الاختبارات', 'المستوى والنشاط والجواهر', 'تفاصيل كل مادة وتقاريرها', 'الشهادات جاهزة للطباعة'],
    icon: UsersRound,
    tone: 'accent',
    art: ART.family,
  },
  {
    id: 'admin',
    title: 'لوحة المشرف',
    tagline: 'إدارة المنصّة بالكامل',
    description: 'الإدارة الشاملة للمنصّة والحسابات والإعدادات الأكاديمية.',
    features: ['المعلمون وكل الحسابات', 'الإعدادات الأكاديمية والمحتوى', 'الصلاحيات وباقاتها', 'إعدادات النظام والشهادات'],
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
 *
 * البطاقةُ خفيفة: الشخصية والاسم وسطرٌ واحد. والوصفُ والصلاحيات في بطاقةٍ
 * زجاجية تنبثق من أسفلها عند المرور (أو التركيز بلوحة المفاتيح).
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
                aria-describedby={`role-info-${role.id}`}
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
                  <span className="portal-role-icon">
                    <Icon />
                  </span>
                </span>
                <span className="portal-role-title">{role.title}</span>
                <span className="portal-role-tagline">{role.tagline}</span>
                <span className="portal-role-cta">
                  الدخول <ArrowLeft aria-hidden="true" />
                </span>
                <span className="portal-role-hint" aria-hidden="true">
                  <Info /> مرّر للتفاصيل
                </span>

                {/* ‏البطاقةُ المنبثقة: تعلو من أسفل البطاقة عند المرور أو التركيز،
                    فيها الوصفُ والصلاحيات — والبطاقةُ نفسها تبقى خفيفة. */}
                <span className="portal-role-popover" id={`role-info-${role.id}`} role="tooltip">
                  <span className="portal-role-popover-title">
                    <Icon aria-hidden="true" /> {role.title}
                  </span>
                  <span className="portal-role-popover-text">{role.description}</span>
                  <span className="portal-role-popover-list">
                    {role.features.map((feature) => (
                      <span key={feature}>
                        <Check aria-hidden="true" /> {feature}
                      </span>
                    ))}
                  </span>
                  <span className="portal-role-popover-cta">
                    الدخول إلى البوابة <ArrowLeft aria-hidden="true" />
                  </span>
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
