import React, { useCallback, useEffect, useState } from 'react';
import { planLabel } from '../../utils/subscriptionPlans';

/**
 * «طلبات الانضمام الجديدة»: ما يرسله الزوّار من «احصل على حساب رسمي» في
 * التطبيق — الباقةُ وفئتُها، والاسم، والصف، وعدد الطلاب، والجوال.
 *
 * التفعيلُ نفسه من «إدارة الحسابات»: يُنشأ الحسابُ هناك وتُختار باقتُه فتُطبَّق
 * صلاحياتُها، و«صلاحيات البطاقات» تبقى فوقها لأيّ تعديلٍ يدويّ.
 */
type JoinRequest = {
  id: string;
  plan: string;
  name: string;
  grade?: string;
  students?: number | null;
  phone: string;
  note?: string;
  status: 'new' | 'contacted' | 'activated' | 'rejected';
  createdAt: string;
};

const STATUS: Record<JoinRequest['status'], { label: string; color: string; bg: string }> = {
  new: { label: 'جديد', color: '#92400e', bg: '#fef3c7' },
  contacted: { label: 'تم التواصل', color: '#1e40af', bg: '#dbeafe' },
  activated: { label: 'مُفعّل', color: '#065f46', bg: '#d1fae5' },
  rejected: { label: 'مرفوض', color: '#991b1b', bg: '#fee2e2' },
};

const JoinRequests: React.FC = () => {
  const [requests, setRequests] = useState<JoinRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState<'all' | JoinRequest['status']>('all');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const response = await fetch('/api/admin/join-requests', { credentials: 'same-origin' });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(data?.error || 'تعذر تحميل الطلبات');
      setRequests(Array.isArray(data.requests) ? data.requests : []);
      setError('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل الطلبات');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const setStatus = async (id: string, status: JoinRequest['status']) => {
    const response = await fetch(`/api/admin/join-requests/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status }),
    });
    if (!response.ok) {
      setError('تعذر تحديث حالة الطلب');
      return;
    }
    setRequests((prev) => prev.map((r) => (r.id === id ? { ...r, status } : r)));
  };

  const whatsapp = (r: JoinRequest) => {
    const phone = r.phone.replace(/\D/g, '');
    const text = encodeURIComponent(`مرحباً ${r.name}، بخصوص طلبك (${planLabel(r.plan)}) في منصة منارة المعرفة.`);
    return `https://wa.me/${phone}?text=${text}`;
  };

  const shown = requests.filter((r) => filter === 'all' || r.status === filter);
  const fresh = requests.filter((r) => r.status === 'new').length;

  return (
    <div dir="rtl" style={{ padding: 20 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap', marginBottom: 16 }}>
        <h2 style={{ margin: 0, fontSize: 22, fontWeight: 900 }}>📥 طلبات الانضمام الجديدة</h2>
        {fresh > 0 && (
          <span style={{ background: '#dc2626', color: 'white', borderRadius: 999, padding: '2px 10px', fontWeight: 800 }}>{fresh} جديد</span>
        )}
        <div style={{ marginInlineStart: 'auto', display: 'flex', gap: 6 }}>
          {(['all', 'new', 'contacted', 'activated', 'rejected'] as const).map((key) => (
            <button
              key={key}
              type="button"
              onClick={() => setFilter(key)}
              style={{
                border: '1px solid #d1d5db',
                borderRadius: 10,
                padding: '6px 12px',
                cursor: 'pointer',
                fontWeight: 700,
                background: filter === key ? '#4f46e5' : 'white',
                color: filter === key ? 'white' : '#111827',
              }}
            >
              {key === 'all' ? 'الكل' : STATUS[key].label}
            </button>
          ))}
          <button type="button" onClick={() => void load()} style={{ border: '1px solid #d1d5db', borderRadius: 10, padding: '6px 12px', cursor: 'pointer' }}>
            تحديث
          </button>
        </div>
      </div>
      <p style={{ color: '#4b5563', marginTop: 0 }}>
        للتفعيل: أنشئ الحساب من «إدارة الحسابات» واختر له «باقة الاشتراك» فتُطبَّق صلاحياتها آلياً. ويبقى «صلاحيات البطاقات» فوق الباقة لفتح أو إغلاق أيّ بطاقة يدوياً.
      </p>
      {error && <div style={{ background: '#fee2e2', color: '#991b1b', padding: 10, borderRadius: 10, marginBottom: 12 }}>{error}</div>}
      {loading ? (
        <div>جارٍ التحميل…</div>
      ) : shown.length === 0 ? (
        <div style={{ color: '#6b7280', padding: 30, textAlign: 'center' }}>لا طلبات هنا.</div>
      ) : (
        <div style={{ display: 'grid', gap: 12 }}>
          {shown.map((r) => (
            <div key={r.id} data-testid="join-request" style={{ background: 'white', border: '1px solid #e5e7eb', borderRadius: 14, padding: 14, display: 'grid', gap: 6 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                <strong style={{ fontSize: 16 }}>{r.name}</strong>
                <span style={{ background: '#ede9fe', color: '#5b21b6', borderRadius: 999, padding: '2px 10px', fontWeight: 800, fontSize: 13 }}>
                  {planLabel(r.plan)}
                </span>
                <span style={{ background: STATUS[r.status]?.bg, color: STATUS[r.status]?.color, borderRadius: 999, padding: '2px 10px', fontWeight: 800, fontSize: 13 }}>
                  {STATUS[r.status]?.label ?? r.status}
                </span>
                <span style={{ marginInlineStart: 'auto', color: '#6b7280', fontSize: 13 }}>
                  {new Date(r.createdAt).toLocaleString('ar')}
                </span>
              </div>
              <div style={{ color: '#374151', fontSize: 14 }}>
                {r.grade ? `الصف: ${r.grade} · ` : ''}
                {r.students ? `عدد الطلاب: ${r.students} · ` : ''}
                الجوال: <span dir="ltr">{r.phone}</span>
              </div>
              {r.note && <div style={{ color: '#4b5563', fontSize: 14 }}>📝 {r.note}</div>}
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                <a href={whatsapp(r)} target="_blank" rel="noreferrer" style={{ background: '#16a34a', color: 'white', borderRadius: 10, padding: '6px 12px', fontWeight: 800, textDecoration: 'none' }}>
                  واتساب
                </a>
                {(['contacted', 'activated', 'rejected'] as const).map((status) => (
                  <button
                    key={status}
                    type="button"
                    disabled={r.status === status}
                    onClick={() => void setStatus(r.id, status)}
                    style={{ border: '1px solid #d1d5db', borderRadius: 10, padding: '6px 12px', cursor: 'pointer', fontWeight: 700, opacity: r.status === status ? 0.5 : 1 }}
                  >
                    {STATUS[status].label}
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default JoinRequests;
