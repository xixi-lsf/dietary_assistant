import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  Map<String, dynamic>? _summary;
  String _date = DateTime.now().toIso8601String().substring(0, 10);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/nutrition/summary?date=$_date');
      setState(() { _summary = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _summary?['totals'] as Map<String, dynamic>? ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('营养追踪'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {
                    setState(() {
                      _date = DateTime.parse(_date).subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
                    });
                    _load();
                  }),
                  Text(_date, style: const TextStyle(fontSize: 16)),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {
                    setState(() {
                      _date = DateTime.parse(_date).add(const Duration(days: 1)).toIso8601String().substring(0, 10);
                    });
                    _load();
                  }),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: BarChart(BarChartData(
                    barGroups: [
                      _bar(0, (totals['protein'] ?? 0).toDouble(), Colors.blue),
                      _bar(1, (totals['carbs'] ?? 0).toDouble(), Colors.orange),
                      _bar(2, (totals['fat'] ?? 0).toDouble(), Colors.red),
                      _bar(3, (totals['fiber'] ?? 0).toDouble(), Colors.green),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text(['蛋白', '碳水', '脂肪', '纤维'][v.toInt()], style: const TextStyle(fontSize: 11)),
                      )),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                  )),
                ),
                const SizedBox(height: 16),
                Text('总热量：${(totals['calories'] ?? 0).toStringAsFixed(0)} kcal',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) => BarChartGroupData(
        x: x,
        barRods: [BarChartRodData(toY: y, color: color, width: 24)],
      );

  void _showAddDialog() {
    final recipeCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    final mealLabels = ['早餐', '午餐', '晚餐', '零食'];
    String mealType = 'lunch';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('记录饮食'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: recipeCtrl, decoration: const InputDecoration(labelText: '菜名')),
          TextField(controller: calCtrl, decoration: const InputDecoration(labelText: '热量 (kcal)'), keyboardType: TextInputType.number),
          DropdownButton<String>(
            value: mealType,
            items: List.generate(4, (i) => DropdownMenuItem(value: mealTypes[i], child: Text(mealLabels[i]))),
            onChanged: (v) => setS(() => mealType = v!),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await ApiService.post('/nutrition/', {
                'date': _date,
                'meal_type': mealType,
                'recipe_name': recipeCtrl.text,
                'calories': double.tryParse(calCtrl.text) ?? 0,
                'protein': 0, 'carbs': 0, 'fat': 0, 'fiber': 0,
              });
              Navigator.pop(context);
              _load();
            },
            child: const Text('保存'),
          ),
        ],
      )),
    );
  }
}
