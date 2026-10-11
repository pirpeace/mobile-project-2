import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;
  static const int _dbVersion = 2;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  static Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'grocery_price.db');
    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // เปิดใช้ Foreign Key (SQLite ปิดไว้เป็นค่าเริ่มต้น)
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ---------------------------------------------------------------
  // สร้างฐานข้อมูลใหม่ (ติดตั้งครั้งแรก)
  // ---------------------------------------------------------------
  static Future<void> _onCreate(Database db, int version) async {
    await _createCategoriesAndSuppliers(db);

    await db.execute('''
      CREATE TABLE products(
        barcode TEXT PRIMARY KEY,
        name TEXT,
        price REAL,
        cost REAL DEFAULT 0,
        stock_qty INTEGER DEFAULT 0,
        min_qty INTEGER DEFAULT 0,
        category_id INTEGER,
        supplier_id INTEGER,
        label_outdated INTEGER DEFAULT 0,
        last_checked TEXT,
        FOREIGN KEY(category_id) REFERENCES categories(id),
        FOREIGN KEY(supplier_id) REFERENCES suppliers(id)
      )
    ''');

    await _createExtraTables(db);
    await _seedCategories(db);

    // สินค้าตัวอย่าง
    await db.insert('products', {
      'barcode': '8853042000963',
      'name': 'ยาทาแผลสด โพวิโดน-ไอโอดีน (ตราเสือดาว)',
      'price': 15.0,
      'category_id': 1,
    });
    await db.insert('products', {
      'barcode': '8853593004328',
      'name': 'ยาทาแผลสด',
      'price': 20.0,
      'category_id': 1,
    });
  }

  // ---------------------------------------------------------------
  // อัปเกรดจาก v1 -> v2 (ข้อมูลสินค้าเดิมไม่หาย)
  // ---------------------------------------------------------------
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createCategoriesAndSuppliers(db);
      await _seedCategories(db);

      await db.execute('ALTER TABLE products ADD COLUMN cost REAL DEFAULT 0');
      await db.execute(
        'ALTER TABLE products ADD COLUMN stock_qty INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE products ADD COLUMN min_qty INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE products ADD COLUMN category_id INTEGER REFERENCES categories(id)',
      );
      await db.execute(
        'ALTER TABLE products ADD COLUMN supplier_id INTEGER REFERENCES suppliers(id)',
      );
      await db.execute(
        'ALTER TABLE products ADD COLUMN label_outdated INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE products ADD COLUMN last_checked TEXT');

      // สินค้าเดิมทั้งหมดให้อยู่หมวด "ทั่วไป"
      await db.execute('UPDATE products SET category_id = 1');

      await _createExtraTables(db);
    }
  }

  static Future<void> _createCategoriesAndSuppliers(Database db) async {
    // หมวดหมู่ + ความถี่การเช็ค + บริษัทเติมให้เองหรือไม่
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        check_freq TEXT DEFAULT 'weekly', -- weekly / monthly / none
        auto_restock INTEGER DEFAULT 0    -- 1 = บริษัทเติมให้ ไม่ต้องเช็ค/สั่ง
      )
    ''');

    // ร้านที่ซื้อของ / ซัพพลายเออร์
    await db.execute('''
      CREATE TABLE suppliers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        line_id TEXT
      )
    ''');
  }

  static Future<void> _createExtraTables(Database db) async {
    // ล็อตสินค้าตามวันหมดอายุ
    await db.execute('''
      CREATE TABLE batches(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT NOT NULL,
        expiry_date TEXT NOT NULL, -- รูปแบบ yyyy-MM-dd
        qty INTEGER NOT NULL,
        FOREIGN KEY(barcode) REFERENCES products(barcode) ON DELETE CASCADE
      )
    ''');

    // ประวัติการเปลี่ยนราคา
    await db.execute('''
      CREATE TABLE price_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT NOT NULL,
        old_price REAL,
        new_price REAL,
        changed_at TEXT,
        FOREIGN KEY(barcode) REFERENCES products(barcode) ON DELETE CASCADE
      )
    ''');

    // บันทึกของที่ทิ้ง / เสียหาย
    await db.execute('''
      CREATE TABLE waste_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT NOT NULL,
        qty INTEGER NOT NULL,
        reason TEXT,
        cost_lost REAL DEFAULT 0,
        created_at TEXT,
        FOREIGN KEY(barcode) REFERENCES products(barcode) ON DELETE CASCADE
      )
    ''');

    // คำขอจากลูกค้า (ของที่ลูกค้าถามหาแต่ร้านไม่มี)
    await db.execute('''
      CREATE TABLE customer_requests(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_name TEXT NOT NULL,
        created_at TEXT
      )
    ''');
  }

  static Future<void> _seedCategories(Database db) async {
    await db.insert('categories', {
      'id': 1,
      'name': 'ทั่วไป',
      'check_freq': 'weekly',
      'auto_restock': 0,
    });
    await db.insert('categories', {
      'id': 2,
      'name': 'เบียร์',
      'check_freq': 'weekly',
      'auto_restock': 0,
    });
    await db.insert('categories', {
      'id': 3,
      'name': 'ไอศกรีม',
      'check_freq': 'none',
      'auto_restock': 1, // บริษัทเติมให้
    });
    await db.insert('categories', {
      'id': 4,
      'name': 'ของใช้ (เช็ครายเดือน)',
      'check_freq': 'monthly',
      'auto_restock': 0,
    });
  }

  // ===============================================================
  // สินค้า
  // ===============================================================

  // 1. ค้นหาสินค้าจากบาร์โค้ด
  static Future<Map<String, dynamic>?> getProduct(String barcode) async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (result.isNotEmpty) return result.first;
    return null;
  }

  // 2. เพิ่มสินค้าใหม่ หรืออัปเดตชื่อ/ราคา (ไม่ทับข้อมูลสต็อกเดิม)
  static Future<void> insertOrUpdateProduct(
    String barcode,
    String name,
    double price,
  ) async {
    final db = await database;
    final existing = await getProduct(barcode);
    if (existing == null) {
      await db.insert('products', {
        'barcode': barcode,
        'name': name,
        'price': price,
        'category_id': 1,
      });
    } else {
      await updateProduct(barcode, name, price);
    }
  }

  // 3. ดึงรายการสินค้าทั้งหมด
  static Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      ORDER BY p.name ASC
    ''');
  }

  // 4. แก้ไขชื่อและราคา (ถ้าราคาเปลี่ยน -> บันทึกประวัติ + ตั้งสถานะป้ายยังไม่อัปเดต)
  static Future<int> updateProduct(
    String barcode,
    String name,
    double price,
  ) async {
    final db = await database;
    return await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        columns: ['price'],
        where: 'barcode = ?',
        whereArgs: [barcode],
      );

      final values = <String, Object?>{'name': name, 'price': price};

      if (rows.isNotEmpty) {
        final oldPrice = (rows.first['price'] as num?)?.toDouble();
        if (oldPrice != price) {
          await txn.insert('price_history', {
            'barcode': barcode,
            'old_price': oldPrice,
            'new_price': price,
            'changed_at': DateTime.now().toIso8601String(),
          });
          values['label_outdated'] = 1;
        }
      }

      return await txn.update(
        'products',
        values,
        where: 'barcode = ?',
        whereArgs: [barcode],
      );
    });
  }

  // 5. ลบสินค้าออกจากฐานข้อมูล (ล็อต/ประวัติของสินค้านั้นถูกลบตาม)
  static Future<int> deleteProduct(String barcode) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
  }

  // ===============================================================
  // สต็อก
  // ===============================================================

  // ตั้งค่าจำนวนคงเหลือ / ขั้นต่ำ / หมวดหมู่
  static Future<int> updateStockSettings(
    String barcode, {
    required int stockQty,
    required int minQty,
    required int? categoryId,
  }) async {
    final db = await database;
    return await db.update(
      'products',
      {
        'stock_qty': stockQty,
        'min_qty': minQty,
        'category_id': categoryId,
        'last_checked': DateTime.now().toIso8601String(),
      },
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
  }

  // รับของเข้า (เพิ่มจำนวนคงเหลือ)
  static Future<void> addStock(String barcode, int qty) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE products SET stock_qty = stock_qty + ?, last_checked = ? WHERE barcode = ?',
      [qty, DateTime.now().toIso8601String(), barcode],
    );
  }

  // รายการที่ต้องซื้อ: เหลือ <= ขั้นต่ำ และไม่ใช่หมวดที่บริษัทเติมให้
  static Future<List<Map<String, dynamic>>> getShoppingList() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, c.name AS category_name,
             s.name AS supplier_name, s.phone AS supplier_phone
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN suppliers s ON p.supplier_id = s.id
      WHERE p.min_qty > 0
        AND p.stock_qty <= p.min_qty
        AND COALESCE(c.auto_restock, 0) = 0
      ORDER BY s.name, p.name
    ''');
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories', orderBy: 'id ASC');
  }

  // ===============================================================
  // ป้ายราคา
  // ===============================================================

  // กดยืนยันว่าเปลี่ยนป้ายหน้าชั้นแล้ว
  static Future<void> markLabelUpdated(String barcode) async {
    final db = await database;
    await db.update(
      'products',
      {'label_outdated': 0},
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
  }

  static Future<List<Map<String, dynamic>>> getPriceHistory(
    String barcode,
  ) async {
    final db = await database;
    return await db.query(
      'price_history',
      where: 'barcode = ?',
      whereArgs: [barcode],
      orderBy: 'changed_at DESC',
    );
  }

  // ===============================================================
  // หมดอายุ / ของที่ทิ้ง / คำขอลูกค้า (ใช้ทำหน้าจอในระยะที่ 2)
  // ===============================================================

  static Future<void> addBatch(
    String barcode,
    DateTime expiry,
    int qty,
  ) async {
    final db = await database;
    final d = expiry.toIso8601String().substring(0, 10); // yyyy-MM-dd
    await db.insert('batches', {
      'barcode': barcode,
      'expiry_date': d,
      'qty': qty,
    });
  }

  // ล็อตที่หมดอายุภายใน [days] วัน (รวมที่หมดแล้ว)
  static Future<List<Map<String, dynamic>>> getExpiringBatches(
    int days,
  ) async {
    final db = await database;
    final cutoff = DateTime.now()
        .add(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);
    return await db.rawQuery(
      '''
      SELECT b.*, p.name
      FROM batches b
      JOIN products p ON b.barcode = p.barcode
      WHERE b.expiry_date <= ?
      ORDER BY b.expiry_date ASC
    ''',
      [cutoff],
    );
  }

  // บันทึกของที่ทิ้ง + ตัดสต็อก + คำนวณมูลค่าที่เสีย
  static Future<void> addWaste(String barcode, int qty, String reason) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        columns: ['cost'],
        where: 'barcode = ?',
        whereArgs: [barcode],
      );
      final cost = rows.isNotEmpty
          ? (rows.first['cost'] as num?)?.toDouble() ?? 0.0
          : 0.0;

      await txn.insert('waste_log', {
        'barcode': barcode,
        'qty': qty,
        'reason': reason,
        'cost_lost': cost * qty,
        'created_at': DateTime.now().toIso8601String(),
      });

      await txn.rawUpdate(
        'UPDATE products SET stock_qty = MAX(stock_qty - ?, 0) WHERE barcode = ?',
        [qty, barcode],
      );
    });
  }

  static Future<void> addCustomerRequest(String itemName) async {
    final db = await database;
    await db.insert('customer_requests', {
      'item_name': itemName,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // สินค้าที่ลูกค้าถามหาบ่อย (เรียงตามจำนวนครั้ง)
  static Future<List<Map<String, dynamic>>> getTopCustomerRequests() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT item_name, COUNT(*) AS times
      FROM customer_requests
      GROUP BY item_name
      ORDER BY times DESC
    ''');
  }
}
