// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:galaxy_ios/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    // 由于 App 初始化依赖 Hive.box(...)（在 MqttController 构造时即访问），
    // 所以测试里需要先 init + openBox。
    final tmp = await Directory.systemTemp.createTemp('galaxy-ios-test-');
    Hive.init(tmp.path);
    await Hive.openBox('settings');
    await Hive.openBox('topics');
    await Hive.openBox('messages');

    // App 主入口是 MqttApp（非模板自带 Counter/MyApp）。
    await tester.pumpWidget(const MqttApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);

    await Hive.close();
    await tmp.delete(recursive: true);
  });
}
