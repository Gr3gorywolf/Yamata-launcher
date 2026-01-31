import 'package:yamata_launcher/models/hltb.dart';
import 'package:yamata_launcher/models/launchbox.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/tgdb.dart';
import 'package:yamata_launcher/services/scrapers/metadata/hltb_scraper.dart';
import 'package:yamata_launcher/services/scrapers/metadata/launchbox_scraper.dart';
import 'package:yamata_launcher/services/scrapers/metadata/tgdb_scraper.dart';
import 'package:yamata_launcher/utils/cached_fetch.dart';

class RomDetailsRepository {
  Future<HltbEntry?> fetchHltbData(RomInfo rom) async {
    return await CachedFetch.object<HltbEntry>(
      key: "hltb_${rom.slug}",
      fetcher: () async {
        var scraper = HltbScraper();
        var results = await scraper.search(rom.name);
        if (results.isEmpty) {
          return null;
        }
        var result = results.first;
        var detail = await scraper.detail(result.id);
        return detail;
      },
      fromJson: (json) => HltbEntry.fromJson(json),
      ttl: Duration(days: 1),
    );
  }

  Future<TgdbGameDetail?> fetchTgdbData(RomInfo rom) async {
    return await CachedFetch.object<TgdbGameDetail>(
      key: "tgdb_${rom.slug}",
      fetcher: () async {
        var scraper = TheGamesDbScraper();
        var results = await scraper.search(rom.name, rom.console);
        if (results.isEmpty) {
          return null;
        }
        var result = results.first;
        var detail = await scraper.detail(result.id);
        return detail;
      },
      fromJson: (json) => TgdbGameDetail.fromJson(json),
      ttl: Duration(days: 1),
    );
  }

  Future<LaunchboxRomDetails?> fetchLaunchboxDetails(RomInfo rom) async {
    return await CachedFetch.object<LaunchboxRomDetails>(
      key: "launchbox_${rom.slug}",
      fetcher: () async {
        var scraper = LaunchboxScraper();
        var detail = await scraper.detail(rom.detailsUrl ?? "");
        return detail;
      },
      fromJson: (json) => LaunchboxRomDetails.fromJson(json),
      ttl: Duration(days: 1),
    );
  }
}
