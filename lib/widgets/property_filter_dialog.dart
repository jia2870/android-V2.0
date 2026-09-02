import 'package:flutter/material.dart';

import '../utils/money_format.dart';
import 'money_form_field.dart';

class PropertyFilterSelection {
  const PropertyFilterSelection({
    this.state,
    this.district,
    this.propertyType,
    this.tenure,
    this.bedrooms,
    this.minPrice,
    this.maxPrice,
    this.districts = const [],
    this.clearAll = false,
  });

  final String? state;
  final String? district;
  final String? propertyType;
  final String? tenure;
  final int? bedrooms;
  final int? minPrice;
  final int? maxPrice;
  final List<String> districts;
  final bool clearAll;
}

class PropertyFilterDialog extends StatefulWidget {
  const PropertyFilterDialog({
    super.key,
    required this.states,
    required this.initialDistricts,
    required this.propertyTypes,
    required this.tenureTypes,
    required this.bedroomOptions,
    required this.loadDistricts,
    this.initialState,
    this.initialDistrict,
    this.initialPropertyType,
    this.initialTenure,
    this.initialBedrooms,
    this.initialMinPrice,
    this.initialMaxPrice,
  });

  final List<String> states;
  final List<String> initialDistricts;
  final List<String> propertyTypes;
  final List<String> tenureTypes;
  final List<int> bedroomOptions;
  final Future<List<String>> Function(String state) loadDistricts;
  final String? initialState;
  final String? initialDistrict;
  final String? initialPropertyType;
  final String? initialTenure;
  final int? initialBedrooms;
  final int? initialMinPrice;
  final int? initialMaxPrice;

  @override
  State<PropertyFilterDialog> createState() => _PropertyFilterDialogState();
}

class _PropertyFilterDialogState extends State<PropertyFilterDialog> {
  late String? _state;
  late String? _district;
  late String? _propertyType;
  late String? _tenure;
  late int? _bedrooms;
  late List<String> _districts;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  bool _loadingDistricts = false;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _district = widget.initialDistrict;
    _propertyType = widget.initialPropertyType;
    _tenure = widget.initialTenure;
    _bedrooms = widget.initialBedrooms;
    _districts = List<String>.of(widget.initialDistricts);
    _minPriceController = TextEditingController(
      text: widget.initialMinPrice == null
          ? ''
          : MoneyFormat.toField(widget.initialMinPrice!.toDouble()),
    );
    _maxPriceController = TextEditingController(
      text: widget.initialMaxPrice == null
          ? ''
          : MoneyFormat.toField(widget.initialMaxPrice!.toDouble()),
    );

    if (_state != null && _districts.isEmpty) {
      _loadDistricts(_state!);
    }
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadDistricts(String state) async {
    setState(() => _loadingDistricts = true);
    try {
      final districts = await widget.loadDistricts(state);
      if (!mounted || _state != state) return;
      setState(() {
        _districts = districts;
        _loadingDistricts = false;
      });
    } catch (_) {
      if (!mounted || _state != state) return;
      setState(() => _loadingDistricts = false);
    }
  }

  void _apply() {
    Navigator.pop(
      context,
      PropertyFilterSelection(
        state: _state,
        district: _district,
        propertyType: _propertyType,
        tenure: _tenure,
        bedrooms: _bedrooms,
        minPrice: MoneyFormat.parse(_minPriceController.text)?.round(),
        maxPrice: MoneyFormat.parse(_maxPriceController.text)?.round(),
        districts: List<String>.unmodifiable(_districts),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter Properties',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _state,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All States'),
                        ),
                        ...widget.states.map(
                          (state) => DropdownMenuItem(
                            value: state,
                            child: Text(state),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _state = value;
                          _district = null;
                          _districts = [];
                        });
                        if (value != null) _loadDistricts(value);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_state),
                      initialValue: _district,
                      decoration: InputDecoration(
                        labelText: 'District',
                        border: const OutlineInputBorder(),
                        suffixIcon: _loadingDistricts
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Districts'),
                        ),
                        ..._districts.map(
                          (district) => DropdownMenuItem(
                            value: district,
                            child: Text(district),
                          ),
                        ),
                      ],
                      onChanged: _loadingDistricts
                          ? null
                          : (value) => setState(() => _district = value),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _propertyType,
                      decoration: const InputDecoration(
                        labelText: 'Property Type',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Types'),
                        ),
                        ...widget.propertyTypes.map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _propertyType = value),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _tenure,
                      decoration: const InputDecoration(
                        labelText: 'Tenure',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Tenure'),
                        ),
                        ...widget.tenureTypes.map(
                          (tenure) => DropdownMenuItem(
                            value: tenure,
                            child: Text(tenure),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _tenure = value),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: _bedrooms,
                      decoration: const InputDecoration(
                        labelText: 'Bedrooms',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Any')),
                        ...widget.bedroomOptions.map(
                          (bedrooms) => DropdownMenuItem(
                            value: bedrooms,
                            child: Text('$bedrooms+'),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _bedrooms = value),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: MoneyFormField(
                            controller: _minPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Min Price',
                              prefixText: 'RM ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MoneyFormField(
                            controller: _maxPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Max Price',
                              prefixText: 'RM ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        const PropertyFilterSelection(clearAll: true),
                      ),
                      child: const Text('Clear Filters'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _apply,
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
