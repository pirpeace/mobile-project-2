import 'package:flutter/material.dart';
import '../helper/db_helper.dart';
import '../product/product_list_screen.dart';
import '../scanner/price_scanner_screen.dart';
import '../shopping/shopping_list_screen.dart';

class _HomeData {
  final int productCount;
  final int lowStockCount;
  final int outdatedLabelCount;
  final List<Map<String, dynamic>> expiring;

  const _HomeData({
    required this.productCount,
    required this.lowStockCount,
    required this.outdatedLabelCount,
    required this.expiring,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;

  static const List<String> _weekdays = [
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์',
    'อาทิตย์',
  ];

  static const List<String> _months = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final products = await DBHelper.getAllProducts();
    final shopping = await DBHelper.getShoppingList();
    final expiring = await DBHelper.getExpiringBatches(7);

    final outdated =
        products.where((p) => (p['label_outdated'] ?? 0) == 1).length;

    return _HomeData(
      productCount: products.length,
      lowStockCount: shopping.length,
      outdatedLabelCount: outdated,
      expiring: expiring,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    if (mounted) {
      _refresh();
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'สวัสดีตอนเช้า';
    if (hour < 17) return 'สวัสดีตอนบ่าย';
    return 'สวัสดีตอนเย็น';
  }

  String _thaiDate() {
    final now = DateTime.now();
    final weekday = _weekdays[now.weekday - 1];
    final month = _months[now.month - 1];
    return 'วัน$weekday ที่ ${now.day} $month ${now.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(
              child: FutureBuilder<_HomeData>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, size: 48, color: cs.error),
                          const SizedBox(height: 12),
                          Text(
                            'โหลดข้อมูลไม่สำเร็จ\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: _refresh,
                            child: const Text('ลองใหม่'),
                          ),
                        ],
                      ),
                    );
                  }

                  return _buildContent(context, snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 24, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, Color.lerp(cs.primary, Colors.black, 0.3)!],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _thaiDate(),
            style: TextStyle(
              color: cs.onPrimary.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _greeting(),
            style: TextStyle(
              color: cs.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'จัดการราคาและสต็อกสินค้าในร้าน',
            style: TextStyle(
              color: cs.onPrimary.withOpacity(0.9),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),
          _ScanCard(onTap: () => _open(const PriceScannerScreen())),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, _HomeData data) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('ภาพรวมวันนี้'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'สินค้าทั้งหมด',
                  value: data.productCount,
                  background: cs.primaryContainer,
                  foreground: cs.onPrimaryContainer,
                  onTap: () => _open(const ProductListScreen()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.shopping_cart_outlined,
                  label: 'ต้องซื้อเพิ่ม',
                  value: data.lowStockCount,
                  background: cs.secondaryContainer,
                  foreground: cs.onSecondaryContainer,
                  onTap: () => _open(const ShoppingListScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.event_busy_outlined,
                  label: 'ใกล้หมดอายุ (7 วัน)',
                  value: data.expiring.length,
                  background: cs.errorContainer,
                  foreground: cs.onErrorContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.sell_outlined,
                  label: 'ป้ายราคาต้องเปลี่ยน',
                  value: data.outdatedLabelCount,
                  background: cs.tertiaryContainer,
                  foreground: cs.onTertiaryContainer,
                  onTap: () => _open(const ProductListScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _SectionTitle('เมนู'),
          const SizedBox(height: 12),
          _MenuTile(
            icon: Icons.list_alt_outlined,
            title: 'รายการสินค้า',
            subtitle: 'ดู แก้ไขราคา และตั้งค่าสต็อกขั้นต่ำ',
            onTap: () => _open(const ProductListScreen()),
          ),
          const SizedBox(height: 10),
          _MenuTile(
            icon: Icons.shopping_cart_checkout,
            title: 'รายการที่ต้องซื้อ',
            subtitle: 'สินค้าที่ใกล้หมด คัดลอกส่งใน LINE ได้',
            onTap: () => _open(const ShoppingListScreen()),
          ),
          const SizedBox(height: 28),
          const _SectionTitle('ใกล้หมดอายุ'),
          const SizedBox(height: 12),
          _buildExpiringSection(context, data.expiring),
        ],
      ),
    );
  }

  Widget _buildExpiringSection(
    BuildContext context,
    List<Map<String, dynamic>> expiring,
  ) {
    final cs = Theme.of(context).colorScheme;

    if (expiring.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 36,
              color: cs.onPrimaryContainer,
            ),
            const SizedBox(height: 8),
            Text(
              'ยังไม่มีสินค้าใกล้หมดอายุ',
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final shown = expiring.take(5).toList();

    return Column(
      children: [
        for (final batch in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ExpiryTile(
              name: batch['name']?.toString() ?? 'ไม่มีชื่อ',
              qty: (batch['qty'] as num?)?.toInt() ?? 0,
              daysLeft: _daysLeft(batch['expiry_date']?.toString(), today),
            ),
          ),
        if (expiring.length > shown.length)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'และอีก ${expiring.length - shown.length} รายการ',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  int _daysLeft(String? expiryDate, DateTime today) {
    final parsed = DateTime.tryParse(expiryDate ?? '');
    if (parsed == null) return 0;
    final expiry = DateTime(parsed.year, parsed.month, parsed.day);
    return expiry.difference(today).inDays;
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}

class _ScanCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ScanCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 34,
                  color: cs.onPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'สแกนเช็คราคา',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'แตะเพื่อเปิดกล้องและสแกนบาร์โค้ด',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 18, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(height: 12),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpiryTile extends StatelessWidget {
  final String name;
  final int qty;
  final int daysLeft;

  const _ExpiryTile({
    required this.name,
    required this.qty,
    required this.daysLeft,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final expired = daysLeft < 0;

    final String badge;
    if (expired) {
      badge = 'หมดอายุแล้ว';
    } else if (daysLeft == 0) {
      badge = 'หมดอายุวันนี้';
    } else {
      badge = 'อีก $daysLeft วัน';
    }

    return Material(
      color: cs.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'เหลือ $qty ชิ้น',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: expired || daysLeft <= 2
                    ? cs.errorContainer
                    : cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: expired || daysLeft <= 2
                      ? cs.onErrorContainer
                      : cs.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
