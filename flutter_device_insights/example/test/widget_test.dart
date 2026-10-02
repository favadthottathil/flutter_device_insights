// Smoke test for the Device Insights example app.
// Verifies the shell renders without hitting any platform channel.
// Golden tests for visual states are in golden_test.dart.

import 'golden_test.dart' show InsightsPageStub;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders AppBar title and initial output text', (tester) async {
    await tester.pumpWidget(const InsightsPageStub());
    await tester.pumpAndSettle();
    expect(find.text('Device insights'), findsOneWidget);
    expect(find.text('Tap a button'), findsOneWidget);
    expect(find.text('Not listening'), findsOneWidget);
  });
}
