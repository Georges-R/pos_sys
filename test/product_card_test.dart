import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/custom_widgets/product_card/product_card.dart';

Widget _host(Size tile, {required double price, required double rate}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: tile.width,
          height: tile.height,
          child: ProductCard(
            productName: 'Long product name that wraps to two lines',
            price: price,
            exchangeRate: rate,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the price in USD and LBP', (tester) async {
    await tester.pumpWidget(
      _host(const Size(200, 174), price: 4.16, rate: 89000),
    );

    expect(find.text('\$4.16'), findsOneWidget);
    expect(find.text('370,240 LBP'), findsOneWidget);
  });

  testWidgets('drops the LBP line when no rate is set', (tester) async {
    await tester.pumpWidget(
      _host(const Size(200, 174), price: 4.16, rate: 0),
    );

    expect(find.text('\$4.16'), findsOneWidget);
    expect(find.textContaining('LBP'), findsNothing);
  });

  // The grid hands out whatever a row division leaves; the smallest real
  // tile is a squeezed cell on a narrow window.
  for (final tile in [const Size(200, 174), const Size(140, 122)]) {
    testWidgets('renders without overflow at ${tile.width}x${tile.height}',
        (tester) async {
      await tester.pumpWidget(
        _host(tile, price: 1234.56, rate: 89000),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
