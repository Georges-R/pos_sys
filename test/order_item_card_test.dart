import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/custom_widgets/order_item_card/order_item_card.dart';

Widget _host(double width,
    {required String name, required int qty, required double unitPrice}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: OrderItemCard(
          productName: name,
          quantity: qty,
          unitPrice: unitPrice,
          onIncrease: () {},
          onDecrease: () {},
          onRemove: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the name, the unit line and the line total',
      (tester) async {
    await tester.pumpWidget(
      _host(400, name: 'testtt', qty: 2, unitPrice: 4.16),
    );

    expect(find.text('testtt'), findsOneWidget);
    expect(find.text('2 x \$4.16'), findsOneWidget);
    expect(find.text('\$8.32'), findsOneWidget);
  });

  // The cart panel is narrowest on a 900pt window, where the scanner column
  // takes its 380pt minimum. A long name next to a four-figure total is the
  // worst case the row has to survive.
  for (final name in ['testtt', 'Imported Belgian Dark Chocolate 200g Bar']) {
    testWidgets('fits the narrowest cart panel: "${name.split(' ').first}"',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(520, name: name, qty: 12, unitPrice: 1234.56),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every quantity control is still tappable', (tester) async {
    var increases = 0, decreases = 0, removals = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: OrderItemCard(
              productName: 'testtt',
              quantity: 1,
              unitPrice: 4.16,
              onIncrease: () => increases++,
              onDecrease: () => decreases++,
              onRemove: () => removals++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect([increases, decreases, removals], [1, 1, 1]);
  });

  testWidgets('a long press reaches the card', (tester) async {
    var longPresses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: OrderItemCard(
              productName: 'testtt',
              quantity: 1,
              unitPrice: 4.16,
              onLongPress: () => longPresses++,
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('testtt'));
    await tester.pump();

    expect(longPresses, 1);
  });
}
