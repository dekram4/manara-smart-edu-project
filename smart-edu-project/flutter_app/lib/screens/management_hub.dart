import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'records_manager.dart';
import 'academic_settings_screen.dart';
import 'reports_screen.dart';
import 'children_screen.dart';
import 'quiz_manager.dart';
import 'permissions_screen.dart';
import 'account_management.dart';
import 'system_settings_screen.dart';
import 'video_notifications_screen.dart';
import 'chat_screen.dart';
import 'account_screen.dart';
import 'teacher_management_screen.dart';
import 'content_management_screen.dart';
import 'certificates_screen.dart';

class ManagementHub extends StatefulWidget {
  const ManagementHub({super.key, required this.role, required this.section});
  final UserRole role;
  final String section;

  @override
  State<ManagementHub> createState() => _ManagementHubState();
}

class _ManagementHubState extends State<ManagementHub> {
  String query = '';

  UserRole get role => widget.role;
  String get section => widget.section;

  @override
  Widget build(BuildContext context) {
    final items = _itemsFor(role, section);
    final filteredItems = query.trim().isEmpty
        ? items
        : items.where((item) {
            final haystack = '${item.title} ${item.subtitle}'.toLowerCase();
            return haystack.contains(query.trim().toLowerCase());
          }).toList();
    final unread = context.watch<AppState>().unreadMessagesForCurrentRole;
    return Scaffold(
      appBar: AppBar(title: Text(section, style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            role == UserRole.teacher
                ? 'أدوات المعلم لإدارة التعلم ومتابعة الطلاب'
                : role == UserRole.guardian
                    ? 'تابع رحلة أبنائك التعليمية من مكان واحد'
                    : 'إدارة منصة منارة المعرفة وبياناتها',
            style: const TextStyle(color: ManaraColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 22),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              hintText: 'ابحث في وظائف القائمة...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () => setState(() => query = ''),
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (filteredItems.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 50),
              child: Center(
                child: Text(
                  'لا توجد وظيفة مطابقة للبحث',
                  style: TextStyle(color: ManaraColors.muted),
                ),
              ),
            ),
          ...filteredItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ManagementTile(
                  title: item.title,
                  subtitle: item.title.contains('الدردشة')
                       ? unread == 0
                           ? item.subtitle
                           : '${item.subtitle} • $unread غير مقروءة'
                       : item.subtitle,
                  icon: item.icon,
                  color: item.color,
                  onTap: () => _openDetails(context, item.title),
                ),
              )),
        ],
      ),
    );
  }

  List<_ManagementItem> _itemsFor(UserRole role, String section) {
    if (role == UserRole.teacher) {
      return [
        const _ManagementItem('الإعدادات الأكاديمية', 'إدارة الصفوف والمواد والفصول والوحدات', '🏫', ManaraColors.purple),
        const _ManagementItem('إدارة المحتوى', 'أضف دروساً واربطها بالصفوف والوحدات', '📚', ManaraColors.purple),
        const _ManagementItem('فيديوهاتي', 'ارفع أو اربط فيديوهات الشرح للطلاب', '🎬', ManaraColors.blue),
        const _ManagementItem('إدارة الحسابات', 'إدارة الطلاب وأولياء الأمور المرتبطين بك', '👥', ManaraColors.mint),
        const _ManagementItem('الاختبارات', 'أنشئ اختبارات وراجع النتائج', '🧠', ManaraColors.orange),
        const _ManagementItem('التقارير', 'تحليل التقدم والنشاط والدرجات', '📊', ManaraColors.deepPurple),
        const _ManagementItem('الشهادات', 'إصدار ومتابعة شهادات الطلاب', '🏆', ManaraColors.orange),
        const _ManagementItem('الدردشة والدعم', 'تواصل مع الطلاب وأولياء الأمور', '💬', ManaraColors.purple),
        const _ManagementItem('حسابي', 'بيانات المعلم وإعدادات الحساب', '👤', ManaraColors.blue),
      ];
    }
    if (role == UserRole.guardian) {
      return [
        const _ManagementItem('أبنائي', 'عرض الحسابات والصفوف والمواد', '👨‍👩‍👧', ManaraColors.mint),
        const _ManagementItem('إضافة ابن', 'أنشئ حساب طالب واربطه بك', '➕', ManaraColors.blue),
        const _ManagementItem('تقارير الأداء', 'درجات الاختبارات والمهام المكتملة', '📈', ManaraColors.blue),
        const _ManagementItem('الشهادات', 'عرض الشهادات والإنجازات', '🏆', ManaraColors.orange),
        const _ManagementItem('الدردشة', 'تواصل مع فريق المنصة والمعلمين', '💬', ManaraColors.purple),
        const _ManagementItem('الإعدادات', 'تخصيص الإشعارات والحساب', '⚙️', ManaraColors.blue),
      ];
    }
    return [
      const _ManagementItem('الإعدادات الأكاديمية', 'الصفوف والمواد والفصول والوحدات', '🗂️', ManaraColors.purple),
      const _ManagementItem('إدارة الحسابات', 'إنشاء الطلاب وأولياء الأمور وربط الأبناء', '👥', ManaraColors.blue),
      const _ManagementItem('إدارة المعلمين', 'المعلمين والصلاحيات والتخصصات', '👩‍🏫', ManaraColors.mint),
      const _ManagementItem('إدارة المحتوى', 'إدارة الدروس والموارد التعليمية', '📚', ManaraColors.orange),
      const _ManagementItem('إدارة الاختبارات', 'إنشاء الاختبارات ومراجعة الأسئلة', '📝', ManaraColors.orange),
      const _ManagementItem('التقارير', 'إحصائيات المنصة والنشاط', '📊', ManaraColors.deepPurple),
      const _ManagementItem('إدارة الصلاحيات', 'تحكم في صلاحيات الأدوار المختلفة', '🔐', ManaraColors.blue),
      const _ManagementItem('إشعارات الفيديو', 'راجع فيديوهات المعلمين الجديدة', '📢', ManaraColors.orange),
      const _ManagementItem('إعدادات النظام', 'الدردشة ودرجة النجاح وإعدادات المنصة', '⚙️', ManaraColors.muted),
      const _ManagementItem('الدردشة مع المعلمين وأولياء الأمور', 'تواصل مباشر مع حسابات المنصة', '💬', ManaraColors.purple),
    ];
  }

  void _openDetails(BuildContext context, String title) {
    if (title == 'أبنائي') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChildrenScreen()));
      return;
    }
    if (title == 'التقارير' || title == 'تقارير الأداء') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
      return;
    }
    if (title == 'الإعدادات الأكاديمية') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AcademicSettingsScreen()));
      return;
    }
    if (title == 'إدارة الحسابات') {
      if (role == UserRole.teacher) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RecordsManager(type: RecordType.students),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccountManagementScreen()),
        );
      }
      return;
    }
    if (title == 'إدارة المعلمين') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherManagementScreen()));
      return;
    }
    if (title == 'إدارة المحتوى') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ContentManagementScreen()));
      return;
    }
    if (title == 'فيديوهاتي') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RecordsManager(type: RecordType.videos)),
      );
      return;
    }
    if (title == 'الاختبارات' || title == 'إدارة الاختبارات') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizManager()));
      return;
    }
    if (title == 'الصلاحيات' || title == 'إدارة الصلاحيات') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionsScreen()));
      return;
    }
    if (title == 'إشعارات الفيديو') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoNotificationsScreen()));
      return;
    }
    if (title == 'إعدادات النظام') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemSettingsScreen()));
      return;
    }
    if (title == 'الدردشة مع المعلمين وأولياء الأمور' ||
        title == 'الدردشة والدعم' ||
        title == 'الدردشة') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
      return;
    }
    if (title == 'إضافة ابن') {
      showAddChildDialog(context);
      return;
    }
    if (title == 'الشهادات') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificatesScreen()));
      return;
    }
    if (title == 'حسابي' || title == 'الإعدادات') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
      return;
    }
    final type = _recordTypeFor(title);
    if (type != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => RecordsManager(type: type)));
      return;
    }
    // Every item exposed by _itemsFor must have an explicit destination.
    // Keeping this guard silent prevents an obsolete server-side menu item
    // from presenting a misleading "not implemented" screen.
    return;
  }

  RecordType? _recordTypeFor(String title) {
    if (title == 'إدارة الطلاب' || title == 'أبنائي') return RecordType.students;
    if (title == 'إدارة المعلمين') return RecordType.teachers;
    if (title == 'إدارة المحتوى') return RecordType.lessons;
    if (title == 'إدارة الفيديوهات') return RecordType.videos;
    return null;
  }
}

class _ManagementItem {
  const _ManagementItem(this.title, this.subtitle, this.icon, this.color);
  final String title;
  final String subtitle;
  final String icon;
  final Color color;
}

class _ManagementTile extends StatefulWidget {
  const _ManagementTile({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
  final String title;
  final String subtitle;
  final String icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ManagementTile> createState() => _ManagementTileState();
}

class _ManagementTileState extends State<_ManagementTile> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: pressed ? .98 : 1,
      duration: const Duration(milliseconds: 120),
      child: InkWell(
      onTapDown: (_) => setState(() => pressed = true),
      onTapCancel: () => setState(() => pressed = false),
      onTap: () {
        setState(() => pressed = false);
        widget.onTap();
      },
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Row(
          children: [
            AnimatedScale(scale: pressed ? 1.08 : 1, duration: const Duration(milliseconds: 120), child: Container(width: 56, height: 56, decoration: BoxDecoration(color: widget.color.withOpacity(.13), borderRadius: BorderRadius.circular(17)), child: Center(child: Text(widget.icon, style: const TextStyle(fontSize: 28))))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 4), Text(widget.subtitle, style: const TextStyle(color: ManaraColors.muted, fontSize: 12))])),
            Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: widget.color),
          ],
        ),
      ),
      ),
    );
  }
}