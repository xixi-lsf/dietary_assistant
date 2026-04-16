import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import 'recipe_detail_screen.dart';

class BanquetScreen extends StatefulWidget {
  const BanquetScreen({super.key});

  @override
  State<BanquetScreen> createState() => _BanquetScreenState();
}

class _BanquetScreenState extends State<BanquetScreen> {
  int _people = 4;
  String _occasion = '宴请';
  bool _customOccasion = false;
  final _customOccasionCtrl = TextEditingController();
  final _prefsCtrl = TextEditingController();
  final _restrictCtrl = TextEditingController();
  List<Recipe> _recipes = [];
  bool _loading = false;
  final Map<String, List<dynamic>> _stepsCache = {};

  static const _occasions = ['宴请', '年夜饭', '生日', '结婚纪念日', '自定义...'];
  static const _occasionEmojis = {'宴请': '🥂', '年夜饭': '🧧', '生日': '🎂', '结婚纪念日': '💍'};

  Future<void> _generate() async {
    setState(() { _loading = true; _recipes = []; });
    try {
      final apiKey = await ApiConfig.getApiKey();
      final aiBaseUrl = await ApiConfig.getAiBaseUrl();
      final data = await ApiService.post('/recipes/banquet', {
        'people_count': _people,
        'occasion': _customOccasion ? _customOccasionCtrl.text : _occasion,
        'preferences': _prefsCtrl.text,
        'dietary_restrictions': _restrictCtrl.text,
        if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
        if (aiBaseUrl != null && aiBaseUrl.isNotEmpty) 'ai_base_url': aiBaseUrl,
      });
      setState(() {
        _recipes = (data['recipes'] as List)
            .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败：$e'), backgroundColor: const Color(0xFFE57373)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('宴请菜单 🥂')),
      body: Column(children: [
        // 配置区
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.shadowOuter, blurRadius: 10, offset: const Offset(3, 4)),
              BoxShadow(color: Colors.white.withOpacity(0.8), blurRadius: 4, offset: const Offset(-1, -1)),
            ],
          ),
          child: Column(children: [
            // 人数选择
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryLight, width: 1.5),
                ),
                child: const Icon(Icons.people_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('用餐人数', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const Spacer(),
              _CounterButton(
                icon: Icons.remove_rounded,
                onTap: _people > 1 ? () => setState(() => _people--) : null,
              ),
              const SizedBox(width: 12),
              Text('$_people 人',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(width: 12),
              _CounterButton(
                icon: Icons.add_rounded,
                onTap: () => setState(() => _people++),
              ),
            ]),
            const SizedBox(height: 14),
            // 场合选择
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _customOccasion ? '自定义...' : _occasion,
                  isExpanded: true,
                  items: _occasions.map((o) => DropdownMenuItem(
                    value: o,
                    child: Text('${_occasionEmojis[o] ?? '✨'} $o'),
                  )).toList(),
                  onChanged: (v) => setState(() {
                    if (v == '自定义...') {
                      _customOccasion = true;
                    } else {
                      _customOccasion = false;
                      _occasion = v!;
                    }
                  }),
                ),
              ),
            ),
            if (_customOccasion) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customOccasionCtrl,
                decoration: const InputDecoration(labelText: '请输入场合', hintText: '如：同学聚会、公司年会...'),
              ),
            ],
            const SizedBox(height: 10),
            TextField(controller: _prefsCtrl,
                decoration: const InputDecoration(labelText: '口味偏好', hintText: '如：偏辣、家常菜')),
            const SizedBox(height: 10),
            TextField(controller: _restrictCtrl,
                decoration: const InputDecoration(labelText: '忌口', hintText: '如：不吃香菜、素食')),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _loading ? null : _generate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _loading ? AppColors.border : AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _loading ? AppColors.border : const Color(0xFFE06040),
                    width: 2,
                  ),
                  boxShadow: _loading ? [] : [
                    BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 8, offset: const Offset(2, 3)),
                  ],
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('生成菜单 ✨',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ),
          ]),
        ),
        // 菜谱列表
        if (_recipes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Text('推荐菜单',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${_recipes.length} 道',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _recipes.length,
              itemBuilder: (_, i) {
                final r = _recipes[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: r, stepsCache: _stepsCache))),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border, width: 2),
                        boxShadow: [
                          BoxShadow(color: AppColors.shadowOuter, blurRadius: 8, offset: const Offset(2, 3)),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primaryLight, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              r.name.isNotEmpty ? r.name[0] : '🍽',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.timer_outlined, size: 13, color: AppColors.textLight),
                                const SizedBox(width: 3),
                                Text('${r.timeMinutes} 分钟',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                                const SizedBox(width: 10),
                                const Icon(Icons.local_fire_department_outlined, size: 13, color: AppColors.textLight),
                                const SizedBox(width: 3),
                                Text('${(r.nutrition['calories'] ?? 0).toStringAsFixed(0)} kcal',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                              ]),
                              if (r.category != null) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.greenSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(r.category!,
                                      style: const TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLight),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ]),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CounterButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primarySoft : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? AppColors.primaryLight : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Icon(icon, size: 18,
            color: enabled ? AppColors.primary : AppColors.textLight),
      ),
    );
  }
}
