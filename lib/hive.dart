import 'package:hive_flutter/hive_flutter.dart';

class MyPrefs {
  static late Box _box;

  /// 📦 التهيئة - لازم تتنادى قبل أي استخدام (زي الأول بالضبط)
  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('app_prefs');
  }

  /// 📝 حفظ قيمة نصية
  static Future<void> setString(String key, String value) async {
    await _box.put(key, value);
  }

  /// 📖 قراءة قيمة نصية
  static String? getString(String key) {
    final value = _box.get(key);
    if (value is String) {
      return value;
    }
    return null;
  }

  /// ❌ حذف قيمة معينة
  static Future<void> remove(String key) async {
    await _box.delete(key);
  }

  /// 🧹 حذف كل البيانات
  static Future<void> clear() async {
    await _box.clear();
  }

}
