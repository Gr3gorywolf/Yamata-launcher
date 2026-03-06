import 'package:sembast/sembast.dart';
import 'package:yamata_launcher/database/db_stores.dart';
import 'package:yamata_launcher/models/download_history_item.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class DownloadHistoryDao {
  final Database db;
  DownloadHistoryDao(this.db);

  Future<DownloadHistoryItem?> get(String slug) async {
    final records = await downloadHistoryDbStore.record(slug).get(db);
    if (records == null) {
      return null;
    }
    return DownloadHistoryItem.fromJson(records);
  }

  Future<List<DownloadHistoryItem>> getLatests() async {
    var finder = Finder(
      sortOrders: [SortOrder('downloadedAt', false)],
      limit: 200,
    );
    final records = await downloadHistoryDbStore.find(db, finder: finder);
    return records.map((e) => DownloadHistoryItem.fromJson(e.value)).toList();
  }

  Future<String?> insert(DownloadHistoryItem item) async {
    return await downloadHistoryDbStore
        .record(item.downloadId ?? StringHelper.generateUUID())
        .add(db, item.toJson());
  }

  Future<String?> update(DownloadHistoryItem item) async {
    await downloadHistoryDbStore
        .record(item.downloadId ?? StringHelper.generateUUID())
        .update(db, item.toJson());
    return null;
  }
}
