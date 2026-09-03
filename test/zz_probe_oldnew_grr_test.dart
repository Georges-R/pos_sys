import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/custom_widgets/product_card/product_card.dart';

/// Exact copy of the pre-change ProductCard (git show HEAD:...).
class OldProductCard extends StatelessWidget {
  const OldProductCard({super.key, required this.productName, required this.price});
  final String productName;
  final double price;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  productName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4.0),
              Flexible(
                child: Text(
                  '\$${price.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const names = <String>[
  'Coca Cola 1.5L Bottle',
  'Chocolate Chip Cookies Family Pack',
];

Widget host({required double gridWidth, required bool isNew}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: gridWidth + 24, // GridView's own EdgeInsets.all(12)
          height: 700,
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: names.length,
            gridDelegate: isNew
                ? const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.15)
                : const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.25),
            itemBuilder: (c, i) => isNew
                ? ProductCard(
                    productName: names[i], price: 4.16, exchangeRate: 90000)
                : OldProductCard(productName: names[i], price: 4.16),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // grid content width = windowWidth - 400 (sidebar) - 24 (grid padding)
  const cases = <String, double>{
    '1366x1024': 942,
    '1180x820': 756,
    '960x720': 536,
  };

  for (final entry in cases.entries) {
    for (final isNew in [false, true]) {
      testWidgets('${isNew ? "NEW" : "OLD"} @ ${entry.key}', (tester) async {
        tester.view.devicePixelRatio = 2.0;
        tester.view.physicalSize = const Size(4000, 2000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(host(gridWidth: entry.value, isNew: isNew));
        await tester.pump();
        final tile = (find
                .byType(isNew ? ProductCard : OldProductCard)
                .evaluate()
                .first
                .findRenderObject() as RenderBox)
            .size;
        debugPrint('${isNew ? "NEW" : "OLD"} ${entry.key} tile=$tile');
        for (final n in names) {
          final rp = tester.renderObject<RenderParagraph>(find.text(n));
          debugPrint('   "$n" box=${rp.size.height.toStringAsFixed(2)} '
              'needs=${rp.textSize.height.toStringAsFixed(2)} '
              'cut=${(rp.textSize.height - rp.size.height).toStringAsFixed(2)} '
              'ellipsized=${rp.didExceedMaxLines}');
        }
      });
    }
  }
}
