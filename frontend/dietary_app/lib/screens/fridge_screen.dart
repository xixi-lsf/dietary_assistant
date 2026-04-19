import 'dart:math' show pi;

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
  final _cardColors = [SketchColors.greenLight, SketchColors.pinkLight, const Color(0xFFFFF7E6)];
  final _accentColors = [const Color(0xFF7A9A52), const Color(0xFFC87C5A), const Color(0xFFB78A2A)];
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
        child: CustomPaint(
          foregroundPainter: const DashedBorderPainter(
            color: SketchColors.lineBrown,
            strokeWidth: 3,
            wobble: 1.2,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F8D6E63),
                  offset: Offset(8, 8),
                  blurRadius: 0,
                ),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: SketchColors.textMain,
                        fontFamily: 'LXGWWenKai',
                      )),
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
                        color: SketchColors.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: SketchColors.lineBrown, width: 2.5),
                      ),
                      child: const Center(child: Text('取消',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: SketchColors.textMain,
                            fontFamily: 'LXGWWenKai',
                          ))),
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
                        color: _accentColors[idx],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: SketchColors.lineBrown, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: SketchColors.lineBrown,
                            offset: Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: const Center(child: Text('添加',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'LXGWWenKai',
                          ))),
                    ),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idx = _tabs.index;
    return Scaffold(
      backgroundColor: SketchColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('我的冰箱 🧊'),
      ),
      floatingActionButton: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _showAddDialog,
          child: Transform.rotate(
            angle: -2 * pi / 180,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _cardColors[idx],
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: SketchColors.lineBrown, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: SketchColors.lineBrown,
                    offset: Offset(5, 5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: SketchColors.textMain, size: 30),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: PaperDotsPainter()),
          ),
          SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 564,
                      child: CustomPaint(
                        foregroundPainter: const DashedBorderPainter(
                          color: SketchColors.lineBrown,
                          strokeWidth: 3,
                          wobble: 1.1,
                        ),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.94),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A8D6E63),
                                offset: Offset(5, 5),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: TabBar(
                            controller: _tabs,
                            indicator: BoxDecoration(
                              color: _cardColors[idx],
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: SketchColors.lineBrown, width: 2),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: SketchColors.textMain,
                            unselectedLabelColor: SketchColors.textMain.withOpacity(0.55),
                            labelStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'LXGWWenKai',
                            ),
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
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: _FridgeLoading())
                      : TabBarView(
                          controller: _tabs,
                          children: List.generate(3, (i) => _ItemList(
                            items: _items,
                            accentColor: _accentColors[i],
                            softColor: _cardColors[i],
                            onDelete: (id) async {
                              await ApiService.delete('/ingredients/$id');
                              _load();
                            },
                          )),
                        ),
                ),
              ],
            ),
          ),
        ],
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CustomPaint(
            foregroundPainter: const DashedBorderPainter(
              color: SketchColors.lineBrown,
              strokeWidth: 3,
              wobble: 1.2,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A8D6E63),
                    offset: Offset(8, 8),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '空空如也 🌿',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: SketchColors.textMain,
                      fontFamily: 'LXGWWenKai',
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '点击右下角贴一张新的小便签吧',
                    style: TextStyle(
                      fontSize: 13,
                      color: SketchColors.textMain,
                      fontFamily: 'LXGWWenKai',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const cardWidth = 184.0;
        const horizontalSpacing = 4.0;
        const verticalSpacing = 12.0;
        final totalWidth = constraints.maxWidth;
        final desiredColumns = totalWidth > 900 ? 4 : 3;
        final usedWidth = (cardWidth * desiredColumns) +
            (horizontalSpacing * (desiredColumns - 1));
        final horizontalInset = ((totalWidth - usedWidth) / 2)
            .clamp(8.0, 20.0)
            .toDouble();

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(horizontalInset, 8, horizontalInset, 96),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: desiredColumns,
            crossAxisSpacing: horizontalSpacing,
            mainAxisSpacing: verticalSpacing,
            mainAxisExtent: 80,
          ),
          itemBuilder: (_, i) {
            final item = items[i];
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: cardWidth,
                child: _FridgeIngredientCard(
                  item: item,
                  accentColor: accentColor,
                  softColor: softColor,
                  tilt: i.isEven ? -0.7 : 0.6,
                  hoverTilt: i.isEven ? 0.45 : -0.4,
                  onDelete: () => onDelete(item.id!),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FridgeIngredientCard extends StatefulWidget {
  final Ingredient item;
  final Color accentColor;
  final Color softColor;
  final double tilt;
  final double hoverTilt;
  final VoidCallback onDelete;

  const _FridgeIngredientCard({
    required this.item,
    required this.accentColor,
    required this.softColor,
    required this.tilt,
    required this.hoverTilt,
    required this.onDelete,
  });

  @override
  State<_FridgeIngredientCard> createState() => _FridgeIngredientCardState();
}

class _FridgeIngredientCardState extends State<_FridgeIngredientCard> {
  bool _hovered = false;

  static const _cardRadius = BorderRadius.only(
    topLeft: Radius.elliptical(28, 16),
    topRight: Radius.elliptical(14, 24),
    bottomRight: Radius.elliptical(24, 14),
    bottomLeft: Radius.elliptical(16, 28),
  );

  @override
  Widget build(BuildContext context) {
    final angle = (_hovered ? widget.hoverTilt : widget.tilt) * pi / 180;
    final scale = _hovered ? 1.02 : 1.0;
    final amountText = '${widget.item.quantity} ${widget.item.unit}'.trim();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..scale(scale, scale)
          ..rotateZ(angle),
        transformAlignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  foregroundPainter: const DashedBorderPainter(
                    color: SketchColors.lineBrown,
                    strokeWidth: 3,
                    dashWidth: 8,
                    dashSpace: 5,
                    borderRadius: _cardRadius,
                    wobble: 1.2,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.softColor,
                      borderRadius: _cardRadius,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A8D6E63),
                          offset: Offset(6, 6),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 12, 34, 10),
                    child: Row(
                      children: [
                        Flexible(
                          flex: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.82),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: SketchColors.lineBrown, width: 1.4),
                            ),
                            child: Text(
                              widget.item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: widget.accentColor,
                                fontFamily: 'LXGWWenKai',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          flex: 5,
                          child: Text(
                            amountText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: SketchColors.textMain,
                              fontFamily: 'LXGWWenKai',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -6,
              left: 22,
              child: Transform.rotate(
                angle: -6 * pi / 180,
                child: Container(
                  width: 46,
                  height: 14,
                  decoration: BoxDecoration(
                    color: SketchColors.lineBrown.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: SketchColors.lineBrown.withOpacity(0.14)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 44,
              right: 8,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: SketchColors.lineBrown, width: 1.2),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: SketchColors.textMain,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FridgeLoading extends StatelessWidget {
  const _FridgeLoading();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const DashedBorderPainter(
        color: SketchColors.lineBrown,
        strokeWidth: 3,
        wobble: 1.2,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A8D6E63),
              offset: Offset(8, 8),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return Container(
                  width: 10,
                  height: 10,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
                  decoration: BoxDecoration(
                    color: index == 1 ? SketchColors.lineBrown : SketchColors.lineBrown.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            const Text(
              '正在翻翻小冰箱...',
              style: TextStyle(
                color: SketchColors.textMain,
                fontSize: 13,
                fontFamily: 'LXGWWenKai',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
