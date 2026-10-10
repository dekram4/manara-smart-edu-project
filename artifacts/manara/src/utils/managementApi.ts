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
    const message =
      payload && typeof payload === 'object' && typeof (payload as { error?: unknown }).error === 'string'
        ? (payload as { error: string }).error
        : `تعذر الاتصال بالخادم (${response.status})`;
    throw new Error(message);
  }
  return payload as T;
}
