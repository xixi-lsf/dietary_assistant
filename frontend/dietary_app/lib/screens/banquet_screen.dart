import 'package:flutter/material.dart';
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
        _recipes = (data['recipes'] as List).map((e) => Recipe.fromJson(Map<String, dynamic>.from(e))).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('宴请菜单'), centerTitle: true),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              const Text('用餐人数：'),
              IconButton(icon: const Icon(Icons.remove), onPressed: _people > 1 ? () => setState(() => _people--) : null),
              Text('$_people 人', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _people++)),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _customOccasion ? '自定义...' : _occasion,
              decoration: const InputDecoration(labelText: '场合'),
              items: _occasions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) => setState(() {
                if (v == '自定义...') {
                  _customOccasion = true;
                } else {
                  _customOccasion = false;
                  _occasion = v!;
                }
              }),
            ),
            if (_customOccasion) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customOccasionCtrl,
                decoration: const InputDecoration(labelText: '请输入场合', hintText: '如：同学聚会、公司年会...'),
              ),
            ],
            const SizedBox(height: 8),
            TextField(controller: _prefsCtrl, decoration: const InputDecoration(labelText: '口味偏好', hintText: '如：偏辣、家常菜')),
            const SizedBox(height: 8),
            TextField(controller: _restrictCtrl, decoration: const InputDecoration(labelText: '忌口', hintText: '如：不吃香菜、素食')),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _generate,
                child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('生成菜单'),
              ),
            ),
          ]),
        ),
        if (_recipes.isNotEmpty) ...[
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _recipes.length,
              itemBuilder: (_, i) {
                final r = _recipes[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: r.category != null ? Chip(label: Text(r.category!, style: const TextStyle(fontSize: 11))) : null,
                    title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${r.timeMinutes} 分钟 · ${(r.nutrition['calories'] ?? 0).toStringAsFixed(0)} kcal'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: r, stepsCache: _stepsCache))),
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
