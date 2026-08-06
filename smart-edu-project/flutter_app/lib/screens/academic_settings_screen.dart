import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../models/academic_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class AcademicSettingsScreen extends StatefulWidget {
  const AcademicSettingsScreen({super.key});

  @override
  State<AcademicSettingsScreen> createState() => _AcademicSettingsScreenState();
}

class _AcademicSettingsScreenState extends State<AcademicSettingsScreen> {
  String query = '';
  String gradeFilter = 'الكل';
  String termFilter = 'الكل';
  final expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات الأكاديمية', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'تحديث الهيكل',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAcademicUnitScreen())),
        backgroundColor: ManaraColors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة وحدة'),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          final grades = state.academicUnits.map((e) => e.grade).toSet().toList()..sort();
          final terms = state.academicUnits.map((e) => e.term).where((e) => e.isNotEmpty).toSet().toList()..sort();
          final filtered = state.academicUnits.where((item) {
            final text = '${item.grade} ${item.atram} ${item.subject} ${item.term} ${item.unit}'.toLowerCase();
            return (query.trim().isEmpty || text.contains(query.trim().toLowerCase())) &&
                (gradeFilter == 'الكل' || item.grade == gradeFilter) &&
                (termFilter == 'الكل' || item.term == termFilter);
          }).toList();
          final tree = _group(filtered);
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
              children: [
                _SummaryRow(units: filtered.length, grades: grades.length, subjects: filtered.map((e) => e.subject).toSet().length),
                const SizedBox(height: 14),
                _FilterBar(
                  query: query,
                  grades: grades,
                  terms: terms,
                  grade: gradeFilter,
                  term: termFilter,
                  onQuery: (value) => setState(() => query = value),
                  onGrade: (value) => setState(() => gradeFilter = value ?? 'الكل'),
                  onTerm: (value) => setState(() => termFilter = value ?? 'الكل'),
                ),
                const SizedBox(height: 16),
                _SectionHeader(count: filtered.length),
                const SizedBox(height: 8),
                 if (state.hierarchicalConfigs.isNotEmpty) ...[
                   _HierarchyConfigs(
                     configs: state.hierarchicalConfigs,
                      teachers: state.teachersForCurrentRole,
                     canCopy: state.role == UserRole.admin,
                     onCopy: (config) => _copyConfig(context, state, config),
                   ),
                   const SizedBox(height: 16),
                 ],
                if (filtered.isEmpty)
                  const _EmptyState(message: 'لا توجد وحدات مطابقة للفلاتر الحالية')
                else
                  ...tree.entries.map((entry) => _GradeNode(
                        grade: entry.key,
                        groups: entry.value,
                        expanded: expanded.contains(entry.key),
                        onToggle: () => setState(() => expanded.contains(entry.key) ? expanded.remove(entry.key) : expanded.add(entry.key)),
                        onDelete: (item) => _confirmDelete(context, item),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _copyConfig(
    BuildContext context,
    AppState state,
    HierarchicalConfig config,
  ) async {
    if (state.teachersForCurrentRole.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف معلماً أولاً لنسخ الإعداد')),
      );
      return;
    }
    TeacherProfile? selected;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('نسخ إعداد ${config.grade}'),
          content: DropdownButtonFormField<TeacherProfile>(
            value: selected,
            decoration: const InputDecoration(labelText: 'المعلم المستهدف'),
            items: state.teachersForCurrentRole
                .map((teacher) => DropdownMenuItem(
                      value: teacher,
                      child: Text(teacher.name),
                    ))
                .toList(),
            onChanged: (value) => setDialogState(() => selected = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('نسخ'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && selected != null && context.mounted) {
      final copied = state.copyAcademicConfigForTeacher(
        grade: config.grade,
        teacherId: selected!.id,
        teacherName: selected!.name,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(copied ? 'تم نسخ الإعداد للمعلم' : 'لا يوجد إعداد عام لهذا الصف'),
        ),
      );
    }
  }

  Map<String, Map<String, Map<String, List<AcademicUnit>>>> _group(List<AcademicUnit> items) {
    final result = <String, Map<String, Map<String, List<AcademicUnit>>>>{};
    for (final item in items) {
      result.putIfAbsent(item.grade, () => {});
      result[item.grade]!.putIfAbsent(item.atram.isEmpty ? 'بدون فصل' : item.atram, () => {});
      result[item.grade]![item.atram.isEmpty ? 'بدون فصل' : item.atram]!.putIfAbsent(item.subject, () => []).add(item);
    }
    return result;
  }

  Future<void> _confirmDelete(BuildContext context, AcademicUnit item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الوحدة؟'),
        content: Text('سيتم حذف «${item.unit}» من ${item.subject}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) context.read<AppState>().removeAcademicUnit(item);
  }
}

class _HierarchyConfigs extends StatelessWidget {
  const _HierarchyConfigs({
    required this.configs,
    required this.teachers,
    required this.canCopy,
    required this.onCopy,
  });

  final List<HierarchicalConfig> configs;
  final List<TeacherProfile> teachers;
  final bool canCopy;
  final ValueChanged<HierarchicalConfig> onCopy;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<HierarchicalConfig>>{};
    for (final config in configs) {
      grouped.putIfAbsent(config.grade, () => []).add(config);
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ManaraColors.lavender.withOpacity(.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إعدادات المسار الهرمي',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 5),
          const Text('نسخ إعداد المشرف للمعلمين مع الحفاظ على نسخة مستقلة لكل معلم',
              style: TextStyle(color: ManaraColors.muted, fontSize: 12)),
          const SizedBox(height: 10),
          ...grouped.entries.expand((entry) => [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                ...entry.value.map((config) {
                  final count = config.atrams
                      .expand((atram) => atram.subjects)
                      .expand((subject) => subject.terms)
                      .fold<int>(0, (sum, term) => sum + term.units.length);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      config.createdByAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.person_outline,
                      color: ManaraColors.purple,
                    ),
                    title: Text(config.createdByName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '$count وحدة • ${config.copiedFromName == null ? 'إعداد أصلي' : 'منسوخ من ${config.copiedFromName}'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: canCopy && config.createdBy == 'admin'
                        ? IconButton(
                            tooltip: 'نسخ للمعلم',
                            onPressed: () => onCopy(config),
                            icon: const Icon(Icons.content_copy_outlined),
                          )
                        : null,
                  );
                }),
              ]),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.units, required this.grades, required this.subjects});
  final int units;
  final int grades;
  final int subjects;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _StatCard(icon: Icons.school_rounded, label: 'الصفوف', value: '$grades', color: ManaraColors.purple),
          _StatCard(icon: Icons.menu_book_rounded, label: 'المواد', value: '$subjects', color: ManaraColors.blue),
          _StatCard(icon: Icons.account_tree_rounded, label: 'الوحدات', value: '$units', color: ManaraColors.orange),
        ],
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;

  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsetsDirectional.only(end: 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: ManaraColors.muted, fontSize: 11)),
          ]),
        ),
      );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.query, required this.grades, required this.terms, required this.grade, required this.term, required this.onQuery, required this.onGrade, required this.onTerm});
  final String query;
  final List<String> grades;
  final List<String> terms;
  final String grade;
  final String term;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onGrade;
  final ValueChanged<String?> onTerm;

  @override
  Widget build(BuildContext context) => Column(children: [
        TextField(
          onChanged: onQuery,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث في الصفوف أو المواد أو الوحدات...'),
        ),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(child: _dropdown('الصف', grade, ['الكل', ...grades], onGrade)),
          const SizedBox(width: 9),
          Expanded(child: _dropdown('الترم', term, ['الكل', ...terms], onTerm)),
        ]),
      ]);

  Widget _dropdown(String label, String value, List<String> values, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(
        value: values.contains(value) ? value : 'الكل',
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: values.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Row(children: [
        const Text('الهيكل الأكاديمي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const Spacer(),
        Text('$count وحدة مرتبطة', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
      ]);
}

class _GradeNode extends StatelessWidget {
  const _GradeNode({required this.grade, required this.groups, required this.expanded, required this.onToggle, required this.onDelete});
  final String grade;
  final Map<String, Map<String, List<AcademicUnit>>> groups;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<AcademicUnit> onDelete;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          ListTile(
            onTap: onToggle,
            leading: CircleAvatar(backgroundColor: ManaraColors.lavender, child: const Icon(Icons.school_rounded, color: ManaraColors.purple)),
            title: Text(grade, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('${groups.length} فصل • ${groups.values.expand((e) => e.keys).toSet().length} مادة', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
            trailing: Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
          ),
          if (expanded)
            ...groups.entries.expand((term) => [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(26, 0, 12, 5),
                    child: Row(children: [
                      const Icon(Icons.calendar_month_rounded, size: 17, color: ManaraColors.orange),
                      const SizedBox(width: 7),
                      Text(term.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  ...term.value.entries.map((subject) => Padding(
                        padding: const EdgeInsetsDirectional.only(start: 42, end: 10, bottom: 8),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 4),
                          leading: const Icon(Icons.menu_book_rounded, size: 19, color: ManaraColors.blue),
                          title: Text(subject.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${subject.value.length} وحدة', style: const TextStyle(color: ManaraColors.muted, fontSize: 11)),
                          children: subject.value
                              .map((item) => ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsetsDirectional.only(start: 26),
                                    leading: const Icon(Icons.layers_outlined, size: 18, color: ManaraColors.purple),
                                    title: Text(item.unit),
                                    subtitle: Text('${item.term} • ${item.createdByName}', style: const TextStyle(fontSize: 11, color: ManaraColors.muted)),
                                    trailing: IconButton(onPressed: () => onDelete(item), icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
                                  ))
                              .toList(),
                        ),
                      )),
                ]),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [const Icon(Icons.search_off_rounded, size: 42, color: ManaraColors.muted), const SizedBox(height: 10), Text(message, style: const TextStyle(color: ManaraColors.muted))]),
      );
}

class AddAcademicUnitScreen extends StatefulWidget {
  const AddAcademicUnitScreen({super.key});
  @override
  State<AddAcademicUnitScreen> createState() => _AddAcademicUnitScreenState();
}

class _AddAcademicUnitScreenState extends State<AddAcademicUnitScreen> {
  final grade = TextEditingController();
  final atram = TextEditingController();
  final subject = TextEditingController();
  final term = TextEditingController();
  final unit = TextEditingController();

  @override
  void dispose() {
    for (final controller in [grade, atram, subject, term, unit]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('إضافة وحدة أكاديمية', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Text('بيانات المسار الأكاديمي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('اربط الوحدة بالصف والفصل والمادة والترم حتى تظهر للمعلم والطالب في المسار الصحيح.', style: TextStyle(color: ManaraColors.muted)),
            const SizedBox(height: 18),
            for (final item in [(grade, 'الصف *'), (atram, 'الفصل الدراسي *'), (subject, 'المادة *'), (term, 'الترم *'), (unit, 'اسم الوحدة *')])
              Padding(padding: const EdgeInsets.only(bottom: 13), child: TextField(controller: item.$1, decoration: InputDecoration(labelText: item.$2))),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const Text('حفظ وربط الوحدة')),
          ],
        ),
      );

  void _save() {
    if ([grade, atram, subject, term, unit].any((controller) => controller.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل جميع حقول المسار الأكاديمي أولاً')));
      return;
    }
    context.read<AppState>().addAcademicUnit(grade: grade.text.trim(), atram: atram.text.trim(), subject: subject.text.trim(), term: term.text.trim(), unit: unit.text.trim());
    Navigator.pop(context);
  }
}