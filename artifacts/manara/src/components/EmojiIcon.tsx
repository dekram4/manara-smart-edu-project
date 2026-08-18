/**
 * EmojiIcon — renders a single emoji using the emoji-mart `em-emoji` web
 * component with the Twitter (Twemoji) image set, guaranteeing identical
 * appearance across Chrome, Safari and mobile browsers.
 *
 * emoji-mart initialises once via `init({ data })`.  After that every
 * `<em-emoji>` element resolves its image from CDN automatically.
 */
import React from 'react';
import { init } from 'emoji-mart';
import data from '@emoji-mart/data';

// Register the em-emoji custom element once (idempotent).
init({ data });

/** Props accepted by the em-emoji custom element. */
interface EmEmojiProps extends React.HTMLAttributes<HTMLElement> {
  /** Raw Unicode emoji string (e.g. "👦"). */
  native?: string;
  /** emoji-mart id (e.g. "boy"), alternative to native. */
  id?: string;
  /** Shortcode (e.g. ":boy:"), alternative to native. */
  shortcodes?: string;
  /**
   * CSS size string — "32px", "1.5em", etc.
   * emoji-mart interprets the value directly as a CSS font-size.
   */
  size?: string;
  /** Image set: "twitter" uses Twemoji via CDN. */
  set?: string;
  /** Skin-tone index 1-6. */
  skin?: number;
}

// Augment the React 18+ JSX namespace (react-jsx transform).
declare module 'react' {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace JSX {
    interface IntrinsicElements {
      'em-emoji': EmEmojiProps;
    }
  }
}

interface EmojiIconProps {
  /** Raw Unicode emoji character to display, e.g. "👦" or "🧑‍🚀". */
  emoji: string;
  /** Pixel size — applied as both the CSS font-size and the image size. */
  size?: number;
  className?: string;
  'aria-label'?: string;
}

const EmojiIcon: React.FC<EmojiIconProps> = ({
  emoji,
  size = 32,
  className,
  'aria-label': ariaLabel,
}) => (
  <span
    className={className}
    aria-label={ariaLabel}
    role={ariaLabel ? 'img' : undefined}
    style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}
  >
    <em-emoji native={emoji} size={`${size}px`} set="twitter" />
  </span>
);

export default EmojiIcon;
