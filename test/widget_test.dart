import 'package:flutter_test/flutter_test.dart';
import 'package:joy_stickcontroller/main.dart';
import 'package:joy_stickcontroller/screens/controller_ui.dart';
void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget( ControllerUI());
    expect(find.byType(ControllerUI), findsOneWidget);

  });
}
