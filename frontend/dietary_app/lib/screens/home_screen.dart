import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _advice;
  bool _adviceLoading = false;
  int? _bmr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final data = await ApiService.get('/nutrition/summary?date=$today');
      setState(() {
        _summary = data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadAdvice() async {
    setState(() {
      _adviceLoading = true;
      _advice = null;
    });
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final apiKey = await ApiConfig.getApiKey();
      final aiBaseUrl = await ApiConfig.getAiBaseUrl();
      final profile = await ApiService.get('/user/profile');
      final cycleDays = profile['cycle_days'] ?? 7;
      final data = await ApiService.post('/ai/diet-advice', {
        'date': today,
        'cycle_days': cycleDays,
        if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
        if (aiBaseUrl != null && aiBaseUrl.isNotEmpty) 'ai_base_url': aiBaseUrl,
      });
      setState(() {
        _advice = data['advice'];
        _bmr = data['bmr'] != null ? (data['bmr'] as num).toInt() : null;
        _adviceLoading = false;
      });
    } catch (e) {
      setState(() {
        _advice = '获取建议失败：$e';
        _adviceLoading = false;
      });
    }
  }

  String _mealLabel(String type) {
    const map = {
      'breakfast': '早餐',
      'lunch': '午餐',
      'dinner': '晚餐',
      'snack': '零食'
    };
    return map[type] ?? type;
  }

  @override
  Widget build(BuildContext context) {
    final totals = _summary?['totals'] as Map<String, dynamic>? ?? {};
    final meals = (_summary?['meals'] as List?) ?? [];

    final Map<String, List<dynamic>> mealGroups = {};
    for (final m in meals) {
      final type = m['meal_type'] ?? 'other';
      mealGroups.putIfAbsent(type, () => []).add(m);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('今日摘要'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '今日摄入',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '总热量：${(totals['calories'] ?? 0).toStringAsFixed(0)} kcal',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text('餐次记录：${meals.length} 条'),
                          if (_bmr != null) ...[
                            const SizedBox(height: 8),
                            Text('建议目标：$_bmr kcal'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '营养统计',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _MetricRow(label: '蛋白质', value: '${(totals['protein'] ?? 0).toStringAsFixed(1)} g'),
                          _MetricRow(label: '碳水', value: '${(totals['carbs'] ?? 0).toStringAsFixed(1)} g'),
                          _MetricRow(label: '脂肪', value: '${(totals['fat'] ?? 0).toStringAsFixed(1)} g'),
                          _MetricRow(label: '纤维', value: '${(totals['fiber'] ?? 0).toStringAsFixed(1)} g'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '今日餐次',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (meals.isEmpty)
                            const Text('今天还没有用餐记录')
                          else
                            ...['breakfast', 'lunch', 'dinner', 'snack']
                                .where((t) => mealGroups.containsKey(t))
                                .map((type) {
                              final items = mealGroups[type]!;
                              final names = items
                                  .map((m) => m['recipe_name'] ?? '')
                                  .where((n) => n.isNotEmpty)
                                  .join('、');
                              final cal = items.fold<double>(
                                0,
                                (s, m) => s + ((m['calories'] ?? 0) as num).toDouble(),
                              );
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(_mealLabel(type)),
                                subtitle: Text(names.isEmpty ? '（已记录）' : names),
                                trailing: Text('${cal.toStringAsFixed(0)} kcal'),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  '饮食建议',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              FilledButton.tonal(
                                onPressed: _adviceLoading ? null : _loadAdvice,
                                child: const Text('获取建议'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_adviceLoading)
                            const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ))
                          else if (_advice != null)
                            Text(_advice!, style: const TextStyle(height: 1.5))
                          else
                            const Text('还没有生成建议'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
