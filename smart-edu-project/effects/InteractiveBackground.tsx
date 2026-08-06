import React, { useEffect, useRef } from 'react';

interface Orb {
  x: number;
  y: number;
  vx: number;
  vy: number;
  r: number;
  color: string;
  opacity: number;
}

export const InteractiveBackground: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const mouseRef = useRef({ x: -999, y: -999 });
  const orbsRef = useRef<Orb[]>([]);
  const rafRef = useRef<number>(0);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const colors = [
      '#6366f1', // indigo
      '#8b5cf6', // violet
      '#a78bfa', // light violet
      '#38bdf8', // cyan
      '#818cf8', // indigo-light
      '#c084fc', // purple
    ];

    const resize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    };
    resize();
    window.addEventListener('resize', resize);

    // Initialise orbs
    orbsRef.current = Array.from({ length: 12 }, () => ({
      x: Math.random() * window.innerWidth,
      y: Math.random() * window.innerHeight,
      vx: (Math.random() - 0.5) * 0.4,
      vy: (Math.random() - 0.5) * 0.4,
      r: 80 + Math.random() * 140,
      color: colors[Math.floor(Math.random() * colors.length)],
      opacity: 0.08 + Math.random() * 0.14,
    }));

    const onMouseMove = (e: MouseEvent) => {
      mouseRef.current = { x: e.clientX, y: e.clientY };
    };
    window.addEventListener('mousemove', onMouseMove);

    const draw = () => {
      const w = canvas.width;
      const h = canvas.height;
      ctx.clearRect(0, 0, w, h);

      // Base dark gradient
      const bg = ctx.createLinearGradient(0, 0, w, h);
      bg.addColorStop(0, '#0f0c29');
      bg.addColorStop(0.5, '#1a1040');
      bg.addColorStop(1, '#0d1b2a');
      ctx.fillStyle = bg;
      ctx.fillRect(0, 0, w, h);

      // Subtle grid
      ctx.save();
      ctx.strokeStyle = 'rgba(99,102,241,0.07)';
      ctx.lineWidth = 1;
      const spacing = 48;
      for (let x = 0; x < w; x += spacing) {
        ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke();
      }
      for (let y = 0; y < h; y += spacing) {
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
      }
      ctx.restore();

      // Mouse glow
      const mx = mouseRef.current.x;
      const my = mouseRef.current.y;
      if (mx > 0) {
        const mouseGlow = ctx.createRadialGradient(mx, my, 0, mx, my, 200);
        mouseGlow.addColorStop(0, 'rgba(139,92,246,0.18)');
        mouseGlow.addColorStop(1, 'rgba(139,92,246,0)');
        ctx.fillStyle = mouseGlow;
        ctx.fillRect(0, 0, w, h);
      }

      // Floating orbs
      for (const orb of orbsRef.current) {
        orb.x += orb.vx;
        orb.y += orb.vy;
        if (orb.x < -orb.r) orb.x = w + orb.r;
        if (orb.x > w + orb.r) orb.x = -orb.r;
        if (orb.y < -orb.r) orb.y = h + orb.r;
        if (orb.y > h + orb.r) orb.y = -orb.r;

        const grd = ctx.createRadialGradient(orb.x, orb.y, 0, orb.x, orb.y, orb.r);
        grd.addColorStop(0, orb.color + Math.round(orb.opacity * 255).toString(16).padStart(2, '0'));
        grd.addColorStop(1, orb.color + '00');
        ctx.fillStyle = grd;
        ctx.beginPath();
        ctx.arc(orb.x, orb.y, orb.r, 0, Math.PI * 2);
        ctx.fill();
      }

      // Neon scan-line shimmer
      const shimmer = ctx.createLinearGradient(0, 0, w, 0);
      shimmer.addColorStop(0, 'rgba(99,102,241,0)');
      shimmer.addColorStop(0.5, 'rgba(99,102,241,0.04)');
      shimmer.addColorStop(1, 'rgba(99,102,241,0)');
      ctx.fillStyle = shimmer;
      ctx.fillRect(0, 0, w, h);

      rafRef.current = requestAnimationFrame(draw);
    };

    draw();

    return () => {
      cancelAnimationFrame(rafRef.current);
      window.removeEventListener('resize', resize);
      window.removeEventListener('mousemove', onMouseMove);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="pointer-events-none fixed inset-0 z-0"
      style={{ display: 'block' }}
    />
  );
};
