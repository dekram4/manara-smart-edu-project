import React, { Component, ErrorInfo, Suspense, useEffect, useMemo, useRef, useState } from 'react';
import { Canvas } from '@react-three/fiber';
import { Html, OrbitControls } from '@react-three/drei';
import '@three-ws/avatar/viewer';
import { StudentAppearance } from '../../../types';
import { getStudentAppearance } from '../../../utils/studentAppearance';
import StudentAvatar from './StudentAvatar';

interface StudentAvatar3DProps {
  appearance?: StudentAppearance;
  className?: string;
  studentName?: string;
}

type ModelProps = {
  appearance: StudentAppearance;
};

const GLOBAL_AVATAR_MODEL_URL = 'https://three.ws/avatars/michelle.glb';

const HAIR_COLORS: Record<string, string> = {
  '#3f2b24': '#3f2b24',
  '#1f2937': '#1f2937',
  '#8b5e3c': '#8b5e3c',
  '#d97706': '#d97706',
  '#e5e7eb': '#e5e7eb',
  '#ec4899': '#ec4899',
  '#7c3aed': '#7c3aed',
};

const normalizeColor = (value: string | undefined, fallback: string) =>
  value && /^#[0-9a-f]{6}$/i.test(value) ? value : fallback;

const getHairColor = (appearance: StudentAppearance) =>
  normalizeColor(appearance.hairColor, HAIR_COLORS['#3f2b24']);

const GlobalAvatarViewer: React.FC<{
  src: string;
  alt: string;
  onError: () => void;
}> = ({ src, alt, onError }) => {
  const viewerRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    const viewer = viewerRef.current;
    if (!viewer) return undefined;
    const handleError = () => onError();
    viewer.addEventListener('error', handleError);
    return () => viewer.removeEventListener('error', handleError);
  }, [onError]);

  return React.createElement('three-ws-viewer', {
    ref: viewerRef,
    src,
    alt,
    background: 'transparent',
    className: 'h-full min-h-[340px] w-full',
    style: { height: '100%', minHeight: 340, width: '100%' },
  });
};

const isStyle = (value: string | undefined, ...styles: string[]) =>
  Boolean(value && styles.includes(value));

const BodyMaterial: React.FC<{ color: string; roughness?: number; metalness?: number }> = ({
  color,
  roughness = 0.72,
  metalness = 0,
}) => <meshStandardMaterial color={color} roughness={roughness} metalness={metalness} />;

const Face: React.FC<{ appearance: StudentAppearance; hairColor: string }> = ({
  appearance,
  hairColor,
}) => {
  const hair = appearance.hair;
  const isBald = hair === '🦲';
  const isCap = isStyle(hair, '🧢', '🎩', '👒', '🎓');
  const isCurly = hair === '🦱';
  const isRedStyle = hair === '🦰';
  const actualHairColor = isRedStyle && !appearance.hairColor ? '#dc2626' : hairColor;

  return (
    <group>
      <mesh position={[0, 2.03, 0]}>
        <sphereGeometry args={[0.52, 24, 18]} />
        <BodyMaterial color={appearance.skinTone || '#edb891'} roughness={0.8} />
      </mesh>
      <mesh position={[-0.52, 2.03, 0]}>
        <sphereGeometry args={[0.1, 12, 8]} />
        <BodyMaterial color={appearance.skinTone || '#edb891'} roughness={0.8} />
      </mesh>
      <mesh position={[0.52, 2.03, 0]}>
        <sphereGeometry args={[0.1, 12, 8]} />
        <BodyMaterial color={appearance.skinTone || '#edb891'} roughness={0.8} />
      </mesh>

      {!isBald && !isCap && (
        <group position={[0, 2.35, 0]}>
          <mesh scale={[0.55, 0.28, 0.54]}>
            <sphereGeometry args={[1, 20, 12]} />
            <BodyMaterial color={actualHairColor} roughness={0.9} />
          </mesh>
          {isCurly && (
            <>
              {[-0.42, -0.22, 0, 0.22, 0.42].map((x) => (
                <mesh key={x} position={[x, 0.04, 0.12]} scale={0.16}>
                  <sphereGeometry args={[1, 12, 8]} />
                  <BodyMaterial color={actualHairColor} roughness={0.9} />
                </mesh>
              ))}
            </>
          )}
        </group>
      )}

      {hair === '🧢' && (
        <group position={[0, 2.43, 0.05]}>
          <mesh scale={[0.58, 0.16, 0.58]}>
            <sphereGeometry args={[1, 20, 12]} />
            <BodyMaterial color={actualHairColor} roughness={0.68} />
          </mesh>
          <mesh position={[0, -0.08, 0.45]} scale={[0.38, 0.035, 0.2]}>
            <boxGeometry args={[1, 1, 1]} />
            <BodyMaterial color={actualHairColor} roughness={0.68} />
          </mesh>
        </group>
      )}
      {hair === '🎩' && (
        <group position={[0, 2.48, 0]}>
          <mesh scale={[0.44, 0.42, 0.44]}>
            <cylinderGeometry args={[0.82, 0.82, 1, 20]} />
            <BodyMaterial color={actualHairColor} roughness={0.62} />
          </mesh>
          <mesh position={[0, -0.5, 0]} scale={[0.72, 0.08, 0.58]}>
            <cylinderGeometry args={[0.82, 0.82, 1, 20]} />
            <BodyMaterial color="#111827" roughness={0.65} />
          </mesh>
        </group>
      )}
      {hair === '👒' && (
        <group position={[0, 2.4, 0]}>
          <mesh scale={[0.56, 0.2, 0.56]}>
            <cylinderGeometry args={[0.9, 0.9, 1, 20]} />
            <BodyMaterial color={actualHairColor} roughness={0.75} />
          </mesh>
          <mesh position={[0, -0.16, 0]} scale={[0.8, 0.06, 0.65]}>
            <cylinderGeometry args={[0.9, 0.9, 1, 20]} />
            <BodyMaterial color="#fbbf24" roughness={0.75} />
          </mesh>
        </group>
      )}
      {hair === '🎓' && (
        <group position={[0, 2.48, 0]}>
          <mesh rotation={[0, Math.PI / 4, 0]} scale={[0.48, 0.08, 0.48]}>
            <boxGeometry args={[1, 1, 1]} />
            <BodyMaterial color="#312e81" roughness={0.72} />
          </mesh>
          <mesh position={[0, 0.12, 0]}>
            <cylinderGeometry args={[0.2, 0.2, 0.3, 16]} />
            <BodyMaterial color="#312e81" roughness={0.72} />
          </mesh>
        </group>
      )}

      <mesh position={[-0.18, 2.08, 0.49]} scale={[0.07, 0.1, 0.04]}>
        <sphereGeometry args={[1, 12, 8]} />
        <BodyMaterial color="#172033" roughness={0.45} />
      </mesh>
      <mesh position={[0.18, 2.08, 0.49]} scale={[0.07, 0.1, 0.04]}>
        <sphereGeometry args={[1, 12, 8]} />
        <BodyMaterial color="#172033" roughness={0.45} />
      </mesh>
      <mesh position={[0, 1.94, 0.51]} scale={[0.13, 0.045, 0.025]}>
        <sphereGeometry args={[1, 12, 8]} />
        <BodyMaterial color="#be4567" roughness={0.55} />
      </mesh>
    </group>
  );
};

const HairAccessory: React.FC<{ appearance: StudentAppearance }> = ({ appearance }) => {
  const accessory = appearance.accessory;
  if (accessory === '👓' || accessory === '🕶️') {
    const glassesColor = accessory === '🕶️' ? '#111827' : '#334155';
    return (
      <group position={[0, 2.07, 0.56]}>
        <mesh position={[-0.18, 0, 0]} rotation={[0, 0, 0]}>
          <torusGeometry args={[0.13, 0.025, 8, 20]} />
          <BodyMaterial color={glassesColor} metalness={0.35} roughness={0.35} />
        </mesh>
        <mesh position={[0.18, 0, 0]}>
          <torusGeometry args={[0.13, 0.025, 8, 20]} />
          <BodyMaterial color={glassesColor} metalness={0.35} roughness={0.35} />
        </mesh>
        <mesh position={[0, 0, 0]}>
          <boxGeometry args={[0.14, 0.025, 0.025]} />
          <BodyMaterial color={glassesColor} metalness={0.35} roughness={0.35} />
        </mesh>
      </group>
    );
  }
  if (accessory === '🎧') {
    return (
      <group position={[0, 2.08, 0]}>
        <mesh position={[-0.52, 0, 0]}>
          <sphereGeometry args={[0.13, 16, 12]} />
          <BodyMaterial color="#a855f7" roughness={0.5} metalness={0.15} />
        </mesh>
        <mesh position={[0.52, 0, 0]}>
          <sphereGeometry args={[0.13, 16, 12]} />
          <BodyMaterial color="#a855f7" roughness={0.5} metalness={0.15} />
        </mesh>
        <mesh position={[0, 0.25, 0]} rotation={[0, 0, 0]}>
          <torusGeometry args={[0.57, 0.035, 8, 24, Math.PI]} />
          <BodyMaterial color="#c084fc" roughness={0.5} metalness={0.15} />
        </mesh>
      </group>
    );
  }
  if (accessory === '🎒') {
    return (
      <mesh position={[0, 0.7, -0.43]} scale={[0.48, 0.65, 0.18]}>
        <boxGeometry args={[1, 1, 1]} />
        <BodyMaterial color="#f97316" roughness={0.78} />
      </mesh>
    );
  }
  if (accessory === '🛡️') {
    return (
      <mesh position={[0.72, 0.85, 0.15]} rotation={[0, -0.35, -0.22]} scale={[0.32, 0.44, 0.08]}>
        <sphereGeometry args={[1, 16, 12]} />
        <BodyMaterial color="#38bdf8" roughness={0.45} metalness={0.4} />
      </mesh>
    );
  }
  if (accessory === '🪄') {
    return (
      <group position={[0.82, 0.62, 0.2]} rotation={[0, 0, -0.55]}>
        <mesh>
          <cylinderGeometry args={[0.025, 0.025, 0.85, 10]} />
          <BodyMaterial color="#fbbf24" roughness={0.5} metalness={0.3} />
        </mesh>
        <mesh position={[0, 0.47, 0]}>
          <icosahedronGeometry args={[0.11, 1]} />
          <BodyMaterial color="#e879f9" roughness={0.32} metalness={0.2} />
        </mesh>
      </group>
    );
  }
  if (accessory === '🏹') {
    return (
      <mesh position={[-0.7, 0.95, -0.15]} rotation={[0, 0, -0.2]}>
        <torusGeometry args={[0.35, 0.025, 8, 24, Math.PI * 1.45]} />
        <BodyMaterial color="#a16207" roughness={0.8} />
      </mesh>
    );
  }
  if (accessory === '📚') {
    return (
      <group position={[-0.72, 0.66, 0.25]} rotation={[0, 0, 0.16]}>
        <mesh position={[0, 0.11, 0]}>
          <boxGeometry args={[0.3, 0.18, 0.1]} />
          <BodyMaterial color="#38bdf8" roughness={0.7} />
        </mesh>
        <mesh position={[0, -0.1, 0]}>
          <boxGeometry args={[0.3, 0.18, 0.1]} />
          <BodyMaterial color="#f472b6" roughness={0.7} />
        </mesh>
      </group>
    );
  }
  return (
    <mesh position={[0.62, 1.18, 0.3]} scale={0.09}>
      <icosahedronGeometry args={[1, 1]} />
      <BodyMaterial color="#fbbf24" roughness={0.35} metalness={0.2} />
    </mesh>
  );
};

const AvatarModel: React.FC<ModelProps> = ({ appearance }) => {
  const top = appearance.top || appearance.outfit || '👕';
  const bottom = appearance.bottom || '👖';
  const shoes = appearance.shoes || '👟';
  const skin = appearance.skinTone || '#edb891';
  const hairColor = getHairColor(appearance);
  const accent = normalizeColor(appearance.color, '#38bdf8');
  const isShorts = bottom === '🩳' || bottom === '🩲';
  const isSkate = shoes === '🛼' || shoes === '⛸️';
  const legColor = isShorts ? skin : bottom === '🥋' ? '#e2e8f0' : '#2563eb';
  const topColor = isStyle(top, '🧥', '🦺') ? '#f97316' : isStyle(top, '🥋') ? '#f8fafc' : accent;

  return (
    <group position={[0, -1.18, 0]}>
      <mesh position={[0, -0.32, 0]}>
        <boxGeometry args={[0.9, 0.42, 0.52]} />
        <BodyMaterial color={legColor} roughness={0.82} />
      </mesh>
      <mesh position={[-0.25, -0.84, 0]}>
        <boxGeometry args={[0.28, 0.85, 0.3]} />
        <BodyMaterial color={legColor} roughness={0.82} />
      </mesh>
      <mesh position={[0.25, -0.84, 0]}>
        <boxGeometry args={[0.28, 0.85, 0.3]} />
        <BodyMaterial color={legColor} roughness={0.82} />
      </mesh>
      <mesh position={[-0.25, -1.3, 0.08]} scale={[0.25, 0.11, isSkate ? 0.44 : 0.32]}>
        <sphereGeometry args={[1, 16, 10]} />
        <BodyMaterial color={isSkate ? '#ec4899' : '#f8fafc'} roughness={0.48} />
      </mesh>
      <mesh position={[0.25, -1.3, 0.08]} scale={[0.25, 0.11, isSkate ? 0.44 : 0.32]}>
        <sphereGeometry args={[1, 16, 10]} />
        <BodyMaterial color={isSkate ? '#ec4899' : '#f8fafc'} roughness={0.48} />
      </mesh>

      <group>
        <mesh position={[0, 0.66, 0]}>
          <boxGeometry args={[1.02, 1.08, 0.6]} />
          <BodyMaterial color={topColor} roughness={0.72} />
        </mesh>
        {top === '🧥' && (
          <>
            <mesh position={[0, 0.67, 0.32]} scale={[0.05, 0.5, 0.02]}>
              <boxGeometry args={[1, 1, 1]} />
              <BodyMaterial color="#fef3c7" roughness={0.72} />
            </mesh>
            <mesh position={[0, 0.6, 0.34]} scale={[0.25, 0.16, 0.03]}>
              <boxGeometry args={[1, 1, 1]} />
              <BodyMaterial color="#fbbf24" roughness={0.72} />
            </mesh>
          </>
        )}
        {top === '🦺' && (
          <mesh position={[0, 0.66, 0.33]} scale={[0.08, 0.5, 0.025]}>
            <boxGeometry args={[1, 1, 1]} />
            <BodyMaterial color="#fde047" roughness={0.65} />
          </mesh>
        )}
        {top === '🥋' && (
          <mesh position={[0, 0.3, 0.33]} scale={[0.4, 0.06, 0.03]}>
            <boxGeometry args={[1, 1, 1]} />
            <BodyMaterial color="#b91c1c" roughness={0.7} />
          </mesh>
        )}
        {top === '🧑‍🚀' && (
          <mesh position={[0, 0.75, 0.34]} scale={[0.2, 0.2, 0.03]}>
            <cylinderGeometry args={[0.75, 0.75, 1, 16]} />
            <BodyMaterial color="#e0f2fe" roughness={0.32} metalness={0.15} />
          </mesh>
        )}
        {top === '👔' && (
          <mesh position={[0, 0.72, 0.34]} scale={[0.08, 0.35, 0.03]}>
            <boxGeometry args={[1, 1, 1]} />
            <BodyMaterial color="#111827" roughness={0.54} />
          </mesh>
        )}
        {top === '🥼' && (
          <mesh position={[0, 0.66, 0.34]} scale={[0.04, 0.5, 0.025]}>
            <boxGeometry args={[1, 1, 1]} />
            <BodyMaterial color="#f8fafc" roughness={0.9} />
          </mesh>
        )}
        {top === '🎓' && (
          <mesh position={[0, 0.64, 0.34]} scale={[0.25, 0.3, 0.03]}>
            <boxGeometry args={[1, 1, 1]} />
            <BodyMaterial color="#fde68a" roughness={0.5} />
          </mesh>
        )}
      </group>

      <mesh position={[-0.64, 0.7, 0]} rotation={[0, 0, -0.18]}>
        <cylinderGeometry args={[0.13, 0.16, 0.88, 12]} />
        <BodyMaterial color={topColor} roughness={0.72} />
      </mesh>
      <mesh position={[0.64, 0.7, 0]} rotation={[0, 0, 0.18]}>
        <cylinderGeometry args={[0.13, 0.16, 0.88, 12]} />
        <BodyMaterial color={topColor} roughness={0.72} />
      </mesh>
      <mesh position={[-0.78, 0.27, 0]}>
        <sphereGeometry args={[0.16, 14, 10]} />
        <BodyMaterial color={skin} roughness={0.82} />
      </mesh>
      <mesh position={[0.78, 0.27, 0]}>
        <sphereGeometry args={[0.16, 14, 10]} />
        <BodyMaterial color={skin} roughness={0.82} />
      </mesh>

      <mesh position={[0, 1.35, 0]}>
        <cylinderGeometry args={[0.16, 0.16, 0.22, 12]} />
        <BodyMaterial color={skin} roughness={0.82} />
      </mesh>
      <Face appearance={appearance} hairColor={hairColor} />
      <HairAccessory appearance={appearance} />
    </group>
  );
};

const ViewerFallback: React.FC<{ appearance?: StudentAppearance; className?: string }> = ({
  appearance,
  className = '',
}) => (
  <div className={`relative flex h-full min-h-[340px] items-center justify-center overflow-hidden rounded-[26px] bg-gradient-to-b from-indigo-950 via-slate-900 to-slate-950 ${className}`}>
    <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_25%,rgba(56,189,248,0.28),transparent_42%),linear-gradient(rgba(255,255,255,0.05)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.05)_1px,transparent_1px)] bg-[length:auto,28px_28px,28px_28px]" />
    <div className="relative z-10 flex flex-col items-center gap-3">
      <StudentAvatar appearance={appearance} size="xl" />
      <span className="rounded-full border border-white/15 bg-white/10 px-3 py-1 text-[10px] font-black text-cyan-100">
        وضع العرض الخفيف
      </span>
    </div>
  </div>
);

class Avatar3DErrorBoundary extends Component<
  { children: React.ReactNode; fallback: React.ReactNode },
  { hasError: boolean }
> {
  state = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.warn('Student 3D avatar unavailable; using the lightweight fallback.', error.message, info.componentStack);
  }

  render() {
    return this.state.hasError ? this.props.fallback : this.props.children;
  }
}

const StudentAvatar3D: React.FC<StudentAvatar3DProps> = ({
  appearance,
  className = '',
  studentName = 'بطلك',
}) => {
  const resolvedAppearance = useMemo(
    () => appearance || getStudentAppearance(null),
    [appearance],
  );
  const [webglAvailable, setWebglAvailable] = useState(false);
  const [previewMode, setPreviewMode] = useState<'global' | 'custom'>('global');
  const [globalAvatarError, setGlobalAvatarError] = useState(false);
  const previousAppearance = useRef<string | null>(null);

  useEffect(() => {
    const serializedAppearance = JSON.stringify(resolvedAppearance);
    if (previousAppearance.current && previousAppearance.current !== serializedAppearance) {
      setPreviewMode('custom');
    }
    previousAppearance.current = serializedAppearance;
  }, [resolvedAppearance]);

  useEffect(() => {
    const canvas = document.createElement('canvas');
    const context =
      canvas.getContext('webgl', { failIfMajorPerformanceCaveat: true }) ||
      canvas.getContext('experimental-webgl', { failIfMajorPerformanceCaveat: true });
    setWebglAvailable(Boolean(context));
  }, []);

  const fallback = <ViewerFallback appearance={resolvedAppearance} className={className} />;
  if (!webglAvailable) return fallback;

  return (
    <div
      className={`relative h-full min-h-[340px] overflow-hidden rounded-[26px] bg-gradient-to-b from-indigo-950 via-slate-900 to-slate-950 ${className}`}
      aria-label={`معاينة ثلاثية الأبعاد لشخصية ${studentName}`}
    >
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_50%_24%,rgba(56,189,248,0.28),transparent_42%),linear-gradient(rgba(255,255,255,0.045)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.045)_1px,transparent_1px)] bg-[length:auto,28px_28px,28px_28px]" />
      <Avatar3DErrorBoundary fallback={fallback}>
        {previewMode === 'global' && !globalAvatarError ? (
          <div className="relative h-full min-h-[340px] w-full">
            <GlobalAvatarViewer
              src={GLOBAL_AVATAR_MODEL_URL}
              alt={`مجسم عالمي لشخصية ${studentName}`}
              onError={() => {
                console.warn('Global avatar model unavailable; using the custom avatar.');
                setGlobalAvatarError(true);
                setPreviewMode('custom');
              }}
            />
          </div>
        ) : (
          <Canvas
            camera={{ position: [0, 1.05, 5.2], fov: 35 }}
            dpr={[1, 1.35]}
            gl={{ antialias: true, powerPreference: 'low-power' }}
          >
            <ambientLight intensity={1.35} />
            <directionalLight position={[3, 5, 4]} intensity={2.3} color="#dbeafe" />
            <directionalLight position={[-4, 2, 2]} intensity={1.3} color="#f0abfc" />
            <pointLight position={[0, 1.5, 2]} intensity={1.15} color="#67e8f9" />
            <Suspense
              fallback={
                <Html center>
                  <div className="whitespace-nowrap rounded-full border border-white/20 bg-slate-950/75 px-4 py-2 text-xs font-black text-white backdrop-blur-md">
                    جارٍ تجهيز شخصيتك ثلاثية الأبعاد...
                  </div>
                </Html>
              }
            >
              <AvatarModel appearance={resolvedAppearance} />
              <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -2.7, 0]}>
                <circleGeometry args={[1.55, 40]} />
                <meshStandardMaterial color="#0f172a" roughness={0.98} transparent opacity={0.85} />
              </mesh>
            </Suspense>
            <OrbitControls
              enablePan={false}
              enableZoom={false}
              minPolarAngle={Math.PI / 2.35}
              maxPolarAngle={Math.PI / 1.8}
              target={[0, 0.3, 0]}
              rotateSpeed={0.75}
            />
          </Canvas>
        )}
      </Avatar3DErrorBoundary>
      <div className="absolute left-3 top-3 z-10 flex gap-1 rounded-full border border-white/15 bg-slate-950/55 p-1 backdrop-blur-md">
        <button
          type="button"
          onClick={() => setPreviewMode('global')}
          className={`rounded-full px-2.5 py-1 text-[10px] font-black transition ${previewMode === 'global' && !globalAvatarError ? 'bg-cyan-400 text-slate-950' : 'text-cyan-100 hover:bg-white/10'}`}
          disabled={globalAvatarError}
        >
          مجسم عالمي
        </button>
        <button
          type="button"
          onClick={() => setPreviewMode('custom')}
          className={`rounded-full px-2.5 py-1 text-[10px] font-black transition ${previewMode === 'custom' || globalAvatarError ? 'bg-violet-400 text-slate-950' : 'text-violet-100 hover:bg-white/10'}`}
        >
          مظهري المخصص
        </button>
      </div>
      <div className="pointer-events-none absolute inset-x-0 bottom-3 z-10 flex justify-center">
        <span className="rounded-full border border-white/15 bg-slate-950/55 px-3 py-1.5 text-[10px] font-black text-cyan-100 backdrop-blur-md">
          اسحب بإصبعك أو بالماوس للدوران 360° · تغييراتك تظهر في المظهر المخصص
        </span>
      </div>
      <div className="pointer-events-none absolute right-3 top-3 z-10 rounded-full border border-emerald-300/20 bg-emerald-300/10 px-2.5 py-1 text-[10px] font-black text-emerald-100">
        3D LIVE
      </div>
    </div>
  );
};

export default StudentAvatar3D;