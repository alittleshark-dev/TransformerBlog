import 'dart:convert';

import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../article_filter.dart';
import '../browser_tab.dart';
import '../config_api.dart';
import '../config_exporter.dart';
import '../content_store.dart';
import '../data_service.dart';
import '../models.dart';
import '../url_utils.dart';
import '../widgets/animations.dart';
import '../widgets/article_card.dart';
import '../widgets/avatar_image.dart';
import '../widgets/contact_link_dialog.dart';
import '../widgets/editable_text.dart';
import '../widgets/friend_dialog.dart';
import '../widgets/glass_card.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/password_change_dialog.dart';
import '../widgets/theme_controls.dart';
import 'article_manager_page.dart';
import 'article_page.dart';
import 'export_page.dart';

/// 首页：宽屏左右双栏，窄屏（手机）单列。
///
/// 支持关键词搜索、标签筛选、按月份归档和分页。
/// 顶部可以切换深浅色；输入密码进入编辑模式后，可以改主色调，
/// 也可以直接点页面上的标题、名字、简介、页脚来改文字。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.settings,
    this.dataService = const DataService(api: ConfigApi()),
  });

  final AppSettings settings;
  final DataService dataService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _wideBreakpoint = 900;
  static const int _pageSize = 5;

  /// profile.json 里的字段，保存成功后要一并清掉它们的本地副本。
  static const List<String> _profileKeys = <String>[
    ContentKeys.siteTitle,
    ContentKeys.name,
    ContentKeys.tagline,
    ContentKeys.avatar,
    ContentKeys.favicon,
    ContentKeys.links,
    ContentKeys.footer,
    ContentKeys.editPassword,
  ];

  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ContentStore _contentStore = ContentStore();

  Profile? _profile;

  /// friendship.json 里的原值，用来在「恢复默认内容」时还原。
  List<Friend> _baseFriends = const [];

  /// 当前生效的友链，编辑模式下改过就是改后的。
  List<Friend> _friends = const [];

  /// assets/data/articles.json 里的原值，用来在「恢复默认内容」时还原。
  List<Article> _baseArticles = const [];

  /// 当前生效的文章，编辑模式下改过就是改后的。
  List<Article> _articles = const [];
  Object? _error;
  bool _loading = true;

  String _query = '';
  String? _activeTag;
  String? _activeArchive;
  int _page = 1;
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Profile profile = await widget.dataService.loadProfile();
      final List<Friend> friends = await widget.dataService.loadFriends();
      final List<Article> articles = await widget.dataService.loadArticles();
      await _contentStore.load();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _baseFriends = friends;
        _friends = _resolveFriends();
        _baseArticles = articles;
        _articles = _resolveArticles();
        _loading = false;
      });
      // 数据拿到之后再把标签页上的图标和标题换掉
      _applyBrowserTab();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _updateQuery(String value) {
    setState(() {
      _query = value;
      _page = 1;
    });
  }

  void _selectTag(String? tag) {
    setState(() {
      _activeTag = _activeTag == tag ? null : tag;
      _page = 1;
    });
  }

  void _selectArchive(String? archive) {
    setState(() {
      _activeArchive = _activeArchive == archive ? null : archive;
      _page = 1;
    });
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _activeTag = null;
      _activeArchive = null;
      _page = 1;
    });
  }

  void _goToPage(int page) {
    setState(() => _page = page);
  }

  void _openArticle(Article article) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/article/${article.id}'),
        builder: (BuildContext context) => ArticlePage(article: article),
      ),
    );
  }

  Future<void> _requestEditMode() async {
    final Profile? profile = _profile;
    if (profile == null) return;
    final String password = _passwordOf(profile);
    if (password.isEmpty) return;

    final bool passed = await PasswordDialog.show(context, password);
    if (!passed || !mounted) return;
    setState(() => _editMode = true);
  }

  void _exitEditMode() {
    _scaffoldKey.currentState?.closeEndDrawer();
    setState(() => _editMode = false);
  }

  /// 字段当前该显示的文字：编辑模式下改过就用改后的，否则用 JSON 里的原值。
  String _text(String key, String fallback) =>
      _contentStore.valueOf(key, fallback);

  /// 当前生效的编辑密码：改过就用改后的，否则用 JSON 里的原值。
  String _passwordOf(Profile profile) =>
      _contentStore.valueOf(ContentKeys.editPassword, profile.editPassword);

  /// 把浏览器标签页上的图标和标题刷成当前生效的值。
  ///
  /// 这俩是直接改 DOM 的，setState 不会自己带上，改完得手动调一次。
  void _applyBrowserTab() {
    final Profile? profile = _profile;
    if (profile == null) return;
    setFavicon(_text(ContentKeys.favicon, profile.favicon));
    setDocumentTitle(_text(ContentKeys.siteTitle, profile.siteTitle));
  }

  /// 把一份配置写回服务端的 JSON 文件。
  ///
  /// 部署了 server/server.dart 时改动会真正落到 assets/data 里，所有访客
  /// 都能看到；没部署就返回 [WriteResult.unavailable]，改动留在本浏览器。
  ///
  /// [password] 只在改密码时传：那一次得用旧密码过服务端的校验，
  /// 否则服务端会把新密码当成错误密码拒掉。
  Future<WriteResult> _pushToServer(
    String path,
    String content, {
    String? password,
  }) async {
    final ConfigApi? api = widget.dataService.api;
    final Profile? profile = _profile;
    if (api == null || profile == null) return WriteResult.unavailable;
    return api.write(
      path.split('/').last,
      content,
      password: password ?? _passwordOf(profile),
    );
  }

  /// 提示这次保存到底落到哪儿了。
  ///
  /// 不提示的话，用户会以为改动已经对所有人生效，其实可能只在本浏览器。
  void _reportSave(WriteResult result) {
    _showMessage(switch (result) {
      WriteResult.saved => '已写入服务器，所有访客可见',
      WriteResult.wrongPassword => '服务器密码不匹配，改动只在本浏览器生效',
      WriteResult.failed => '写入服务器失败，改动只在本浏览器生效',
      WriteResult.unavailable => '未部署后端，改动只在本浏览器生效',
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  /// 把当前 profile 推回服务器。联系方式、头像、文字改完都走这里。
  Future<void> _pushProfile() async {
    final Profile? profile = _profile;
    if (profile == null) return;
    final String json = profileJson(profile, _contentStore);
    final WriteResult result = await _pushToServer(ConfigFiles.profile, json);
    if (result == WriteResult.saved) {
      // 服务器已经存下了，就把这份合并后的值当成新基准、并把本地副本删掉，
      // 否则本地副本会一直盖着 profile.json，以后直接改 JSON 页面不会变
      _profile = Profile.fromJson(jsonDecode(json) as Map<String, dynamic>);
      await _contentStore.removeAll(_profileKeys);
      if (mounted) setState(() {});
    }
    _reportSave(result);
  }

  /// 弹框改一段文字，保存后立刻生效并写进本地存储。
  Future<void> _editText({
    required String key,
    required String label,
    required String current,
    bool multiline = false,
  }) async {
    final String? value = await EditTextDialog.show(
      context,
      title: '修改$label',
      initialValue: current,
      multiline: multiline,
    );
    if (value == null || !mounted) return;
    await _contentStore.set(key, value);
    if (!mounted) return;
    setState(() {});
    // 改的可能就是站点标题，标签页要跟着变
    _applyBrowserTab();
    await _pushProfile();
  }

  Future<void> _resetText() async {
    // 有后端时这个操作会把服务器上的内容也一起清掉，先问一句
    if (widget.dataService.api != null) {
      final bool confirmed = await _confirmServerReset();
      if (!confirmed || !mounted) return;
      await _contentStore.clear();
      // 把出厂默认值推回服务器，否则刷新一下改过的东西又回来了
      const DataService bundled = DataService();
      await _pushToServer(
        ConfigFiles.profile,
        profileJson(await bundled.loadProfile(), _contentStore),
      );
      await _pushToServer(
        ConfigFiles.friendship,
        friendsJson(await bundled.loadFriends()),
      );
      await _pushToServer(
        ConfigFiles.articles,
        articlesJson(await bundled.loadArticles()),
      );
      if (!mounted) return;
      // 服务器内容变了，重新拉一遍
      setState(() => _loading = true);
      await _load();
      return;
    }

    await _contentStore.clear();
    if (!mounted) return;
    setState(() {
      _friends = _resolveFriends();
      _articles = _resolveArticles();
    });
    // 图标和标题是直接改 DOM 的，不会随 setState 自己变回来
    _applyBrowserTab();
  }

  /// 有后端时的恢复默认，会连服务器上的 JSON 一起覆盖，所以要确认。
  Future<bool> _confirmServerReset() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('恢复默认内容'),
        content: const Text(
          '已部署后端，这个操作会把服务器上的 profile.json、'
          'friendship.json、articles.json 一起覆盖成模板出厂内容。\n\n'
          '服务器上改过的东西都会丢失，确定吗？',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定覆盖'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 当前该用哪份友链：编辑模式下改过就用改后的，否则用 JSON 里的原值。
  List<Friend> _resolveFriends() => _contentStore.has(ContentKeys.friends)
      ? _contentStore.listOf<Friend>(
          ContentKeys.friends,
          _baseFriends,
          Friend.fromJson,
        )
      : _baseFriends;

  Future<void> _saveFriends(List<Friend> friends) async {
    // 先在本地生效，界面立刻更新，不用等服务器
    await _contentStore.setList(
      ContentKeys.friends,
      <Map<String, dynamic>>[
        for (final Friend friend in friends) friend.toJson(),
      ],
    );
    if (!mounted) return;
    setState(() => _friends = _resolveFriends());

    final WriteResult result =
        await _pushToServer(ConfigFiles.friendship, friendsJson(friends));
    if (result == WriteResult.saved) {
      // 服务器已经存下了，本地副本没用了，留着只会盖住 friendship.json
      _baseFriends = friends;
      await _contentStore.removeAll(<String>[ContentKeys.friends]);
    }
    _reportSave(result);
  }

  /// 新增（index 为 null）或修改一条友链。
  Future<void> _editFriend(List<Friend> friends, int? index) async {
    final Friend? result = await FriendDialog.show(
      context,
      initial: index == null ? null : friends[index],
    );
    if (result == null || !mounted) return;

    final List<Friend> updated = <Friend>[...friends];
    if (index == null) {
      updated.add(result);
    } else {
      updated[index] = result;
    }
    await _saveFriends(updated);
  }

  Future<void> _removeFriend(List<Friend> friends, int index) async {
    await _saveFriends(<Friend>[...friends]..removeAt(index));
  }

  /// 当前该用哪份文章列表：编辑模式下改过就用改后的，否则用 JSON 里的原值。
  ///
  /// 用 [ContentStore.has] 判断有没有改过，而不是看列表是不是空的，
  /// 否则「把文章全删光」会被当成「没改过」而重新冒出原来的文章。
  List<Article> _resolveArticles() {
    final List<Article> source = _contentStore.has(ContentKeys.articles)
        ? _contentStore.listOf<Article>(ContentKeys.articles, const [], Article.fromJson)
        : _baseArticles;
    return <Article>[...source]
      ..sort((Article a, Article b) => b.date.compareTo(a.date));
  }

  Future<void> _saveArticles(List<Article> articles) async {
    // 先在本地生效，界面立刻更新，不用等服务器
    await _contentStore.setList(
      ContentKeys.articles,
      <Map<String, dynamic>>[
        for (final Article article in articles) article.toJson(),
      ],
    );
    if (!mounted) return;
    setState(() => _articles = _resolveArticles());

    final WriteResult result =
        await _pushToServer(ConfigFiles.articles, articlesJson(articles));
    if (result == WriteResult.saved) {
      // 服务器已经存下了，本地副本没用了，留着只会盖住 articles.json
      _baseArticles = articles;
      await _contentStore.removeAll(<String>[ContentKeys.articles]);
    }
    _reportSave(result);
  }

  /// 把当前所有改动导出成 JSON，方便覆盖回 assets/data。
  void _openExport() {
    final Profile? profile = _profile;
    if (profile == null) return;
    _scaffoldKey.currentState?.closeEndDrawer();
    ExportPage.open(
      context,
      exportConfig(
        base: profile,
        friends: _friends,
        articles: _articles,
        store: _contentStore,
      ),
    );
  }

  Future<void> _openArticleManager() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/manage/articles'),
        builder: (BuildContext context) => ArticleManagerPage(
          articles: _articles,
          onSave: _saveArticles,
          savedToServer: widget.dataService.api != null,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  /// 弹框改头像地址，保存后立刻生效。
  Future<void> _editAvatar(String current) async {
    final String? value = await AvatarEditDialog.show(
      context,
      initialValue: current,
    );
    if (value == null || !mounted) return;
    await _contentStore.set(ContentKeys.avatar, value);
    if (!mounted) return;
    setState(() {});
    await _pushProfile();
  }

  /// 弹框改浏览器标签页上的图标，保存后立刻生效。
  Future<void> _editFavicon(String current) async {
    final String? value = await AvatarEditDialog.show(
      context,
      initialValue: current,
      title: '更换站点图标',
      labelText: '图标地址',
      hintText: 'https://example.com/favicon.png',
      helperText: '建议用正方形的图片（比如 64×64 的 png），'
          '浏览器标签页上就显示这个；留空则用默认图标',
    );
    if (value == null || !mounted) return;
    await _contentStore.set(ContentKeys.favicon, value);
    if (!mounted) return;
    setState(() {});
    _applyBrowserTab();
    await _pushProfile();
  }

  /// 改编辑模式密码。
  ///
  /// 有后端时这次写入必须用**旧密码**认证：服务端认的是 JSON 里当前那个密码，
  /// 拿新密码去写会被当成密码错误。服务端没收下就把本地也退回去，
  /// 免得两边密码对不上、下次进不去编辑模式。
  Future<void> _changePassword() async {
    final Profile? profile = _profile;
    if (profile == null) return;
    final String oldPassword = _passwordOf(profile);

    final String? value = await PasswordChangeDialog.show(context);
    if (value == null || !mounted) return;

    await _contentStore.set(ContentKeys.editPassword, value);
    if (!mounted) return;
    setState(() {});

    final String json = profileJson(profile, _contentStore);
    final WriteResult result = await _pushToServer(
      ConfigFiles.profile,
      json,
      password: oldPassword,
    );
    if (!mounted) return;

    if (widget.dataService.api != null && result != WriteResult.saved) {
      await _contentStore.set(ContentKeys.editPassword, oldPassword);
      if (!mounted) return;
      setState(() {});
      _showMessage('服务器没接受，密码未修改');
      return;
    }
    if (result == WriteResult.saved) {
      // 新密码已经在服务器上了，本地副本没必要留，免得又盖住 profile.json
      _profile = Profile.fromJson(jsonDecode(json) as Map<String, dynamic>);
      await _contentStore.removeAll(_profileKeys);
      if (!mounted) return;
      setState(() {});
    }
    _showMessage(
      result == WriteResult.saved
          ? '密码已修改，并写入服务器'
          : '密码已修改（未部署后端，导出配置后才会写进 JSON）',
    );
  }

  /// 联系方式列表：编辑模式下改过就用改后的，否则用 JSON 里的原值。
  List<ContactLink> _linksOf(Profile profile) => _contentStore.listOf<ContactLink>(
        ContentKeys.links,
        profile.links,
        ContactLink.fromJson,
      );

  Future<void> _saveLinks(List<ContactLink> links) async {
    await _contentStore.setList(
      ContentKeys.links,
      <Map<String, dynamic>>[
        for (final ContactLink link in links) link.toJson(),
      ],
    );
    if (!mounted) return;
    setState(() {});
    await _pushProfile();
  }

  /// 新增（index 为 null）或修改一条联系方式。
  Future<void> _editContact(List<ContactLink> links, int? index) async {
    final ContactLink? result = await ContactLinkDialog.show(
      context,
      initial: index == null ? null : links[index],
    );
    if (result == null || !mounted) return;

    final List<ContactLink> updated = <ContactLink>[...links];
    if (index == null) {
      updated.add(result);
    } else {
      updated[index] = result;
    }
    await _saveLinks(updated);
  }

  Future<void> _removeContact(List<ContactLink> links, int index) async {
    await _saveLinks(<ContactLink>[...links]..removeAt(index));
  }

  /// 包成可编辑文字，非编辑模式下就是原来的普通文字。
  Widget _editable({
    required String key,
    required String label,
    required String fallback,
    TextStyle? style,
    TextAlign textAlign = TextAlign.start,
    bool multiline = false,
  }) {
    final String current = _text(key, fallback);
    return EditableTextBlock(
      text: current,
      editMode: _editMode,
      style: style,
      textAlign: textAlign,
      onEdit: () => _editText(
        key: key,
        label: label,
        current: current,
        multiline: multiline,
      ),
    );
  }

  /// 让侧栏里的卡片依次淡入。
  Widget _stagger(int index, Widget child) =>
      FadeSlideIn(delay: staggerDelay(index), child: child);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Profile? profile = _profile;
    final bool canEdit = profile?.editPassword.isNotEmpty ?? false;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _editMode
          ? ColorPanel(
              settings: widget.settings,
              onResetText: _resetText,
              onExport: _openExport,
              onEditFavicon: () => _editFavicon(
                _text(ContentKeys.favicon, profile?.favicon ?? ''),
              ),
              onChangePassword: _changePassword,
              favicon: _text(ContentKeys.favicon, profile?.favicon ?? ''),
              hasTextChanges: !_contentStore.isEmpty,
              savedToServer: widget.dataService.api != null,
            )
          : null,
      appBar: AppBar(
        title: _editable(
          key: ContentKeys.siteTitle,
          label: '站点标题',
          fallback: profile?.siteTitle ?? '个人网站',
        ),
        centerTitle: false,
        elevation: 4,
        actions: [
          ThemeModeButton(settings: widget.settings),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (Widget child, Animation<double> animation) =>
                FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
            child: _editMode
                ? Row(
                    key: const ValueKey<String>('editing'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_note),
                        tooltip: '管理文章',
                        onPressed: _openArticleManager,
                      ),
                      IconButton(
                        icon: const Icon(Icons.palette_outlined),
                        tooltip: '调整主色调',
                        onPressed: () =>
                            _scaffoldKey.currentState?.openEndDrawer(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.lock_open),
                        tooltip: '退出编辑模式',
                        onPressed: _exitEditMode,
                      ),
                    ],
                  )
                : canEdit
                    ? EditModeButton(
                        key: const ValueKey<String>('locked'),
                        onPressed: _requestEditMode,
                      )
                    : const SizedBox(
                        key: ValueKey<String>('none'),
                        width: 0,
                      ),
          ),
        ],
      ),
      body: SizedBox.expand(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [Color(0xFF11161F), Color(0xFF1B2430)]
                  : const [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            ),
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(onRetry: _load);
    }

    final Profile profile = _profile!;
    final List<Article> filtered = filterArticles(
      _articles,
      query: _query,
      tag: _activeTag,
      archive: _activeArchive,
    );
    final int pageCount = filtered.isEmpty
        ? 1
        : (filtered.length + _pageSize - 1) ~/ _pageSize;
    final int page = _page.clamp(1, pageCount);
    final int start = (page - 1) * _pageSize;
    final List<Article> paged = start >= filtered.length
        ? const []
        : filtered.skip(start).take(_pageSize).toList();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget sidebar = _buildSidebar(context, profile);
        final String footerText = _text(ContentKeys.footer, profile.footer);
        final Widget footer = footerText.isEmpty && !_editMode
            ? const SizedBox.shrink()
            : _buildFooter(context, footerText);
        final Widget pagination = PaginationBar(
          page: page,
          pageCount: pageCount,
          onPageChanged: _goToPage,
        );

        if (constraints.maxWidth < _wideBreakpoint) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sidebar,
                const SizedBox(height: 16),
                ..._buildToolbar(context),
                ..._buildArticleCards(context, paged, filtered.isEmpty),
                pagination,
                footer,
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 300,
                      child: SingleChildScrollView(child: sidebar),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ..._buildToolbar(context),
                          Expanded(
                            child: _buildArticleList(
                              context,
                              paged,
                              filtered.isEmpty,
                            ),
                          ),
                          pagination,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              footer,
            ],
          ),
        );
      },
    );
  }

  /// 搜索框 + 标签筛选，没有文章时整体不显示。
  List<Widget> _buildToolbar(BuildContext context) {
    if (_articles.isEmpty) return const [];
    return [
      GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: TextField(
          controller: _searchController,
          onChanged: _updateQuery,
          decoration: InputDecoration(
            border: InputBorder.none,
            icon: const Icon(Icons.search),
            hintText: '搜索标题、简介、正文或标签',
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: '清空',
                    onPressed: () {
                      _searchController.clear();
                      _updateQuery('');
                    },
                  ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _buildTagFilter(context),
      const SizedBox(height: 12),
    ];
  }

  Widget _buildTagFilter(BuildContext context) {
    final Map<String, int> counts = countTags(_articles);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: Text('全部 (${_articles.length})'),
          selected: _activeTag == null,
          onSelected: (bool _) => _selectTag(null),
        ),
        for (final MapEntry<String, int> entry in counts.entries)
          FilterChip(
            label: Text('${entry.key} (${entry.value})'),
            selected: _activeTag == entry.key,
            onSelected: (bool _) => _selectTag(entry.key),
          ),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context, Profile profile) {
    final List<ContactLink> links = _linksOf(profile);
    final List<Widget> cards = <Widget>[
      GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EditableAvatar(
              editMode: _editMode,
              onEdit: () => _editAvatar(_text(ContentKeys.avatar, profile.avatar)),
              child: AvatarImage(
                url: _text(ContentKeys.avatar, profile.avatar),
                size: 80,
              ),
            ),
            const SizedBox(height: 12),
            _editable(
              key: ContentKeys.name,
              label: '名字',
              fallback: profile.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (profile.tagline.isNotEmpty || _editMode) ...[
              const SizedBox(height: 8),
              _editable(
                key: ContentKeys.tagline,
                label: '一句话介绍',
                fallback: profile.tagline,
                textAlign: TextAlign.center,
                multiline: true,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      if (links.isNotEmpty || _editMode)
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < links.length; i++)
                _buildContactRow(context, links, i),
              if (_editMode) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _editContact(links, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加联系方式'),
                ),
              ],
            ],
          ),
        ),
      if (_articles.isNotEmpty) _buildArchiveCard(context),
      if (_friends.isNotEmpty || _editMode)
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('友链', style: _monoStyle),
              const SizedBox(height: 4),
              for (int i = 0; i < _friends.length; i++)
                _buildFriendRow(context, _friends, i),
              if (_editMode) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _editFriend(_friends, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加友链'),
                ),
              ],
            ],
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _stagger(i, cards[i]),
        ],
      ],
    );
  }

  Widget _buildArchiveCard(BuildContext context) {
    final Map<String, List<Article>> groups = groupByArchive(_articles);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('归档', style: _monoStyle),
          const SizedBox(height: 4),
          _buildArchiveRow(context, null, '全部时间', _articles.length),
          for (final MapEntry<String, List<Article>> entry in groups.entries)
            _buildArchiveRow(
              context,
              entry.key,
              entry.key,
              entry.value.length,
            ),
        ],
      ),
    );
  }

  Widget _buildArchiveRow(
    BuildContext context,
    String? key,
    String label,
    int count,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool active = _activeArchive == key;
    return InkWell(
      onTap: () => _selectArchive(key),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? scheme.primary : null,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(
    BuildContext context,
    List<ContactLink> links,
    int index,
  ) {
    final ContactLink link = links[index];
    final Widget text = Text('${link.label}: ${link.value}', style: _monoStyle);

    if (!_editMode) {
      if (link.url == null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: text,
        );
      }
      return InkWell(
        onTap: () => openExternalUrl(context, link.url!),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: text,
        ),
      );
    }

    // 编辑模式下点整行改内容，右边的图标删掉这一条
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Tooltip(
            message: '点击修改',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                onTap: () => _editContact(links, index),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.06),
                    border: Border(
                      bottom: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: text,
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          tooltip: '删除',
          visualDensity: VisualDensity.compact,
          onPressed: () => _removeContact(links, index),
        ),
      ],
    );
  }

  Widget _buildFriendRow(
    BuildContext context,
    List<Friend> friends,
    int index,
  ) {
    final Friend friend = friends[index];
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarImage(url: friend.avatar, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  friend.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          if (friend.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              friend.description,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );

    if (!_editMode) {
      return InkWell(
        onTap: friend.url.isEmpty
            ? null
            : () => openExternalUrl(context, friend.url),
        child: content,
      );
    }

    // 编辑模式下点整块改内容，右边的图标删掉这一条
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Tooltip(
            message: '点击修改',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                onTap: () => _editFriend(friends, index),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.06),
                    border: Border(
                      bottom: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          tooltip: '删除友链',
          visualDensity: VisualDensity.compact,
          onPressed: () => _removeFriend(friends, index),
        ),
      ],
    );
  }

  /// 宽屏：可滚动的懒加载列表。
  Widget _buildArticleList(
    BuildContext context,
    List<Article> articles,
    bool isFilteredEmpty,
  ) {
    if (articles.isEmpty) {
      return _buildEmptyView(context, isFilteredEmpty);
    }
    return ListView.separated(
      itemCount: articles.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final Article article = articles[index];
        return FadeSlideIn(
          key: ValueKey<String>('article-$index-${article.id}'),
          delay: staggerDelay(index),
          child: ArticleCard(
            article: article,
            onTap: () => _openArticle(article),
          ),
        );
      },
    );
  }

  /// 窄屏：外层已经有滚动视图，这里只铺卡片。
  List<Widget> _buildArticleCards(
    BuildContext context,
    List<Article> articles,
    bool isFilteredEmpty,
  ) {
    if (articles.isEmpty) {
      return [_buildEmptyView(context, isFilteredEmpty)];
    }
    return [
      for (int i = 0; i < articles.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FadeSlideIn(
            key: ValueKey<String>('article-mobile-$i-${articles[i].id}'),
            delay: staggerDelay(i),
            child: ArticleCard(
              article: articles[i],
              onTap: () => _openArticle(articles[i]),
            ),
          ),
        ),
    ];
  }

  Widget _buildEmptyView(BuildContext context, bool isFilteredEmpty) {
    if (!isFilteredEmpty) {
      return const Center(child: Text('暂无文章'));
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('没有匹配的文章'),
          const SizedBox(height: 12),
          TextButton(onPressed: _resetFilters, child: const Text('清除筛选条件')),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: _editable(
          key: ContentKeys.footer,
          label: '页脚',
          fallback: text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

const TextStyle _monoStyle = TextStyle(
  fontSize: 16,
  fontFamily: 'Consolas',
  fontFamilyFallback: ['monospace', 'Courier New'],
);

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text(
              '数据加载失败，请检查 assets/data 下的 JSON 文件',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
