import 'package:flutter_test/flutter_test.dart';
import 'package:pos/core/routes/paths.dart';
import 'package:pos/http_client/local_storage/hive_service.dart';

import '../helpers/pos_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(bootStorage);
  tearDown(tearDownStorage);

  Future<void> openHistory(WidgetTester tester) async {
    await useTabletSurface(tester);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await withStorage(tester, () async {
      Future<void> sale(String id, DateTime date, double usd,
              {String type = 'immediate', String? status}) =>
          HiveService.storeSale(id, {
            'id': id,
            'items': [],
            'totalUSD': usd,
            'totalLBP': usd * 90000,
            'date': date.toIso8601String(),
            'type': type,
            if (status != null) 'status': status,
          });
      await sale('cash', today.add(const Duration(minutes: 1)), 5.0);
      await sale('tab', today.add(const Duration(minutes: 2)), 3.0,
          type: 'tab', status: 'open');
      // Always outside this year, whatever day the test runs on.
      await sale('old', today.subtract(const Duration(days: 400)), 50.0);
    });
    await tester.pumpWidget(posApp(initialRoute: Paths.salesListingScreen));
    await settle(tester);
  }

  testWidgets('opens on today, grouped under a header for the day',
      (tester) async {
    await openHistory(tester);

    expect(find.textContaining('Today  ·'), findsOneWidget);
    expect(find.text('Total: 8.00 \$'), findsOneWidget);
  });

  testWidgets('unpaid shows only the tabs still owed', (tester) async {
    await openHistory(tester);

    await tester.tap(find.text('Unpaid'));
    await settle(tester);
    expect(find.text('Total: 3.00 \$'), findsOneWidget);

    await tester.tap(find.text('Paid'));
    await settle(tester);
    expect(find.text('Total: 5.00 \$'), findsOneWidget);
  });

  testWidgets('a quick period widens the history', (tester) async {
    await openHistory(tester);

    await tester.tap(find.text('This year'));
    await settle(tester);
    expect(find.text('Total: 8.00 \$'), findsOneWidget,
        reason: 'the sale from over a year ago stays out');
  });

  testWidgets('pick dates asks for a from and a to', (tester) async {
    await openHistory(tester);

    await tester.tap(find.text('Pick dates'));
    await settle(tester);
    expect(find.text('Show sales from – to'), findsOneWidget);
  });

  testWidgets('the date picker fills the tablet, and still takes taps',
      (tester) async {
    await openHistory(tester);
    await tester.tap(find.text('Pick dates'));
    await settle(tester);

    // Flutter's own calendar is at most 384pt wide, putting Monday and
    // Wednesday about 105pt apart.
    final monday = tester.getCenter(find.text('M'));
    final wednesday = tester.getCenter(find.text('W'));
    expect(wednesday.dx - monday.dx, greaterThan(150));

    await tester.tap(find.text('Show'));
    await settle(tester);
    expect(find.text('Show sales from – to'), findsNothing);
    expect(find.text('Pick dates'), findsNothing,
        reason: 'the chip now shows the range that was confirmed');
  });
}
