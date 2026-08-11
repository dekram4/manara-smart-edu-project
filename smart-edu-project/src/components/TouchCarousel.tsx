import React, { ReactNode, useEffect, useRef, useState } from 'react';

interface TouchCarouselProps {
  children: ReactNode;
  label: string;
  activeIndex?: number;
  onActiveIndexChange?: (index: number) => void;
  className?: string;
  trackClassName?: string;
  itemCount?: number;
}

const TouchCarousel: React.FC<TouchCarouselProps> = ({
  children,
  label,
  activeIndex: controlledIndex,
  onActiveIndexChange,
  className = '',
  trackClassName = '',
  itemCount,
}) => {
  const viewportRef = useRef<HTMLDivElement>(null);
  const [internalIndex, setInternalIndex] = useState(0);
  const activeIndex = controlledIndex ?? internalIndex;
  const items = React.Children.toArray(children);
  const count = itemCount ?? items.length;

  const announceIndex = (nextIndex: number, vibrate = true) => {
    const safeIndex = Math.max(0, Math.min(nextIndex, Math.max(count - 1, 0)));
    if (safeIndex === activeIndex) return;
    if (controlledIndex === undefined) setInternalIndex(safeIndex);
    onActiveIndexChange?.(safeIndex);
    if (vibrate && typeof navigator !== 'undefined' && 'vibrate' in navigator) {
      navigator.vibrate?.(8);
    }
  };

  const getClosestIndex = () => {
    const viewport = viewportRef.current;
    if (!viewport) return 0;
    const viewportRect = viewport.getBoundingClientRect();
    const viewportCenter = viewportRect.left + viewportRect.width / 2;
    let closestIndex = 0;
    let closestDistance = Number.POSITIVE_INFINITY;

    Array.from(viewport.children).forEach((child, index) => {
      const rect = (child as HTMLElement).getBoundingClientRect();
      const distance = Math.abs(rect.left + rect.width / 2 - viewportCenter);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = index;
      }
    });
    return closestIndex;
  };

  useEffect(() => {
    const viewport = viewportRef.current;
    if (!viewport || controlledIndex === undefined) return;
    const item = viewport.children[activeIndex] as HTMLElement | undefined;
    item?.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
  }, [activeIndex, controlledIndex]);

  const handleScroll = () => {
    window.requestAnimationFrame(() => announceIndex(getClosestIndex()));
  };

  const scrollToIndex = (index: number) => {
    const item = viewportRef.current?.children[index] as HTMLElement | undefined;
    item?.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
    announceIndex(index);
  };

  return (
    <div className={`touch-carousel overflow-hidden md:overflow-visible ${className}`}>
      <div
        ref={viewportRef}
        dir="ltr"
        onScroll={handleScroll}
        aria-label={label}
        className={`touch-carousel-track flex snap-x snap-mandatory gap-3 overflow-x-auto overscroll-x-contain px-1 pb-2 [scrollbar-width:none] [-ms-overflow-style:none] md:overflow-visible md:px-0 md:pb-0 md:snap-none ${trackClassName}`}
        style={{ WebkitOverflowScrolling: 'touch' }}
      >
        {items.map((item, index) => (
          <div
            key={index}
            dir="rtl"
            className="touch-carousel-item min-w-0 shrink-0 snap-center md:min-w-0 md:shrink"
          >
            {item}
          </div>
        ))}
      </div>

      {count > 1 && (
        <div className="mt-3 flex items-center justify-center gap-2 md:hidden" role="tablist" aria-label={`مؤشرات ${label}`}>
          {Array.from({ length: count }, (_, index) => (
            <button
              key={index}
              type="button"
              role="tab"
              aria-selected={activeIndex === index}
              aria-label={`${label}: ${index + 1} من ${count}`}
              onClick={() => scrollToIndex(index)}
              className={`min-h-3 min-w-3 rounded-full p-0 transition-all duration-200 ${
                activeIndex === index
                  ? 'h-3 w-7 bg-amber-300 shadow-[0_0_12px_rgba(252,211,77,0.7)]'
                  : 'h-3 w-3 bg-white/30 hover:bg-white/60'
              }`}
            />
          ))}
        </div>
      )}
    </div>
  );
};

export default TouchCarousel;