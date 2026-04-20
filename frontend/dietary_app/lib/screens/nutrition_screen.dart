import 'dart:math' show pi, min, cos, sin;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

// ── 营养素配置表 ──────────────────────────────────────────
class _MacroInfo {
  final String key;
  final String label;
  final String emoji;
  final double target;
  final Color color;
  final Color tint;

  const _MacroInfo({
    required this.key,
    required this.label,
    required this.emoji,
    required this.target,
    required this.color,
    required this.tint,
  });
}

const _macros = [
  _MacroInfo(key: 'protein', label: '蛋白质', emoji: '🥩', target: 60, color: Color(0xFFFF8A7A), tint: Color(0xFFFFF0E8)),
  _MacroInfo(key: 'carbs',   label: '碳水',   emoji: '🍚', target: 250, color: Color(0xFF6CC3A0), tint: Color(0xFFEEF8EB)),
  _MacroInfo(key: 'fat',     label: '脂肪',   emoji: '🧈', target: 55, color: Color(0xFFF9C270), tint: Color(0xFFFFF7DC)),
  _MacroInfo(key: 'fiber',   label: '纤维',   emoji: '🥬', target: 25, color: Color(0xFF9B87F5), tint: Color(0xFFF4EEFB)),
];

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
      _date = DateTime.parse(_date)
          .add(Duration(days: days))
          .toIso8601String()
          .substring(0, 10);
    });
    _load();
  }

  bool get _isToday =>
      _date == DateTime.now().toIso8601String().substring(0, 10);

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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 860;
                      final pad = isWide ? 32.0 : 16.0;
                      return ListView(
                        padding: EdgeInsets.fromLTRB(pad, 8, pad, 90),
                        children: [
                          _buildDateHeader(),
                          const SizedBox(height: 20),
                          if (isWide)
                            _buildWideLayout(totals, calories.toDouble())
                          else
                            _buildNarrowLayout(totals, calories.toDouble()),
                        ],
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  // ── 日期切换 header ──────────────────────────────────────
  Widget _buildDateHeader() {
    return HandDrawnCard(
      color: Colors.white,
      rotation: 0,
      hoverRotation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    fontFamily: 'LXGWWenKai',
                  ),
                ),
                if (_isToday)
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
    );
  }

  // ── 宽屏双栏布局 ──────────────────────────────────────────
  Widget _buildWideLayout(Map<String, dynamic> totals, double calories) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左栏：热量 hero + 圆环
        Expanded(
          flex: 12,
          child: Column(
            children: [
              _buildCalorieHero(calories),
              const SizedBox(height: 20),
              _buildMacroRingsSection(totals),
            ],
          ),
        ),
        const SizedBox(width: 28),
        // 右栏：图表（高度匹配左栏）
        Expanded(
          flex: 18,
          child: _buildChartCard(totals, expand: true),
        ),
      ],
    );
  }

  // ── 窄屏纵向堆叠 ──────────────────────────────────────────
  Widget _buildNarrowLayout(Map<String, dynamic> totals, double calories) {
    return Column(
      children: [
        _buildCalorieHero(calories),
        const SizedBox(height: 18),
        _buildMacroRingsSection(totals),
        const SizedBox(height: 18),
        _buildChartCard(totals, expand: false),
      ],
    );
  }

  // ── 热量 Hero 卡 ──────────────────────────────────────────
  Widget _buildCalorieHero(double calories) {
    const double target = 2000;
    final progress = (calories / target).clamp(0.0, 1.0);
    final remaining = (target - calories).clamp(0, double.infinity);

    return HandDrawnCard(
      color: SketchColors.pinkLight,
      rotation: -0.8,
      hoverRotation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🔥 今日摄入',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SketchColors.textMain,
                  fontFamily: 'LXGWWenKai',
                ),
              ),
              const Spacer(),
              if (_isToday)
                const _TinyBadge(text: 'TODAY'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                calories.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: SketchColors.textMain,
                  fontFamily: 'LXGWWenKai',
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'kcal',
                style: TextStyle(
                  fontSize: 15,
                  color: SketchColors.textMain,
                  fontFamily: 'LXGWWenKai',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: SketchColors.lineBrown.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFF8A7A)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已摄入 ${calories.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: SketchColors.textMain.withOpacity(0.6),
                  fontFamily: 'LXGWWenKai',
                ),
              ),
              Text(
                '剩余 ${remaining.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: SketchColors.textMain.withOpacity(0.6),
                  fontFamily: 'LXGWWenKai',
                ),
              ),
            ],
          ),
          if (calories == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '还没开始记录哦，点右下角 + 添加~',
                style: TextStyle(
                  fontSize: 12,
                  color: SketchColors.textMain.withOpacity(0.45),
                  fontFamily: 'LXGWWenKai',
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 2x2 营养圆环区 ─────────────────────────────────────────
  Widget _buildMacroRingsSection(Map<String, dynamic> totals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 6, bottom: 12),
          child: Text(
            '每日摄入目标',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: SketchColors.textMain,
              fontFamily: 'LXGWWenKai',
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final spacing = 12.0;
            final cardW = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: _macros.map((m) {
                final value = (totals[m.key] ?? 0).toDouble();
                return SizedBox(
                  width: cardW,
                  child: _MacroRingCard(info: m, value: value),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ── 营养柱状图卡 ──────────────────────────────────────────
  Widget _buildChartCard(Map<String, dynamic> totals, {bool expand = false}) {
    final chartContent = BarChart(
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
        barGroups: List.generate(_macros.length, (i) {
          final m = _macros[i];
          final v = (totals[m.key] ?? 0).toDouble();
          return _bar(i, v, m.color);
        }),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= _macros.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${_macros[idx].emoji} ${_macros[idx].label}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: SketchColors.textMain,
                      fontFamily: 'LXGWWenKai',
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
                  fontFamily: 'LXGWWenKai',
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
    );

    return HandDrawnCard(
      color: Colors.white,
      rotation: 0,
      hoverRotation: 0,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '📊 营养分布',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: SketchColors.textMain,
                  fontFamily: 'LXGWWenKai',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0D9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: SketchColors.lineBrown.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _isToday ? '今日' : _date,
                  style: TextStyle(
                    fontSize: 10,
                    color: SketchColors.textMain.withOpacity(0.6),
                    fontFamily: 'LXGWWenKai',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (expand)
            SizedBox(height: 480, child: chartContent)
          else
            SizedBox(height: 240, child: chartContent),
          const SizedBox(height: 12),
          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _macros.map((m) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: m.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      m.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: SketchColors.textMain.withOpacity(0.6),
                        fontFamily: 'LXGWWenKai',
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) => BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: y,
            color: color,
            width: 32,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: (y * 1.3).clamp(10, double.infinity),
              color: color.withOpacity(0.10),
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
                _SketchField(controller: recipeCtrl, label: '菜名', hint: '请输入今天吃的食物'),
                const SizedBox(height: 12),
                _SketchField(controller: calCtrl, label: '热量 (kcal)', hint: '请输入热量数值', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                const Text('餐次', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SketchColors.textMain)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: List.generate(4, (i) => _SketchChoiceChip(
                    label: mealLabels[i],
                    selected: mealType == mealTypes[i],
                    onTap: () => setS(() => mealType = mealTypes[i]),
                  )),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _SketchPrimaryButton(label: '取消', fill: Colors.white, onTap: () => Navigator.pop(context))),
                  const SizedBox(width: 12),
                  Expanded(child: _SketchPrimaryButton(
                    label: '保存',
                    fill: const Color(0xFFE8F7E7),
                    onTap: () async {
                      await ApiService.post('/nutrition/', {
                        'date': _date, 'meal_type': mealType,
                        'recipe_name': recipeCtrl.text,
                        'calories': double.tryParse(calCtrl.text) ?? 0,
                        'protein': 0, 'carbs': 0, 'fat': 0, 'fiber': 0,
                      });
                      Navigator.pop(context);
                      _load();
                    },
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 圆环卡片 + 圆环画笔
// ══════════════════════════════════════════════════════════════

class _MacroRingCard extends StatelessWidget {
  final _MacroInfo info;
  final double value;

  const _MacroRingCard({required this.info, required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = (value / info.target).clamp(0.0, 1.0);
    final pctText = '${(pct * 100).toStringAsFixed(0)}%';

    return HandDrawnCard(
      color: info.tint,
      rotation: 0,
      hoverRotation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${info.emoji} ${info.label}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SketchColors.textMain,
              fontFamily: 'LXGWWenKai',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: _NutritionRingPainter(
                progress: pct,
                color: info.color,
                bgColor: SketchColors.lineBrown.withOpacity(0.10),
                strokeWidth: 9,
              ),
              child: Center(
                child: Text(
                  pctText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: info.color,
                    fontFamily: 'LXGWWenKai',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${value.toStringAsFixed(1)}g',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: info.color,
              fontFamily: 'LXGWWenKai',
            ),
          ),
          Text(
            '目标 ${info.target.toStringAsFixed(0)}g',
            style: TextStyle(
              fontSize: 10,
              color: SketchColors.textMain.withOpacity(0.5),
              fontFamily: 'LXGWWenKai',
            ),
          ),
        ],
      ),
    );
  }
}

// ── 圆环画笔 ──────────────────────────────────────────────
class _NutritionRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  const _NutritionRingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
    this.strokeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 背景环
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // 进度弧
    if (progress > 0) {
      final fgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(_NutritionRingPainter old) =>
      progress != old.progress || color != old.color;
}

// ══════════════════════════════════════════════════════════════
// 辅助小组件（保留原有）
// ══════════════════════════════════════════════════════════════

class _SketchFab extends StatelessWidget {
  final VoidCallback onTap;
  const _SketchFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58, height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0D9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SketchColors.lineBrown, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x228D6E63), offset: Offset(5, 5), blurRadius: 0)],
        ),
        child: const Icon(Icons.add_rounded, color: SketchColors.lineBrown, size: 28),
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
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SketchColors.textMain)),
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
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0D9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SketchColors.lineBrown, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x1A8D6E63), offset: Offset(4, 4), blurRadius: 0)],
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
  const _SketchChoiceChip({required this.label, required this.selected, required this.onTap});

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
          shadows: const [BoxShadow(color: Color(0x1A8D6E63), offset: Offset(3, 3), blurRadius: 0)],
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: SketchColors.textMain)),
      ),
    );
  }
}

class _SketchField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  const _SketchField({required this.controller, required this.label, required this.hint, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SketchColors.textMain)),
        ),
        CustomPaint(
          foregroundPainter: const DashedBorderPainter(color: SketchColors.lineBrown, strokeWidth: 2, dashWidth: 7, dashSpace: 4),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.elliptical(38, 20), topRight: Radius.elliptical(14, 36),
                bottomRight: Radius.elliptical(34, 16), bottomLeft: Radius.elliptical(20, 28),
              ),
              boxShadow: [BoxShadow(color: Color(0x128D6E63), offset: Offset(4, 4), blurRadius: 0)],
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hint, border: InputBorder.none, enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none, filled: false,
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
  const _SketchPrimaryButton({required this.label, required this.onTap, required this.fill});

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
            shadows: const [BoxShadow(color: Color(0x228D6E63), offset: Offset(5, 5), blurRadius: 0)],
          ),
          child: Center(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: SketchColors.textMain))),
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
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(2), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = radius;
    final path = Path();
    path.moveTo(rect.left + r, rect.top + 2);
    path.quadraticBezierTo(rect.left + rect.width * 0.18, rect.top - 3, rect.left + rect.width * 0.32, rect.top + 3);
    path.quadraticBezierTo(rect.left + rect.width * 0.56, rect.top + 8, rect.right - r, rect.top + 1);
    path.quadraticBezierTo(rect.right + 2, rect.top + 4, rect.right - 2, rect.top + r * 0.9);
    path.quadraticBezierTo(rect.right - 4, rect.center.dy, rect.right - 1, rect.bottom - r);
    path.quadraticBezierTo(rect.right - rect.width * 0.22, rect.bottom + 4, rect.center.dx, rect.bottom - 1);
    path.quadraticBezierTo(rect.left + rect.width * 0.18, rect.bottom + 6, rect.left + 4, rect.bottom - r * 0.9);
    path.quadraticBezierTo(rect.left - 4, rect.center.dy, rect.left + 2, rect.top + r);
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
