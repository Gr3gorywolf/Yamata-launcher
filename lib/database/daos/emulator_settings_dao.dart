import 'package:yamata_launcher/database/db_stores.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:sembast/sembast.dart';

class EmulatorSettingsDao {
  final Database db;
  EmulatorSettingsDao(this.db);

  Future<EmulatorSetting?> get(String slug) async {
    final records = await emulatorSettingDbStore.record(slug).get(db);
    if (records == null) {
      return null;
    }
    return EmulatorSetting.fromJson(records);
  }

  Future<List<EmulatorSetting>> getAll() async {
    final records = await emulatorSettingDbStore.find(db);
    return records.map((e) => EmulatorSetting.fromJson(e.value)).toList();
  }

  Future<String?> insert(EmulatorSetting item) async {
    return await emulatorSettingDbStore
        .record(item.console)
        .add(db, item.toJson());
  }

  Future<Map<String, Object?>?> update(EmulatorSetting item) async {
    return await emulatorSettingDbStore
        .record(item.console)
        .update(db, item.toJson());
  }

  Future<String?> delete(String console) async {
    final records = await emulatorSettingDbStore.record(console).delete(db);
    return records;
  }
}
