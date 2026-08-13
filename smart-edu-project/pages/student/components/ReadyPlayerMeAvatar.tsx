import React, { Component, Suspense, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { Canvas, useThree } from '@react-three/fiber';
import { OrbitControls, useGLTF } from '@react-three/drei';
import * as THREE from 'three';
import { StudentAppearance } from '../../../types';

const READY_PLAYER_ME_CREATOR_URL =
  (import.meta as ImportMeta & { env?: Record<string, string | undefined> }).env
    ?.VITE_READY_PLAYER_ME_CREATOR_URL
  || 'https://demo.readyplayer.me/avatar';

const READY_PLAYER_ME_ORIGIN = new URL(READY_PLAYER_ME_CREATOR_URL).origin;

const postReadyPlayerMeMessage = (
  frame: HTMLIFrameElement | null,
  message: Record<string, unknown>,
) => {
  frame?.contentWindow?.postMessage(JSON.stringify(message), READY_PLAYER_ME_ORIGIN);
};

const getAvatarId = (url: string, explicitId?: string) => {
  if (explicitId) return explicitId;
  const match = url.match(/models\.readyplayer\.me\/([^/?#]+)\.glb/i);
  return match?.[1] || '';
};

export type ReadyPlayerMeExport = Pick<
  StudentAppearance,
  'readyPlayerMeAvatarUrl' | 'readyPlayerMeAvatarId' | 'readyPlayerMeAvatarImageUrl'
>;

interface ReadyPlayerMeCreatorProps {
  onExport: (avatar: ReadyPlayerMeExport) => void;
}

export const ReadyPlayerMeCreator: React.FC<ReadyPlayerMeCreatorProps> = ({ onExport }) => {
  const frameRef = useRef<HTMLIFrameElement | null>(null);
  const [frameReady, setFrameReady] = useState(false);
  const [lastExported, setLastExported] = useState(false);

  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      if (event.origin !== READY_PLAYER_ME_ORIGIN) return;

      let payload = event.data;
      if (typeof payload === 'string') {
        try {
          payload = JSON.parse(payload);
        } catch {
          return;
        }
      }

      if (!payload || payload.source !== 'readyplayerme') return;

      if (payload.eventName === 'v1.frame.ready') {
        setFrameReady(true);
        postReadyPlayerMeMessage(frameRef.current, {
          target: 'readyplayerme',
          type: 'subscribe',
          eventName: 'v1.avatar.exported',
        });
        return;
      }

      if (payload.eventName === 'v1.avatar.exported' && payload.data?.url) {
        const url = String(payload.data.url);
        const avatarId = getAvatarId(url, payload.data.avatarId ? String(payload.data.avatarId) : undefined);
        const imageUrl = avatarId
          ? `https://models.readyplayer.me/${avatarId}.png`
          : url.replace(/\.glb(\?.*)?$/i, '.png$1');

        setLastExported(true);
        onExport({
          readyPlayerMeAvatarUrl: url,
          readyPlayerMeAvatarId: avatarId || undefined,
          readyPlayerMeAvatarImageUrl: imageUrl,
        });
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [onExport]);

  return (
    <div className="overflow-hidden rounded-[26px] border border-cyan-300/25 bg-slate-950 shadow-2xl">
      <div className="flex flex-col gap-2 border-b border-white/10 bg-slate-900/80 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-sm font-black text-white">مصمم الأفاتار ثلاثي الأبعاد</p>
          <p className="mt-1 text-[11px] font-bold text-slate-400">
            صمّم الشخصية كاملة ثم اضغط Save داخل المحرر
          </p>
        </div>
        <span className={`inline-flex w-fit items-center gap-2 rounded-full px-3 py-1 text-[10px] font-black ${
          lastExported
            ? 'bg-emerald-400/15 text-emerald-200'
            : frameReady
              ? 'bg-cyan-400/15 text-cyan-200'
              : 'bg-amber-400/15 text-amber-200'
        }`}>
          <span className={`h-2 w-2 rounded-full ${lastExported ? 'bg-emerald-300' : frameReady ? 'bg-cyan-300' : 'bg-amber-300'}`} />
          {lastExported ? 'تم حفظ الأفاتار' : frameReady ? 'المحرر جاهز' : 'جاري تجهيز المحرر'}
        </span>
      </div>
      <iframe
        ref={frameRef}
        title="Ready Player Me Avatar Creator"
        src={`${READY_PLAYER_ME_CREATOR_URL}?frameApi&source=manara`}
        allow="camera *; microphone *"
        className="h-[600px] min-h-[70vh] w-full border-0 bg-slate-950 sm:h-[680px] md:h-[720px]"
      />
    </div>
  );
};

const AvatarCamera: React.FC = () => {
  const { camera } = useThree();

  useEffect(() => {
    camera.lookAt(0, 0, 0);
    camera.updateProjectionMatrix();
  }, [camera]);

  return null;
};

const ReadyPlayerMeModel: React.FC<{ url: string }> = ({ url }) => {
  const { scene } = useGLTF(url);
  const groupRef = useRef<THREE.Group>(null);

  useLayoutEffect(() => {
    if (!groupRef.current) return;
    const box = new THREE.Box3().setFromObject(scene);
    const size = box.getSize(new THREE.Vector3());
    const center = box.getCenter(new THREE.Vector3());
    const scale = 2.7 / Math.max(size.y, 0.001);

    groupRef.current.scale.setScalar(scale);
    groupRef.current.position.set(
      -center.x * scale,
      -center.y * scale - 1.35,
      -center.z * scale,
    );
  }, [scene]);

  return (
    <group ref={groupRef}>
      <primitive object={scene} />
    </group>
  );
};

class ReadyPlayerMeViewerBoundary extends Component<
  { children: React.ReactNode; fallback: React.ReactNode },
  { hasError: boolean }
> {
  state = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  render() {
    return this.state.hasError ? this.props.fallback : this.props.children;
  }
}

interface ReadyPlayerMeViewerProps {
  url?: string;
  imageUrl?: string;
}

export const ReadyPlayerMeViewer: React.FC<ReadyPlayerMeViewerProps> = ({ url, imageUrl }) => {
  if (!url) {
    return (
      <div className="flex min-h-[360px] items-center justify-center rounded-[26px] border border-dashed border-white/15 bg-slate-950/50 px-6 text-center">
        <div>
          <div className="mx-auto mb-4 h-24 w-16 rounded-[45%] border-2 border-cyan-300/50 bg-gradient-to-b from-cyan-300/20 to-indigo-500/20" />
          <p className="text-sm font-black text-slate-300">سيظهر الأفاتار هنا بعد الضغط على Save</p>
        </div>
      </div>
    );
  }

  const imageFallback = imageUrl ? (
    <div className="flex min-h-[360px] items-center justify-center bg-slate-950 p-4">
      <img src={imageUrl} alt="الأفاتار المحفوظ" className="h-full max-h-[440px] w-full object-contain" />
    </div>
  ) : (
    <div className="flex min-h-[360px] items-center justify-center bg-slate-950 text-sm font-black text-slate-300">
      تعذر تحميل المعاينة ثلاثية الأبعاد
    </div>
  );

  return (
    <div className="overflow-hidden rounded-[26px] border border-cyan-300/25 bg-slate-950 shadow-2xl">
      <ReadyPlayerMeViewerBoundary fallback={imageFallback}>
        <Canvas
          camera={{ position: [0, 0, 4.4], fov: 35 }}
          dpr={[1, 1.5]}
          gl={{ antialias: true, powerPreference: 'low-power' }}
        >
          <AvatarCamera />
          <ambientLight intensity={1.8} />
          <directionalLight position={[3, 5, 4]} intensity={2.4} color="#dbeafe" />
          <directionalLight position={[-3, 2, 2]} intensity={1.4} color="#c4b5fd" />
          <Suspense fallback={null}>
            <ReadyPlayerMeModel url={url} />
            <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -1.38, 0]}>
              <circleGeometry args={[1.45, 40]} />
              <meshStandardMaterial color="#0f172a" roughness={1} transparent opacity={0.85} />
            </mesh>
          </Suspense>
          <OrbitControls
            enablePan={false}
            enableZoom={false}
            minPolarAngle={Math.PI / 2.4}
            maxPolarAngle={Math.PI / 1.75}
            target={[0, 0, 0]}
            rotateSpeed={0.75}
          />
        </Canvas>
      </ReadyPlayerMeViewerBoundary>
      <div className="border-t border-white/10 bg-slate-900/80 px-3 py-2 text-center text-[10px] font-black text-cyan-100">
        اسحب الشخصية لتدويرها 360 درجة
      </div>
    </div>
  );
};