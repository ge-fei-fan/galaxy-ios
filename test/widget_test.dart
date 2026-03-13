import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:galaxy_ios/main.dart';

void main() {
  setUpAll(() async {
    // 由于测试不会执行 main()，需要手动初始化 Hive 并打开 box，
    // 否则 MqttController 构造函数里 Hive.box(...) 会报错。
    final dir = await Directory.systemTemp.createTemp('galaxy_ios_test_');
    Hive.init(dir.path);
    await Hive.openBox('settings');
    await Hive.openBox('topics');
    await Hive.openBox('messages');
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('App boots and shows bottom tabs', (WidgetTester tester) async {
    // 只做最小化冒烟测试：能启动并渲染出底部 Tab 文案。
    await tester.pumpWidget(
      const MqttApp(platformOverride: TargetPlatform.iOS),
    );
    await tester.pump();

    expect(find.text('配置'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('消息'), findsOneWidget);
  });
}
