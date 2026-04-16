import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
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
          SnackBar(content: Text('推荐失败：$e'), backgroundColor: const Color(0xFFE57373)),
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
                const Text('记录这餐 🍽️',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryLight, width: 1.5),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_selectedDish!.name} + ${_selectedStaple!.name}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    Text('合计 ${_combinedCalories.toStringAsFixed(0)} kcal',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                  ]),
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
                      items: List.generate(4, (i) => DropdownMenuItem(
                        value: mealTypes[i], child: Text(mealLabels[i]))),
                      onChanged: (v) => setS(() => mealType = v!),
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
                      final dish = _selectedDish!;
                      final staple = _selectedStaple!;
                      await ApiService.post('/nutrition/', {
                        'date': today, 'meal_type': mealType,
                        'recipe_name': dish.name,
                        'calories': dish.nutrition['calories'] ?? 0,
                        'protein': dish.nutrition['protein'] ?? 0,
                        'carbs': dish.nutrition['carbs'] ?? 0,
                        'fat': dish.nutrition['fat'] ?? 0,
                        'fiber': dish.nutrition['fiber'] ?? 0,
                      });
                      await ApiService.post('/nutrition/', {
                        'date': today, 'meal_type': mealType,
                        'recipe_name': staple.name,
                        'calories': staple.nutrition['calories'] ?? 0,
                        'protein': staple.nutrition['protein'] ?? 0,
                        'carbs': staple.nutrition['carbs'] ?? 0,
                        'fat': staple.nutrition['fat'] ?? 0,
                        'fiber': staple.nutrition['fiber'] ?? 0,
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已记录'), backgroundColor: AppColors.green),
                        );
                      }
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

  @override
  Widget build(BuildContext context) {
    final hasNewFormat = _dishes.isNotEmpty || _staples.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('菜单推荐 🍽️')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // 设置卡片
                _ClayCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryLight, width: 1.5),
                          ),
                          child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text('今天想怎么吃？',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        const Spacer(),
                        _ClayBadge(
                          label: _agentMode ? 'Agent' : '普通',
                          color: _agentMode ? AppColors.lavender : AppColors.textLight,
                          bgColor: _agentMode ? AppColors.lavenderSoft : AppColors.bg,
                        ),
                      ]),
                      const SizedBox(height: 14),
                      // 场合选择
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _OccasionPill(label: '日常', selected: _occasion == '日常' && !_agentMode,
                            onTap: () => setState(() { _occasion = '日常'; _agentMode = false; })),
                        _OccasionPill(label: '外食', selected: _occasion == '外食' && !_agentMode,
                            onTap: () => setState(() { _occasion = '外食'; _agentMode = false; })),
                        _OccasionPill(
                          label: 'Agent 模式',
                          selected: _agentMode,
                          onTap: () => setState(() { _agentMode = !_agentMode; _agentNotes = ''; _lastToolCalls = []; }),
                          selectedColor: AppColors.lavender,
                          selectedBg: AppColors.lavenderSoft,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      // 人数
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: Row(children: [
                          const Icon(Icons.people_rounded, size: 18, color: AppColors.textMid),
                          const SizedBox(width: 8),
                          const Text('用餐人数', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                          const Spacer(),
                          _CounterBtn(icon: Icons.remove_rounded,
                              onTap: _people > 1 ? () => setState(() => _people--) : null),
                          const SizedBox(width: 12),
                          Text('$_people 人',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                          const SizedBox(width: 12),
                          _CounterBtn(icon: Icons.add_rounded, onTap: () => setState(() => _people++)),
                        ]),
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
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => _recommend(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE06040), width: 2),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 8, offset: const Offset(2, 3))],
                          ),
                          child: const Center(
                            child: Text('生成菜单 ✨',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                // Agent 信息卡
                if (_agentMode && (_agentNotes.isNotEmpty || _lastToolCalls.isNotEmpty)) ...[
                  _AgentInfoCard(notes: _agentNotes, toolCalls: _lastToolCalls),
                  const SizedBox(height: 12),
                ],

                // 空状态
                if (!hasNewFormat && _legacyRecipes.isEmpty)
                  _ClayCard(
                    color: AppColors.yellowSoft,
                    borderColor: const Color(0xFFFFE599),
                    child: const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('还没有生成菜单 🌱\n点上方按钮，让管家帮你排一份今日菜单。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMid, fontSize: 14, height: 1.6)),
                      ),
                    ),
                  )
                else ...[
                  if (hasNewFormat) ...[
                    if (_dishes.isNotEmpty) ...[
                      _SectionHeader(emoji: '🥘', title: '今日菜肴'),
                      const SizedBox(height: 8),
                      ..._dishes.map((r) => _RecipeCard(
                        recipe: r,
                        selected: _selectedDish?.name == r.name,
                        stepsCache: _stepsCache,
                        recommendationMode: _agentMode ? 'agent' : 'hardcoded',
                        onTap: () => setState(() =>
                            _selectedDish = _selectedDish?.name == r.name ? null : r),
                      )),
                    ],
                    if (_staples.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _SectionHeader(emoji: '🍚', title: '搭配主食'),
                      const SizedBox(height: 8),
                      ..._staples.map((r) => _RecipeCard(
                        recipe: r,
                        selected: _selectedStaple?.name == r.name,
                        stepsCache: _stepsCache,
                        recommendationMode: _agentMode ? 'agent' : 'hardcoded',
                        onTap: () => setState(() =>
                            _selectedStaple = _selectedStaple?.name == r.name ? null : r),
                      )),
                    ],
                  ] else ...[
                    _SectionHeader(emoji: '✨', title: '推荐结果'),
                    const SizedBox(height: 8),
                    ..._legacyRecipes.map((r) => _RecipeCard(
                      recipe: r,
                      selected: _selectedLegacy?.name == r.name,
                      stepsCache: _stepsCache,
                      recommendationMode: _agentMode ? 'agent' : 'hardcoded',
                      onTap: () => setState(() =>
                          _selectedLegacy = _selectedLegacy?.name == r.name ? null : r),
                    )),
                  ],

                  // 组合热量卡
                  if (_selectedDish != null && _selectedStaple != null) ...[
                    const SizedBox(height: 4),
                    _ClayCard(
                      color: AppColors.primarySoft,
                      borderColor: AppColors.primaryLight,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.local_fire_department_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            const Text('今日组合热量',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                          ]),
                          const SizedBox(height: 10),
                          Text('${_selectedDish!.name} + ${_selectedStaple!.name}',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                          const SizedBox(height: 4),
                          Text('${_combinedCalories.toStringAsFixed(0)} kcal',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary)),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _confirmAndLog,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(1, 3))],
                              ),
                              child: const Center(child: Text('记录这餐',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white))),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 反馈卡
                  _ClayCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.rate_review_rounded, color: AppColors.textMid, size: 18),
                          const SizedBox(width: 8),
                          const Text('不够满意？再改一版',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        ]),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _feedbackCtrl,
                          decoration: const InputDecoration(
                            hintText: '比如：不要重复、想吃牛肉、主食换成更清淡的',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            final fb = _feedbackCtrl.text;
                            _feedbackCtrl.clear();
                            _recommend(feedback: fb);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border, width: 2),
                            ),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.refresh_rounded, size: 16, color: AppColors.textMid),
                              SizedBox(width: 6),
                              Text('重新推荐', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMid)),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────

class _ClayCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color borderColor;

  const _ClayCard({
    required this.child,
    this.color = AppColors.bgCard,
    this.borderColor = AppColors.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.shadowOuter, blurRadius: 10, offset: const Offset(3, 4)),
          BoxShadow(color: Colors.white.withOpacity(0.8), blurRadius: 4, offset: const Offset(-1, -1)),
        ],
      ),
      child: child,
    );
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
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
    ]);
  }
}

class _ClayBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  const _ClayBadge({required this.label, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _OccasionPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color selectedBg;

  const _OccasionPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = AppColors.primary,
    this.selectedBg = AppColors.primarySoft,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedBg : AppColors.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? selectedColor.withOpacity(0.5) : AppColors.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Text(label, style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: selected ? selectedColor : AppColors.textMid,
        )),
      ),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CounterBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primarySoft : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: enabled ? AppColors.primaryLight : AppColors.border, width: 1.5),
        ),
        child: Icon(icon, size: 16, color: enabled ? AppColors.primary : AppColors.textLight),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool selected;
  final Map<String, List<dynamic>> stepsCache;
  final String recommendationMode;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.selected,
    required this.stepsCache,
    required this.recommendationMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primaryLight : AppColors.border,
              width: selected ? 2.5 : 2,
            ),
            boxShadow: [
              BoxShadow(color: AppColors.shadowOuter, blurRadius: 8, offset: const Offset(2, 3)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryLight, width: 1.5),
              ),
              child: Center(
                child: Text(
                  recipe.name.isNotEmpty ? recipe.name[0] : '🍽',
                  style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(recipe.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.timer_outlined, size: 13, color: AppColors.textLight),
                  const SizedBox(width: 3),
                  Text('${recipe.timeMinutes} 分钟',
                      style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                  const SizedBox(width: 10),
                  const Icon(Icons.local_fire_department_outlined, size: 13, color: AppColors.textLight),
                  const SizedBox(width: 3),
                  Text('${(recipe.nutrition['calories'] ?? 0).toStringAsFixed(0)} kcal',
                      style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                ]),
                if (recipe.ingredients.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(recipe.ingredients.take(3).join('、'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                ],
              ]),
            ),
            Column(children: [
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe, stepsCache: stepsCache))),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: const Text('食谱', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMid)),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => FeedbackDialog.show(context, recipe.name, recommendationMode: recommendationMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.greenLight, width: 1.5),
                  ),
                  child: const Text('评价', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)),
                ),
              ),
            ]),
          ]),
        ),
      ),
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
    return _ClayCard(
      color: AppColors.lavenderSoft,
      borderColor: const Color(0xFFD8C8F0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.psychology_rounded, color: AppColors.lavender, size: 18),
            const SizedBox(width: 8),
            const Text('Agent 灵感记录',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${widget.toolCalls.length} 个工具',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.lavender)),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textMid, size: 20),
            ),
          ]),
          if (widget.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.notes, style: const TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.5)),
          ],
          if (_expanded && widget.toolCalls.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...widget.toolCalls.map((tc) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.arrow_right_rounded, size: 16, color: AppColors.lavender),
                const SizedBox(width: 6),
                Text(_toolNames[tc['tool']] ?? tc['tool'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textDark)),
              ]),
            )),
          ],
        ]),
      ),
    );
  }
}
