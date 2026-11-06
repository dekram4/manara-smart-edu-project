/**
 * منعُ تكرار الضغط على أزرار الحفظ في اللوحات — مرّةً واحدة لكل الصفحات.
 *
 * أزرارُ الحفظ والإضافة والحذف موزّعةٌ على عشرات الشاشات، بعضُها يحفظ في
 * المتصفّح وحده وبعضُها ينتظر الخادم، ولا يمنع أيٌّ منها ضغطةً ثانية قبل أن
 * تنتهي الأولى: فتُحفظ الشهادةُ مرّتين، ويُنشأ الطالبُ مرّتين.
 *
 * فالحارسُ يستمع على مستوى الصفحة قبل React (مرحلة الالتقاط):
 *   • أوّلُ ضغطةٍ على زرّ إجراءٍ تمرّ، ويُعلَّم الزرُّ «مشغولاً» (`is-busy`).
 *   • كلُّ طلبٍ إلى الخادم يبدأ أثناء ذلك يُنسب إليه، ولا يُفكّ الزرُّ قبل أن
 *     تنتهي طلباتُه كلُّها — أو بعد مهلةٍ قصيرة إن كان الحفظُ في المتصفّح وحده.
 *   • ما يأتي في الأثناء — نقرٌ أو Enter في النموذج — يُوقَف قبل أن يصل React.
 * والزرُّ لا يُعطَّل بـ `disabled` حتى لا تتعارض حالتُه مع ما يكتبه React.
 */

const ACTION_LABEL = /حفظ|إضافة|أضف|إصدار|إنشاء|انشاء|تحديث|رفع|نشر|اعتماد|تأكيد|حذف|توليد|إرسال|ارسال|تطبيق|تفعيل|تعطيل|استيراد|نقل|ربط|تصفير|تغيير|إعادة تعيين|موافقة|قبول|رفض|سحب|دفع|مزامنة/;
const SCOPE = '.portal-shell, .portal-dialog-backdrop, [role="dialog"]';
const MIN_BUSY_MS = 700;
const MAX_BUSY_MS = 20000;
/** طلبٌ يبدأ خلال هذه المدّة من الضغط يُنسب إلى الزرّ، ولو بعد `await`. */
const ATTACH_WINDOW_MS = 4000;

interface BusyAction {
  el: HTMLElement;
  startedAt: number;
  pending: number;
  minTimer: number;
  maxTimer: number;
  minElapsed: boolean;
  /** الضغطةُ التي أنشأت القفلَ على زرّ إرسالٍ يتبعها حدثُ `submit` واحد: يمرّ. */
  submitAllowed: boolean;
}

const busy = new Map<HTMLElement, BusyAction>();
let fetchPatched = false;

const release = (action: BusyAction) => {
  if (busy.get(action.el) !== action) return;
  busy.delete(action.el);
  window.clearTimeout(action.minTimer);
  window.clearTimeout(action.maxTimer);
  action.el.classList.remove('is-busy');
  action.el.removeAttribute('aria-busy');
};

const maybeRelease = (action: BusyAction) => {
  if (action.minElapsed && action.pending <= 0) release(action);
};

/** الأزرارُ التي تُحرس: إرسالُ نموذج، أو زرٌّ نصُّه/وصفُه إجراءُ حفظٍ أو تعديل. */
const actionButtonOf = (target: EventTarget | null): HTMLElement | null => {
  const el = (target as Element | null)?.closest?.('button, a[role="button"], input[type="submit"]') as HTMLElement | null;
  if (!el || !el.closest(SCOPE)) return null;
  if (el.closest('nav, .dashboard-sidebar, .portal-topbar, [role="tablist"]')) return null;
  if ((el as HTMLButtonElement).disabled) return null;
  if (el.dataset.noGuard !== undefined) return null;
  const isSubmit = (el as HTMLButtonElement).type === 'submit' && Boolean(el.closest('form'));
  const label = `${el.textContent || ''} ${el.getAttribute('aria-label') || ''} ${el.getAttribute('title') || ''}`;
  return isSubmit || ACTION_LABEL.test(label) ? el : null;
};

const patchFetch = () => {
  if (fetchPatched || typeof window.fetch !== 'function') return;
  fetchPatched = true;
  const original = window.fetch.bind(window);
  window.fetch = ((...args: Parameters<typeof fetch>) => {
    const now = Date.now();
    const owners = Array.from(busy.values()).filter((action) => now - action.startedAt <= ATTACH_WINDOW_MS);
    owners.forEach((action) => { action.pending += 1; });
    const done = () => owners.forEach((action) => {
      action.pending -= 1;
      maybeRelease(action);
    });
    const request = original(...args);
    request.then(done, done);
    return request;
  }) as typeof fetch;
};

const lock = (el: HTMLElement, submitAllowed = false) => {
  const action: BusyAction = {
    el,
    startedAt: Date.now(),
    pending: 0,
    minElapsed: false,
    submitAllowed,
    minTimer: 0,
    maxTimer: 0,
  };
  action.minTimer = window.setTimeout(() => {
    action.minElapsed = true;
    maybeRelease(action);
  }, MIN_BUSY_MS);
  action.maxTimer = window.setTimeout(() => release(action), MAX_BUSY_MS);
  busy.set(el, action);
  el.classList.add('is-busy');
  el.setAttribute('aria-busy', 'true');
};

const stop = (event: Event) => {
  event.preventDefault();
  event.stopPropagation();
  event.stopImmediatePropagation();
};

const onClick = (event: MouseEvent) => {
  const el = actionButtonOf(event.target);
  if (!el) return;
  if (busy.has(el)) {
    stop(event);
    return;
  }
  lock(el, true);
};

/** Enter في حقلٍ يرسل النموذج: يُوقَف إن كان زرُّ إرساله مشغولاً. */
const onSubmit = (event: Event) => {
  const form = event.target as HTMLFormElement | null;
  if (!form?.closest?.(SCOPE)) return;
  const submitter = (event as SubmitEvent).submitter as HTMLElement | null
    ?? (form.querySelector('button[type="submit"], input[type="submit"]') as HTMLElement | null);
  const action = submitter ? busy.get(submitter) : undefined;
  if (action) {
    if (action.submitAllowed) {
      action.submitAllowed = false;
      return;
    }
    stop(event);
    return;
  }
  if (submitter && !(submitter as HTMLButtonElement).disabled) lock(submitter);
};

let installs = 0;

/** يُركَّب مع قشرة اللوحات ويُفكّ معها. */
export function installActionGuard(): () => void {
  patchFetch();
  installs += 1;
  if (installs === 1) {
    document.addEventListener('click', onClick, true);
    document.addEventListener('submit', onSubmit, true);
  }
  return () => {
    installs -= 1;
    if (installs === 0) {
      document.removeEventListener('click', onClick, true);
      document.removeEventListener('submit', onSubmit, true);
      Array.from(busy.values()).forEach(release);
    }
  };
}
