import React from 'react';
import type { LucideIcon } from 'lucide-react';
import { ArrowRight, Check } from 'lucide-react';

interface PortalLoginLayoutProps {
  /** «بوابة المعلم»… — في اللوحة الجانبية وفوق العنوان. */
  portalName: string;
  /** عنوانُ النموذج: «تسجيل الدخول»، «تغيير كلمة المرور». */
  title: string;
  subtitle?: string;
  icon: LucideIcon;
  /** ما في هذه البوابة، في اللوحة الجانبية. */
  features: string[];
  onBack?: () => void;
  error?: string;
  children: React.ReactNode;
}

/**
 * صفحةُ الدخول للبوابات الثلاث: لوحةُ الهوية بجانب النموذج.
 *
 * كانت كلُّ صفحةٍ بطاقةً تقفز عند الظهور، تطفو حولها قلوبٌ ونجومٌ ومدارس،
 * وأزرارُها «🚀 تسجيل الدخول». الآن تصميمٌ واحد هادئ للثلاث، ولا يختلف إلا
 * الاسمُ والأيقونة وما في البوابة.
 */
export const PortalLoginLayout: React.FC<PortalLoginLayoutProps> = ({
  portalName,
  title,
  subtitle,
  icon: Icon,
  features,
  onBack,
  error,
  children,
}) => (
  <div className="portal-auth portal-login manara-enterprise" dir="rtl">
    <aside className="portal-login-aside" aria-hidden="true">
      <div className="portal-login-brand">
        <img src="/manara-logo-emblem.png" alt="" />
        <div>
          <strong>منصة منارة المعرفة التعليمية</strong>
          <span>تعليمٌ ذكي، معرفة، ومستقبلٌ مشرق</span>
        </div>
      </div>
      <div className="portal-login-pitch">
        <span className="portal-login-pitch-icon">
          <Icon />
        </span>
        <h2>{portalName}</h2>
        <ul>
          {features.map((feature) => (
            <li key={feature}>
              <Check /> {feature}
            </li>
          ))}
        </ul>
      </div>
      <p className="portal-login-legal">© {new Date().getFullYear()} منصة منارة المعرفة التعليمية</p>
    </aside>

    <main className="portal-login-main">
      <div className="portal-login-card">
        {onBack && (
          <button type="button" onClick={onBack} className="portal-login-back">
            <ArrowRight aria-hidden="true" /> اختيار بوابة أخرى
          </button>
        )}
        <div className="portal-login-mobile-brand">
          <img src="/manara-logo-emblem.png" alt="شعار منصة منارة المعرفة التعليمية" />
          <span>منصة منارة المعرفة التعليمية</span>
        </div>
        <p className="portal-login-eyebrow">{portalName}</p>
        <h1>{title}</h1>
        {subtitle && <p className="portal-login-subtitle">{subtitle}</p>}
        {error && (
          <div className="portal-login-error" role="alert">
            {error}
          </div>
        )}
        {children}
      </div>
    </main>
  </div>
);

export const PortalField: React.FC<{
  label: string;
  hint?: string;
  children: React.ReactNode;
}> = ({ label, hint, children }) => (
  <label className="portal-field">
    <span className="portal-field-label">{label}</span>
    {children}
    {hint && <span className="portal-field-hint">{hint}</span>}
  </label>
);
