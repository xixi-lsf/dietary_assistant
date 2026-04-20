import 'dart:math';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// 三层反馈弹窗 — 手绘风格
/// Level 1: 👍/👎 快速反馈
/// Level 2: 单选原因（结构化）
/// Level 3: 深度评分 + 自由文字
class FeedbackDialog extends StatefulWidget {
  final String recipeName;
  final bool cooked;
  final String recommendationMode;

  const FeedbackDialog({super.key, required this.recipeName, this.cooked = false, this.recommendationMode = 'hardcoded'});

  static Future<void> show(BuildContext context, String recipeName, {bool cooked = false, String recommendationMode = 'hardcoded'}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FeedbackDialog(recipeName: recipeName, cooked: cooked, recommendationMode: recommendationMode),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  bool? _liked;

  static const _positiveReasons = ['口感很好', '食材新鲜', '步骤简单', '营养均衡', '份量合适', '味道正宗', '适合我的口味'];
  static const _negativeReasons = ['太辣', '太淡', '太油', '太咸', '食材难买', '步骤复杂', '不喜欢食材', '份量不对', '热量太高'];

  final Set<String> _selectedReasons = {};
  final _quickInputCtrl = TextEditingController();
  int _deepScore = 4;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  late AnimationController _swayCtrl;

  @override
  void initState() {
    super.initState();
    _swayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _swayCtrl.dispose();
    _commentCtrl.dispose();
    _quickInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit({required int score, String comment = '', String level = 'quick', String quickReason = ''}) async {
    setState(() => _submitting = true);
    try {
      final apiKey = await ApiConfig.getApiKey();
      final aiBaseUrl = await ApiConfig.getAiBaseUrl();
      await ApiService.postWithHeaders('/ai/feedback', {
        'recipe_name': widget.recipeName,
        'score': score,
        'comment': comment,
        'structured_tags': '',
        'feedback_level': level,
        'quick_reason': quickReason,
        'recommendation_mode': widget.recommendationMode,
      }, extraHeaders: {
        if (apiKey != null && apiKey.isNotEmpty) 'X-API-Key': apiKey,
        if (aiBaseUrl != null && aiBaseUrl.isNotEmpty) 'X-AI-Base-URL': aiBaseUrl,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('感谢反馈，记忆已更新～ 🌱', style: TextStyle(color: SketchColors.textMain)),
            backgroundColor: SketchColors.bg,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: SketchColors.lineBrown, width: 2),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 手绘风标签 chip
  Widget _sketchChip(String label, {required bool selected, required Color activeColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeColor.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.elliptical(12 + Random(label.hashCode).nextDouble() * 8, 10),
            topRight: Radius.elliptical(10, 12 + Random(label.hashCode + 1).nextDouble() * 8),
            bottomRight: Radius.elliptical(14 + Random(label.hashCode + 2).nextDouble() * 6, 10),
            bottomLeft: Radius.elliptical(10, 14 + Random(label.hashCode + 3).nextDouble() * 6),
          ),
          border: Border.all(
            color: selected ? activeColor : SketchColors.lineBrown.withOpacity(0.4),
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: activeColor.withOpacity(0.1), offset: const Offset(3, 3), blurRadius: 0)]
              : [const BoxShadow(color: Color(0x0D8D6E63), offset: Offset(2, 2), blurRadius: 0)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (selected) ...[
            Icon(Icons.check_rounded, size: 14, color: activeColor),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(
            fontSize: 13,
            color: selected ? activeColor : SketchColors.textMain,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          )),
        ]),
      ),
    );
  }

  /// 手绘风按钮
  Widget _sketchButton({required String text, required VoidCallback? onTap, bool primary = true, bool loading = false}) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: primary ? SketchColors.lineBrown : SketchColors.lineBrown.withOpacity(0.4),
          strokeWidth: primary ? 2.5 : 1.5,
          dashWidth: primary ? 10 : 6,
          dashSpace: primary ? 4 : 5,
          borderRadius: BorderRadius.circular(20),
          wobble: 0.8,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: primary ? const Color(0xFFF0F9F0) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: SketchColors.lineBrown.withOpacity(primary ? 0.15 : 0.08),
                offset: const Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SketchColors.lineBrown))
              : Text(text, style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primary ? SketchColors.textMain : SketchColors.lineBrown.withOpacity(0.6),
                )),
        ),
      ),
    );
  }

  /// 手绘风输入框
  Widget _sketchTextField({required TextEditingController controller, String hint = '', int maxLines = 1, ValueChanged<String>? onChanged}) {
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: SketchColors.lineBrown.withOpacity(0.5),
        strokeWidth: 2,
        dashWidth: 6,
        dashSpace: 4,
        borderRadius: BorderRadius.circular(12),
        wobble: 0.6,
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: SketchColors.textMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: SketchColors.lineBrown.withOpacity(0.4), fontSize: 13),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildStep0() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // 标题
      Text('「${widget.recipeName}」', style: const TextStyle(
        fontSize: 17, fontWeight: FontWeight.w800, color: SketchColors.textMain,
      )),
      const SizedBox(height: 4),
      Text('怎么样？', style: TextStyle(
        fontSize: 14, color: SketchColors.lineBrown.withOpacity(0.7),
      )),
      const SizedBox(height: 20),
      // 👍 👎 按钮
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _thumbCard(true),
        _thumbCard(false),
      ]),
      if (widget.cooked) ...[
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => _step = 2),
          child: Text('做完了，写详细评价 ✍️', style: TextStyle(
            fontSize: 13, color: SketchColors.lineBrown.withOpacity(0.6),
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dashed,
          )),
        ),
      ],
    ]);
  }

  Widget _thumbCard(bool like) {
    final emoji = like ? '😋' : '😕';
    final label = like ? '喜欢' : '不喜欢';
    final bgColor = like ? const Color(0xFFF0F9F0) : const Color(0xFFFFF5F6);
    return GestureDetector(
      onTap: () => setState(() { _liked = like; _step = 1; }),
      child: CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: SketchColors.lineBrown,
          strokeWidth: 2.5,
          dashWidth: 8,
          dashSpace: 5,
          borderRadius: BorderRadius.only(
            topLeft: Radius.elliptical(like ? 30 : 15, like ? 15 : 30),
            topRight: Radius.elliptical(like ? 15 : 30, like ? 30 : 15),
            bottomRight: Radius.elliptical(like ? 25 : 20, like ? 20 : 25),
            bottomLeft: Radius.elliptical(like ? 20 : 25, like ? 25 : 20),
          ),
          wobble: 1.2,
        ),
        child: Container(
          width: 110,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: SketchColors.lineBrown.withOpacity(0.1), offset: const Offset(6, 6), blurRadius: 0),
            ],
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SketchColors.textMain)),
          ]),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    final score = _liked == true ? 4 : 2;
    final reasons = _liked == true ? _positiveReasons : _negativeReasons;
    final activeColor = _liked == true ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 返回 + 标题
      Row(children: [
        GestureDetector(
          onTap: () => setState(() { _step = 0; _selectedReasons.clear(); }),
          child: const Icon(Icons.arrow_back_rounded, size: 20, color: SketchColors.lineBrown),
        ),
        const SizedBox(width: 8),
        Text(
          _liked == true ? '🌿 哪里做得好？' : '🍂 哪里不满意？',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: SketchColors.textMain),
        ),
      ]),
      const SizedBox(height: 14),
      // 标签
      Wrap(spacing: 8, runSpacing: 10, children: reasons.map((r) {
        final selected = _selectedReasons.contains(r);
        return _sketchChip(r, selected: selected, activeColor: activeColor,
          onTap: () => setState(() => selected ? _selectedReasons.remove(r) : _selectedReasons.add(r)),
        );
      }).toList()),
      const SizedBox(height: 14),
      _sketchTextField(
        controller: _quickInputCtrl,
        hint: '还有其他想说的？（可选）',
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 18),
      // 按钮行
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        _sketchButton(text: '跳过', primary: false, onTap: () => _submit(score: score, level: 'quick')),
        const SizedBox(width: 10),
        _sketchButton(
          text: '提交',
          loading: _submitting,
          onTap: () {
            final allReasons = [
              ..._selectedReasons,
              if (_quickInputCtrl.text.trim().isNotEmpty) _quickInputCtrl.text.trim(),
            ];
            _submit(score: score, level: 'quick', quickReason: allReasons.join(','));
          },
        ),
      ]),
    ]);
  }

  Widget _buildStep2() {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        GestureDetector(
          onTap: () => setState(() => _step = 0),
          child: const Icon(Icons.arrow_back_rounded, size: 20, color: SketchColors.lineBrown),
        ),
        const SizedBox(width: 8),
        Text('✨「${widget.recipeName}」详细评价', style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: SketchColors.textMain,
        )),
      ]),
      const SizedBox(height: 16),
      // 星星评分 — 手绘风
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
        final filled = i < _deepScore;
        return GestureDetector(
          onTap: () => setState(() => _deepScore = i + 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: filled ? const Color(0xFFFFF8E1) : Colors.white,
              border: Border.all(
                color: filled ? const Color(0xFFFFB300) : SketchColors.lineBrown.withOpacity(0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.elliptical(12 + i * 2.0, 10),
                topRight: Radius.elliptical(10, 12 + i * 2.0),
                bottomRight: Radius.elliptical(14 - i * 1.0, 10),
                bottomLeft: Radius.elliptical(10, 14 - i * 1.0),
              ),
              boxShadow: filled
                  ? [const BoxShadow(color: Color(0x1AFFB300), offset: Offset(3, 3), blurRadius: 0)]
                  : null,
            ),
            child: Center(child: Text(
              filled ? '⭐' : '☆',
              style: TextStyle(fontSize: filled ? 20 : 18),
            )),
          ),
        );
      })),
      const SizedBox(height: 14),
      _sketchTextField(
        controller: _commentCtrl,
        hint: '口感、难度、改进建议……',
        maxLines: 3,
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        _sketchButton(
          text: '提交评价',
          loading: _submitting,
          onTap: () => _submit(score: _deepScore, comment: _commentCtrl.text, level: 'deep'),
        ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _swayCtrl,
      builder: (_, child) {
        final angle = sin(_swayCtrl.value * pi * 2) * 0.005;
        return Transform.rotate(angle: angle, child: child);
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.of(context).viewInsets.bottom + 12),
        child: CustomPaint(
          foregroundPainter: DashedBorderPainter(
            color: SketchColors.lineBrown,
            strokeWidth: 3,
            dashWidth: 10,
            dashSpace: 5,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.elliptical(40, 20),
              topRight: Radius.elliptical(15, 50),
              bottomRight: Radius.elliptical(50, 15),
              bottomLeft: Radius.elliptical(20, 40),
            ),
            wobble: 1.4,
          ),
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutBack,
              child: _step == 0
                  ? _buildStep0()
                  : _step == 1
                      ? _buildStep1()
                      : _buildStep2(),
            ),
          ),
        ),
      ),
    );
  }
}
