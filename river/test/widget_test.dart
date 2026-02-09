import 'package:flutter_test/flutter_test.dart';
import 'package:river/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App renders login buttons', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const RiverApp());
    await tester.pumpAndSettle();

    expect(find.text('登录至RiverSide'), findsOneWidget);
    expect(find.text('登录至清水河畔'), findsOneWidget);
  });
}
