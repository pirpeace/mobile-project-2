import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../helper/db_helper.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late Future<List<Map<String, dynamic>>> _listFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _listFuture = DBHelper.getShoppingList();
    });
  }

  int _suggestedQty(Map<String, dynamic> item) {
    final int stock = item['stock_qty'] ?? 0;
    final int min = item['min_qty'] ?? 0;
    final need = (min * 2) - stock;
    return need < 1 ? 1 : need;
  }

  Future<void> _copyList(List<Map<String, dynamic>> items) async {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';

    final buffer = StringBuffer('รายการที่ต้องซื้อ $dateStr\n');

    for (final item in items) {
      final supplier = item['supplier_name'];
      buffer.writeln(
        '- ${item['name']} x ${_suggestedQty(item)}'
        '${supplier != null ? ' ($supplier)' : ''}',
      );
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('คัดลอกรายการแล้ว นำไปวางใน LINE ได้เลย'),
      ),
    );
  }

  Future<void> _showReceiveDialog(Map<String, dynamic> item) async {
    final qtyController = TextEditingController(
      text: _suggestedQty(item).toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("รับของเข้า: ${item['name']}"),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "จำนวนที่ซื้อมา"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(qtyController.text.trim());
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('กรุณากรอกจำนวนที่มากกว่า 0'),
                  ),
                );
                return;
              }

              await DBHelper.addStock(item['barcode'], qty);
              if (!mounted) return;
              Navigator.pop(context);
              _reload();
            },
            child: const Text("บันทึก"),
          ),
        ],
      ),
    );

    qtyController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการที่ต้องซื้อ'),
        actions: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _listFuture,
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              return IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'คัดลอกรายการ',
                onPressed: items.isEmpty ? null : () => _copyList(items),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _listFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'ตอนนี้ไม่มีสินค้าที่ต้องซื้อเพิ่ม',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final supplier = item['supplier_name'];

              return ListTile(
                title: Text(
                  item['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'เหลือ ${item['stock_qty']} (ขั้นต่ำ ${item['min_qty']})'
                  '${supplier != null ? '\nซื้อที่: $supplier' : ''}',
                ),
                isThreeLine: supplier != null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ซื้อ ${_suggestedQty(item)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      tooltip: 'ซื้อแล้ว',
                      onPressed: () => _showReceiveDialog(item),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
