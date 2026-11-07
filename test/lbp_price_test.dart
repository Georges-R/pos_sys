import 'package:flutter_test/flutter_test.dart';
import 'package:pos/core/helpers/lbp_price.dart';

void main() {
  group('LbpPrice.parseCode', () {
    test('reads T or t followed by the amount', () {
      expect(LbpPrice.parseCode('T250000'), 250000);
      expect(LbpPrice.parseCode('t250000'), 250000);
      expect(LbpPrice.parseCode(' T 250000 '), 250000);
    });

    test('tolerates thousands separators', () {
      expect(LbpPrice.parseCode('T250,000'), 250000);
      expect(LbpPrice.parseCode('T1,500,000'), 1500000);
    });

    test('is not fooled by ordinary barcodes', () {
      for (final code in ['5285000000123', 'T', 'TT100', 'T12a', 'X100', '']) {
        expect(LbpPrice.parseCode(code), isNull, reason: code);
      }
    });
  });
}
