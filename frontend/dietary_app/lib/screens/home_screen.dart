import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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

  String _mealEmoji(String type) {
    const map = {
      'breakfast': '🌅',
      'lunch': '☀️',
      'dinner': '🌙',
      'snack': '🍪'
    };
    return map[type] ?? '🍽️';
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
    final calories = (totals['calories'] ?? 0) as num;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: _LoadingDots())
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.bgCard,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _CalorieHeroCard(
                          calories: calories.toDouble(),
                          bmr: _bmr,
                        ),
                        const SizedBox(height: 16),
                        _NutritionCard(totals: totals),
                        const SizedBox(height: 16),
                        _MealsCard(
                          meals: meals,
                          mealGroups: mealGroups,
                          mealLabel: _mealLabel,
                          mealEmoji: _mealEmoji,
                        ),
                        const SizedBox(height: 16),
                        _AdviceCard(
                          advice: _advice,
                          loading: _adviceLoading,
                          onTap: _loadAdvice,
                        ),
                        const SizedBox(height: 8),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  SliverAppBar _buildAppBar() {
    final now = DateTime.now();
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final weekday = weekdays[now.weekday - 1];
    return SliverAppBar(
      backgroundColor: AppColors.bg,
      expandedHeight: 100,
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '今日摘要 ✨',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    '${now.month}月${now.day}日 · 周$weekday',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 营养卡 ───────────────────────────────────────────────
class _NutritionCard extends StatelessWidget {
  final Map<String, dynamic> totals;
  const _NutritionCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    return _ClayCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.greenLight, width: 1.5),
                  ),
                  child: const Icon(Icons.eco_rounded, color: AppColors.green, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('营养统计',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _NutriBadge(label: '蛋白质', value: '${(totals['protein'] ?? 0).toStringAsFixed(1)}g', color: AppColors.primary, bgColor: AppColors.primarySoft),
                const SizedBox(width: 10),
                _NutriBadge(label: '碳水', value: '${(totals['carbs'] ?? 0).toStringAsFixed(1)}g', color: AppColors.yellow, bgColor: AppColors.yellowSoft),
                const SizedBox(width: 10),
                _NutriBadge(label: '脂肪', value: '${(totals['fat'] ?? 0).toStringAsFixed(1)}g', color: AppColors.lavender, bgColor: AppColors.lavenderSoft),
                const SizedBox(width: 10),
                _NutriBadge(label: '纤维', value: '${(totals['fiber'] ?? 0).toStringAsFixed(1)}g', color: AppColors.green, bgColor: AppColors.greenSoft),
              ],
            ),
          ],
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

  const _NutriBadge({required this.label, required this.value, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }
}

// ── 餐次卡 ───────────────────────────────────────────────
class _MealsCard extends StatelessWidget {
  final List meals;
  final Map<String, List<dynamic>> mealGroups;
  final String Function(String) mealLabel;
  final String Function(String) mealEmoji;

  const _MealsCard({
    required this.meals,
    required this.mealGroups,
    required this.mealLabel,
    required this.mealEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return _ClayCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.yellowSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.yellow.withOpacity(0.4), width: 1.5),
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: AppColors.yellow, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('今日餐次',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${meals.length} 条',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (meals.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('今天还没有用餐记录 🍽️',
                      style: TextStyle(fontSize: 14, color: AppColors.textLight)),
                ),
              )
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
                    0, (s, m) => s + ((m['calories'] ?? 0) as num).toDouble());
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(mealEmoji(type), style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mealLabel(type),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                            if (names.isNotEmpty)
                              Text(names,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.yellowSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.yellow.withOpacity(0.3), width: 1),
                        ),
                        child: Text('${cal.toStringAsFixed(0)} kcal',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMid)),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ── 饮食建议卡 ───────────────────────────────────────────
class _AdviceCard extends StatelessWidget {
  final String? advice;
  final bool loading;
  final VoidCallback onTap;

  const _AdviceCard({this.advice, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ClayCard(
      color: AppColors.greenSoft,
      borderColor: AppColors.greenLight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.green.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(1, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.tips_and_updates_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('饮食建议',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                ),
                GestureDetector(
                  onTap: loading ? null : onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: loading ? AppColors.border : AppColors.green,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: loading ? [] : [
                        BoxShadow(
                          color: AppColors.green.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      loading ? '生成中...' : '获取建议',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: loading ? AppColors.textLight : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (loading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: _LoadingDots(),
              ))
            else if (advice != null)
              Text(advice!, style: const TextStyle(fontSize: 14, color: AppColors.textDark, height: 1.7))
            else
              Text('点击右上角按钮获取今日饮食建议 🌿',
                  style: TextStyle(fontSize: 14, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }
}

// ── 加载动画 ─────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = ((_ctrl.value - delay) % 1.0 + 1.0) % 1.0;
            final scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.6 + 0.4 * scale),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Clay 卡片基础组件 ────────────────────────────────────
class _ClayCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color borderColor;
  final double radius;

  const _ClayCard({
    required this.child,
    this.color = AppColors.bgCard,
    this.borderColor = AppColors.border,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowOuter,
            blurRadius: 10,
            offset: const Offset(3, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 4,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── 热量英雄卡 ───────────────────────────────────────────
class _CalorieHeroCard extends StatelessWidget {
  final double calories;
  final int? bmr;

  const _CalorieHeroCard({required this.calories, this.bmr});

  @override
  Widget build(BuildContext context) {
    final progress = bmr != null && bmr! > 0
        ? (calories / bmr!).clamp(0.0, 1.0)
        : 0.0;
    final progressColor = progress > 0.9
        ? AppColors.primary
        : progress > 0.6
            ? AppColors.yellow
            : AppColors.green;

    return _ClayCard(
      color: AppColors.primarySoft,
      borderColor: AppColors.primaryLight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(2, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.local_fire_department_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('今日摄入热量',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textMid)),
                    Text(
                      '${calories.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (bmr != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('目标：$bmr kcal',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMid)),
                  Text('${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: progressColor)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white.withOpacity(0.6),
                  valueColor: AlwaysStoppedAnimation(progressColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
