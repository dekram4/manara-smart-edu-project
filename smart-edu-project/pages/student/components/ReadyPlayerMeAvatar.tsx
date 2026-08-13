import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  StudentAppearance,
} from '../../../types';
import {
  STUDENT_BOTTOM_OPTIONS,
  STUDENT_COLOR_OPTIONS,
  STUDENT_HAIR_COLOR_OPTIONS,
  STUDENT_SHOES_OPTIONS,
  STUDENT_SKIN_OPTIONS,
  STUDENT_TOP_OPTIONS,
} from '../../../utils/studentAppearance';

const READY_PLAYER_ME_CREATOR_URL = (
  import.meta as ImportMeta & { env?: Record<string, string | undefined> }
).env?.VITE_READY_PLAYER_ME_CREATOR_URL?.trim() || '';

const getCreatorOrigin = (value: string) => {
  try {
    return new URL(value).origin;
  } catch {
    return '';
  }
};

const READY_PLAYER_ME_ORIGIN = getCreatorOrigin(READY_PLAYER_ME_CREATOR_URL);

const withFrameApi = (value: string) => {
  try {
    const url = new URL(value);
    url.searchParams.set('frameApi', '');
    url.searchParams.set('source', 'manara');
    return url.toString();
  } catch {
    return value;
  }
};

const postReadyPlayerMeMessage = (
  frame: HTMLIFrameElement | null,
  message: Record<string, unknown>,
) => {
  if (!frame || !READY_PLAYER_ME_ORIGIN) return;
  frame.contentWindow?.postMessage(JSON.stringify(message), READY_PLAYER_ME_ORIGIN);
};

const getAvatarId = (url: string, explicitId?: string) => {
  if (explicitId) return explicitId;
  const match = url.match(/models\.readyplayer\.me\/([^/?#]+)\.glb/i);
  return match?.[1] || '';
};

export type ReadyPlayerMeExport = Pick<
  StudentAppearance,
  'readyPlayerMeAvatarUrl' | 'readyPlayerMeAvatarId' | 'readyPlayerMeAvatarImageUrl'
>;

interface LocalAvatarBuilderProps {
  initialAppearance: StudentAppearance;
  onSave: (appearance: StudentAppearance) => void;
}

const LOCAL_TOP_COLORS = ['#38bdf8', '#f97316', '#facc15', '#f8fafc', '#bfdbfe', '#64748b', '#f1f5f9', '#7c3aed'];
const LOCAL_BOTTOM_COLORS = ['#2563eb', '#14b8a6', '#e2e8f0', '#f472b6', '#94a3b8', '#a16207'];
const LOCAL_SHOE_COLORS = ['#f8fafc', '#92400e', '#111827', '#ec4899', '#67e8f9', '#fbbf24'];

const getOptionIndex = (value: string | undefined, options: readonly { value: string }[]) => {
  const index = options.findIndex(option => option.value === value);
  return index >= 0 ? index : 0;
};

const LocalAvatarPreview: React.FC<{ appearance: StudentAppearance }> = ({ appearance }) => {
  const skin = appearance.skinTone || '#edb891';
  const hair = appearance.hairColor || '#3f2b24';
  const shirt = appearance.color || '#38bdf8';
  const topIndex = getOptionIndex(appearance.top, STUDENT_TOP_OPTIONS);
  const bottomIndex = getOptionIndex(appearance.bottom, STUDENT_BOTTOM_OPTIONS);
  const shoeIndex = getOptionIndex(appearance.shoes, STUDENT_SHOES_OPTIONS);

  return (
    <div className="relative flex min-h-[330px] items-center justify-center overflow-hidden rounded-[26px] border border-cyan-300/20 bg-[radial-gradient(circle_at_50%_20%,rgba(34,211,238,0.25),transparent_34%),linear-gradient(180deg,#102a43,#081426)] p-4">
      <div className="absolute inset-x-8 bottom-5 h-12 rounded-full bg-cyan-300/15 blur-2xl" />
      <svg viewBox="0 0 180 300" className="relative z-10 h-[300px] w-full max-w-[220px]" role="img" aria-label="معاينة شخصية الطالب كاملة">
        <defs>
          <linearGradient id="localAvatarShirt" x1="0" x2="1">
            <stop offset="0" stopColor={shirt} />
            <stop offset="1" stopColor="#172554" stopOpacity="0.85" />
          </linearGradient>
          <linearGradient id="localAvatarPants" x1="0" x2="1">
            <stop offset="0" stopColor={LOCAL_BOTTOM_COLORS[bottomIndex]} />
            <stop offset="1" stopColor="#0f172a" />
          </linearGradient>
        </defs>
        <ellipse cx="90" cy="285" rx="54" ry="9" fill="#020617" opacity="0.7" />
        <path d="M57 210h66l11 62H46z" fill="url(#localAvatarPants)" stroke="#cbd5e1" strokeOpacity="0.18" strokeWidth="2" />
        <path d="M52 266h31l-3 15H43c-4 0-5-5-2-8zM97 266h31l8 7c3 3 1 8-4 8H98z" fill={LOCAL_SHOE_COLORS[shoeIndex]} stroke="#e2e8f0" strokeOpacity="0.3" strokeWidth="2" />
        <path d="M49 130c8-12 23-19 41-19s33 7 41 19l-4 82H53z" fill="url(#localAvatarShirt)" stroke="#e0f2fe" strokeOpacity="0.25" strokeWidth="2" />
        <path d="M49 143l-18 48 15 7 19-39zM131 143l18 48-15 7-19-39z" fill={shirt} stroke="#e0f2fe" strokeOpacity="0.25" strokeWidth="2" />
        <circle cx="90" cy="78" r="43" fill={skin} stroke="#f8fafc" strokeOpacity="0.28" strokeWidth="2" />
        <path d="M48 76c0-37 16-53 42-53s42 16 42 53c-9-13-19-19-30-19-15 0-29 10-54 19z" fill={hair} />
        <path d="M56 66c6-26 21-36 35-36 20 0 31 12 35 35-13-8-24-12-35-12-13 0-23 5-35 13z" fill={hair} opacity="0.92" />
        <circle cx="74" cy="82" r="4" fill="#0f172a" />
        <circle cx="106" cy="82" r="4" fill="#0f172a" />
        <path d="M78 101c8 6 16 6 24 0" fill="none" stroke="#7f1d1d" strokeLinecap="round" strokeWidth="3" />
        <path d="M75 132h30v17H75z" fill={skin} />
        <path d="M76 153h28v10H76z" fill="#f8fafc" opacity="0.7" />
        <circle cx="90" cy="177" r="8" fill="#f8fafc" opacity="0.22" />
      </svg>
      <span className="absolute bottom-3 rounded-full border border-white/15 bg-slate-950/65 px-3 py-1 text-[10px] font-black text-cyan-100">
        معاينة كاملة
      </span>
    </div>
  );
};

const safeAvatarColor = (value: string | undefined, fallback: string) =>
  value && /^#[0-9a-f]{6}$/i.test(value) ? value : fallback;

const createLocalAvatarImageUrl = (appearance: StudentAppearance) => {
  const skin = safeAvatarColor(appearance.skinTone, '#edb891');
  const hair = safeAvatarColor(appearance.hairColor, '#3f2b24');
  const shirt = safeAvatarColor(appearance.color, '#38bdf8');
  const bottomIndex = getOptionIndex(appearance.bottom, STUDENT_BOTTOM_OPTIONS);
  const shoeIndex = getOptionIndex(appearance.shoes, STUDENT_SHOES_OPTIONS);
  const pants = LOCAL_BOTTOM_COLORS[bottomIndex] || LOCAL_BOTTOM_COLORS[0];
  const shoes = LOCAL_SHOE_COLORS[shoeIndex] || LOCAL_SHOE_COLORS[0];

  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 300">
      <defs>
        <linearGradient id="shirt" x1="0" x2="1">
          <stop offset="0" stop-color="${shirt}"/>
          <stop offset="1" stop-color="#172554"/>
        </linearGradient>
        <linearGradient id="pants" x1="0" x2="1">
          <stop offset="0" stop-color="${pants}"/>
          <stop offset="1" stop-color="#0f172a"/>
        </linearGradient>
      </defs>
      <rect width="180" height="300" rx="28" fill="#081426"/>
      <ellipse cx="90" cy="285" rx="54" ry="9" fill="#020617" opacity=".7"/>
      <path d="M57 210h66l11 62H46z" fill="url(#pants)" stroke="#cbd5e1" stroke-opacity=".18" stroke-width="2"/>
      <path d="M52 266h31l-3 15H43c-4 0-5-5-2-8zM97 266h31l8 7c3 3 1 8-4 8H98z" fill="${shoes}" stroke="#e2e8f0" stroke-opacity=".3" stroke-width="2"/>
      <path d="M49 130c8-12 23-19 41-19s33 7 41 19l-4 82H53z" fill="url(#shirt)" stroke="#e0f2fe" stroke-opacity=".25" stroke-width="2"/>
      <path d="M49 143l-18 48 15 7 19-39zM131 143l18 48-15 7-19-39z" fill="${shirt}" stroke="#e0f2fe" stroke-opacity=".25" stroke-width="2"/>
      <circle cx="90" cy="78" r="43" fill="${skin}" stroke="#f8fafc" stroke-opacity=".28" stroke-width="2"/>
      <path d="M48 76c0-37 16-53 42-53s42 16 42 53c-9-13-19-19-30-19-15 0-29 10-54 19z" fill="${hair}"/>
      <path d="M56 66c6-26 21-36 35-36 20 0 31 12 35 35-13-8-24-12-35-12-13 0-23 5-35 13z" fill="${hair}" opacity=".92"/>
      <circle cx="74" cy="82" r="4" fill="#0f172a"/>
      <circle cx="106" cy="82" r="4" fill="#0f172a"/>
      <path d="M78 101c8 6 16 6 24 0" fill="none" stroke="#7f1d1d" stroke-linecap="round" stroke-width="3"/>
      <path d="M75 132h30v17H75z" fill="${skin}"/>
    </svg>
  `;

  return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`;
};

const LocalAvatarBuilder: React.FC<LocalAvatarBuilderProps> = ({ initialAppearance, onSave }) => {
  const [draft, setDraft] = useState<StudentAppearance>(initialAppearance);
  const update = (patch: Partial<StudentAppearance>) => setDraft(current => ({ ...current, ...patch }));

  const save = () => {
    const savedAppearance = {
      ...draft,
      readyPlayerMeAvatarUrl: 'local:manara-avatar',
      readyPlayerMeAvatarId: 'local-manara-avatar',
    } satisfies StudentAppearance;
    onSave({
      ...savedAppearance,
      readyPlayerMeAvatarImageUrl: createLocalAvatarImageUrl(savedAppearance),
    });
  };

  return (
    <div className="rounded-[26px] border border-cyan-300/25 bg-slate-950 p-3 shadow-2xl sm:p-4">
      <div className="mb-3 flex flex-col gap-2 border-b border-white/10 pb-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-sm font-black text-white">مصمم الأفاتار المحلي</p>
          <p className="mt-1 text-[11px] font-bold leading-5 text-slate-400">
            المحرر يعمل مباشرة على الجوال والتابلت ويحفظ الشخصية كاملة بدون رابط خارجي.
          </p>
        </div>
        <span className="inline-flex w-fit items-center gap-2 rounded-full bg-emerald-400/15 px-3 py-1 text-[10px] font-black text-emerald-200">
          <span className="h-2 w-2 rounded-full bg-emerald-300" />
          يعمل الآن
        </span>
      </div>

      <LocalAvatarPreview appearance={draft} />

      <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
        <label className="text-xs font-black text-cyan-100">
          لون البشرة
          <select
            value={draft.skinTone || ''}
            onChange={event => update({ skinTone: event.target.value })}
            className="mt-1 w-full rounded-xl border border-white/10 bg-slate-900 px-3 py-3 text-sm font-bold text-white outline-none focus:border-cyan-300"
          >
            {STUDENT_SKIN_OPTIONS.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
          </select>
        </label>
        <label className="text-xs font-black text-cyan-100">
          لون الشعر
          <select
            value={draft.hairColor || ''}
            onChange={event => update({ hairColor: event.target.value })}
            className="mt-1 w-full rounded-xl border border-white/10 bg-slate-900 px-3 py-3 text-sm font-bold text-white outline-none focus:border-cyan-300"
          >
            {STUDENT_HAIR_COLOR_OPTIONS.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
          </select>
        </label>
        <label className="text-xs font-black text-cyan-100">
          اللون العلوي
          <select
            value={draft.color || ''}
            onChange={event => update({ color: event.target.value })}
            className="mt-1 w-full rounded-xl border border-white/10 bg-slate-900 px-3 py-3 text-sm font-bold text-white outline-none focus:border-cyan-300"
          >
            {STUDENT_COLOR_OPTIONS.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
          </select>
        </label>
        <label className="text-xs font-black text-cyan-100">
          نوع العلوي
          <select
            value={draft.top || ''}
            onChange={event => update({ top: event.target.value })}
            className="mt-1 w-full rounded-xl border border-white/10 bg-slate-900 px-3 py-3 text-sm font-bold text-white outline-none focus:border-cyan-300"
          >
            {STUDENT_TOP_OPTIONS.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
          </select>
        </label>
        <label className="text-xs font-black text-cyan-100">
          البنطال
          <select
            value={draft.bottom || ''}
            onChange={event => update({ bottom: event.target.value })}
            className="mt-1 w-full rounded-xl border border-white/10 bg-slate-900 px-3 py-3 text-sm font-bold text-white outline-none focus:border-cyan-300"
          >
            {STUDENT_BOTTOM_OPTIONS.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
          </select>
        </label>
        <label className="text-xs font-black text-cyan-100">
          الأحذية
          <select
            value={draft.shoes || ''}
            onChange={event => update({ shoes: event.target.value })}
            className="mt-1 w-full rounded-xl border border-white/10 bg-slate-900 px-3 py-3 text-sm font-bold text-white outline-none focus:border-cyan-300"
          >
            {STUDENT_SHOES_OPTIONS.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
          </select>
        </label>
      </div>

      <button
        type="button"
        onClick={save}
        className="mt-4 w-full rounded-2xl bg-gradient-to-r from-cyan-300 to-indigo-400 px-5 py-3.5 text-sm font-black text-slate-950 shadow-lg shadow-cyan-400/20 transition hover:brightness-110 active:scale-[0.99]"
      >
        حفظ الشخصية في ملفي
      </button>
    </div>
  );
};

interface ReadyPlayerMeCreatorProps {
  initialAppearance: StudentAppearance;
  onExport: (avatar: ReadyPlayerMeExport) => void;
  onLocalSave: (appearance: StudentAppearance) => void;
}

export const ReadyPlayerMeCreator: React.FC<ReadyPlayerMeCreatorProps> = ({
  initialAppearance,
  onExport,
  onLocalSave,
}) => {
  const frameRef = useRef<HTMLIFrameElement | null>(null);
  const [frameReady, setFrameReady] = useState(false);
  const [lastExported, setLastExported] = useState(false);
  const [iframeFailed, setIframeFailed] = useState(false);
  const [timedOut, setTimedOut] = useState(false);
  const canUseRemoteCreator = Boolean(READY_PLAYER_ME_CREATOR_URL && READY_PLAYER_ME_ORIGIN);

  useEffect(() => {
    if (!canUseRemoteCreator) return undefined;
    const handleMessage = (event: MessageEvent) => {
      if (event.origin !== READY_PLAYER_ME_ORIGIN) return;

      let payload = event.data;
      if (typeof payload === 'string') {
        try {
          payload = JSON.parse(payload);
        } catch {
          return;
        }
      }

      if (!payload || payload.source !== 'readyplayerme') return;

      if (payload.eventName === 'v1.frame.ready') {
        setFrameReady(true);
        postReadyPlayerMeMessage(frameRef.current, {
          target: 'readyplayerme',
          type: 'subscribe',
          eventName: 'v1.avatar.exported',
        });
        return;
      }

      if (payload.eventName === 'v1.avatar.exported' && payload.data?.url) {
        const url = String(payload.data.url);
        const avatarId = getAvatarId(url, payload.data.avatarId ? String(payload.data.avatarId) : undefined);
        const imageUrl = avatarId
          ? `https://models.readyplayer.me/${avatarId}.png`
          : url.replace(/\.glb(\?.*)?$/i, '.png$1');

        setLastExported(true);
        onExport({
          readyPlayerMeAvatarUrl: url,
          readyPlayerMeAvatarId: avatarId || undefined,
          readyPlayerMeAvatarImageUrl: imageUrl,
        });
      }
    };

    window.addEventListener('message', handleMessage);
    const timeoutId = window.setTimeout(() => {
      if (!frameReady) setTimedOut(true);
    }, 7000);
    return () => {
      window.clearTimeout(timeoutId);
      window.removeEventListener('message', handleMessage);
    };
  }, [canUseRemoteCreator, frameReady, onExport]);

  if (!canUseRemoteCreator || iframeFailed || timedOut) {
    return (
      <div>
        {!canUseRemoteCreator && (
          <div className="mb-3 rounded-2xl border border-amber-300/25 bg-amber-400/10 px-4 py-3 text-xs font-bold leading-6 text-amber-100">
            محرر Ready Player Me يحتاج Application Subdomain صالحًا. تم تشغيل المحرر المحلي تلقائيًا حتى تستطيع حفظ الشخصية الآن.
          </div>
        )}
        {canUseRemoteCreator && (
          <div className="mb-3 rounded-2xl border border-amber-300/25 bg-amber-400/10 px-4 py-3 text-xs font-bold leading-6 text-amber-100">
            تعذر تحميل المحرر الخارجي. استخدم المصمم المحلي الآن، أو تحقق من رابط Ready Player Me في إعدادات البيئة.
          </div>
        )}
        <LocalAvatarBuilder initialAppearance={initialAppearance} onSave={onLocalSave} />
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-[26px] border border-cyan-300/25 bg-slate-950 shadow-2xl">
      <div className="flex flex-col gap-2 border-b border-white/10 bg-slate-900/80 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-sm font-black text-white">مصمم الأفاتار ثلاثي الأبعاد</p>
          <p className="mt-1 text-[11px] font-bold text-slate-400">صمّم الشخصية كاملة ثم اضغط Save داخل المحرر</p>
        </div>
        <span className={`inline-flex w-fit items-center gap-2 rounded-full px-3 py-1 text-[10px] font-black ${
          lastExported
            ? 'bg-emerald-400/15 text-emerald-200'
            : frameReady
              ? 'bg-cyan-400/15 text-cyan-200'
              : 'bg-amber-400/15 text-amber-200'
        }`}>
          <span className={`h-2 w-2 rounded-full ${lastExported ? 'bg-emerald-300' : frameReady ? 'bg-cyan-300' : 'bg-amber-300'}`} />
          {lastExported ? 'تم حفظ الأفاتار' : frameReady ? 'المحرر جاهز' : 'جاري تجهيز المحرر'}
        </span>
      </div>
      <iframe
        ref={frameRef}
        title="Ready Player Me Avatar Creator"
        src={withFrameApi(READY_PLAYER_ME_CREATOR_URL)}
        allow="camera *; microphone *; autoplay *"
        onError={() => setIframeFailed(true)}
        className="h-[600px] min-h-[70vh] w-full border-0 bg-slate-950 sm:h-[680px] md:h-[720px]"
      />
    </div>
  );
};

interface ReadyPlayerMeViewerProps {
  url?: string;
  imageUrl?: string;
}

export const ReadyPlayerMeViewer: React.FC<ReadyPlayerMeViewerProps> = ({ url, imageUrl }) => (
  <div className="overflow-hidden rounded-[26px] border border-cyan-300/25 bg-slate-950 shadow-2xl">
    {imageUrl ? (
      <div className="flex min-h-[360px] items-center justify-center bg-slate-950 p-4">
        <img src={imageUrl} alt="الأفاتار المحفوظ" className="h-full max-h-[440px] w-full object-contain" />
      </div>
    ) : url ? (
      <div className="flex min-h-[360px] items-center justify-center px-6 text-center text-sm font-black text-slate-300">
        تم حفظ رابط الأفاتار، وستظهر الصورة بعد توفر معاينة الأفاتار.
      </div>
    ) : (
      <div className="flex min-h-[360px] items-center justify-center rounded-[26px] border border-dashed border-white/15 bg-slate-950/50 px-6 text-center">
        <div>
          <div className="mx-auto mb-4 h-24 w-16 rounded-[45%] border-2 border-cyan-300/50 bg-gradient-to-b from-cyan-300/20 to-indigo-500/20" />
          <p className="text-sm font-black text-slate-300">سيظهر الأفاتار هنا بعد الحفظ</p>
        </div>
      </div>
    )}
    {url && (
      <div className="border-t border-white/10 bg-slate-900/80 px-3 py-2 text-center text-[10px] font-black text-cyan-100">
        الأفاتار محفوظ في ملف الطالب
      </div>
    )}
  </div>
);