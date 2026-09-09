import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/property_model.dart';

class _StateResult<T> {
  final T? value;
  final bool isFallback;
  final String? fallbackState;
  const _StateResult(this.value, {required this.isFallback, this.fallbackState});

  static _StateResult<T> empty<T>() => _StateResult<T>(null, isFallback: false);
}

class NeighbourhoodInsight {
  final double? populationPercent;
  final double? crimePercent;
  final double? waterPercent;
  final double? incomeMean;
  final String? incomeLevel;
  final String? expenditureLevel;
  final int? schoolsTotal;
  final int? hospitalBedsTotal;

  final Set<String> fallbackFields;

  final String? fallbackState;

  const NeighbourhoodInsight({
    this.populationPercent,
    this.crimePercent,
    this.waterPercent,
    this.incomeMean,
    this.incomeLevel,
    this.expenditureLevel,
    this.schoolsTotal,
    this.hospitalBedsTotal,
    this.fallbackFields = const {},
    this.fallbackState,
  });

  factory NeighbourhoodInsight.empty() => const NeighbourhoodInsight();

  bool get hasFallbackData => fallbackFields.isNotEmpty && fallbackState != null;

  String? get fallbackNote {
    if (!hasFallbackData) return null;
    return 'Data marked with * comes from the neighboring $fallbackState and is for reference only.';
  }

  String _withMark(String text, String field) =>
      fallbackFields.contains(field) ? '$text *' : text;

  String get populationDisplay => populationPercent != null
      ? _withMark('${populationPercent!.toStringAsFixed(1)}% \n of Malaysia', 'population')
      : 'N/A';

  String get crimeDisplay => crimePercent != null
      ? _withMark('${crimePercent!.toStringAsFixed(1)}% \n of Malaysia', 'crime')
      : 'N/A';

  String get waterDisplay => waterPercent != null
      ? _withMark('${waterPercent!.toStringAsFixed(1)}% \n of Malaysia', 'water')
      : 'N/A';

  String get incomeDisplay =>
      incomeLevel != null ? _withMark(_levelLabel(incomeLevel!), 'income') : 'N/A';

  String get expenditureDisplay =>
      expenditureLevel != null ? _withMark(_costLabel(expenditureLevel!), 'expenditure') : 'N/A';

  String get schoolsDisplay =>
      schoolsTotal != null ? _withMark('$schoolsTotal Schools', 'schools') : 'N/A';

  String get hospitalBedsDisplay => hospitalBedsTotal != null
      ? _withMark('${_formatWithCommas(hospitalBedsTotal!)} Beds', 'hospitalBeds')
      : 'N/A';

  static String _levelLabel(String level) {
    switch (level) {
      case 'Low':
        return '🟢 Low';
      case 'Medium':
        return '🟡 Medium';
      case 'High':
        return '🔴 High';
      default:
        return level;
    }
  }

  static String _costLabel(String level) {
    switch (level) {
      case 'Low':
        return '🟢 Low Cost';
      case 'Medium':
        return '🟡 Medium Cost';
      case 'High':
        return '🔴 High Cost';
      default:
        return level;
    }
  }

  static String _formatWithCommas(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}

class NeighbourhoodInsightService {
  static const String _baseUrl = 'https://api.data.gov.my/data-catalogue';
  static const int _fetchLimit = 20000;
  static final Map<String, List<Map<String, dynamic>>> _cache = {};
  static const bool debugLogging = true;

  static const Map<String, String> _stateFallbackMap = {
    'putrajaya': 'Selangor',
    'w.p. putrajaya': 'Selangor',
    'wilayah persekutuan putrajaya': 'Selangor',
    'kuala lumpur': 'Selangor',
    'w.p. kuala lumpur': 'Selangor',
    'wilayah persekutuan kuala lumpur': 'Selangor',
    'labuan': 'Sabah',
    'w.p. labuan': 'Sabah',
    'wilayah persekutuan labuan': 'Sabah',
  };

  String? _fallbackStateFor(String state) {
    final key = state.trim().toLowerCase();
    return _stateFallbackMap[key];
  }

  void _log(String message) {
    if (debugLogging) {
      print('[NeighbourhoodInsight] $message');
    }
  }

  _StateResult<T> _withFallback<T>(String state, T? Function(String s) compute) {
    final direct = compute(state);
    if (direct != null) {
      return _StateResult<T>(direct, isFallback: false);
    }

    final fallback = _fallbackStateFor(state);
    if (fallback == null) return _StateResult.empty<T>();

    _log('"$state" has no data; trying fallback state "$fallback"');
    final fallbackValue = compute(fallback);
    if (fallbackValue == null) return _StateResult.empty<T>();

    return _StateResult<T>(fallbackValue, isFallback: true, fallbackState: fallback);
  }

  Future<NeighbourhoodInsight> getInsightForProperty(PropertyModel property) async {
    final state = property.state;
    final district = property.district;

    _log('=== getInsightForProperty START ===');
    _log('property.listingId=${property.listingId}, state="$state", district="$district"');

    if (state == null || state.trim().isEmpty) {
      _log('property.state is null or empty; Population/Crime/Water/Income will be N/A.');
    }

    final populationFuture = _fetchPopulationPercent(state);
    final crimeFuture = _fetchCrimePercent(state);
    final waterFuture = _fetchWaterPercent(state);
    final incomeFuture = _fetchIncome(state);
    final expenditureFuture = _fetchExpenditureLevel(state, district);
    final schoolsFuture = _fetchSchoolsTotal(state, district);
    final hospitalBedsFuture = _fetchHospitalBedsTotal(state, district);

    final population = await populationFuture;
    final crime = await crimeFuture;
    final water = await waterFuture;
    final income = await incomeFuture;
    final expenditure = await expenditureFuture;
    final schools = await schoolsFuture;
    final hospitalBeds = await hospitalBedsFuture;

    final fallbackFields = <String>{};
    String? fallbackState;
    void track(String field, _StateResult r) {
      if (r.isFallback) {
        fallbackFields.add(field);
        fallbackState ??= r.fallbackState;
      }
    }

    track('population', population);
    track('crime', crime);
    track('water', water);
    track('income', income);
    track('expenditure', expenditure);
    track('schools', schools);
    track('hospitalBeds', hospitalBeds);

    final incomeValue = income.value;

    final insight = NeighbourhoodInsight(
      populationPercent: population.value,
      crimePercent: crime.value,
      waterPercent: water.value,
      incomeMean: incomeValue?['mean'] as double?,
      incomeLevel: incomeValue?['level'] as String?,
      expenditureLevel: expenditure.value,
      schoolsTotal: schools.value,
      hospitalBedsTotal: hospitalBeds.value,
      fallbackFields: fallbackFields,
      fallbackState: fallbackState,
    );

    _log('=== RESULT: population=${insight.populationPercent}, crime=${insight.crimePercent}, '
        'water=${insight.waterPercent}, income=${insight.incomeMean}(${insight.incomeLevel}), '
        'expenditure=${insight.expenditureLevel}, schools=${insight.schoolsTotal}, '
        'beds=${insight.hospitalBedsTotal}, fallbackFields=$fallbackFields, '
        'fallbackState=$fallbackState ===');

    return insight;
  }

  Future<_StateResult<double>> _fetchPopulationPercent(String? state) async {
    if (state == null || state.trim().isEmpty) {
      return _StateResult.empty<double>();
    }

    try {
      final stateData = await _fetchDataset('population_state');
      final nationalData = await _fetchDataset('population_malaysia');

      bool isStateOverall(Map<String, dynamic> r) =>
          r['age']?.toString() == 'overall_age' &&
          r['sex']?.toString() == 'overall_sex' &&
          r['ethnicity']?.toString() == 'overall_ethnicity';

      bool isNationalOverall(Map<String, dynamic> r) =>
          r['age']?.toString() == 'overall' &&
          r['sex']?.toString() == 'both' &&
          r['ethnicity']?.toString() == 'overall';

      double? populationAtYear(List<Map<String, dynamic>> rows, int year) {
        for (final r in rows) {
          final date = DateTime.tryParse(r['date']?.toString() ?? '');
          if (date != null && date.year == year) {
            return (r['population'] as num?)?.toDouble();
          }
        }
        return null;
      }

      int? latestYear(List<Map<String, dynamic>> rows) {
        int? year;
        for (final r in rows) {
          final date = DateTime.tryParse(r['date']?.toString() ?? '');
          if (date != null && (year == null || date.year > year)) {
            year = date.year;
          }
        }
        return year;
      }

      final nationalRows = nationalData.where(isNationalOverall).toList();
      final nationalLatest = latestYear(nationalRows);
      if (nationalLatest == null) return _StateResult.empty<double>();

      double? computeForState(String s) {
        final rows = stateData
            .where((r) => isStateOverall(r) && _matchesState(r['state'], s))
            .toList();
        final year = latestYear(rows);
        if (year == null) return null;
        final statePop = populationAtYear(rows, year);
        if (statePop == null || statePop <= 0) return null;

        final malaysiaPop = populationAtYear(nationalRows, year) ??
            populationAtYear(nationalRows, nationalLatest);
        if (malaysiaPop == null || malaysiaPop <= 0) return null;

        final percent = statePop / malaysiaPop * 100;
        _log(
          'Population: $s $statePop / $malaysiaPop '
          '(stateYear=$year) = ${percent.toStringAsFixed(2)}%',
        );
        if (percent > 40) {
          _log('Population: WARNING unusually high share for "$s": $percent%');
        }
        return percent;
      }

      return _withFallback<double>(state, computeForState);
    } catch (e) {
      _log('Population -> EXCEPTION: $e');
      return _StateResult.empty<double>();
    }
  }

  Future<_StateResult<double>> _fetchCrimePercent(String? state) async {
    if (state == null) return _StateResult.empty<double>();
    try {
      final data = await _fetchDataset('crime_district');
      bool baseFilter(Map<String, dynamic> r) =>
          r['type']?.toString() == 'all' &&
              (r['category']?.toString() == 'assault' || r['category']?.toString() == 'property');

      final malaysiaRecords = data
          .where((r) =>
      baseFilter(r) && r['district']?.toString() == 'All' && r['state']?.toString() == 'Malaysia')
          .toList();
      final malaysiaCrime = _sumAtLatestYear(malaysiaRecords, 'crimes');
      if (malaysiaCrime == null || malaysiaCrime == 0) return _StateResult.empty<double>();

      double? computeForState(String s) {
        final records = data
            .where((r) =>
        baseFilter(r) && r['district']?.toString() == 'All' && _matchesState(r['state'], s))
            .toList();
        return _sumAtLatestYear(records, 'crimes');
      }

      final result = _withFallback<double>(state, computeForState);
      if (result.value == null) return _StateResult.empty<double>();
      return _StateResult<double>(
        result.value! / malaysiaCrime * 100,
        isFallback: result.isFallback,
        fallbackState: result.fallbackState,
      );
    } catch (e) {
      _log('Crime -> EXCEPTION: $e');
      return _StateResult.empty<double>();
    }
  }

  Future<_StateResult<double>> _fetchWaterPercent(String? state) async {
    if (state == null) return _StateResult.empty<double>();
    try {
      final data = await _fetchDataset('water_consumption');
      bool isRelevantSector(dynamic sector) {
        final v = sector?.toString().toLowerCase() ?? '';
        return v == 'domestic' || v.contains('non');
      }

      final malaysiaRecords =
      data.where((r) => isRelevantSector(r['sector']) && r['state']?.toString() == 'Malaysia').toList();
      final malaysiaWater = _sumAtLatestYear(malaysiaRecords, 'value');
      if (malaysiaWater == null || malaysiaWater == 0) return _StateResult.empty<double>();

      double? computeForState(String s) {
        final records = data.where((r) => isRelevantSector(r['sector']) && _matchesState(r['state'], s)).toList();
        return _sumAtLatestYear(records, 'value');
      }

      final result = _withFallback<double>(state, computeForState);
      if (result.value == null) return _StateResult.empty<double>();
      return _StateResult<double>(
        result.value! / malaysiaWater * 100,
        isFallback: result.isFallback,
        fallbackState: result.fallbackState,
      );
    } catch (e) {
      _log('Water -> EXCEPTION: $e');
      return _StateResult.empty<double>();
    }
  }

  Future<_StateResult<Map<String, dynamic>>> _fetchIncome(String? state) async {
    if (state == null) return _StateResult.empty<Map<String, dynamic>>();
    try {
      final data = await _fetchDataset('hh_income_state');

      Map<String, dynamic>? computeForState(String s) {
        final records = data.where((r) => _matchesState(r['state'], s)).toList();
        if (records.isEmpty) return null;

        records.sort((a, b) {
          final da = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(0);
          final db = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(0);
          return db.compareTo(da);
        });

        final mean = (records.first['income_mean'] as num?)?.toDouble();
        if (mean == null) return null;

        String level;
        if (mean < 5200) {
          level = 'Low';
        } else if (mean <= 15000) {
          level = 'Medium';
        } else {
          level = 'High';
        }
        return {'mean': mean, 'level': level};
      }

      return _withFallback<Map<String, dynamic>>(state, computeForState);
    } catch (e) {
      _log('Income -> EXCEPTION: $e');
      return _StateResult.empty<Map<String, dynamic>>();
    }
  }

  Future<_StateResult<String>> _fetchExpenditureLevel(String? state, String? district) async {
    try {
      final data = await _fetchDataset('hies_district');

      final Map<String, Map<String, dynamic>> latestByDistrict = {};
      for (final r in data) {
        final d = r['district']?.toString();
        if (d == null || d.isEmpty) continue;
        final date = DateTime.tryParse(r['date']?.toString() ?? '');
        if (date == null) continue;
        final existing = latestByDistrict[d];
        if (existing == null) {
          latestByDistrict[d] = r;
        } else {
          final existingDate = DateTime.tryParse(existing['date']?.toString() ?? '');
          if (existingDate == null || date.isAfter(existingDate)) {
            latestByDistrict[d] = r;
          }
        }
      }

      final values = latestByDistrict.values
          .map((r) => (r['expenditure_mean'] as num?)?.toDouble())
          .whereType<double>()
          .toList()
        ..sort();
      if (values.isEmpty) return _StateResult.empty<String>();

      double? stateAverage(String s) {
        final stateValues = latestByDistrict.values
            .where((r) => _matchesState(r['state'], s))
            .map((r) => (r['expenditure_mean'] as num?)?.toDouble())
            .whereType<double>()
            .toList();
        if (stateValues.isEmpty) return null;
        return stateValues.reduce((a, b) => a + b) / stateValues.length;
      }

      double? target;
      bool isFallback = false;
      String? fallbackState;

      if (district != null) {
        for (final entry in latestByDistrict.entries) {
          if (_matchesDistrict(entry.key, district)) {
            target = (entry.value['expenditure_mean'] as num?)?.toDouble();
            break;
          }
        }
      }

      if (target == null && state != null) {
        final result = _withFallback<double>(state, stateAverage);
        target = result.value;
        isFallback = result.isFallback;
        fallbackState = result.fallbackState;
      }

      if (target == null) return _StateResult.empty<String>();

      final lowCutoffIndex = ((values.length * 0.33).floor()).clamp(0, values.length - 1);
      final highCutoffIndex = ((values.length * 0.66).floor()).clamp(0, values.length - 1);
      final lowCutoff = values[lowCutoffIndex];
      final highCutoff = values[highCutoffIndex];

      final level = target <= lowCutoff ? 'Low' : (target <= highCutoff ? 'Medium' : 'High');
      return _StateResult<String>(level, isFallback: isFallback, fallbackState: fallbackState);
    } catch (e) {
      _log('Expenditure -> EXCEPTION: $e');
      return _StateResult.empty<String>();
    }
  }

  Future<_StateResult<int>> _fetchSchoolsTotal(String? state, String? district) async {
    try {
      final data = await _fetchDataset('schools_district');
      const stages = {'primary', 'secondary', 'tertiary'};

      int? computeForScope(List<Map<String, dynamic>> scoped) {
        if (scoped.isEmpty) return null;
        int total = 0;
        bool found = false;
        for (final stage in stages) {
          final stageRecords = scoped.where((r) => r['stage']?.toString() == stage).toList();
          final sum = _sumAtLatestYear(stageRecords, 'schools');
          if (sum != null) {
            total += sum.round();
            found = true;
          }
        }
        return found ? total : null;
      }

      List<Map<String, dynamic>> scoped = [];
      if (district != null) {
        scoped = data.where((r) => _matchesDistrict(r['district']?.toString(), district)).toList();
      }
      final districtResult = computeForScope(scoped);
      if (districtResult != null) {
        return _StateResult<int>(districtResult, isFallback: false);
      }

      if (state == null) return _StateResult.empty<int>();

      int? computeForState(String s) {
        final stateScoped = data
            .where((r) => r['district']?.toString() == 'All Districts' && _matchesState(r['state'], s))
            .toList();
        return computeForScope(stateScoped);
      }

      return _withFallback<int>(state, computeForState);
    } catch (e) {
      _log('Schools -> EXCEPTION: $e');
      return _StateResult.empty<int>();
    }
  }

  Future<_StateResult<int>> _fetchHospitalBedsTotal(String? state, String? district) async {
    try {
      final data = await _fetchDataset('hospital_beds');
      const types = {'hospital_moh', 'hospital_non_moh', 'special_medical_institution'};

      if (district != null) {
        final scoped = data
            .where((r) =>
        _matchesDistrict(r['district']?.toString(), district) && types.contains(r['type']?.toString()))
            .toList();
        final sum = _sumAtLatestYear(scoped, 'beds');
        if (sum != null) return _StateResult<int>(sum.round(), isFallback: false);
      }

      if (state == null) return _StateResult.empty<int>();

      int? computeForState(String s) {
        final scoped = data
            .where((r) =>
        r['district']?.toString() == 'All Districts' &&
            _matchesState(r['state'], s) &&
            types.contains(r['type']?.toString()))
            .toList();
        final sum = _sumAtLatestYear(scoped, 'beds');
        return sum?.round();
      }

      return _withFallback<int>(state, computeForState);
    } catch (e) {
      _log('HospitalBeds -> EXCEPTION: $e');
      return _StateResult.empty<int>();
    }
  }


  Future<List<Map<String, dynamic>>> _fetchDataset(String id) async {
    if (_cache.containsKey(id)) {
      return _cache[id]!;
    }

    final uri = Uri.parse('$_baseUrl?id=$id&limit=$_fetchLimit');
    _log('fetch "$id" -> GET $uri');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        _log('fetch "$id" -> HTTP ${response.statusCode} ${response.reasonPhrase}');
        throw Exception('Failed to load $id: ${response.reasonPhrase}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        _cache[id] = <Map<String, dynamic>>[];
        return _cache[id]!;
      }

      final List<Map<String, dynamic>> records = decoded.cast<Map<String, dynamic>>();
      _log('fetch "$id" -> OK, ${records.length} records');
      _cache[id] = records;
      return records;
    } catch (e) {
      _log('fetch "$id" -> EXCEPTION: $e');
      rethrow;
    }
  }

  double? _sumAtLatestYear(List<Map<String, dynamic>> records, String valueField) {
    if (records.isEmpty) return null;

    int? latestYear;
    for (final r in records) {
      final date = DateTime.tryParse(r['date']?.toString() ?? '');
      if (date != null && (latestYear == null || date.year > latestYear!)) {
        latestYear = date.year;
      }
    }
    if (latestYear == null) return null;

    double sum = 0;
    bool found = false;
    for (final r in records) {
      final date = DateTime.tryParse(r['date']?.toString() ?? '');
      if (date != null && date.year == latestYear) {
        final v = r[valueField];
        if (v is num) {
          sum += v.toDouble();
          found = true;
        }
      }
    }
    return found ? sum : null;
  }

  bool _matchesState(dynamic recordState, String? targetState) {
    if (targetState == null) return false;
    final a = recordState?.toString().trim().toLowerCase() ?? '';
    var b = targetState.trim().toLowerCase();
    if (a.isEmpty || b.isEmpty) return false;

    if (b == 'penang') b = 'pulau pinang';
    if (b == 'kl' || b == 'wp kuala lumpur') b = 'w.p. kuala lumpur';
    if (b == 'wp putrajaya' || b == 'putrajaya') b = 'w.p. putrajaya';
    if (b == 'wp labuan' || b == 'labuan') b = 'w.p. labuan';

    if (a == b) return true;
    return a.contains(b) || b.contains(a);
  }

  bool _matchesDistrict(dynamic recordDistrict, String? targetDistrict) {
    if (targetDistrict == null) return false;
    final a = recordDistrict?.toString().trim().toLowerCase() ?? '';
    final b = targetDistrict.trim().toLowerCase();
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    return a.contains(b) || b.contains(a);
  }
}
