import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/custom_widgets/totals_tiles/totals_tiles.dart';

Widget _host(double width, {required double usd, required double lbp}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: TotalsTiles(
            totalUSD: usd,
            totalLBP: lbp,
            usdFootnote: 'Includes 11% VAT  ·  \$1,223.34',
            lbpFootnote: '1 USD  =  89,000 LBP',
          ),
        ),
      ),
    ),
  );
}

void main() {
  // Checkout panel (iPad landscape minus padding), a mid width, and the
  // 400px cart sidebar minus its 12px padding.
  for (final width in [1318.0, 640.0, 376.0]) {
    testWidgets('renders without overflow at ${width}pt',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(width, usd: 12345.67, lbp: 1098765000),
      );
      expect(tester.takeException(), isNull);

      // Side by side when wide, stacked when narrow.
      final rowMode = find.ancestor(
        of: find.textContaining('LBP', findRichText: true).first,
        matching: find.byType(Row),
      );
      expect(rowMode, width < 620 ? findsNothing : findsWidgets);
    });
  }
}
