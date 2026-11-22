import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Download as IconDownload,
  Image as IconImage,
  Lock as IconLock,
  Mic as IconMic,
  Paperclip as IconPaperclip,
  Send as IconSend,
  Square as IconStop,
  Unlock as IconUnlock,
  X as IconX,
} from 'lucide-react';

/**
 * «دردشة طلابي»: المعلّمُ يراسل كلَّ طالبٍ من طلابه — نصّاً وصوتاً وصوراً
 * ومستندات — ويقفل الدردشةَ لطالبٍ بعينه أو لطلابه جميعاً متى شاء.
 *
 * ── تختفي بعد المشاهدة كما في التطبيق ──
 * النصُّ يُقرأ بعرضه، والمقطعُ بسماعه، والصورةُ والملفُّ بفتحهما. ويرى الطالبُ
 * أنّ معلّمه شاهدها، وتبقى هنا حتى تُغلق النافذة — ثم لا تعود، وتُحذف من الخادم.
 *
 * ── والقفل ──
 * يوقف إرسالَ الطالب كلَّه (إلى زملائه وإلى المعلّم)، ويرى في تطبيقه: «المعلم قام
 * بقفل الدردشة حالياً». والمعلّمُ يرسل له كما يشاء.
 *
 * والجلسةُ من ملفّ تعريف المعلّم (`manara_teacher_session`): الخادمُ يقصر كلَّ شيءٍ
 * على طلابه هو.
 */

type Kind = 'text' | 'voice' | 'image' | 'file';

interface ChatMessage {
  id: string;
  from: string;
  to: string;
  name: string;
  grade: string;
  message: string;
  time: string;
  kind: Kind;
  voiceId?: string;
  imageId?: string;
  fileId?: string;
  fileName?: string;
  fileSize?: number;
  durationMs?: number;
  mine?: boolean;
  readByAll?: boolean;
}

interface ChatStudent {
  id: string;
  name: string;
  grade: string;
  chat: boolean;
  locked: boolean;
}

interface StudentInboxProps {
  onClose: () => void;
}

const BASE = '/api/teacher/chat';
const IMAGE_MAX = 590 * 1024;
const FILE_MAX = 1500 * 1024;
const FILE_STORED_MAX = 1100 * 1024;
const VOICE_MAX_MS = 30_000;
const FILE_ACCEPT = '.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.odt,.ods,.odp,.rtf,.txt,.csv,.md,.json,.png,.jpg,.jpeg,.webp,.gif';

function toBase64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
}

/** gzip في المتصفّح إن صغُر به الملفّ عُشراً — وإلا يُرسل كما هو. */
async function pack(bytes: Uint8Array): Promise<{ data: Uint8Array; gzip: boolean }> {
  const Stream = (window as unknown as { CompressionStream?: typeof CompressionStream }).CompressionStream;
  if (!Stream || bytes.length < 512) return { data: bytes, gzip: false };
  try {
    const stream = new Blob([bytes as BlobPart]).stream().pipeThrough(new Stream('gzip'));
    const packed = new Uint8Array(await new Response(stream).arrayBuffer());
    return packed.length < bytes.length * 0.9 ? { data: packed, gzip: true } : { data: bytes, gzip: false };
  } catch {
    return { data: bytes, gzip: false };
  }
}

/** صورةٌ كبيرة تُصغَّر JPEG في المتصفّح حتى تدخل السقف. */
async function shrinkImage(file: File): Promise<Uint8Array> {
  const original = new Uint8Array(await file.arrayBuffer());
  if (original.length <= IMAGE_MAX && /image\/(png|jpeg|webp)/.test(file.type)) return original;
  const bitmap = await createImageBitmap(file);
  let side = 1280;
  for (let attempt = 0; attempt < 5; attempt++) {
    const scale = Math.min(1, side / Math.max(bitmap.width, bitmap.height));
    const canvas = document.createElement('canvas');
    canvas.width = Math.round(bitmap.width * scale);
    canvas.height = Math.round(bitmap.height * scale);
    const ctx = canvas.getContext('2d')!;
    ctx.fillStyle = '#fff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    for (const quality of [0.82, 0.7, 0.58]) {
      const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/jpeg', quality));
      if (blob && blob.size <= IMAGE_MAX) return new Uint8Array(await blob.arrayBuffer());
    }
    side = Math.round(side * 0.75);
  }
  throw new Error('الصورة كبيرة جداً');
}

const sizeLabel = (bytes = 0) =>
  bytes >= 1024 * 1024 ? `${(bytes / 1024 / 1024).toFixed(1)} MB` : `${Math.ceil(bytes / 1024)} KB`;

const StudentInbox: React.FC<StudentInboxProps> = ({ onClose }) => {
  const [students, setStudents] = useState<ChatStudent[]>([]);
  const [lockAll, setLockAll] = useState(false);
  const [notice, setNotice] = useState('');
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [selected, setSelected] = useState('');
  const [query, setQuery] = useState('');
  const [draft, setDraft] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const [opened, setOpened] = useState<Set<string>>(new Set());
  const [busyId, setBusyId] = useState('');
  const [viewer, setViewer] = useState<{ url: string; name: string } | null>(null);
  const [recording, setRecording] = useState(false);
  const visit = useRef<string | null>(null);
  const reported = useRef<Set<string>>(new Set());
  const objectUrls = useRef<string[]>([]);
  const recorder = useRef<MediaRecorder | null>(null);
  const recordStart = useRef(0);
  const fileInput = useRef<HTMLInputElement>(null);
  const listEnd = useRef<HTMLDivElement>(null);

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

  const loadStudents = useCallback(async () => {
    const response = await fetch(`${BASE}/students`, { credentials: 'same-origin' });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data?.error || 'تعذر تحميل الطلاب الآن');
    setStudents(Array.isArray(data.students) ? data.students : []);
    setLockAll(data?.lock?.all === true);
  }, []);

  const loadMessages = useCallback(async () => {
    const q = visit.current ? `?visit=${encodeURIComponent(visit.current)}` : '';
    const response = await fetch(`${BASE}/messages${q}`, { credentials: 'same-origin' });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data?.error || 'تعذر تحميل الرسائل الآن');
    visit.current ??= typeof data.visit === 'string' ? data.visit : null;
    const list: ChatMessage[] = Array.isArray(data.messages) ? data.messages : [];
    setMessages(list);
    // ‏رسائلي التي قرأها الطالب: تُستهلك عندي أيضاً، فتُكنس.
    void reportSeen(list.filter((m) => m.mine && m.readByAll).map((m) => m.id));
  }, [reportSeen]);

  const load = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    try {
      await Promise.all([loadStudents(), loadMessages()]);
      setError('');
    } catch (err) {
      if (!silent) setError(err instanceof Error ? err.message : 'تعذر التحميل الآن');
    } finally {
      if (!silent) setLoading(false);
    }
  }, [loadStudents, loadMessages]);

  useEffect(() => {
    void load();
    const timer = window.setInterval(() => void loadMessages().catch(() => undefined), 8000);
    const urls = objectUrls.current;
    return () => {
      window.clearInterval(timer);
      urls.forEach((url) => URL.revokeObjectURL(url));
      recorder.current?.stream.getTracks().forEach((t) => t.stop());
    };
  }, [load, loadMessages]);

  const thread = useMemo(
    () => messages.filter((m) => m.from === selected || m.to === selected),
    [messages, selected],
  );

  // ‏النصُّ من الطالب يُقرأ بعرضه في محادثته.
  useEffect(() => {
    if (!selected) return;
    void reportSeen(thread.filter((m) => !m.mine && m.kind === 'text').map((m) => m.id));
    listEnd.current?.scrollIntoView({ block: 'end' });
  }, [thread, selected, reportSeen]);

  const unread = useCallback(
    (id: string) => messages.filter((m) => m.from === id && !opened.has(m.id) && !reported.current.has(m.id)).length,
    [messages, opened],
  );

  const shown = students.filter((s) => !query.trim() || s.name.includes(query.trim()) || s.grade.includes(query.trim()));
  const current = students.find((s) => s.id === selected);

  const post = async (route: string, body: Record<string, unknown>) => {
    const response = await fetch(`${BASE}/${route}`, {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(response.status === 404 && data?.code === 'not_found'
        ? 'هذه الميزة غير متاحة على الخادم بعد'
        : data?.error || 'تعذر الإرسال الآن');
    }
    return data;
  };

  const run = async (task: () => Promise<unknown>) => {
    if (sending || !selected) return;
    setSending(true);
    setError('');
    try {
      await task();
      await loadMessages();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر الإرسال الآن');
    } finally {
      setSending(false);
    }
  };

  const sendText = () => {
    const message = draft.trim();
    if (!message) return;
    void run(async () => {
      await post('messages', { to: selected, message });
      setDraft('');
    });
  };

  const sendFile = (file: File) => {
    void run(async () => {
      if (/^image\/(png|jpeg|webp)$/.test(file.type)) {
        const bytes = await shrinkImage(file);
        await post('image', { to: selected, image: toBase64(bytes) });
        return;
      }
      if (file.size > FILE_MAX) throw new Error('الملف أكبر من 1.5 ميغابايت');
      const { data, gzip } = await pack(new Uint8Array(await file.arrayBuffer()));
      if (data.length > FILE_STORED_MAX) throw new Error('الملف أكبر من المسموح');
      await post('file', { to: selected, name: file.name, file: toBase64(data), gzip });
    });
  };

  const toggleRecording = async () => {
    if (recording) {
      recorder.current?.stop();
      return;
    }
    if (!selected || sending) return;
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mime = ['audio/webm;codecs=opus', 'audio/ogg;codecs=opus', 'audio/mp4']
        .find((type) => MediaRecorder.isTypeSupported(type));
      const rec = new MediaRecorder(stream, { mimeType: mime, audioBitsPerSecond: 24_000 });
      const chunks: BlobPart[] = [];
      rec.ondataavailable = (e) => chunks.push(e.data);
      rec.onstop = () => {
        stream.getTracks().forEach((t) => t.stop());
        setRecording(false);
        const durationMs = Math.min(Date.now() - recordStart.current, VOICE_MAX_MS);
        const blob = new Blob(chunks, { type: rec.mimeType });
        void run(async () => {
          const bytes = new Uint8Array(await blob.arrayBuffer());
          await post('voice', { to: selected, audio: toBase64(bytes), durationMs });
        });
      };
      recorder.current = rec;
      recordStart.current = Date.now();
      rec.start();
      setRecording(true);
      window.setTimeout(() => rec.state === 'recording' && rec.stop(), VOICE_MAX_MS);
    } catch {
      setError('لم يُسمح باستخدام الميكروفون');
    }
  };

  const fetchBlob = async (route: string, id: string) => {
    const response = await fetch(`${BASE}/${route}/${encodeURIComponent(id)}`, { credentials: 'same-origin' });
    if (!response.ok) throw new Error('تعذر الفتح الآن');
    const url = URL.createObjectURL(await response.blob());
    objectUrls.current.push(url);
    return url;
  };

  const openMedia = async (message: ChatMessage) => {
    if (busyId) return;
    setBusyId(message.id);
    try {
      if (message.kind === 'voice' && message.voiceId) {
        await new Audio(await fetchBlob('voice', message.voiceId)).play();
      } else if (message.kind === 'image' && message.imageId) {
        setViewer({ url: await fetchBlob('image', message.imageId), name: message.name });
      } else if (message.kind === 'file' && message.fileId) {
        const link = document.createElement('a');
        link.href = await fetchBlob('file', message.fileId);
        link.download = message.fileName || 'ملف';
        link.click();
      }
      setOpened((prev) => new Set(prev).add(message.id));
      if (!message.mine) void reportSeen([message.id]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر الفتح');
    } finally {
      setBusyId('');
    }
  };

  const setLock = async (change: { all: boolean } | { studentId: string; locked: boolean }) => {
    try {
      const data = await post('lock', change);
      const lock = data?.lock ?? {};
      setLockAll(lock.all === true);
      const locked = new Set<string>(Array.isArray(lock.students) ? lock.students : []);
      setStudents((prev) => prev.map((s) => ({ ...s, locked: lock.all === true || locked.has(s.id) })));
      const who = 'all' in change ? 'لجميع الطلاب' : `للطالب ${students.find((s) => s.id === change.studentId)?.name ?? ''}`;
      const on = 'all' in change ? change.all : change.locked;
      setNotice(on
        ? `🔒 قُفلت الدردشة ${who}. سيرى: «المعلم قام بقفل الدردشة حالياً».`
        : `🔓 فُتحت الدردشة ${who}.`);
      setError('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تغيير القفل');
    }
  };

  const time = (value: string) => {
    const date = new Date(value);
    return Number.isNaN(date.getTime())
      ? ''
      : date.toLocaleString('ar', { hour: '2-digit', minute: '2-digit', day: 'numeric', month: 'short' });
  };

  const mediaLabel = (m: ChatMessage, seen: boolean) => {
    if (busyId === m.id) return 'جارٍ الفتح…';
    if (m.kind === 'voice') return seen ? 'استمعتَ إليها ✓' : `🎤 رسالة صوتية${m.durationMs ? ` (${Math.round(m.durationMs / 1000)} ث)` : ''}`;
    if (m.kind === 'image') return seen ? 'شاهدتَها ✓' : '🖼️ صورة — اضغط للمشاهدة';
    return `📎 ${m.fileName || 'ملف'} · ${sizeLabel(m.fileSize)}${seen ? ' ✓' : ''}`;
  };

  return (
    <div style={styles.overlay} role="dialog" aria-modal="true" aria-label="دردشة طلابي" dir="rtl">
      <div style={styles.panel}>
        <div style={styles.header}>
          <div>
            <div style={styles.title}>✉️ دردشة طلابي</div>
            <div style={styles.subtitle}>
              راسل طلابك نصاً وصوتاً وصوراً ومستندات. تختفي الرسالة بعد مشاهدتها وإغلاق النافذة.
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <button
              type="button"
              data-testid="lock-all"
              onClick={() => void setLock({ all: !lockAll })}
              style={{ ...styles.lockAll, background: lockAll ? '#b91c1c' : '#065f46' }}
            >
              {lockAll ? <IconLock size={16} /> : <IconUnlock size={16} />}
              {lockAll ? 'الدردشة مقفلة للجميع — افتحها' : 'قفل الدردشة للجميع'}
            </button>
            <button type="button" onClick={onClose} style={styles.close} aria-label="إغلاق">
              <IconX size={22} />
            </button>
          </div>
        </div>

        {error && <div style={styles.error}>{error}</div>}
        {notice && !error && <div style={styles.notice} data-testid="lock-notice">{notice}</div>}

        <div style={styles.body}>
          <aside style={styles.side}>
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="ابحث عن طالب أو صف"
              style={styles.search}
            />
            {loading ? (
              <div style={styles.empty}>جارٍ التحميل…</div>
            ) : shown.length === 0 ? (
              <div style={styles.empty}>
                لا يوجد طلاب مربوطون بك بعد. اربط الطالب بك من «إدارة الطلاب وأولياء الأمور» ليظهر هنا.
              </div>
            ) : (
              shown.map((student) => {
                const count = unread(student.id);
                return (
                  <div
                    key={student.id}
                    style={{ ...styles.student, ...(student.id === selected ? styles.studentActive : {}) }}
                  >
                    <button type="button" onClick={() => setSelected(student.id)} style={styles.studentName}>
                      <strong>{student.name}</strong>
                      <span style={styles.meta}>{student.grade}{student.chat ? '' : ' · الدردشة معطّلة'}</span>
                    </button>
                    {count > 0 && <span style={styles.badge}>{count}</span>}
                    <button
                      type="button"
                      title={student.locked ? 'فتح الدردشة لهذا الطالب' : 'قفل الدردشة لهذا الطالب'}
                      data-testid={`lock-${student.id}`}
                      onClick={() => void setLock({ studentId: student.id, locked: !student.locked })}
                      disabled={lockAll}
                      style={{
                        ...styles.lockOne,
                        color: student.locked ? '#b91c1c' : '#047857',
                        borderColor: student.locked ? '#fecaca' : '#a7f3d0',
                        background: student.locked ? '#fef2f2' : '#ecfdf5',
                        opacity: lockAll ? 0.5 : 1,
                      }}
                    >
                      {student.locked ? <IconLock size={14} /> : <IconUnlock size={14} />}
                      <span>{student.locked ? 'مقفلة' : 'مفتوحة'}</span>
                    </button>
                  </div>
                );
              })
            )}
          </aside>

          <section style={styles.thread}>
            {!current ? (
              <div style={styles.empty}>اختر طالباً لبدء الدردشة معه.</div>
            ) : (
              <>
                <div style={styles.threadHead}>
                  <strong>{current.name}</strong>
                  <span style={styles.meta}>{current.grade}</span>
                  {current.locked && <span style={styles.lockedTag}>🔒 الدردشة مقفلة لهذا الطالب</span>}
                  <button
                    type="button"
                    data-testid="lock-current"
                    disabled={lockAll}
                    onClick={() => void setLock({ studentId: current.id, locked: !current.locked })}
                    style={{ ...styles.lockAll, marginInlineStart: 'auto', padding: '6px 12px',
                      background: current.locked ? '#047857' : '#b91c1c', opacity: lockAll ? 0.5 : 1 }}
                  >
                    {current.locked ? <IconUnlock size={14} /> : <IconLock size={14} />}
                    {current.locked ? 'فتح الدردشة لهذا الطالب' : 'قفل الدردشة لهذا الطالب'}
                  </button>
                </div>
                <div style={styles.list}>
                  {thread.length === 0 && <div style={styles.empty}>لا رسائل بعد. اكتب أول رسالة.</div>}
                  {thread.map((m) => {
                    const seen = opened.has(m.id);
                    return (
                      <div key={m.id} style={{ ...styles.bubble, ...(m.mine ? styles.mine : styles.theirs) }}>
                        <div style={styles.cardHead}>
                          <strong>{m.mine ? 'أنت' : m.name}</strong>
                          <span style={{ ...styles.meta, color: m.mine ? '#e0e7ff' : '#6b7280' }}>{time(m.time)}</span>
                        </div>
                        {m.kind === 'text' ? (
                          <div style={styles.text}>{m.message}</div>
                        ) : (
                          <button
                            type="button"
                            onClick={() => void openMedia(m)}
                            disabled={busyId === m.id}
                            style={{ ...styles.media, background: seen ? '#e5e7eb' : 'linear-gradient(135deg, #0ea5e9, #8b5cf6)', color: seen ? '#374151' : 'white' }}
                          >
                            {m.kind === 'voice' ? <IconMic size={18} /> : m.kind === 'image' ? <IconImage size={18} /> : <IconDownload size={18} />}
                            <span>{mediaLabel(m, seen)}</span>
                          </button>
                        )}
                        {m.mine && <div style={styles.receipt}>{m.readByAll ? '✓✓ قرأها' : '✓ أُرسلت'}</div>}
                      </div>
                    );
                  })}
                  <div ref={listEnd} />
                </div>
                <div style={styles.composer}>
                  <input
                    ref={fileInput}
                    type="file"
                    accept={FILE_ACCEPT}
                    style={{ display: 'none' }}
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      e.target.value = '';
                      if (file) sendFile(file);
                    }}
                  />
                  <button type="button" title="إرسال صورة أو مستند" onClick={() => fileInput.current?.click()} disabled={sending || recording} style={styles.iconButton}>
                    <IconPaperclip size={20} />
                  </button>
                  <button
                    type="button"
                    title={recording ? 'إيقاف وإرسال' : 'تسجيل رسالة صوتية'}
                    onClick={() => void toggleRecording()}
                    disabled={sending && !recording}
                    style={{ ...styles.iconButton, background: recording ? '#dc2626' : '#f1f5f9', color: recording ? 'white' : '#111827' }}
                  >
                    {recording ? <IconStop size={20} /> : <IconMic size={20} />}
                  </button>
                  <textarea
                    value={draft}
                    onChange={(e) => setDraft(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' && !e.shiftKey) {
                        e.preventDefault();
                        sendText();
                      }
                    }}
                    maxLength={2000}
                    rows={1}
                    placeholder={recording ? 'جارٍ التسجيل… اضغط ■ للإرسال' : 'اكتب رسالة لطالبك'}
                    style={styles.input}
                    disabled={recording}
                  />
                  <button type="button" onClick={sendText} disabled={sending || !draft.trim()} style={styles.send}>
                    <IconSend size={18} />
                    {sending ? '…' : 'إرسال'}
                  </button>
                </div>
              </>
            )}
          </section>
        </div>
      </div>

      {viewer && (
        <div style={styles.viewer} onClick={() => setViewer(null)} role="dialog" aria-label="صورة">
          <img src={viewer.url} alt={viewer.name} style={{ maxWidth: '92vw', maxHeight: '85vh', borderRadius: 16 }} />
        </div>
      )}
    </div>
  );
};

const styles: Record<string, React.CSSProperties> = {
  overlay: {
    position: 'fixed', inset: 0, background: 'rgba(15, 23, 42, 0.55)', zIndex: 1000,
    display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16,
  },
  panel: {
    width: 'min(1100px, 100%)', height: 'min(90vh, 820px)', background: '#fff', borderRadius: 24,
    display: 'flex', flexDirection: 'column', overflow: 'hidden', boxShadow: '0 20px 50px rgba(0,0,0,0.25)',
  },
  header: {
    display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12, flexWrap: 'wrap',
    padding: 18, borderBottom: '2px solid #f1f5f9', background: '#fdf2f8',
  },
  title: { fontSize: 20, fontWeight: 800, color: '#831843' },
  subtitle: { fontSize: 13, color: '#6b7280', marginTop: 4, lineHeight: 1.6 },
  close: {
    border: 'none', background: 'white', borderRadius: 999, width: 40, height: 40, cursor: 'pointer',
    display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#374151', flexShrink: 0,
  },
  lockAll: {
    border: 'none', color: 'white', borderRadius: 999, padding: '9px 14px', cursor: 'pointer',
    display: 'flex', alignItems: 'center', gap: 6, fontWeight: 800, fontSize: 13,
  },
  error: { margin: '10px 18px 0', padding: 12, borderRadius: 12, background: '#fee2e2', color: '#991b1b', fontWeight: 700 },
  body: { display: 'flex', flex: 1, minHeight: 0, flexWrap: 'wrap' },
  side: {
    width: 'min(300px, 100%)', borderInlineEnd: '2px solid #f1f5f9', overflowY: 'auto', padding: 12,
    display: 'flex', flexDirection: 'column', gap: 6, maxHeight: '100%',
  },
  search: { padding: '9px 12px', borderRadius: 12, border: '2px solid #e5e7eb', marginBottom: 6, fontSize: 14 },
  student: { display: 'flex', alignItems: 'center', gap: 6, borderRadius: 14, padding: 4, border: '2px solid transparent' },
  studentActive: { background: '#eef2ff', borderColor: '#c7d2fe' },
  studentName: {
    flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 2, border: 'none',
    background: 'transparent', cursor: 'pointer', padding: '6px 8px', textAlign: 'right', fontSize: 14,
  },
  badge: { background: '#db2777', color: 'white', borderRadius: 999, minWidth: 22, height: 22, fontSize: 12, fontWeight: 800, display: 'flex', alignItems: 'center', justifyContent: 'center' },
  lockOne: { border: '2px solid #e5e7eb', background: 'white', borderRadius: 10, minWidth: 34, height: 34, padding: '0 8px', gap: 4, fontSize: 11, fontWeight: 800, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' },
  notice: { margin: '0 16px 8px', padding: '8px 12px', borderRadius: 10, background: '#ecfdf5', color: '#065f46', fontWeight: 700, fontSize: 13 },
  thread: { flex: 1, minWidth: 280, display: 'flex', flexDirection: 'column', minHeight: 0, maxHeight: '100%' },
  threadHead: { display: 'flex', gap: 10, alignItems: 'center', padding: '12px 16px', borderBottom: '2px solid #f1f5f9', flexWrap: 'wrap' },
  lockedTag: { background: '#fef3c7', color: '#92400e', borderRadius: 999, padding: '3px 10px', fontSize: 12, fontWeight: 800 },
  list: { flex: 1, padding: 16, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 10 },
  empty: { textAlign: 'center', color: '#6b7280', padding: 32, fontWeight: 700 },
  bubble: { borderRadius: 16, padding: 12, maxWidth: '78%' },
  mine: { alignSelf: 'flex-start', background: '#4338ca', color: 'white' },
  theirs: { alignSelf: 'flex-end', background: '#f8fafc', border: '2px solid #f1f5f9', color: '#111827' },
  cardHead: { display: 'flex', justifyContent: 'space-between', gap: 8, marginBottom: 6, flexWrap: 'wrap' },
  meta: { fontSize: 12, color: '#6b7280' },
  text: { lineHeight: 1.7, whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' },
  receipt: { fontSize: 11, marginTop: 6, opacity: 0.85 },
  media: {
    display: 'flex', alignItems: 'center', gap: 8, width: '100%', border: 'none', borderRadius: 12,
    padding: '10px 12px', cursor: 'pointer', fontWeight: 800, fontSize: 13, textAlign: 'right',
  },
  composer: { display: 'flex', gap: 8, padding: 12, borderTop: '2px solid #f1f5f9', alignItems: 'flex-end' },
  iconButton: { border: 'none', background: '#f1f5f9', borderRadius: 12, width: 42, height: 42, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 },
  input: { flex: 1, resize: 'vertical', minHeight: 42, maxHeight: 140, borderRadius: 12, border: '2px solid #e5e7eb', padding: '10px 12px', fontSize: 14, fontFamily: 'inherit' },
  send: { border: 'none', background: '#16a34a', color: 'white', borderRadius: 12, padding: '0 16px', height: 42, cursor: 'pointer', fontWeight: 800, display: 'flex', alignItems: 'center', gap: 6 },
  viewer: { position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', zIndex: 1001, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'zoom-out' },
};

export default StudentInbox;
