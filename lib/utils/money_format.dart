import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class MoneyFormat {
  MoneyFormat._();

  static const int decimalDigits = 2;

  /// Ceiling for user-entered amounts (salary, savings, debts, etc.).
  static const double maxAmount = 9999999.99;

  /// Safety ceiling for calculated results (recommended budget, totals).
  static const double maxCalculated = 999999999999.99;

  static final NumberFormat _display = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _grouped = NumberFormat('#,##0', 'en_US');

  static double clamp(num value) {
    if (value.isNaN || value.isInfinite) return 0;
    if (value <= 0) return 0;
    if (value >= maxAmount) return maxAmount;
    return value.toDouble();
  }

  /// Clamp calculated money (e.g. recommended budget) — not the input limit.
  static double clampCalculated(num value) {
    if (value.isNaN || value.isInfinite) return 0;
    if (value <= 0) return 0;
    if (value >= maxCalculated) return maxCalculated;
    return value.toDouble();
  }

  static String display(num value) => _display.format(clamp(value));

  static String displayCalculated(num value) =>
      _display.format(clampCalculated(value));

  static String toField(num? value) =>
      (value == null || value <= 0) ? '' : display(value);

  static String groupInteger(String digits) {
    if (digits.isEmpty) return '';
    final parsed = int.tryParse(digits);
    if (parsed == null) return digits;
    return _grouped.format(parsed);
  }

  static double? parse(String? text) {
    if (text == null) return null;
    final cleaned = text.replaceAll(',', '').replaceAll('\$', '').trim();
    if (cleaned.isEmpty) return null;
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return null;
    return clamp(parsed);
  }

  static double parseOrZero(String? text) => parse(text) ?? 0;
}

class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({this.decimalDigits = MoneyFormat.decimalDigits});

  final int decimalDigits;

  static const int _maxIntegerDigits = 7;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    if (raw.isEmpty) return newValue;

    final caret = newValue.selection.end;
    final kept = StringBuffer();
    var keptBeforeCaret = 0;
    var hasDot = false;

    for (var i = 0; i < raw.length; i++) {
      final char = raw[i];
      final code = char.codeUnitAt(0);
      final isDigit = code >= 0x30 && code <= 0x39;
      final isDot = char == '.' && decimalDigits > 0 && !hasDot;
      if (!isDigit && !isDot) continue;
      if (isDot) hasDot = true;
      kept.write(char);
      if (i < caret) keptBeforeCaret++;
    }

    var text = kept.toString();
    if (text.isEmpty) return const TextEditingValue();

    if (text.startsWith('.')) {
      text = '0$text';
      keptBeforeCaret++;
    }

    final dot = text.indexOf('.');
    final integerInput = dot == -1 ? text : text.substring(0, dot);
    final decimalInput = dot == -1 ? null : text.substring(dot + 1);

    final integerPart = integerInput.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    keptBeforeCaret -= integerInput.length - integerPart.length;

    if (integerPart.length > _maxIntegerDigits) return oldValue;

    final buffer = StringBuffer(MoneyFormat.groupInteger(integerPart));
    if (decimalInput != null) {
      buffer.write('.');
      buffer.write(decimalInput.length > decimalDigits
          ? decimalInput.substring(0, decimalDigits)
          : decimalInput);
    }
    final formatted = buffer.toString();

    var offset = formatted.length;
    if (keptBeforeCaret <= 0) {
      offset = 0;
    } else {
      var seen = 0;
      for (var i = 0; i < formatted.length; i++) {
        if (formatted[i] != ',') seen++;
        if (seen == keptBeforeCaret) {
          offset = i + 1;
          break;
        }
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
