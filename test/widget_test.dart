import 'package:flutter_test/flutter_test.dart';
import 'package:perruques_salon/auth/auth_provider.dart';
import 'package:perruques_salon/main.dart';

void main() {
  testWidgets('App renders login screen', (tester) async {
    await tester.pumpWidget(MyApp(auth: AuthProvider()));
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
