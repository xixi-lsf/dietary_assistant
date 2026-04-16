import 'package:flutter/material.dart';
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
  List<Ingredient> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() { if (!_tabs.indexIsChanging) _load(); });
    _load();
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('添加'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称')),
          TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: '数量'), keyboardType: TextInputType.number),
          TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: '单位')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await ApiService.post('/ingredients/', {
                'name': nameCtrl.text,
                'category': _categories[_tabs.index],
                'quantity': double.tryParse(qtyCtrl.text) ?? 0,
                'unit': unitCtrl.text,
              });
              Navigator.pop(context);
              _load();
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('冰箱'),
        centerTitle: true,
        bottom: TabBar(controller: _tabs, tabs: _labels.map((l) => Tab(text: l)).toList()),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddDialog, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: List.generate(3, (_) => _ItemList(items: _items, onDelete: (id) async {
                await ApiService.delete('/ingredients/$id');
                _load();
              })),
            ),
    );
  }
}

class _ItemList extends StatelessWidget {
  final List<Ingredient> items;
  final Future<void> Function(int) onDelete;
  const _ItemList({required this.items, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('暂无数据'));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return ListTile(
          title: Text(item.name),
          subtitle: Text('${item.quantity} ${item.unit}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => onDelete(item.id!),
          ),
        );
      },
    );
  }
}
