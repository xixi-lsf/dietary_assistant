import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';

/// 三层反馈弹窗
/// Level 1: 👍/👎 快速反馈
/// Level 2: 单选原因（结构化）
/// Level 3: 深度评分 + 自由文字（做完之后）
class FeedbackDialog extends StatefulWidget {
  final String recipeName;
  final bool cooked;
  final String recommendationMode;

  const FeedbackDialog({super.key, required this.recipeName, this.cooked = false, this.recommendationMode = 'hardcoded'});

  static Future<void> show(BuildContext context, String recipeName, {bool cooked = false, String recommendationMode = 'hardcoded'}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FeedbackDialog(recipeName: recipeName, cooked: cooked, recommendationMode: recommendationMode),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  // 0=选层, 1=快速原因, 2=深度反馈
  int _step = 0;
  bool? _liked;

  static const _positiveReasons = ['口感很好', '食材新鲜', '步骤简单', '营养均衡', '份量合适', '味道正宗', '适合我的口味'];
  static const _negativeReasons = ['太辣', '太淡', '太油', '太咸', '食材难买', '步骤复杂', '不喜欢食材', '份量不对', '热量太高'];

  final Set<String> _selectedReasons = {};
  final _quickInputCtrl = TextEditingController();  // 自由输入
  int _deepScore = 4;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
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
          const SnackBar(content: Text('感谢反馈，记忆已更新～'), backgroundColor: Colors.green),
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

  Widget _buildStep0() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('「${widget.recipeName}」怎么样？', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _thumbBtn(true),
        _thumbBtn(false),
      ]),
      const SizedBox(height: 12),
      if (widget.cooked)
        TextButton(
          onPressed: () => setState(() => _step = 2),
          child: const Text('做完了，写详细评价'),
        ),
    ]);
  }

  Widget _thumbBtn(bool like) {
    return GestureDetector(
      onTap: () {
        setState(() { _liked = like; _step = 1; });
      },
      child: Column(children: [
        Icon(like ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
            size: 40, color: like ? Colors.green : Colors.red),
        const SizedBox(height: 4),
        Text(like ? '喜欢' : '不喜欢', style: const TextStyle(fontSize: 13)),
      ]),
    );
  }

  Widget _buildStep1() {
    final score = _liked == true ? 4 : 2;
    final reasons = _liked == true ? _positiveReasons : _negativeReasons;
    final color = _liked == true ? Colors.green : Colors.red;

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_liked == true ? '哪里做得好？' : '哪里不满意？',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: reasons.map((r) {
        final selected = _selectedReasons.contains(r);
        return FilterChip(
          label: Text(r),
          selected: selected,
          selectedColor: color.withOpacity(0.15),
          checkmarkColor: color,
          side: BorderSide(color: selected ? color : Colors.grey.shade300),
          onSelected: (v) => setState(() => v ? _selectedReasons.add(r) : _selectedReasons.remove(r)),
        );
      }).toList()),
      const SizedBox(height: 10),
      TextField(
        controller: _quickInputCtrl,
        decoration: InputDecoration(
          hintText: '还有其他想说的？（可选）',
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          suffixIcon: _quickInputCtrl.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => setState(() => _quickInputCtrl.clear()))
              : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton(
          onPressed: () => _submit(score: score, level: 'quick'),
          child: const Text('跳过'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _submitting ? null : () {
            final allReasons = [
              ..._selectedReasons,
              if (_quickInputCtrl.text.trim().isNotEmpty) _quickInputCtrl.text.trim(),
            ];
            _submit(
              score: score,
              level: 'quick',
              quickReason: allReasons.join(','),
            );
          },
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('提交'),
        ),
      ]),
    ]);
  }

  Widget _buildStep2() {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('「${widget.recipeName}」详细评价', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
        return IconButton(
          icon: Icon(i < _deepScore ? Icons.star_rounded : Icons.star_outline_rounded,
              color: Colors.amber, size: 32),
          onPressed: () => setState(() => _deepScore = i + 1),
        );
      })),
      const SizedBox(height: 8),
      TextField(
        controller: _commentCtrl,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: '口感、难度、改进建议……',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.all(10),
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        FilledButton(
          onPressed: _submitting ? null : () => _submit(
            score: _deepScore,
            comment: _commentCtrl.text,
            level: 'deep',
          ),
          child: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('提交'),
        ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _step == 0 ? _buildStep0() : _step == 1 ? _buildStep1() : _buildStep2(),
      ),
    );
  }
}
