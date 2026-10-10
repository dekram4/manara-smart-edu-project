/**
 * طلباتُ لوحة المعلم والمشرف إلى الخادم بجلسة الكوكي نفسها.
 *
 * الخطأ يُرمى بنصّ الخادم إن أرسله، فتعرضه الشاشة كما كُتب بالعربية.
 */
export async function managementRequest<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const response = await fetch(path, {
    ...init,
    credentials: 'same-origin',
    headers: {
      Accept: 'application/json',
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...(init.headers as Record<string, string> | undefined),
    },
  });
  const raw = await response.text();
  let payload: unknown = null;
  try {
    payload = raw ? JSON.parse(raw) : null;
  } catch {
    payload = null;
  }
  if (!response.ok) {
    const fields = (payload && typeof payload === 'object' ? payload : {}) as { error?: unknown; detail?: unknown };
    const message = typeof fields.error === 'string'
      ? fields.error
      : `تعذر الاتصال بالخادم (${response.status})`;
    // السببُ التقنيّ سطراً ثانياً: بدونه يصل كلُّ فشلٍ بالجملة نفسها ولا يُعرف ما يُصلح.
    const detail = typeof fields.detail === 'string' && fields.detail.trim() ? fields.detail.trim() : '';
    throw new Error(detail ? `${message}\n${detail}` : message);
  }
  return payload as T;
}
