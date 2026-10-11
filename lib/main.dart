import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'helper/db_helper.dart';
import 'product/product_list_screen.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PriceScannerScreen(),
    ),
  );
}

class PriceScannerScreen extends StatefulWidget {
  const PriceScannerScreen({super.key});

  @override
  State<PriceScannerScreen> createState() => _PriceScannerScreenState();
}

class _PriceScannerScreenState extends State<PriceScannerScreen> {
  // 1. เพิ่ม MobileScannerController เข้ามาจัดการกล้อง
  final MobileScannerController controller = MobileScannerController(
    autoStart: false,
  );
  bool isScanning = true;

  @override
  void initState() {
    super.initState();
    controller.start();
  }

  @override
  void dispose() {
    controller.dispose(); // คืนทรัพยากรเมื่อปิดหน้าจอ
    super.dispose();
  }

  // ฟังก์ชันกลับมาสแกนต่อ (สั่งปิด Dialog + เปิดกล้องใหม่)
  void _resumeScanning() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    setState(() => isScanning = true);
    controller.start();
  }

  // ฟังก์ชันสำหรับเปิดไปยังหน้าจัดการรายการสินค้า
  void _openProductList() {
    controller.stop(); // หยุดกล้องชั่วคราวขณะสลับหน้า
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProductListScreen()),
    ).then((_) {
      setState(() => isScanning = true);
      controller.start(); // สั่งกล้องทำงานต่อเมื่อกลับมา
    });
  }

  // ฟังก์ชันเมื่อสแกนเจอบาร์โค้ด
  void _onDetect(BarcodeCapture capture) async {
    if (!isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String barcode = barcodes.first.rawValue!;

      setState(() => isScanning = false);
      controller.stop(); // หยุดกล้องชั่วคราวระหว่างโชว์ Dialog

      // ค้นหาข้อมูลใน DB
      final product = await DBHelper.getProduct(barcode);

      if (!mounted) return;

      if (product != null) {
        _showPriceDialog(product['name'], product['price'].toString());
      } else {
        _showAddProductDialog(barcode);
      }
    }
  }

  // Dialog แสดงราคาขาย
  void _showPriceDialog(String name, String price) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: Column(
          children: [
            const Text(
              "ราคาขาย",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              "฿$price",
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: _resumeScanning, // ใช้ฟังก์ชันเพื่อเริ่มสแกนต่อ
            child: const Text("ตกลง / สแกนชิ้นต่อไป"),
          ),
        ],
      ),
    );
  }

  // Dialog บันทึกสินค้าใหม่
  void _showAddProductDialog(String barcode) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text("ไม่พบสินค้า ($barcode)"),
        content: Column(
          children: [
            const Text("กรอกข้อมูลเพื่อบันทึกราคาไว้ใช้ครั้งถัดไป"),
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
          ],
        ),
        actions: [
          TextButton(onPressed: _resumeScanning, child: const Text("ยกเลิก")),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(priceController.text);
              if (nameController.text.isNotEmpty && price != null) {
                await DBHelper.insertOrUpdateProduct(
                  barcode,
                  nameController.text,
                  price,
                );
                if (!mounted) return;
                _resumeScanning();
              }
            },
            child: const Text("บันทึก"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สแกนเช็คราคาด่วน'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'รายการสินค้า',
            onPressed: _openProductList,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openProductList,
        icon: const Icon(Icons.list),
        label: const Text('จัดการสินค้า'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Stack(
        children: [
          // 2. ผูก controller เข้ากับ MobileScanner
          MobileScanner(controller: controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'ส่องบาร์โค้ดให้อยู่ในกรอบเพื่อเช็คราคา',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
