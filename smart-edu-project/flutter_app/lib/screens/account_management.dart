import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  int tab = 0;
  String search = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الحسابات', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: ManaraColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tab == 0 ? 'إضافة طالب' : 'إضافة ولي أمر'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: TextField(
              onChanged: (value) => setState(() => search = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'بحث بالاسم أو اسم المستخدم أو رقم الجوال',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('الطلاب'), icon: Icon(Icons.school_outlined)),
                ButtonSegment(value: 1, label: Text('أولياء الأمور'), icon: Icon(Icons.family_restroom)),
              ],
              selected: {tab},
              onSelectionChanged: (value) => setState(() => tab = value.first),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: tab == 0 ? _students(state) : _guardians(state)),
        ],
      ),
    );
  }

  Widget _students(AppState state) {
    final sourceStudents = state.studentsForCurrentRole;
    final records = sourceStudents.where((student) {
      final parent = _parentFor(state, student.parentId);
      return search.isEmpty ||
          student.name.toLowerCase().contains(search) ||
          student.username.toLowerCase().contains(search) ||
          student.primaryGrade.toLowerCase().contains(search) ||
          (parent?.name.toLowerCase().contains(search) ?? false);
    }).toList();
    if (records.isEmpty) return _empty('لا يوجد طلاب مطابقون للبحث', Icons.school_outlined);
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final student = records[index];
        final parent = _parentFor(state, student.parentId);
        return _AccountCard(
          icon: '🎒',
          title: student.name,
          details: [
            student.primaryGrade,
            'اسم المستخدم: ${student.username}',
             if (student.studentIdNumber.isNotEmpty) 'رقم الطالب: ${student.studentIdNumber}',
             if (student.nationalId.isNotEmpty) 'رقم الهوية: ${student.nationalId}',
             if (student.parentPhoneNumber.isNotEmpty) 'جوال ولي الأمر: ${student.parentPhoneNumber}',
            parent == null ? 'ولي الأمر: غير مرتبط' : 'ولي الأمر: ${parent.name}',
          ],
          onEdit: () => _openEditor(context, student: student),
          onDelete: () => _confirmDelete(
            context,
            title: 'حذف الطالب؟',
            action: () => state.removeStudent(student.id),
          ),
        );
      },
    );
  }

  Widget _guardians(AppState state) {
    final records = state.guardiansForCurrentRole.where((guardian) {
      return search.isEmpty ||
          guardian.name.toLowerCase().contains(search) ||
          guardian.username.toLowerCase().contains(search) ||
          guardian.phoneNumber.contains(search) ||
          guardian.nationalId.contains(search);
    }).toList();
    if (records.isEmpty) return _empty('لا يوجد أولياء أمور مطابقون للبحث', Icons.family_restroom);
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final guardian = records[index];
        final children = state.studentsForCurrentRole
            .where((student) => guardian.childIds.contains(student.id))
            .toList();
        return _AccountCard(
          icon: '👨‍👩‍👧',
          title: guardian.name,
          details: [
            'اسم المستخدم: ${guardian.username}',
            if (guardian.phoneNumber.isNotEmpty) 'الجوال: ${guardian.phoneNumber}',
            if (guardian.nationalId.isNotEmpty) 'رقم الهوية: ${guardian.nationalId}',
            'المنشئ: ${guardian.createdByName}',
            'الأبناء: ${children.isEmpty ? 'لا يوجد' : children.map((child) => child.name).join('، ')}',
          ],
          onEdit: () => _openEditor(context, guardian: guardian),
          onDelete: () => _confirmDelete(
            context,
            title: 'حذف ولي الأمر؟',
            action: () => state.removeGuardian(guardian.id),
          ),
        );
      },
    );
  }

  GuardianProfile? _parentFor(AppState state, String? id) {
    if (id == null) return null;
    for (final parent in state.guardiansForCurrentRole) {
      if (parent.id == id) return parent;
    }
    return null;
  }

  Widget _empty(String text, IconData icon) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 54, color: ManaraColors.purple.withOpacity(.45)),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: ManaraColors.muted)),
        ]),
      );

  void _openEditor(BuildContext context, {StudentProfile? student, GuardianProfile? guardian}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountEditorScreen(student: student, guardian: guardian),
      ),
    );
  }

  void _confirmDelete(BuildContext context, {required String title, required VoidCallback action}) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: const Text('سيتم حذف الحساب من البيانات المحلية. لا يمكن التراجع عن هذه العملية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              action();
              Navigator.pop(context);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.icon,
    required this.title,
    required this.details,
    required this.onEdit,
    required this.onDelete,
  });
  final String icon;
  final String title;
  final List<String> details;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 27, backgroundColor: ManaraColors.lavender, child: Text(icon, style: const TextStyle(fontSize: 24))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                ...details.map((detail) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(detail, style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
                    )),
              ]),
            ),
            Column(children: [
              IconButton(onPressed: onEdit, tooltip: 'تعديل', icon: const Icon(Icons.edit_outlined, color: ManaraColors.blue)),
              IconButton(onPressed: onDelete, tooltip: 'حذف', icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
            ]),
          ],
        ),
      );
}

class AccountEditorScreen extends StatefulWidget {
  const AccountEditorScreen({super.key, this.student, this.guardian});
  final StudentProfile? student;
  final GuardianProfile? guardian;

  @override
  State<AccountEditorScreen> createState() => _AccountEditorScreenState();
}

class _AccountEditorScreenState extends State<AccountEditorScreen> {
  late final TextEditingController name;
  late final TextEditingController username;
  late final TextEditingController password;
  late final TextEditingController grade;
  late final TextEditingController phone;
  late final TextEditingController nationalId;
  late final TextEditingController parentPhone;
  late final TextEditingController studentIdNumber;
  String? parentId;
  String? teacherId;
  bool canChangeGrade = false;
  final selectedChildren = <String>{};

  bool get isGuardian => widget.guardian != null || widget.student == null && _modeGuardian;
  bool _modeGuardian = false;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    final guardian = widget.guardian;
    _modeGuardian = guardian != null;
    name = TextEditingController(text: student?.name ?? guardian?.name ?? '');
    username = TextEditingController(text: student?.username ?? guardian?.username ?? '');
    password = TextEditingController(text: guardian?.password ?? '');
    grade = TextEditingController(text: student?.primaryGrade ?? 'الصف الرابع');
    phone = TextEditingController(text: guardian?.phoneNumber ?? '');
    nationalId = TextEditingController(text: guardian?.nationalId ?? '');
    parentPhone = TextEditingController(text: student?.parentPhoneNumber ?? '');
    studentIdNumber = TextEditingController(text: student?.studentIdNumber ?? '');
    parentId = student?.parentId;
    teacherId = student?.teacherId;
    canChangeGrade = student?.canChangeGrade ?? false;
    selectedChildren.addAll(guardian?.childIds ?? const []);
  }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    password.dispose();
    grade.dispose();
    phone.dispose();
    nationalId.dispose();
    parentPhone.dispose();
    studentIdNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final editing = widget.student != null || widget.guardian != null;
    return Scaffold(
      appBar: AppBar(title: Text('${editing ? 'تعديل' : 'إضافة'} ${isGuardian ? 'ولي أمر' : 'طالب'}', style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
        children: [
          if (!editing) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('طالب'), icon: Icon(Icons.school_outlined)),
                ButtonSegment(value: true, label: Text('ولي أمر'), icon: Icon(Icons.family_restroom)),
              ],
              selected: {isGuardian},
              onSelectionChanged: (value) => setState(() => _modeGuardian = value.first),
            ),
            const SizedBox(height: 18),
          ],
          TextField(controller: name, decoration: InputDecoration(labelText: isGuardian ? 'اسم ولي الأمر *' : 'اسم الطالب *')),
          const SizedBox(height: 13),
          TextField(controller: username, decoration: const InputDecoration(labelText: 'اسم المستخدم *')),
          const SizedBox(height: 13),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
          if (!isGuardian) ...[
            const SizedBox(height: 13),
            TextField(controller: grade, decoration: const InputDecoration(labelText: 'الصف الأساسي *')),
            const SizedBox(height: 13),
            TextField(controller: studentIdNumber, decoration: const InputDecoration(labelText: 'رقم الطالب / الهوية')),
            const SizedBox(height: 13),
            TextField(controller: nationalId, decoration: const InputDecoration(labelText: 'رقم الهوية الوطنية')),
            const SizedBox(height: 13),
            TextField(controller: parentPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم جوال ولي الأمر')),
            SwitchListTile(
              value: canChangeGrade,
              onChanged: (value) => setState(() => canChangeGrade = value),
              title: const Text('السماح بتغيير الصف'),
              activeColor: ManaraColors.purple,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String?>(
              value: parentId,
              decoration: const InputDecoration(labelText: 'ولي الأمر المرتبط'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('بدون ولي أمر')),
                ...state.guardiansForCurrentRole.map(
                  (parent) => DropdownMenuItem<String?>(
                    value: parent.id,
                    child: Text(parent.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => parentId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: teacherId,
              decoration: const InputDecoration(labelText: 'المعلم المرتبط'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('بدون معلم محدد'),
                ),
                ...state.teachersForCurrentRole.map(
                  (teacher) => DropdownMenuItem<String?>(
                    value: teacher.id,
                    child: Text('${teacher.name} • ${teacher.subject ?? 'بدون تخصص'}'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => teacherId = value),
            ),
          ] else ...[
            const SizedBox(height: 13),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الجوال *')),
            const SizedBox(height: 13),
            TextField(controller: nationalId, decoration: const InputDecoration(labelText: 'رقم الهوية')),
            const SizedBox(height: 18),
            const Text('ربط الأبناء', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...state.studentsForCurrentRole.map((student) => CheckboxListTile(
                  value: selectedChildren.contains(student.id),
                  onChanged: (value) => setState(() => value == true ? selectedChildren.add(student.id) : selectedChildren.remove(student.id)),
                  title: Text(student.name),
                  subtitle: Text(student.primaryGrade),
                  contentPadding: EdgeInsets.zero,
                  activeColor: ManaraColors.purple,
                )),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(onPressed: () => _save(state), icon: const Icon(Icons.save_outlined), label: const Text('حفظ الحساب')),
        ],
      ),
    );
  }

  void _save(AppState state) {
    if (name.text.trim().isEmpty || username.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل الاسم واسم المستخدم')));
      return;
    }
    final accountId = widget.student?.id ?? widget.guardian?.id;
    if (!state.usernameAvailable(username.text, exceptId: accountId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اسم المستخدم مستخدم مسبقاً')));
      return;
    }
    final identity = isGuardian
        ? nationalId.text.trim()
        : (studentIdNumber.text.trim().isNotEmpty ? studentIdNumber.text.trim() : nationalId.text.trim());
    if (identity.isNotEmpty && !state.identityAvailable(identity, exceptId: accountId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رقم الهوية أو الرقم التعريفي مستخدم مسبقاً')));
      return;
    }
    if (isGuardian && phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل رقم الجوال لولي الأمر')));
      return;
    }
    if (widget.student != null) {
      state.updateStudent(
        id: widget.student!.id,
        name: name.text.trim(),
        username: username.text.trim(),
        grade: grade.text.trim(),
        parentId: parentId,
        teacherId: teacherId ?? '',
        password: password.text,
        parentPhoneNumber: parentPhone.text.trim(),
        studentIdNumber: studentIdNumber.text.trim(),
        nationalId: nationalId.text.trim(),
        canChangeGrade: canChangeGrade,
      );
    } else if (widget.guardian != null) {
      state.updateGuardian(id: widget.guardian!.id, name: name.text.trim(), username: username.text.trim(), phoneNumber: phone.text.trim(), nationalId: nationalId.text.trim(), password: password.text, childIds: selectedChildren.toList());
    } else if (isGuardian) {
      state.addGuardian(name: name.text.trim(), username: username.text.trim(), phoneNumber: phone.text.trim(), nationalId: nationalId.text.trim(), password: password.text, childIds: selectedChildren.toList());
    } else {
      state.addStudent(
        name: name.text.trim(),
        username: username.text.trim(),
        grade: grade.text.trim(),
        parentId: parentId,
        teacherId: teacherId,
        password: password.text,
        parentPhoneNumber: parentPhone.text.trim(),
        studentIdNumber: studentIdNumber.text.trim(),
        nationalId: nationalId.text.trim(),
        canChangeGrade: canChangeGrade,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حفظ حساب ${isGuardian ? 'ولي الأمر' : 'الطالب'} بنجاح')),
    );
    Navigator.pop(context);
  }
}