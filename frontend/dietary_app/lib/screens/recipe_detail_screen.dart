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
                const Text('记录这道菜 🍽️',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryLight, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      Text(
                        '${_nutritionValue(recipe.nutrition, 'calories').toStringAsFixed(0)} kcal · 蛋白质 ${_nutritionValue(recipe.nutrition, 'protein').toStringAsFixed(1)}g',
                        style: const TextStyle(fontSize: 13, color: AppColors.textMid),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
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
                      Navigator.pop(ctx);
                      await _logNutritionAndDeductIngredients(mealType, today);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(1, 3))],
                      ),
                      child: const Center(child: Text('确认记录',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
                    ),
                  )),
                ]),
              ],
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(recipe.name),
        actions: [
          GestureDetector(
            onTap: _toggleFavorite,
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isFavorited ? const Color(0xFFFFEBEB) : AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isFavorited ? const Color(0xFFFFCCCC) : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Icon(
                _isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFavorited ? const Color(0xFFE57373) : AppColors.textLight,
                size: 20,
              ),
            ),
          ),
          GestureDetector(
            onTap: _showLogDialog,
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryLight, width: 1.5),
              ),
              child: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 20),
            ),
          ),
          GestureDetector(
            onTap: _showFeedbackDialog,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.yellowSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE599), width: 1.5),
              ),
              child: const Icon(Icons.star_outline_rounded, color: Color(0xFFD4A017), size: 20),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(
                  width: 44, height: 44,
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                ),
                const SizedBox(height: 14),
                Text('AI 正在生成步骤详情...', style: TextStyle(color: AppColors.textMid, fontSize: 14)),
              ]),
            )
          : _error != null
              ? Center(child: Text('加载失败：$_error', style: const TextStyle(color: AppColors.textMid)))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final useTwoColumns = constraints.maxWidth >= 860;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        // 基本信息卡
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primaryLight, width: 3),
                            boxShadow: ClayShadow.raised(),
                          ),
                          child: Row(children: [
                            _InfoChip(icon: Icons.timer_outlined, label: '${recipe.timeMinutes} 分钟', color: AppColors.primary),
                            const SizedBox(width: 10),
                            _InfoChip(icon: Icons.local_fire_department_outlined,
                                label: '${_nutritionValue(recipe.nutrition, 'calories').toStringAsFixed(0)} kcal',
                                color: AppColors.primary),
                            if (recipe.category != null) ...[
                              const SizedBox(width: 10),
                              _InfoChip(icon: Icons.label_outline_rounded, label: recipe.category!, color: AppColors.green),
                            ],
                          ]),
                        ),
                        const SizedBox(height: 14),
                        // 食材
                        _SectionHeader(emoji: '🥬', title: '食材'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: recipe.ingredients.map((item) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.greenSoft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.greenLight, width: 1.5),
                            ),
                            child: Text(item, style: const TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w600)),
                          )).toList(),
                        ),
                        const SizedBox(height: 16),
                        // 烹饪步骤
                        _SectionHeader(emoji: '👨‍🍳', title: '烹饪步骤'),
                        const SizedBox(height: 10),
                        if (!useTwoColumns)
                          Column(children: [
                            for (int i = 0; i < _steps.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _StepCard(index: i, step: _steps[i]),
                            ],
                          ])
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Column(children: [
                                for (int i = 0; i < _steps.length; i += 2) ...[
                                  if (i > 0) const SizedBox(height: 10),
                                  _StepCard(index: i, step: _steps[i]),
                                ],
                              ])),
                              const SizedBox(width: 10),
                              Expanded(child: Column(children: [
                                for (int i = 1; i < _steps.length; i += 2) ...[
                                  if (i > 1) const SizedBox(height: 10),
                                  _StepCard(index: i, step: _steps[i]),
                                ],
                              ])),
                            ],
                          ),
                        const SizedBox(height: 20),
                        // 底部操作按钮
                        Row(children: [
                          Expanded(child: ClayButton(
                            onTap: _showLogDialog,
                            color: AppColors.primarySoft,
                            borderColor: AppColors.primaryLight,
                            shadows: ClayShadow.raised(depth: 0.8),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            radius: 16,
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 18),
                              SizedBox(width: 6),
                              Text('记录这道菜', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ]),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: ClayButton(
                            onTap: _showFeedbackDialog,
                            color: AppColors.yellowSoft,
                            borderColor: const Color(0xFFFFE599),
                            shadows: ClayShadow.raised(
                              darkColor: const Color(0x44D4A017),
                              lightColor: const Color(0xBBFFFFFF),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            radius: 16,
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.star_outline_rounded, color: Color(0xFFD4A017), size: 18),
                              SizedBox(width: 6),
                              Text('评价', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFD4A017))),
                            ]),
                          )),
                        ]),
                      ],
                    );
                  },
                ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    ]);
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
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
    ]);
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final RecipeStep step;

  const _StepCard({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    final panels = <Widget>[];
    if (step.resultDescription.isNotEmpty) {
      panels.add(_StepInfoPanel(
        title: '完成标准',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.green,
        bgColor: AppColors.greenSoft,
        borderColor: AppColors.greenLight,
        description: step.resultDescription,
        imageUrl: step.resultImageUrl,
      ));
    }
    if (step.processDescription.isNotEmpty) {
      panels.add(_StepInfoPanel(
        title: '操作要点',
        icon: Icons.info_outline_rounded,
        color: AppColors.blue,
        bgColor: AppColors.blueSoft,
        borderColor: AppColors.blue.withOpacity(0.3),
        description: step.processDescription,
        imageUrl: step.processImageUrl,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 3),
        boxShadow: ClayShadow.raised(),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.primaryLight, width: 1.5),
              ),
              child: Center(
                child: Text('${index + 1}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(step.step,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
            ),
          ]),
          if (panels.isNotEmpty) ...[
            const SizedBox(height: 10),
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

class _StepInfoPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String description;
  final String? imageUrl;

  const _StepInfoPanel({
    required this.title,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.description,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.5)),
              ],
            )),
          ]),
          if (imageUrl != null) ...[
            const SizedBox(height: 8),
            _ProxiedImage(url: imageUrl!, height: 160),
          ],
        ],
      ),
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
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        _proxyUrl!,
        width: double.infinity,
        height: widget.height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => SizedBox(
          height: widget.height,
          child: const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.textLight, size: 32)),
        ),
      ),
    );
  }
}
