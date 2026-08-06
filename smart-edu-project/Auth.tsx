import { useState } from 'react';
import { supabase } from './supabaseClient';

export default function Auth() {
  const [loading, setLoading] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const handleAuth = async (isSignUp: boolean) => {
    setLoading(true);
    const { error } = isSignUp
      ? await supabase.auth.signUp({ email, password })
      : await supabase.auth.signInWithPassword({ email, password });

    if (error) alert(error.message);
    else if (isSignUp) alert('تم إنشاء الحساب بنجاح! الرجاء التحقق من بريدك الإلكتروني.');
    setLoading(false);
  };

  return (
    <div style={{ padding: '20px', maxWidth: '400px', margin: 'auto' }}>
      <h2>تسجيل الدخول للنظام</h2>
      <input
        type="email"
        placeholder="البريد الإلكتروني"
        onChange={(e) => setEmail(e.target.value)}
        style={{ display: 'block', width: '100%', marginBottom: '10px' }}
      />
      <input
        type="password"
        placeholder="كلمة المرور"
        onChange={(e) => setPassword(e.target.value)}
        style={{ display: 'block', width: '100%', marginBottom: '10px' }}
      />
      <button onClick={() => handleAuth(false)} disabled={loading}>
        {loading ? 'جاري الدخول...' : 'دخول'}
      </button>
      <button onClick={() => handleAuth(true)} disabled={loading} style={{ marginLeft: '10px' }}>
        إنشاء حساب جديد
      </button>
    </div>
  );
}
