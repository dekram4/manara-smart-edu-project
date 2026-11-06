import React, { useState } from 'react';
import { Settings } from 'lucide-react';
import { PortalField, PortalLoginLayout, PortalSubmitButton } from '../../components/portal/PortalLogin';
import { useSubmitLock } from '../../hooks/useSubmitLock';

interface AdminLoginProps {
  /** يُنتظر: الزرُّ يبقى مقفلاً حتى تُحمَّل بياناتُ الحساب وتُفتح اللوحة. */
  onLoginSuccess: () => void | Promise<void>;
  onBack?: () => void;
}

const AdminLogin: React.FC<AdminLoginProps> = ({ onLoginSuccess, onBack }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const { busy, run } = useSubmitLock();

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    void run(async () => {
      setError('');
      try {
        const response = await fetch('/api/auth/admin', {
          method: 'POST',
          credentials: 'same-origin',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username: username.trim(), password }),
        });
        if (response.ok) {
          // ‏تُفتح لوحةُ المشرف بدورٍ يؤكّده ردُّ الخادم لا بنجاح الطلب وحده.
          const result = await response.json().catch(() => ({}));
          if (!result.role || result.role === 'admin') {
            await onLoginSuccess();
            return;
          }
        }
        if (response.status === 503) {
          setError('لم يتم إعداد بيانات دخول المشرف في متغيّرات الخادم بعد.');
          return;
        }
      } catch {
        // Keep the same generic message for network and credential failures.
      }
      setError('خطأ في اسم المستخدم أو كلمة المرور.');
    });
  };

  return (
    <PortalLoginLayout
      portalName="لوحة المشرف"
      title="تسجيل الدخول"
      subtitle="للمشرفين المخوّلين بإدارة المنصّة."
      icon={Settings}
      features={['المعلمون والحسابات والصلاحيات', 'الإعدادات الأكاديمية والمحتوى', 'التقارير وإعدادات النظام']}
      onBack={onBack}
      error={error}
    >
      <form onSubmit={handleLogin} className="portal-login-form">
        <PortalField label="اسم المستخدم">
          <input
            type="text"
            name="username"
            autoComplete="username"
            autoCapitalize="none"
            spellCheck={false}
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="portal-input"
            dir="ltr"
            required
          />
        </PortalField>
        <PortalField label="كلمة المرور">
          <input
            type="password"
            name="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="portal-input"
            dir="ltr"
            required
          />
        </PortalField>
        <PortalSubmitButton busy={busy} label="دخول النظام" />
      </form>
    </PortalLoginLayout>
  );
};

export default AdminLogin;
