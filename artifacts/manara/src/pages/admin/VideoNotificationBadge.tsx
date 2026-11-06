import React, { useState, useEffect } from 'react';
import { Bell } from 'lucide-react';
import { STORAGE_KEYS } from '../../constants';

const VideoNotificationBadge: React.FC<{ onClick: () => void }> = ({ onClick }) => {
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    const tick = () => {
      const saved = localStorage.getItem(STORAGE_KEYS.VIDEO_NOTIFICATIONS);
      if (saved) {
        const all = JSON.parse(saved);
        setUnreadCount(all.filter((n: any) => !n.read).length);
      }
    };
    tick();
    const interval = setInterval(tick, 5000);
    return () => clearInterval(interval);
  }, []);

  return (
    <button
      type="button"
      onClick={onClick}
      className="portal-btn portal-btn-secondary relative"
      title="إشعارات الفيديو"
      aria-label={unreadCount > 0 ? `إشعارات الفيديو: ${unreadCount} غير مقروءة` : 'إشعارات الفيديو'}
    >
      <Bell aria-hidden="true" />
      {unreadCount > 0 && (
        <span className="absolute -top-1.5 -left-1.5 min-w-[20px] h-5 bg-red-600 text-white rounded-full text-[11px] font-black flex items-center justify-center px-1">
          {unreadCount}
        </span>
      )}
    </button>
  );
};

export default VideoNotificationBadge;
