// 🎨 MANARA - Lamsa-inspired warm color palette
export const colors = {
  // Primary - Student (Orange family)
  primary: '#FF6B35',
  primaryLight: '#FF9A6B',
  primaryDark: '#E85520',

  // Secondary - Teacher (Amber family)
  secondary: '#F59E0B',
  secondaryLight: '#FBBF24',
  secondaryDark: '#D97706',

  // Accent - Parent (Rose family)
  accent: '#FB7185',
  accentLight: '#FDA4AF',
  accentDark: '#E11D48',

  // Admin (Purple family)
  admin: '#A78BFA',
  adminLight: '#C4B5FD',
  adminDark: '#7C3AED',

  // Game colors
  teal: '#4ECDC4',
  green: '#4ADE80',
  blue: '#60A5FA',
  yellow: '#FFE66D',
  pink: '#FF6B9D',
  red: '#EF4444',

  // Neutrals
  background: '#FFF8F0',
  backgroundAlt: '#FFF0E6',
  surface: '#FFFFFF',
  surfaceAlt: '#FDF6EE',

  text: '#2D3748',
  textLight: '#718096',
  textMuted: '#A0AEC0',
  border: '#FFE8D6',
  borderLight: '#FFF0E6',

  // Gradients
  studentGradient: ['#FF6B35', '#FF6B9D', '#A78BFA'],
  teacherGradient: ['#F59E0B', '#FB923C', '#FF6B35'],
  parentGradient: ['#FB7185', '#F472B6', '#A78BFA'],
  adminGradient: ['#A78BFA', '#818CF8', '#6366F1'],

  // XP bar
  xpGradient: ['#FFE66D', '#FFB347', '#FF8C42'],
};

export type ColorTheme = 'student' | 'teacher' | 'parent' | 'admin';

export const getThemeColors = (role: ColorTheme) => {
  switch (role) {
    case 'student': return {
      primary: colors.primary,
      primaryLight: colors.primaryLight,
      gradient: colors.studentGradient,
      bg: '#FFF5EE',
      card: '#FFFFFF',
    };
    case 'teacher': return {
      primary: colors.secondary,
      primaryLight: colors.secondaryLight,
      gradient: colors.teacherGradient,
      bg: '#FFFBF0',
      card: '#FFFFFF',
    };
    case 'parent': return {
      primary: colors.accent,
      primaryLight: colors.accentLight,
      gradient: colors.parentGradient,
      bg: '#FFF5F7',
      card: '#FFFFFF',
    };
    case 'admin': return {
      primary: colors.admin,
      primaryLight: colors.adminLight,
      gradient: colors.adminGradient,
      bg: '#F9F7FF',
      card: '#FFFFFF',
    };
  }
};
