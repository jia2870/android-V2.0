import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_asg/utils/money_format.dart';

/// Feeds [input] through the formatter as if it had just been typed, with the
/// caret sitting at the end of the text.
TextEditingValue typed(String input, {String previous = ''}) {
  return const MoneyInputFormatter().formatEditUpdate(
    TextEditingValue(
      text: previous,
      selection: TextSelection.collapsed(offset: previous.length),
    ),
    TextEditingValue(
      text: input,
      selection: TextSelection.collapsed(offset: input.length),
    ),
  );
}

void main() {
  group('MoneyFormat', () {
    test('displays amounts with separators and two decimals', () {
      expect(MoneyFormat.display(8000), '8,000.00');
      expect(MoneyFormat.display(1000000), '1,000,000.00');
      expect(MoneyFormat.display(0), '0.00');
      expect(MoneyFormat.display(1234.5), '1,234.50');
    });

    test('parses grouped text back into a plain number', () {
      expect(MoneyFormat.parse('8,000.00'), 8000.0);
      expect(MoneyFormat.parse('1,000,000.00'), 1000000.0);
      expect(MoneyFormat.parse('  1,234.56 '), 1234.56);
      expect(MoneyFormat.parse(''), isNull);
      expect(MoneyFormat.parse('abc'), isNull);
      expect(MoneyFormat.parseOrZero(null), 0);
    });

    test('blanks out non-positive amounts when filling a field', () {
      expect(MoneyFormat.toField(0), '');
      expect(MoneyFormat.toField(null), '');
      expect(MoneyFormat.toField(8000), '8,000.00');
    });

    test('clamps absurd amounts for display and parse', () {
      expect(MoneyFormat.clamp(1e18), MoneyFormat.maxAmount);
      expect(MoneyFormat.display(1e18), MoneyFormat.display(MoneyFormat.maxAmount));
      expect(MoneyFormat.parse('1,000,000,000,000,000,000.00'), MoneyFormat.maxAmount);
      expect(MoneyFormat.toField(1e18), MoneyFormat.display(MoneyFormat.maxAmount));
    });

    test('survives a display -> parse -> display round trip', () {
      for (final amount in [0.0, 5.0, 999.99, 8000.0, 1234567.89]) {
        expect(MoneyFormat.parse(MoneyFormat.display(amount)), amount);
      }
    });
  });

  group('MoneyInputFormatter', () {
    test('groups digits as they are typed', () {
      expect(typed('8000').text, '8,000');
      expect(typed('1000000').text, '1,000,000');
      expect(typed('999').text, '999');
    });

    test('keeps the caret after the digit that was just entered', () {
      final value = typed('8000');
      expect(value.text, '8,000');
      expect(value.selection.baseOffset, value.text.length);
    });

    test('accepts a decimal part but caps it at two digits', () {
      expect(typed('1234.5').text, '1,234.5');
      expect(typed('1234.56').text, '1,234.56');
      expect(typed('1234.5678').text, '1,234.56');
    });

    test('allows only one decimal point and drops other characters', () {
      expect(typed('1.2.3').text, '1.23');
      expect(typed('12ab34').text, '1,234');
    });

    test('normalises a leading decimal point and stray leading zeros', () {
      expect(typed('.5').text, '0.5');
      expect(typed('007').text, '7');
      expect(typed('0').text, '0');
    });

    test('clears the field when every character is deleted', () {
      expect(typed('', previous: '8,000').text, '');
    });

    test('regroups correctly when a digit is removed', () {
      final value = typed('1,000,00', previous: '1,000,000');
      expect(value.text, '100,000');
    });
  });
}
