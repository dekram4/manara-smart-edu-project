
import React, { useState } from 'react';
import { ParentInfo } from '../../types';
import { KeyRound } from 'lucide-react';
import { PortalField, PortalLoginLayout } from '../../components/portal/PortalLogin';
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

  const [saving, setSaving] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
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

    setSaving(true);
    const saveError = await onPasswordChange(currentPassword, newPassword);
    setSaving(false);
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
        <button disabled={saving} type="submit" className="portal-btn portal-btn-primary">
          {saving ? 'جارٍ الحفظ…' : 'تحديث كلمة المرور والدخول'}
        </button>
      </form>
    </PortalLoginLayout>
  );
};

export default ParentAccountSetup;
