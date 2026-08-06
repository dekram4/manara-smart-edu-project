import React, { useEffect, useRef, useState } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { Float, Stars } from '@react-three/drei';
import * as Matter from 'matter-js';

interface Immersive3DSceneProps {
  accent?: string;
  intensity?: number;
}

function EducationalBook({
  position,
  rotation = [0, 0, 0],
}: {
  position: [number, number, number];
  rotation?: [number, number, number];
}) {
  const meshRef = useRef<any>(null);

  useFrame((state, delta) => {
    if (!meshRef.current) return;
    meshRef.current.rotation.y += delta * 0.45;
    meshRef.current.rotation.z = Math.sin(state.clock.elapsedTime * 0.8) * 0.08;
  });

  return (
    <Float speed={1.7} rotationIntensity={0.45} floatIntensity={0.75}>
      <group ref={meshRef} position={position} rotation={rotation}>
        {/* غلاف الكتاب */}
        <mesh position={[-0.38, 0, 0]}>
          <boxGeometry args={[0.78, 1.25, 0.12]} />
          <meshStandardMaterial color="#4f46e5" emissive="#312e81" emissiveIntensity={0.35} roughness={0.28} metalness={0.2} />
        </mesh>
        <mesh position={[0.38, 0, 0]}>
          <boxGeometry args={[0.78, 1.25, 0.12]} />
          <meshStandardMaterial color="#7c3aed" emissive="#4c1d95" emissiveIntensity={0.3} roughness={0.28} metalness={0.2} />
        </mesh>
        {/* صفحات الكتاب المفتوح */}
        <mesh position={[-0.38, 0, 0.08]} rotation={[0, -0.08, 0]}>
          <boxGeometry args={[0.7, 1.12, 0.06]} />
          <meshStandardMaterial color="#fef3c7" roughness={0.8} />
        </mesh>
        <mesh position={[0.38, 0, 0.08]} rotation={[0, 0.08, 0]}>
          <boxGeometry args={[0.7, 1.12, 0.06]} />
          <meshStandardMaterial color="#fff7ed" roughness={0.8} />
        </mesh>
        {/* سطران مضيئان على الصفحات */}
        <mesh position={[-0.38, 0.22, 0.12]}>
          <boxGeometry args={[0.42, 0.025, 0.015]} />
          <meshBasicMaterial color="#38bdf8" />
        </mesh>
        <mesh position={[0.38, 0.22, 0.12]}>
          <boxGeometry args={[0.42, 0.025, 0.015]} />
          <meshBasicMaterial color="#f472b6" />
        </mesh>
      </group>
    </Float>
  );
}

function EducationalPencil({ position }: { position: [number, number, number] }) {
  const meshRef = useRef<any>(null);

  useFrame((_, delta) => {
    if (meshRef.current) meshRef.current.rotation.z += delta * 0.35;
  });

  return (
    <Float speed={2.1} rotationIntensity={0.7} floatIntensity={1.1}>
      <group ref={meshRef} position={position} rotation={[0.5, 0.3, -0.6]}>
        <mesh>
          <cylinderGeometry args={[0.1, 0.1, 1.65, 12]} />
          <meshStandardMaterial color="#facc15" emissive="#ca8a04" emissiveIntensity={0.25} />
        </mesh>
        <mesh position={[0, 0.9, 0]}>
          <coneGeometry args={[0.1, 0.28, 12]} />
          <meshStandardMaterial color="#f5deb3" />
        </mesh>
        <mesh position={[0, 1.06, 0]}>
          <coneGeometry args={[0.035, 0.1, 8]} />
          <meshStandardMaterial color="#334155" />
        </mesh>
        <mesh position={[0, -0.9, 0]}>
          <cylinderGeometry args={[0.105, 0.105, 0.18, 12]} />
          <meshStandardMaterial color="#f472b6" emissive="#be185d" emissiveIntensity={0.25} />
        </mesh>
      </group>
    </Float>
  );
}

function EducationalGlobe({ position }: { position: [number, number, number] }) {
  const meshRef = useRef<any>(null);

  useFrame((_, delta) => {
    if (meshRef.current) meshRef.current.rotation.y += delta * 0.3;
  });

  return (
    <Float speed={1.5} rotationIntensity={0.35} floatIntensity={0.8}>
      <group ref={meshRef} position={position}>
        <mesh>
          <sphereGeometry args={[0.62, 24, 16]} />
          <meshStandardMaterial color="#0ea5e9" emissive="#075985" emissiveIntensity={0.35} roughness={0.45} metalness={0.15} />
        </mesh>
        <mesh rotation={[Math.PI / 2, 0, 0]}>
          <torusGeometry args={[0.74, 0.025, 8, 40]} />
          <meshStandardMaterial color="#fbbf24" emissive="#d97706" emissiveIntensity={0.5} />
        </mesh>
        <mesh rotation={[0.2, 0, 0.5]}>
          <torusGeometry args={[0.62, 0.018, 8, 40]} />
          <meshStandardMaterial color="#f8fafc" emissive="#bae6fd" emissiveIntensity={0.3} />
        </mesh>
      </group>
    </Float>
  );
}

function EducationalMicroscope({ position }: { position: [number, number, number] }) {
  const meshRef = useRef<any>(null);

  useFrame((state) => {
    if (meshRef.current) meshRef.current.rotation.y = Math.sin(state.clock.elapsedTime * 0.7) * 0.18;
  });

  return (
    <Float speed={1.8} rotationIntensity={0.4} floatIntensity={0.7}>
      <group ref={meshRef} position={position} scale={0.75}>
        <mesh position={[0, -0.58, 0]}>
          <boxGeometry args={[1.2, 0.12, 0.6]} />
          <meshStandardMaterial color="#14b8a6" emissive="#0f766e" emissiveIntensity={0.35} />
        </mesh>
        <mesh position={[0, -0.2, 0]}>
          <cylinderGeometry args={[0.08, 0.08, 0.75, 12]} />
          <meshStandardMaterial color="#e2e8f0" metalness={0.65} roughness={0.25} />
        </mesh>
        <mesh position={[0.2, 0.22, 0]} rotation={[0, 0, -0.7]}>
          <cylinderGeometry args={[0.1, 0.13, 0.85, 12]} />
          <meshStandardMaterial color="#64748b" metalness={0.6} roughness={0.25} />
        </mesh>
        <mesh position={[0.48, 0.56, 0]} rotation={[0, 0, -0.7]}>
          <cylinderGeometry args={[0.13, 0.09, 0.42, 12]} />
          <meshStandardMaterial color="#a78bfa" emissive="#7c3aed" emissiveIntensity={0.35} />
        </mesh>
        <mesh position={[0, 0.02, 0.18]}>
          <cylinderGeometry args={[0.2, 0.2, 0.06, 16]} />
          <meshStandardMaterial color="#fbbf24" emissive="#d97706" emissiveIntensity={0.3} />
        </mesh>
      </group>
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
        <EducationalBook position={[-2.15, 0.85, 0]} rotation={[0.25, 0.15, -0.15]} />
        <EducationalPencil position={[2.1, 0.8, 0]} />
        <EducationalGlobe position={[2.15, -1.1, 0]} />
        <EducationalMicroscope position={[-1.9, -1.2, 0]} />
      </Canvas>
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,_rgba(255,255,255,0.12),_transparent_32%),radial-gradient(circle_at_bottom_right,_rgba(255,255,255,0.08),_transparent_35%)]" />
    </div>
  );
};

export default Immersive3DScene;
