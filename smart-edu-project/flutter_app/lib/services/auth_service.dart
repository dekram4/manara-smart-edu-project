import '../models/app_models.dart';

class AuthSession {
  const AuthSession({
    required this.role,
    required this.displayName,
    required this.userId,
  });

  final UserRole role;
  final String displayName;
  final String userId;
}

/// طبقة المصادقة التي ستتصل لاحقاً بجدول المستخدمين/Supabase.
/// لا تحتوي الواجهة على منطق كلمات المرور، حتى يمكن استبدال المصدر دون إعادة
/// بناء الشاشات.
class ManaraAuthService {
  const ManaraAuthService();

  Future<AuthSession?> signIn({
    required UserRole role,
    required String username,
    required String password,
    Set<String> knownUsernames = const {},
    Map<String, String> knownDisplayNames = const {},
  }) async {
    final normalizedUsername = username.trim().toLowerCase();
    if (normalizedUsername.isEmpty || password.trim().isEmpty) return null;

    final names = <UserRole, String>{
      UserRole.student: 'سلمان',
      UserRole.teacher: 'أحمد المعلم',
      UserRole.guardian: 'ولي الأمر',
    };
    final allowedUsers = <UserRole, Set<String>>{
      UserRole.student: {'salman', 'student'},
      UserRole.teacher: {'ahmad', 'teacher'},
      UserRole.guardian: {'parent', 'guardian'},
    };
    if (!allowedUsers[role]!.contains(normalizedUsername) && !knownUsernames.contains(normalizedUsername)) return null;
    return AuthSession(
      role: role,
      displayName: knownDisplayNames[normalizedUsername] ?? names[role]!,
      userId: '${role.name}-$normalizedUsername',
    );
  }

}