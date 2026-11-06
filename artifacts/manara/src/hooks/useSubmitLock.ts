import { useCallback, useRef, useState } from 'react';

/**
 * قفلُ الإرسال: ضغطةٌ واحدة تمرّ، وما يتبعها حتى ينتهي الطلب يُتجاهَل.
 *
 * كانت صفحاتُ الدخول تتحقّق بـ `if (submitting) return` من حالةٍ لم تُرسم بعد،
 * فنقرتان متلاحقتان في الإطار نفسه تريان كلتاهما `false` فتُرسلان طلبين —
 * جلستين، وترحيبين. والقفلُ هنا في `useRef` يُقرأ ويُكتب فوراً، و`busy`
 * للرسم وحده: تعطيلُ الزرّ ومؤشّرُ التحميل.
 */
export function useSubmitLock() {
  const locked = useRef(false);
  const [busy, setBusy] = useState(false);

  const run = useCallback(async <T,>(task: () => Promise<T>): Promise<T | undefined> => {
    if (locked.current) return undefined;
    locked.current = true;
    setBusy(true);
    try {
      return await task();
    } finally {
      locked.current = false;
      setBusy(false);
    }
  }, []);

  return { busy, run };
}
