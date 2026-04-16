import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';
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
        final matches =
            list.where((f) => f['recipe_name'] == widget.recipe.name).toList();
        final fav = matches.isEmpty ? null : matches.first;
        if (fav != null) {
          await ApiService.delete('/favorites/${fav['id']}');
        }
        setState(() => _isFavorited = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已取消收藏')),
          );
        }
      } else {
        final recipeJson = jsonEncode(widget.recipe.toJson());
        await ApiService.post('/favorites/', {
          'recipe_name': widget.recipe.name,
          'recipe_data': recipeJson,
        });
        setState(() => _isFavorited = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已收藏'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadDetail() async {
    final cache = widget.stepsCache;
    final key = widget.recipe.name;

    if (cache != null && cache.containsKey(key)) {
      setState(() {
        _steps = cache[key]!
            .map((e) => RecipeStep.fromJson(Map<String, dynamic>.from(e)))
            .toList();
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
        if (imageApiKey != null && imageApiKey.isNotEmpty)
          'image_api_key': imageApiKey,
        if (imageBaseUrl != null && imageBaseUrl.isNotEmpty)
          'image_base_url': imageBaseUrl,
      });

      final rawSteps = data['steps'] as List;
      if (cache != null) cache[key] = rawSteps;

      setState(() {
        _steps = rawSteps
            .map((e) => RecipeStep.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showLogDialog() {
    final recipe = widget.recipe;
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    final mealLabels = ['早餐', '午餐', '晚餐', '零食'];
    String mealType = 'lunch';
    final today = DateTime.now().toIso8601String().substring(0, 10);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('记录这道菜'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                recipe.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${_nutritionValue(recipe.nutrition, 'calories').toStringAsFixed(0)} kcal · 蛋白质 ${_nutritionValue(recipe.nutrition, 'protein').toStringAsFixed(1)}g',
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                value: mealType,
                isExpanded: true,
                items: List.generate(
                  mealTypes.length,
                  (i) => DropdownMenuItem(
                    value: mealTypes[i],
                    child: Text(mealLabels[i]),
                  ),
                ),
                onChanged: (value) {
                  if (value != null) {
                    setStateDialog(() => mealType = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _logNutritionAndDeductIngredients(mealType, today);
              },
              child: const Text('确认记录'),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _logNutritionAndDeductIngredients(String mealType, String date) async {
    final recipe = widget.recipe;
    try {
      await ApiService.post('/nutrition/', {
        'date': date,
        'meal_type': mealType,
        'recipe_name': recipe.name,
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已记录营养摄入，食材已扣减'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('记录失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      appBar: AppBar(
        title: Text(recipe.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorited ? Icons.favorite : Icons.favorite_border,
              color: _isFavorited ? Colors.red : null,
            ),
            tooltip: _isFavorited ? '取消收藏' : '收藏',
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '记录饮食',
            onPressed: _showLogDialog,
          ),
          IconButton(
            icon: const Icon(Icons.star_outline),
            tooltip: '评价',
            onPressed: _showFeedbackDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('AI 正在生成步骤详情...'),
                ],
              ),
            )
          : _error != null
              ? Center(child: Text('加载失败：$_error'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final useTwoColumns = constraints.maxWidth >= 860;
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 16),
                            const SizedBox(width: 4),
                            Text('${recipe.timeMinutes} 分钟'),
                            const SizedBox(width: 16),
                            const Icon(Icons.local_fire_department_outlined, size: 16),
                            const SizedBox(width: 4),
                            Text('${_nutritionValue(recipe.nutrition, 'calories').toStringAsFixed(0)} kcal'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '食材',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: recipe.ingredients
                              .map((item) => Chip(label: Text(item)))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '烹饪步骤',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        if (!useTwoColumns)
                          Column(
                            children: [
                              for (int i = 0; i < _steps.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
                                _StepCard(index: i, step: _steps[i]),
                              ],
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    for (int i = 0; i < _steps.length; i += 2) ...[
                                      if (i > 0) const SizedBox(height: 12),
                                      _StepCard(index: i, step: _steps[i]),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  children: [
                                    for (int i = 1; i < _steps.length; i += 2) ...[
                                      if (i > 1) const SizedBox(height: 12),
                                      _StepCard(index: i, step: _steps[i]),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('记录这道菜'),
                                onPressed: _showLogDialog,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.star_outline),
                                label: const Text('评价'),
                                onPressed: _showFeedbackDialog,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
    );
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
      panels.add(
        _StepInfoPanel(
          title: '完成标准',
          icon: Icons.check_circle_outline,
          color: Colors.green,
          background: Colors.green.shade50,
          description: step.resultDescription,
          imageUrl: step.resultImageUrl,
        ),
      );
    }
    if (step.processDescription.isNotEmpty) {
      panels.add(
        _StepInfoPanel(
          title: '操作要点',
          icon: Icons.info_outline,
          color: Colors.blue,
          background: Colors.blue.shade50,
          description: step.processDescription,
          imageUrl: step.processImageUrl,
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.step,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (panels.isNotEmpty) ...[
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final splitPanels = panels.length > 1 && constraints.maxWidth >= 520;
                  if (!splitPanels) {
                    return Column(
                      children: [
                        for (int i = 0; i < panels.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          panels[i],
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: panels[0]),
                      const SizedBox(width: 8),
                      Expanded(child: panels[1]),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepInfoPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color background;
  final String description;
  final String? imageUrl;

  const _StepInfoPanel({
    required this.title,
    required this.icon,
    required this.color,
    required this.background,
    required this.description,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(description, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
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
    if (mounted) {
      setState(() => _proxyUrl = '$base/ai/image-proxy?url=$encoded');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_proxyUrl == null) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.white,
        child: Image.network(
          _proxyUrl!,
          width: double.infinity,
          height: widget.height,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => SizedBox(
            height: widget.height,
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}
