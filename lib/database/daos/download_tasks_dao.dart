import 'package:yamata_launcher/database/db_stores.dart';
import 'package:yamata_launcher/models/download_info.dart';
import 'package:yamata_launcher/models/download_task.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:sembast/sembast.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class DownloadTasksDao {
  final Database db;
  DownloadTasksDao(this.db);

  String _getKey(DownloadInfo download) => StringHelper.hash20(
      download.romSlug + (download.sourceExtractableUrl ?? ''));

  Future<DownloadTask?> get(DownloadInfo download) async {
    final records = await downloadTaskDbStore.record(_getKey(download)).get(db);
    if (records == null) {
      return null;
    }
    return DownloadTask.fromJson(records);
  }

  Future<List<DownloadTask>> getAll() async {
    final records = await downloadTaskDbStore.find(db);
    return records.map((e) => DownloadTask.fromJson(e.value)).toList();
  }

  Future<Map<String, Object?>?> updateDownloadInfo(
      DownloadInfo download) async {
    final task = await get(download);
    if (task == null) {
      return null;
    }
    final updatedTask = DownloadTask(
      slug: task.slug,
      sourceRom: task.sourceRom,
      download: download,
    );
    return await update(updatedTask);
  }

  Future<String?> insert(DownloadTask item) async {
    return await downloadTaskDbStore
        .record(_getKey(item.download))
        .add(db, item.toJson());
  }

  Future<Map<String, Object?>?> update(DownloadTask item) async {
    return await downloadTaskDbStore
        .record(_getKey(item.download))
        .update(db, item.toJson());
  }

  Future<String?> delete(DownloadInfo download) async {
    final records =
        await downloadTaskDbStore.record(_getKey(download)).delete(db);
    return records;
  }

  Future<void> clear() async {
    await downloadTaskDbStore.delete(db);
  }
}
