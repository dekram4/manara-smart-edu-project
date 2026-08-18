import React from 'react';
import { motion } from 'framer-motion';
import ManaraHome from './ManaraHome';

const ManaraPreview: React.FC = () => {
  return (
    <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="min-h-screen bg-gray-900 flex justify-center items-start py-4">
      <div style={{ width: '100%', maxWidth: 430 }}>
        <ManaraHome
          name="الملكة"
          age={5}
          xp={1250}
          gems={45}
          level={3}
          levelProgress={65}
          activeTab="home"
          onTabChange={(tab) => console.log('Tab:', tab)}
          onNavigate={(screen) => console.log('Screen:', screen)}
        />
      </div>
    </motion.div>
  );
};

export default ManaraPreview;
