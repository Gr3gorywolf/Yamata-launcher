import 'package:yamata_launcher/utils/string_helper.dart';

class SearchResult {
  final String item;
  final int score;

  const SearchResult(this.item, this.score);
}

class PlainTextSearch {
  /// Performs a plain-text search over [items] using [query].
  ///

  static bool matches(String query, String text) {
    final queryTokens = query.tokensForSearch();
    if (queryTokens.isEmpty) return false;

    return _matchElement(queryTokens, text).$1;
  }

  static (bool, int) _matchElement(
    List<String> queryTokens,
    String element, {
    int minConsecutiveLength = 6,
    bool requireAllTokens = true,
  }) {
    final normalizedItem = element.normalizeForSearch();
    if (normalizedItem.isEmpty) return (false, 0);

    final itemTokens =
        normalizedItem.split(' ').where((t) => t.isNotEmpty).toList();

    final matchData = _matchTokens(
      queryTokens: queryTokens,
      itemNormalized: normalizedItem,
      itemTokens: itemTokens,
      minConsecutiveLength: minConsecutiveLength,
      requireAllTokens: requireAllTokens,
    );

    return matchData;
  }

  static List<SearchResult> search(
    String query,
    List<String> items, {
    int minConsecutiveLength = 6,
    bool requireAllTokens = true,
  }) {
    final queryTokens = query.tokensForSearch();
    if (queryTokens.isEmpty) return const [];

    final results = <SearchResult>[];

    for (final item in items) {
      final matchData = _matchElement(queryTokens, item,
          minConsecutiveLength: minConsecutiveLength,
          requireAllTokens: requireAllTokens);
      if (matchData.$1) {
        results.add(SearchResult(item, matchData.$2));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Returns (matches, score).
  /// The score is used to sort results by relevance.
  static (bool, int) _matchTokens({
    required List<String> queryTokens,
    required String itemNormalized,
    required List<String> itemTokens,
    required int minConsecutiveLength,
    required bool requireAllTokens,
  }) {
    int score = 0;
    int matched = 0;

    for (final q in queryTokens) {
      bool tokenMatched = false;

      // Primary match: query token exists in the normalized full text.
      if (itemNormalized.contains(q)) {
        tokenMatched = true;
        matched++;

        score += 10; // base match score

        // Bonus: exact token exists as a standalone word.
        if (itemTokens.contains(q)) score += 10;

        // Bonus: token appears at the start of a word.
        if (RegExp(r'(^|\s)' + RegExp.escape(q)).hasMatch(itemNormalized)) {
          score += 6;
        }
      } else {
        // Fallback: consecutive match between query token and any item token
        // (helps with partial inputs / small typos).
        for (final it in itemTokens) {
          if (StringHelper.hasMinConsecutiveMatch(
            q,
            it,
            minLength: minConsecutiveLength,
          )) {
            tokenMatched = true;
            matched++;
            score += 6;
            break;
          }
        }
      }

      // If required, every query token must match.
      if (!tokenMatched && requireAllTokens) {
        return (false, 0);
      }
    }

    // Slight penalty for very long items with few matches.
    score -= (itemTokens.length ~/ 10);

    // Bonus if all query tokens matched.
    if (matched == queryTokens.length) score += 10;

    // Bonus for early match (looks more relevant to users).
    final firstIndex = itemNormalized.indexOf(queryTokens.first);
    if (firstIndex == 0) score += 10;
    if (firstIndex > 0 && firstIndex < 10) score += 5;

    return (matched > 0, score);
  }
}
