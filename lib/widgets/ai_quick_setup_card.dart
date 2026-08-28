import 'package:flutter/material.dart';

import '../models/quick_setup_draft.dart';
import '../services/preference_extraction_service.dart';
import '../utils/money_format.dart';

class AIQuickSetupCard extends StatefulWidget {
  const AIQuickSetupCard({
    super.key,
    required this.isDark,
    required this.recommendedBudget,
    required this.onComplete,
    required this.onSkip,
  });

  final bool isDark;
  final double recommendedBudget;
  final void Function(QuickSetupDraft draft) onComplete;
  final VoidCallback onSkip;

  @override
  State<AIQuickSetupCard> createState() => _AIQuickSetupCardState();
}

class _AIQuickSetupCardState extends State<AIQuickSetupCard> {
  static const _purposes = ['Own Stay', 'Investment', 'Both'];
  static const _propertyTypeOptions = [
    'Apartment',
    'Condominium',
    'Terrace',
    'Semi-D',
    'Bungalow',
  ];
  static const _areaChips = [
    'KLCC',
    'Petaling Jaya',
    'Subang Jaya',
    'Penang',
    'Johor Bahru',
    'Shah Alam',
    'Cheras',
    'Puchong',
  ];
  static const _bedroomOptions = [1, 2, 3, 4, 5];

  int _step = 0;
  String? _purpose;
  final _locations = <String>[];
  final _excluded = <String>[];
  final _selectedTypes = <String>[];
  int? _bedrooms;
  String? _priceRange;

  final _customAreaController = TextEditingController();
  final _excludeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.recommendedBudget > 0) {
      _priceRange =
          PreferenceExtractionService.budgetToRange(widget.recommendedBudget);
    }
  }

  @override
  void dispose() {
    _customAreaController.dispose();
    _excludeController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 1) {
      _applyCustomArea();
      _applyExclude();
    }
    if (_step < 4) {
      setState(() => _step++);
      return;
    }
    _finish();
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _purpose != null;
      case 1:
        return _locations.isNotEmpty;
      case 2:
        return _selectedTypes.isNotEmpty;
      case 3:
        return _bedrooms != null;
      case 4:
        return _priceRange != null && _priceRange!.isNotEmpty;
      default:
        return false;
    }
  }

  void _finish() {
    widget.onComplete(QuickSetupDraft(
      purpose: _purpose,
      locations: List.of(_locations),
      excludedLocations: List.of(_excluded),
      propertyTypes: List.of(_selectedTypes),
      bedrooms: _bedrooms,
      priceRange: _priceRange,
    ));
  }

  void _toggleLocation(String area) {
    setState(() {
      if (_locations.contains(area)) {
        _locations.remove(area);
      } else {
        _locations.add(area);
      }
    });
  }

  void _toggleType(String type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
    });
  }

  void _applyCustomArea() {
    final text = _customAreaController.text.trim();
    if (text.isEmpty) return;
    for (final part in text.split(RegExp(r'[,;/]'))) {
      final area = part.trim();
      if (area.isNotEmpty && !_locations.contains(area)) {
        _locations.add(area);
      }
    }
    _customAreaController.clear();
  }

  void _applyExclude() {
    final text = _excludeController.text.trim();
    if (text.isEmpty) return;
    for (final part in text.split(RegExp(r'[,;/]'))) {
      final area = part.trim();
      if (area.isNotEmpty && !_excluded.contains(area)) {
        _excluded.add(area);
      }
    }
    _excludeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final borderColor =
        widget.isDark ? Colors.blue.withValues(alpha: 0.35) : Colors.blue[100]!;
    final compactHeight = MediaQuery.sizeOf(context).height < 500;

    return Card(
      color: cardColor,
      elevation: widget.isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.all(compactHeight ? 10 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, size: 20, color: Colors.blue[400]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Quick setup (${_step + 1}/5)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onSkip,
                  style: compactHeight
                      ? TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        )
                      : null,
                  child: const Text('Skip', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            SizedBox(height: compactHeight ? 3 : 6),
            LinearProgressIndicator(
              value: (_step + 1) / 5,
              backgroundColor:
                  widget.isDark ? Colors.white12 : Colors.blue[50],
              color: Colors.blue,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            SizedBox(height: compactHeight ? 8 : 16),
            _buildStepContent(),
            SizedBox(height: compactHeight ? 8 : 16),
            Row(
              children: [
                if (_step > 0)
                  TextButton(onPressed: _back, child: const Text('Back'))
                else
                  const SizedBox(width: 64),
                const Spacer(),
                FilledButton(
                  onPressed: _canProceed() ? _next : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    visualDensity:
                        compactHeight ? VisualDensity.compact : null,
                  ),
                  child: Text(_step == 4 ? 'Done' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _stepBlock(
          title: 'What is this property for?',
          subtitle: 'Like a real agent would ask first.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _purposes
                .map(
                  (p) => ChoiceChip(
                    label: Text(p),
                    selected: _purpose == p,
                    onSelected: (_) => setState(() => _purpose = p),
                  ),
                )
                .toList(),
          ),
        );
      case 1:
        return _stepBlock(
          title: 'Which areas interest you?',
          subtitle: 'Pick one or more. You can type others below.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _areaChips
                    .map(
                      (a) => FilterChip(
                        label: Text(a, style: const TextStyle(fontSize: 12)),
                        selected: _locations.contains(a),
                        onSelected: (_) => _toggleLocation(a),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customAreaController,
                decoration: InputDecoration(
                  hintText: 'Other areas (e.g. Mont Kiara, Bangsar)',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) {
                  _applyCustomArea();
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Areas to avoid (optional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _excludeController,
                decoration: InputDecoration(
                  hintText: 'e.g. Putrajaya, Rawang',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) {
                  _applyExclude();
                  setState(() {});
                },
              ),
              if (_locations.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Selected: ${_locations.join(', ')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],
              if (_excluded.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Avoid: ${_excluded.join(', ')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark ? Colors.orange[200] : Colors.orange[800],
                  ),
                ),
              ],
            ],
          ),
        );
      case 2:
        return _stepBlock(
          title: 'Property type',
          subtitle: 'Select all that apply.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _propertyTypeOptions
                .map(
                  (t) => FilterChip(
                    label: Text(t, style: const TextStyle(fontSize: 12)),
                    selected: _selectedTypes.contains(t),
                    onSelected: (_) => _toggleType(t),
                  ),
                )
                .toList(),
          ),
        );
      case 3:
        return _stepBlock(
          title: 'How many bedrooms?',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _bedroomOptions
                .map(
                  (b) => ChoiceChip(
                    label: Text(b >= 5 ? '5+' : '$b'),
                    selected: _bedrooms == b,
                    onSelected: (_) => setState(() => _bedrooms = b),
                  ),
                )
                .toList(),
          ),
        );
      case 4:
        return _stepBlock(
          title: 'Budget range',
          subtitle: widget.recommendedBudget > 0
              ? 'Profile budget: ${MoneyFormat.display(widget.recommendedBudget)}'
              : 'Pick the range that fits you.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PreferenceExtractionService.priceRangeLabels
                .map(
                  (label) => ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    selected: _priceRange == label,
                    onSelected: (_) => setState(() => _priceRange = label),
                  ),
                )
                .toList(),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _stepBlock({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: widget.isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
