import React, { useState } from 'react';
import { UsersRound } from 'lucide-react';
import { PortalField, PortalLoginLayout, PortalSubmitButton } from '../../components/portal/PortalLogin';
import { useSubmitLock } from '../../hooks/useSubmitLock';

interface ParentLoginProps {
  onLogin: (username: string, password: string) => Promise<string | null>;
  onBack?: () => void;
}

const ParentLogin: React.FC<ParentLoginProps> = ({ onLogin, onBack }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const { busy, run } = useSubmitLock();

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    void run(async () => {
      setError('');
      const message = await onLogin(username.trim(), password);
      if (message) setError(message);
    });
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
        <PortalSubmitButton busy={busy} label="دخول" />
      </form>
      <p className="portal-login-help">نسيت كلمة المرور؟ تواصل مع معلم ابنك.</p>
    </PortalLoginLayout>
  );
};

export default ParentLogin;
