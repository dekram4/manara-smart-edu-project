import 'dart:math' as math;

/// نقطةٌ في مستوى الشكل، بإحداثياتٍ من 0 إلى 1 نسبةً إلى عرضه وارتفاعه.
class TracePoint {
  const TracePoint(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(TracePoint other) =>
      math.sqrt(math.pow(x - other.x, 2) + math.pow(y - other.y, 2));

  @override
  String toString() => '(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}

/// جرّةُ قلمٍ واحدة: نقاطٌ يمرّ بها الإصبع بترتيبها. ونقطةٌ واحدة وحدها
/// نُقطةُ حرف (كنقطة الباء) تُلمس لمساً.
class TraceStroke {
  const TraceStroke(this.points);

  final List<TracePoint> points;

  bool get isDot => points.length == 1;
}

/// مساراتُ التتبّع لحرفٍ أو رقمٍ أو كلمة.
class TracePlan {
  const TracePlan({
    required this.strokes,
    required this.width,
    required this.height,
    required this.inkWidth,
  });

  final List<TraceStroke> strokes;

  /// أبعادُ الشبكة التي بُنيت منها النقاط، لحفظ نسبة الشكل عند الرسم.
  final int width;
  final int height;

  /// سُمكُ الخطّ نسبةً إلى ارتفاع الشكل: منه يُقدَّر كم يبتعد الإصبع.
  final double inkWidth;

  bool get isEmpty => strokes.isEmpty;

  /// صيغةٌ مضغوطة: كلُّ جرّةٍ قائمةُ أعدادٍ متتالية (x، y، x، y …) بأربع
  /// خاناتٍ عشرية — تكفي لشاشةٍ بآلاف النقاط، وتُبقي الملفَّ المولَّد صغيراً.
  Map<String, Object> toJson() => {
        'w': width,
        'h': height,
        'ink': double.parse(inkWidth.toStringAsFixed(4)),
        's': [
          for (final stroke in strokes)
            [
              for (final p in stroke.points) ...[
                double.parse(p.x.toStringAsFixed(4)),
                double.parse(p.y.toStringAsFixed(4)),
              ],
            ],
        ],
      };

  static TracePlan fromJson(Map<String, Object?> json) {
    final strokes = <TraceStroke>[];
    for (final raw in (json['s'] as List? ?? const [])) {
      final flat = [for (final v in raw as List) (v as num).toDouble()];
      strokes.add(TraceStroke([
        for (var i = 0; i + 1 < flat.length; i += 2) TracePoint(flat[i], flat[i + 1]),
      ]));
    }
    return TracePlan(
      strokes: strokes,
      width: (json['w'] as num? ?? 0).toInt(),
      height: (json['h'] as num? ?? 0).toInt(),
      inkWidth: (json['ink'] as num? ?? 0).toDouble(),
    );
  }
}

/// يبني [TracePlan] من صورةٍ ثنائية للشكل كما يرسمه الخطّ.
///
/// ── لماذا من الخطّ لا من مساراتٍ محفوظة ──
/// ما يُتتبّع يأتي من نصّ المعلم: أيّ حرفٍ وأيّ كلمةٍ بأيّ وصل. ومساراتٌ
/// محفوظةٌ لكل حرفٍ بأشكاله الأربعة لا تغطّي الكلمات الموصولة، ونموذجٌ لغويٌّ
/// لا يرسم مسارَ حرفٍ عربيٍّ بدقّة. فالشكلُ يُرسم بالخطّ نفسه الذي يراه
/// الطفل، ويُرقَّق إلى هيكله (Zhang–Suen)، ثم يُمشى الهيكلُ جرّةً جرّة.
///
/// ── والاتجاه ──
/// كلُّ جرّةٍ تبدأ من طرفها الأقرب إلى بداية الكتابة: الأيمنِ الأعلى في
/// العربية، والأيسرِ الأعلى في الإنجليزية والأرقام. وعند التفرّع يُختار
/// الفرعُ الأقربُ إلى استمرار الاتجاه. وهذا يطابق طريقةَ الكتابة في أغلب
/// الحروف، لا كلّها: ترتيبُ الجرّات في بعض الحروف عُرفٌ يُعلَّم ولا يُستنتج
/// من الشكل.
class TracePlanner {
  const TracePlanner._();

  /// [ink]: صفوفُ الشبكة، `true` حيث الحبر. [rtl]: الكتابة من اليمين.
  /// [spacing]: المسافةُ بين نقطتين نسبةً إلى ارتفاع الشكل.
  /// [topFirst]: جرّاتُ القطعة الواحدة من أعلاها — كما يُعلَّم الحرفُ والرقم
  /// وحدهما (الجيم: الخطُّ العلوي ثم القوس؛ و2: القوسُ ثم القاعدة). وفي
  /// الكلمة تبقى بترتيب المشي على امتدادها.
  static TracePlan plan(
    List<List<bool>> ink, {
    required bool rtl,
    double spacing = 0.13,
    bool topFirst = false,
  }) {
    final height = ink.length;
    final width = height == 0 ? 0 : ink.first.length;
    if (width == 0 || height == 0) {
      return const TracePlan(strokes: [], width: 0, height: 0, inkWidth: 0);
    }
    final grid = _Grid(width, height);
    var inkCount = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (ink[y][x]) {
          grid.set(x, y, true);
          inkCount++;
        }
      }
    }
    if (inkCount == 0) {
      return TracePlan(strokes: const [], width: width, height: height, inkWidth: 0);
    }

    final bounds = grid.bounds();
    final shapeHeight = math.max(bounds.height, 1);
    final components = _components(grid);
    final skeleton = _thin(grid.copy());
    _removeStaircase(skeleton);
    final skeletonCount = skeleton.count();
    final inkWidth = skeletonCount == 0 ? 0.0 : inkCount / skeletonCount / shapeHeight;
    _pruneSpurs(skeleton, (shapeHeight * 0.08).round().clamp(2, 12));

    final step = math.max(2.0, shapeHeight * spacing);
    final dotSize = shapeHeight * 0.22;
    // كلُّ قطعةٍ متّصلة بجرّاتها معاً وبترتيب مشيها؛ والقطعُ بترتيب الكتابة.
    final anchored = <({double anchor, int order, List<TraceStroke> strokes})>[];

    for (final component in components) {
      final box = _Box.of(component);
      final size = math.max(box.width, box.height);
      if (size <= dotSize) {
        // نقطةٌ أو همزةٌ صغيرة: تُلمس في وسطها.
        final cx = component.map((p) => p.x).reduce((a, b) => a + b) / component.length;
        final cy = component.map((p) => p.y).reduce((a, b) => a + b) / component.length;
        anchored.add((
          anchor: cx,
          order: anchored.length,
          strokes: [TraceStroke([TracePoint(cx / width, cy / height)])],
        ));
        continue;
      }
      final bones = [
        for (final p in component)
          if (skeleton.get(p.x, p.y)) p,
      ];
      if (bones.isEmpty) continue;
      final minLength = math.max(3, (shapeHeight * 0.2).round());
      final strokes = <TraceStroke>[
        for (final path in _walk(skeleton, bones, width, rtl, minLength))
          if (_resample(
                _downward(rtl ? _notUpward(path, shapeHeight) : _fromWritingStart(path, shapeHeight)),
                step,
              )
              case final points when points.isNotEmpty)
            TraceStroke([
              for (final p in points) TracePoint(p.x / width, p.y / height),
            ]),
      ];
      if (strokes.isEmpty) continue;
      if (topFirst) {
        // الأعلى أوّلاً؛ وما تقاربت بداياتُه ارتفاعاً (أسنانُ السين) فباتجاه
        // الكتابة — وإلا قُدّم سنٌّ أوسطُ على الأيمن لفرق بكسلٍ أو اثنين.
        final indexed = strokes.indexed.toList()
          ..sort((a, b) {
            final pa = a.$2.points.first;
            final pb = b.$2.points.first;
            if ((pa.y - pb.y).abs() > 0.12) return pa.y.compareTo(pb.y);
            final byDirection = rtl ? pb.x.compareTo(pa.x) : pa.x.compareTo(pb.x);
            return byDirection != 0 ? byDirection : a.$1.compareTo(b.$1);
          });
        strokes
          ..clear()
          ..addAll(indexed.map((entry) => entry.$2));
      }
      // طرفُ القطعة في اتجاه الكتابة: أوّلُ ما تصل إليه اليد.
      anchored.add((
        anchor: (rtl ? box.maxX : box.minX).toDouble(),
        order: anchored.length,
        strokes: strokes,
      ));
    }

    // من بداية الكتابة إلى نهايتها. ونقطةُ الحرف بعد جسمه: مركزُها داخلَه
    // وبدايةُ الجسم طرفُه، فتأتي بعده في الترتيب.
    anchored.sort((a, b) {
      final byAnchor = rtl ? b.anchor.compareTo(a.anchor) : a.anchor.compareTo(b.anchor);
      return byAnchor != 0 ? byAnchor : a.order.compareTo(b.order);
    });
    return TracePlan(
      strokes: [for (final entry in anchored) ...entry.strokes],
      width: width,
      height: height,
      inkWidth: inkWidth,
    );
  }

  // ── المكوّنات المتّصلة ──────────────────────────────────────────────

  static List<List<_P>> _components(_Grid grid) {
    final seen = List<bool>.filled(grid.width * grid.height, false);
    final out = <List<_P>>[];
    for (var y = 0; y < grid.height; y++) {
      for (var x = 0; x < grid.width; x++) {
        if (!grid.get(x, y) || seen[y * grid.width + x]) continue;
        final members = <_P>[];
        final queue = <_P>[_P(x, y)];
        seen[y * grid.width + x] = true;
        while (queue.isNotEmpty) {
          final p = queue.removeLast();
          members.add(p);
          for (final n in grid.neighbours(p)) {
            final k = n.y * grid.width + n.x;
            if (!seen[k]) {
              seen[k] = true;
              queue.add(n);
            }
          }
        }
        out.add(members);
      }
    }
    return out;
  }

  // ── الترقيق: Zhang–Suen ─────────────────────────────────────────────

  static _Grid _thin(_Grid grid) {
    var changed = true;
    while (changed) {
      changed = false;
      for (final pass in const [0, 1]) {
        final remove = <_P>[];
        for (var y = 1; y < grid.height - 1; y++) {
          for (var x = 1; x < grid.width - 1; x++) {
            if (!grid.get(x, y)) continue;
            // p2..p9 باتجاه عقارب الساعة من الأعلى.
            final n = [
              grid.get(x, y - 1), grid.get(x + 1, y - 1), grid.get(x + 1, y),
              grid.get(x + 1, y + 1), grid.get(x, y + 1), grid.get(x - 1, y + 1),
              grid.get(x - 1, y), grid.get(x - 1, y - 1),
            ];
            final b = n.where((v) => v).length;
            if (b < 2 || b > 6) continue;
            var a = 0;
            for (var i = 0; i < 8; i++) {
              if (!n[i] && n[(i + 1) % 8]) a++;
            }
            if (a != 1) continue;
            final ok = pass == 0
                ? !(n[0] && n[2] && n[4]) && !(n[2] && n[4] && n[6])
                : !(n[0] && n[2] && n[6]) && !(n[0] && n[4] && n[6]);
            if (ok) remove.add(_P(x, y));
          }
        }
        for (final p in remove) {
          grid.set(p.x, p.y, false);
        }
        if (remove.isNotEmpty) changed = true;
      }
    }
    return grid;
  }

  /// يزيل البكسلَ الزائد في زوايا الدرج: الترقيقُ يترك خطّاً قطرياً بسُمك
  /// بكسلين في مواضع، فيبدو كلُّ زاويةٍ طرفاً أو مفترقاً. يُحذف البكسلُ إن
  /// جاوره جاران متعامدان (شمالٌ وشرق، …) وبقي الخطُّ متّصلاً بدونه.
  static void _removeStaircase(_Grid skeleton) {
    final remove = <_P>[];
    for (var y = 1; y < skeleton.height - 1; y++) {
      for (var x = 1; x < skeleton.width - 1; x++) {
        if (!skeleton.get(x, y)) continue;
        final n = skeleton.get(x, y - 1);
        final e = skeleton.get(x + 1, y);
        final s = skeleton.get(x, y + 1);
        final w = skeleton.get(x - 1, y);
        final corner = (n && e && !s && !w) ||
            (e && s && !n && !w) ||
            (s && w && !n && !e) ||
            (w && n && !e && !s);
        if (!corner) continue;
        // جارٌ ثالثٌ قطريّ خارج الزاوية يعني مفترقاً حقيقياً.
        final diagonals = [
          skeleton.get(x + 1, y - 1) && !(n && e),
          skeleton.get(x + 1, y + 1) && !(e && s),
          skeleton.get(x - 1, y + 1) && !(s && w),
          skeleton.get(x - 1, y - 1) && !(w && n),
        ].where((v) => v).length;
        if (diagonals == 0) remove.add(_P(x, y));
      }
    }
    for (final p in remove) {
      skeleton.set(p.x, p.y, false);
    }
  }

  /// يقصّ الفروعَ القصيرة التي يتركها الترقيق عند الزوايا: طرفٌ يصل إلى
  /// مفترقٍ في أقلّ من [maxLength] نقطة ليس جرّةً بل أثرُ سُمك الخطّ.
  static void _pruneSpurs(_Grid skeleton, int maxLength) {
    for (var round = 0; round < 2; round++) {
      final ends = <_P>[];
      skeleton.forEachSet((p) {
        if (skeleton.neighbours(p).length == 1) ends.add(p);
      });
      for (final end in ends) {
        final branch = <_P>[end];
        var previous = end;
        var current = end;
        var reachedJunction = false;
        while (branch.length <= maxLength) {
          final next = skeleton
              .neighbours(current)
              .where((n) => n != previous && !branch.contains(n))
              .toList();
          if (next.length != 1) {
            reachedJunction = next.length > 1;
            break;
          }
          previous = current;
          current = next.first;
          if (skeleton.neighbours(current).length > 2) {
            reachedJunction = true;
            break;
          }
          branch.add(current);
        }
        if (reachedJunction && branch.length <= maxLength) {
          for (final p in branch) {
            skeleton.set(p.x, p.y, false);
          }
        }
      }
    }
  }

  // ── المشي على الهيكل ────────────────────────────────────────────────

  static List<List<_P>> _walk(
    _Grid skeleton,
    List<_P> bones,
    int width,
    bool rtl,
    int minLength,
  ) {
    final visited = <int>{};
    final paths = <List<_P>>[];
    final bonesSet = {for (final p in bones) p.key(width)};
    int degree(_P p) => skeleton
        .neighbours(p)
        .where((n) => bonesSet.contains(n.key(width)))
        .length;

    // الأقربُ إلى بداية الكتابة: الأيمنُ أو الأيسر، ثم الأعلى.
    double startScore(_P p) => (rtl ? p.x : -p.x) * 4 - p.y.toDouble();

    // ارتفاعُ الشكل: به يُعرف أيُّ الطرفين أعلى «بوضوح».
    final shapeTop = bones.map((p) => p.y).reduce(math.min);
    final shapeSpan = math.max(1, bones.map((p) => p.y).reduce(math.max) - shapeTop);

    /// أيُّ الطرفين تبدأ منه اليد. في العربية: الأعلى بوضوح أوّلاً — الجيمُ
    /// من رأسها لا من ذيلها الأيمن الأسفل — وما تقارب ارتفاعُه فالأيمن (الباء،
    /// النون). ومن اليسار: [startScore] كما هو، تُصحّحه [_fromWritingStart].
    _P better(_P a, _P b) {
      if (rtl && (a.y - b.y).abs() > shapeSpan * 0.25) return a.y < b.y ? a : b;
      return startScore(a) >= startScore(b) ? a : b;
    }

    _P? nextStart() {
      final open = bones.where((p) => !visited.contains(p.key(width))).toList();
      if (open.isEmpty) return null;
      final ends = open.where((p) => degree(p) <= 1).toList();
      final pool = ends.isNotEmpty ? ends : open;
      // حلقةٌ بلا طرف (كالصفر والهاء): تبدأ من أعلاها.
      if (ends.isEmpty && paths.isEmpty) {
        return pool.reduce((a, b) => a.y < b.y || (a.y == b.y && startScore(a) > startScore(b)) ? a : b);
      }
      return pool.reduce(better);
    }

    while (true) {
      final start = nextStart();
      if (start == null) break;
      final path = <_P>[start];
      visited.add(start.key(width));
      var current = start;
      while (true) {
        final options = skeleton
            .neighbours(current)
            .where((n) =>
                bonesSet.contains(n.key(width)) && !visited.contains(n.key(width)))
            .toList();
        if (options.isEmpty) break;
        _P chosen;
        if (options.length == 1 || path.length < 2) {
          chosen = options.length == 1
              ? options.first
              : options.reduce((a, b) => startScore(a) <= startScore(b) ? a : b);
        } else {
          // استمرارُ الاتجاه: أصغرُ زاويةٍ مع اتجاه آخر بضع نقاط.
          final back = path[math.max(0, path.length - 5)];
          final dx = current.x - back.x;
          final dy = current.y - back.y;
          double turn(_P n) {
            final nx = n.x - current.x;
            final ny = n.y - current.y;
            final dot = dx * nx + dy * ny;
            final len = math.sqrt(dx * dx + dy * dy) * math.sqrt(nx * nx + ny * ny);
            return len == 0 ? 0 : -dot / len;
          }
          chosen = options.reduce((a, b) => turn(a) <= turn(b) ? a : b);
        }
        visited.add(chosen.key(width));
        path.add(chosen);
        current = chosen;
      }
      paths.add(path);
    }
    // الجرّةُ الأولى تبقى؛ وما بعدها إن قصر فأثرُ مفترقٍ لا جرّة — يمرّ به
    // الإصبعُ وهو يكتب ما حوله.
    if (paths.isEmpty) return paths;
    return [
      paths.first,
      ...paths.skip(1).where((path) => path.length >= minLength),
    ];
  }

  /// في الكتابة من اليسار (الإنجليزية والأرقام): جرّةٌ طرفاها على ارتفاعٍ
  /// واحدٍ تقريباً تُكتب من اليسار — هكذا يبدأ «٨» من قاعدته اليسرى لا
  /// اليمنى، والخطُّ الأفقيُّ من أوّله.
  ///
  /// والمنحنياتُ لا تُمسّ: «6» و«9» و«C» تبدأ من يمينها الأعلى، وقلبُها
  /// لأن نهايتها أيسرُ يُخطئها. والعربيةُ لا يُطبَّق عليها أصلاً.
  ///
  /// وجرّةٌ صاعدةٌ في جملتها — نهايتُها أعلى من بدايتها بوضوح — تُكتب نازلة:
  /// المشيُ يبدأ من الطرف المفتوح الأيسر، وهو في «S» ذيلُها الأسفل وفي «9»
  /// ذيلُها؛ واليدُ تبدأهما من الأعلى.
  static List<_P> _fromWritingStart(List<_P> path, int shapeHeight) {
    if (path.length < 2) return path;
    final rise = path.first.y - path.last.y;
    if (rise > shapeHeight * 0.3) return path.reversed.toList();
    final level = rise.abs() < shapeHeight * 0.2;
    return level && path.last.x < path.first.x ? path.reversed.toList() : path;
  }

  /// في العربية: جرّةٌ صاعدةٌ في جملتها تُكتب نازلة. الراءُ والزاي رأسُهما
  /// منعطفٌ لا طرفٌ مفتوح، فيبدأ المشيُ من ذيلهما الأسفل صاعداً؛ واليدُ
  /// تبدأهما من الأعلى.
  static List<_P> _notUpward(List<_P> path, int shapeHeight) {
    if (path.length < 2) return path;
    return path.first.y - path.last.y > shapeHeight * 0.3 ? path.reversed.toList() : path;
  }

  /// الخطُّ الرأسيُّ يُكتب من أعلاه: الألفُ وساقُ اللام والكاف، و1 وl.
  ///
  /// المشيُ يبدأ من طرفٍ مفتوح؛ وفي الألف قد يكون الأعلى منعطفاً صغيراً لا
  /// طرفاً، فيبدأ من الأسفل صاعداً — بعكس ما يُعلَّم الطفل. فجرّةٌ رأسيّةٌ
  /// في معظمها تُقلب إن بدأت من أسفلها.
  static List<_P> _downward(List<_P> path) {
    if (path.length < 2) return path;
    final dx = (path.last.x - path.first.x).abs();
    final dy = path.last.y - path.first.y;
    return dy < 0 && -dy > dx * 2 ? path.reversed.toList() : path;
  }

  /// نقاطٌ على مسافاتٍ متساوية بطول المسار، أوّلُها بدايتُه وآخرُها نهايتُه.
  static List<_P> _resample(List<_P> path, double step) {
    if (path.isEmpty) return const [];
    if (path.length == 1) return [path.first];
    final out = <_P>[path.first];
    var carried = 0.0;
    for (var i = 1; i < path.length; i++) {
      final a = path[i - 1];
      final b = path[i];
      carried += math.sqrt(math.pow(b.x - a.x, 2) + math.pow(b.y - a.y, 2));
      if (carried >= step) {
        out.add(b);
        carried = 0;
      }
    }
    final last = path.last;
    final tail = out.last;
    final gap = math.sqrt(math.pow(last.x - tail.x, 2) + math.pow(last.y - tail.y, 2));
    if (gap >= step * 0.4) {
      out.add(last);
    } else if (out.length > 1) {
      out[out.length - 1] = last;
    }
    return out;
  }
}

class _P {
  const _P(this.x, this.y);

  final int x;
  final int y;

  int key(int width) => y * width + x;

  @override
  bool operator ==(Object other) => other is _P && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

class _Box {
  const _Box(this.minX, this.minY, this.maxX, this.maxY);

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  int get width => maxX - minX + 1;
  int get height => maxY - minY + 1;

  static _Box of(Iterable<_P> points) {
    var minX = 1 << 30, minY = 1 << 30, maxX = -1, maxY = -1;
    for (final p in points) {
      minX = math.min(minX, p.x);
      minY = math.min(minY, p.y);
      maxX = math.max(maxX, p.x);
      maxY = math.max(maxY, p.y);
    }
    return _Box(minX, minY, maxX, maxY);
  }
}

class _Grid {
  _Grid(this.width, this.height) : _cells = List<bool>.filled(width * height, false);

  _Grid._raw(this.width, this.height, this._cells);

  final int width;
  final int height;
  final List<bool> _cells;

  bool get(int x, int y) =>
      x >= 0 && y >= 0 && x < width && y < height && _cells[y * width + x];

  void set(int x, int y, bool value) => _cells[y * width + x] = value;

  _Grid copy() => _Grid._raw(width, height, List<bool>.of(_cells));

  int count() => _cells.where((v) => v).length;

  void forEachSet(void Function(_P p) visit) {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (_cells[y * width + x]) visit(_P(x, y));
      }
    }
  }

  List<_P> neighbours(_P p) => [
        for (var dy = -1; dy <= 1; dy++)
          for (var dx = -1; dx <= 1; dx++)
            if ((dx != 0 || dy != 0) && get(p.x + dx, p.y + dy)) _P(p.x + dx, p.y + dy),
      ];

  _Box bounds() {
    final points = <_P>[];
    forEachSet(points.add);
    return _Box.of(points);
  }
}
