import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map_navigator_example/main.dart';

void main() {
  testWidgets('NavigationDemoApp builds test', (WidgetTester tester) async {
    await tester.pumpWidget(const NavigationDemoApp());
    expect(find.text('Flutter Map Navigator SDK'), findsOneWidget);
  });
}
