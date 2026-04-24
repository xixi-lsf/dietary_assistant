import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class MemoryStatsScreen extends StatefulWidget {
  const MemoryStatsScreen({super.key});

  @override
  State<MemoryStatsScreen> createState() => _MemoryStatsScreenState();
}

class _MemoryStatsScreenState extends State<MemoryStatsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _observation;
  bool _observationLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _observation = null;
    });
    try {
      final data = await ApiService.get('/memory/stats');
      setState(() {
        _data = Map<String, dynamic>.from(data);
        _loading = false;
      });
      _loadObservation();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadObservation() async {
    setState(() => _observationLoading = true);
    try {
      final apiKey = await ApiConfig.getApiKey();
      final aiBaseUrl = await ApiConfig.getAiBaseUrl();
      final aiModel = await ApiConfig.getAiModel();
      final result = await ApiService.post('/memory/diet-observation', {
        'api_key': apiKey ?? '',
        'ai_base_url': aiBaseUrl,
        'ai_model': aiModel,
      });
      setState(() {
        _observation = result['observation'] as String? ?? '';
        _observationLoading = false;
      });
    } catch (_) {
      setState(() => _observationLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('口味记忆'),
        actions: [
          GestureDetector(
            onTap: _load,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryLight, width: 1.5),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_data == null) return _emptyState();

    final d = _data!;
    final convIndex = (d['convergence_index'] as num).toDouble();
    final current = d['current_memory'] != null
        ? Map<String, dynamic>.from(d['current_memory'])
        : null;
    final weights =
        Map<String, dynamic>.from(current?['taste_weights'] as Map? ?? {});
    final feedbackCount = current?['feedback_count'] as int? ?? 0;

    if (weights.isEmpty && feedbackCount == 0) return _emptyState();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _convergenceCard(convIndex, feedbackCount),
        const SizedBox(height: 14),
        if (weights.isNotEmpty) ...[
          _sectionHeader('☁️', '口味词云'),
          const SizedBox(height: 10),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              child: _WordCloud(weights: weights),
            ),
          ),
          const SizedBox(height: 14),
        ],
        _sectionHeader('🔍', '饮食观察'),
        const SizedBox(height: 10),
        _observationCard(),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: HandDrawnCard(
          color: AppColors.yellowSoft,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🌱', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              '快来告诉管家你的偏好吧',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              '去菜单页评价几道菜，记忆系统就会开始学习～',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textMid, height: 1.6),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _convergenceCard(double convIndex, int feedbackCount) {
    final Color color = convIndex >= 0.7
        ? AppColors.green
        : convIndex >= 0.4
            ? AppColors.yellow
            : AppColors.textLight;
    final Color bgColor = convIndex >= 0.7
        ? AppColors.greenSoft
        : convIndex >= 0.4
            ? AppColors.yellowSoft
            : AppColors.bg;
    final Color borderColor = convIndex >= 0.7
        ? AppColors.greenLight
        : convIndex >= 0.4
            ? const Color(0xFFFFE599)
            : AppColors.border;
    final String label = convIndex >= 0.7
        ? '偏好已稳定 ✓'
        : convIndex >= 0.4
            ? '学习中...'
            : '数据不足';

    return HandDrawnCard(
      color: bgColor,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('收敛指数',
                style: TextStyle(fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: 4),
            Text(
              '${(convIndex * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 36, fontWeight: FontWeight.w800, color: color),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('累计反馈',
              style: TextStyle(fontSize: 12, color: AppColors.textLight)),
          const SizedBox(height: 4),
          Text('$feedbackCount 条',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark)),
        ]),
      ]),
    );
  }

  Widget _observationCard() {
    if (_observationLoading) {
      return HandDrawnCard(
        padding: const EdgeInsets.all(24),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
          SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)),
          SizedBox(width: 12),
          Text('管家正在观察你的口味...',
              style: TextStyle(fontSize: 13, color: AppColors.textMid)),
        ]),
      );
    }
    final text = _observation ?? '';
    if (text.isEmpty) {
      return HandDrawnCard(
        padding: const EdgeInsets.all(20),
        child: const Text('暂无观察数据',
            style: TextStyle(fontSize: 13, color: AppColors.textLight)),
      );
    }
    return HandDrawnCard(
      color: AppColors.primarySoft,
      padding: const EdgeInsets.all(20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🤖', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textDark, height: 1.7)),
        ),
      ]),
    );
  }

  Widget _sectionHeader(String emoji, String title) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark)),
    ]);
  }
}

// ── 词云 ─────────────────────────────────────────────────────
class _PlacedWord {
  final String text;
  final Offset offset;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  const _PlacedWord({
    required this.text,
    required this.offset,
    required this.fontSize,
    required this.fontWeight,
    required this.color,
  });
}

class _WordCloud extends StatefulWidget {
  final Map<String, dynamic> weights;
  const _WordCloud({required this.weights});
  @override
  State<_WordCloud> createState() => _WordCloudState();
}

class _WordCloudState extends State<_WordCloud> {
  List<_PlacedWord> _placed = [];
  double _computedWidth = 0;
  double _canvasH = 0;

  // 拉开色差：深红 → 中橙 → 亮橙 → 暖黄，参考 HTML 词云配色
  static const _colors = [
    Color(0xFF8B2500), // 深砖红
    Color(0xFFE76F51), // 珊瑚橙
    Color(0xFFE9C46A), // 暖黄
    Color(0xFFC4451F), // 深橙红
    Color(0xFFF4A261), // 浅橙
    Color(0xFF6B1A00), // 暗红
    Color(0xFFFFB347), // 金橙黄
    Color(0xFFD96C3A), // 中橙
    Color(0xFFF2C94C), // 亮黄
    Color(0xFFB03A00), // 棕红
    Color(0xFFF38D68), // 粉橙
    Color(0xFF7A1F00), // 深酒红
    Color(0xFFE07A3C), // 橙棕
    Color(0xFFFFD166), // 黄油黄
    Color(0xFFCC4A1A), // 红橙
  ];

  void _layout(double canvasW) {
    if ((canvasW - _computedWidth).abs() < 1) return;
    _computedWidth = canvasW;

    // 初始画布高度用于布局计算，正方形画布
    final canvasH = canvasW;

    // 网格法防重叠，gridSize = 10px，和 wordcloud2.js gridSize:12 同原理
    const gs = 10;
    final gw = (canvasW / gs).ceil() + 2;
    final gh = (canvasH / gs).ceil() + 2;
    final grid = List.filled(gw * gh, false);

    bool canPlace(Rect r) {
      // 检查时额外留 1 格间距
      final x0 = (r.left / gs).floor() - 1;
      final y0 = (r.top / gs).floor() - 1;
      final x1 = (r.right / gs).ceil() + 1;
      final y1 = (r.bottom / gs).ceil() + 1;
      for (int gy = y0; gy <= y1; gy++) {
        for (int gx = x0; gx <= x1; gx++) {
          if (gx < 0 || gy < 0 || gx >= gw || gy >= gh) return false;
          if (grid[gy * gw + gx]) return false;
        }
      }
      return true;
    }

    void markGrid(Rect r) {
      final x0 = max(0, (r.left / gs).floor());
      final y0 = max(0, (r.top / gs).floor());
      final x1 = min(gw - 1, (r.right / gs).ceil());
      final y1 = min(gh - 1, (r.bottom / gs).ceil());
      for (int gy = y0; gy <= y1; gy++) {
        for (int gx = x0; gx <= x1; gx++) {
          grid[gy * gw + gx] = true;
        }
      }
    }

    // 去重
    final seen = <String>{};
    final sorted = widget.weights.entries
        .map((e) => MapEntry(e.key, (e.value as num).toDouble()))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final unique = sorted.where((e) => seen.add(e.key)).toList();
    final n = unique.length;
    if (n == 0) return;

    // 字号范围随词数自适应
    final double maxFs = n <= 5 ? 44 : n <= 10 ? 34 : n <= 15 ? 26 : 20;
    final double minFs = n <= 5 ? 22 : n <= 10 ? 16 : n <= 15 ? 12 : 10;

    final placed = <_PlacedWord>[];
    final cx = canvasW / 2;
    final cy = canvasH / 2;
    // 螺旋扩张系数，控制词云密度
    final double a = canvasW / (2 * pi * 16);

    for (int i = 0; i < unique.length; i++) {
      final tag = unique[i].key;
      final w = unique[i].value.clamp(0.0, 1.0);
      final fontSize = minFs + w * (maxFs - minFs);
      final color = _colors[i % _colors.length];
      final fw = w >= 0.65 ? FontWeight.w800 : w >= 0.4 ? FontWeight.w700 : FontWeight.w500;

      final tp = TextPainter(
        text: TextSpan(text: tag, style: TextStyle(fontSize: fontSize, fontWeight: fw, color: color)),
        textDirection: TextDirection.ltr,
      )..layout();

      double t = 0;
      while (t < 1000) {
        // y 轴乘 0.85 产生轻微椭圆感，和 HTML ellipticity:0.85 一致
        final px = cx + a * t * cos(t) - tp.width / 2;
        final py = cy + a * t * sin(t) * 0.85 - tp.height / 2;
        final rect = Rect.fromLTWH(px, py, tp.width, tp.height);

        if (rect.left >= 4 && rect.top >= 4 &&
            rect.right <= canvasW - 4 && rect.bottom <= canvasH - 4) {
          if (canPlace(rect)) {
            markGrid(rect);
            placed.add(_PlacedWord(
              text: tag, offset: Offset(px, py),
              fontSize: fontSize, fontWeight: fw, color: color,
            ));
            break;
          }
        }
        t += 0.1;
      }
    }

    if (placed.isEmpty) return;

    // 计算实际内容边界，裁掉多余空白
    double minY = double.infinity, maxY = 0;
    double minX = double.infinity, maxX = 0;
    for (final pw in placed) {
      final tp2 = TextPainter(
        text: TextSpan(text: pw.text, style: TextStyle(fontSize: pw.fontSize, fontWeight: pw.fontWeight)),
        textDirection: TextDirection.ltr,
      )..layout();
      minY = min(minY, pw.offset.dy);
      maxY = max(maxY, pw.offset.dy + tp2.height);
      minX = min(minX, pw.offset.dx);
      maxX = max(maxX, pw.offset.dx + tp2.width);
    }

    const pad = 14.0;
    final shiftY = minY - pad;
    // 水平居中偏移
    final contentCx = (minX + maxX) / 2;
    final shiftX = contentCx - canvasW / 2;

    final adjusted = placed.map((pw) => _PlacedWord(
      text: pw.text,
      offset: Offset(pw.offset.dx - shiftX, pw.offset.dy - shiftY),
      fontSize: pw.fontSize,
      fontWeight: pw.fontWeight,
      color: pw.color,
    )).toList();

    final actualH = (maxY - shiftY + pad).clamp(80.0, canvasW * 1.0);

    setState(() {
      _placed = adjusted;
      _canvasH = actualH;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      WidgetsBinding.instance.addPostFrameCallback((_) => _layout(w));

      if (_canvasH == 0) return const SizedBox(height: 120);

      return CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: SketchColors.lineBrown,
          strokeWidth: 2.5,
          dashWidth: 8,
          dashSpace: 5,
          wobble: 1.2,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.only(
              topLeft: Radius.elliptical(40, 20),
              topRight: Radius.elliptical(15, 50),
              bottomRight: Radius.elliptical(50, 15),
              bottomLeft: Radius.elliptical(20, 40),
            ),
            boxShadow: [
              BoxShadow(color: Color(0x1A8D6E63), offset: Offset(8, 8), blurRadius: 0),
            ],
          ),
          width: w,
          height: _canvasH,
          child: CustomPaint(painter: _WordCloudPainter(placed: _placed)),
        ),
      );
    });
  }
}

class _WordCloudPainter extends CustomPainter {
  final List<_PlacedWord> placed;
  const _WordCloudPainter({required this.placed});

  @override
  void paint(Canvas canvas, Size size) {
    for (final pw in placed) {
      final tp = TextPainter(
        text: TextSpan(
          text: pw.text,
          style: TextStyle(fontSize: pw.fontSize, fontWeight: pw.fontWeight, color: pw.color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pw.offset);
    }
  }

  @override
  bool shouldRepaint(_WordCloudPainter old) => placed != old.placed;
}
