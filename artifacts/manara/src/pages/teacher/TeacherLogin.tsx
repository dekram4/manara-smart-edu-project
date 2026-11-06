import { openTeacherSession } from '../../utils/serverSession';
import React, { useState } from 'react';
import { TeacherInfo } from '../../types';
import { STORAGE_KEYS } from '../../constants';
import { hashPassword } from '../../utils/password';
import { KeyRound, Presentation } from 'lucide-react';
import { PortalField, PortalLoginLayout } from '../../components/portal/PortalLogin';
import { readStorageArray, writeActiveSession } from '../../utils/storage';

interface TeacherLoginProps {
  onLoginSuccess: (teacher: TeacherInfo) => void;
  onBack?: () => void;
}

const TeacherLogin: React.FC<TeacherLoginProps> = ({ onLoginSuccess, onBack }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showChangePassword, setShowChangePassword] = useState(false);
  const [currentTeacher, setCurrentTeacher] = useState<TeacherInfo | null>(null);
  const [error, setError] = useState('');

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    const normalizedUsername = username.trim();
    const teachers = readStorageArray<TeacherInfo>(STORAGE_KEYS.TEACHERS);
    // ‏الدخولُ من الخادم وحده: كان يُجرَّب أوّلاً على نسخة المتصفّح، فيدخل المعلمُ
    // ‏بلا جلسةٍ في الخادم — أو بجلسة دورٍ آخر بقيت في المتصفّح — ويُكتب بها.
    let teacher: TeacherInfo | undefined;

    if (!teacher) {
      try {
        const response = await fetch('/api/auth/teacher/login', {
          method: 'POST',
          credentials: 'same-origin',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username: normalizedUsername, password }),
        });
        const result = await response.json().catch(() => ({}));
        // ‏والدورُ من ردّ الخادم نفسه: لا تُفتح لوحةُ المعلم إلا بجلسة معلّم.
        if (!response.ok || !result.teacher || (result.role && result.role !== 'teacher')) {
          setError(result.error || 'اسم المستخدم أو كلمة المرور غير صحيحة');
          return;
        }
        teacher = {
          ...result.teacher,
          username: normalizedUsername,
          password: hashPassword(password),
        } as TeacherInfo;
        localStorage.setItem(
          STORAGE_KEYS.TEACHERS,
          JSON.stringify([
            ...teachers.filter(item => item.id !== teacher!.id),
            teacher,
          ]),
        );
      } catch {
        setError('تعذر الاتصال بالخادم. تحقق من الإنترنت ثم حاول مرة أخرى.');
        return;
      }
    }

    teacher.lastActivity = new Date().toISOString();
    const updated = teachers.map(t => t.id === teacher.id ? teacher : t);
    localStorage.setItem(STORAGE_KEYS.TEACHERS, JSON.stringify(updated));

    if (teacher.mustChangePassword) {
      setCurrentTeacher(teacher);
      setShowChangePassword(true);
    } else {
      // جلسة الوسائط لا تحجب الدخول.
      //
      // كانت `return` عند فشلها تمنع المعلّم من الدخول أصلاً، وتعرض له
      // «تعذر تأكيد جلسة رفع الفيديو» على شاشة تسجيل الدخول — وهي جلسة لا
      // يحتاجها إلا لحظة رفع ملف MP4 فعلياً. فمعلّم يريد مراجعة تقاريره
      // كان يُمنَع لعطل في ميزة لا يستعملها.
      //
      // والرفع نفسه محميّ: `uploadMp4Video` يكتشف انتهاء الجلسة ويطلب
      // إعادة الدخول برسالته الخاصة عند الحاجة الحقيقية.
      //
      // وهي أيضاً جلسة الحفظ: الخادم لا يعرف من يكتب إلا منها، فبدونها
      // يردّ كل حفظ بـ 401 ولا يصل شيء إلى الطلاب. الدخول يكمل على أي
      // حال — منعُه لا يصلح شيئاً — لكن الفشل يُقال للمعلم صراحةً بدل
      // سطر في طرفية المتصفح لا يقرأه أحد.
      const session = await openTeacherSession(teacher.username, password);
      if (session.ok === false) {
        alert(
          'دخلت إلى لوحتك، لكن الخادم لم يفتح جلسة الحفظ:\n' +
            `${session.reason}\n\n` +
            'ما تعدّله سيبقى في هذا المتصفح ولن يصل إلى الطلاب حتى تُفتح الجلسة. ' +
            'راجع المشرف للتأكد من أن حسابك مسجَّل في الخادم، ثم أعد تسجيل الدخول.',
        );
      }
      writeActiveSession(STORAGE_KEYS.CURRENT_TEACHER, teacher);
      onLoginSuccess(teacher);
    }
  };

  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!newPassword.trim() || !confirmPassword.trim()) {
      setError('يرجى ملء جميع الحقول');
      return;
    }

    if (newPassword !== confirmPassword) {
      setError('كلمتا المرور غير متطابقتين');
      return;
    }

    if (newPassword.length < 6) {
      setError('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    if (!currentTeacher) return;

    try {
      const response = await fetch('/api/auth/teacher/change-password', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: currentTeacher.username,
          currentPassword: password,
          newPassword,
        }),
      });
      const result = await response.json().catch(() => ({}));
      if (!response.ok) {
        setError(result.error || 'تعذر تحديث كلمة المرور الآن');
        return;
      }
    } catch {
      setError('تعذر الاتصال بالخادم. تحقق من الإنترنت ثم حاول مرة أخرى.');
      return;
    }

    const hashedPassword = hashPassword(newPassword);
    const teachers = readStorageArray<TeacherInfo>(STORAGE_KEYS.TEACHERS);
    const updated = teachers.map(t =>
      t.id === currentTeacher.id
        ? { ...t, password: hashedPassword, mustChangePassword: false }
        : t
    );

    localStorage.setItem(STORAGE_KEYS.TEACHERS, JSON.stringify(updated));

    const updatedTeacher = { ...currentTeacher, password: hashedPassword, mustChangePassword: false };
    writeActiveSession(STORAGE_KEYS.CURRENT_TEACHER, updatedTeacher);
    onLoginSuccess(updatedTeacher);
  };

  const teacherFeatures = ['الفصول والطلاب وأولياء الأمور', 'الدروس والاختبارات والمحتوى', 'التقارير والشهادات'];

  if (showChangePassword && currentTeacher) {
    return (
      <PortalLoginLayout
        portalName="بوابة المعلم"
        title="تغيير كلمة المرور"
        subtitle={`مرحباً ${currentTeacher.name}، غيّر كلمة المرور المؤقتة قبل المتابعة.`}
        icon={KeyRound}
        features={teacherFeatures}
        error={error}
      >
        <form onSubmit={handleChangePassword} className="portal-login-form">
          <PortalField label="كلمة المرور الجديدة" hint="ستة أحرف على الأقل">
            <input
              type="password"
              name="new-password"
              autoComplete="new-password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              className="portal-input"
              required
            />
          </PortalField>
          <PortalField label="تأكيد كلمة المرور">
            <input
              type="password"
              name="confirm-password"
              autoComplete="new-password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className="portal-input"
              required
            />
          </PortalField>
          <button type="submit" className="portal-btn portal-btn-primary">حفظ والمتابعة</button>
        </form>
      </PortalLoginLayout>
    );
  }

  return (
    <PortalLoginLayout
      portalName="بوابة المعلم"
      title="تسجيل الدخول"
      subtitle="ادخل بحساب المعلم الذي أنشأه لك المشرف."
      icon={Presentation}
      features={teacherFeatures}
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
            required
          />
        </PortalField>
        <button type="submit" className="portal-btn portal-btn-primary">تسجيل الدخول</button>
      </form>
      <p className="portal-login-help">للدعم الفني، تواصل مع مشرف المنصّة.</p>
    </PortalLoginLayout>
  );
};

export default TeacherLogin;
