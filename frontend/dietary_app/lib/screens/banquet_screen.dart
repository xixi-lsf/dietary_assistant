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
  static const _occasionEmojis = {
    '宴请': '🥂',
    '年夜饭': '🧧',
    '生日': '🎂',
    '结婚纪念日': '💍',
    '自定义...': '✨',
  };

  @override
  void dispose() {
    _customOccasionCtrl.dispose();
    _prefsCtrl.dispose();
    _restrictCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _recipes = [];
    });
    try {
      final apiKey = await ApiConfig.getApiKey();
      final aiBaseUrl = await ApiConfig.getAiBaseUrl();
      final imageApiKey = await ApiConfig.getImageApiKey();
      final imageBaseUrl = await ApiConfig.getImageBaseUrl();
      final data = await ApiService.post('/recipes/banquet', {
        'people_count': _people,
        'occasion': _customOccasion ? _customOccasionCtrl.text : _occasion,
        'preferences': _prefsCtrl.text,
        'dietary_restrictions': _restrictCtrl.text,
        if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
        if (aiBaseUrl != null && aiBaseUrl.isNotEmpty) 'ai_base_url': aiBaseUrl,
        if (imageApiKey != null && imageApiKey.isNotEmpty)
          'image_api_key': imageApiKey,
        if (imageBaseUrl != null && imageBaseUrl.isNotEmpty)
          'image_base_url': imageBaseUrl,
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
          SnackBar(
            content: Text('生成失败：$e'),
            backgroundColor: const Color(0xFFE57373),
          ),
        );
      }
    }
  }

  void _selectOccasion(String occasion) {
    setState(() {
      if (occasion == '自定义...') {
        _customOccasion = true;
      } else {
        _customOccasion = false;
        _occasion = occasion;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('宴请菜单 🥂'),
      ),
      body: Container(
        color: SketchColors.bg,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: PaperDotsPainter())),
            Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      HandDrawnCard(
                        color: Colors.white,
                        rotation: 0,
                        hoverRotation: 0,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF0D9),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: SketchColors.lineBrown,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.celebration_rounded,
                                    color: SketchColors.lineBrown,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '宴请菜单',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: SketchColors.textMain,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '按人数、场合和口味快速生成一桌菜单。',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: SketchColors.textMain,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Icon(
                                  Icons.people_rounded,
                                  size: 18,
                                  color: SketchColors.lineBrown,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '用餐人数',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: SketchColors.textMain,
                                  ),
                                ),
                                const Spacer(),
                                _SketchCountButton(
                                  icon: Icons.remove_rounded,
                                  onTap: _people > 1
                                      ? () => setState(() => _people--)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '$_people 人',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: SketchColors.textMain,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _SketchCountButton(
                                  icon: Icons.add_rounded,
                                  onTap: () => setState(() => _people++),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '场合',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: SketchColors.textMain,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _occasions.map((occasion) {
                                final selected = _customOccasion
                                    ? occasion == '自定义...'
                                    : occasion == _occasion;
                                return _SketchChoiceChip(
                                  label:
                                      '${_occasionEmojis[occasion] ?? '✨'} $occasion',
                                  selected: selected,
                                  onTap: () => _selectOccasion(occasion),
                                );
                              }).toList(),
                            ),
                            if (_customOccasion) ...[
                              const SizedBox(height: 14),
                              _SketchField(
                                controller: _customOccasionCtrl,
                                label: '请输入场合',
                                hint: '如：同学聚会、公司年会...',
                              ),
                            ],
                            const SizedBox(height: 14),
                            _SketchField(
                              controller: _prefsCtrl,
                              label: '口味偏好',
                              hint: '如：偏辣、家常菜',
                            ),
                            const SizedBox(height: 14),
                            _SketchField(
                              controller: _restrictCtrl,
                              label: '忌口',
                              hint: '如：不吃香菜、素食',
                            ),
                            const SizedBox(height: 16),
                            _SketchPrimaryButton(
                              label: _loading ? '正在生成菜单...' : '生成菜单',
                              onTap: _loading ? null : _generate,
                              busy: _loading,
                            ),
                          ],
                        ),
                      ),
                      if (_recipes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text(
                              '推荐菜单',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: SketchColors.textMain,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _SketchMetaBadge(text: '${_recipes.length} 道'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._recipes.map(
                          (recipe) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RecipeDetailScreen(
                                    recipe: recipe,
                                    stepsCache: _stepsCache,
                                  ),
                                ),
                              ),
                              child: HandDrawnCard(
                                color: Colors.white,
                                rotation: 0,
                                hoverRotation: 0,
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _BanquetImage(recipe: recipe),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            recipe.name,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: SketchColors.textMain,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              _SketchMetaBadge(
                                                text:
                                                    '${recipe.timeMinutes} 分钟',
                                              ),
                                              _SketchMetaBadge(
                                                text:
                                                    '${((recipe.nutrition['calories'] ?? 0) as num).toDouble().toStringAsFixed(0)} kcal',
                                              ),
                                              if (recipe.category != null)
                                                _SketchMetaBadge(
                                                  text: recipe.category!,
                                                ),
                                            ],
                                          ),
                                          if (recipe.ingredients.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              recipe.ingredients
                                                  .take(5)
                                                  .join('、'),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: SketchColors.textMain,
                                                height: 1.45,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: SketchColors.lineBrown,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SketchCountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _SketchCountButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: ShapeDecoration(
          color: enabled ? const Color(0xFFFFF0D9) : const Color(0xFFF4EFE4),
          shape: _SketchWobblyShape(radius: 12),
          shadows: const [
            BoxShadow(
              color: Color(0x1A8D6E63),
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? SketchColors.lineBrown : const Color(0xFFB7A79D),
        ),
      ),
    );
  }
}

class _SketchChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SketchChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: ShapeDecoration(
          color: selected ? const Color(0xFFFFF0D9) : Colors.white,
          shape: _SketchWobblyShape(radius: 14),
          shadows: const [
            BoxShadow(
              color: Color(0x1A8D6E63),
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: SketchColors.textMain,
          ),
        ),
      ),
    );
  }
}

class _SketchField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _SketchField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SketchColors.textMain,
            ),
          ),
        ),
        CustomPaint(
          foregroundPainter: const DashedBorderPainter(
            color: SketchColors.lineBrown,
            strokeWidth: 2,
            dashWidth: 7,
            dashSpace: 4,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.elliptical(38, 20),
                topRight: Radius.elliptical(14, 36),
                bottomRight: Radius.elliptical(34, 16),
                bottomLeft: Radius.elliptical(20, 28),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x128D6E63),
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintStyle: const TextStyle(color: AppColors.textLight),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SketchPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  const _SketchPrimaryButton({
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.55 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: ShapeDecoration(
            color: const Color(0xFFE8F7E7),
            shape: _SketchWobblyShape(radius: 18),
            shadows: const [
              BoxShadow(
                color: Color(0x228D6E63),
                offset: Offset(5, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SketchColors.lineBrown,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: SketchColors.textMain,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SketchMetaBadge extends StatelessWidget {
  final String text;

  const _SketchMetaBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ShapeDecoration(
        color: const Color(0xFFFFFBF4),
        shape: _SketchWobblyShape(radius: 14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: SketchColors.textMain,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BanquetImage extends StatefulWidget {
  final Recipe recipe;
  const _BanquetImage({required this.recipe});

  @override
  State<_BanquetImage> createState() => _BanquetImageState();
}

class _BanquetImageState extends State<_BanquetImage> {
  String? _proxyUrl;

  @override
  void initState() {
    super.initState();
    _buildProxyUrl();
  }

  Future<void> _buildProxyUrl() async {
    final originalUrl = widget.recipe.previewImageUrl;
    if (originalUrl == null || originalUrl.isEmpty) return;
    final base = await ApiConfig.getBaseUrl();
    final encoded = Uri.encodeComponent(originalUrl);
    if (mounted) {
      setState(() => _proxyUrl = '$base/ai/image-proxy?url=$encoded');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4DF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SketchColors.lineBrown, width: 2),
        ),
        child: widget.recipe.previewImageUrl == null
            ? Center(
                child: Text(
                  widget.recipe.name.isNotEmpty ? widget.recipe.name[0] : '🍽',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: SketchColors.lineBrown,
                  ),
                ),
              )
            : _proxyUrl == null
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SketchColors.lineBrown,
                    ),
                  )
                : Image.network(
                    _proxyUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: SketchColors.lineBrown,
                        size: 30,
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _SketchWobblyShape extends ShapeBorder {
  final double radius;

  const _SketchWobblyShape({this.radius = 18});

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(2);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect.deflate(2), textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = radius;
    final path = Path();
    path.moveTo(rect.left + r, rect.top + 2);
    path.quadraticBezierTo(rect.left + rect.width * 0.18, rect.top - 3,
        rect.left + rect.width * 0.32, rect.top + 3);
    path.quadraticBezierTo(rect.left + rect.width * 0.56, rect.top + 8,
        rect.right - r, rect.top + 1);
    path.quadraticBezierTo(rect.right + 2, rect.top + 4, rect.right - 2,
        rect.top + r * 0.9);
    path.quadraticBezierTo(rect.right - 4, rect.center.dy,
        rect.right - 1, rect.bottom - r);
    path.quadraticBezierTo(rect.right - rect.width * 0.22, rect.bottom + 4,
        rect.center.dx, rect.bottom - 1);
    path.quadraticBezierTo(rect.left + rect.width * 0.18, rect.bottom + 6,
        rect.left + 4, rect.bottom - r * 0.9);
    path.quadraticBezierTo(rect.left - 4, rect.center.dy, rect.left + 2,
        rect.top + r);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final path = getOuterPath(rect, textDirection: textDirection);
    final paint = Paint()
      ..color = SketchColors.lineBrown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) => _SketchWobblyShape(radius: radius * t);
}
