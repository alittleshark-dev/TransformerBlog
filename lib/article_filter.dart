import 'models.dart';

/// 按关键词、标签、归档月份筛选文章，条件为空表示不筛选。
List<Article> filterArticles(
  List<Article> articles, {
  String query = '',
  String? tag,
  String? archive,
}) {
  final String keyword = query.trim().toLowerCase();
  return articles.where((Article article) {
    if (tag != null && !article.tags.contains(tag)) return false;
    if (archive != null && !article.date.startsWith(archive)) return false;
    if (keyword.isEmpty) return true;
    return article.title.toLowerCase().contains(keyword) ||
        article.summary.toLowerCase().contains(keyword) ||
        article.content.toLowerCase().contains(keyword) ||
        article.tags.any((String item) => item.toLowerCase().contains(keyword));
  }).toList();
}

/// 统计每个标签的文章数，按数量降序、同数量按名称升序。
Map<String, int> countTags(List<Article> articles) {
  final Map<String, int> counts = <String, int>{};
  for (final Article article in articles) {
    for (final String tag in article.tags) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  final List<String> names = counts.keys.toList()
    ..sort((String a, String b) {
      final int byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return <String, int>{for (final String name in names) name: counts[name]!};
}

/// 按 yyyy-MM 分组，月份倒序。
Map<String, List<Article>> groupByArchive(List<Article> articles) {
  final Map<String, List<Article>> groups = <String, List<Article>>{};
  for (final Article article in articles) {
    final String key = article.date.length >= 7
        ? article.date.substring(0, 7)
        : '未知时间';
    groups.putIfAbsent(key, () => <Article>[]).add(article);
  }
  final List<String> keys = groups.keys.toList()
    ..sort((String a, String b) => b.compareTo(a));
  return <String, List<Article>>{
    for (final String key in keys) key: groups[key]!,
  };
}
