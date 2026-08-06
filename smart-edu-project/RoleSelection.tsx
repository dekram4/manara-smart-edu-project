import { useState } from 'react';
import { supabase } from './supabaseClient';

export default function RoleSelection({ userId, onRoleSelected }: { userId: string, onRoleSelected: () => void }) {
  const [loading, setLoading] = useState(false);

  const setRole = async (role: string) => {
    setLoading(true);
    // حفظ الدور في جدول profiles
    const { error } = await supabase
      .from('profiles')
      .upsert({ id: userId, role: role, full_name: 'مستخدم جديد' });

    if (error) {
      alert("حدث خطأ: " + error.message);
    } else {
      onRoleSelected();
    }
    setLoading(false);
  };

  return (
    <div style={{ textAlign: 'center', padding: '50px' }}>
      <h2>أهلاً بك! اختر نوع حسابك للبدء</h2>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '15px', maxWidth: '400px', margin: '20px auto' }}>
        <button onClick={() => setRole('admin')} disabled={loading}>مشرف</button>
        <button onClick={() => setRole('teacher')} disabled={loading}>معلم</button>
        <button onClick={() => setRole('parent')} disabled={loading}>ولي أمر</button>
        <button onClick={() => setRole('student')} disabled={loading}>طالب</button>
      </div>
    </div>
  );
}
