import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class MemoryStatsScreen extends StatefulWidget {
  const MemoryStatsScreen({super.key});

  @override
  State<MemoryStatsScreen> createState() => _MemoryStatsScreenState();
}

class _MemoryStatsScreenState extends State<MemoryStatsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.get('/memory/stats');
      setState(() { _data = Map<String, dynamic>.from(data); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('记忆收敛分析 🧠'),
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
              child: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text('加载失败：$_error', style: const TextStyle(color: AppColors.textMid)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    final history = List<Map<String, dynamic>>.from(
        (d['taste_weight_history'] as List).map((e) => Map<String, dynamic>.from(e)));
    final scoreTrend = List<Map<String, dynamic>>.from(
        (d['score_trend'] as List).map((e) => Map<String, dynamic>.from(e)));
    final convIndex = (d['convergence_index'] as num).toDouble();
    final current = d['current_memory'] != null
        ? Map<String, dynamic>.from(d['current_memory'])
        : null;
    final summary = d['summary'] as String? ?? '';

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      _summaryCard(convIndex, current, summary),
      const SizedBox(height: 14),

      if (history.length >= 2) ...[
        _SectionHeader(emoji: '📈', title: '口味权重收敛曲线'),
        const SizedBox(height: 4),
        const Text('各口味标签的权重随反馈次数的变化，趋于平稳说明系统已认识你的偏好。',
            style: TextStyle(fontSize: 12, color: AppColors.textLight)),
        const SizedBox(height: 10),
        ClayCard(
          padding: const EdgeInsets.all(16),
          child: SizedBox(height: 220, child: _weightChart(history)),
        ),
        const SizedBox(height: 14),

        _SectionHeader(emoji: '📉', title: '权重方差（稳定性指标）'),
        const SizedBox(height: 4),
        const Text('方差越低说明偏好越稳定，可用于收敛速度分析。',
            style: TextStyle(fontSize: 12, color: AppColors.textLight)),
        const SizedBox(height: 10),
        ClayCard(
          padding: const EdgeInsets.all(16),
          child: SizedBox(height: 160, child: _varianceChart(history)),
        ),
        const SizedBox(height: 14),
      ],

      if (scoreTrend.length >= 2) ...[
        _SectionHeader(emoji: '⭐', title: '推荐满意度趋势'),
        const SizedBox(height: 4),
        const Text('单次评分（散点）与滑动平均（折线），上升趋势说明记忆系统在改善推荐质量。',
            style: TextStyle(fontSize: 12, color: AppColors.textLight)),
        const SizedBox(height: 10),
        ClayCard(
          padding: const EdgeInsets.all(16),
          child: SizedBox(height: 200, child: _scoreChart(scoreTrend)),
        ),
        const SizedBox(height: 14),
      ],

      if (history.isEmpty && scoreTrend.isEmpty)
        ClayCard(
          color: AppColors.yellowSoft,
          borderColor: const Color(0xFFFFE599),
          padding: const EdgeInsets.all(32),
          child: const Center(
            child: Text('还没有反馈数据 🌱\n去菜单页评价几道菜，记忆系统就会开始学习～',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMid, fontSize: 14, height: 1.6)),
          ),
        ),

      if (current != null) ...[
        _SectionHeader(emoji: '💾', title: '当前长期记忆'),
        const SizedBox(height: 10),
        _currentMemoryCard(current),
      ],
    ]);
  }

  Widget _summaryCard(double convIndex, Map<String, dynamic>? current, String summary) {
    final count = current?['feedback_count'] as int? ?? 0;
    final Color color = convIndex >= 0.7 ? AppColors.green : convIndex >= 0.4 ? AppColors.yellow : AppColors.textLight;
    final Color bgColor = convIndex >= 0.7 ? AppColors.greenSoft : convIndex >= 0.4 ? AppColors.yellowSoft : AppColors.bg;
    final Color borderColor = convIndex >= 0.7 ? AppColors.greenLight : convIndex >= 0.4 ? const Color(0xFFFFE599) : AppColors.border;
    final String label = convIndex >= 0.7 ? '偏好已稳定 ✓' : convIndex >= 0.4 ? '学习中...' : '数据不足';

    return ClayCard(
      color: bgColor,
      borderColor: borderColor,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('收敛指数', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 4),
              Text('${(convIndex * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: color)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('累计反馈', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 4),
              Text('$count 条', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            ]),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: convIndex,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.5),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(summary, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.5)),
          ],
        ]),
    );
  }

  Widget _weightChart(List<Map<String, dynamic>> history) {
    final allTags = <String>{};
    for (final s in history) {
      final w = Map<String, dynamic>.from(s['weights_snapshot'] as Map);
      allTags.addAll(w.keys);
    }
    final tags = allTags.toList();
    final colors = [
      AppColors.primary, AppColors.green, AppColors.yellow,
      AppColors.lavender, AppColors.blue, const Color(0xFFFF8FAB),
      const Color(0xFF80CBC4), const Color(0xFFFFCC80),
    ];

    final lines = tags.asMap().entries.map((entry) {
      final tag = entry.value;
      final color = colors[entry.key % colors.length];
      final spots = <FlSpot>[];
      for (final s in history) {
        final w = Map<String, dynamic>.from(s['weights_snapshot'] as Map);
        if (w.containsKey(tag)) {
          spots.add(FlSpot((s['feedback_index'] as int).toDouble(), (w[tag] as num).toDouble()));
        }
      }
      return LineChartBarData(spots: spots, isCurved: true, color: color, barWidth: 2.5,
          dotData: const FlDotData(show: false));
    }).toList();

    return LineChart(LineChartData(
      lineBarsData: lines,
      minY: 0, maxY: 1,
      gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4])),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
            getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1),
                style: const TextStyle(fontSize: 10, color: AppColors.textLight)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.textLight)))),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.asMap().entries.map((e) {
            final tag = tags[e.key % tags.length];
            return LineTooltipItem('$tag\n${e.value.y.toStringAsFixed(2)}',
                TextStyle(color: colors[e.key % colors.length], fontSize: 11));
          }).toList(),
        ),
      ),
    ));
  }

  Widget _varianceChart(List<Map<String, dynamic>> history) {
    final spots = history.map((s) => FlSpot(
      (s['feedback_index'] as int).toDouble(),
      (s['variance'] as num).toDouble(),
    )).toList();

    return LineChart(LineChartData(
      lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true,
        color: AppColors.primary, barWidth: 2.5,
        belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.1)),
        dotData: const FlDotData(show: false),
      )],
      minY: 0,
      gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4])),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
            getTitlesWidget: (v, _) => Text(v.toStringAsFixed(3),
                style: const TextStyle(fontSize: 9, color: AppColors.textLight)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.textLight)))),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
    ));
  }

  Widget _scoreChart(List<Map<String, dynamic>> scoreTrend) {
    final scoreSpots = scoreTrend.map((s) => FlSpot(
      (s['feedback_index'] as int).toDouble(), (s['score'] as num).toDouble(),
    )).toList();
    final avgSpots = scoreTrend.map((s) => FlSpot(
      (s['feedback_index'] as int).toDouble(), (s['rolling_avg'] as num).toDouble(),
    )).toList();

    return LineChart(LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: scoreSpots, isCurved: false,
          color: AppColors.blue.withOpacity(0.4), barWidth: 0,
          dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) =>
              FlDotCirclePainter(radius: 4, color: AppColors.blue.withOpacity(0.5),
                  strokeWidth: 0, strokeColor: Colors.transparent)),
        ),
        LineChartBarData(
          spots: avgSpots, isCurved: true,
          color: AppColors.blue, barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: AppColors.blue.withOpacity(0.08)),
        ),
      ],
      minY: 1, maxY: 5,
      gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4])),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.textLight)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.textLight)))),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
    ));
  }

  Widget _currentMemoryCard(Map<String, dynamic> current) {
    final weights = Map<String, dynamic>.from(current['taste_weights'] as Map? ?? {});
    final constraints = List<String>.from(current['hard_constraints'] as List? ?? []);
    final goals = List<String>.from(current['health_goals'] as List? ?? []);
    final summary = current['preference_summary'] as String? ?? '';

    final sortedWeights = weights.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    return ClayCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (sortedWeights.isNotEmpty) ...[
            const Text('口味权重', style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...sortedWeights.map((e) {
              final v = (e.value as num).toDouble();
              final color = v >= 0.7 ? AppColors.green : v <= 0.3 ? AppColors.primary : AppColors.yellow;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 72, child: Text(e.key,
                      style: const TextStyle(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600))),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: v, minHeight: 8,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Text(v.toStringAsFixed(2),
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                ]),
              );
            }),
            const SizedBox(height: 10),
          ],
          if (constraints.isNotEmpty) ...[
            const Text('硬约束（绝对禁忌）', style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: constraints.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFCCCC), width: 1.5),
              ),
              child: Text(c, style: const TextStyle(fontSize: 12, color: Color(0xFFE57373), fontWeight: FontWeight.w600)),
            )).toList()),
            const SizedBox(height: 10),
          ],
          if (goals.isNotEmpty) ...[
            const Text('健康目标', style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: goals.map((g) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.greenLight, width: 1.5),
              ),
              child: Text(g, style: const TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w600)),
            )).toList()),
            const SizedBox(height: 10),
          ],
          if (summary.isNotEmpty) ...[
            const Text('偏好摘要', style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(summary, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.5)),
          ],
        ]),
    );
  }
}



class _SectionHeader extends StatelessWidget {
  final String emoji;
  final String title;

  const _SectionHeader({required this.emoji, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
    ]);
  }
}
