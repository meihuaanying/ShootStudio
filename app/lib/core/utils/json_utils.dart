import 'dart:convert';

/// JSON 读取小工具：宽容地处理 dynamic → Map/List 的转换。
Map<String, Object?> asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  return <String, Object?>{};
}

List<Object?> asList(Object? value) {
  if (value is List) return value;
  return const <Object?>[];
}

List<String> asStringList(Object? value) =>
    asList(value).whereType<String>().toList();

Map<String, Object?> decodeMap(String raw) => asMap(jsonDecode(raw));

List<Map<String, Object?>> asMapList(Object? value) =>
    asList(value).whereType<Map>().map(asMap).toList();

double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int asInt(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// 深拷贝（JSON 往返），保证状态隔离。
Map<String, Object?> deepCopy(Map<String, Object?> source) =>
    asMap(jsonDecode(jsonEncode(source)));

List<Map<String, Object?>> deepCopyList(List<Map<String, Object?>> source) =>
    asMapList(jsonDecode(jsonEncode(source)));

/// 解析关节三轴角 [x, y, z]（兼容 List 与 Map 两种历史存储格式）。
List<double> tripleOf(Object? raw) {
  if (raw is List && raw.length >= 3) {
    return <double>[
      (raw[0] as num?)?.toDouble() ?? 0,
      (raw[1] as num?)?.toDouble() ?? 0,
      (raw[2] as num?)?.toDouble() ?? 0,
    ];
  }
  if (raw is Map) {
    return <double>[
      (raw['0'] as num?)?.toDouble() ?? 0,
      (raw['1'] as num?)?.toDouble() ?? 0,
      (raw['2'] as num?)?.toDouble() ?? 0,
    ];
  }
  return <double>[0, 0, 0];
}
