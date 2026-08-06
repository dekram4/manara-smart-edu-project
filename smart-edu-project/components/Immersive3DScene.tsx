import React, { useEffect, useRef, useState } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { Float, Stars } from '@react-three/drei';
import * as Matter from 'matter-js';

interface Immersive3DSceneProps {
  accent?: string;
  intensity?: number;
}

function FloatingCard({
  position,
  color,
  scale = 1,
  speed = 1.2,
}: {
  position: [number, number, number];
  color: string;
  scale?: number;
  speed?: number;
}) {
  const meshRef = useRef<any>(null);

  useFrame((state, delta) => {
    if (!meshRef.current) return;
    meshRef.current.rotation.y += delta * 0.55;
    meshRef.current.rotation.x += delta * 0.2;
    meshRef.current.position.y = position[1] + Math.sin(state.clock.elapsedTime * speed) * 0.25;
  });

  return (
    <Float speed={1.8} rotationIntensity={0.8} floatIntensity={0.9}>
      <mesh ref={meshRef} position={position} scale={scale}>
        <boxGeometry args={[1.25, 0.8, 0.25]} />
        <meshStandardMaterial color={color} emissive={color} emissiveIntensity={0.28} roughness={0.2} metalness={0.35} />
      </mesh>
      <mesh position={[position[0], position[1], position[2] + 0.13]}>
        <planeGeometry args={[1.1, 0.7]} />
        <meshBasicMaterial color="#ffffff" transparent opacity={0.1} />
      </mesh>
    </Float>
  );
}

function PhysicsOrbs({ accent }: { accent: string }) {
  const [bubbles, setBubbles] = useState<Array<{ id: number; x: number; y: number; size: number; color: string }>>([]);

  useEffect(() => {
    const engine = Matter.Engine.create({
      gravity: { x: 0, y: 0.001, scale: 0.001 },
    });

    const colors = [accent, '#f472b6', '#f59e0b', '#22d3ee'];
    const bodies = colors.map((color, index) => {
      const size = 18 + index * 5;
      const body = Matter.Bodies.circle(80 + index * 60, 40 + index * 22, size, {
        restitution: 0.92,
        frictionAir: 0.004,
        friction: 0.002,
        density: 0.002,
      });
      body.plugin = { color };
      return body;
    });

    Matter.World.add(engine.world, bodies);

    let frame = 0;
    const tick = () => {
      Matter.Engine.update(engine, 1000 / 60);
      setBubbles(
        bodies.map((body, index) => ({
          id: index,
          x: body.position.x,
          y: body.position.y,
          size: 18 + index * 5,
          color: (body.plugin as { color?: string } | undefined)?.color || accent,
        })),
      );
      frame = window.requestAnimationFrame(tick);
    };

    tick();

    return () => {
      window.cancelAnimationFrame(frame);
      Matter.World.clear(engine.world, true);
      Matter.Engine.clear(engine);
    };
  }, [accent]);

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      {bubbles.map((bubble) => (
        <div
          key={bubble.id}
          className="absolute rounded-full blur-[2px]"
          style={{
            left: `${Math.max(5, Math.min(95, bubble.x / 4))}%`,
            top: `${Math.max(5, Math.min(95, bubble.y / 4))}%`,
            width: bubble.size,
            height: bubble.size,
            background: `radial-gradient(circle, ${bubble.color} 0%, rgba(255,255,255,0.04) 70%)`,
            opacity: 0.32,
            boxShadow: `0 0 28px ${bubble.color}`,
            transform: 'translate(-50%, -50%)',
          }}
        />
      ))}
    </div>
  );
}

const Immersive3DScene: React.FC<Immersive3DSceneProps> = ({ accent = '#38bdf8', intensity = 1 }) => {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden rounded-[inherit]">
      <PhysicsOrbs accent={accent} />
      <Canvas camera={{ position: [0, 0, 7], fov: 45 }} dpr={[1, 2]} gl={{ antialias: true }}>
        <ambientLight intensity={0.8} />
        <pointLight position={[4, 4, 4]} intensity={1.3} color="#38bdf8" />
        <pointLight position={[-3, -2, 4]} intensity={1.05} color="#f472b6" />
        <Stars radius={7} depth={18} count={1200} factor={4} saturation={0} fade speed={0.85} />
        <FloatingCard position={[-2.2, 0.8, 0]} color={accent} scale={1.05 + intensity * 0.08} speed={1.2} />
        <FloatingCard position={[2.1, -0.2, 0]} color="#f59e0b" scale={0.95 + intensity * 0.06} speed={1.5} />
        <FloatingCard position={[0.2, -1.2, 0]} color="#22d3ee" scale={0.9 + intensity * 0.05} speed={1.35} />
      </Canvas>
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,_rgba(255,255,255,0.12),_transparent_32%),radial-gradient(circle_at_bottom_right,_rgba(255,255,255,0.08),_transparent_35%)]" />
    </div>
  );
};

export default Immersive3DScene;
