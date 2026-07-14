// Smoke test for the app shell + main menu. The ember layer animates forever, so
// we pump fixed frames (never pumpAndSettle).

import 'package:flutter_test/flutter_test.dart';
import 'package:ak_reader/main.dart';
import 'package:ak_reader/stores/kv_store.dart';
import 'package:ak_reader/ui/ash_fx.dart';

void main() {
  testWidgets('main menu renders the ambient layer and title', (tester) async {
    await tester.pumpWidget(AkReaderApp(kv: MemoryKeyValueStore()));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(AshFx), findsOneWidget);
    expect(find.text('Story Reader'), findsOneWidget);
    expect(find.text('Reading Guide'), findsOneWidget);
  });
}
