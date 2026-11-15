import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../services/coloring_cloud.dart';
import '../services/drawing_studio.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';

/// «استوديو الرسم»: شاشةٌ مستقلّةٌ عن ألعاب التلوين — طبقات، وفرشٌ احترافية،
/// وأشكالٌ ومسطرة، وتدرّج، وقطّارةٌ ولوحةُ ألوانٍ دقيقة تُحفظ فيها ألوانُ
/// الطالب، وتراجعٌ وإعادة.
class DrawingStudioScreen extends StatefulWidget {
  const DrawingStudioScreen({super.key, this.account, this.saveToPhotos, this.initial});

  final ColoringAccount? account;

  /// للاختبار: الحفظُ في الاستوديو.
  final Future<bool> Function(Uint8List png)? saveToPhotos;

  /// مشروعٌ يُفتح بدل ورقةٍ بيضاء.
  final StudioController? initial;

  @override
  State<DrawingStudioScreen> createState() => DrawingStudioScreenState();
}

enum StudioTool { brush, shape, gradient, eyedropper }

String _t(String ar, String en) => StudentSettings.isArabic ? ar : en;

class DrawingStudioScreenState extends State<DrawingStudioScreen> {
  late StudioController _controller = widget.initial ?? StudioController();
  StudioTool _tool = StudioTool.brush;
  StudioBrush _brush = StudioBrush.inkPen;
  StudioShape _shape = StudioShape.rectangle;
  bool _filled = false;
  bool _radial = false;
  bool _ruler = false;
  double _size = 8;
  double _opacity = 1;
  Color _color = const Color(0xFF111827);
  Color _color2 = const Color(0xFFFFFFFF);
  List<Color> _custom = const [];
  bool _saving = false;
  int? _pointer;
  String? _message;
  Timer? _messageTimer;

  String get _owner => widget.account?.studentId ?? 'guest';

  @visibleForTesting
  StudioController get controller => _controller;
  @visibleForTesting
  Color get color => _color;
  @visibleForTesting
  StudioTool get tool => _tool;
  @visibleForTesting
  List<Color> get customColors => _custom;

  static const brushes = <StudioBrush, (IconData, String, String)>{
    StudioBrush.inkPen: (Icons.edit_rounded, 'قلم حبر', 'Ink pen'),
    StudioBrush.pencil: (Icons.create_outlined, 'رصاص', 'Pencil'),
    StudioBrush.inking: (Icons.draw_rounded, 'تحبير', 'Inking'),
    StudioBrush.oil: (Icons.brush_rounded, 'زيتية', 'Oil'),
    StudioBrush.watercolor: (Icons.water_drop_rounded, 'مائية', 'Watercolor'),
    StudioBrush.airbrush: (Icons.blur_on_rounded, 'بخّاخ', 'Airbrush'),
    StudioBrush.marker: (Icons.border_color_rounded, 'تحديد', 'Marker'),
    StudioBrush.eraser: (Icons.auto_fix_normal_rounded, 'ممحاة', 'Eraser'),
  };

  static const shapes = <StudioShape, (IconData, String, String)>{
    StudioShape.line: (Icons.horizontal_rule_rounded, 'خط', 'Line'),
    StudioShape.rectangle: (Icons.crop_square_rounded, 'مستطيل', 'Rectangle'),
    StudioShape.ellipse: (Icons.circle_outlined, 'بيضاوي', 'Ellipse'),
    StudioShape.triangle: (Icons.change_history_rounded, 'مثلث', 'Triangle'),
    StudioShape.star: (Icons.star_outline_rounded, 'نجمة', 'Star'),
    StudioShape.hexagon: (Icons.hexagon_outlined, 'سداسي', 'Hexagon'),
    StudioShape.arrow: (Icons.arrow_forward_rounded, 'سهم', 'Arrow'),
  };

  static const quickColors = <Color>[
    Color(0xFF111827), Color(0xFFFFFFFF), Color(0xFF6B7280), Color(0xFFEF4444),
    Color(0xFFF97316), Color(0xFFFACC15), Color(0xFF84CC16), Color(0xFF22C55E),
    Color(0xFF14B8A6), Color(0xFF0EA5E9), Color(0xFF2563EB), Color(0xFF7C3AED),
    Color(0xFFDB2777), Color(0xFF92400E), Color(0xFFFDE0C4), Color(0xFFC68642),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(StudioColors.load(_owner).then((colors) {
      if (mounted) setState(() => _custom = colors);
    }));
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    if (widget.initial != _controller || widget.initial == null) _controller.dispose();
    super.dispose();
  }

  StudioPen get _pen => StudioPen(
        brush: _brush,
        color: _color,
        color2: _color2,
        size: _size,
        opacity: _opacity,
        shape: _tool == StudioTool.shape ? _shape : null,
        filled: _filled,
        gradient: _tool == StudioTool.gradient,
        radial: _radial,
        ruler: _ruler,
      );

  void _toast(String text) {
    _messageTimer?.cancel();
    setState(() => _message = text);
    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = null);
    });
  }

  void _setColor(Color c) {
    HapticFeedback.selectionClick();
    setState(() {
      _color = c;
      if (_tool == StudioTool.eyedropper) _tool = StudioTool.brush;
      if (_brush == StudioBrush.eraser) _brush = StudioBrush.inkPen;
    });
  }

  Future<void> _sample(Offset at) async {
    final picked = await _controller.sampleAt(at);
    if (!mounted || picked == null) return;
    setState(() {
      _color = picked;
      _tool = StudioTool.brush;
      if (_brush == StudioBrush.eraser) _brush = StudioBrush.inkPen;
    });
    _toast(_t('أخذتُ اللون من الرسمة', 'Colour picked from the drawing'));
  }

  Future<void> _saveColor(Color c) async {
    final kept = await StudioColors.add(_owner, c);
    if (mounted) setState(() => _custom = kept);
  }

  // ── الحفظ ──

  Future<void> _save() async {
    final target = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            key: const ValueKey('studio-save-project'),
            leading: const Icon(Icons.folder_rounded),
            title: Text(_t('احفظ في «مشاريعي» بطبقاتها', 'Save to My projects (keeps layers)')),
            onTap: () => Navigator.pop(context, 'project'),
          ),
          ListTile(
            key: const ValueKey('studio-save-photos'),
            leading: const Icon(Icons.photo_library_rounded),
            title: Text(_t('احفظ صورةً في استوديو الجهاز', 'Save a picture to Photos')),
            onTap: () => Navigator.pop(context, 'photos'),
          ),
        ]),
      ),
    );
    if (target == null || !mounted) return;
    setState(() => _saving = true);
    try {
      if (target == 'project') {
        await StudioProjects.save(_owner, _controller);
        _toast(_t('حُفظ المشروع ✓', 'Project saved ✓'));
      } else {
        final png = await _controller.toPng();
        final saver = widget.saveToPhotos ??
            (Uint8List bytes) async {
              if (!await Gal.hasPermission() && !await Gal.requestPermission()) return false;
              await Gal.putImageBytes(bytes, name: 'manara_studio_${DateTime.now().millisecondsSinceEpoch}');
              return true;
            };
        final ok = png != null && await saver(png).catchError((_) => false);
        _toast(ok ? _t('حُفظت الصورة في الاستوديو ✓', 'Saved to Photos ✓') : _t('تعذّر الحفظ في الاستوديو', 'Could not save to Photos'));
      }
      StudentSoundService.instance.playTap();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openProjects() async {
    final projects = await StudioProjects.load(_owner);
    if (!mounted) return;
    final picked = await showModalBottomSheet<StudioController>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: projects.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_t('لا مشاريع محفوظة بعد', 'No saved projects yet'), textAlign: TextAlign.center),
                )
              : Wrap(
                  key: const ValueKey('studio-projects-list'),
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _newProjectTile(context),
                    for (final (i, p) in projects.indexed)
                      GestureDetector(
                        key: ValueKey('studio-project-$i'),
                        onTap: () => Navigator.pop(context, p),
                        child: Container(
                          width: 110,
                          height: 110,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
                          ),
                          child: CustomPaint(painter: StudioPainter(p)),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final old = _controller;
    setState(() => _controller = picked);
    if (old != widget.initial) old.dispose();
  }

  Widget _newProjectTile(BuildContext context) => GestureDetector(
        key: const ValueKey('studio-project-new'),
        onTap: () => Navigator.pop(context, StudioController()),
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFF5F3FF),
            border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
          ),
          child: const Icon(Icons.add_rounded, size: 40, color: Color(0xFF7C3AED)),
        ),
      );

  // ── لوحةُ الألوان الدقيقة ──

  Future<void> _openPicker() async {
    final chosen = await showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ColorPickerSheet(
        initial: _color,
        custom: _custom,
        onSave: (c) async {
          await _saveColor(c);
          return _custom;
        },
      ),
    );
    if (chosen != null && mounted) _setColor(chosen);
  }

  // ── البناء ──

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth > box.maxHeight * 1.05 && box.maxWidth >= 600;
            final board = Padding(padding: const EdgeInsets.all(8), child: Center(child: _board()));
            final panel = _panel(context, wide: wide);
            return Stack(children: [
              Column(children: [
                _topBar(context),
                Expanded(
                  child: wide
                      ? Row(children: [
                          Expanded(child: board),
                          SizedBox(
                            width: math.min(360, box.maxWidth * 0.38),
                            child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(4, 4, 12, 16), child: panel),
                          ),
                        ])
                      : Column(children: [
                          Expanded(flex: 5, child: board),
                          Expanded(
                            flex: 4,
                            child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: panel),
                          ),
                        ]),
                ),
              ]),
              if (_message != null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: IgnorePointer(
                    child: Container(
                      key: const ValueKey('studio-message'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xEE1F2937), borderRadius: BorderRadius.circular(14)),
                      child: Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 8, 0),
        child: Row(children: [
          IconButton(
            tooltip: _t('رجوع', 'Back'),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '🎨 ${_t('استوديو الرسم', 'Drawing Studio')}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: StudentSurface.ink(context)),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                key: const ValueKey('studio-undo'),
                tooltip: _t('تراجع', 'Undo'),
                onPressed: _controller.canUndo ? _controller.undo : null,
                icon: const Icon(Icons.undo_rounded),
              ),
              IconButton(
                key: const ValueKey('studio-redo'),
                tooltip: _t('إعادة', 'Redo'),
                onPressed: _controller.canRedo ? _controller.redo : null,
                icon: const Icon(Icons.redo_rounded),
              ),
            ]),
          ),
          IconButton(
            key: const ValueKey('studio-projects'),
            tooltip: _t('مشاريعي', 'My projects'),
            onPressed: _openProjects,
            icon: const Icon(Icons.folder_open_rounded),
          ),
          FilledButton.icon(
            key: const ValueKey('studio-save'),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(_t('حفظ', 'Save')),
          ),
        ]),
      );

  Widget _board() => LayoutBuilder(builder: (context, box) {
        final side = math.max(1.0, math.min(box.maxWidth, box.maxHeight));
        Offset toDoc(Offset local) => local / side * studioSize;
        return SizedBox.square(
          dimension: side,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFC4B5FD), width: 3),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: StatefulBuilder(builder: (context, _) {
                return Listener(
                  key: const ValueKey('studio-board'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) {
                    if (_pointer != null) return;
                    _pointer = e.pointer;
                    if (_tool == StudioTool.eyedropper) return;
                    _controller.begin(toDoc(e.localPosition), _pen);
                  },
                  onPointerMove: (e) {
                    if (e.pointer != _pointer || _tool == StudioTool.eyedropper) return;
                    _controller.move(toDoc(e.localPosition));
                  },
                  onPointerUp: (e) {
                    if (e.pointer != _pointer) return;
                    _pointer = null;
                    if (_tool == StudioTool.eyedropper) {
                      unawaited(_sample(toDoc(e.localPosition)));
                    } else {
                      _controller.end();
                    }
                  },
                  onPointerCancel: (e) {
                    if (e.pointer != _pointer) return;
                    _pointer = null;
                    _controller.end();
                  },
                  child: RepaintBoundary(
                    child: CustomPaint(
                      isComplex: true,
                      willChange: true,
                      size: Size.square(side),
                      painter: StudioPainter(_controller),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      });

  Widget _section(BuildContext context, String title, Widget child) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: StudentSurface.mutedInk(context))),
          const SizedBox(height: 6),
          child,
        ]),
      );

  Widget _chip({required Key key, required IconData icon, required String label, required bool selected, required VoidCallback onTap}) =>
      GestureDetector(
        key: key,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEDE9FE) : StudentSurface.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xFF7C3AED) : StudentSurface.outline(context), width: selected ? 2 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: selected ? const Color(0xFF7C3AED) : StudentSurface.ink(context)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: StudentSurface.ink(context))),
          ]),
        ),
      );

  Widget _dot(Color c, {required Key key, VoidCallback? onTap, double size = 30, bool selected = false}) => GestureDetector(
        key: key,
        onTap: onTap ?? () => _setColor(c),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? const Color(0xFF7C3AED) : const Color(0x33000000), width: selected ? 3 : 1),
          ),
        ),
      );

  Widget _panel(BuildContext context, {required bool wide}) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: StudentSurface.glass(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: StudentSurface.outline(context)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          _section(
            context,
            _t('الفرش', 'Brushes'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in brushes.entries)
                _chip(
                  key: ValueKey('studio-brush-${e.key.name}'),
                  icon: e.value.$1,
                  label: _t(e.value.$2, e.value.$3),
                  selected: _tool == StudioTool.brush && _brush == e.key,
                  onTap: () => setState(() {
                    _tool = StudioTool.brush;
                    _brush = e.key;
                  }),
                ),
            ]),
          ),
          _section(
            context,
            _t('أدوات', 'Tools'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _chip(
                key: const ValueKey('studio-tool-shape'),
                icon: Icons.category_rounded,
                label: _t('أشكال', 'Shapes'),
                selected: _tool == StudioTool.shape,
                onTap: () => setState(() => _tool = StudioTool.shape),
              ),
              _chip(
                key: const ValueKey('studio-tool-gradient'),
                icon: Icons.gradient_rounded,
                label: _t('تدرّج', 'Gradient'),
                selected: _tool == StudioTool.gradient,
                onTap: () => setState(() => _tool = StudioTool.gradient),
              ),
              _chip(
                key: const ValueKey('studio-tool-eyedropper'),
                icon: Icons.colorize_rounded,
                label: _t('قطّارة', 'Eyedropper'),
                selected: _tool == StudioTool.eyedropper,
                onTap: () => setState(() => _tool = StudioTool.eyedropper),
              ),
              _chip(
                key: const ValueKey('studio-ruler'),
                icon: Icons.straighten_rounded,
                label: _t('مسطرة', 'Ruler'),
                selected: _ruler,
                onTap: () => setState(() => _ruler = !_ruler),
              ),
            ]),
          ),
          if (_tool == StudioTool.shape)
            _section(
              context,
              _t('الشكل', 'Shape'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in shapes.entries)
                  _chip(
                    key: ValueKey('studio-shape-${e.key.name}'),
                    icon: e.value.$1,
                    label: _t(e.value.$2, e.value.$3),
                    selected: _shape == e.key,
                    onTap: () => setState(() => _shape = e.key),
                  ),
                _chip(
                  key: const ValueKey('studio-shape-filled'),
                  icon: _filled ? Icons.square_rounded : Icons.check_box_outline_blank_rounded,
                  label: _t('مملوء', 'Filled'),
                  selected: _filled,
                  onTap: () => setState(() => _filled = !_filled),
                ),
              ]),
            ),
          if (_tool == StudioTool.gradient)
            _section(
              context,
              _t('اسحب على اللوحة: من اللون الأوّل إلى الثاني', 'Drag across the canvas: first colour to second'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _chip(
                  key: const ValueKey('studio-gradient-linear'),
                  icon: Icons.linear_scale_rounded,
                  label: _t('خطّي', 'Linear'),
                  selected: !_radial,
                  onTap: () => setState(() => _radial = false),
                ),
                _chip(
                  key: const ValueKey('studio-gradient-radial'),
                  icon: Icons.radio_button_checked_rounded,
                  label: _t('دائري', 'Radial'),
                  selected: _radial,
                  onTap: () => setState(() => _radial = true),
                ),
                _chip(
                  key: const ValueKey('studio-gradient-clear'),
                  icon: Icons.opacity_rounded,
                  label: _t('إلى شفّاف', 'To clear'),
                  selected: _color2.a == 0,
                  onTap: () => setState(() => _color2 = _color2.a == 0 ? const Color(0xFFFFFFFF) : const Color(0x00FFFFFF)),
                ),
              ]),
            ),
          _section(
            context,
            '${_t('الحجم', 'Size')}: ${_size.round()}',
            Slider(
              key: const ValueKey('studio-size'),
              min: 1,
              max: 80,
              value: _size,
              onChanged: (v) => setState(() => _size = v),
            ),
          ),
          _section(
            context,
            '${_t('الشفافية', 'Opacity')}: ${(_opacity * 100).round()}%',
            Slider(
              key: const ValueKey('studio-opacity'),
              min: 0.05,
              max: 1,
              value: _opacity,
              onChanged: (v) => setState(() => _opacity = v),
            ),
          ),
          _section(
            context,
            _t('الألوان', 'Colours'),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                // ‏اللونان: الأوّلُ للرسم، والثاني للتدرّج — لمسةٌ تبادلهما.
                SizedBox(
                  width: 58,
                  height: 50,
                  child: Stack(children: [
                    Positioned(right: 0, bottom: 0, child: _dot(_color2, key: const ValueKey('studio-color2'), size: 32, onTap: _swapColors)),
                    Positioned(left: 0, top: 0, child: _dot(_color, key: const ValueKey('studio-color1'), size: 38, onTap: _openPicker, selected: true)),
                  ]),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('studio-swap-colors'),
                  tooltip: _t('بدّل اللونين', 'Swap colours'),
                  onPressed: _swapColors,
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  key: const ValueKey('studio-color-picker'),
                  onPressed: _openPicker,
                  icon: const Icon(Icons.palette_rounded, size: 18),
                  label: Text(_t('لوحة دقيقة', 'Fine picker')),
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (i, c) in quickColors.indexed)
                  _dot(c, key: ValueKey('studio-quick-$i'), selected: c == _color),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text(_t('ألواني', 'My colours'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: StudentSurface.mutedInk(context))),
                const SizedBox(width: 6),
                IconButton(
                  key: const ValueKey('studio-save-color'),
                  tooltip: _t('احفظ اللون الحالي', 'Save current colour'),
                  onPressed: () => unawaited(_saveColor(_color)),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ]),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (i, c) in _custom.indexed) _dot(c, key: ValueKey('studio-custom-$i'), selected: c == _color),
              ]),
            ]),
          ),
          _section(context, _t('الطبقات', 'Layers'), _layersPanel(context)),
        ]),
      );

  void _swapColors() {
    HapticFeedback.selectionClick();
    setState(() {
      final c = _color;
      _color = _color2.a == 0 ? _color2.withValues(alpha: 1) : _color2;
      _color2 = c;
    });
  }

  Widget _layersPanel(BuildContext context) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final layers = _controller.layers;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 4, runSpacing: 4, children: [
              IconButton.filledTonal(
                key: const ValueKey('studio-layer-add'),
                tooltip: _t('طبقة جديدة', 'New layer'),
                onPressed: layers.length >= StudioController.maxLayers ? null : () => _controller.addLayer(),
                icon: const Icon(Icons.add_rounded),
              ),
              IconButton.filledTonal(
                key: const ValueKey('studio-layer-duplicate'),
                tooltip: _t('نسخ الطبقة', 'Duplicate layer'),
                onPressed: layers.length >= StudioController.maxLayers ? null : _controller.duplicateLayer,
                icon: const Icon(Icons.copy_rounded),
              ),
              IconButton.filledTonal(
                key: const ValueKey('studio-layer-up'),
                tooltip: _t('ارفع الطبقة', 'Move layer up'),
                onPressed: _controller.active < layers.length - 1 ? () => _controller.moveLayer(1) : null,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton.filledTonal(
                key: const ValueKey('studio-layer-down'),
                tooltip: _t('أنزل الطبقة', 'Move layer down'),
                onPressed: _controller.active > 0 ? () => _controller.moveLayer(-1) : null,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton.filledTonal(
                key: const ValueKey('studio-layer-clear'),
                tooltip: _t('امسح الطبقة', 'Clear layer'),
                onPressed: _controller.clearLayer,
                icon: const Icon(Icons.cleaning_services_rounded),
              ),
              IconButton.filledTonal(
                key: const ValueKey('studio-layer-delete'),
                tooltip: _t('احذف الطبقة', 'Delete layer'),
                onPressed: _controller.removeLayer,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ]),
            const SizedBox(height: 6),
            // ‏الأعلى أوّلاً، كما في برامج الرسم.
            for (var i = layers.length - 1; i >= 0; i--)
              Container(
                key: ValueKey('studio-layer-$i'),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
                decoration: BoxDecoration(
                  color: i == _controller.active ? const Color(0xFFEDE9FE) : StudentSurface.card(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: i == _controller.active ? const Color(0xFF7C3AED) : StudentSurface.outline(context),
                    width: i == _controller.active ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  IconButton(
                    key: ValueKey('studio-layer-visible-$i'),
                    onPressed: () => _controller.toggleVisible(i),
                    icon: Icon(layers[i].visible ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20),
                  ),
                  GestureDetector(
                    key: ValueKey('studio-layer-select-$i'),
                    onTap: () => _controller.selectLayer(i),
                    child: Container(
                      width: 40,
                      height: 40,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x33000000))),
                      child: CustomPaint(painter: _LayerThumb(layers[i])),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _controller.selectLayer(i),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('${_t('طبقة', 'Layer')} ${layers[i].name} · ${(layers[i].opacity * 100).round()}%',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: StudentSurface.ink(context))),
                        SizedBox(
                          height: 28,
                          child: Slider(
                            key: ValueKey('studio-layer-opacity-$i'),
                            value: layers[i].opacity,
                            onChangeStart: (_) => _controller.beginOpacityChange(),
                            onChanged: (v) => _controller.setOpacity(i, v),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
          ]);
        },
      );
}

/// صورةٌ مصغّرةٌ لطبقةٍ واحدة على شبكة الشفافية.
class _LayerThumb extends CustomPainter {
  _LayerThumb(this.layer);

  final StudioLayer layer;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 4;
    for (var x = 0; x < 4; x++) {
      for (var y = 0; y < 4; y++) {
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell),
            Paint()..color = (x + y).isEven ? const Color(0xFFFFFFFF) : const Color(0xFFE5E7EB));
      }
    }
    canvas
      ..save()
      ..scale(size.shortestSide / studioSize)
      ..saveLayer(const Rect.fromLTWH(0, 0, studioSize, studioSize), Paint())
      ..drawPicture(StudioController.pictureOf(layer))
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(_LayerThumb old) => old.layer != layer;
}

/// لوحةُ ألوانٍ دقيقة: درجةٌ وتشبّعٌ وسطوع، وشفافية، وكتابةُ الرمز السداسيّ،
/// وحفظُ اللون في «ألواني».
class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initial, required this.custom, required this.onSave});

  final Color initial;
  final List<Color> custom;
  final Future<List<Color>> Function(Color) onSave;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late List<Color> _custom = widget.custom;
  late final TextEditingController _hex = TextEditingController(text: _hexOf(widget.initial));

  static String _hexOf(Color c) => (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  Color get _color => _hsv.toColor();

  void _set(HSVColor hsv) {
    setState(() => _hsv = hsv);
    _hex.text = _hexOf(hsv.toColor());
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(key: const ValueKey('studio-picker-sheet'), mainAxisSize: MainAxisSize.min, children: [
            LayoutBuilder(builder: (context, box) {
              final w = math.min(box.maxWidth, 420.0);
              const h = 200.0;
              void pick(Offset p) => _set(_hsv
                  .withSaturation((p.dx / w).clamp(0.0, 1.0))
                  .withValue(1 - (p.dy / h).clamp(0.0, 1.0)));
              return GestureDetector(
                key: const ValueKey('studio-picker-sv'),
                onPanDown: (d) => pick(d.localPosition),
                onPanUpdate: (d) => pick(d.localPosition),
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Stack(children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(colors: [Colors.white, HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor()]),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0xFF000000)],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _hsv.saturation * w - 10,
                      top: (1 - _hsv.value) * h - 10,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                      ),
                    ),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 10),
            // ‏شريطُ الدرجة.
            LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              void pick(Offset p) => _set(_hsv.withHue((p.dx / w).clamp(0.0, 1.0) * 359.9));
              return GestureDetector(
                key: const ValueKey('studio-picker-hue'),
                onPanDown: (d) => pick(d.localPosition),
                onPanUpdate: (d) => pick(d.localPosition),
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(colors: [
                      for (var h = 0; h <= 6; h++) HSVColor.fromAHSV(1, (h * 60.0) % 360, 1, 1).toColor(),
                    ]),
                  ),
                  child: Align(
                    alignment: Alignment(_hsv.hue / 180 - 1, 0),
                    child: Container(
                      width: 10,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.black26)),
                    ),
                  ),
                ),
              );
            }),
            Row(children: [
              Text(_t('الشفافية', 'Opacity')),
              Expanded(
                child: Slider(
                  key: const ValueKey('studio-picker-alpha'),
                  min: 0.05,
                  max: 1,
                  value: _hsv.alpha.clamp(0.05, 1.0),
                  onChanged: (v) => setState(() => _hsv = _hsv.withAlpha(v)),
                ),
              ),
            ]),
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black26)),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 130,
                child: TextField(
                  key: const ValueKey('studio-picker-hex'),
                  controller: _hex,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(prefixText: '#', isDense: true, border: OutlineInputBorder()),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (v) {
                    if (v.length != 6) return;
                    final parsed = int.tryParse(v, radix: 16);
                    if (parsed != null) setState(() => _hsv = HSVColor.fromColor(Color(0xFF000000 | parsed)).withAlpha(_hsv.alpha));
                  },
                ),
              ),
              const Spacer(),
              IconButton(
                key: const ValueKey('studio-picker-save'),
                tooltip: _t('احفظ في ألواني', 'Save to my colours'),
                onPressed: () async {
                  final kept = await widget.onSave(_color);
                  if (mounted) setState(() => _custom = kept);
                },
                icon: const Icon(Icons.bookmark_add_rounded),
              ),
            ]),
            if (_custom.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in _custom)
                  GestureDetector(
                    onTap: () => _set(HSVColor.fromColor(c)),
                    child: Container(width: 28, height: 28, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.black26))),
                  ),
              ]),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('studio-picker-use'),
                onPressed: () => Navigator.pop(context, _color),
                child: Text(_t('استخدم هذا اللون', 'Use this colour')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
