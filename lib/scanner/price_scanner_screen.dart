import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../helper/db_helper.dart';
import '../product/product_image.dart';
import 'animated_scanner_overlay.dart';

class PriceScannerScreen extends StatefulWidget {
  const PriceScannerScreen({super.key});

  @override
  State<PriceScannerScreen> createState() => _PriceScannerScreenState();
}

class _PriceScannerScreenState extends State<PriceScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    torchEnabled: false,
  );

  bool _isScanning = true;
  bool _isDialogShowing = false;
  bool _isTorchOn = false;
  bool _isCameraReady = false;
  String _lastScanned = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _startCamera();
        break;
      case AppLifecycleState.paused:
        _controller.stop();
        break;
      default:
        break;
    }
  }

  Future<void> _startCamera() async {
    try {
      await _controller.start();
      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCameraReady = false);
        _showErrorSnackBar('ไม่สามารถเปิดกล้องได้: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resumeScanning() {
    if (_isDialogShowing && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    if (mounted) {
      setState(() {
        _isScanning = true;
        _isDialogShowing = false;
      });
      _startCamera();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_isScanning || _isDialogShowing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    final barcode = barcodes.first.rawValue!;
    await HapticFeedback.lightImpact();

    setState(() {
      _lastScanned = barcode;
      _isScanning = false;
      _isDialogShowing = true;
    });
    await _controller.stop();

    final product = await DBHelper.getProduct(barcode);
    if (!mounted) return;

    if (product != null) {
      _showPriceDialog(
        product['name']?.toString() ?? 'ไม่มีชื่อ',
        product['price']?.toString() ?? '0',
        product['image_file']?.toString(),
      );
    } else {
      _showAddProductDialog(barcode);
    }
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() => _isTorchOn = !_isTorchOn);
  }

  Future<void> _switchCamera() async {
    await _controller.switchCamera();
  }

  void _showPriceDialog(String name, String price, String? imageFile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageFile != null && imageFile.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ProductImage(
                  imageFile: imageFile,
                  width: 140,
                  height: 140,
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              "ราคาขาย",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              "฿$price",
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton.icon(
            onPressed: _resumeScanning,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text("สแกนต่อ"),
            style: FilledButton.styleFrom(
              minimumSize: const Size(160, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddProductDialog(String barcode) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "ไม่พบสินค้า",
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  barcode,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text("กรอกข้อมูลเพื่อบันทึกราคาไว้ใช้ครั้งถัดไป"),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "ชื่อสินค้า",
                  prefixIcon: Icon(Icons.label_outline),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: "ราคาขาย (บาท)",
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _resumeScanning,
            child: const Text("ยกเลิก"),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text.trim());

              if (name.isEmpty || price == null) {
                _showErrorSnackBar('กรุณากรอกชื่อและราคาให้ถูกต้อง');
                return;
              }

              await DBHelper.insertOrUpdateProduct(barcode, name, price);
              if (!mounted) return;
              _resumeScanning();
            },
            child: const Text("บันทึก"),
          ),
        ],
      ),
    );

    nameController.dispose();
    priceController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('สแกนเช็คราคา'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.yellow : Colors.white,
            ),
            tooltip: 'ไฟฉาย',
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            tooltip: 'สลับกล้อง',
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ScannerMaskPainter(
              frameWidth: 280,
              frameHeight: 180,
            ),
          ),
          Center(
            child: AnimatedScannerOverlay(
              width: 280,
              height: 180,
              borderColor: Colors.white.withOpacity(0.9),
              laserColor: Colors.redAccent,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5 + 110,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ส่องบาร์โค้ดให้อยู่ในกรอบเพื่อเช็คราคา',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!_isCameraReady)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'กำลังเปิดกล้อง...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          if (_lastScanned.isNotEmpty)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white.withOpacity(0.95),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.qr_code,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'สแกนล่าสุด',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _lastScanned,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerMaskPainter extends CustomPainter {
  final double frameWidth;
  final double frameHeight;

  _ScannerMaskPainter({
    required this.frameWidth,
    required this.frameHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameWidth,
      height: frameHeight,
    );

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final framePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          frameRect,
          const Radius.circular(12),
        ),
      );

    final maskPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      framePath,
    );

    canvas.drawPath(maskPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
