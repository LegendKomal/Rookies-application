import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recent search queries, newest first, persisted on-device so they survive
/// app restarts. Case-insensitive duplicates collapse into one entry that
/// moves back to the top when searched again.
class SearchHistoryService extends ChangeNotifier {
  SearchHistoryService._();
  static final SearchHistoryService instance = SearchHistoryService._();

  static const String _prefsKey = 'recent_searches';
  static const int _maxEntries = 10;

  List<String> _queries = [];
  bool _loaded = false;

  List<String> get queries => List.unmodifiable(_queries);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _queries = prefs.getStringList(_prefsKey) ?? [];
      notifyListeners();
    } catch (_) {
      // History is a convenience — a storage failure just means none shown.
    }
  }

  Future<void> add(String query) async {
    final trimmed = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return;
    _queries = [
      trimmed,
      ..._queries.where((q) => q.toLowerCase() != trimmed.toLowerCase()),
    ].take(_maxEntries).toList();
    notifyListeners();
    await _save();
  }

  Future<void> remove(String query) async {
    _queries = _queries.where((q) => q != query).toList();
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    _queries = [];
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _queries);
    } catch (_) {}
  }
}
