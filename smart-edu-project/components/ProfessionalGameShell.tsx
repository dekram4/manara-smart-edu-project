import React, { useMemo, useState } from 'react';
import { motion } from 'framer-motion';

interface TaskItem {
  id: string;
  title: string;
  type: 'learn' | 'play' | 'reward';
}

export const ProfessionalGameShell: React.FC = () => {
  const [items] = useState<TaskItem[]>([
    { id: '1', title: 'درس اليوم', type: 'learn' },
    { id: '2', title: 'مهمة اللعب', type: 'play' },
    { id: '3', title: 'مكافأة', type: 'reward' },
  ]);

  const palette = useMemo(() => ({
    learn: 'from-sky-500 to-blue-600',
    play: 'from-fuchsia-500 to-purple-600',
    reward: 'from-amber-400 to-orange-500',
  }), []);

  return (
    <div className="rounded-[36px] border border-white/20 bg-slate-950/70 p-6 shadow-2xl backdrop-blur-xl">
      <div className="mb-5 flex items-center justify-between">
        <div>
          <h3 className="text-2xl font-black text-white">لوحة مهام احترافية</h3>
          <p className="text-sm text-slate-300">اكتشف مسار التعلم بكل تفاعل واضح ومميز</p>
        </div>
        <motion.div animate={{ y: [0, -6, 0] }} transition={{ repeat: Infinity, duration: 1.8 }} className="rounded-full bg-amber-400 px-4 py-2 text-sm font-black text-slate-900">
          🎮 Game Flow
        </motion.div>
      </div>

      <div className="space-y-3">
        {items.map((item) => (
          <motion.div
            key={item.id}
            whileHover={{ scale: 1.01, y: -2 }}
            whileTap={{ scale: 0.98 }}
            className={`rounded-[24px] bg-gradient-to-r ${palette[item.type]} p-4 text-white shadow-lg`}
          >
            <div className="flex items-center justify-between">
              <span className="text-lg font-black">{item.title}</span>
              <span className="text-sm font-semibold">▶</span>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
};
