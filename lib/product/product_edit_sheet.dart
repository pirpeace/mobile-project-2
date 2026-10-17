import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../helper/db_helper.dart';
import '../helper/image_helper.dart';
import 'product_image.dart';

/// เปิดหน้าแก้ไขสินค้า คืนค่า true ถ้ามีการบันทึกหรือลบ (ให้หน้ารายการโหลดใหม่)
Future<bool> showProductEditSheet(
  BuildContext context,
  Map<String, dynamic> product,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _ProductEditSheet(product: product),
  );
  return result ?? false;
}

class _ProductEditSheet extends StatefulWidget {
  final Map<String, dynamic> product;

  const _ProductEditSheet({required this.product});

  @override
  State<_ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends State<_ProductEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _minController;
  late final String? _originalImageFile;

  List<Map<String, dynamic>> _categories = [];
  int? _categoryId;
  String? _imageFile;

  // รูปที่ถ่าย/เลือกใหม่ในหน้านี้ (ถ้ายกเลิกจะลบทิ้ง)
  final List<String> _newFiles = [];
  bool _finished = false;
  bool _saving = false;
  bool _labelCleared = false;

  String get _barcode => widget.product['barcode'].toString();

  bool get _wasOutdated => (widget.product['label_outdated'] ?? 0) == 1;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p['name']?.toString());
    _priceController = TextEditingController(text: p['price']?.toString());
    _stockController = TextEditingController(
      text: (p['stock_qty'] ?? 0).toString(),
    );
    _minController = TextEditingController(
      text: (p['min_qty'] ?? 0).toString(),
    );
    _categoryId = p['category_id'] as int?;
    _imageFile = p['image_file']?.toString();
    _originalImageFile = _imageFile;
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _minController.dispose();

    if (!_finished) {
      for (final file in _newFiles) {
        ImageHelper.delete(file);
      }
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await DBHelper.getCategories();
    if (!mounted) return;
    setState(() => _categories = categories);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showPhotoOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกจากแกลเลอรี'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (_imageFile != null)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('ลบรูป'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    switch (action) {
      case 'camera':
        await _pick(ImageSource.camera);
        break;
      case 'gallery':
        await _pick(ImageSource.gallery);
        break;
      case 'remove':
        setState(() => _imageFile = null);
        break;
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final fileName = await ImageHelper.pickAndSave(_barcode, source);
      if (fileName == null || !mounted) return;
      setState(() {
        _newFiles.add(fileName);
        _imageFile = fileName;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('ไม่สามารถเลือกรูปได้: $e');
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());

    if (name.isEmpty || price == null) {
      _showSnack('กรุณากรอกชื่อและราคาให้ถูกต้อง');
      return;
    }

    setState(() => _saving = true);

    try {
      await DBHelper.updateProduct(_barcode, name, price);
      await DBHelper.updateStockSettings(
        _barcode,
        stockQty: int.tryParse(_stockController.text.trim()) ?? 0,
        minQty: int.tryParse(_minController.text.trim()) ?? 0,
        categoryId: _categoryId,
      );
      await DBHelper.updateProductImage(_barcode, _imageFile);
      if (_labelCleared) {
        await DBHelper.markLabelUpdated(_barcode);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('บันทึกไม่สำเร็จ: $e');
      return;
    }

    // ลบไฟล์รูปที่ไม่ได้ใช้แล้ว
    for (final file in _newFiles) {
      if (file != _imageFile) {
        await ImageHelper.delete(file);
      }
    }
    if (_originalImageFile != null && _originalImageFile != _imageFile) {
      await ImageHelper.delete(_originalImageFile);
    }

    _finished = true;
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final name = _nameController.text.trim().isEmpty
        ? (widget.product['name']?.toString() ?? '')
        : _nameController.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text("คุณต้องการลบรายการ '$name' หรือไม่?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await DBHelper.deleteProduct(_barcode);
    for (final file in _newFiles) {
      await ImageHelper.delete(file);
    }
    await ImageHelper.delete(_originalImageFile);

    _finished = true;
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: GestureDetector(
              onTap: _showPhotoOptions,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: ProductImage(
                      imageFile: _imageFile,
                      width: 160,
                      height: 160,
                      iconSize: 48,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: cs.primary,
                      child: Icon(
                        Icons.photo_camera,
                        size: 20,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'แตะที่รูปเพื่อถ่ายหรือเปลี่ยนรูป',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'บาร์โค้ด: $_barcode',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'ชื่อสินค้า',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'ราคาขาย (บาท)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.sell_outlined),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _stockController,
                  decoration: const InputDecoration(
                    labelText: 'คงเหลือ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _minController,
                  decoration: const InputDecoration(
                    labelText: 'ขั้นต่ำ (เตือนซื้อ)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'หมวดหมู่',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in _categories)
                ChoiceChip(
                  label: Text(c['name']?.toString() ?? ''),
                  selected: _categoryId == c['id'],
                  onSelected: (_) =>
                      setState(() => _categoryId = c['id'] as int),
                ),
            ],
          ),
          if (_wasOutdated) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('เปลี่ยนป้ายราคาที่ชั้นแล้ว'),
              subtitle: const Text('ป้ายราคาของสินค้านี้ยังไม่ได้อัปเดต'),
              value: _labelCleared,
              onChanged: (v) => setState(() => _labelCleared = v),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('บันทึก'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _saving ? null : _delete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบสินค้านี้'),
            style: TextButton.styleFrom(foregroundColor: cs.error),
          ),
        ],
      ),
    );
  }
}
