import 'package:web/web.dart' as web;

/// 把浏览器标签页上的图标换掉。
///
/// 做法是把 index.html 里原有的 `<link rel="icon">` 全部摘掉，再插一个新的。
/// [url] 为空时还原成默认的 favicon.png。
void setFavicon(String url) {
  final web.Element head = web.document.head ?? web.document.documentElement!;

  // 先清掉已有的 icon 声明，不然会残留多个，浏览器挑哪个不确定
  final web.NodeList existing =
      web.document.querySelectorAll('link[rel*="icon"]');
  for (int i = existing.length - 1; i >= 0; i--) {
    final web.Node? node = existing.item(i);
    node?.parentNode?.removeChild(node);
  }

  final web.HTMLLinkElement link =
      web.document.createElement('link') as web.HTMLLinkElement;
  link.rel = 'icon';
  link.href = url.isEmpty ? 'favicon.png' : url;
  head.appendChild(link);
}

/// 把浏览器标签页上的标题换掉。
///
/// MaterialApp 的 `title` 只在它自己的值变化时才写一次 document.title，
/// 所以这里改完不会被它覆盖回去。
void setDocumentTitle(String title) {
  web.document.title = title;
}
