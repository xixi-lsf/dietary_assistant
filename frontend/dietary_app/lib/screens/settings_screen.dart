import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import 'recipe_detail_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _dislikesCtrl = TextEditingController();
  final _prefsCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  final _cycleDaysCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _aiBaseUrlCtrl = TextEditingController();
  final _imageApiKeyCtrl = TextEditingController();
  final _imageBaseUrlCtrl = TextEditingController();
  final _weatherApiKeyCtrl = TextEditingController();
  final _serperApiKeyCtrl = TextEditingController();
  String _gender = 'male';
  String _activityLevel = 'moderate';
  bool _loading = true;

  double? get _bmr {
    final age = int.tryParse(_ageCtrl.text);
    final height = double.tryParse(_heightCtrl.text);
    final weight = double.tryParse(_weightCtrl.text);
    if (age == null || age == 0 || height == null || height == 0 || weight == null || weight == 0) return null;
    double bmr = _gender == 'female'
        ? 10 * weight + 6.25 * height - 5 * age - 161
        : 10 * weight + 6.25 * height - 5 * age + 5;
    const multipliers = {'sedentary': 1.2, 'light': 1.375, 'moderate': 1.55, 'active': 1.725};
    return bmr * (multipliers[_activityLevel] ?? 1.55);
  }

  List<dynamic> _favorites = [];
  bool _favsLoading = false;

  static const _activityOptions = [
    ('sedentary', '久坐（几乎不运动）'),
    ('light', '轻度活动（每周1-3次）'),
    ('moderate', '中度活动（每周3-5次）'),
    ('active', '高度活动（每天运动）'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _loadFavorites();
    _ageCtrl.addListener(() => setState(() {}));
    _heightCtrl.addListener(() => setState(() {}));
    _weightCtrl.addListener(() => setState(() {}));
  }

  Future<void> _load() async {
    try {
      final profile = await ApiService.get('/user/profile');
      final apiKey = await ApiConfig.getApiKey();
      final baseUrl = await ApiConfig.getBaseUrl();
      final aiBaseUrl = await ApiConfig.getAiBaseUrl();
      final imageApiKey = await ApiConfig.getImageApiKey();
      final imageBaseUrl = await ApiConfig.getImageBaseUrl();
      final weatherApiKey = await ApiConfig.getWeatherApiKey();
      final serperApiKey = await ApiConfig.getSerperApiKey();
      setState(() {
        _nameCtrl.text = profile['name'] ?? '';
        _dislikesCtrl.text = profile['dislikes'] ?? '';
        _prefsCtrl.text = profile['preferences'] ?? '';
        _goalCtrl.text = profile['goal'] ?? '';
        _cycleDaysCtrl.text = (profile['cycle_days'] ?? 7).toString();
        _ageCtrl.text = (profile['age'] ?? 0) == 0 ? '' : profile['age'].toString();
        _heightCtrl.text = (profile['height_cm'] ?? 0) == 0 ? '' : profile['height_cm'].toString();
        _weightCtrl.text = (profile['weight_kg'] ?? 0) == 0 ? '' : profile['weight_kg'].toString();
        _gender = profile['gender'] ?? 'male';
        _activityLevel = profile['activity_level'] ?? 'moderate';
        _apiKeyCtrl.text = apiKey ?? '';
        _baseUrlCtrl.text = baseUrl;
        _aiBaseUrlCtrl.text = aiBaseUrl ?? '';
        _imageApiKeyCtrl.text = imageApiKey ?? '';
        _imageBaseUrlCtrl.text = imageBaseUrl ?? '';
        _weatherApiKeyCtrl.text = weatherApiKey ?? '';
        _serperApiKeyCtrl.text = serperApiKey ?? '';
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadFavorites() async {
    setState(() => _favsLoading = true);
    try {
      final list = await ApiService.getList('/favorites/');
      setState(() { _favorites = list; _favsLoading = false; });
    } catch (_) {
      setState(() => _favsLoading = false);
    }
  }

  Future<void> _deleteFavorite(int id) async {
    await ApiService.delete('/favorites/$id');
    _loadFavorites();
  }

  Future<void> _save() async {
    await ApiService.put('/user/profile', {
      'name': _nameCtrl.text,
      'dislikes': _dislikesCtrl.text,
      'preferences': _prefsCtrl.text,
      'goal': _goalCtrl.text,
      'cycle_days': int.tryParse(_cycleDaysCtrl.text) ?? 7,
      'age': int.tryParse(_ageCtrl.text) ?? 0,
      'gender': _gender,
      'height_cm': double.tryParse(_heightCtrl.text) ?? 0,
      'weight_kg': double.tryParse(_weightCtrl.text) ?? 0,
      'activity_level': _activityLevel,
    });
    await ApiConfig.setApiKey(_apiKeyCtrl.text);
    await ApiConfig.setBaseUrl(_baseUrlCtrl.text);
    await ApiConfig.setAiBaseUrl(_aiBaseUrlCtrl.text);
    await ApiConfig.setImageApiKey(_imageApiKeyCtrl.text);
    await ApiConfig.setImageBaseUrl(_imageBaseUrlCtrl.text);
    await ApiConfig.setWeatherApiKey(_weatherApiKeyCtrl.text);
    await ApiConfig.setSerperApiKey(_serperApiKeyCtrl.text);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ 已保存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('设置 ⚙️')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // 顶部横幅
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primarySoft, AppColors.greenSoft],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primaryLight, width: 2),
                    boxShadow: [BoxShadow(color: AppColors.shadowOuter, blurRadius: 10, offset: const Offset(3, 4))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('把小厨房调成最顺手的样子',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                            SizedBox(height: 6),
                            Text('配置个人信息、热量目标和各种 API，让推荐更贴合你 🌿',
                                style: TextStyle(fontSize: 13, color: AppColors.textMid, height: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.primaryLight, width: 1.5),
                        ),
                        child: const Icon(Icons.settings_suggest_rounded, size: 30, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '个人信息',
                  emoji: '👤',
                  accentColor: AppColors.primary,
                  children: [
                    TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '姓名')),
                    const SizedBox(height: 10),
                    TextField(controller: _dislikesCtrl, decoration: const InputDecoration(labelText: '不喜欢的食物')),
                    const SizedBox(height: 10),
                    TextField(controller: _prefsCtrl, decoration: const InputDecoration(labelText: '饮食偏好')),
                    const SizedBox(height: 10),
                    TextField(controller: _goalCtrl, decoration: const InputDecoration(labelText: '健康目标')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cycleDaysCtrl,
                      decoration: const InputDecoration(labelText: '饮食观察周期（天）', hintText: '默认7天'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: '身体数据',
                  emoji: '💪',
                  subtitle: '用于估算每日热量目标',
                  accentColor: AppColors.green,
                  children: [
                    Row(children: [
                      _GenderChip(label: '男', selected: _gender == 'male', onTap: () => setState(() => _gender = 'male')),
                      const SizedBox(width: 10),
                      _GenderChip(label: '女', selected: _gender == 'female', onTap: () => setState(() => _gender = 'female')),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: TextField(controller: _ageCtrl,
                   decoration: const InputDecoration(labelText: '年龄', suffixText: '岁'),
                          keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: _heightCtrl,
                          decoration: const InputDecoration(labelText: '身高', suffixText: 'cm'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: _weightCtrl,
                          decoration: const InputDecoration(labelText: '体重', suffixText: 'kg'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                    ]),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, width: 2),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _activityLevel,
                          isExpanded: true,
                          items: _activityOptions.map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2))).toList(),
                          onChanged: (v) => setState(() => _activityLevel = v!),
                        ),
                      ),
                    ),
                    if (_bmr != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryLight, width: 1.5),
                        ),
                        child: Row(children: [
                          const Icon(Icons.local_fire_department_rounded, color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text('每日热量目标：${_bmr!.toStringAsFixed(0)} kcal',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        ]),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'API 配置',
                  emoji: '🔑',
                  accentColor: AppColors.lavender,
                  children: [
                    TextField(controller: _baseUrlCtrl,
                        decoration: const InputDecoration(labelText: '后端地址', hintText: 'http://localhost:8000')),
                    const SizedBox(height: 10),
                    TextField(controller: _apiKeyCtrl,
                        decoration: const InputDecoration(labelText: 'AI API Key'), obscureText: true),
                    const SizedBox(height: 10),
                    TextField(controller: _aiBaseUrlCtrl,
                        decoration: const InputDecoration(labelText: 'AI Base URL（代理时填写）', hintText: 'https://codeapi.icu')),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: '图片生成 API',
                  emoji: '🎨',
                  subtitle: '可选：用于推荐成品图或步骤图',
                  accentColor: AppColors.blue,
                  children: [
                    const Text('推荐：通义万象 wanx2.1-t2i-turbo（约0.04元/张）',
                        style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                    const SizedBox(height: 10),
                    TextField(controller: _imageApiKeyCtrl,
                        decoration: const InputDecoration(labelText: '图片生成 API Key'), obscureText: true),
                    const SizedBox(height: 10),
                    TextField(controller: _imageBaseUrlCtrl,
                        decoration: const InputDecoration(labelText: '图片生成 Base URL')),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: '外部工具 API',
                  emoji: '🌐',
                  subtitle: 'Agent 模式可用；不填就跳过',
                  accentColor: AppColors.yellow,
                  children: [
                    TextField(controller: _weatherApiKeyCtrl,
                        decoration: const InputDecoration(labelText: 'OpenWeatherMap API Key', hintText: '天气查询，免费注册'),
                        obscureText: true),
                    const SizedBox(height: 10),
                    TextField(controller: _serperApiKeyCtrl,
                        decoration: const InputDecoration(labelText: 'Serper API Key', hintText: '网页搜索，免费2500次/月'),
                        obscureText: true),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _save,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE06040), width: 2),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(2, 4))],
                    ),
                    child: const Center(
                      child: Text('保存设置',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: '收藏菜品',
                  emoji: '❤️',
                  accentColor: const Color(0xFFE57373),
                  trailing: GestureDetector(
                    onTap: _loadFavorites,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                    ),
                  ),
                  children: [
                    if (_favsLoading)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ))
                    else if (_favorites.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: const Text('还没有收藏的菜品 🍽️',
                            style: TextStyle(color: AppColors.textLight), textAlign: TextAlign.center),
                      )
                    else
                      ..._favorites.map((fav) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border, width: 1.5),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.favorite_rounded, color: Color(0xFFE57373), size: 20),
                            ),
                            title: Text(fav['recipe_name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
                            trailing: GestureDetector(
                              onTap: () => _deleteFavorite(fav['id']),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEB),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE57373), size: 16),
                              ),
                            ),
                            onTap: () {
                              final dataStr = fav['recipe_data'] ?? '';
                              if (dataStr.isNotEmpty) {
                                try {
                                  final recipeJson = jsonDecode(dataStr);
                                  final recipe = Recipe.fromJson(recipeJson);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)));
                                } catch (_) {}
                              }
                            },
                          ),
                        ),
                      )),
                  ],
                ),
              ],
            ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryLight : AppColors.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : AppColors.textLight,
            )),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String emoji;
  final String? subtitle;
  final Widget? trailing;
  final Color accentColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.emoji,
    this.subtitle,
    this.trailing,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.shadowOuter, blurRadius: 10, offset: const Offset(3, 4)),
          BoxShadow(color: Colors.white.withOpacity(0.8), blurRadius: 4, offset: const Offset(-1, -1)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
