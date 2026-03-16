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
    await Hive.close();
    if (hiveTestDir.existsSync()) {
      await hiveTestDir.delete(recursive: true);
    }
  });

  testWidgets('App boot smoke test', (WidgetTester tester) async {
    // 仅做启动冒烟测试：能正常构建并出现标题即可。
    await tester.pumpWidget(const MqttApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('MQTT'), findsWidgets);
  });
}
