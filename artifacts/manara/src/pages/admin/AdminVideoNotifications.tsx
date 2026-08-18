import React, { useState, useEffect } from 'react';
import { STORAGE_KEYS } from '../../constants';

interface VideoNotification {
  id: string;
  type: string;
  message: string;
  teacherId: string;
  teacherName: string;
  videoId: string;
  videoTitle?: string;
  grade?: string;
  atram?: string;
  subject?: string;
  term?: string;
  unit?: string;
  createdAt: string;
  read: boolean;
}

const AdminVideoNotifications: React.FC = () => {
  const [notifications, setNotifications] = useState<VideoNotification[]>([]);
  const [filters, setFilters] = useState({ grade: '', atram: '', subject: '', term: '', unit: '' });

  useEffect(() => {
    loadNotifications();
    const interval = setInterval(loadNotifications, 5000);
    return () => clearInterval(interval);
  }, []);

  const loadNotifications = () => {
    const saved = localStorage.getItem(STORAGE_KEYS.VIDEO_NOTIFICATIONS);
    if (saved) {
      const all: VideoNotification[] = JSON.parse(saved);
      setNotifications(all.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()));
    }
  };

  const markAsRead = (id: string) => {
    const saved = localStorage.getItem(STORAGE_KEYS.VIDEO_NOTIFICATIONS);
    if (!saved) return;
    const all: VideoNotification[] = JSON.parse(saved);
    const updated = all.map(n => n.id === id ? { ...n, read: true } : n);
    localStorage.setItem(STORAGE_KEYS.VIDEO_NOTIFICATIONS, JSON.stringify(updated));
    setNotifications(updated.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()));
  };

  const clearAll = () => {
    if (!confirm('هل أنت متأكد من حذف كل الإشعارات؟')) return;
    localStorage.setItem(STORAGE_KEYS.VIDEO_NOTIFICATIONS, '[]');
    setNotifications([]);
  };

  const unreadCount = notifications.filter(n => !n.read).length;

  const filteredNotifications = notifications.filter((n) => {
    if (filters.grade && n.grade !== filters.grade) return false;
    if (filters.atram && n.atram !== filters.atram) return false;
    if (filters.subject && n.subject !== filters.subject) return false;
    if (filters.term && n.term !== filters.term) return false;
    if (filters.unit && n.unit !== filters.unit) return false;
    return true;
  });

  const filterOptions = {
    grades: Array.from(new Set(notifications.map((n) => n.grade).filter(Boolean))) as string[],
    atrams: Array.from(new Set(notifications.map((n) => n.atram).filter(Boolean))) as string[],
    subjects: Array.from(new Set(notifications.map((n) => n.subject).filter(Boolean))) as string[],
    terms: Array.from(new Set(notifications.map((n) => n.term).filter(Boolean))) as string[],
    units: Array.from(new Set(notifications.map((n) => n.unit).filter(Boolean))) as string[],
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <h2 className="text-3xl font-black text-purple-800">📢 إشعارات الفيديوهات</h2>
          {unreadCount > 0 && (
            <span className="px-3 py-1 bg-red-500 text-white rounded-full text-sm font-bold animate-pulse">
              {unreadCount} جديدة
            </span>
          )}
        </div>
        {notifications.length > 0 && (
          <button
            onClick={clearAll}
            className="px-4 py-2 bg-red-100 text-red-600 rounded-xl font-bold hover:bg-red-200 transition-all text-sm"
          >
            🗑️ حذف الكل
          </button>
        )}
      </div>

      <div className="rounded-2xl border border-purple-200 bg-purple-50 p-4">
        <div className="mb-3 flex items-center justify-between">
          <h3 className="text-lg font-black text-purple-800">🔎 فلترة إشعارات الفيديو</h3>
          <button
            onClick={() => setFilters({ grade: '', atram: '', subject: '', term: '', unit: '' })}
            className="rounded-lg bg-white px-3 py-1 text-xs font-bold text-purple-700 hover:bg-purple-100"
          >
            مسح الفلاتر
          </button>
        </div>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <select value={filters.grade} onChange={(e) => setFilters({ ...filters, grade: e.target.value })} className="rounded-xl border border-purple-200 bg-white p-3 font-bold text-purple-900">
            <option value="">🎓 كل الصفوف</option>
            {filterOptions.grades.map((grade) => <option key={grade} value={grade}>{grade}</option>)}
          </select>
          <select value={filters.atram} onChange={(e) => setFilters({ ...filters, atram: e.target.value })} className="rounded-xl border border-purple-200 bg-white p-3 font-bold text-purple-900">
            <option value="">📅 كل الأترام</option>
            {filterOptions.atrams.map((atram) => <option key={atram} value={atram}>{atram}</option>)}
          </select>
          <select value={filters.subject} onChange={(e) => setFilters({ ...filters, subject: e.target.value })} className="rounded-xl border border-purple-200 bg-white p-3 font-bold text-purple-900">
            <option value="">📖 كل المواد</option>
            {filterOptions.subjects.map((subject) => <option key={subject} value={subject}>{subject}</option>)}
          </select>
          <select value={filters.term} onChange={(e) => setFilters({ ...filters, term: e.target.value })} className="rounded-xl border border-purple-200 bg-white p-3 font-bold text-purple-900">
            <option value="">📑 كل الفصول</option>
            {filterOptions.terms.map((term) => <option key={term} value={term}>{term}</option>)}
          </select>
          <select value={filters.unit} onChange={(e) => setFilters({ ...filters, unit: e.target.value })} className="rounded-xl border border-purple-200 bg-white p-3 font-bold text-purple-900">
            <option value="">📦 كل الوحدات</option>
            {filterOptions.units.map((unit) => <option key={unit} value={unit}>{unit}</option>)}
          </select>
        </div>
      </div>

      <div className="space-y-4">
        {filteredNotifications.map((n) => (
          <div
            key={n.id}
            className={`p-6 rounded-2xl border-2 transition-all ${
              n.read
                ? 'bg-white border-purple-100'
                : 'bg-purple-50 border-purple-300 shadow-md'
            }`}
          >
            <div className="flex items-start justify-between gap-4">
              <div className="flex-1">
                <p className={`text-lg font-bold ${n.read ? 'text-purple-800' : 'text-purple-900'}`}>
                  {n.message}
                </p>
                <div className="flex items-center gap-4 mt-3 text-sm text-purple-500 font-medium">
                  <span>👨‍🏫 {n.teacherName}</span>
                  {n.grade && <span>🎓 {n.grade}</span>}
                  {n.atram && <span>📅 {n.atram}</span>}
                  {n.subject && <span>📖 {n.subject}</span>}
                  {n.term && <span>📑 {n.term}</span>}
                  {n.unit && <span>📦 {n.unit}</span>}
                  <span>🕒 {new Date(n.createdAt).toLocaleString('ar-SA')}</span>
                </div>
              </div>
              {!n.read && (
                <button
                  onClick={() => markAsRead(n.id)}
                  className="px-4 py-2 bg-purple-600 text-white rounded-xl font-bold hover:bg-purple-700 transition-all text-sm shrink-0"
                >
                  ✓ تميت القراءة
                </button>
              )}
              {n.read && (
                <span className="px-3 py-1 bg-green-100 text-green-600 rounded-xl text-xs font-bold">
                  ✓ مقروءة
                </span>
              )}
            </div>
          </div>
        ))}

        {filteredNotifications.length === 0 && (
          <div className="p-16 bg-purple-50 rounded-[40px] border-2 border-dashed border-purple-300 text-center">
            <div className="text-7xl mb-6">📢</div>
            <h3 className="text-2xl font-black text-purple-800 mb-3">لا توجد إشعارات مطابقة للفلاتر</h3>
            <p className="text-purple-600 font-bold">جرّب تغيير الفلاتر أو انتظر إشعارات جديدة من المعلمين</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default AdminVideoNotifications;
