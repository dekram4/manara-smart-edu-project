import React, { useState } from 'react';
import { UsersRound } from 'lucide-react';
import { PortalField, PortalLoginLayout } from '../../components/portal/PortalLogin';

interface ParentLoginProps {
  onLogin: (username: string, password: string) => Promise<string | null>;
  onBack?: () => void;
}

const ParentLogin: React.FC<ParentLoginProps> = ({ onLogin, onBack }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (submitting) return;
    setError('');
    setSubmitting(true);
    try {
      const message = await onLogin(username.trim(), password);
      if (message) setError(message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <PortalLoginLayout
      portalName="بوابة ولي الأمر"
      title="تسجيل الدخول"
      subtitle="ادخل بالحساب الذي أنشأه لك معلم ابنك."
      icon={UsersRound}
      features={['درجات الأبناء ونتائج اختباراتهم', 'المستوى والنشاط والجواهر والنقاط', 'التقارير والشهادات جاهزة للطباعة']}
      onBack={onBack}
      error={error}
    >
      <form onSubmit={handleSubmit} className="portal-login-form">
        <PortalField label="اسم المستخدم">
          <input
            value={username}
            onChange={e => setUsername(e.target.value)}
            type="text"
            name="username"
            autoComplete="username"
            autoCapitalize="none"
            spellCheck={false}
            className="portal-input"
            required
          />
        </PortalField>
        <PortalField label="كلمة المرور">
          <input
            value={password}
            onChange={e => setPassword(e.target.value)}
            type="password"
            name="password"
            autoComplete="current-password"
            className="portal-input"
            required
          />
        </PortalField>
        <button type="submit" disabled={submitting} className="portal-btn portal-btn-primary">
          {submitting ? 'جارٍ التحقق…' : 'دخول'}
        </button>
      </form>
      <p className="portal-login-help">نسيت كلمة المرور؟ تواصل مع معلم ابنك.</p>
    </PortalLoginLayout>
  );
};

export default ParentLogin;
