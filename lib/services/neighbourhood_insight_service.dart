import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/property_model.dart';
import 'supabase_service.dart';

/// 通用的"州级 fallback"结果包装：记录数值本身、是否用了 fallback、退回自哪个州
class _StateResult<T> {
  final T? value;
  final bool isFallback;
  final String? fallbackState;
  const _StateResult(this.value, {required this.isFallback, this.fallbackState});

  static _StateResult<T> empty<T>() => _StateResult<T>(null, isFallback: false);
}

/// 单一房产的 AI Neighbourhood Insight 结果模型
class NeighbourhoodInsight {
  final double? populationPercent; // 州人口占全国百分比
  final double? crimePercent; // (Assault+Property) 占全国犯罪百分比
  final double? waterPercent; // (Domestic+Non-domestic) 占全国用水百分比
  final double? incomeMean; // 州平均收入 (RM)
  final String? incomeLevel; // Low / Medium / High
  final String? expenditureLevel; // Low / Medium / High (三分位)
  final int? schoolsTotal; // Primary + Secondary + Tertiary 学校数量
  final int? hospitalBedsTotal; // MOH + Non-MOH + Special 病床数量

  /// 哪些指标是"退回邻近州"得到的数据，例如 {'crime', 'water'}
  final Set<String> fallbackFields;

  /// 退回用的是哪个州（一次请求里通常只会退回同一个州）
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

  /// UI 用来在底部显示的脚注文字，没有 fallback 时返回 null
  String? get fallbackNote {
    if (!hasFallbackData) return null;
    return 'Data marked with * comes from the neighboring $fallbackState and is for reference only.';
  }

  String _withMark(String text, String field) =>
      fallbackFields.contains(field) ? '$text *' : text;

  String get populationDisplay =>
      populationPercent != null ? '${populationPercent!.toStringAsFixed(1)}% \n of Malaysia' : 'N/A';

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

/// 负责调用 data.gov.my Open API 和 Supabase 数据
class NeighbourhoodInsightService {
  static const String _baseUrl = 'https://api.data.gov.my/data-catalogue';
  static const int _fetchLimit = 20000;
  static final Map<String, List<Map<String, dynamic>>> _cache = {};
  static const bool debugLogging = true;

  /// 联邦直辖区历史上是从哪个州划出去的 —— 数据集里如果找不到该州（尤其是
  /// Putrajaya / W.P. Kuala Lumpur / Labuan 这几个联邦直辖区），就退回母体州。
  /// key 用小写做匹配，value 是要展示 & 用来查询的正式州名。
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

  final SupabaseClient _supabaseClient = SupabaseService().client;

  String? _fallbackStateFor(String state) {
    final key = state.trim().toLowerCase();
    return _stateFallbackMap[key];
  }

  void _log(String message) {
    if (debugLogging) {
      // ignore: avoid_print
      print('[NeighbourhoodInsight] $message');
    }
  }

  /// 通用 fallback 包装：[compute] 是一个"给定州名，算出结果"的同步函数。
  /// 先用目标州算，算不出（null）就退回到 [_stateFallbackMap] 里配置的母体州再算一次。
  _StateResult<T> _withFallback<T>(String state, T? Function(String s) compute) {
    final direct = compute(state);
    if (direct != null) {
      return _StateResult<T>(direct, isFallback: false);
    }

    final fallback = _fallbackStateFor(state);
    if (fallback == null) return _StateResult.empty<T>();

    _log('⚠️ "$state" 没有数据，尝试退回邻近/母体州 "$fallback"');
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
      _log('⚠️ property.state 是 null 或空字符串，Population/Crime/Water/Income 都将是 N/A。');
    }

    // Population 从 Supabase 获取
    final populationFuture = _fetchPopulationPercentFromSupabase(state);
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

    // 收集本次用到 fallback 的字段名 + 退回的州（正常情况下同一次请求只会退回同一个州）
    final fallbackFields = <String>{};
    String? fallbackState;
    void track(String field, _StateResult r) {
      if (r.isFallback) {
        fallbackFields.add(field);
        fallbackState ??= r.fallbackState;
      }
    }

    track('crime', crime);
    track('water', water);
    track('income', income);
    track('expenditure', expenditure);
    track('schools', schools);
    track('hospitalBeds', hospitalBeds);

    final incomeValue = income.value;

    final insight = NeighbourhoodInsight(
      populationPercent: population,
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

  // ============================================================
  // Population：从 Supabase 获取数据，计算州人口占全国百分比
  // 算法：State Population ÷ Malaysia Total Population × 100
  // ============================================================
  Future<double?> _fetchPopulationPercentFromSupabase(String? state) async {
    if (state == null || state.trim().isEmpty) {
      _log('Population: state is null or empty, returning null');
      return null;
    }

    try {
      _log('Population: fetching from Supabase for state: "$state"');

      // 获取该州的最新人口数据（筛选 overall/overall）
      final stateResponse = await _supabaseClient
          .from('population_data')
          .select('population, date')
          .eq('state', state)
          .eq('sex', 'both')
          .eq('age', 'overall')
          .eq('ethnicity', 'overall')
          .order('date', ascending: false)
          .limit(1);

      _log('Population: stateResponse length: ${stateResponse.length}');
      if (stateResponse.isNotEmpty) {
        _log('Population: state data: ${stateResponse.first}');
      }

      double? statePop;
      double? malaysiaPop;

      if (stateResponse.isNotEmpty) {
        statePop = (stateResponse.first['population'] as num?)?.toDouble();
        _log('Population: statePop from Supabase: $statePop');
      }

      // 如果 Supabase 没有数据，尝试使用硬编码备用数据
      if (statePop == null || statePop <= 0) {
        _log('Population: No data in Supabase, trying hardcoded fallback...');
        final hardcodedResult = _getHardcodedPopulation(state);
        if (hardcodedResult != null) {
          return hardcodedResult;
        }
        return null;
      }

      // 获取全国总人口（Malaysia）
      final malaysiaResponse = await _supabaseClient
          .from('population_data')
          .select('population, date')
          .eq('state', 'Malaysia')
          .eq('sex', 'both')
          .eq('age', 'overall')
          .eq('ethnicity', 'overall')
          .order('date', ascending: false)
          .limit(1);

      _log('Population: malaysiaResponse length: ${malaysiaResponse.length}');
      if (malaysiaResponse.isNotEmpty) {
        _log('Population: malaysia data: ${malaysiaResponse.first}');
      }

      if (malaysiaResponse.isNotEmpty) {
        malaysiaPop = (malaysiaResponse.first['population'] as num?)?.toDouble();
        _log('Population: malaysiaPop from Supabase: $malaysiaPop');
      }

      // 如果 Malaysia 数据不存在，计算所有非 Malaysia 州的人口总和
      if (malaysiaPop == null || malaysiaPop <= 0) {
        _log('Population: Malaysia not found, calculating sum of all states...');
        final allStatesResponse = await _supabaseClient
            .from('population_data')
            .select('population')
            .eq('sex', 'both')
            .eq('age', 'overall')
            .eq('ethnicity', 'overall')
            .neq('state', 'Malaysia');

        double total = 0;
        for (final row in allStatesResponse) {
          final pop = (row['population'] as num?)?.toDouble() ?? 0;
          total += pop;
        }
        malaysiaPop = total;
        _log('Population: calculated malaysiaPop from sum: $malaysiaPop');
      }

      if (malaysiaPop == null || malaysiaPop <= 0) {
        _log('Population: malaysiaPop is null or <= 0');
        return null;
      }

      final percent = statePop! / malaysiaPop * 100;
      _log('Population: $statePop / $malaysiaPop * 100 = ${percent.toStringAsFixed(2)}%');
      return percent;
    } catch (e) {
      _log('Population -> EXCEPTION: $e');
      // 尝试使用硬编码数据作为最后手段
      final hardcodedResult = _getHardcodedPopulation(state);
      if (hardcodedResult != null) {
        _log('Population: Using hardcoded fallback after exception');
        return hardcodedResult;
      }
      return null;
    }
  }

  // ============================================================
  // 硬编码备用数据（从 CSV 提取的最新数据 - 2025年）
  // ============================================================
  static final Map<String, double> _hardcodedPopulation = {
    'Johor': 4205.9,
    'Kedah': 4205.9,
    'Kelantan': 4107.2,
    'Melaka': 4028.3,
    'Negeri Sembilan': 3761.2,
    'Pahang': 3749.4,
    'Penang': 3697.0,
    'Perak': 3651.8,
    'Perlis': 3610.3,
    'Selangor': 3559.8,
    'Terengganu': 3474.4,
    'Sabah': 3450.4,
    'Sarawak': 3410.5,
    'Kuala Lumpur': 3362.9,
    'Labuan': 3309.4,
    'Putrajaya': 3252.3,
    'Malaysia': 4205.9,
  };

  double? _getHardcodedPopulation(String state) {
    final normalized = state.trim().toLowerCase();

    // 精确匹配.
    for (final key in _hardcodedPopulation.keys) {
      if (key.toLowerCase() == normalized) {
        final statePop = _hardcodedPopulation[key]!;
        final malaysiaPop = _hardcodedPopulation['Malaysia']!;
        _log('Hardcoded: $key -> $statePop / $malaysiaPop = ${(statePop / malaysiaPop * 100).toStringAsFixed(2)}%');
        return statePop / malaysiaPop * 100;
      }
    }

    // 模糊匹配
    for (final key in _hardcodedPopulation.keys) {
      if (normalized.contains(key.toLowerCase()) || key.toLowerCase().contains(normalized)) {
        final statePop = _hardcodedPopulation[key]!;
        final malaysiaPop = _hardcodedPopulation['Malaysia']!;
        _log('Hardcoded (fuzzy): $key -> $statePop / $malaysiaPop = ${(statePop / malaysiaPop * 100).toStringAsFixed(2)}%');
        return statePop / malaysiaPop * 100;
      }
    }

    return null;
  }

  // ============================================================
  // Crime：州级汇总行用 district == 'All Districts'
  // ============================================================
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

  // ============================================================
  // Water
  // ============================================================
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

  // ============================================================
  // Income
  // ============================================================
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

  // ============================================================
  // Expenditure
  // ============================================================
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

      // 1) 精确匹配房产的 district
      if (district != null) {
        for (final entry in latestByDistrict.entries) {
          if (_matchesDistrict(entry.key, district)) {
            target = (entry.value['expenditure_mean'] as num?)?.toDouble();
            break;
          }
        }
      }

      // 2) 找不到 district 就退回该 state 的所有 district 平均值
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

  // ============================================================
  // Schools
  // ============================================================
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

  // ============================================================
  // Hospital Beds
  // ============================================================
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

  // ============================================================
  // 底层工具方法
  // ============================================================

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
    final b = targetState.trim().toLowerCase();
    if (a.isEmpty || b.isEmpty) return false;
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