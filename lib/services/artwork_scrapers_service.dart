import 'package:yamata_launcher/models/artwork_scraper.dart';
import 'package:yamata_launcher/services/credentials_service.dart';

class ArtworkScrapersService {
  static final List<ArtworkScraper> configurableScrapers = [
    ArtworkScraper(
      name: "Steam GridDB",
      requiresAuth: true,
      refUrl: "https://www.steamgriddb.com",
      icon: "https://avatars.githubusercontent.com/u/48405094",
      type: ArtworkProviders.SGDB,
    ),
  ];

  static Future<String?> getCredentials(ArtworkScraper artworkScraper) {
    return CredentialsService.getCredentials(artworkScraper.type.name);
  }

  static Future<bool> saveCredentials(
    ArtworkScraper artworkScraper,
    String credentials,
  ) {
    return CredentialsService.saveCredentials(
      artworkScraper.type.name,
      credentials,
    );
  }

  static Future<void> removeCredentials(ArtworkScraper artworkScraper) {
    return CredentialsService.removeCredentials(artworkScraper.type.name);
  }
}
