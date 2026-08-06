import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});
  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  String query = '';
  String type = 'الكل';
  CertificateRecord? selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الشهادات والإصدار', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'تصدير القائمة',
            onPressed: () => _exportList(
              context,
              _filteredRecords(context.read<AppState>()),
            ),
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final state = context.watch<AppState>();
          final role = state.role;
          if ((role != UserRole.admin && role != UserRole.teacher) ||
              state.permissions['issueCertificates'] != true) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const IssueCertificateScreen()),
            ),
            backgroundColor: ManaraColors.orange,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('إصدار شهادة'),
          );
        },
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          final scopedRecords = state.certificatesForCurrentRole;
          final canIssue = (state.role == UserRole.admin ||
                  state.role == UserRole.teacher) &&
              state.permissions['issueCertificates'] == true;
          final records = _filteredRecords(state);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
            children: [
              _CertificateStats(records: scopedRecords),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث باسم الطالب أو المادة أو الصف...'),
              ),
              const SizedBox(height: 9),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'نوع الشهادة', isDense: true),
                items: ['الكل', 'شهادة تفوق', 'شهادة تقدير', 'شهادة مشاركة'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                onChanged: (value) => setState(() => type = value ?? 'الكل'),
              ),
              const SizedBox(height: 17),
              Row(children: [
                const Text('الشهادات الصادرة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text('${records.length} شهادة', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              if (records.isEmpty)
                _empty()
              else
                ...records.map((certificate) => _CertificateCard(
                      certificate: certificate,
                      selected: selected?.id == certificate.id,
                      onPreview: () => setState(() => selected = certificate),
                      onPrint: () => _print(context, certificate),
                       onShare: () => _share(context, certificate),
                       onDelete: canIssue ? () => _delete(context, certificate) : null,
                    )),
              if (selected != null) ...[
                const SizedBox(height: 14),
                 _CertificatePreview(
                   certificate: selected!,
                   onPrint: () => _print(context, selected!),
                   onShare: () => _share(context, selected!),
                 ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _empty() => Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Column(children: [Icon(Icons.workspace_premium_outlined, size: 46, color: ManaraColors.muted), SizedBox(height: 10), Text('لا توجد شهادات مطابقة', style: TextStyle(color: ManaraColors.muted))]),
      );

  List<CertificateRecord> _filteredRecords(AppState state) {
    final queryText = query.trim().toLowerCase();
    return state.certificatesForCurrentRole.where((item) {
      final label = _typeLabel(item.type);
      final searchable =
          '${item.studentName} ${item.subject} ${item.grade} ${item.term}'
              .toLowerCase();
      return (queryText.isEmpty || searchable.contains(queryText)) &&
          (type == 'الكل' || label == type);
    }).toList();
  }

  Future<void> _delete(BuildContext context, CertificateRecord certificate) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الشهادة؟'),
        content: Text('سيتم حذف شهادة ${certificate.studentName} من السجل المحلي.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<AppState>().removeCertificate(certificate.id);
      if (selected?.id == certificate.id) setState(() => selected = null);
    }
  }

  Future<void> _print(BuildContext context, CertificateRecord certificate) async {
    final document = _certificateDocument(certificate);
    await Printing.layoutPdf(
      onLayout: (_) async => document.save(),
      name: 'certificate-${certificate.id}.pdf',
    );
  }

  Future<void> _share(BuildContext context, CertificateRecord certificate) async {
    final document = _certificateDocument(certificate);
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'certificate-${certificate.id}.pdf',
    );
  }

  Future<void> _exportList(
    BuildContext context,
    List<CertificateRecord> records,
  ) async {
    if (records.isEmpty) {
      _info(context, 'لا توجد شهادات لتصديرها');
      return;
    }
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('منصة منارة المعرفة',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Text('سجل الشهادات الصادرة',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 14),
              pw.Table.fromTextArray(
                headers: const ['الطالب', 'نوع الشهادة', 'المادة', 'الدرجة', 'التاريخ'],
                data: records
                    .map((record) => [
                          record.studentName,
                          _typeLabel(record.type),
                          record.subject,
                          '${record.average}%',
                          record.date.split('T').first,
                        ])
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) async => document.save(),
      name: 'manara-certificates.pdf',
    );
  }

  pw.Document _certificateDocument(CertificateRecord certificate) {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(34),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.amber, width: 3),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('منصة منارة المعرفة',
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 28),
                  pw.Text(_typeLabel(certificate.type),
                      style: pw.TextStyle(
                          fontSize: 28,
                          color: PdfColors.brown,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),
                  pw.Text('تُمنح إلى الطالب/ة',
                      style: const pw.TextStyle(fontSize: 15)),
                  pw.SizedBox(height: 8),
                  pw.Text(certificate.studentName,
                      style: pw.TextStyle(
                          fontSize: 26, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 18),
                  pw.Text(
                    'تقديراً لإنجازه في مادة ${certificate.subject}\n'
                    '${certificate.grade} — ${certificate.term}\n'
                    'المتوسط: ${certificate.average}%',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 16),
                  ),
                  pw.SizedBox(height: 26),
                  pw.Text('المعلم: ${certificate.teacherName}'),
                  pw.Text('التاريخ: ${certificate.date.split('T').first}'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return document;
  }

  void _info(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  static String _typeLabel(CertificateType type) {
    switch (type) {
      case CertificateType.excellence:
        return 'شهادة تفوق';
      case CertificateType.appreciation:
        return 'شهادة تقدير';
      case CertificateType.participation:
        return 'شهادة مشاركة';
    }
  }
}

class _CertificateStats extends StatelessWidget {
  const _CertificateStats({required this.records});
  final List<CertificateRecord> records;
  @override
  Widget build(BuildContext context) {
    final excellence = records.where((e) => e.type == CertificateType.excellence).length;
    final average = records.isEmpty ? 0 : records.map((e) => e.average).reduce((a, b) => a + b) ~/ records.length;
    return Row(children: [
      _box('الإجمالي', '${records.length}', Icons.workspace_premium_rounded, ManaraColors.orange),
      _box('شهادات التفوق', '$excellence', Icons.emoji_events_rounded, ManaraColors.purple),
      _box('متوسط الدرجات', '$average%', Icons.insights_rounded, ManaraColors.blue),
    ]);
  }
  Widget _box(String label, String value, IconData icon, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsetsDirectional.only(end: 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 6), Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 10, color: ManaraColors.muted))]),
        ),
      );
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({required this.certificate, required this.selected, required this.onPreview, required this.onPrint, required this.onShare, required this.onDelete});
  final CertificateRecord certificate;
  final bool selected;
  final VoidCallback onPreview;
  final VoidCallback onPrint;
  final VoidCallback onShare;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: selected ? ManaraColors.orange : Colors.transparent)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(radius: 25, backgroundColor: Color(0xFFFFF2DB), child: Text('🏆', style: TextStyle(fontSize: 23))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_typeLabel(certificate.type), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text(certificate.studentName, style: const TextStyle(color: ManaraColors.deepPurple, fontWeight: FontWeight.bold)),
              Text('${certificate.subject} • ${certificate.grade} • ${certificate.term}', style: const TextStyle(color: ManaraColors.muted, fontSize: 12)),
              Text('المعلم: ${certificate.teacherName} • المتوسط: ${certificate.average}%', style: const TextStyle(color: ManaraColors.muted, fontSize: 11)),
              const SizedBox(height: 7),
              Wrap(spacing: 6, children: [
                Chip(label: Text(certificate.date.split('T').first), visualDensity: VisualDensity.compact),
                Chip(label: Text('رقم ${certificate.id.split('-').last}'), visualDensity: VisualDensity.compact, backgroundColor: ManaraColors.lavender),
              ]),
            ])),
            Column(children: [
              TextButton(onPressed: onPreview, child: const Text('عرض')),
              IconButton(tooltip: 'طباعة', onPressed: onPrint, icon: const Icon(Icons.print_outlined, color: ManaraColors.blue)),
               IconButton(tooltip: 'مشاركة', onPressed: onShare, icon: const Icon(Icons.share_outlined, color: ManaraColors.purple)),
               if (onDelete != null)
                 IconButton(tooltip: 'حذف', onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
            ]),
          ]),
        ),
      );
}

class _CertificatePreview extends StatelessWidget {
  const _CertificatePreview({required this.certificate, required this.onPrint, required this.onShare});
  final CertificateRecord certificate;
  final VoidCallback onPrint;
  final VoidCallback onShare;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: ManaraColors.orange.withOpacity(.35))),
        child: Column(children: [
          Row(children: [
            const Text('معاينة الشهادة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Spacer(),
             IconButton(onPressed: onShare, tooltip: 'مشاركة', icon: const Icon(Icons.share_outlined, color: ManaraColors.purple)),
            FilledButton.icon(onPressed: onPrint, icon: const Icon(Icons.print_outlined), label: const Text('طباعة')),
          ]),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 30, 18, 25),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF2),
              border: Border.all(color: const Color(0xFFD9BC6B), width: 3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(children: [
              const Text('منصة منارة المعرفة', style: TextStyle(color: Color(0xFF80632B), fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(_typeLabel(certificate.type), style: const TextStyle(fontSize: 24, color: Color(0xFF80632B), fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('تُمنح إلى الطالب/ة', style: TextStyle(color: ManaraColors.muted)),
              Text(certificate.studentName, style: const TextStyle(fontSize: 25, color: ManaraColors.deepPurple, fontWeight: FontWeight.w900)),
              Text('لتفوقه/ا في مادة ${certificate.subject}\n${certificate.grade} — ${certificate.term}', textAlign: TextAlign.center, style: const TextStyle(color: ManaraColors.muted, height: 1.6)),
              const SizedBox(height: 16),
              Text('المعلم: ${certificate.teacherName}\nالتاريخ: ${certificate.date.split('T').first}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF80632B))),
            ]),
          ),
        ]),
      );
}

class IssueCertificateScreen extends StatefulWidget {
  const IssueCertificateScreen({super.key});
  @override
  State<IssueCertificateScreen> createState() => _IssueCertificateScreenState();
}

class _IssueCertificateScreenState extends State<IssueCertificateScreen> {
  StudentProfile? student;
  TeacherProfile? teacher;
  CertificateType type = CertificateType.excellence;
  final subject = TextEditingController();
  final grade = TextEditingController();
  final atram = TextEditingController();
  final term = TextEditingController();
  final note = TextEditingController();

  @override
  void dispose() {
    for (final controller in [subject, grade, atram, term, note]) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('إصدار شهادة', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text('بيانات المستفيد والإصدار', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          DropdownButtonFormField<StudentProfile>(
            value: student,
            decoration: const InputDecoration(labelText: 'الطالب *'),
            items: state.studentsForCurrentRole
                .map((item) =>
                    DropdownMenuItem(value: item, child: Text(item.name)))
                .toList(),
            onChanged: (value) => setState(() => student = value),
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<TeacherProfile>(
            value: teacher,
            decoration: const InputDecoration(labelText: 'المعلم *'),
            items: state.teachersForCurrentRole
                .map((item) =>
                    DropdownMenuItem(value: item, child: Text(item.name)))
                .toList(),
            onChanged: (value) => setState(() => teacher = value),
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<CertificateType>(
            value: type,
            decoration: const InputDecoration(labelText: 'نوع الشهادة'),
            items: const [
              DropdownMenuItem(value: CertificateType.excellence, child: Text('شهادة تفوق')),
              DropdownMenuItem(value: CertificateType.appreciation, child: Text('شهادة تقدير')),
              DropdownMenuItem(value: CertificateType.participation, child: Text('شهادة مشاركة')),
            ],
            onChanged: (value) => setState(() => type = value ?? CertificateType.excellence),
          ),
          const SizedBox(height: 13),
          for (final item in [(subject, 'المادة *'), (grade, 'الصف *'), (atram, 'الفصل الدراسي *'), (term, 'الترم *'), (note, 'ملاحظة (اختياري)')])
            Padding(padding: const EdgeInsets.only(bottom: 13), child: TextField(controller: item.$1, maxLines: item.$2.startsWith('ملاحظة') ? 3 : 1, decoration: InputDecoration(labelText: item.$2))),
          FilledButton.icon(onPressed: () => _save(state), icon: const Icon(Icons.workspace_premium_outlined), label: const Text('إصدار وحفظ الشهادة')),
        ],
      ),
    );
  }

  void _save(AppState state) {
    if (student == null || teacher == null || [subject, grade, atram, term].any((c) => c.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل الطالب والمعلم وكل بيانات المسار الأكاديمي')));
      return;
    }
    final before = state.certificates.length;
    state.issueCertificate(studentId: student!.id, studentName: student!.name, teacherId: teacher!.id, teacherName: teacher!.name, type: type, subject: subject.text.trim(), grade: grade.text.trim(), atram: atram.text.trim(), term: term.text.trim(), note: note.text.trim());
    if (state.certificates.length == before) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هذه الشهادة موجودة مسبقاً لهذا الطالب والمسار')));
      return;
    }
    Navigator.pop(context);
  }
}

String _typeLabel(CertificateType type) {
  switch (type) {
    case CertificateType.excellence:
      return 'شهادة تفوق';
    case CertificateType.appreciation:
      return 'شهادة تقدير';
    case CertificateType.participation:
      return 'شهادة مشاركة';
  }
}