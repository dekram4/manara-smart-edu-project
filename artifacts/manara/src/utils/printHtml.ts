/**
 * HTML تقارير الطباعة — آمنٌ افتراضياً.
 *
 * ── لماذا وسمٌ لا تعقيمٌ يدوي عند كل قيمة ──
 * التقارير تدمج أسماءَ الطلاب والمعلمين وأولياء الأمور وبياناتٍ أخرى أدخلها
 * مستخدمون، ثم تكتبها في نافذةٍ جديدة. اسمٌ مثل `<img src=x onerror=…>` كان
 * سيُنفَّذ هناك. فكلُّ قيمةٍ تُدرج في `html\`…\`` تُعقَّم تلقائياً — ولا يمرّ
 * دون تعقيمٍ إلا ما بناه `html` نفسه (أجزاءُ التقرير المتداخلة). فقيمةٌ تُضاف
 * إلى تقريرٍ لاحقاً لا يُنسى تعقيمُها.
 */

import DOMPurify from 'dompurify';

const HTML_ESCAPES: Record<string, string> = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;',
  '`': '&#96;',
};

/** نصٌّ يُعرض كما هو — لا يُفسَّر وسوماً ولا سماتٍ. */
export function escapeHtml(value: unknown): string {
  if (value === null || value === undefined) return '';
  return String(value).replace(/[&<>"'`]/g, (ch) => HTML_ESCAPES[ch]);
}

/** جزءُ HTML بناه `html` — موثوقٌ لأنّ كلَّ قيمةٍ فيه عُقّمت. */
export class SafeHtml {
  constructor(readonly value: string) {}
  toString(): string {
    return this.value;
  }
}

export type HtmlValue = SafeHtml | readonly HtmlValue[] | string | number | boolean | null | undefined;

function render(value: HtmlValue): string {
  if (value instanceof SafeHtml) return value.value;
  if (Array.isArray(value)) return value.map(render).join('');
  if (value === false) return '';
  return escapeHtml(value);
}

/** قالبٌ يعقّم كلَّ ما يُدرج فيه؛ والقوائمُ تُضمّ عناصرُها بلا فاصل. */
export function html(strings: TemplateStringsArray, ...values: HtmlValue[]): SafeHtml {
  let out = strings[0];
  for (let i = 0; i < values.length; i++) {
    out += render(values[i]) + strings[i + 1];
  }
  return new SafeHtml(out);
}

/**
 * إعداداتُ تعقيم مستند الطباعة: مستندٌ كامل (head وstyle وtitle) بلا أيّ سكربت.
 * فالطباعةُ نفسُها لا تُكتب في المستند — بل يشغّلها printDocument من هنا.
 */
const PRINT_SANITIZE_CONFIG = {
  WHOLE_DOCUMENT: true,
  ADD_TAGS: ['title', 'meta'],
  ADD_ATTR: ['charset'],
  FORBID_TAGS: ['script', 'iframe', 'object', 'embed', 'base', 'link'],
};

export interface PrintDocumentOptions {
  /** يطبع بعد هذه المهلة (ملّي ثانية) من تحميل المستند؛ وإلا فور التحميل. */
  autoPrintDelayMs?: number;
}

/**
 * أطولُ بقاءٍ لإطار الطباعة إن لم يصل حدثُ انتهاء الطباعة (afterprint) — فبعضُ
 * متصفّحات الهاتف لا ترسله. والإطارُ مخفيٌّ، فبقاؤه هذه المدّة لا يضرّ.
 */
const PRINT_FRAME_LIFETIME_MS = 5 * 60_000;

/**
 * يطبع مستنداً كاملاً — ولا يقبل إلا ما بناه `html`.
 *
 * يُعقَّم المستند بـ DOMPurify (طبقةٌ ثانيةٌ فوق تعقيم `html` للقيم: لا سكربتَ ولا
 * معالجَ أحداث)، ثم يوضع في إطارٍ مخفيٍّ في الصفحة نفسها عبر `srcdoc` — لا نافذةَ
 * تُفتح ولا انتقالَ إلى رابط. وبعد تحميله يُطبع الإطارُ نفسه، ثم يُزال.
 *
 * والإطارُ معزولٌ (`sandbox`): لا يجري فيه أيُّ سكربت؛ و`allow-modals` ليُسمح بنافذة
 * الطباعة، و`allow-same-origin` لتصل إليه الصفحةُ فتطبعه.
 * وDOMPurify يُسقط `<!DOCTYPE>` — فيُعاد إن كان في المستند، كي لا يتغيّر وضعُ العرض.
 */
export function printDocument(
  documentHtml: SafeHtml,
  options: PrintDocumentOptions = {},
): void {
  const source = documentHtml.value;
  const doctype = /^\s*<!DOCTYPE html>/i.test(source) ? '<!DOCTYPE html>' : '';
  const sanitized = DOMPurify.sanitize(source, PRINT_SANITIZE_CONFIG);

  const frame = document.createElement('iframe');
  frame.setAttribute('sandbox', 'allow-same-origin allow-modals');
  frame.setAttribute('aria-hidden', 'true');
  frame.tabIndex = -1;
  Object.assign(frame.style, {
    position: 'fixed',
    right: '0',
    bottom: '0',
    width: '0',
    height: '0',
    border: '0',
    opacity: '0',
    pointerEvents: 'none',
  });

  let removed = false;
  const remove = () => {
    if (removed) return;
    removed = true;
    frame.remove();
  };

  frame.addEventListener('load', () => {
    const view = frame.contentWindow;
    if (!view) {
      remove();
      return;
    }
    view.addEventListener('afterprint', () => window.setTimeout(remove, 0), { once: true });
    window.setTimeout(() => {
      view.focus();
      view.print();
    }, options.autoPrintDelayMs ?? 0);
    window.setTimeout(remove, PRINT_FRAME_LIFETIME_MS);
  }, { once: true });

  frame.srcdoc = doctype + sanitized;
  document.body.appendChild(frame);
}
