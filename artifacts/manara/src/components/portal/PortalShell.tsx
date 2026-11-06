import React, { useState } from 'react';
import type { LucideIcon } from 'lucide-react';
import { LogOut, Menu, X } from 'lucide-react';
import { sceneFor } from './PortalUI';

export interface PortalNavItem {
  id: string;
  label: string;
  icon: LucideIcon;
  active?: boolean;
  onSelect: () => void;
  /** يظهر في طرف العنصر (عدّاد تنبيهات مثلاً). */
  badge?: React.ReactNode;
}

interface PortalShellProps {
  /** «لوحة المشرف»، «بوابة المعلم»، «بوابة ولي الأمر». */
  portalName: string;
  userName: string;
  /** وصفُ المستخدم تحت اسمه: «مشرف النظام»، «معلم»… */
  userRole: string;
  nav: PortalNavItem[];
  /** عناصرُ بعد فاصل: الدردشة والدعم. */
  secondaryNav?: PortalNavItem[];
  onLogout: () => void;
  /** عنوانُ الصفحة الجارية في الشريط العلوي. */
  pageTitle: string;
  /** ما يوضع في طرف الشريط العلوي قبل اسم المستخدم (جرس التنبيهات…). */
  topbarEnd?: React.ReactNode;
  children: React.ReactNode;
}

/** الحرفُ الأوّل من الاسم بلا «أ.» ولا «د.»: صورةٌ رمزية بلا رموزٍ تعبيرية. */
export const initialOf = (name: string): string => {
  const cleaned = name.replace(/^(أ\.|د\.|م\.)\s*/u, '').trim();
  return cleaned ? Array.from(cleaned)[0] : '•';
};

/**
 * قشرةُ اللوحات الثلاث: قائمةٌ جانبية كحليّة، وشريطٌ علوي باسم الصفحة،
 * ومساحةُ المحتوى.
 *
 * كانت كلُّ لوحةٍ تبني قائمتها بنفسها: ألوانٌ مختلفة، ورموزٌ تعبيرية بدل
 * الأيقونات، وزرُّ «إغلاق» يظهر على الحاسوب. فصارت واحدة: البنية والأيقونات
 * والسلوك نفسه للمشرف والمعلم وولي الأمر، ولا يختلف إلا ما في القائمة.
 *
 * وتُبقي أصنافَ `dashboard-*` القديمة على العناصر البنيوية: سلوكُ الدرج على
 * الشاشات الصغيرة (فتحٌ وإغلاقٌ وطبقةٌ معتمة) مكتوبٌ عليها في index.css.
 */
const PortalShell: React.FC<PortalShellProps> = ({
  portalName,
  userName,
  userRole,
  nav,
  secondaryNav = [],
  onLogout,
  pageTitle,
  topbarEnd,
  children,
}) => {
  const [drawerOpen, setDrawerOpen] = useState(false);
  // ‏خلفيةُ الصفحة الجارية: رسمٌ من أقسام التطبيق في زاوية المحتوى.
  const scene = sceneFor(nav.find((item) => item.active)?.id);

  const renderItem = (item: PortalNavItem) => {
    const Icon = item.icon;
    return (
      <button
        key={item.id}
        type="button"
        onClick={() => {
          item.onSelect();
          setDrawerOpen(false);
        }}
        className={`dashboard-menu-item${item.active ? ' is-active' : ''}`}
        aria-current={item.active ? 'page' : undefined}
      >
        <Icon aria-hidden="true" />
        <span>{item.label}</span>
        {item.badge ? <span className="portal-nav-badge">{item.badge}</span> : null}
      </button>
    );
  };

  return (
    <div dir="rtl" className="dashboard-shell manara-enterprise portal-shell">
      {drawerOpen && (
        <button
          type="button"
          className="dashboard-sidebar-overlay"
          onClick={() => setDrawerOpen(false)}
          aria-label="إغلاق القائمة"
        />
      )}
      <aside
        className={`dashboard-sidebar ${drawerOpen ? 'dashboard-sidebar--open' : 'dashboard-sidebar--closed'} flex flex-col transition-transform duration-300 pb-[env(safe-area-inset-bottom)] pt-[env(safe-area-inset-top)]`}
        aria-label="القائمة الرئيسية"
      >
        <div className="portal-sidebar-brand">
          <img src="/manara-logo-emblem.png" alt="" />
          <div className="min-w-0">
            <strong>منارة المعرفة</strong>
            <span>{portalName}</span>
          </div>
          <button
            type="button"
            className="portal-sidebar-close"
            onClick={() => setDrawerOpen(false)}
            aria-label="إغلاق القائمة"
          >
            <X size={18} aria-hidden="true" />
          </button>
        </div>

        <div className="portal-sidebar-user">
          <span className="portal-avatar" aria-hidden="true">{initialOf(userName)}</span>
          <p className="min-w-0">
            <span className="portal-user-name block">{userName}</span>
            <span className="portal-user-role block">{userRole}</span>
          </p>
        </div>

        <nav className="dashboard-nav">
          <p className="portal-nav-label">القائمة</p>
          {nav.map(renderItem)}
          {secondaryNav.length > 0 && <p className="portal-nav-label">التواصل</p>}
          {secondaryNav.map(renderItem)}
        </nav>

        <div className="dashboard-sidebar-footer">
          <button type="button" onClick={onLogout} className="dashboard-menu-item portal-logout">
            <LogOut aria-hidden="true" />
            <span>تسجيل الخروج</span>
          </button>
        </div>
      </aside>

      <main className="dashboard-main flex flex-col">
        <header className="portal-topbar">
          <button
            type="button"
            className="portal-topbar-menu"
            onClick={() => setDrawerOpen(true)}
            aria-label="فتح القائمة"
          >
            <Menu size={20} aria-hidden="true" />
          </button>
          <div className="portal-topbar-title">
            <small>{portalName}</small>
            <strong>{pageTitle}</strong>
          </div>
          <div className="portal-topbar-end">
            {topbarEnd}
            <div className="portal-topbar-user">
              <span className="portal-avatar" aria-hidden="true">{initialOf(userName)}</span>
              <span>{userName}</span>
            </div>
          </div>
        </header>
        <div className="dashboard-content-area min-w-0 flex-1 safe-area-x safe-area-bottom">
          {scene && <img key={scene} className="portal-scene" src={scene} alt="" aria-hidden="true" />}
          <div className="dashboard-content-fluid">{children}</div>
        </div>
      </main>
    </div>
  );
};

export default PortalShell;
