import { hashPassword, isHashed } from '../utils/password';
import { STORAGE_KEYS } from '../constants';

// ============================================================
// ترقية كلمات المرور القديمة (نص صريح) إلى صيغة مجزّأة، لمرة واحدة.
// تُستدعى بعد المزامنة الأولى، فتُحفظ النتائج محلياً وتُزامَن إلى Supabase.
// تتجاهل أي قيمة مجزّأة مسبقاً، فلا ضرر من تكرار التشغيل.
// ============================================================

function migrateUserArray(key: string): void {
  const raw = localStorage.getItem(key);
  if (!raw) return;
  let arr: any;
  try {
    arr = JSON.parse(raw);
  } catch {
    return;
  }
  if (!Array.isArray(arr)) return;

  let changed = false;
  for (const user of arr) {
    if (user && typeof user.password === 'string' && user.password && !isHashed(user.password)) {
      user.password = hashPassword(user.password);
      changed = true;
    }
  }
  if (changed) localStorage.setItem(key, JSON.stringify(arr));
}

function migrateAdminSettings(): void {
  const raw = localStorage.getItem(STORAGE_KEYS.ADMIN_SETTINGS);
  if (!raw) return;
  let settings: any;
  try {
    settings = JSON.parse(raw);
  } catch {
    return;
  }
  if (
    settings &&
    typeof settings.adminPassword === 'string' &&
    settings.adminPassword &&
    !isHashed(settings.adminPassword)
  ) {
    settings.adminPassword = hashPassword(settings.adminPassword);
    localStorage.setItem(STORAGE_KEYS.ADMIN_SETTINGS, JSON.stringify(settings));
  }
}

export function migratePasswordsToHash(): void {
  migrateUserArray(STORAGE_KEYS.STUDENTS);
  migrateUserArray(STORAGE_KEYS.PARENTS);
  migrateUserArray(STORAGE_KEYS.TEACHERS);
  migrateAdminSettings();
}
