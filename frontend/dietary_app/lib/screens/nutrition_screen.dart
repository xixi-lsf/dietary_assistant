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
      setState(() {
        _summary = data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _changeDate(int days) {
    setState(() {
      _date = DateTime.parse(_date)
          .add(Duration(days: days))
          .toIso8601String()
          .substring(0, 10);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final totals = _summary?['totals'] as Map<String, dynamic>? ?? {};
    final calories = (totals['calories'] ?? 0) as num;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('营养追踪 📊'),
      ),
      floatingActionButton: _SketchFab(onTap: _showAddDialog),
      body: Container(
        color: SketchColors.bg,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: PaperDotsPainter())),
            _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: SketchColors.lineBrown,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    children: [
                      HandDrawnCard(
                        color: Colors.white,
                        rotation: 0,
                        hoverRotation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            _SketchRoundButton(
                              icon: Icons.chevron_left_rounded,
                              onTap: () => _changeDate(-1),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    _date,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: SketchColors.textMain,
                                    ),
                                  ),
                                  if (_date ==
                                      DateTime.now()
                                          .toIso8601String()
                                          .substring(0, 10))
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: _TinyBadge(text: '今天'),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _SketchRoundButton(
                              icon: Icons.chevron_right_rounded,
                              onTap: () => _changeDate(1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      HandDrawnCard(
                        color: const Color(0xFFFFF0D9),
                        rotation: 0,
                        hoverRotation: 0,
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE2B8),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: SketchColors.lineBrown,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.local_fire_department_rounded,
                                color: SketchColors.lineBrown,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '总热量',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: SketchColors.textMain,
                                  ),
                                ),
                                Text(
                                  '${calories.toStringAsFixed(0)} kcal',
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: SketchColors.textMain,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      HandDrawnCard(
                        color: Colors.white,
                        rotation: 0,
                        hoverRotation: 0,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '营养分布',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: SketchColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 190,
                              child: BarChart(
                                BarChartData(
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
                                    _bar(
                                      0,
                                      (totals['protein'] ?? 0).toDouble(),
                                      const Color(0xFFFF9B73),
                                    ),
                                    _bar(
                                      1,
                                      (totals['carbs'] ?? 0).toDouble(),
                                      const Color(0xFFFFD166),
                                    ),
                                    _bar(
                                      2,
                                      (totals['fat'] ?? 0).toDouble(),
                                      const Color(0xFFC9B8E8),
                                    ),
                                    _bar(
                                      3,
                                      (totals['fiber'] ?? 0).toDouble(),
                                      const Color(0xFF90C97A),
                                    ),
                                  ],
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (v, _) {
                                          const labels = ['蛋白质', '碳水', '脂肪', '纤维'];
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Text(
                                              labels[v.toInt()],
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: SketchColors.textMain,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 36,
                                        getTitlesWidget: (v, _) => Text(
                                          '${v.toInt()}g',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: SketchColors.lineBrown,
                                          ),
                                        ),
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _NutriBadge(
                            label: '蛋白质',
                            value:
                                '${(totals['protein'] ?? 0).toStringAsFixed(1)}g',
                            color: const Color(0xFFFF9B73),
                            bgColor: const Color(0xFFFFF0E8),
                          ),
                          _NutriBadge(
                            label: '碳水',
                            value:
                                '${(totals['carbs'] ?? 0).toStringAsFixed(1)}g',
                            color: const Color(0xFFE0A91B),
                            bgColor: const Color(0xFFFFF7DC),
                          ),
                          _NutriBadge(
                            label: '脂肪',
                            value: '${(totals['fat'] ?? 0).toStringAsFixed(1)}g',
                            color: const Color(0xFF9A82D6),
                            bgColor: const Color(0xFFF4EEFB),
                          ),
                          _NutriBadge(
                            label: '纤维',
                            value:
                                '${(totals['fiber'] ?? 0).toStringAsFixed(1)}g',
                            color: const Color(0xFF6AA45A),
                            bgColor: const Color(0xFFEEF8EB),
                          ),
                        ],
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) => BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: y,
            color: color,
            width: 28,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(8),
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: (y * 1.3).clamp(10, double.infinity),
              color: color.withOpacity(0.12),
            ),
          ),
        ],
      );

  void _showAddDialog() {
    final recipeCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    final mealLabels = ['早餐 🌅', '午餐 ☀️', '晚餐 🌙', '零食 🍪'];
    String mealType = 'lunch';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: HandDrawnCard(
            color: Colors.white,
            rotation: 0,
            hoverRotation: 0,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '记录饮食 🍽️',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SketchColors.textMain,
                  ),
                ),
                const SizedBox(height: 18),
                _SketchField(
                  controller: recipeCtrl,
                  label: '菜名',
                  hint: '请输入今天吃的食物',
                ),
                const SizedBox(height: 12),
                _SketchField(
                  controller: calCtrl,
                  label: '热量 (kcal)',
                  hint: '请输入热量数值',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                const Text(
                  '餐次',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SketchColors.textMain,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    4,
                    (i) => _SketchChoiceChip(
                      label: mealLabels[i],
                      selected: mealType == mealTypes[i],
                      onTap: () => setS(() => mealType = mealTypes[i]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _SketchPrimaryButton(
                        label: '取消',
                        fill: Colors.white,
                        onTap: () async {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SketchPrimaryButton(
                        label: '保存',
                        fill: const Color(0xFFE8F7E7),
                        onTap: () async {
                          await ApiService.post('/nutrition/', {
                            'date': _date,
                            'meal_type': mealType,
                            'recipe_name': recipeCtrl.text,
                            'calories': double.tryParse(calCtrl.text) ?? 0,
                            'protein': 0,
                            'carbs': 0,
                            'fat': 0,
                            'fiber': 0,
                          });
                          Navigator.pop(context);
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NutriBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  const _NutriBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 52) / 2,
      child: HandDrawnCard(
        color: bgColor,
        rotation: 0,
        hoverRotation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: SketchColors.textMain,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SketchFab extends StatelessWidget {
  final VoidCallback onTap;

  const _SketchFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0D9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SketchColors.lineBrown, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x228D6E63),
              offset: Offset(5, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: SketchColors.lineBrown,
          size: 28,
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String text;

  const _TinyBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        color: const Color(0xFFE8F7E7),
        shape: _SketchWobblyShape(radius: 10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: SketchColors.textMain,
        ),
      ),
    );
  }
}

class _SketchRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SketchRoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0D9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SketchColors.lineBrown, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A8D6E63),
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(icon, color: SketchColors.lineBrown, size: 20),
      ),
    );
  }
}

class _SketchChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SketchChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: ShapeDecoration(
          color: selected ? const Color(0xFFFFF0D9) : Colors.white,
          shape: _SketchWobblyShape(radius: 14),
          shadows: const [
            BoxShadow(
              color: Color(0x1A8D6E63),
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: SketchColors.textMain,
          ),
        ),
      ),
    );
  }
}

class _SketchField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  const _SketchField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SketchColors.textMain,
            ),
          ),
        ),
        CustomPaint(
          foregroundPainter: const DashedBorderPainter(
            color: SketchColors.lineBrown,
            strokeWidth: 2,
            dashWidth: 7,
            dashSpace: 4,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.elliptical(38, 20),
                topRight: Radius.elliptical(14, 36),
                bottomRight: Radius.elliptical(34, 16),
                bottomLeft: Radius.elliptical(20, 28),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x128D6E63),
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintStyle: const TextStyle(color: AppColors.textLight),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SketchPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color fill;

  const _SketchPrimaryButton({
    required this.label,
    required this.onTap,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.55 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: ShapeDecoration(
            color: fill,
            shape: _SketchWobblyShape(radius: 18),
            shadows: const [
              BoxShadow(
                color: Color(0x228D6E63),
                offset: Offset(5, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: SketchColors.textMain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SketchWobblyShape extends ShapeBorder {
  final double radius;

  const _SketchWobblyShape({this.radius = 18});

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(2);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect.deflate(2), textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = radius;
    final path = Path();
    path.moveTo(rect.left + r, rect.top + 2);
    path.quadraticBezierTo(rect.left + rect.width * 0.18, rect.top - 3,
        rect.left + rect.width * 0.32, rect.top + 3);
    path.quadraticBezierTo(rect.left + rect.width * 0.56, rect.top + 8,
        rect.right - r, rect.top + 1);
    path.quadraticBezierTo(rect.right + 2, rect.top + 4, rect.right - 2,
        rect.top + r * 0.9);
    path.quadraticBezierTo(rect.right - 4, rect.center.dy,
        rect.right - 1, rect.bottom - r);
    path.quadraticBezierTo(rect.right - rect.width * 0.22, rect.bottom + 4,
        rect.center.dx, rect.bottom - 1);
    path.quadraticBezierTo(rect.left + rect.width * 0.18, rect.bottom + 6,
        rect.left + 4, rect.bottom - r * 0.9);
    path.quadraticBezierTo(rect.left - 4, rect.center.dy, rect.left + 2,
        rect.top + r);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final path = getOuterPath(rect, textDirection: textDirection);
    final paint = Paint()
      ..color = SketchColors.lineBrown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) => _SketchWobblyShape(radius: radius * t);
}
