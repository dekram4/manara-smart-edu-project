import { managementRequest } from './managementApi';

/**
 * رابطُ تحميل تطبيق الطالب (APK) — يُحفظ في الخادم (`app_kv`) لا في
 * المتصفّح، فرابطٌ يضعه المشرف يراه كلُّ زائرٍ لشاشة الأدوار.
 */
export interface StudentApkSetting {
  url: string;
  updatedAt: string;
  /** الرابطُ المؤقّت، لم يضع المشرف رابطه بعد. */
  isDefault: boolean;
}

const ENDPOINT = '/api/app-settings/student-apk';

export function fetchStudentApk(): Promise<StudentApkSetting> {
  return managementRequest<StudentApkSetting>(ENDPOINT);
}

export function saveStudentApk(url: string): Promise<StudentApkSetting> {
  return managementRequest<StudentApkSetting>(ENDPOINT, {
    method: 'PUT',
    body: JSON.stringify({ url }),
  });
}

/**
 * يقبل `https://` وحده — الخادمُ يرفض غيره كذلك. والتحقّقُ هنا ليرى المشرف
 * الخطأ قبل أن يضغط «حفظ»، لا ليحلّ محلّ تحقّق الخادم.
 */
export function isAcceptableApkUrl(value: string): boolean {
  try {
    const url = new URL(value.trim());
    return url.protocol === 'https:';
  } catch {
    return false;
  }
}
