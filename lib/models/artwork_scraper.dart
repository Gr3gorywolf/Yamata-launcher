enum ArtworkProviders {
  LAUNCHBOX("Launchbox gamedb"),
  TGDB("TheGamesDB"),
  SCREENSCRAPER("ScreenScraper (Needs credentials)"),
  SGDB("Steam GridDB (Needs API key)");

  final String value;
  const ArtworkProviders(this.value);
}

class ArtworkScraper {
  String name;
  String refUrl;
  String icon;
  bool requiresAuth;
  ArtworkProviders type;
  ArtworkScraper(
      {required this.name,
      required this.requiresAuth,
      required this.refUrl,
      required this.icon,
      required this.type});
}
