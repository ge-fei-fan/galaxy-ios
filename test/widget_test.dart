// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:galaxy_ios/main.dart';

void main() {
  testWidgets('App boot smoke test', (WidgetTester tester) async {
    // 仅做启动冒烟测试：能正常构建并出现标题即可。
    await tester.pumpWidget(const MqttApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('MQTT'), findsWidgets);
  });
}
