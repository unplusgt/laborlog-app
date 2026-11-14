import 'package:flutter_test/flutter_test.dart';

import 'package:laborlog_app/main.dart';
import 'package:laborlog_app/screens/login_screen.dart';

void main() {
  testWidgets('La app arranca en la pantalla de login', (WidgetTester tester) async {
    await tester.pumpWidget(LaborLogApp());

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
