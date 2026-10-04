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
 * فالطباعةُ نفسُها لا تُكتب في المستند — بل يربطها writePrintDocument من هنا.
 */
const PRINT_SANITIZE_CONFIG = {
  WHOLE_DOCUMENT: true,
  ADD_TAGS: ['title', 'meta'],
  ADD_ATTR: ['charset'],
  FORBID_TAGS: ['script', 'iframe', 'object', 'embed', 'base', 'link'],
};

export interface PrintDocumentOptions {
  /** يطبع تلقائياً بعد هذه المهلة (ملّي ثانية) من كتابة المستند. */
  autoPrintDelayMs?: number;
}

/**
 * يكتب مستنداً كاملاً في نافذة الطباعة — ولا يقبل إلا ما بناه `html`.
 *
 * ثم يعقّمه بـ DOMPurify قبل الكتابة: طبقةٌ ثانيةٌ فوق تعقيم `html` للقيم، فلا يصل
 * إلى النافذة سكربتٌ ولا معالجُ أحداثٍ (`onclick`/`onerror`…) وإن تسرّب.
 *
 * ولأنّ التعقيم يُسقط السكربتات، فالطباعةُ تُربط من هنا: كلُّ عنصرٍ يحمل
 * `data-print-button` يطبع عند الضغط، و[autoPrintDelayMs] يطبع تلقائياً.
 * وDOMPurify يُسقط `<!DOCTYPE>` — فيُعاد إن كان في المستند، كي لا يتغيّر وضعُ العرض.
 */
export function writePrintDocument(
  target: Window,
  documentHtml: SafeHtml,
  options: PrintDocumentOptions = {},
): void {
  const source = documentHtml.value;
  const doctype = /^\s*<!DOCTYPE html>/i.test(source) ? '<!DOCTYPE html>' : '';
  const sanitized = DOMPurify.sanitize(source, PRINT_SANITIZE_CONFIG);
  target.document.open();
  target.document.write(doctype + sanitized);
  target.document.close();

  const print = () => {
    target.focus();
    target.print();
  };
  target.document.querySelectorAll('[data-print-button]').forEach((button) => {
    button.addEventListener('click', print);
  });
  if (options.autoPrintDelayMs !== undefined) {
    target.setTimeout(print, options.autoPrintDelayMs);
  }
}
