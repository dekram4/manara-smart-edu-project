import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Eye as IconEye, Mic as IconMic, X as IconX } from 'lucide-react';

/**
 * «رسائل طلابي»: ما أرسله طلابُ المعلّم إليه من تطبيقهم — نصوصٌ ومقاطعُ صوتية.
 * والصورُ واللوحاتُ بين الطلاب وحدهم، فلا تصل هنا.
 *
 * ── تختفي بعد المشاهدة كما في التطبيق ──
 * المعلّمُ مستلمٌ كأيّ زميل: النصُّ يُقرأ بعرضه، والمقطعُ بسماعه. ويرى الطالبُ في تطبيقه أنّ معلّمه شاهدها، وتبقى هنا حتى يُغلق
 * المعلّمُ النافذة — ثم لا تعود، وتُحذف من الخادم.
 *
 * والجلسةُ من ملفّ تعريف المعلّم (`manara_teacher_session`) لا من هنا: الخادمُ
 * يقصر الرسائلَ على طلابه هو.
 */

interface InboxMessage {
  id: string;
  from: string;
  name: string;
  grade: string;
  message: string;
  time: string;
  kind: 'text' | 'voice';
  voiceId?: string;
  durationMs?: number;
}

interface StudentInboxProps {
  onClose: () => void;
}

const BASE = '/api/teacher/chat';

const StudentInbox: React.FC<StudentInboxProps> = ({ onClose }) => {
  const [messages, setMessages] = useState<InboxMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [opened, setOpened] = useState<Set<string>>(new Set());
  const [busyId, setBusyId] = useState('');
  const visit = useRef<string | null>(null);
  const reported = useRef<Set<string>>(new Set());
  const objectUrls = useRef<string[]>([]);

  const reportSeen = useCallback(async (ids: string[]) => {
    const fresh = ids.filter((id) => !reported.current.has(id));
    if (fresh.length === 0) return;
    fresh.forEach((id) => reported.current.add(id));
    try {
      const response = await fetch(`${BASE}/seen`, {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ids: fresh }),
      });
      if (!response.ok) fresh.forEach((id) => reported.current.delete(id));
    } catch {
      fresh.forEach((id) => reported.current.delete(id));
    }
  }, []);

  const load = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    try {
      const query = visit.current ? `?visit=${encodeURIComponent(visit.current)}` : '';
      const response = await fetch(`${BASE}/messages${query}`, { credentials: 'same-origin' });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(data?.error || 'تعذر تحميل رسائل الطلاب الآن');
      visit.current ??= typeof data.visit === 'string' ? data.visit : null;
      const list: InboxMessage[] = Array.isArray(data.messages) ? data.messages : [];
      setMessages(list);
      setError('');
      // ‏النصُّ يُقرأ بعرضه. أمّا المقطعُ فبسماعه.
      void reportSeen(list.filter((m) => m.kind === 'text').map((m) => m.id));
    } catch (err) {
      if (!silent) setError(err instanceof Error ? err.message : 'تعذر تحميل رسائل الطلاب الآن');
    } finally {
      if (!silent) setLoading(false);
    }
  }, [reportSeen]);

  useEffect(() => {
    void load();
    const timer = window.setInterval(() => void load(true), 8000);
    const urls = objectUrls.current;
    return () => {
      window.clearInterval(timer);
      urls.forEach((url) => URL.revokeObjectURL(url));
    };
  }, [load]);

  const fetchVoice = async (id: string): Promise<string> => {
    const response = await fetch(`${BASE}/voice/${encodeURIComponent(id)}`, { credentials: 'same-origin' });
    if (!response.ok) throw new Error('تعذر تشغيل الرسالة الصوتية');
    const url = URL.createObjectURL(await response.blob());
    objectUrls.current.push(url);
    return url;
  };

  const openMessage = async (message: InboxMessage) => {
    if (busyId) return;
    setBusyId(message.id);
    try {
      if (message.kind === 'voice' && message.voiceId) {
        const url = await fetchVoice(message.voiceId);
        await new Audio(url).play();
      }
      setOpened((prev) => new Set(prev).add(message.id));
      void reportSeen([message.id]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر الفتح');
    } finally {
      setBusyId('');
    }
  };

  const time = (value: string) => {
    const date = new Date(value);
    return Number.isNaN(date.getTime())
      ? ''
      : date.toLocaleString('ar', { hour: '2-digit', minute: '2-digit', day: 'numeric', month: 'short' });
  };

  return (
    <div style={styles.overlay} role="dialog" aria-modal="true" aria-label="رسائل طلابي" dir="rtl">
      <div style={styles.panel}>
        <div style={styles.header}>
          <div>
            <div style={styles.title}>✉️ رسائل طلابي</div>
            <div style={styles.subtitle}>
              ما أرسله طلابك إليك من التطبيق. تختفي الرسالة بعد مشاهدتها وإغلاق هذه النافذة.
            </div>
          </div>
          <button type="button" onClick={onClose} style={styles.close} aria-label="إغلاق">
            <IconX size={22} />
          </button>
        </div>

        {error && <div style={styles.error}>{error}</div>}

        <div style={styles.list}>
          {loading ? (
            <div style={styles.empty}>جارٍ التحميل…</div>
          ) : messages.length === 0 ? (
            <div style={styles.empty}>لا توجد رسائل جديدة من طلابك.</div>
          ) : (
            messages.map((message) => {
              const seen = opened.has(message.id);
              return (
                <div key={message.id} style={styles.card}>
                  <div style={styles.cardHead}>
                    <strong>{message.name}</strong>
                    <span style={styles.meta}>
                      {message.grade ? `${message.grade} · ` : ''}
                      {time(message.time)}
                    </span>
                  </div>
                  {message.kind === 'text' ? (
                    <div style={styles.text}>{message.message}</div>
                  ) : (
                    <button
                      type="button"
                      onClick={() => void openMessage(message)}
                      disabled={busyId === message.id}
                      style={{
                        ...styles.media,
                        background: seen
                          ? '#e5e7eb'
                          : 'linear-gradient(135deg, #0ea5e9, #8b5cf6)',
                        color: seen ? '#374151' : 'white',
                      }}
                    >
                      <IconMic size={22} />
                      <span>
                        {busyId === message.id
                          ? 'جارٍ الفتح…'
                          : seen ? 'استمعتَ إليها ✓' : 'رسالة صوتية — اضغط للاستماع'}
                      </span>
                      <IconEye size={18} />
                    </button>
                  )}
                </div>
              );
            })
          )}
        </div>
      </div>

    </div>
  );
};

const styles: Record<string, React.CSSProperties> = {
  overlay: {
    position: 'fixed', inset: 0, background: 'rgba(15, 23, 42, 0.55)', zIndex: 1000,
    display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16,
  },
  panel: {
    width: 'min(640px, 100%)', maxHeight: '90vh', background: '#fff', borderRadius: 24,
    display: 'flex', flexDirection: 'column', overflow: 'hidden', boxShadow: '0 20px 50px rgba(0,0,0,0.25)',
  },
  header: {
    display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12,
    padding: 20, borderBottom: '2px solid #f1f5f9', background: '#fdf2f8',
  },
  title: { fontSize: 20, fontWeight: 800, color: '#831843' },
  subtitle: { fontSize: 13, color: '#6b7280', marginTop: 4, lineHeight: 1.6 },
  close: {
    border: 'none', background: 'white', borderRadius: 999, width: 40, height: 40, cursor: 'pointer',
    display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#374151', flexShrink: 0,
  },
  error: { margin: '12px 20px 0', padding: 12, borderRadius: 12, background: '#fee2e2', color: '#991b1b', fontWeight: 700 },
  list: { padding: 20, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 12 },
  empty: { textAlign: 'center', color: '#6b7280', padding: 32, fontWeight: 700 },
  card: { border: '2px solid #f1f5f9', borderRadius: 16, padding: 14, background: '#fafafa' },
  cardHead: { display: 'flex', justifyContent: 'space-between', gap: 8, marginBottom: 8, flexWrap: 'wrap' },
  meta: { fontSize: 12, color: '#6b7280' },
  text: { lineHeight: 1.7, color: '#111827', whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' },
  media: {
    display: 'flex', alignItems: 'center', gap: 10, width: '100%', border: 'none', borderRadius: 14,
    padding: '12px 14px', cursor: 'pointer', fontWeight: 800, fontSize: 14, textAlign: 'right',
  },
};

export default StudentInbox;
