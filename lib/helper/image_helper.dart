import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// จัดการรูปสินค้า: เลือก/ถ่ายรูป แล้วคัดลอกเก็บไว้ในโฟลเดอร์ของแอป
///
/// ในฐานข้อมูลเก็บเฉพาะ "ชื่อไฟล์" (ไม่เก็บ path เต็ม)
/// เพราะบน iOS path ของโฟลเดอร์แอปอาจเปลี่ยนหลังอัปเดตแอป
class ImageHelper {
  static final ImagePicker _picker = ImagePicker();
  static late Directory _dir;

  /// ต้องเรียกครั้งเดียวใน main() ก่อน runApp
  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _dir = Directory(p.join(docs.path, 'product_images'));
    if (!await _dir.exists()) {
      await _dir.create(recursive: true);
    }
  }

  /// แปลงชื่อไฟล์ที่เก็บในฐานข้อมูลเป็น File จริง
  static File? fileFor(String? fileName) {
    if (fileName == null || fileName.isEmpty) return null;
    return File(p.join(_dir.path, fileName));
  }

  /// เลือกหรือถ่ายรูป แล้วบันทึกลงโฟลเดอร์ของแอป
  /// คืนค่าเป็นชื่อไฟล์ หรือ null ถ้าผู้ใช้ยกเลิก
  static Future<String?> pickAndSave(
    String barcode,
    ImageSource source,
  ) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (picked == null) return null;

    final fileName = '${barcode}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(picked.path).copy(p.join(_dir.path, fileName));
    return fileName;
  }

  static Future<void> delete(String? fileName) async {
    final file = fileFor(fileName);
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // ลบไม่สำเร็จไม่เป็นไร ไฟล์ที่ค้างไม่กระทบการทำงาน
    }
  }
}
