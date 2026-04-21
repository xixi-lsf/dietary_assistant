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
  final _aiModelCtrl = TextEditingController();
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
      final aiModel = await ApiConfig.getAiModel();
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
        _aiModelCtrl.text = aiModel ?? '';
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
    await ApiConfig.setAiModel(_aiModelCtrl.text);

    // 把口味偏好/忌口初始化为口味权重（只初始化尚未有记录的标签）
    final apiKey = _apiKeyCtrl.text.trim();
    if (apiKey.isNotEmpty && (_prefsCtrl.text.isNotEmpty || _dislikesCtrl.text.isNotEmpty)) {
      try {
        await ApiService.post('/ai/init-memory-from-profile', {
          'preferences': _prefsCtrl.text,
          'dislikes': _dislikesCtrl.text,
          'api_key': apiKey,
          'ai_base_url': _aiBaseUrlCtrl.text.trim(),
          'ai_model': _aiModelCtrl.text.trim(),
        });
      } catch (_) {}
    }

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已保存 🌱', style: TextStyle(color: SketchColors.textMain)),
        backgroundColor: SketchColors.bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: SketchColors.lineBrown, width: 2),
        ),
      ),
    );
  }

  // ── 手绘风输入框 ──
  Widget _sketchField(TextEditingController ctrl, String label, {
    String? hint, bool obscure = false, String? suffix,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 5),
            child: Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: SketchColors.lineBrown.withOpacity(0.7),
            )),
          ),
          CustomPaint(
            foregroundPainter: DashedBorderPainter(
              color: SketchColors.lineBrown.withOpacity(0.45),
              strokeWidth: 2,
              dashWidth: 6,
              dashSpace: 4,
              borderRadius: BorderRadius.circular(12),
              wobble: 0.6,
            ),
            child: TextField(
              controller: ctrl,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 14, color: SketchColors.textMain),
              decoration: InputDecoration(
                hintText: hint,
                suffixText: suffix,
                hintStyle: TextStyle(color: SketchColors.lineBrown.withOpacity(0.35), fontSize: 13),
                suffixStyle: TextStyle(color: SketchColors.lineBrown.withOpacity(0.5), fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 手绘风性别 chip ──
  Widget _sketchGenderChip(String label, String value) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F9F0) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.elliptical(selected ? 18 : 12, 10),
            topRight: Radius.elliptical(10, selected ? 18 : 12),
            bottomRight: Radius.elliptical(selected ? 16 : 12, 10),
            bottomLeft: Radius.elliptical(10, selected ? 16 : 12),
          ),
          border: Border.all(
            color: selected ? const Color(0xFF2E7D32) : SketchColors.lineBrown.withOpacity(0.35),
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: selected
              ? [const BoxShadow(color: Color(0x152E7D32), offset: Offset(3, 3), blurRadius: 0)]
              : [BoxShadow(color: SketchColors.lineBrown.withOpacity(0.06), offset: const Offset(2, 2), blurRadius: 0)],
        ),
        child: Text(label, style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 14,
          color: selected ? const Color(0xFF2E7D32) : SketchColors.lineBrown.withOpacity(0.6),
        )),
      ),
    );
  }

  // ── 主 build ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SketchColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('设置 ⚙️'),
      ),
      body: Container(
        color: SketchColors.bg,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: PaperDotsPainter())),
            _loading
                ? const Center(child: CircularProgressIndicator(color: SketchColors.lineBrown))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 860;
                      final pad = isWide ? 32.0 : 16.0;
                      return ListView(
                        padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
                        children: [
                          _buildBanner(),
                          const SizedBox(height: 18),
                          if (isWide)
                            _buildWideLayout()
                          else
                            _buildNarrowLayout(),
                          const SizedBox(height: 18),
                          _buildSaveButton(),
                          const SizedBox(height: 20),
                          _buildFavoritesSection(),
                        ],
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  // ── 顶部横幅 ──
  Widget _buildBanner() {
    return HandDrawnCard(
      color: const Color(0xFFF0F9F0),
      rotation: -0.3,
      hoverRotation: 0.2,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('把小厨房调成最顺手的样子',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: SketchColors.textMain)),
            const SizedBox(height: 6),
            Text('配置个人信息、热量目标和各种 API，让推荐更贴合你 🌿',
                style: TextStyle(fontSize: 13, color: SketchColors.lineBrown.withOpacity(0.7), height: 1.5)),
          ]),
        ),
        const SizedBox(width: 12),
        CustomPaint(
          foregroundPainter: DashedBorderPainter(
            color: SketchColors.lineBrown.withOpacity(0.5),
            strokeWidth: 2,
            dashWidth: 5,
            dashSpace: 4,
            borderRadius: BorderRadius.circular(16),
            wobble: 0.8,
          ),
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('🛠️', style: TextStyle(fontSize: 28))),
          ),
        ),
      ]),
    );
  }

  // ── 宽屏两栏 ──
  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左栏：个人信息 + 身体数据
        Expanded(child: Column(children: [
          _buildPersonalSection(),
          const SizedBox(height: 16),
          _buildBodySection(),
        ])),
        const SizedBox(width: 24),
        // 右栏：API 配置
        Expanded(child: Column(children: [
          _buildApiSection(),
          const SizedBox(height: 16),
          _buildImageApiSection(),
          const SizedBox(height: 16),
          _buildToolApiSection(),
        ])),
      ],
    );
  }

  // ── 窄屏单栏 ──
  Widget _buildNarrowLayout() {
    return Column(children: [
      _buildPersonalSection(),
      const SizedBox(height: 16),
      _buildBodySection(),
      const SizedBox(height: 16),
      _buildApiSection(),
      const SizedBox(height: 16),
      _buildImageApiSection(),
      const SizedBox(height: 16),
      _buildToolApiSection(),
    ]);
  }

  // ── 个人信息 ──
  Widget _buildPersonalSection() {
    return _SketchSection(
      title: '个人信息',
      emoji: '👤',
      rotation: -0.5,
      children: [
        _sketchField(_nameCtrl, '姓名'),
        _sketchField(_dislikesCtrl, '不喜欢的食物'),
        _sketchField(_prefsCtrl, '饮食偏好'),
        _sketchField(_goalCtrl, '健康目标'),
        _sketchField(_cycleDaysCtrl, '饮食观察周期', hint: '默认7天', suffix: '天',
            keyboardType: TextInputType.number),
      ],
    );
  }

  // ── 身体数据 ──
  Widget _buildBodySection() {
    return _SketchSection(
      title: '身体数据',
      emoji: '💪',
      subtitle: '用于估算每日热量目标',
      rotation: 0.4,
      children: [
        Row(children: [
          _sketchGenderChip('男', 'male'),
          const SizedBox(width: 10),
          _sketchGenderChip('女', 'female'),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _sketchField(_ageCtrl, '年龄', suffix: '岁', keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _sketchField(_heightCtrl, '身高', suffix: 'cm',
              keyboardType: const TextInputType.numberWithOptions(decimal: true))),
          const SizedBox(width: 10),
          Expanded(child: _sketchField(_weightCtrl, '体重', suffix: 'kg',
              keyboardType: const TextInputType.numberWithOptions(decimal: true))),
        ]),
        // 活动等级下拉
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 5),
                child: Text('活动等级', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: SketchColors.lineBrown.withOpacity(0.7),
                )),
              ),
              CustomPaint(
                foregroundPainter: DashedBorderPainter(
                  color: SketchColors.lineBrown.withOpacity(0.45),
                  strokeWidth: 2,
                  dashWidth: 6,
                  dashSpace: 4,
                  borderRadius: BorderRadius.circular(12),
                  wobble: 0.6,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _activityLevel,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 14, color: SketchColors.textMain),
                      icon: Icon(Icons.expand_more_rounded, color: SketchColors.lineBrown.withOpacity(0.5)),
                      items: _activityOptions.map((o) => DropdownMenuItem(
                        value: o.$1,
                        child: Text(o.$2),
                      )).toList(),
                      onChanged: (v) => setState(() => _activityLevel = v!),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 热量目标
        if (_bmr != null)
          HandDrawnCard(
            color: const Color(0xFFF0F9F0),
            rotation: 0,
            hoverRotation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('每日热量目标：${_bmr!.toStringAsFixed(0)} kcal',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: SketchColors.textMain)),
            ]),
          ),
      ],
    );
  }

  // ── API 配置 ──
  Widget _buildApiSection() {
    return _SketchSection(
      title: 'API 配置',
      emoji: '🔑',
      rotation: -0.3,
      children: [
        _sketchField(_baseUrlCtrl, '后端地址', hint: 'http://localhost:8000'),
        _sketchField(_apiKeyCtrl, 'AI API Key', obscure: true),
        _sketchField(_aiBaseUrlCtrl, 'AI Base URL', hint: 'https://api.deepseek.com/v1/chat/completions'),
        _sketchField(_aiModelCtrl, 'AI 模型名称', hint: 'deepseek-chat, claude-sonnet-4-6 等'),
      ],
    );
  }

  // ── 图片生成 API ──
  Widget _buildImageApiSection() {
    return _SketchSection(
      title: '图片生成 API',
      emoji: '🎨',
      subtitle: '可选：用于推荐成品图或步骤图',
      rotation: 0.5,
      children: [
        _sketchField(_imageApiKeyCtrl, '图片生成 API Key', obscure: true),
        _sketchField(_imageBaseUrlCtrl, '图片生成 Base URL'),
      ],
    );
  }

  // ── 外部工具 API ──
  Widget _buildToolApiSection() {
    return _SketchSection(
      title: '外部工具 API',
      emoji: '🌐',
      rotation: -0.4,
      children: [
        _sketchField(_weatherApiKeyCtrl, 'OpenWeatherMap API Key', hint: '天气查询', obscure: true),
        _sketchField(_serperApiKeyCtrl, 'Serper API Key', hint: '网页搜索', obscure: true),
      ],
    );
  }

  // ── 保存按钮 ──
  Widget _buildSaveButton() {
    return JellyButton(
      onTap: _save,
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Text('💾'),
        SizedBox(width: 8),
        Text('保存设置'),
      ]),
    );
  }

  // ── 收藏菜品 ──
  Widget _buildFavoritesSection() {
    return _SketchSection(
      title: '收藏菜品',
      emoji: '❤️',
      rotation: 0.3,
      trailing: GestureDetector(
        onTap: _loadFavorites,
        child: CustomPaint(
          foregroundPainter: DashedBorderPainter(
            color: SketchColors.lineBrown.withOpacity(0.4),
            strokeWidth: 1.5,
            dashWidth: 4,
            dashSpace: 3,
            borderRadius: BorderRadius.circular(10),
            wobble: 0.5,
          ),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.refresh_rounded, size: 18, color: SketchColors.lineBrown.withOpacity(0.6)),
          ),
        ),
      ),
      children: [
        if (_favsLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(color: SketchColors.lineBrown),
          ))
        else if (_favorites.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SketchColors.lineBrown.withOpacity(0.2), width: 1.5),
            ),
            child: Text('还没有收藏的菜品 🍽️',
                style: TextStyle(color: SketchColors.lineBrown.withOpacity(0.5)), textAlign: TextAlign.center),
          )
        else
          ..._favorites.map((fav) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FavCard(
              name: fav['recipe_name'] ?? '',
              onDelete: () => _deleteFavorite(fav['id']),
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
    );
  }
}

/// 手绘风分区卡片
class _SketchSection extends StatelessWidget {
  final String title;
  final String emoji;
  final String? subtitle;
  final Widget? trailing;
  final double rotation;
  final List<Widget> children;

  const _SketchSection({
    required this.title,
    required this.emoji,
    this.subtitle,
    this.trailing,
    this.rotation = 0,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return HandDrawnCard(
      color: SketchColors.bg,
      rotation: rotation,
      hoverRotation: -rotation,
      padding: const EdgeInsets.all(20),
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
                  Text(title, style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16, color: SketchColors.textMain,
                  )),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(
                      fontSize: 12, color: SketchColors.lineBrown.withOpacity(0.6),
                    )),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 16),
          // 虚线分隔
          CustomPaint(
            size: const Size(double.infinity, 2),
            painter: _DashLinePainter(),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// 水平虚线分隔线
class _DashLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SketchColors.lineBrown.withOpacity(0.2)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + 6, size.height / 2), paint);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 收藏菜品卡片
class _FavCard extends StatelessWidget {
  final String name;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _FavCard({required this.name, required this.onDelete, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: SketchColors.lineBrown.withOpacity(0.35),
          strokeWidth: 1.5,
          dashWidth: 6,
          dashSpace: 4,
          borderRadius: BorderRadius.circular(14),
          wobble: 0.5,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: SketchColors.lineBrown.withOpacity(0.06), offset: const Offset(3, 3), blurRadius: 0)],
          ),
          child: Row(children: [
            const Text('❤️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name, style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: SketchColors.textMain,
              )),
            ),
            GestureDetector(
              onTap: onDelete,
              child: CustomPaint(
                foregroundPainter: DashedBorderPainter(
                  color: const Color(0xFFE57373).withOpacity(0.5),
                  strokeWidth: 1.5,
                  dashWidth: 4,
                  dashSpace: 3,
                  borderRadius: BorderRadius.circular(10),
                  wobble: 0.4,
                ),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE57373), size: 16),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
