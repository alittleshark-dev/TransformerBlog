import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:transformer_blog/app_settings.dart';
import 'package:transformer_blog/config_api.dart';
import 'package:transformer_blog/config_exporter.dart';
import 'package:transformer_blog/content_store.dart';
import 'package:transformer_blog/data_service.dart';
import 'package:transformer_blog/main.dart';
import 'package:transformer_blog/models.dart';
import 'package:transformer_blog/pages/article_editor_page.dart';
import 'package:transformer_blog/pages/article_manager_page.dart';
import 'package:transformer_blog/pages/export_page.dart';
import 'package:transformer_blog/pages/home_page.dart';
import 'package:transformer_blog/widgets/article_card.dart';

/// 假后端：记录前端到底往服务器写了什么，不真发请求。
class _RecordingApi extends ConfigApi {
  _RecordingApi({this.result = WriteResult.saved});

  /// 写入时假装服务端返回什么，用来测被拒绝的情况。
  final WriteResult result;

  /// 每次写入的记录，按顺序排列。
  final List<({String name, String content, String password})> writes =
      <({String name, String content, String password})>[];

  @override
  Future<String?> read(String name) async => null;

  @override
  Future<WriteResult> write(
    String name,
    String content, {
    required String password,
  }) async {
    writes.add((name: name, content: content, password: password));
    return result;
  }
}

/// 用假数据替换 assets 读取，让测试不依赖真实 JSON 文件。
class _FakeDataService extends DataService {
  const _FakeDataService({super.api});

  @override
  Future<Profile> loadProfile() async => const Profile(
    siteTitle: '测试站点',
    name: '测试用户',
    tagline: '一句话介绍',
    avatar: '',
    links: [
      ContactLink(label: 'Github', value: 'tester', url: 'https://example.com'),
    ],
    footer: '© 测试',
    editPassword: 'test-pass',
  );

  @override
  Future<List<Friend>> loadFriends() async => const [
    Friend(
      name: '测试好友',
      description: '欢迎！欢迎！',
      avatar: '',
      url: 'https://example.com',
    ),
  ];

  /// 7 篇：1-4 在 2026-09，5-7 在 2026-08；奇数带「技术」，偶数带「随笔」。
  /// 每页 5 篇，所以第 1 页是 文章 1-5，第 2 页是 文章 6-7。
  @override
  Future<List<Article>> loadArticles() async => <Article>[
    for (int i = 1; i <= 4; i++) _article(i, '2026-09-0${5 - i}'),
    for (int i = 5; i <= 7; i++) _article(i, '2026-08-0${8 - i}'),
  ];

  static Article _article(int index, String date) => Article(
    id: '$index',
    title: '文章 $index',
    summary: '简介 $index',
    date: date,
    content: '## 小标题\n\n正文内容 $index',
    tags: <String>[index.isEven ? '随笔' : '技术'],
  );
}

class _FailingDataService extends DataService {
  const _FailingDataService();

  @override
  Future<Profile> loadProfile() async {
    throw const FormatException('坏的 JSON');
  }
}

Future<void> _pumpHome(
  WidgetTester tester,
  DataService service, {
  AppSettings? settings,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(settings: settings ?? AppSettings(), dataService: service),
    ),
  );
  await tester.pumpAndSettle();
}

/// 进入编辑模式：点锁图标，输入正确密码。
Future<void> _enterEditMode(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.lock_outline));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    'test-pass',
  );
  await tester.tap(find.text('确定'));
  await tester.pumpAndSettle();
}

/// 切到宽屏尺寸，保证搜索框、标签、分页都在可视区域内。
Future<void> _useWideSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// 编辑模式下从顶栏进入文章管理页。
Future<void> _openArticleManager(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.edit_note));
  await tester.pumpAndSettle();
}

/// 编辑面板是个可滚动的 ListView，靠下的按钮得先滚出来才点得到。
Future<void> _tapInPanel(WidgetTester tester, String label) async {
  final Finder target = find.text(label);
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// 关掉编辑面板。它盖在顶栏上，不关就点不到那些图标。
Future<void> _closePanel(WidgetTester tester) async {
  tester.state<ScaffoldState>(find.byType(Scaffold)).closeEndDrawer();
  await tester.pumpAndSettle();
}

/// 按文件名取出导出结果并解析，免得测试依赖文件的排列顺序。
dynamic _jsonAt(List<ExportedFile> files, String name) {
  final ExportedFile file = files.firstWhere(
    (ExportedFile f) => f.name == name,
    orElse: () => throw StateError('导出结果里没有 $name'),
  );
  return jsonDecode(file.content);
}

/// 友链编辑对话框里的输入框，按顺序是：名称、描述、头像、链接。
Finder _friendDialogFields() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

/// 编辑器里的输入框，按顺序是：标题、日期、标签、摘要、正文。
Finder _editorFields() => find.descendant(
  of: find.byType(ArticleEditorPage),
  matching: find.byType(TextField),
);

/// 管理页里某一项的文字，避开首页上同名的文章卡片。
Finder _inManager(String text) => find.descendant(
  of: find.byType(ArticleManagerPage),
  matching: find.text(text),
);

/// 管理页里所有的删除按钮。
Finder _managerDeleteButtons() => find.descendant(
  of: find.byType(ArticleManagerPage),
  matching: find.byIcon(Icons.delete_outline),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('assets/data 下的真实 JSON 能正常解析', () async {
    const DataService service = DataService();
    final Profile profile = await service.loadProfile();
    final List<Friend> friends = await service.loadFriends();
    final List<Article> articles = await service.loadArticles();

    expect(profile.name, isNotEmpty);
    expect(friends, isNotEmpty);
    expect(articles, isNotEmpty);
    expect(articles.every((Article a) => a.id.isNotEmpty), isTrue);
    // 返回顺序应该是日期倒序
    for (int i = 1; i < articles.length; i++) {
      expect(articles[i - 1].date.compareTo(articles[i].date) >= 0, isTrue);
    }
  });

  testWidgets('窄屏下展示个人信息、友链与第一页文章', (WidgetTester tester) async {
    await _pumpHome(tester, const _FakeDataService());

    expect(find.text('测试用户'), findsOneWidget);
    expect(find.text('测试好友'), findsOneWidget);
    expect(find.text('文章 1'), findsOneWidget);
    // 第二页的文章不应该出现
    expect(find.text('文章 7'), findsNothing);
  });

  testWidgets('宽屏下同样展示文章列表', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());

    expect(find.text('测试用户'), findsOneWidget);
    expect(find.text('文章 1'), findsOneWidget);
  });

  testWidgets('点击文章卡片进入详情页并渲染 Markdown', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());

    await tester.tap(find.text('文章 1'));
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('2026-09-04'), findsOneWidget);
    expect(find.textContaining('正文内容 1', findRichText: true), findsOneWidget);
  });

  testWidgets('搜索可以过滤文章', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());

    await tester.enterText(find.byType(TextField), '文章 3');
    await tester.pumpAndSettle();

    // 搜索框里也有「文章 3」这段文字，所以按卡片来断言
    expect(find.widgetWithText(ArticleCard, '文章 3'), findsOneWidget);
    expect(find.widgetWithText(ArticleCard, '文章 1'), findsNothing);
  });

  testWidgets('标签筛选只保留对应标签的文章', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());

    await tester.tap(find.text('技术 (4)'));
    await tester.pumpAndSettle();

    expect(find.text('文章 1'), findsOneWidget);
    expect(find.text('文章 2'), findsNothing);
  });

  testWidgets('归档可以按月份筛选', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());

    await tester.ensureVisible(find.text('2026-08'));
    await tester.tap(find.text('2026-08'));
    await tester.pumpAndSettle();

    expect(find.text('文章 5'), findsOneWidget);
    expect(find.text('文章 1'), findsNothing);
  });

  testWidgets('分页可以翻到下一页', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());

    expect(find.text('文章 6'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('文章 6'), findsOneWidget);
    expect(find.text('文章 1'), findsNothing);
  });

  testWidgets('筛选没有结果时可以一键清除条件', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());

    await tester.enterText(find.byType(TextField), '不存在的关键词');
    await tester.pumpAndSettle();

    expect(find.text('没有匹配的文章'), findsOneWidget);

    await tester.tap(find.text('清除筛选条件'));
    await tester.pumpAndSettle();

    expect(find.text('文章 1'), findsOneWidget);
  });

  testWidgets('数据读取失败时展示错误提示与重试按钮', (WidgetTester tester) async {
    await _pumpHome(tester, const _FailingDataService());

    expect(find.textContaining('数据加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('深浅色切换按钮可以切换主题', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(dataService: _FakeDataService()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });

  testWidgets('编辑模式需要密码，密码错误会提示', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());

    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    expect(find.text('进入编辑模式'), findsOneWidget);

    final Finder dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    await tester.enterText(dialogField, '错误的密码');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('密码不正确'), findsOneWidget);

    // 密码正确后才进入编辑模式
    await tester.enterText(dialogField, 'test-pass');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
  });

  testWidgets('编辑模式下拖动滑块可以改变主色调', (WidgetTester tester) async {
    await _useWideSurface(tester);
    final AppSettings settings = AppSettings();
    await _pumpHome(tester, const _FakeDataService(), settings: settings);
    await _enterEditMode(tester);

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();

    expect(find.text('主色调'), findsOneWidget);
    expect(settings.seedColor, AppSettings.defaultSeedColor);

    final Finder hueSlider = find.byType(Slider).first;
    final Rect rect = tester.getRect(hueSlider);
    await tester.tapAt(Offset(rect.left + rect.width * 0.8, rect.center.dy));
    await tester.pumpAndSettle();

    expect(settings.seedColor, isNot(AppSettings.defaultSeedColor));
  });

  testWidgets('编辑模式下点击文字可以改内容，非编辑模式不行', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());

    // 非编辑模式：点名字不该有反应
    await tester.tap(find.text('测试用户'));
    await tester.pumpAndSettle();
    expect(find.text('修改名字'), findsNothing);

    await _enterEditMode(tester);

    await tester.tap(find.text('测试用户'));
    await tester.pumpAndSettle();
    expect(find.text('修改名字'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '新的名字',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('新的名字'), findsOneWidget);
    expect(find.text('测试用户'), findsNothing);
  });

  testWidgets('部署了后端时，编辑保存会写回服务器', (WidgetTester tester) async {
    await _useWideSurface(tester);
    final _RecordingApi api = _RecordingApi();
    await _pumpHome(tester, _FakeDataService(api: api));
    await _enterEditMode(tester);

    await tester.tap(find.text('测试用户'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '写进服务器的名字',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(api.writes, hasLength(1));
    final ({String name, String content, String password}) written =
        api.writes.single;
    expect(written.name, 'profile.json');
    expect(written.content, contains('写进服务器的名字'));
    // 密码得一起带上，服务端靠它拦写操作
    expect(written.password, 'test-pass');
    // 推的是合并后的完整配置，没改过的字段也在，不能只推改动项
    expect(written.content, contains('"editPassword": "test-pass"'));
    expect(written.content, contains('"footer"'));
    expect(find.text('已写入服务器，所有访客可见'), findsOneWidget);
  });

  testWidgets('写进服务器后清掉本地副本，免得盖住 JSON 文件', (WidgetTester tester) async {
    await _useWideSurface(tester);
    final _RecordingApi api = _RecordingApi();
    await _pumpHome(tester, _FakeDataService(api: api));
    await _enterEditMode(tester);

    await tester.tap(find.text('测试用户'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '写进服务器的名字',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(api.writes, hasLength(1));
    // 内容已经在服务器上了，本地副本是整体替换而非合并的，留着会一直盖住
    // profile.json——以后直接改 JSON 页面反而不会变
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> stored =
        jsonDecode(prefs.getString('profileOverrides') ?? '{}')
            as Map<String, dynamic>;
    expect(stored.containsKey(ContentKeys.name), isFalse);
    // 界面上还是改后的值，不能因为清了副本就退回去
    expect(find.text('写进服务器的名字'), findsOneWidget);
  });

  testWidgets('没部署后端时提示改动只在本浏览器生效', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);

    await tester.tap(find.text('测试用户'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '只在本地的名字',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('未部署后端，改动只在本浏览器生效'), findsOneWidget);
  });

  testWidgets('改友链和文章也会推给后端', (WidgetTester tester) async {
    await _useWideSurface(tester);
    final _RecordingApi api = _RecordingApi();
    await _pumpHome(tester, _FakeDataService(api: api));
    await _enterEditMode(tester);

    // 删掉一条友链，应该推 friendship.json
    await tester.ensureVisible(find.byTooltip('删除友链').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除友链').first);
    await tester.pumpAndSettle();

    expect(api.writes, hasLength(1));
    expect(api.writes.single.name, 'friendship.json');
    // 原数据只有一条友链，删完就是空数组
    expect(api.writes.single.content.trim(), '[]');

    // 新建一篇文章，应该推 articles.json
    await _openArticleManager(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find
          .descendant(
            of: find.byType(ArticleEditorPage),
            matching: find.byType(TextField),
          )
          .first,
      '后端测试文章',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(api.writes, hasLength(2));
    expect(api.writes.last.name, 'articles.json');
    expect(api.writes.last.content, contains('后端测试文章'));
  });

  testWidgets('编辑面板可以恢复默认文字', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);

    await tester.tap(find.text('测试用户'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '临时名字',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('临时名字'), findsOneWidget);

    // 打开编辑面板，点「恢复默认文字」
    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复默认内容'));
    await tester.pumpAndSettle();

    expect(find.text('测试用户'), findsOneWidget);
    expect(find.text('临时名字'), findsNothing);
  });

  testWidgets('编辑模式下可以改头像地址', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());

    // 非编辑模式没有改头像的入口
    expect(find.byIcon(Icons.edit), findsNothing);

    await _enterEditMode(tester);
    expect(find.byIcon(Icons.edit), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    expect(find.text('修改头像'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'assets/images/avatar.png',
    );
    await tester.pump();

    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('修改头像'), findsNothing);
  });

  testWidgets('编辑模式下可以更换站点图标', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);

    // 非编辑模式没有这个面板
    expect(find.text('站点设置'), findsNothing);

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    expect(find.text('站点设置'), findsOneWidget);
    expect(find.text('默认图标'), findsOneWidget);

    await _tapInPanel(tester, '更换站点图标');
    expect(find.text('更换站点图标'), findsWidgets);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'assets/images/icon.png',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 面板里的预览跟着换成新地址
    expect(find.text('assets/images/icon.png'), findsOneWidget);
    expect(find.text('默认图标'), findsNothing);
  });

  testWidgets('编辑模式下可以修改编辑密码', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    await _tapInPanel(tester, '修改编辑密码');

    final Finder fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    // 两次输入不一致不让保存
    await tester.enterText(fields.at(0), 'new-pass');
    await tester.enterText(fields.at(1), 'other-pass');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('两次输入不一致'), findsOneWidget);

    await tester.enterText(fields.at(1), 'new-pass');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('密码已修改'), findsOneWidget);

    // 退出编辑模式后：旧密码进不去，新密码可以
    await _closePanel(tester);
    await tester.tap(find.byIcon(Icons.lock_open));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    final Finder passwordField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    await tester.enterText(passwordField, 'test-pass');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('密码不正确'), findsOneWidget);

    await tester.enterText(passwordField, 'new-pass');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
  });

  testWidgets('有后端时改密码用旧密码认证，新密码写进 JSON', (WidgetTester tester) async {
    await _useWideSurface(tester);
    final _RecordingApi api = _RecordingApi();
    await _pumpHome(tester, _FakeDataService(api: api));
    await _enterEditMode(tester);

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    await _tapInPanel(tester, '修改编辑密码');

    final Finder fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'new-pass');
    await tester.enterText(fields.at(1), 'new-pass');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(api.writes, hasLength(1));
    expect(api.writes.single.name, 'profile.json');
    // 服务端认的是 JSON 里当前那个密码，这一次必须拿旧的去过校验
    expect(api.writes.single.password, 'test-pass');
    expect(api.writes.single.content, contains('"editPassword": "new-pass"'));
    expect(find.text('密码已修改，并写入服务器'), findsOneWidget);
  });

  testWidgets('服务器没收下新密码时本地回滚', (WidgetTester tester) async {
    await _useWideSurface(tester);
    final _RecordingApi api = _RecordingApi(result: WriteResult.wrongPassword);
    await _pumpHome(tester, _FakeDataService(api: api));
    await _enterEditMode(tester);

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    await _tapInPanel(tester, '修改编辑密码');

    final Finder fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'new-pass');
    await tester.enterText(fields.at(1), 'new-pass');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('服务器没接受，密码未修改'), findsOneWidget);

    // 旧密码仍然能用，不能出现两边密码对不上、进不去编辑模式
    await _closePanel(tester);
    await tester.tap(find.byIcon(Icons.lock_open));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'test-pass',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
  });

  testWidgets('编辑模式下可以增删改联系方式', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());

    // 非编辑模式：只能看，没有增删入口
    expect(find.text('Github: tester'), findsOneWidget);
    expect(find.text('添加联系方式'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await _enterEditMode(tester);

    final Finder fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    // 改一条
    await tester.tap(find.text('Github: tester'));
    await tester.pumpAndSettle();
    expect(find.text('修改联系方式'), findsOneWidget);

    await tester.enterText(fields.at(1), 'new-tester');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('Github: new-tester'), findsOneWidget);
    expect(find.text('Github: tester'), findsNothing);

    // 加一条
    await tester.tap(find.text('添加联系方式'));
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(0), '知乎');
    await tester.enterText(fields.at(1), 'zhihu');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('知乎: zhihu'), findsOneWidget);

    // 删一条（删的是第一行 Github）
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Github: new-tester'), findsNothing);
    expect(find.text('知乎: zhihu'), findsOneWidget);
  });

  testWidgets('联系方式名称或内容为空时不让保存', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);

    await tester.tap(find.text('添加联系方式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('名称和内容都要填'), findsOneWidget);
    expect(find.text('添加联系方式'), findsWidgets);
  });

  testWidgets('非编辑模式下没有文章管理入口', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());

    expect(find.byIcon(Icons.edit_note), findsNothing);
    expect(find.byType(ArticleManagerPage), findsNothing);
  });

  testWidgets('没部署后端时文章管理页说明改动只在本地', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);
    await _openArticleManager(tester);

    expect(find.textContaining('只保存在当前浏览器'), findsOneWidget);
  });

  testWidgets('部署了后端时文章管理页说明改动会写进 articles.json', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, _FakeDataService(api: _RecordingApi()));
    await _enterEditMode(tester);
    await _openArticleManager(tester);

    expect(find.textContaining('写进 assets/data/articles.json'), findsOneWidget);
  });

  testWidgets('编辑模式下可以新建文章并出现在首页', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);
    await _openArticleManager(tester);

    expect(find.text('文章管理'), findsOneWidget);
    expect(_inManager('文章 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('新建文章'), findsOneWidget);

    await tester.enterText(_editorFields().at(0), '新写的文章');
    await tester.enterText(_editorFields().at(2), '技术、随笔');
    await tester.enterText(_editorFields().at(4), '## 小标题\n\n正文');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 回到管理页，新文章在列表里
    expect(_inManager('新写的文章'), findsOneWidget);

    // 再回首页，新文章排在第一位（日期是今天）
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('新写的文章'), findsOneWidget);
  });

  testWidgets('编辑模式下可以改文章标题', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);
    await _openArticleManager(tester);

    await tester.tap(
      find
          .descendant(
            of: find.byType(ArticleManagerPage),
            matching: find.byIcon(Icons.edit_outlined),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('编辑文章'), findsOneWidget);

    await tester.enterText(_editorFields().at(0), '改过的标题');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(_inManager('改过的标题'), findsOneWidget);
    expect(_inManager('文章 1'), findsNothing);
  });

  testWidgets('删文章前要确认，取消就不删', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);
    await _openArticleManager(tester);

    expect(_managerDeleteButtons(), findsNWidgets(7));

    await tester.tap(_managerDeleteButtons().first);
    await tester.pumpAndSettle();
    expect(find.text('删除文章'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(_managerDeleteButtons(), findsNWidgets(7));

    await tester.tap(_managerDeleteButtons().first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(_managerDeleteButtons(), findsNWidgets(6));
    expect(_inManager('文章 1'), findsNothing);
  });

  testWidgets('文章全删光后首页不会又冒出原来的文章', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);
    await _openArticleManager(tester);

    for (int i = 0; i < 7; i++) {
      await tester.tap(_managerDeleteButtons().first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();
    }

    expect(find.text('还没有文章'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('文章 1'), findsNothing);
    expect(find.text('文章 7'), findsNothing);
  });

  testWidgets('文章标题为空时不让保存', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);
    await _openArticleManager(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('标题不能为空'), findsOneWidget);
    expect(find.text('新建文章'), findsOneWidget);
  });

  test('导出配置会把改动合并进原 JSON', () async {
    const DataService service = _FakeDataService();
    final Profile base = await service.loadProfile();
    final List<Friend> friends = await service.loadFriends();
    final List<Article> articles = await service.loadArticles();

    final ContentStore store = ContentStore();
    await store.set(ContentKeys.name, '改过的名字');
    await store.set(ContentKeys.siteTitle, '改过的标题');
    await store.set(ContentKeys.favicon, 'assets/images/icon.png');
    await store.set(ContentKeys.editPassword, 'new-pass');
    await store.setList(ContentKeys.links, <Map<String, dynamic>>[
      <String, dynamic>{'label': '知乎', 'value': 'zhihu'},
    ]);

    final List<ExportedFile> files = exportConfig(
      base: base,
      friends: friends,
      articles: articles,
      store: store,
    );

    expect(files.map((ExportedFile f) => f.path).toList(), <String>[
      'assets/data/profile.json',
      'assets/data/friendship.json',
      'assets/data/articles.json',
    ]);

    final Map<String, dynamic> profileJson = _jsonAt(files, 'profile.json');

    // 改过的用新值
    expect(profileJson['name'], '改过的名字');
    expect(profileJson['siteTitle'], '改过的标题');
    // 没改过的用原值补齐，导出的是一份完整配置
    expect(profileJson['tagline'], base.tagline);
    expect(profileJson['footer'], base.footer);
    expect(profileJson['avatar'], base.avatar);
    // 站点图标同理：改过用改后的
    expect(profileJson['favicon'], 'assets/images/icon.png');
    // 改过密码就用改后的，否则导出后编辑入口就没了
    expect(profileJson['editPassword'], 'new-pass');
    // 联系方式整条替换，没填 url 的不写出 url 字段
    expect(profileJson['links'], <dynamic>[
      <String, dynamic>{'label': '知乎', 'value': 'zhihu'},
    ]);

    // 友链没改过，导出的是原样，不能变成空数组
    expect(_jsonAt(files, 'friendship.json'), <dynamic>[
      <String, dynamic>{
        'name': '测试好友',
        'description': '欢迎！欢迎！',
        'avatar': '',
        'url': 'https://example.com',
      },
    ]);

    final List<dynamic> articleJson =
        _jsonAt(files, 'articles.json') as List<dynamic>;
    expect(articleJson.length, articles.length);
    expect((articleJson.first as Map<String, dynamic>)['title'], '文章 1');
    expect((articleJson.first as Map<String, dynamic>)['tags'], <dynamic>[
      '技术',
    ]);
  });

  test('文章全删光时导出的是一份空数组', () async {
    const DataService service = _FakeDataService();
    final Profile base = await service.loadProfile();
    final List<Friend> friends = await service.loadFriends();

    final ContentStore store = ContentStore();
    await store.setList(ContentKeys.articles, <Map<String, dynamic>>[]);

    final List<ExportedFile> files = exportConfig(
      base: base,
      friends: friends,
      articles: const [],
      store: store,
    );

    expect(_jsonAt(files, 'articles.json'), <dynamic>[]);
    // 友链不受影响
    expect((_jsonAt(files, 'friendship.json') as List<dynamic>).length, 1);
  });

  testWidgets('编辑模式下可以打开导出页看到改后的内容', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);

    // 先把名字改掉，导出里应该是改后的值
    await tester.tap(find.text('测试用户'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '导出用名字',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 调色面板里点「导出配置」
    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出配置'));
    await tester.pumpAndSettle();

    expect(find.byType(ExportPage), findsOneWidget);
    expect(find.text('profile.json'), findsOneWidget);
    expect(find.text('articles.json'), findsOneWidget);

    final ExportPage page = tester.widget<ExportPage>(find.byType(ExportPage));
    expect(page.files.first.content, contains('导出用名字'));
    expect(page.files.first.content, contains('"editPassword": "test-pass"'));
    expect(page.files.last.content, contains('文章 1'));
    // 三个文件都在：个人信息、友链、文章
    expect(page.files.map((ExportedFile f) => f.name).toList(), <String>[
      'profile.json',
      'friendship.json',
      'articles.json',
    ]);
  });

  testWidgets('编辑模式下可以修改友链', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);

    await tester.ensureVisible(find.text('测试好友'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试好友'));
    await tester.pumpAndSettle();

    expect(find.text('修改友链'), findsOneWidget);

    await tester.enterText(_friendDialogFields().at(0), '改过的友链');
    await tester.enterText(_friendDialogFields().at(1), '改过的描述');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('改过的友链'), findsOneWidget);
    expect(find.text('改过的描述'), findsOneWidget);
    expect(find.text('测试好友'), findsNothing);
  });

  testWidgets('编辑模式下可以添加和删除友链', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());
    await _enterEditMode(tester);

    // 添加一条
    await tester.ensureVisible(find.text('添加友链'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加友链'));
    await tester.pumpAndSettle();
    await tester.enterText(_friendDialogFields().at(0), '新朋友');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('新朋友'), findsOneWidget);
    expect(find.text('测试好友'), findsOneWidget);

    // 名称空着不让保存
    await tester.ensureVisible(find.text('添加友链'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加友链'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('名称要填'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // 删掉原来那条，新增的还在
    await tester.ensureVisible(find.byTooltip('删除友链').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除友链').first);
    await tester.pumpAndSettle();

    expect(find.text('测试好友'), findsNothing);
    expect(find.text('新朋友'), findsOneWidget);
  });

  testWidgets('非编辑模式下友链没有编辑入口', (WidgetTester tester) async {
    await _useWideSurface(tester);
    await _pumpHome(tester, const _FakeDataService());

    await tester.ensureVisible(find.text('测试好友'));
    await tester.pumpAndSettle();

    expect(find.text('添加友链'), findsNothing);
    expect(find.byTooltip('删除友链'), findsNothing);
  });
}
