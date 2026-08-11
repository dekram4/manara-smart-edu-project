import React, { ReactNode, useEffect, useRef } from 'react';
import { A11y, Pagination } from 'swiper/modules';
import { Swiper, SwiperSlide } from 'swiper/react';
import type { Swiper as SwiperInstance } from 'swiper';
import 'swiper/css';
import 'swiper/css/pagination';

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
 * The student carousels intentionally use Swiper instead of hand-rolled touch
 * handlers. Swiper handles momentum, direction locking, nested touch areas,
 * iOS rubber-banding, and slide measurement when the dashboard changes size.
 */
const TouchCarousel: React.FC<TouchCarouselProps> = ({
  children,
  label,
  activeIndex,
  onActiveIndexChange,
  className = '',
  trackClassName = '',
}) => {
  const swiperRef = useRef<SwiperInstance | null>(null);
  const items = React.Children.toArray(children);
  const count = items.length || 1;

  useEffect(() => {
    const swiper = swiperRef.current;
    if (!swiper || activeIndex === undefined || activeIndex < 0 || activeIndex >= count) return;
    if (swiper.activeIndex !== activeIndex) {
      swiper.slideTo(activeIndex);
    }
  }, [activeIndex, count]);

  return (
    <div className={`student-swiper relative min-w-0 ${className}`} dir="rtl">
      <div className="student-swiper-mobile">
        <Swiper
          modules={[A11y, Pagination]}
          onSwiper={(swiper) => {
            swiperRef.current = swiper;
            if (activeIndex !== undefined && activeIndex > 0) {
              swiper.slideTo(activeIndex, 0);
            }
          }}
          onSlideChange={(swiper) => onActiveIndexChange?.(swiper.activeIndex)}
          slidesPerView={1.08}
          spaceBetween={14}
          centeredSlides
          loop={false}
          resistance
          resistanceRatio={0.72}
          threshold={8}
          touchRatio={1}
          touchAngle={35}
          nested
          observer
          observeParents
          watchOverflow
          grabCursor
          noSwiping
          noSwipingClass="swiper-no-swiping"
          noSwipingSelector="input, textarea, select, iframe, video, [data-swiper-no-swiping]"
          a11y={{ containerMessage: label }}
          pagination={count > 1 ? { clickable: true, dynamicBullets: count > 7 } : false}
          breakpoints={{
            480: {
              slidesPerView: 1.16,
              spaceBetween: 16,
            },
            640: {
              slidesPerView: 1.55,
              spaceBetween: 18,
            },
            768: {
              slidesPerView: 1.85,
              spaceBetween: 20,
            },
          }}
          className="!overflow-visible"
        >
          {items.map((item, index) => (
            <SwiperSlide key={index} className="!h-auto">
              <div className="h-full min-w-0" dir="rtl">
                {item}
              </div>
            </SwiperSlide>
          ))}
        </Swiper>
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