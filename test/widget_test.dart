import 'package:flutter_test/flutter_test.dart';
import 'package:joy_stickcontroller/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ControllerApp());
    expect(find.byType(ControllerApp), findsOneWidget);
  });
}
