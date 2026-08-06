import 'package:flutter/material.dart';
import '../models/academic_models.dart';
import '../theme/app_theme.dart';

class AcademicScopeSelection {
  const AcademicScopeSelection({
    this.grade = '',
    this.atram = '',
    this.subject = '',
    this.term = '',
    this.unit = '',
  });

  final String grade;
  final String atram;
  final String subject;
  final String term;
  final String unit;

  AcademicScopeSelection copyWith({
    String? grade,
    String? atram,
    String? subject,
    String? term,
    String? unit,
  }) {
    return AcademicScopeSelection(
      grade: grade ?? this.grade,
      atram: atram ?? this.atram,
      subject: subject ?? this.subject,
      term: term ?? this.term,
      unit: unit ?? this.unit,
    );
  }
}

class AcademicScopeSelector extends StatefulWidget {
  const AcademicScopeSelector({
    super.key,
    required this.paths,
    required this.initialGrade,
    this.initialSelection,
    required this.onChanged,
  });

  final List<AcademicUnit> paths;
  final String initialGrade;
  final AcademicScopeSelection? initialSelection;
  final ValueChanged<AcademicScopeSelection> onChanged;

  @override
  State<AcademicScopeSelector> createState() => _AcademicScopeSelectorState();
}

class _AcademicScopeSelectorState extends State<AcademicScopeSelector> {
  late AcademicScopeSelection selection;

  @override
  void initState() {
    super.initState();
    final grades = _unique(widget.paths.map((path) => path.grade));
    final requested = widget.initialSelection;
    final initialGrade = grades.contains(requested?.grade)
        ? requested!.grade
        : grades.contains(widget.initialGrade)
            ? widget.initialGrade
        : (grades.length == 1 ? grades.first : '');
    selection = requested == null
        ? AcademicScopeSelection(grade: initialGrade)
        : requested.copyWith(grade: initialGrade);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(selection);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gradePaths = _where(grade: selection.grade);
    final atramValues = _unique(gradePaths.map((path) => path.atram));
    final atramPaths = _where(grade: selection.grade, atram: selection.atram);
    final subjectValues = _unique(atramPaths.map((path) => path.subject));
    final subjectPaths = _where(
      grade: selection.grade,
      atram: selection.atram,
      subject: selection.subject,
    );
    final termValues = _unique(subjectPaths.map((path) => path.term));
    final unitValues = _unique(
      _where(
        grade: selection.grade,
        atram: selection.atram,
        subject: selection.subject,
        term: selection.term,
      ).map((path) => path.unit),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'اختر المسار الدراسي',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'ستظهر لك الدروس والفيديوهات المرتبطة بمعلمك وباختياراتك فقط.',
          style: TextStyle(color: ManaraColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _select(
                label: 'الصف',
                value: selection.grade,
                values: _unique(widget.paths.map((path) => path.grade)),
                enabled: widget.paths.isNotEmpty,
                onChanged: (value) => _change(
                  selection.copyWith(
                    grade: value,
                    atram: '',
                    subject: '',
                    term: '',
                    unit: '',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _select(
                label: 'الفصل',
                value: selection.atram,
                values: atramValues,
                enabled: selection.grade.isNotEmpty,
                onChanged: (value) => _change(
                  selection.copyWith(
                    atram: value,
                    subject: '',
                    term: '',
                    unit: '',
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _select(
                label: 'المادة',
                value: selection.subject,
                values: subjectValues,
                enabled: selection.atram.isNotEmpty,
                onChanged: (value) => _change(
                  selection.copyWith(subject: value, term: '', unit: ''),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _select(
                label: 'الترم',
                value: selection.term,
                values: termValues,
                enabled: selection.subject.isNotEmpty,
                onChanged: (value) =>
                    _change(selection.copyWith(term: value, unit: '')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _select(
          label: 'الوحدة',
          value: selection.unit,
          values: unitValues,
          enabled: selection.term.isNotEmpty,
          onChanged: (value) => _change(selection.copyWith(unit: value)),
        ),
      ],
    );
  }

  void _change(AcademicScopeSelection next) {
    setState(() => selection = next);
    widget.onChanged(next);
  }

  List<AcademicUnit> _where({
    String grade = '',
    String atram = '',
    String subject = '',
    String term = '',
  }) {
    return widget.paths.where((path) {
      return (grade.isEmpty || path.grade == grade) &&
          (atram.isEmpty || path.atram == atram) &&
          (subject.isEmpty || path.subject == subject) &&
          (term.isEmpty || path.term == term);
    }).toList();
  }

  List<String> _unique(Iterable<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Widget _select({
    required String label,
    required String value,
    required List<String> values,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: values.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('الكل'),
        ),
        ...values.map(
          (item) => DropdownMenuItem<String>(
            value: item,
            child: Text(item, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}