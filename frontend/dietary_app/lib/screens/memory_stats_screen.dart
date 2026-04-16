import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
      appBar: AppBar(
        title: const Text('记忆收敛分析'),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('加载失败：$_error'))
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

    return ListView(padding: const EdgeInsets.all(16), children: [
      // 摘要卡片
      _summaryCard(convIndex, current, summary),
      const SizedBox(height: 16),

      if (history.length >= 2) ...[
        _sectionTitle('口味权重收敛曲线'),
        const SizedBox(height: 4),
        const Text('各口味标签的权重随反馈次数的变化，趋于平稳说明系统已认识你的偏好。',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        SizedBox(height: 220, child: _weightChart(history)),
        const SizedBox(height: 16),

        _sectionTitle('权重方差（稳定性指标）'),
        const SizedBox(height: 4),
        const Text('方差越低说明偏好越稳定，可用于论文中的收敛速度分析。',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        SizedBox(height: 160, child: _varianceChart(history)),
        const SizedBox(height: 16),
      ],

      if (scoreTrend.length >= 2) ...[
        _sectionTitle('推荐满意度趋势'),
        const SizedBox(height: 4),
        const Text('单次评分（散点）与滑动平均（折线），上升趋势说明记忆系统在改善推荐质量。',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        SizedBox(height: 200, child: _scoreChart(scoreTrend)),
        const SizedBox(height: 16),
      ],

      if (history.isEmpty && scoreTrend.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('还没有反馈数据\n去菜单页评价几道菜，记忆系统就会开始学习～',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ),
        ),

      // 当前记忆状态
      if (current != null) ...[
        _sectionTitle('当前长期记忆'),
        const SizedBox(height: 8),
        _currentMemoryCard(current),
      ],
    ]);
  }

  Widget _summaryCard(double convIndex, Map<String, dynamic>? current, String summary) {
    final count = current?['feedback_count'] as int? ?? 0;
    final color = convIndex >= 0.7 ? Colors.green : convIndex >= 0.4 ? Colors.orange : Colors.grey;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('收敛指数', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text('${(convIndex * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('累计反馈', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text('$count 条', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: convIndex, color: color, backgroundColor: Colors.grey.shade200),
          const SizedBox(height: 8),
          Text(summary, style: const TextStyle(fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold));
  }

  Widget _weightChart(List<Map<String, dynamic>> history) {
    // 收集所有 tag
    final allTags = <String>{};
    for (final s in history) {
      final w = Map<String, dynamic>.from(s['weights_snapshot'] as Map);
      allTags.addAll(w.keys);
    }
    final tags = allTags.toList();
    final colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.brown,
    ];

    final lines = tags.asMap().entries.map((entry) {
      final tag = entry.value;
      final color = colors[entry.key % colors.length];
      final spots = <FlSpot>[];
      for (final s in history) {
        final w = Map<String, dynamic>.from(s['weights_snapshot'] as Map);
        if (w.containsKey(tag)) {
          spots.add(FlSpot(
            (s['feedback_index'] as int).toDouble(),
            (w[tag] as num).toDouble(),
          ));
        }
      }
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      );
    }).toList();

    return LineChart(LineChartData(
      lineBarsData: lines,
      minY: 0, maxY: 1,
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
            getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 10)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)))),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: true),
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
        spots: spots,
        isCurved: true,
        color: Colors.deepOrange,
        barWidth: 2,
        belowBarData: BarAreaData(show: true, color: Colors.deepOrange.withOpacity(0.1)),
        dotData: const FlDotData(show: false),
      )],
      minY: 0,
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
            getTitlesWidget: (v, _) => Text(v.toStringAsFixed(3), style: const TextStyle(fontSize: 9)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)))),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: true),
    ));
  }

  Widget _scoreChart(List<Map<String, dynamic>> scoreTrend) {
    final scoreSpots = scoreTrend.map((s) => FlSpot(
      (s['feedback_index'] as int).toDouble(),
      (s['score'] as num).toDouble(),
    )).toList();
    final avgSpots = scoreTrend.map((s) => FlSpot(
      (s['feedback_index'] as int).toDouble(),
      (s['rolling_avg'] as num).toDouble(),
    )).toList();

    return LineChart(LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: scoreSpots,
          isCurved: false,
          color: Colors.blue.withOpacity(0.4),
          barWidth: 0,
          dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) =>
              FlDotCirclePainter(radius: 4, color: Colors.blue.withOpacity(0.5), strokeWidth: 0, strokeColor: Colors.transparent)),
        ),
        LineChartBarData(
          spots: avgSpots,
          isCurved: true,
          color: Colors.blue,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
      minY: 1, maxY: 5,
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)))),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: true),
    ));
  }

  Widget _currentMemoryCard(Map<String, dynamic> current) {
    final weights = Map<String, dynamic>.from(current['taste_weights'] as Map? ?? {});
    final constraints = List<String>.from(current['hard_constraints'] as List? ?? []);
    final goals = List<String>.from(current['health_goals'] as List? ?? []);
    final summary = current['preference_summary'] as String? ?? '';

    final sortedWeights = weights.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (sortedWeights.isNotEmpty) ...[
            const Text('口味权重', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            ...sortedWeights.map((e) {
              final v = (e.value as num).toDouble();
              final color = v >= 0.7 ? Colors.green : v <= 0.3 ? Colors.red : Colors.orange;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(width: 80, child: Text(e.key, style: const TextStyle(fontSize: 12))),
                  Expanded(child: LinearProgressIndicator(value: v, color: color, backgroundColor: Colors.grey.shade200)),
                  const SizedBox(width: 8),
                  Text(v.toStringAsFixed(2), style: TextStyle(fontSize: 11, color: color)),
                ]),
              );
            }),
            const SizedBox(height: 8),
          ],
          if (constraints.isNotEmpty) ...[
            const Text('硬约束（绝对禁忌）', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: constraints.map((c) =>
                Chip(label: Text(c, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.red.shade50,
                    side: BorderSide(color: Colors.red.shade200))).toList()),
            const SizedBox(height: 8),
          ],
          if (goals.isNotEmpty) ...[
            const Text('健康目标', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: goals.map((g) =>
                Chip(label: Text(g, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.green.shade50)).toList()),
            const SizedBox(height: 8),
          ],
          if (summary.isNotEmpty) ...[
            const Text('偏好摘要', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(summary, style: const TextStyle(fontSize: 13)),
          ],
        ]),
      ),
    );
  }
}
