import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback_dialog.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final Map<String, List<dynamic>>? stepsCache;

  const RecipeDetailScreen({super.key, required this.recipe, this.stepsCache});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  List<RecipeStep> _steps = [];
  bool _loading = true;
  String? _error;
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    try {
      final list = await ApiService.getList('/favorites/');
      setState(() {
        _isFavorited = list.any((f) => f['recipe_name'] == widget.recipe.name);
      });
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    try {
      if (_isFavorited) {
        final list = await ApiService.getList('/favorites/');
        final matches = list.where((f) => f['recipe_name'] == widget.recipe.name).toList();
        final fav = matches.isEmpty ? null : matches.first;
        if (fav != null) await ApiService.delete('/favorites/${fav['id']}');
        setState(() => _isFavorited = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消收藏')));
      } else {
        final recipeJson = jsonEncode(widget.recipe.toJson());
        await ApiService.post('/favorites/', {
          'recipe_name': widget.recipe.name,
          'recipe_data': recipeJson,
        });
        setState(() => _isFavorited = true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ 已收藏')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
    }
  }

  Future<void> _loadDetail() async {
    final cache = widget.stepsCache;
    final key = widget.recipe.name;

    if (cache != null && cache.containsKey(key)) {
      setState(() {
        _steps = cache[key]!.map((e) => RecipeStep.fromJson(Map<String, dynamic>.from(e))).toList();
        _loading = false;
      });
      return;
    }

    try {
      final apiKey = await ApiConfig.getApiKey();
      final aiBaseUrl = await ApiConfig.getAiBaseUrl();
      final imageApiKey = await ApiConfig.getImageApiKey();
      final imageBaseUrl = await ApiConfig.getImageBaseUrl();

      final data = await ApiService.post('/recipes/detail', {
        'recipe_name': widget.recipe.name,
        'steps': widget.recipe.steps,
        if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
        if (aiBaseUrl != null && aiBaseUrl.isNotEmpty) 'ai_base_url': aiBaseUrl,
        if (imageApiKey != null && imageApiKey.isNotEmpty) 'image_api_key': imageApiKey,
        if (imageBaseUrl != null && imageBaseUrl.isNotEmpty) 'image_base_url': imageBaseUrl,
      });

      final rawSteps = data['steps'] as List;
      if (cache != null) cache[key] = rawSteps;

      setState(() {
        _steps = rawSteps.map((e) => RecipeStep.fromJson(Map<String, dynamic>.from(e))).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _showLogDialog() {
    final recipe = widget.recipe;
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    final mealLabels = ['早餐 🌅', '午餐 ☀️', '晚餐 🌙', '零食 🍪'];
    String mealType = 'lunch';
    final today = DateTime.now().toIso8601String().substring(0, 10);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: CustomPaint(
            foregroundPainter: DashedBorderPainter(wobble: 1.4),
            child: Container(
              decoration: BoxDecoration(
                color: SketchColors.bg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.elliptical(40, 20),
                  topRight: Radius.elliptical(15, 50),
                  bottomRight: Radius.elliptical(50, 15),
                  bottomLeft: Radius.elliptical(20, 40),
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x1A8D6E63), offset: Offset(10, 10), blurRadius: 0),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('记录这道菜 🍽️',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: SketchColors.textMain,
                        fontFamily: 'LXGWWenKai',
                      )),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SketchColors.pinkLight,
                      border: Border.all(color: SketchColors.lineBrown, width: 2),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(8),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(recipe.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: SketchColors.textMain,
                              fontFamily: 'LXGWWenKai',
                            )),
                        const SizedBox(height: 4),
                        Text(
                          '${_nutritionValue(recipe.nutrition, 'calories').toStringAsFixed(0)} kcal · 蛋白质 ${_nutritionValue(recipe.nutrition, 'protein').toStringAsFixed(1)}g',
                          style: TextStyle(
                            fontSize: 13,
                            color: SketchColors.textMain.withOpacity(0.6),
                            fontFamily: 'LXGWWenKai',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(8),
                        bottomLeft: Radius.circular(14),
                      ),
                      border: Border.all(color: SketchColors.lineBrown, width: 2),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: mealType,
                        isExpanded: true,
                        style: const TextStyle(
                          color: SketchColors.textMain,
                          fontFamily: 'LXGWWenKai',
                          fontSize: 14,
                        ),
                        items: List.generate(mealTypes.length, (i) => DropdownMenuItem(
                          value: mealTypes[i], child: Text(mealLabels[i]),
                        )),
                        onChanged: (v) { if (v != null) setS(() => mealType = v); },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: SketchColors.lineBrown, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Color(0x1A8D6E63), offset: Offset(3, 3), blurRadius: 0),
                          ],
                        ),
                        child: const Center(child: Text('取消',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: SketchColors.textMain,
                              fontFamily: 'LXGWWenKai',
                            ))),
                      ),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _logNutritionAndDeductIngredients(mealType, today);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: SketchColors.accentSoft,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: SketchColors.lineBrown, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Color(0x1A8D6E63), offset: Offset(3, 3), blurRadius: 0),
                          ],
                        ),
                        child: const Center(child: Text('确认记录',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: SketchColors.textMain,
                              fontFamily: 'LXGWWenKai',
                            ))),
                      ),
                    )),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logNutritionAndDeductIngredients(String mealType, String date) async {
    final recipe = widget.recipe;
    try {
      await ApiService.post('/nutrition/', {
        'date': date, 'meal_type': mealType, 'recipe_name': recipe.name,
        'calories': _nutritionValue(recipe.nutrition, 'calories'),
        'protein': _nutritionValue(recipe.nutrition, 'protein'),
        'carbs': _nutritionValue(recipe.nutrition, 'carbs'),
        'fat': _nutritionValue(recipe.nutrition, 'fat'),
        'fiber': _nutritionValue(recipe.nutrition, 'fiber'),
      });
      final apiKey = await ApiConfig.getApiKey();
      final aiBaseUrl = await ApiConfig.getAiBaseUrl();
      await ApiService.post('/ingredients/deduct', {
        'recipe_name': recipe.name,
        'ingredients': recipe.ingredients,
        if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
        if (aiBaseUrl != null && aiBaseUrl.isNotEmpty) 'ai_base_url': aiBaseUrl,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ 已记录营养摄入，食材已扣减')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('记录失败：$e')),
      );
    }
  }

  void _showFeedbackDialog() {
    FeedbackDialog.show(context, widget.recipe.name, cooked: true);
  }

  double _nutritionValue(Map<String, dynamic> nutrition, String key) {
    final value = nutrition[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    return Scaffold(
      backgroundColor: SketchColors.bg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: PaperDotsPainter())),
          SafeArea(
            child: Column(
              children: [
                // 手绘风顶栏
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                  child: Row(
                    children: [
                      _SketchIconBtn(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recipe.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: SketchColors.textMain,
                            fontFamily: 'LXGWWenKai',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _SketchIconBtn(
                        icon: _isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        onTap: _toggleFavorite,
                        active: _isFavorited,
                      ),
                      const SizedBox(width: 6),
                      _SketchIconBtn(
                        icon: Icons.add_circle_outline_rounded,
                        onTap: _showLogDialog,
                      ),
                      const SizedBox(width: 6),
                      _SketchIconBtn(
                        icon: Icons.star_outline_rounded,
                        onTap: _showFeedbackDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 内容区
                Expanded(
                  child: _loading
                      ? const Center(child: _SketchLoadingDots())
                      : _error != null
                          ? Center(
                              child: Text('加载失败：$_error',
                                  style: const TextStyle(
                                    color: SketchColors.textMain,
                                    fontFamily: 'LXGWWenKai',
                                  )),
                            )
                          : _buildContent(recipe),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Recipe recipe) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;
        final hPad = isWide ? 36.0 : 20.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 32),
          children: [
            // 基本信息卡
            HandDrawnCard(
              color: SketchColors.pinkLight,
              rotation: -0.6,
              hoverRotation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _SketchInfoChip(emoji: '⏱️', label: '${recipe.timeMinutes} 分钟'),
                  _SketchInfoChip(
                    emoji: '🔥',
                    label: '${_nutritionValue(recipe.nutrition, 'calories').toStringAsFixed(0)} kcal',
                  ),
                  if (recipe.category != null)
                    _SketchInfoChip(emoji: '🏷️', label: recipe.category!),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // 食材
            _SketchSectionHeader(emoji: '🥬', title: '食材'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recipe.ingredients.map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 13,
                    color: SketchColors.textMain,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'LXGWWenKai',
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),
            // 烹饪步骤
            _SketchSectionHeader(emoji: '👨‍🍳', title: '烹饪步骤'),
            const SizedBox(height: 12),
            if (!isWide)
              Column(children: [
                for (int i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _SketchStepCard(index: i, step: _steps[i]),
                ],
              ])
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: [
                    for (int i = 0; i < _steps.length; i += 2) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _SketchStepCard(index: i, step: _steps[i]),
                    ],
                  ])),
                  const SizedBox(width: 14),
                  Expanded(child: Column(children: [
                    for (int i = 1; i < _steps.length; i += 2) ...[
                      if (i > 1) const SizedBox(height: 14),
                      _SketchStepCard(index: i, step: _steps[i]),
                    ],
                  ])),
                ],
              ),
            const SizedBox(height: 24),
            // 底部操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                JellyButton(
                  onTap: _showLogDialog,
                  child: const Text('📝 记录这道菜'),
                ),
                const SizedBox(width: 16),
                JellyButton(
                  onTap: _showFeedbackDialog,
                  child: const Text('⭐ 评价'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 手绘风子组件
// ══════════════════════════════════════════════════════════════

/// 手绘风顶栏图标按钮
class _SketchIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _SketchIconBtn({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFF0F0) : Colors.white,
          border: Border.all(color: SketchColors.lineBrown, width: 2),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(8),
            bottomLeft: Radius.circular(14),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x1A8D6E63), offset: Offset(3, 3), blurRadius: 0),
          ],
        ),
        child: Icon(icon, size: 20, color: active ? const Color(0xFFE57373) : SketchColors.lineBrown),
      ),
    );
  }
}

/// 手绘风信息标签
class _SketchInfoChip extends StatelessWidget {
  final String emoji;
  final String label;

  const _SketchInfoChip({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 15)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: SketchColors.textMain,
        fontFamily: 'LXGWWenKai',
      )),
    ]);
  }
}

/// 手绘风区块标题
class _SketchSectionHeader extends StatelessWidget {
  final String emoji;
  final String title;

  const _SketchSectionHeader({required this.emoji, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: SketchColors.textMain,
        fontFamily: 'LXGWWenKai',
      )),
    ]);
  }
}

/// 手绘风步骤卡片 — 虚线边框 + 微倾斜 + 偏移阴影
class _SketchStepCard extends StatelessWidget {
  final int index;
  final RecipeStep step;

  const _SketchStepCard({required this.index, required this.step});

  // 每张卡片微倾斜角度交替
  static const _rotations = [-0.8, 0.6, -0.4, 0.9, -0.5, 0.7];

  @override
  Widget build(BuildContext context) {
    final panels = <Widget>[];
    if (step.resultDescription.isNotEmpty) {
      panels.add(_SketchInfoPanel(
        title: '完成标准',
        emoji: '✅',
        bgColor: SketchColors.greenLight,
        description: step.resultDescription,
        imageUrl: step.resultImageUrl,
      ));
    }
    if (step.processDescription.isNotEmpty) {
      panels.add(_SketchInfoPanel(
        title: '操作要点',
        emoji: '💡',
        bgColor: const Color(0xFFFFF8E8),
        description: step.processDescription,
        imageUrl: step.processImageUrl,
      ));
    }

    final rot = _rotations[index % _rotations.length];

    return HandDrawnCard(
      rotation: rot,
      hoverRotation: 0,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // 步骤编号 — 手绘圆圈
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: SketchColors.accentSoft,
                shape: BoxShape.circle,
                border: Border.all(color: SketchColors.lineBrown, width: 2.5),
              ),
              child: Center(
                child: Text('${index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: SketchColors.textMain,
                    fontFamily: 'LXGWWenKai',
                  )),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(step.step,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: SketchColors.textMain,
                  fontFamily: 'LXGWWenKai',
                  height: 1.5,
                )),
            ),
          ]),
          if (panels.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final split = panels.length > 1 && constraints.maxWidth >= 520;
              if (!split) {
                return Column(children: [
                  for (int i = 0; i < panels.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    panels[i],
                  ],
                ]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: panels[0]),
                const SizedBox(width: 8),
                Expanded(child: panels[1]),
              ]);
            }),
          ],
        ],
      ),
    );
  }
}

/// 手绘风步骤信息面板
class _SketchInfoPanel extends StatelessWidget {
  final String title;
  final String emoji;
  final Color bgColor;
  final String description;
  final String? imageUrl;

  const _SketchInfoPanel({
    required this.title,
    required this.emoji,
    required this.bgColor,
    required this.description,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: SketchColors.lineBrown.withOpacity(0.4), width: 1.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(6),
          bottomLeft: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(
              fontSize: 12,
              color: SketchColors.textMain,
              fontWeight: FontWeight.w800,
              fontFamily: 'LXGWWenKai',
            )),
          ]),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(
            fontSize: 13,
            color: SketchColors.textMain.withOpacity(0.8),
            height: 1.5,
            fontFamily: 'LXGWWenKai',
          )),
          if (imageUrl != null) ...[
            const SizedBox(height: 8),
            _ProxiedImage(url: imageUrl!, height: 160),
          ],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
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
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: SketchColors.lineBrown.withOpacity(0.3 + 0.7 * scale),
                      shape: BoxShape.circle,
                      border: Border.all(color: SketchColors.lineBrown, width: 1.5),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        Text('AI 正在生成步骤详情...',
          style: TextStyle(
            color: SketchColors.textMain.withOpacity(0.6),
            fontSize: 14,
            fontFamily: 'LXGWWenKai',
          )),
      ],
    );
  }
}

class _ProxiedImage extends StatefulWidget {
  final String url;
  final double height;

  const _ProxiedImage({required this.url, this.height = 160});

  @override
  State<_ProxiedImage> createState() => _ProxiedImageState();
}

class _ProxiedImageState extends State<_ProxiedImage> {
  String? _proxyUrl;

  @override
  void initState() {
    super.initState();
    _buildProxyUrl();
  }

  Future<void> _buildProxyUrl() async {
    final base = await ApiConfig.getBaseUrl();
    final encoded = Uri.encodeComponent(widget.url);
    if (mounted) setState(() => _proxyUrl = '$base/ai/image-proxy?url=$encoded');
  }

  @override
  Widget build(BuildContext context) {
    if (_proxyUrl == null) {
      return SizedBox(height: widget.height,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: SketchColors.lineBrown)));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: SketchColors.lineBrown.withOpacity(0.3), width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.5),
          child: Image.network(
            _proxyUrl!,
            width: double.infinity,
            height: widget.height,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => SizedBox(
              height: widget.height,
              child: const Center(child: Icon(Icons.broken_image_rounded, color: SketchColors.lineBrown, size: 32)),
            ),
          ),
        ),
      ),
    );
  }
}
