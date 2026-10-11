import 'package:flutter/material.dart';
import '../helper/db_helper.dart';
import '../shopping/shopping_list_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Map<String, dynamic>>> _productListFuture;

  @override
  void initState() {
    super.initState();
    _refreshProductList();
  }

  // ฟังก์ชันรีโหลดข้อมูลสินค้าใหม่จาก Database
  void _refreshProductList() {
    setState(() {
      _productListFuture = DBHelper.getAllProducts();
    });
  }

  void _openShoppingList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ShoppingListScreen()),
    ).then((_) => _refreshProductList());
  }

  // Dialog แก้ไขข้อมูลสินค้า (ชื่อ, ราคา, จำนวนคงเหลือ, ขั้นต่ำ, หมวดหมู่)
  Future<void> _showEditProductDialog(Map<String, dynamic> product) async {
    final categories = await DBHelper.getCategories();
    if (!mounted) return;

    final nameController = TextEditingController(text: product['name']);
    final priceController = TextEditingController(
      text: product['price'].toString(),
    );
    final stockController = TextEditingController(
      text: (product['stock_qty'] ?? 0).toString(),
    );
    final minController = TextEditingController(
      text: (product['min_qty'] ?? 0).toString(),
    );
    int? selectedCategory = product['category_id'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text("แก้ไขสินค้า (${product['barcode']})"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "ชื่อสินค้า"),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: "ราคาขาย (บาท)"),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: stockController,
                  decoration: const InputDecoration(labelText: "จำนวนคงเหลือ"),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: minController,
                  decoration: const InputDecoration(
                    labelText: "จำนวนขั้นต่ำ (ต่ำกว่านี้ให้เตือนซื้อ)",
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: "หมวดหมู่"),
                  items: categories
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: c['id'] as int,
                          child: Text(c['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocalState(() => selectedCategory = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ยกเลิก"),
            ),
            ElevatedButton(
              onPressed: () async {
                final price = double.tryParse(priceController.text);
                if (nameController.text.isNotEmpty && price != null) {
                  await DBHelper.updateProduct(
                    product['barcode'],
                    nameController.text,
                    price,
                  );
                  await DBHelper.updateStockSettings(
                    product['barcode'],
                    stockQty: int.tryParse(stockController.text) ?? 0,
                    minQty: int.tryParse(minController.text) ?? 0,
                    categoryId: selectedCategory,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  _refreshProductList(); // รีโหลดข้อมูลหน้าจอ
                }
              },
              child: const Text("บันทึก"),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog ยืนยันการลบสินค้า
  void _confirmDelete(String barcode, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ยืนยันการลบ"),
        content: Text("คุณต้องการลบรายการ '$name' หรือไม่?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await DBHelper.deleteProduct(barcode);
              if (!mounted) return;
              Navigator.pop(context);
              _refreshProductList(); // รีโหลดข้อมูลหน้าจอ
            },
            child: const Text("ลบ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการสินค้าทั้งหมด'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_checkout),
            tooltip: 'รายการที่ต้องซื้อ',
            onPressed: _openShoppingList,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _productListFuture,
        builder: (context, snapshot) {
          // 1. กำลังโหลดข้อมูลจาก Database
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. เกิดข้อผิดพลาดในการดึงข้อมูล
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'เกิดข้อผิดพลาด: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // 3. กรณีไม่มีข้อมูลสินค้าเลย
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ยังไม่มีข้อมูลสินค้าในระบบ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'กลับไปหน้าสแกนเพื่อเพิ่มสินค้าชิ้นแรกของคุณ',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // 4. กรณีมีข้อมูลสินค้าใน Database
          final products = snapshot.data!;

          return ListView.separated(
            itemCount: products.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = products[index];
              final bool labelOutdated = (item['label_outdated'] ?? 0) == 1;
              final int stock = item['stock_qty'] ?? 0;
              final int min = item['min_qty'] ?? 0;
              final bool lowStock = min > 0 && stock <= min;

              return ListTile(
                isThreeLine: true,
                leading: CircleAvatar(
                  backgroundColor: Colors.blueAccent.shade100,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
                title: Text(
                  item['name'] ?? 'ไม่มีชื่อสินค้า',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('บาร์โค้ด: ${item['barcode']}'),
                    Text(
                      '${item['category_name'] ?? '-'} | คงเหลือ $stock'
                      '${lowStock ? ' (ใกล้หมด!)' : ''}',
                      style: TextStyle(
                        color: lowStock ? Colors.red : Colors.black54,
                        fontWeight: lowStock
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (labelOutdated)
                      InkWell(
                        onTap: () async {
                          await DBHelper.markLabelUpdated(item['barcode']);
                          _refreshProductList();
                        },
                        child: const Text(
                          'ป้ายราคายังไม่อัปเดต (แตะเมื่อเปลี่ยนป้ายแล้ว)',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '฿${item['price']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => _showEditProductDialog(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _confirmDelete(item['barcode'], item['name'] ?? ''),
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
