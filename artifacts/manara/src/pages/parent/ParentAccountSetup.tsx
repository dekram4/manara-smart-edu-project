
import React, { useState } from 'react';
import { ParentInfo } from '../../types';
import { KeyRound } from 'lucide-react';
import { PortalField, PortalLoginLayout, PortalSubmitButton } from '../../components/portal/PortalLogin';
import { useSubmitLock } from '../../hooks/useSubmitLock';
import { passwordsMatch } from '../../utils/password';

interface ParentAccountSetupProps {
  parent: ParentInfo;
  onPasswordChange: (currentPassword: string, newPassword: string) => Promise<string | null>;
}

const ParentAccountSetup: React.FC<ParentAccountSetupProps> = ({ parent, onPasswordChange }) => {
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');

  const { busy, run } = useSubmitLock();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    void run(() => save());
  };

  const save = async () => {
    setError('');

    if (!passwordsMatch(currentPassword, parent.password)) {
      setError('كلمة المرور الحالية غير صحيحة');
      return;
    }
    if (newPassword.length < 6) {
      setError('كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (newPassword === currentPassword) {
      setError('كلمة المرور الجديدة يجب أن تكون مختلفة عن الحالية');
      return;
    }
    if (newPassword !== confirmPassword) {
      setError('تأكيد كلمة المرور غير متطابق');
      return;
    }

    const saveError = await onPasswordChange(currentPassword, newPassword);
    if (saveError) {
      setError(saveError);
      return;
    }
    alert('تم تحديث كلمة المرور بنجاح!');
  };

  return (
    <PortalLoginLayout
      portalName="بوابة ولي الأمر"
      title={`أهلاً بك، ${parent.name}`}
      subtitle="هذا أوّل دخولٍ لك. غيّر كلمة المرور المؤقتة لحماية حسابك."
      icon={KeyRound}
      features={['درجات الأبناء ونتائج اختباراتهم', 'المستوى والنشاط والجواهر والنقاط', 'التقارير والشهادات جاهزة للطباعة']}
      error={error}
    >
      <form onSubmit={handleSubmit} className="portal-login-form">
        <PortalField label="كلمة المرور الحالية">
          <input type="password" value={currentPassword} onChange={e => setCurrentPassword(e.target.value)} className="portal-input" autoComplete="current-password" required autoFocus />
        </PortalField>
        <PortalField label="كلمة المرور الجديدة" hint="ستة أحرف على الأقل">
          <input type="password" value={newPassword} onChange={e => setNewPassword(e.target.value)} className="portal-input" autoComplete="new-password" required />
        </PortalField>
        <PortalField label="تأكيد كلمة المرور">
          <input type="password" value={confirmPassword} onChange={e => setConfirmPassword(e.target.value)} className="portal-input" autoComplete="new-password" required />
        </PortalField>
        <PortalSubmitButton busy={busy} label="تحديث كلمة المرور والدخول" busyLabel="جارٍ الحفظ…" />
      </form>
    </PortalLoginLayout>
  );
};

export default ParentAccountSetup;
