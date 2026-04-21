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
      final aiModel = await ApiConfig.getAiModel();
      if (apiKey == null || apiKey.isEmpty || aiBaseUrl == null || aiBaseUrl.isEmpty || aiModel == null || aiModel.isEmpty) {
        setState(() {
          _advice = '请先在设置中配置 API Key、Base URL 和模型名称';
          _adviceLoading = false;
        });
        return;
      }
      final profile = await ApiService.get('/user/profile');
      final cycleDays = profile['cycle_days'] ?? 7;
      final data = await ApiService.post('/ai/diet-advice', {
        'date': today,
        'cycle_days': cycleDays,
        'api_key': apiKey,
        'ai_base_url': aiBaseUrl,
        'ai_model': aiModel,
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

  String _mealLabel(String type) =>
      const {
        'breakfast': '早餐',
        'lunch': '午餐',
        'dinner': '晚餐',
        'snack': '零食'
      }[type] ??
      type;

  String _mealEmoji(String type) =>
      const {
        'breakfast': '🌅',
        'lunch': '☀️',
        'dinner': '🌙',
        'snack': '🍪'
      }[type] ??
      '🍽️';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final weekday = weekdays[now.weekday - 1];
    final totals = _summary?['totals'] as Map<String, dynamic>? ?? {};
    final meals = (_summary?['meals'] as List?) ?? [];
    final Map<String, List<dynamic>> mealGroups = {};
    for (final m in meals) {
      mealGroups.putIfAbsent(m['meal_type'] ?? 'other', () => []).add(m);
    }
    final calories = (totals['calories'] ?? 0) as num;

    return Scaffold(
      backgroundColor: SketchColors.bg,
      body: Stack(
        children: [
          // 纸张纹理背景点阵
          Positioned.fill(
            child: CustomPaint(painter: PaperDotsPainter()),
          ),
          // 内容
          SafeArea(
            child: _loading
                ? const Center(child: _SketchLoadingDots())
                : RefreshIndicator(
                    color: SketchColors.lineBrown,
                    backgroundColor: Colors.white,
                    onRefresh: _load,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 800;
                        return ListView(
                          padding: EdgeInsets.fromLTRB(
                              isWide ? 40 : 24, 16, isWide ? 40 : 24, 32),
                          children: [
                            // ── 顶部日期 header ──
                            _buildHeader(now, weekday),
                            const SizedBox(height: 28),

                            // ── Grid 布局：宽屏左右并排，窄屏上下堆叠 ──
                            if (isWide) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildCalorieCard(
                                        calories.toDouble()),
                                  ),
                                  const SizedBox(width: 30),
                                  Expanded(
                                    child: _buildNutritionCard(totals),
                                  ),
                                ],
                              ),
                            ] else ...[
                              _buildCalorieCard(calories.toDouble()),
                              const SizedBox(height: 22),
                              _buildNutritionCard(totals),
                            ],
                            const SizedBox(height: 22),

                            // ── 餐次卡 (full width) ──
                            _buildMealsCard(meals, mealGroups),
                            const SizedBox(height: 22),

                            // ── 饮食建议卡 (full width) ──
                            _buildAdviceCard(),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── 顶部日期区域 — 对标 HTML header-area ──────────────────
  Widget _buildHeader(DateTime now, String weekday) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日摘要 📒',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: SketchColors.textMain,
                    fontFamily: 'LXGWWenKai',
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${now.month}月${now.day}日 · 周$weekday',
                  style: TextStyle(
                    fontSize: 14,
                    color: SketchColors.textMain.withOpacity(0.5),
                    fontFamily: 'LXGWWenKai',
                  ),
                ),
              ],
            ),
          ),
          // 手绘小碗装饰 — 对标 HTML sketch-bowl
          const _SketchBowl(),
        ],
      ),
    );
  }

  // ── 今日摄入卡 — pink-tint card-tilt-left ─────────────────
  Widget _buildCalorieCard(double calories) {
    final hasTarget = _bmr != null && _bmr! > 0;
    final remaining = hasTarget
        ? (_bmr! - calories).clamp(0, double.infinity).toStringAsFixed(0)
        : '—';
    final progress = hasTarget ? (calories / _bmr!).clamp(0.0, 1.0) : 0.0;

    return HandDrawnCard(
      color: SketchColors.pinkLight,
      rotation: -1.2,
      hoverRotation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                calories.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: SketchColors.textMain,
                  fontFamily: 'LXGWWenKai',
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'kcal',
                style: TextStyle(
                  fontSize: 16,
                  color: SketchColors.textMain,
                  fontFamily: 'LXGWWenKai',
                ),
              ),
            ],
          ),
          if (calories == 0 && !hasTarget)
            Text(
              '还没开始吃东西哦~',
              style: TextStyle(
                fontSize: 13,
                color: SketchColors.textMain.withOpacity(0.5),
                fontFamily: 'LXGWWenKai',
              ),
            ),
          const SizedBox(height: 14),
          // 目标摄入子卡
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: SketchColors.lineBrown, width: 2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(8),
                bottomLeft: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '目标摄入',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: SketchColors.textMain,
                          fontFamily: 'LXGWWenKai',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasTarget
                            ? '$_bmr kcal'
                            : '点击"智能建议"可自动计算',
                        style: TextStyle(
                          fontSize: 12,
                          color: SketchColors.textMain.withOpacity(0.6),
                          fontFamily: 'LXGWWenKai',
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasTarget)
                  Text(
                    '剩 $remaining',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SketchColors.lineBrown,
                      fontFamily: 'LXGWWenKai',
                    ),
                  ),
              ],
            ),
          ),
          if (hasTarget) ...[
            const SizedBox(height: 10),
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: SketchColors.lineBrown, width: 2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(6),
                  bottomRight: Radius.circular(10),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: Colors.transparent,
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFFFF8C69)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 营养配比卡 — card-tilt-right + nutri-grid ─────────────
  Widget _buildNutritionCard(Map<String, dynamic> totals) {
    return HandDrawnCard(
      rotation: 1.0,
      hoverRotation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 营养配比',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: SketchColors.textMain,
              fontFamily: 'LXGWWenKai',
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth > 520
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _nutriItem(
                      '${(totals['protein'] ?? 0).toStringAsFixed(1)}g',
                      '蛋白质',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _nutriItem(
                      '${(totals['carbs'] ?? 0).toStringAsFixed(1)}g',
                      '碳水',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _nutriItem(
                      '${(totals['fat'] ?? 0).toStringAsFixed(1)}g',
                      '脂肪',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _nutriItem(
                      '${(totals['fiber'] ?? 0).toStringAsFixed(1)}g',
                      '纤维',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 单个营养项 — 对标 HTML nutri-item
  Widget _nutriItem(String value, String label) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: SketchColors.lineBrown, width: 2),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(25),
          bottomRight: Radius.circular(12),
          bottomLeft: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: SketchColors.textMain,
                fontFamily: 'LXGWWenKai',
              )),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: SketchColors.textMain.withOpacity(0.6),
                fontFamily: 'LXGWWenKai',
              )),
        ],
      ),
    );
  }

  // ── 餐次卡 — full-width card-tilt-left ────────────────────
  Widget _buildMealsCard(List meals, Map<String, List<dynamic>> mealGroups) {
    return HandDrawnCard(
      rotation: 0,
      hoverRotation: -1.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🍴 我的餐次',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: SketchColors.textMain,
              fontFamily: 'LXGWWenKai',
            ),
          ),
          const SizedBox(height: 14),
          if (meals.isEmpty)
            // 空状态 — 对标 HTML 虚线空框
            Container(
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFDCDCDC),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '等待第一笔美味记录...',
                  style: TextStyle(
                    fontSize: 14,
                    color: SketchColors.textMain.withOpacity(0.4),
                    fontFamily: 'LXGWWenKai',
                  ),
                ),
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
                  0,
                  (s, m) =>
                      s + ((m['calories'] ?? 0) as num).toDouble());
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                        color: SketchColors.lineBrown, width: 2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(8),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(_mealEmoji(type),
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _mealLabel(type),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: SketchColors.textMain,
                                fontFamily: 'LXGWWenKai',
                              ),
                            ),
                            if (names.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                names,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: SketchColors.textMain
                                      .withOpacity(0.6),
                                  fontFamily: 'LXGWWenKai',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '${cal.toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: SketchColors.lineBrown,
                          fontFamily: 'LXGWWenKai',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── 饮食建议卡 — green-tint card-tilt-right + jelly-btn ──
  Widget _buildAdviceCard() {
    return HandDrawnCard(
      color: SketchColors.greenLight,
      rotation: 0,
      hoverRotation: 1.5,
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
      child: Column(
        children: [
          const Text(
            '🌱 智能建议',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: SketchColors.textMain,
              fontFamily: 'LXGWWenKai',
            ),
          ),
          const SizedBox(height: 8),
          if (_adviceLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: _SketchLoadingDots(),
            )
          else if (_advice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _advice!,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 14,
                  color: SketchColors.textMain,
                  height: 1.7,
                  fontFamily: 'LXGWWenKai',
                ),
              ),
            )
          else
            const Text(
              '想知道今天怎么吃更健康吗？',
              style: TextStyle(
                fontSize: 14,
                color: SketchColors.textMain,
                fontFamily: 'LXGWWenKai',
              ),
            ),
          const SizedBox(height: 12),
          JellyButton(
            onTap: _adviceLoading ? null : _loadAdvice,
            child: Text(_adviceLoading ? '生成中...' : '获取建议'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 手绘装饰组件
// ══════════════════════════════════════════════════════════════

/// 手绘小碗 — 对标 HTML sketch-bowl
class _SketchBowl extends StatelessWidget {
  const _SketchBowl();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 50,
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: 60,
              height: 35,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: SketchColors.lineBrown, width: 3),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 18,
            child: Opacity(
              opacity: 0.6,
              child: Text('♨️', style: TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 手绘风加载动画
class _SketchLoadingDots extends StatefulWidget {
  const _SketchLoadingDots();

  @override
  State<_SketchLoadingDots> createState() => _SketchLoadingDotsState();
}

class _SketchLoadingDotsState extends State<_SketchLoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
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
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = ((_ctrl.value - i / 3) % 1.0 + 1.0) % 1.0;
          final scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color:
                      SketchColors.lineBrown.withOpacity(0.3 + 0.7 * scale),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: SketchColors.lineBrown, width: 1.5),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
