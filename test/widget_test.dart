import 'package:flutter_test/flutter_test.dart';
import 'package:grand_piano/main.dart';

void main() {
  testWidgets('App smoke test — GrandPianoApp builds without error',
      (WidgetTester tester) async {
    // Pump the top-level app widget. SplashScreen uses animations but does not
    // require audio, so this is safe to run in the test environment.
    await tester.pumpWidget(const GrandPianoApp());
    // Verify the widget tree rendered at least one frame without throwing.
    expect(find.byType(GrandPianoApp), findsOneWidget);
  });
}
