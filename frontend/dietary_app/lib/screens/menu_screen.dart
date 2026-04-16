import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import '../widgets/feedback_dialog.dart';
import 'recipe_detail_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _prefCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  String _occasion = '日常';
  static final Map<String, List<dynamic>> _stepsCache = {};
  int _people = 2;
  bool _agentMode = false;
  String _agentNotes = '';
  List<Map<String, dynamic>> _lastToolCalls = [];

  List<Recipe> _dishes = [];
  List<Recipe> _staples = [];
  List<Recipe> _legacyRecipes = [];
  bool _loading = false;

  Recipe? _selectedDish;
  Recipe? _selectedStaple;
  Recipe? _selectedLegacy;

  static const _cacheKey = 'menu_cache';
  static const _cacheTsKey = 'menu_cache_ts';

  double get _combinedCalories =>
      ((_selectedDish?.nutrition['calories'] ?? 0) as num).toDouble() +
      ((_selectedStaple?.nutrition['calories'] ?? 0) as num).toDouble();

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_cacheTsKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - ts < 24 * 60 * 60 * 1000) {
        final raw = prefs.getString(_cacheKey);
        if (raw != null) {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          setState(() {
            if (data['dishes'] != null) {
              _dishes = (data['dishes'] as List)
                  .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
              _staples = (data['staples'] as List? ?? [])
                  .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
            } else if (data['recipes'] != null) {
              _legacyRecipes = (data['recipes'] as List)
                  .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
      await prefs.setInt(_cacheTsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _recommend({String feedback = ''}) async {
    setState(() {
      _loading = true;
      _dishes = [];
      _staples = [];
      _legacyRecipes = [];
      _selectedDish = null;
      _selectedStaple = null;
      _selectedLegacy = null;
      _agentNotes = '';
      _lastToolCalls = [];
    });
    try {
      final apiKey = await ApiConfig.getApiKey();
      final aiBaseUrl = await ApiConfig.getAiBaseUrl();
      final imageApiKey = await ApiConfig.getImageApiKey();
      final imageBaseUrl = await ApiConfig.getImageBaseUrl();

      Map<String, dynamic> data;

      if (_agentMode && apiKey != null && apiKey.isNotEmpty) {
        data = await ApiService.post('/agent/recommend', {
          'occasion': _occasion,
          'people_count': _people,
          'preferences': _prefCtrl.text,
          'api_key': apiKey,
          if (aiBaseUrl != null && aiBaseUrl.isNotEmpty) 'ai_base_url': aiBaseUrl,
          if (imageApiKey != null && imageApiKey.isNotEmpty) 'image_api_key': imageApiKey,
          if (imageBaseUrl != null && imageBaseUrl.isNotEmpty) 'image_base_url': imageBaseUrl,
          if ((await ApiConfig.getWeatherApiKey())?.isNotEmpty == true)
            'weather_api_key': await ApiConfig.getWeatherApiKey(),
          if ((await ApiConfig.getSerperApiKey())?.isNotEmpty == true)
            'serper_api_key': await ApiConfig.getSerperApiKey(),
        });
        setState(() {
          _agentNotes = data['agent_notes'] as String? ?? '';
          _lastToolCalls = (data['tool_calls'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      } else {
        String nutritionAdvice = '';
        if (apiKey != null && apiKey.isNotEmpty) {
          try {
            final today = DateTime.now().toIso8601String().substring(0, 10);
            final profile = await ApiService.get('/user/profile');
            final adviceData = await ApiService.post('/ai/diet-advice', {
              'date': today,
              'cycle_days': profile['cycle_days'] ?? 7,
              'api_key': apiKey,
              if (aiBaseUrl != null && aiBaseUrl.isNotEmpty) 'ai_base_url': aiBaseUrl,
            });
            nutritionAdvice = adviceData['advice'] ?? '';
          } catch (_) {}
        }
        data = await ApiService.post('/recipes/recommend', {
          'occasion': _occasion,
          'people_count': _people,
          'preferences': _prefCtrl.text,
          'use_fridge': true,
          if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
          if (aiBaseUrl != null && aiBaseUrl.isNotEmpty) 'ai_base_url': aiBaseUrl,
          if (imageApiKey != null && imageApiKey.isNotEmpty) 'image_api_key': imageApiKey,
          if (imageBaseUrl != null && imageBaseUrl.isNotEmpty) 'image_base_url': imageBaseUrl,
          'model': (apiKey != null && apiKey.isNotEmpty) ? 'claude' : 'mock',
          'feedback': feedback,
          'nutrition_advice': nutritionAdvice,
        });
      }

      await _saveCache(data);

      setState(() {
        if (data['dishes'] != null) {
          _dishes = (data['dishes'] as List)
              .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _staples = (data['staples'] as List? ?? [])
              .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else if (data['recipes'] != null) {
          _legacyRecipes = (data['recipes'] as List)
              .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else {
          throw Exception(data['detail'] ?? '返回数据异常');
        }
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('推荐失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmAndLog() async {
    if (_selectedDish == null || _selectedStaple == null) return;
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    final mealLabels = ['早餐', '午餐', '晚餐', '零食'];
    String mealType = 'lunch';
    final today = DateTime.now().toIso8601String().substring(0, 10);

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('记录这餐'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_selectedDish!.name} + ${_selectedStaple!.name}'),
              Text(
                '合计 ${_combinedCalories.toStringAsFixed(0)} kcal',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: mealType,
                decoration: const InputDecoration(labelText: '餐次', isDense: true),
                items: List.generate(
                  4,
                  (i) => DropdownMenuItem(value: mealTypes[i], child: Text(mealLabels[i])),
                ),
                onChanged: (v) => setS(() => mealType = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final dish = _selectedDish!;
                final staple = _selectedStaple!;
                await ApiService.post('/nutrition/', {
                  'date': today,
                  'meal_type': mealType,
                  'recipe_name': dish.name,
                  'calories': dish.nutrition['calories'] ?? 0,
                  'protein': dish.nutrition['protein'] ?? 0,
                  'carbs': dish.nutrition['carbs'] ?? 0,
                  'fat': dish.nutrition['fat'] ?? 0,
                  'fiber': dish.nutrition['fiber'] ?? 0,
                });
                await ApiService.post('/nutrition/', {
                  'date': today,
                  'meal_type': mealType,
                  'recipe_name': staple.name,
                  'calories': staple.nutrition['calories'] ?? 0,
                  'protein': staple.nutrition['protein'] ?? 0,
                  'carbs': staple.nutrition['carbs'] ?? 0,
                  'fat': staple.nutrition['fat'] ?? 0,
                  'fiber': staple.nutrition['fiber'] ?? 0,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已记录'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('确认记录'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitFeedback() async {}

  Widget _recipeCard(Recipe r, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withOpacity(0.72)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withOpacity(0.25)
                : theme.colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _RecipePreviewImage(recipe: r, width: double.infinity, height: 154),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _PlainBadge(
                      text: '${(r.nutrition['calories'] ?? 0).toStringAsFixed(0)} kcal',
                      icon: Icons.local_fire_department_outlined,
                      backgroundColor: Colors.white.withOpacity(0.82),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.84),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        selected ? Icons.check_circle : Icons.add_circle_outline,
                        color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                r.name,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(label: '${r.timeMinutes} 分钟', icon: Icons.schedule_outlined),
                  _InfoChip(
                    label: '${(r.nutrition['protein'] ?? 0).toStringAsFixed(1)}g 蛋白',
                    icon: Icons.spa_outlined,
                  ),
                ],
              ),
              if (r.ingredients.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  r.ingredients.take(4).join('、'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecipeDetailScreen(recipe: r, stepsCache: _stepsCache),
                        ),
                      ),
                      child: const Text('看食谱'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => FeedbackDialog.show(
                        context,
                        r.name,
                        recommendationMode: _agentMode ? 'agent' : 'hardcoded',
                      ),
                      child: const Text('评价'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNewFormat = _dishes.isNotEmpty || _staples.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('菜单推荐'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '菜单设置',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _PlainBadge(
                              text: _agentMode ? 'Agent 模式' : '普通模式',
                              icon: _agentMode ? Icons.auto_awesome : Icons.tune,
                            ),
                            const SizedBox(width: 8),
                            _PlainBadge(
                              text: '$_people 人',
                              icon: Icons.groups_2_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '按场景和口味生成今日菜单。',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _PlainSectionCard(
                  title: '今天想怎么吃？',
                  subtitle: '先选场景，再加一点偏好，管家会重新排出更像菜单页的组合。',
                  icon: Icons.tune,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ChoicePill(
                          label: '日常',
                          selected: _occasion == '日常',
                          onTap: () => setState(() => _occasion = '日常'),
                        ),
                        _ChoicePill(
                          label: '外食',
                          selected: _occasion == '外食',
                          onTap: () => setState(() => _occasion = '外食'),
                        ),
                        _ChoicePill(
                          label: _agentMode ? 'Agent 模式' : '普通模式',
                          selected: _agentMode,
                          onTap: () => setState(() {
                            _agentMode = !_agentMode;
                            _agentNotes = '';
                            _lastToolCalls = [];
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withOpacity(0.46),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.groups_2_outlined, size: 18),
                          const SizedBox(width: 8),
                          const Text('用餐人数', style: TextStyle(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          _CountButton(
                            icon: Icons.remove,
                            onTap: () => setState(() {
                              if (_people > 1) _people--;
                            }),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('$_people', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          ),
                          _CountButton(
                            icon: Icons.add,
                            onTap: () => setState(() => _people++),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _prefCtrl,
                      decoration: const InputDecoration(
                        labelText: '口味便签',
                        hintText: '如：想吃牛肉、清淡一点、早餐 300 kcal 左右',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _recommend(),
                        child: const Text('生成菜单'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_agentMode && (_agentNotes.isNotEmpty || _lastToolCalls.isNotEmpty)) ...[
                  _AgentInfoCard(notes: _agentNotes, toolCalls: _lastToolCalls),
                  const SizedBox(height: 12),
                ],
                if (!hasNewFormat && _legacyRecipes.isEmpty)
                  const _PlainEmptyCard(
                    icon: Icons.restaurant_menu_outlined,
                    title: '还没有生成菜单',
                    subtitle: '点一下上方按钮，让管家帮你排一份今日菜单。',
                  )
                else ...[
                  if (hasNewFormat) ...[
                    if (_dishes.isNotEmpty)
                      _MenuSection(
                        title: '今日菜肴',
                        subtitle: '选一份最想吃的主菜，卡片里可以直接看图和详情',
                        icon: Icons.lunch_dining_outlined,
                        children: _dishes
                            .map(
                              (r) => _recipeCard(
                                r,
                                _selectedDish?.name == r.name,
                                () => setState(() => _selectedDish = _selectedDish?.name == r.name ? null : r),
                              ),
                            )
                            .toList(),
                      ),
                    if (_staples.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _MenuSection(
                        title: '搭配主食',
                        subtitle: '再挑一个主食，组合热量会自动算好',
                        icon: Icons.rice_bowl_outlined,
                        children: _staples
                            .map(
                              (r) => _recipeCard(
                                r,
                                _selectedStaple?.name == r.name,
                                () => setState(() => _selectedStaple = _selectedStaple?.name == r.name ? null : r),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ] else
                    _MenuSection(
                      title: '推荐结果',
                      subtitle: '当前接口返回的是单列菜单，也保持成更轻松的卡片样式',
                      icon: Icons.auto_awesome_outlined,
                      children: _legacyRecipes
                          .map(
                            (r) => _LegacyRecipeCard(
                              recipe: r,
                              selected: _selectedLegacy?.name == r.name,
                              onTap: () => setState(() => _selectedLegacy = _selectedLegacy?.name == r.name ? null : r),
                              onOpen: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RecipeDetailScreen(recipe: r, stepsCache: _stepsCache),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  if (_selectedDish != null && _selectedStaple != null) ...[
                    const SizedBox(height: 12),
                    _PlainSectionCard(
                      title: '今日组合热量',
                      subtitle: '主菜 + 主食已经帮你配好，可以直接记入餐次',
                      icon: Icons.local_fire_department_outlined,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer.withOpacity(0.58),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_selectedDish!.name} + ${_selectedStaple!.name}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_combinedCalories.toStringAsFixed(0)} kcal',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _confirmAndLog,
                                  child: const Text('记录这餐'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  _PlainSectionCard(
                    title: '不够满意？再改一版',
                    subtitle: '告诉我想换什么，马上重新排更贴近你口味的版本。',
                    icon: Icons.rate_review_outlined,
                    children: [
                      TextField(
                        controller: _feedbackCtrl,
                        decoration: const InputDecoration(
                          hintText: '比如：不要重复、想吃牛肉、主食换成更清淡的',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('重新推荐'),
                          onPressed: () {
                            final fb = _feedbackCtrl.text;
                            _feedbackCtrl.clear();
                            _recommend(feedback: fb);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _MenuSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return _PlainSectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      children: children,
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : Colors.white.withOpacity(0.84),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? theme.colorScheme.primary.withOpacity(0.25) : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CountButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.82),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.48),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _LegacyRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  const _LegacyRecipeCard({
    required this.recipe,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer.withOpacity(0.72) : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            _RecipePreviewImage(recipe: recipe, width: 88, height: 88),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(
                    '${recipe.timeMinutes} 分钟 · ${(recipe.nutrition['calories'] ?? 0).toStringAsFixed(0)} kcal',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: onOpen, child: const Text('查看详情')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipePreviewImage extends StatefulWidget {
  final Recipe recipe;
  final double width;
  final double height;

  const _RecipePreviewImage({
    required this.recipe,
    this.width = 84,
    this.height = 84,
  });

  @override
  State<_RecipePreviewImage> createState() => _RecipePreviewImageState();
}

class _RecipePreviewImageState extends State<_RecipePreviewImage> {
  String? _proxyUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final imageUrl = widget.recipe.previewImageUrl;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await _setProxyUrl(imageUrl);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setProxyUrl(String originalUrl) async {
    final base = await ApiConfig.getBaseUrl();
    final encoded = Uri.encodeComponent(originalUrl);
    if (mounted) {
      setState(() => _proxyUrl = '$base/ai/image-proxy?url=$encoded');
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(22);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: _proxyUrl != null
            ? Image.network(
                _proxyUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(context),
              )
            : _loading
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.restaurant,
          size: 22,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
        ),
        const SizedBox(height: 4),
        Text(
          '成品图',
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AgentInfoCard extends StatefulWidget {
  final String notes;
  final List<Map<String, dynamic>> toolCalls;
  const _AgentInfoCard({required this.notes, required this.toolCalls});

  @override
  State<_AgentInfoCard> createState() => _AgentInfoCardState();
}

class _AgentInfoCardState extends State<_AgentInfoCard> {
  bool _expanded = false;

  static const _toolNames = {
    'get_fridge_contents': '查冰箱',
    'get_nutrition_history': '查营养历史',
    'get_user_memory': '读取记忆',
    'update_user_preference': '更新偏好',
    'log_meal': '记录餐食',
    'calculate_nutrition': '估算营养',
    'explain_recommendation': '解释推荐',
    'detect_conflict': '检测冲突',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PlainSectionCard(
      title: 'Agent 灵感记录',
      subtitle: '这一轮推荐里，管家参考了额外工具和上下文。',
      icon: Icons.psychology_outlined,
      children: [
        Row(
          children: [
            _PlainBadge(
              text: '调用了 ${widget.toolCalls.length} 个工具',
              icon: Icons.build_outlined,
            ),
            const Spacer(),
            IconButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            ),
          ],
        ),
        if (widget.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(widget.notes, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
        if (_expanded && widget.toolCalls.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...widget.toolCalls.map(
            (tc) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.82),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.arrow_right, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _toolNames[tc['tool']] ?? tc['tool'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}


class _PlainSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  const _PlainSectionCard({
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PlainBadge extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? backgroundColor;

  const _PlainBadge({required this.text, required this.icon, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PlainEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlainEmptyCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
