// Smoke test for the temporary data-layer screen (PortSmokeApp). Replaced the
// default `flutter create` counter test, which referenced a non-existent MyApp.

import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/main.dart';

void main() {
  testWidgets('smoke screen renders parsed story items', (tester) async {
    await tester.pumpWidget(const PortSmokeApp());
    await tester.pumpAndSettle();

    // The sample runs through normalizeStory and renders as a list.
    expect(find.text('Data-layer smoke test'), findsOneWidget);
    // Amiya's first line survives nickname substitution and speaker resolution.
    expect(find.textContaining('Amiya:'), findsWidgets);
    // The decision line renders as a CHOICE row.
    expect(find.textContaining('CHOICE:'), findsOneWidget);
  });
}
