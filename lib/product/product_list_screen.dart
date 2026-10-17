import 'package:flutter/material.dart';
import '../helper/db_helper.dart';
import '../shopping/shopping_list_screen.dart';
import 'product_edit_sheet.dart';
import 'product_image.dart';

String _formatPrice(dynamic price) {
  final value = (price as num?)?.toDouble() ?? 0;
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  static const String _noCategory = 'ไม่ระบุหมวด';

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  Object? _error;
  String _query = '';
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await DBHelper.getAllProducts();
      if (!mounted) return;
      setState(() {
        _all = data;
        _loading = false;
        _error = null;
        if (_categoryFilter != null &&
            !_group(_all).keys.contains(_categoryFilter)) {
          _categoryFilter = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// จัดกลุ่มตามหมวดหมู่ (เรียงตามลำดับหมวด) และเรียงชื่อสินค้าในแต่ละหมวด
  Map<String, List<Map<String, dynamic>>> _group(
    List<Map<String, dynamic>> items,
  ) {
    final sorted = [...items]
      ..sort((a, b) {
        final ai = (a['category_id'] as int?) ?? (1 << 30);
        final bi = (b['category_id'] as int?) ?? (1 << 30);
        final byCategory = ai.compareTo(bi);
        if (byCategory != 0) return byCategory;
        return (a['name']?.toString() ?? '').compareTo(
          b['name']?.toString() ?? '',
        );
      });

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final p in sorted) {
      final key = p['category_name']?.toString() ?? _noCategory;
      groups.putIfAbsent(key, () => []).add(p);
    }
    return groups;
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((p) {
      final category = p['category_name']?.toString() ?? _noCategory;
      if (_categoryFilter != null && category != _categoryFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      final name = p['name']?.toString().toLowerCase() ?? '';
      final barcode = p['barcode']?.toString().toLowerCase() ?? '';
      return name.contains(q) || barcode.contains(q);
    }).toList();
  }

  void _openShoppingList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ShoppingListScreen()),
    ).then((_) => _load());
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final changed = await showProductEditSheet(context, item);
    if (changed && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการสินค้า'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_checkout),
            tooltip: 'รายการที่ต้องซื้อ',
            onPressed: _openShoppingList,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อสินค้าหรือบาร์โค้ด',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          _buildCategoryChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final names = _group(_all).keys.toList();
    if (names.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('ทั้งหมด'),
              selected: _categoryFilter == null,
              onSelected: (_) => setState(() => _categoryFilter = null),
            ),
          ),
          for (final n in names)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(n),
                selected: _categoryFilter == n,
                onSelected: (_) => setState(() => _categoryFilter = n),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('เกิดข้อผิดพลาด: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      );
    }

    if (_all.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              'ยังไม่มีข้อมูลสินค้าในระบบ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'กลับไปหน้าสแกนเพื่อเพิ่มสินค้าชิ้นแรกของคุณ',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Text(
          'ไม่พบสินค้าที่ค้นหา',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    final groups = _group(items);

    // จำนวนคอลัมน์ตามความกว้างจอ แล้วคำนวณความสูงการ์ด = รูปจัตุรัส + พื้นที่ข้อความ
    const sidePadding = 16.0;
    const gap = 16.0;
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
    final itemWidth = (width - sidePadding * 2 - gap * (columns - 1)) / columns;
    final itemExtent = itemWidth + 84;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (final entry in groups.entries) ...[
            SliverToBoxAdapter(
              child: _CategoryHeader(
                name: entry.key,
                count: entry.value.length,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: sidePadding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  mainAxisExtent: itemExtent,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = entry.value[index];
                  return _ProductCard(item: item, onTap: () => _edit(item));
                }, childCount: entry.value.length),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String name;
  final int count;

  const _CategoryHeader({required this.name, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;

  const _StatusDot({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 15, color: foreground),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _ProductCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final int stock = item['stock_qty'] ?? 0;
    final int min = item['min_qty'] ?? 0;
    final lowStock = min > 0 && stock <= min;
    final outdated = (item['label_outdated'] ?? 0) == 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(
                      imageFile: item['image_file']?.toString(),
                      iconSize: 44,
                    ),
                    if (outdated || lowStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (outdated)
                              _StatusDot(
                                icon: Icons.sell_outlined,
                                background: cs.tertiaryContainer,
                                foreground: cs.onTertiaryContainer,
                              ),
                            if (outdated && lowStock) const SizedBox(width: 4),
                            if (lowStock)
                              _StatusDot(
                                icon: Icons.warning_amber_rounded,
                                background: cs.errorContainer,
                                foreground: cs.onErrorContainer,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item['name']?.toString() ?? 'ไม่มีชื่อสินค้า',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '฿${_formatPrice(item['price'])}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
