import React, { ReactNode, useEffect, useRef, useState } from 'react';

interface TouchCarouselProps {
  children: ReactNode;
  label: string;
  activeIndex?: number;
  onActiveIndexChange?: (index: number) => void;
  className?: string;
  trackClassName?: string;
  itemCount?: number;
  /** Prevent a child carousel from handing touch gestures to an ancestor. */
  nested?: boolean;
  /** Mark the carousel as a no-swiping surface for embedded controls/iframes. */
  noSwiping?: boolean;
  showControls?: boolean;
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
  nested = false,
  noSwiping = false,
  showControls = true,
}) => {
  const mobileTrackRef = useRef<HTMLDivElement | null>(null);
  const items = React.Children.toArray(children);
  const count = items.length || 1;
  const [internalIndex, setInternalIndex] = useState(0);
  const selectedIndex = Math.min(
    Math.max(activeIndex ?? internalIndex, 0),
    Math.max(count - 1, 0),
  );

  const updateIndex = (index: number) => {
    const nextIndex = Math.min(Math.max(index, 0), Math.max(count - 1, 0));
    setInternalIndex(nextIndex);
    onActiveIndexChange?.(nextIndex);
    const track = mobileTrackRef.current;
    const item = track?.children[nextIndex] as HTMLElement | undefined;
    item?.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
  };

  useEffect(() => {
    const track = mobileTrackRef.current;
    if (!track || activeIndex === undefined || activeIndex < 0 || activeIndex >= count) return;
    const item = track.children[activeIndex] as HTMLElement | undefined;
    item?.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
  }, [activeIndex, count]);

  const handleMobileScroll = () => {
    if (!mobileTrackRef.current || count < 2) return;
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
    setInternalIndex(nearestIndex);
    onActiveIndexChange?.(nearestIndex);
  };

  return (
    <div
      className={`student-swiper relative min-w-0 ${className}`}
      data-swiper-nested={nested ? 'true' : undefined}
      data-swiper-no-swiping={noSwiping ? 'true' : undefined}
      dir="rtl"
      onTouchStart={nested ? (event) => event.stopPropagation() : undefined}
      onTouchMove={nested ? (event) => event.stopPropagation() : undefined}
      onPointerDown={nested ? (event) => event.stopPropagation() : undefined}
    >
      <div
        ref={mobileTrackRef}
        className={`student-swiper-mobile ${noSwiping ? 'student-swiper-no-swiping' : ''}`}
        role="region"
        aria-label={label}
        onScroll={handleMobileScroll}
        onTouchStart={nested ? (event) => event.stopPropagation() : undefined}
        onTouchMove={nested ? (event) => event.stopPropagation() : undefined}
      >
        {items.map((item, index) => (
          <div
            key={index}
            className="student-swiper-mobile-item h-full min-w-0 snap-center"
            dir="rtl"
          >
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

      {showControls && count > 1 && (
        <div className="student-swiper-controls" aria-label={`التنقل في ${label}`}>
          <button
            type="button"
            className="student-swiper-arrow"
            aria-label="البطاقة السابقة"
            onClick={() => updateIndex(selectedIndex > 0 ? selectedIndex - 1 : count - 1)}
          >
            ‹
          </button>
          <div className="student-swiper-dots" aria-hidden="true">
            {items.map((_, index) => (
              <span key={index} className={index === selectedIndex ? 'is-active' : ''} />
            ))}
          </div>
          <button
            type="button"
            className="student-swiper-arrow"
            aria-label="البطاقة التالية"
            onClick={() => updateIndex(selectedIndex + 1 < count ? selectedIndex + 1 : 0)}
          >
            ›
          </button>
        </div>
      )}
    </div>
  );
};

export default TouchCarousel;