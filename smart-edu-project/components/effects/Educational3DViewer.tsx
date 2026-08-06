import React, { Component, ErrorInfo, Suspense, useEffect, useState } from 'react';
import { Canvas } from '@react-three/fiber';
import { Float, Html, OrbitControls, useGLTF } from '@react-three/drei';

interface Educational3DViewerProps {
  modelUrl?: string;
  className?: string;
  fallbackEmoji?: string;
}

function Model({ url }: { url: string }) {
  const { scene } = useGLTF(url);
  return (
    <Float speed={2} rotationIntensity={1} floatIntensity={1.5}>
      <primitive object={scene} scale={2} />
    </Float>
  );
}

class ViewerErrorBoundary extends Component<
  { children: React.ReactNode; fallback: React.ReactNode },
  { hasError: boolean }
> {
  state = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.warn('Educational 3D model unavailable; using the visual fallback.', error.message, info.componentStack);
  }

  render() {
    return this.state.hasError ? this.props.fallback : this.props.children;
  }
}

const ViewerFallback: React.FC<{ emoji: string }> = ({ emoji }) => (
  <div className="flex h-full w-full items-center justify-center">
    <div className="relative flex h-24 w-24 items-center justify-center rounded-[28px] border border-white/25 bg-white/10 text-6xl shadow-[0_0_40px_rgba(56,189,248,0.2)] backdrop-blur-md animate-float">
      <span>{emoji}</span>
      <span className="absolute -right-2 -top-2 text-xl text-yellow-200 animate-pulse">✦</span>
    </div>
  </div>
);

export const Educational3DViewer: React.FC<Educational3DViewerProps> = ({
  modelUrl,
  className = '',
  fallbackEmoji = '📚',
}) => {
  const [webglAvailable, setWebglAvailable] = useState(false);

  useEffect(() => {
    const canvas = document.createElement('canvas');
    const context =
      canvas.getContext('webgl', { failIfMajorPerformanceCaveat: true }) ||
      canvas.getContext('experimental-webgl', { failIfMajorPerformanceCaveat: true });
    setWebglAvailable(Boolean(context));
  }, []);

  const fallback = <ViewerFallback emoji={fallbackEmoji} />;
  const hasModelUrl = Boolean(modelUrl?.trim());

  return (
    <div className={`relative h-80 w-full overflow-hidden ${className}`}>
      {webglAvailable && hasModelUrl ? (
        <ViewerErrorBoundary fallback={fallback}>
          <Canvas camera={{ position: [0, 0, 5], fov: 45 }} dpr={[1, 1.5]}>
            <ambientLight intensity={0.8} />
            <directionalLight position={[10, 10, 5]} intensity={1.5} />
            <Suspense
              fallback={
                <Html center>
                  <div className="whitespace-nowrap rounded-full border border-white/20 bg-slate-950/70 px-4 py-2 text-sm font-bold text-white backdrop-blur-md">
                    جاري تحميل المجسم...
                  </div>
                </Html>
              }
            >
              <Model url={modelUrl as string} />
            </Suspense>
            <OrbitControls enableZoom={false} enablePan={false} />
          </Canvas>
        </ViewerErrorBoundary>
      ) : (
        fallback
      )}
    </div>
  );
};

export default Educational3DViewer;