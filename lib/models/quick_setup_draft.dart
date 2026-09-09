import '../services/preference_extraction_service.dart';
import '../utils/affordability_context.dart';

class QuickSetupDraft {
  QuickSetupDraft({
    this.purpose,
    this.locations = const [],
    this.excludedLocations = const [],
    this.propertyTypes = const [],
    this.bedrooms,
    this.priceRange,
  });

  String? purpose;
  List<String> locations;
  List<String> excludedLocations;
  List<String> propertyTypes;
  int? bedrooms;
  String? priceRange;

  bool get isComplete =>
      purpose != null &&
      purpose!.isNotEmpty &&
      locations.isNotEmpty &&
      propertyTypes.isNotEmpty &&
      bedrooms != null &&
      priceRange != null &&
      priceRange!.isNotEmpty;

  int get completedStepCount {
    var count = 0;
    if (purpose != null && purpose!.isNotEmpty) count++;
    if (locations.isNotEmpty) count++;
    if (propertyTypes.isNotEmpty) count++;
    if (bedrooms != null) count++;
    if (priceRange != null && priceRange!.isNotEmpty) count++;
    return count;
  }

  ExtractedPreferences toPreferences(BuyerAffordabilitySnapshot affordability) {
    final purposeVal = purpose ?? 'Own Stay';
    final types = propertyTypes.isEmpty ? ['Apartment'] : propertyTypes;
    final range = priceRange ??
        PreferenceExtractionService.budgetToRange(affordability.recommendedBudget);
    final beds = bedrooms ?? 3;

    return ExtractedPreferences(
      purpose: purposeVal,
      propertyTypes: types,
      priceRange: range,
      bedrooms: beds,
      locations: locations,
      mustHaveFeatures: const [],
      excludedLocations: excludedLocations,
      summary: ExtractedPreferences.summaryFromFields(
        purpose: purposeVal,
        types: types,
        priceRange: range,
        bedrooms: beds,
        locations: locations,
        excludedLocations: excludedLocations,
      ),
      confidence: 0.9,
    );
  }

  String toConversationMessage() {
    final buffer = StringBuffer('I am looking for property for $purpose.');
    buffer.write(' Prefer ${propertyTypes.join(', ')}');
    buffer.write(' with $bedrooms bedrooms');
    if (locations.isNotEmpty) {
      buffer.write(' in ${locations.join(', ')}');
    }
    if (priceRange != null) buffer.write(', budget around $priceRange');
    if (excludedLocations.isNotEmpty) {
      buffer.write('. Please exclude ${excludedLocations.join(', ')}');
    }
    buffer.write('.');
    return buffer.toString();
  }
}
