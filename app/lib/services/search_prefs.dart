import 'dart:convert';

import '../core/db/database.dart';

/// 搜索偏好（D83）：历史（最近 20）与收藏（不限）存 settings JSON，无需迁移。
class SearchPrefs {
  SearchPrefs(this._db);

  final AppDatabase _db;

  static const String historyKey = 'search_history';
  static const String favoritesKey = 'search_favorites';
  static const int historyLimit = 20;

  Future<List<String>> history() async => _read(historyKey);
  Future<List<String>> favorites() async => _read(favoritesKey);

  /// 返回更新后的历史（最新在前，去重）。
  Future<List<String>> pushHistory(String query) async {
    final String q = query.trim();
    if (q.isEmpty) return history();
    final List<String> list = await _read(historyKey)
      ..removeWhere((String e) => e == q)
      ..insert(0, q);
    while (list.length > historyLimit) {
      list.removeLast();
    }
    await _write(historyKey, list);
    return list;
  }

  Future<void> clearHistory() => _write(historyKey, <String>[]);

  Future<bool> isFavorite(String query) async {
    final List<String> list = await _read(favoritesKey);
    return list.contains(query.trim());
  }

  /// 切换收藏，返回切换后状态。
  Future<bool> toggleFavorite(String query) async {
    final String q = query.trim();
    if (q.isEmpty) return false;
    final List<String> list = await _read(favoritesKey);
    final bool added = !list.contains(q);
    if (added) {
      list.insert(0, q);
    } else {
      list.removeWhere((String e) => e == q);
    }
    await _write(favoritesKey, list);
    return added;
  }

  Future<List<String>> _read(String key) async {
    try {
      final String raw = await _db.getSetting(key) ?? '[]';
      return (jsonDecode(raw) as List<Object?>).whereType<String>().toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> _write(String key, List<String> value) =>
      _db.setSetting(key, jsonEncode(value));
}
