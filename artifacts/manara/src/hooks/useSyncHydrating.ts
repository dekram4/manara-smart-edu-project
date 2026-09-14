import { useEffect, useState } from 'react';
import { getSyncStatus, onSyncStatus } from '../db/sync';

/**
 * هل ما يزال التحميل الأول من Supabase جارياً؟
 *
 * الشاشات تقرأ الشجرة الأكاديمية من التخزين المحلي قراءةً متزامنة. فإن
 * فُتحت الشاشة قبل اكتمال التحميل كانت القراءة فارغة، فتعرض القائمة
 * «لا توجد دروس معرّفة» — وهي رسالة خاطئة تدفع المعلّم إلى إضافة دروس
 * موجودة فعلاً. هذه الراية تُفرّق بين «لا دروس» و«لم تصل بعد».
 */
export function useSyncHydrating(): boolean {
  const [hydrating, setHydrating] = useState(() => getSyncStatus().hydrating);
  useEffect(() => onSyncStatus(status => setHydrating(status.hydrating)), []);
  return hydrating;
}
