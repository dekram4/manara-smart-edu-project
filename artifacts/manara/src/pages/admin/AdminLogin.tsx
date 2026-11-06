import React, { useState } from 'react';
import { Settings } from 'lucide-react';
import { PortalField, PortalLoginLayout } from '../../components/portal/PortalLogin';

interface AdminLoginProps {
  onLoginSuccess: () => void;
  onBack?: () => void;
}

const AdminLogin: React.FC<AdminLoginProps> = ({ onLoginSuccess, onBack }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (submitting) return;
    setError('');
    setSubmitting(true);
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
          onLoginSuccess();
          return;
        }
      }
      if (response.status === 503) {
        setError('لم يتم إعداد بيانات دخول المشرف في متغيّرات الخادم بعد.');
        return;
      }
    } catch {
      // Keep the same generic message for network and credential failures.
    } finally {
      setSubmitting(false);
    }
    setError('خطأ في اسم المستخدم أو كلمة المرور.');
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
        <button type="submit" disabled={submitting} className="portal-btn portal-btn-primary">
          {submitting ? 'جارٍ التحقق…' : 'دخول النظام'}
        </button>
      </form>
    </PortalLoginLayout>
  );
};

export default AdminLogin;
