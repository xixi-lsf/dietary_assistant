import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _categories = ['ingredient', 'cookware', 'seasoning'];
  final _labels = ['食材', '厨具', '调料'];
  final _emojis = ['🥦', '🍳', '🧂'];
  final _colors = [AppColors.green, AppColors.primary, AppColors.yellow];
  final _softColors = [AppColors.greenSoft, AppColors.primarySoft, AppColors.yellowSoft];
  final _borderColors = [AppColors.greenLight, AppColors.primaryLight, Color(0xFFFFE599)];
  List<Ingredient> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() { if (!_tabs.indexIsChanging) _load(); });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cat = _categories[_tabs.index];
      final data = await ApiService.getList('/ingredients/?category=$cat');
      setState(() {
        _items = data.map((e) => Ingredient.fromJson(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final idx = _tabs.index;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.shadowOuter, blurRadius: 16, offset: const Offset(3, 5)),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(_emojis[idx], style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text('添加${_labels[idx]}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              ]),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '名称', prefixIcon: Icon(Icons.edit_rounded)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: '数量'),
                  keyboardType: TextInputType.number,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(labelText: '单位'),
                )),
              ]),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(context),
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
                    await ApiService.post('/ingredients/', {
                      'name': nameCtrl.text,
                      'category': _categories[idx],
                      'quantity': double.tryParse(qtyCtrl.text) ?? 0,
                      'unit': unitCtrl.text,
                    });
                    Navigator.pop(context);
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _colors[idx],
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: _colors[idx].withOpacity(0.3), blurRadius: 8, offset: const Offset(1, 3))],
                    ),
                    child: const Center(child: Text('添加',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
                  ),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idx = _tabs.index;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('我的冰箱 🧊'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  color: _softColors[idx],
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _borderColors[idx], width: 1.5),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: _colors[idx],
                unselectedLabelColor: AppColors.textLight,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: List.generate(3, (i) => Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_emojis[i], style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(_labels[i]),
                    ],
                  ),
                )),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: GestureDetector(
        onTap: _showAddDialog,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _colors[idx],
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: _colors[idx].withOpacity(0.4), blurRadius: 12, offset: const Offset(2, 4)),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
      body: _loading
          ? const Center(child: _FridgeLoading())
          : TabBarView(
              controller: _tabs,
              children: List.generate(3, (i) => _ItemList(
                items: _items,
                accentColor: _colors[i],
                softColor: _softColors[i],
                onDelete: (id) async {
                  await ApiService.delete('/ingredients/$id');
                  _load();
                },
              )),
            ),
    );
  }
}

class _ItemList extends StatelessWidget {
  final List<Ingredient> items;
  final Color accentColor;
  final Color softColor;
  final Future<void> Function(int) onDelete;

  const _ItemList({
    required this.items,
    required this.accentColor,
    required this.softColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('空空如也 🌿', style: TextStyle(fontSize: 16, color: AppColors.textLight)),
            const SizedBox(height: 8),
            Text('点击右下角添加', style: TextStyle(fontSize: 13, color: AppColors.textLight)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 2),
              boxShadow: [
                BoxShadow(color: AppColors.shadowOuter, blurRadius: 6, offset: const Offset(2, 3)),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: softColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    item.name.isNotEmpty ? item.name[0] : '?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: accentColor),
                  ),
                ),
              ),
              title: Text(item.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              subtitle: Text('${item.quantity} ${item.unit}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textLight)),
              trailing: GestureDetector(
                onTap: () => onDelete(item.id!),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFCCCC), width: 1.5),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE57373), size: 18),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FridgeLoading extends StatelessWidget {
  const _FridgeLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            color: AppColors.green,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 12),
        Text('加载中...', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
      ],
    );
  }
}
