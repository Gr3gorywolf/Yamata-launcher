import 'package:yamata_launcher/database/db_stores.dart';
import 'package:yamata_launcher/models/custom_download_path.dart';
import 'package:sembast/sembast.dart';

class CustomPathDao {
  final Database db;
  CustomPathDao(this.db);

  Stream<RecordSnapshot<String, Map<String, Object?>>?> getSubscription() {
    return customPathDbStore.query().onSnapshot(db);
  }

  Future<CustomDownloadPath?> get(String consoleSlug) async {
    final records = await customPathDbStore.record(consoleSlug).get(db);
    if (records == null) {
      return null;
    }
    return CustomDownloadPath.fromJson(records);
  }

  Future<List<CustomDownloadPath>> getAll() async {
    final records = await customPathDbStore.find(db);
    return records.map((e) => CustomDownloadPath.fromJson(e.value)).toList();
  }

  Future<String?> insert(CustomDownloadPath item) async {
    return await customPathDbStore.record(item.console).add(db, item.toJson());
  }

  Future<Map<String, Object?>?> update(CustomDownloadPath item) async {
    return await customPathDbStore
        .record(item.console)
        .update(db, item.toJson());
  }

  Future<String?> delete(String consoleSlug) async {
    final records = await customPathDbStore.record(consoleSlug).delete(db);
    return records;
  }
}
