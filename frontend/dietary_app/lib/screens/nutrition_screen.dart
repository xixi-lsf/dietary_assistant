import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
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

  void _changeDate(int days) {
    setState(() {
      _date = DateTime.parse(_date).add(Duration(days: days)).toIso8601String().substring(0, 10);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final totals = _summary?['totals'] as Map<String, dynamic>? ?? {};
    final calories = (totals['calories'] ?? 0) as num;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('营养追踪 📊')),
      floatingActionButton: GestureDetector(
        onTap: _showAddDialog,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(2, 4))],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                // 日期选择器
                ClayCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textMid),
                        onPressed: () => _changeDate(-1),
                      ),
                      Column(children: [
                        Text(_date,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        Text(
                          _date == DateTime.now().toIso8601String().substring(0, 10) ? '今天' : '',
                          style: const TextStyle(fontSize: 11, color: AppColors.primary),
                        ),
                      ]),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textMid),
                        onPressed: () => _changeDate(1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 热量大卡
                ClayCard(
                  color: AppColors.primarySoft,
                  borderColor: AppColors.primaryLight,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE06040), width: 3),
                          boxShadow: ClayShadow.primaryBtn(),
                        ),
                        child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('总热量', style: TextStyle(fontSize: 13, color: AppColors.textMid)),
                          Text('${calories.toStringAsFixed(0)} kcal',
                              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 营养柱状图
                ClayCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('营养分布',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: BarChart(BarChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: AppColors.border,
                              strokeWidth: 1,
                              dashArray: [4, 4],
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: [
                            _bar(0, (totals['protein'] ?? 0).toDouble(), AppColors.primary),
                            _bar(1, (totals['carbs'] ?? 0).toDouble(), AppColors.yellow),
                            _bar(2, (totals['fat'] ?? 0).toDouble(), AppColors.lavender),
                            _bar(3, (totals['fiber'] ?? 0).toDouble(), AppColors.green),
                          ],
                          titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) {
                                  const labels = ['蛋白质', '碳水', '脂肪', '纤维'];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(labels[v.toInt()],
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMid)),
                                  );
                                },
                              )),
                              leftTitles: AxisTitles(sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                getTitlesWidget: (v, _) => Text('${v.toInt()}g',
                                    style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                              )),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                          )),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),

                // 营养徽章
                Row(children: [
                  _NutriBadge(label: '蛋白质', value: '${(totals['protein'] ?? 0).toStringAsFixed(1)}g',
                      color: AppColors.primary, bgColor: AppColors.primarySoft, borderColor: AppColors.primaryLight),
                  const SizedBox(width: 10),
                  _NutriBadge(label: '碳水', value: '${(totals['carbs'] ?? 0).toStringAsFixed(1)}g',
                      color: const Color(0xFFD4A017), bgColor: AppColors.yellowSoft, borderColor: Color(0xFFFFE599)),
                  const SizedBox(width: 10),
                  _NutriBadge(label: '脂肪', value: '${(totals['fat'] ?? 0).toStringAsFixed(1)}g',
                      color: AppColors.lavender, bgColor: AppColors.lavenderSoft, borderColor: Color(0xFFD8C8F0)),
                  const SizedBox(width: 10),
                  _NutriBadge(label: '纤维', value: '${(totals['fiber'] ?? 0).toStringAsFixed(1)}g',
                      color: AppColors.green, bgColor: AppColors.greenSoft, borderColor: AppColors.greenLight),
                ]),
              ],
            ),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) => BarChartGroupData(
        x: x,
        barRods: [BarChartRodData(
          toY: y,
          color: color,
          width: 28,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: (y * 1.3).clamp(10, double.infinity),
            color: color.withOpacity(0.1),
          ),
        )],
      );

  void _showAddDialog() {
    final recipeCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    final mealLabels = ['早餐 🌅', '午餐 ☀️', '晚餐 🌙', '零食 🍪'];
    String mealType = 'lunch';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 2),
            boxShadow: [BoxShadow(color: AppColors.shadowOuter, blurRadius: 16, offset: const Offset(3, 5))],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('记录饮食 🍽️',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 20),
              TextField(controller: recipeCtrl,
                  decoration: const InputDecoration(labelText: '菜名', prefixIcon: Icon(Icons.restaurant_rounded))),
              const SizedBox(height: 12),
              TextField(controller: calCtrl,
                  decoration: const InputDecoration(labelText: '热量 (kcal)', prefixIcon: Icon(Icons.local_fire_department_rounded)),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: mealType,
                    isExpanded: true,
                    items: List.generate(4, (i) => DropdownMenuItem(
                      value: mealTypes[i],
                      child: Text(mealLabels[i]),
                    )),
                    onChanged: (v) => setS(() => mealType = v!),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: const Center(child: Text('取消',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMid))),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () async {
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(1, 3))],
                    ),
                    child: const Center(child: Text('保存',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
                  ),
                )),
              ]),
            ],
          ),
        ),
      )),
    );
  }
}

// ClayCard from app_theme.dart is used directly

class _NutriBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const _NutriBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, offset: const Offset(2, 3)),
            const BoxShadow(color: Color(0xBBFFFFFF), blurRadius: 4, offset: Offset(-1, -1)),
          ],
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
