/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './*.{js,ts,jsx,tsx}',
    './pages/**/*.{js,ts,jsx,tsx}',
    './src/components/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      fontFamily: {
        tajawal: ['Tajawal', 'sans-serif'],
      },
      colors: {
        // ===== MANARA SYSTEM brand palette (derived from the logo) =====
        // Primary brand = teal / cyan. We override `indigo` (the app's
        // dominant primary color) so every existing indigo-* usage adopts
        // the new brand automatically.
        indigo: {
          50: '#ecfdfd',
          100: '#cdf6f5',
          200: '#9eebea',
          300: '#63d9da',
          400: '#2fc1c6',
          500: '#1497a0',
          600: '#0a747f',
          700: '#0b5d66',
          800: '#0c4a53',
          900: '#0c3a43',
          950: '#07272e',
        },
        // Tertiary accent = harmonized cyan-blue. We override `blue` (used in
        // ~120 places) so it sits in tune with the teal brand instead of the
        // default vivid blue. (blue carries no warning/danger semantics.)
        blue: {
          50: '#eff9ff',
          100: '#d6f0fd',
          200: '#ace0fb',
          300: '#74ccf7',
          400: '#36b2ed',
          500: '#1394d2',
          600: '#0a6f99',
          700: '#0c5a7d',
          800: '#0e4a66',
          900: '#0f3a51',
          950: '#082636',
        },
        // Secondary = deep ocean navy (the logo's dark backdrop). Overrides
        // `purple` so indigo→purple gradients become teal→navy.
        purple: {
          50: '#eef3f8',
          100: '#d7e3ef',
          200: '#b3c8de',
          300: '#84a4c6',
          400: '#5680ac',
          500: '#356290',
          600: '#274e76',
          700: '#1f3e5e',
          800: '#1b3450',
          900: '#16293e',
          950: '#0e1b2a',
        },
        // Convenience aliases for new work.
        brand: {
          50: '#ecfdfd',
          100: '#cdf6f5',
          200: '#9eebea',
          300: '#63d9da',
          400: '#2fc1c6',
          500: '#14a2ab',
          600: '#0b8693',
          700: '#0a6c78',
          800: '#0c5460',
          900: '#0c3f4b',
          950: '#072a33',
        },
        accent: {
          cyan: '#22d3ee',
          emerald: '#10b981',
          teal: '#14b8a6',
          navy: '#0e1b2a',
        },
      },
      animation: {
        fadeIn: 'fadeIn 0.3s ease-in-out',
        shake: 'shake 0.5s ease-in-out',
        popIn: 'popIn 0.4s ease-out',
        float: 'float 3s ease-in-out infinite',
        glow: 'glow 2s ease-in-out infinite',
        pulseScale: 'pulseScale 2s ease-in-out infinite',
        slideUp: 'slideUp 0.4s ease-out',
        wobble: 'wobble 0.6s ease-in-out',
        ripple: 'ripple 0.6s linear',
        spinSlow: 'spinSlow 8s linear infinite',
        jelly: 'jelly 0.8s ease',
        heartbeat: 'heartbeat 1.5s ease-in-out infinite',
        confetti: 'confetti 1s ease-out forwards',
        rainbow: 'rainbow 3s linear infinite',
        flipIn: 'flipIn 0.5s ease-out',
        morph: 'morph 4s ease-in-out infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0', transform: 'translateY(8px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        shake: {
          '0%, 100%': { transform: 'translateX(0)' },
          '25%': { transform: 'translateX(-8px)' },
          '75%': { transform: 'translateX(8px)' },
        },
        popIn: {
          '0%': { opacity: '0', transform: 'scale(0.5)' },
          '70%': { transform: 'scale(1.05)' },
          '100%': { opacity: '1', transform: 'scale(1)' },
        },
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-12px)' },
        },
        glow: {
          '0%, 100%': { boxShadow: '0 0 5px rgba(11,134,147,0.3)' },
          '50%': { boxShadow: '0 0 25px rgba(11,134,147,0.6), 0 0 50px rgba(11,134,147,0.2)' },
        },
        pulseScale: {
          '0%, 100%': { transform: 'scale(1)' },
          '50%': { transform: 'scale(1.05)' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(30px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        wobble: {
          '0%': { transform: 'rotate(0deg)' },
          '15%': { transform: 'rotate(-5deg)' },
          '30%': { transform: 'rotate(3deg)' },
          '45%': { transform: 'rotate(-2deg)' },
          '60%': { transform: 'rotate(1deg)' },
          '100%': { transform: 'rotate(0deg)' },
        },
        ripple: {
          '0%': { transform: 'scale(0)', opacity: '1' },
          '100%': { transform: 'scale(4)', opacity: '0' },
        },
        spinSlow: {
          '0%': { transform: 'rotate(0deg)' },
          '100%': { transform: 'rotate(360deg)' },
        },
        jelly: {
          '0%, 100%': { transform: 'scale(1, 1)' },
          '25%': { transform: 'scale(0.9, 1.1)' },
          '50%': { transform: 'scale(1.1, 0.9)' },
          '75%': { transform: 'scale(0.95, 1.05)' },
        },
        heartbeat: {
          '0%, 100%': { transform: 'scale(1)' },
          '14%': { transform: 'scale(1.15)' },
          '28%': { transform: 'scale(1)' },
          '42%': { transform: 'scale(1.15)' },
          '70%': { transform: 'scale(1)' },
        },
        confetti: {
          '0%': { opacity: '1', transform: 'translateY(-20px) rotate(0deg)' },
          '100%': { opacity: '0', transform: 'translateY(200px) rotate(720deg)' },
        },
        rainbow: {
          '0%': { filter: 'hue-rotate(0deg)' },
          '100%': { filter: 'hue-rotate(360deg)' },
        },
        flipIn: {
          '0%': { opacity: '0', transform: 'perspective(400px) rotateY(90deg)' },
          '100%': { opacity: '1', transform: 'perspective(400px) rotateY(0deg)' },
        },
        morph: {
          '0%, 100%': { borderRadius: '60% 40% 30% 70% / 60% 30% 70% 40%' },
          '50%': { borderRadius: '30% 60% 70% 40% / 50% 60% 30% 60%' },
        },
      },
    },
  },
  plugins: [],
};
