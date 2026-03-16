// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:galaxy_ios/main.dart';

void main() {
  late Directory hiveTestDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    hiveTestDir = await Directory.systemTemp.createTemp('galaxy_ios_hive_test_');
    Hive.init(hiveTestDir.path);

    // 让 MqttController 能正常读取 box。
    await Hive.openBox('settings');
    await Hive.openBox('topics');
    await Hive.openBox('messages');
    await Hive.openBox('profiles');
  });

  tearDownAll(() async {
    // Windows 下 Hive 关箱/删除目录偶发卡住，导致测试超时。
    // 这里尽量触发关闭，但不 await、不删除目录，避免 tearDownAll 超时。
    Hive.close();
  });

  testWidgets('App boot smoke test', (WidgetTester tester) async {
    // 仅做启动冒烟测试：能正常构建并出现标题即可。
    await tester.pumpWidget(const MqttApp());

    // App 启动过程中 controller.initialize() 内部有一个 500ms 的延迟 timer，
    // 测试环境会检测“残留 timer”。这里主动推进时间，让该 timer 执行完毕。
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.textContaining('MQTT'), findsWidgets);
  });
}
