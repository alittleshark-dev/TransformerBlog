import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'config_api.dart';
import 'data_service.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.dataService = const DataService(api: ConfigApi())});

  final DataService dataService;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppSettings _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          // 只是首屏加载前的占位，页面拿到 profile.json 后会改成 siteTitle
          title: '个人网站',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: _settings.seedColor),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _settings.seedColor,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: _settings.themeMode,
          home: HomePage(
            settings: _settings,
            dataService: widget.dataService,
          ),
        );
      },
    );
  }
}
