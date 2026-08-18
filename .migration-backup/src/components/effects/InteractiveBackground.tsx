import React, { useEffect, useState } from "react";
import { motion, useSpring, useMotionValue } from "framer-motion";

export const InteractiveBackground: React.FC = () => {
  const [mousePosition, setMousePosition] = useState({ x: 0, y: 0 });

  // قيم حركة ملطفة لتتبع الماوس
  const mouseX = useMotionValue(0);
  const mouseY = useMotionValue(0);

  const springX = useSpring(mouseX, { stiffness: 50, damping: 20 });
  const springY = useSpring(mouseY, { stiffness: 50, damping: 20 });

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      const { clientX, clientY } = e;
      const targetX = clientX - window.innerWidth / 2;
      const targetY = clientY - window.innerHeight / 2;

      mouseX.set(targetX * 0.05);
      mouseY.set(targetY * 0.05);
      setMousePosition({ x: clientX, y: clientY });
    };

    window.addEventListener("mousemove", handleMouseMove);
    return () => window.removeEventListener("mousemove", handleMouseMove);
  }, [mouseX, mouseY]);

  return (
    <div className="fixed inset-0 pointer-events-none overflow-hidden bg-slate-950 -z-10">
      {/* 1. إضاءة نيون تتبع حركة الماوس */}
      <motion.div
        className="absolute w-[500px] h-[500px] rounded-full bg-gradient-to-r from-indigo-500/20 to-purple-500/20 blur-[120px]"
        style={{
          x: mousePosition.x - 250,
          y: mousePosition.y - 250,
        }}
        transition={{ type: "spring", damping: 30, stiffness: 200 }}
      />

      {/* 2. دوائر وكرة إضاءة عائمة متفاعلة مع الاتجاه عكسياً */}
      <motion.div
        style={{ x: springX, y: springY }}
        className="absolute top-1/4 right-1/4 w-[400px] h-[400px] bg-indigo-600/30 blur-[140px] rounded-full"
      />
      <motion.div
        style={{ x: springX, y: springY }}
        className="absolute bottom-1/4 left-1/4 w-[350px] h-[350px] bg-blue-500/20 blur-[130px] rounded-full"
      />

      {/* 3. شبكة الجزيئات الهندسيّة والعناصر التفاعلية الطافية */}
      <div className="absolute inset-0 bg-[radial-gradient(#3b82f6_1px,transparent_1px)] [background-size:32px_32px] opacity-15" />

      {/* 4. رموز وأشكال عائمة (رموز تعليمية/رياضية حركية) */}
      {[...Array(12)].map((_, i) => (
        <motion.div
          key={i}
          initial={{
            x:
              Math.random() *
              (typeof window !== "undefined" ? window.innerWidth : 1000),
            y:
              Math.random() *
              (typeof window !== "undefined" ? window.innerHeight : 1000),
            opacity: 0.2,
          }}
          animate={{
            y: [0, -30, 0],
            rotate: [0, 180, 360],
            opacity: [0.2, 0.6, 0.2],
          }}
          transition={{
            duration: 8 + Math.random() * 6,
            repeat: Infinity,
            ease: "easeInOut",
            delay: i * 0.5,
          }}
          className="absolute w-4 h-4 rounded-full border border-indigo-400/40 bg-indigo-500/10 backdrop-blur-sm"
          style={{
            top: `${i * 8 + 5}%`,
            left: `${i * 9 + 2}%`,
          }}
        />
      ))}
    </div>
  );
};
