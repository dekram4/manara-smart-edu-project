import React from 'react';
import type { LucideIcon } from 'lucide-react';
import { Inbox } from 'lucide-react';

/**
 * رسومُ المنصّة — منسوخةٌ من رسوم تطبيق الطالب إلى `public/illustrations`
 * (مصغّرةً بصيغة WebP)، فتحمل اللوحاتُ الشخصياتِ والأشياءَ نفسها التي يعرفها
 * الطالب في تطبيقه.
 */
export const ART = {
  kids: '/illustrations/kids.webp',
  books: '/illustrations/books.webp',
  booksStack: '/illustrations/books-stack.webp',
  school: '/illustrations/school.webp',
  globe: '/illustrations/globe.webp',
  boy: '/illustrations/boy.webp',
  girl: '/illustrations/girl.webp',
  reader: '/illustrations/reader.webp',
  robot: '/illustrations/robot.webp',
} as const;

/** صورةُ المادة من اسمها: القرآن والنورانية، الرياضيات، العلوم، الإنجليزية، العربية. */
export const subjectArt = (subject: string): string => {
  const name = subject.replace(/[\u064B-\u0652]/g, '').toLowerCase();
  if (/قران|قرآن|نوراني|تجويد|اسلام|إسلام|توحيد|حديث|فقه/.test(name)) return '/illustrations/subject-quran.webp';
  if (/رياض|حساب|math/.test(name)) return '/illustrations/subject-math.webp';
  if (/علوم|science|فيزياء|كيمياء|أحياء|احياء/.test(name)) return '/illustrations/subject-science.webp';
  if (/انجليز|إنجليز|english/.test(name)) return '/illustrations/subject-english.webp';
  if (/عرب|لغتي|لغة|حروف|قراءة|املاء|إملاء|خط/.test(name)) return '/illustrations/subject-arabic.webp';
  return '/illustrations/subject-general.webp';
};

/** صورةُ الطالب في البطاقات: ولدٌ أو بنت بحسب ما اختاره في تطبيقه. */
export const studentArt = (gender?: string): string => (gender === 'female' ? ART.girl : ART.boy);

/** ألوانُ الدلالة المشتركة في portal.css (`.tone-*`). */
export type PortalTone = 'primary' | 'accent' | 'gold' | 'success' | 'warning' | 'danger' | 'neutral';

export const PageHeader: React.FC<{
  title: string;
  description?: string;
  eyebrow?: string;
  icon?: LucideIcon;
  actions?: React.ReactNode;
  /** رسمٌ من `/illustrations` يُعرض في طرف الرأس (يختفي على الشاشات الضيّقة). */
  art?: string;
}> = ({ title, description, eyebrow, icon: Icon, actions, art }) => (
  <header className={`portal-page-header${art ? ' has-art' : ''}`}>
    {Icon && (
      <span className="portal-page-header-icon" aria-hidden="true">
        <Icon />
      </span>
    )}
    <div className="portal-page-header-text">
      {eyebrow && <p className="portal-eyebrow">{eyebrow}</p>}
      <h1>{title}</h1>
      {description && <p className="portal-description">{description}</p>}
    </div>
    {actions && <div className="portal-page-header-actions">{actions}</div>}
    {art && <img className="portal-page-header-art" src={art} alt="" aria-hidden="true" loading="lazy" />}
  </header>
);

export const StatCard: React.FC<{
  label: string;
  value: React.ReactNode;
  hint?: React.ReactNode;
  icon: LucideIcon;
  tone?: PortalTone;
  onClick?: () => void;
}> = ({ label, value, hint, icon: Icon, tone = 'primary', onClick }) => {
  const body = (
    <>
      <div className="portal-stat-top">
        <span className="portal-stat-label">{label}</span>
        <span className="portal-stat-icon" aria-hidden="true">
          <Icon />
        </span>
      </div>
      <span className="portal-stat-value">{value}</span>
      {hint !== undefined && <span className="portal-stat-hint">{hint}</span>}
    </>
  );
  return onClick ? (
    <button type="button" className={`portal-stat tone-${tone}`} onClick={onClick}>
      {body}
    </button>
  ) : (
    <div className={`portal-stat tone-${tone}`}>{body}</div>
  );
};

export const Panel: React.FC<{
  title?: string;
  subtitle?: string;
  icon?: LucideIcon;
  actions?: React.ReactNode;
  flush?: boolean;
  className?: string;
  children: React.ReactNode;
}> = ({ title, subtitle, icon: Icon, actions, flush, className = '', children }) => (
  <section className={`portal-panel ${className}`}>
    {(title || actions) && (
      <div className="portal-panel-head">
        <div className="min-w-0">
          {title && (
            <h2>
              {Icon && <Icon aria-hidden="true" />}
              {title}
            </h2>
          )}
          {subtitle && <p>{subtitle}</p>}
        </div>
        {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
      </div>
    )}
    <div className={`portal-panel-body${flush ? ' is-flush' : ''}`}>{children}</div>
  </section>
);

export const ProgressBar: React.FC<{ value: number; tone?: PortalTone; label?: string }> = ({
  value,
  tone = 'accent',
  label,
}) => {
  const clamped = Math.max(0, Math.min(100, Number.isFinite(value) ? value : 0));
  return (
    <div
      className={`portal-progress tone-${tone}`}
      role="progressbar"
      aria-valuenow={Math.round(clamped)}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-label={label}
    >
      <span style={{ width: `${clamped}%` }} />
    </div>
  );
};

export const Badge: React.FC<{ tone?: PortalTone; children: React.ReactNode }> = ({ tone = 'primary', children }) => (
  <span className={`portal-badge tone-${tone}`}>{children}</span>
);

export const EmptyState: React.FC<{ title: string; description?: string; icon?: LucideIcon; art?: string }> = ({
  title,
  description,
  icon: Icon = Inbox,
  art = ART.books,
}) => (
  <div className="portal-empty">
    {art ? <img className="portal-empty-art" src={art} alt="" aria-hidden="true" loading="lazy" /> : <Icon aria-hidden="true" />}
    <strong>{title}</strong>
    {description && <span className="text-sm">{description}</span>}
  </div>
);

/** نبرةُ الدرجة: ممتاز فما فوق ٩٠، جيد من ٧٥، مقبول من ٦٠، وإلا يحتاج متابعة. */
export const scoreTone = (percentage: number): PortalTone =>
  percentage >= 90 ? 'success' : percentage >= 75 ? 'primary' : percentage >= 60 ? 'warning' : 'danger';

export const scoreLabel = (percentage: number): string =>
  percentage >= 90 ? 'ممتاز' : percentage >= 75 ? 'جيد جداً' : percentage >= 60 ? 'جيد' : 'يحتاج متابعة';

/** «اليوم»، «أمس»، «منذ ٣ أيام»، أو التاريخ — لآخر نشاط. */
export const relativeDay = (value?: string): string => {
  if (!value) return '—';
  const time = new Date(value).getTime();
  if (!Number.isFinite(time)) return '—';
  const days = Math.floor((Date.now() - time) / 86400000);
  if (days <= 0) return 'اليوم';
  if (days === 1) return 'أمس';
  if (days === 2) return 'منذ يومين';
  if (days <= 10) return `منذ ${days} أيام`;
  if (days < 30) return `منذ ${days} يوماً`;
  return new Date(value).toLocaleDateString('ar-SA-u-ca-gregory-nu-latn', { day: 'numeric', month: 'short', year: 'numeric' });
};
