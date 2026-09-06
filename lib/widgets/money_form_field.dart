import 'package:flutter/material.dart';
import '../utils/money_format.dart';

class MoneyFormField extends StatefulWidget {
  const MoneyFormField({
    super.key,
    required this.controller,
    this.decoration = const InputDecoration(),
    this.style,
    this.validator,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.scrollPadding = const EdgeInsets.all(20),
    this.calculated = false,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final TextStyle? style;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final EdgeInsets scrollPadding;

  /// Use the calculated-money ceiling so summed totals are not capped at
  /// [MoneyFormat.maxAmount] (e.g. Monthly Commitments from all debts).
  final bool calculated;

  @override
  State<MoneyFormField> createState() => _MoneyFormFieldState();
}

class _MoneyFormFieldState extends State<MoneyFormField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_normalizeOnBlur);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_normalizeOnBlur);
    _focusNode.dispose();
    super.dispose();
  }

  void _normalizeOnBlur() {
    if (_focusNode.hasFocus) return;
    final value = MoneyFormat.parse(
      widget.controller.text,
      calculated: widget.calculated,
    );
    if (value == null) return;

    final normalized = MoneyFormat.display(value, calculated: widget.calculated);
    if (normalized == widget.controller.text) return;

    widget.controller.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    widget.onChanged?.call(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: false,
      decoration: widget.decoration,
      style: widget.style,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      validator: widget.validator,
      scrollPadding: widget.scrollPadding,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        MoneyInputFormatter(calculated: widget.calculated),
      ],
    );
  }
}
