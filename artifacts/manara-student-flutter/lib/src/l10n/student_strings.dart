import 'package:flutter/widgets.dart';

import '../services/student_settings.dart';

/// The app's text in both languages, in one place.
///
/// A plain map rather than generated ARB classes on purpose: the app is
/// Arabic-first and the English side exists so a student can read the
/// interface, not so the project can be translated into arbitrary
/// languages. A map is what a teacher or a reviewer can actually read and
/// correct without a build step.
///
/// Lookup falls back to Arabic for any key English has not been given, so
/// a missing translation shows the Arabic word rather than a blank or a
/// raw key. That is the right failure for this app: an Arabic word in an
/// English sentence is understandable; `portal.cinema` is not.
class StudentStrings {
  const StudentStrings._();

  static const _ar = <String, String>{
    // Brand and shell
    'app.name': 'منارة المعرفة التعليمية',
    'app.shortName': 'منارة المعرفة',
    'app.skipHint': 'اضغط في أي مكان للتخطي',

    // Login
    'login.greeting': 'أهلاً بك يا بطل! 🎒',
    'login.username': 'اسم المستخدم',
    'login.password': 'كلمة المرور',
    'login.submit': 'تسجيل الدخول',
    'login.usernameRequired': 'اكتب اسم المستخدم',
    'login.passwordRequired': 'اكتب كلمة المرور',

    // Portal hub
    'hub.changeLesson': 'تغيير الدرس',
    'hub.changeLessonTooltip': 'تغيير الدرس أو المسار',
    'hub.welcome': 'أهلًا بك في منارة المعرفة',

    // Portal cards
    'portal.lesson': 'شرح الدرس',
    'portal.lesson.sub': 'تعلم بطريقة ممتعة',
    'portal.cinema': 'سينما منارة',
    'portal.cinema.sub': 'فيديوهات المعلم والمشرف',
    'portal.games': 'عالم الترفيه',
    'portal.games.sub': 'ألعاب تعليمية',
    'portal.personality': 'شخصيتي',
    'portal.personality.sub': 'أصنع بطلي',
    'portal.tutor': 'المعلم الافتراضي',
    'portal.tutor.sub': 'صديقك الذكي',
    'portal.quiz': 'مركز الاختبارات',
    'portal.quiz.sub': 'اختبارات المعلم والدورية',
    'portal.solver': 'حلّ المسائل',
    'portal.solver.sub': 'اسأل عن الدرس',
    'portal.meeting': 'اللقاء المباشر',
    'portal.meeting.sub': 'حصة مع معلمك',
    'portal.chat': 'دردشة منارة',
    'portal.chat.sub': 'تواصل آمن',
    'portal.challenge': 'بطاقة التحدي',
    'portal.challenge.sub': 'اسحب وأكمل',

    // Shared actions
    'action.retry': 'إعادة المحاولة',
    'action.close': 'إغلاق',
    'action.confirm': 'تثبيت ومتابعة',
    'action.cancel': 'إلغاء',
    'action.next': 'التالي',
    'action.refresh': 'تحديث',

    // Settings toggles
    'settings.theme.toDark': 'تفعيل الوضع الداكن',
    'settings.theme.toLight': 'تفعيل الوضع الفاتح',
    'settings.language': 'تغيير اللغة',
  };

  static const _en = <String, String>{
    'app.name': 'Manara Knowledge Academy',
    'app.shortName': 'Manara',
    'app.skipHint': 'Tap anywhere to skip',

    'login.greeting': 'Welcome, champion! 🎒',
    'login.username': 'Username',
    'login.password': 'Password',
    'login.submit': 'Sign in',
    'login.usernameRequired': 'Enter your username',
    'login.passwordRequired': 'Enter your password',

    'hub.changeLesson': 'Change lesson',
    'hub.changeLessonTooltip': 'Change the lesson or path',
    'hub.welcome': 'Welcome to Manara',

    'portal.lesson': 'The Lesson',
    'portal.lesson.sub': 'Learn the fun way',
    'portal.cinema': 'Manara Cinema',
    'portal.cinema.sub': 'Videos from your teacher',
    'portal.games': 'Arcade',
    'portal.games.sub': 'Learning games',
    'portal.personality': 'My Character',
    'portal.personality.sub': 'Make your hero',
    'portal.tutor': 'Virtual Teacher',
    'portal.tutor.sub': 'Your smart friend',
    'portal.quiz': 'Quiz Centre',
    'portal.quiz.sub': 'Tests and practice',
    'portal.solver': 'Problem Solver',
    'portal.solver.sub': 'Ask about the lesson',
    'portal.meeting': 'Live Class',
    'portal.meeting.sub': 'Meet your teacher',
    'portal.chat': 'Manara Chat',
    'portal.chat.sub': 'Safe messaging',
    'portal.challenge': 'Challenge Card',
    'portal.challenge.sub': 'Drag and complete',

    'action.retry': 'Try again',
    'action.close': 'Close',
    'action.confirm': 'Confirm',
    'action.cancel': 'Cancel',
    'action.next': 'Next',
    'action.refresh': 'Refresh',

    'settings.theme.toDark': 'Switch to dark mode',
    'settings.theme.toLight': 'Switch to light mode',
    'settings.language': 'Change language',
  };

  /// Looks a key up in the language currently chosen.
  static String of(String key) {
    if (!StudentSettings.isArabic) {
      final english = _en[key];
      if (english != null) return english;
    }
    return _ar[key] ?? key;
  }

  /// Every key defined, for tests that check the two tables agree.
  @visibleForTesting
  static Iterable<String> get keys => _ar.keys;

  @visibleForTesting
  static Iterable<String> get englishKeys => _en.keys;
}

/// Shorthand so call sites read as text rather than as lookups.
String tr(String key) => StudentStrings.of(key);
