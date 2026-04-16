import 'dart:convert';
import 'package:flutter/material.dart';
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
      setState(() {
        _favorites = list;
        _favsLoading = false;
      });
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
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.secondaryContainer.withOpacity(0.85),
                        theme.colorScheme.primaryContainer.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '把小厨房调成最顺手的样子',
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '这里可以配置个人信息、热量目标和各种 API，让推荐更贴合你。',
                              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.74),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(Icons.settings_suggest, size: 34, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '个人信息',
                  icon: Icons.person_outline,
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
                  icon: Icons.favorite_border,
                  subtitle: '用于估算每日热量目标',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(label: const Text('男'), selected: _gender == 'male', onSelected: (_) => setState(() => _gender = 'male')),
                        ChoiceChip(label: const Text('女'), selected: _gender == 'female', onSelected: (_) => setState(() => _gender = 'female')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _ageCtrl, decoration: const InputDecoration(labelText: '年龄', suffixText: '岁'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _heightCtrl, decoration: const InputDecoration(labelText: '身高', suffixText: 'cm'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _weightCtrl, decoration: const InputDecoration(labelText: '体重', suffixText: 'kg'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _activityLevel,
                      decoration: const InputDecoration(labelText: '活动水平'),
                      items: _activityOptions.map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2))).toList(),
                      onChanged: (v) => setState(() => _activityLevel = v!),
                    ),
                    if (_bmr != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.local_fire_department, color: theme.colorScheme.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '每日热量目标：${_bmr!.toStringAsFixed(0)} kcal',
                              style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.onPrimaryContainer),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'API 配置',
                  icon: Icons.key_outlined,
                  children: [
                    TextField(controller: _baseUrlCtrl, decoration: const InputDecoration(labelText: '后端地址', hintText: 'http://localhost:8000')),
                    const SizedBox(height: 10),
                    TextField(controller: _apiKeyCtrl, decoration: const InputDecoration(labelText: 'AI API Key'), obscureText: true),
                    const SizedBox(height: 10),
                    TextField(controller: _aiBaseUrlCtrl, decoration: const InputDecoration(labelText: 'AI Base URL（代理时填写）', hintText: 'https://codeapi.icu')),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: '图片生成 API',
                  icon: Icons.image_outlined,
                  subtitle: '可选：用于推荐成品图或步骤图',
                  children: [
                    Text(
                      '推荐：Stable Diffusion（Replicate）、DALL-E 3、Flux（fal.ai）',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _imageApiKeyCtrl, decoration: const InputDecoration(labelText: '图片生成 API Key'), obscureText: true),
                    const SizedBox(height: 10),
                    TextField(controller: _imageBaseUrlCtrl, decoration: const InputDecoration(labelText: '图片生成 Base URL')),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: '外部工具 API',
                  icon: Icons.travel_explore_outlined,
                  subtitle: 'Agent 模式可用；不填就跳过',
                  children: [
                    TextField(controller: _weatherApiKeyCtrl, decoration: const InputDecoration(labelText: 'OpenWeatherMap API Key', hintText: '天气查询，免费注册'), obscureText: true),
                    const SizedBox(height: 10),
                    TextField(controller: _serperApiKeyCtrl, decoration: const InputDecoration(labelText: 'Serper API Key', hintText: '网页搜索，免费2500次/月'), obscureText: true),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: _save, child: const Text('保存设置')),
                ),
                const SizedBox(height: 24),
                _SectionCard(
                  title: '收藏菜品',
                  icon: Icons.favorite_outline,
                  trailing: IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loadFavorites),
                  children: [
                    if (_favsLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                    else if (_favorites.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Text('还没有收藏的菜品'),
                      )
                    else
                      ..._favorites.map((fav) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.favorite, color: theme.colorScheme.primary),
                              ),
                              title: Text(fav['recipe_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteFavorite(fav['id']),
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
                          )),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle!,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
