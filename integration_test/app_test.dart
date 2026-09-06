import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:salon_booking/src/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('avvio sicuro senza backend configurato', (tester) async {
    await tester.pumpWidget(const SalonApp(backendReady: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('Il codice è pronto'), findsOneWidget);
  });
}
