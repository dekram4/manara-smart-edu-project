import React, { ReactNode, useEffect, useRef } from 'react';

interface TouchCarouselProps {
  children: ReactNode;
  label: string;
  activeIndex?: number;
  onActiveIndexChange?: (index: number) => void;
  className?: string;
  trackClassName?: string;
  itemCount?: number;
}

/**
 * Keep the mobile carousel CSS-native. The previous Swiper wrapper could load
 * a second React dispatcher in the Replit preview and crash the whole student
 * portal with "Invalid hook call". Native overflow scrolling gives us the
 * same touch behavior without making the dashboard depend on a third-party
 * renderer.
 */
const TouchCarousel: React.FC<TouchCarouselProps> = ({
  children,
  label,
  activeIndex,
  onActiveIndexChange,
  className = '',
  trackClassName = '',
}) => {
  const mobileTrackRef = useRef<HTMLDivElement | null>(null);
  const items = React.Children.toArray(children);
  const count = items.length || 1;

  useEffect(() => {
    const track = mobileTrackRef.current;
    if (!track || activeIndex === undefined || activeIndex < 0 || activeIndex >= count) return;
    const item = track.children[activeIndex] as HTMLElement | undefined;
    item?.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
  }, [activeIndex, count]);

  const handleMobileScroll = () => {
    if (!onActiveIndexChange || !mobileTrackRef.current || count < 2) return;
    const track = mobileTrackRef.current;
    const center = track.scrollLeft + track.clientWidth / 2;
    let nearestIndex = 0;
    let nearestDistance = Number.POSITIVE_INFINITY;
    Array.from(track.children).forEach((child, index) => {
      const element = child as HTMLElement;
      const childCenter = element.offsetLeft + element.offsetWidth / 2;
      const distance = Math.abs(childCenter - center);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    });
    onActiveIndexChange(nearestIndex);
  };

  return (
    <div className={`student-swiper relative min-w-0 ${className}`} dir="rtl">
      <div
        ref={mobileTrackRef}
        className="student-swiper-mobile"
        role="region"
        aria-label={label}
        onScroll={handleMobileScroll}
      >
        {items.map((item, index) => (
          <div key={index} className="student-swiper-mobile-item h-full min-w-0 snap-center" dir="rtl">
            {item}
          </div>
        ))}
      </div>

      <div className={`student-swiper-desktop ${trackClassName}`}>
        {items.map((item, index) => (
          <div key={index} className="min-w-0 h-full" dir="rtl">
            {item}
          </div>
        ))}
      </div>
    </div>
  );
};

export default TouchCarousel;