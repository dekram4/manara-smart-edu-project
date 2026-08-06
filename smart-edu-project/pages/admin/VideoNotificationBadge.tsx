import React, { useState, useEffect } from 'react';
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
      onClick={onClick}
      className="relative p-2 rounded-full hover:bg-purple-50 transition-all active:scale-95"
      title="إشعارات الفيديو"
    >
      <span className="text-2xl">📢</span>
      {unreadCount > 0 && (
        <span className="absolute -top-1 -right-1 min-w-[20px] h-5 bg-red-500 text-white rounded-full text-xs font-black flex items-center justify-center px-1 animate-pulse">
          {unreadCount}
        </span>
      )}
    </button>
  );
};

export default VideoNotificationBadge;
