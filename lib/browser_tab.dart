/// 改浏览器标签页上的图标和标题。
///
/// 只有 Web 能改 DOM，其他平台是空实现，所以这里按平台条件导出。
library;

export 'browser_tab_stub.dart'
    if (dart.library.js_interop) 'browser_tab_web.dart';
