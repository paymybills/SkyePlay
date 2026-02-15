import 'package:hetu_spotube_plugin/hetu_spotube_plugin.dart';

class DummyLocalStorage implements Localstorage {
  final Map<String, dynamic> _storage = {};

  @override
  Future<void> clear() async => _storage.clear();

  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);

  @override
  Future<bool?> getBool(String key) async => _storage[key] as bool?;

  @override
  Future<double?> getDouble(String key) async => _storage[key] as double?;

  @override
  Future<int?> getInt(String key) async => _storage[key] as int?;

  @override
  Future<String?> getString(String key) async => _storage[key] as String?;

  @override
  Future<List<String>?> getStringList(String key) async =>
      _storage[key] as List<String>?;

  @override
  Future<void> remove(String key) async => _storage.remove(key);

  @override
  Future<void> setBool(String key, bool value) async => _storage[key] = value;

  @override
  Future<void> setDouble(String key, double value) async => _storage[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _storage[key] = value;

  @override
  Future<void> setString(String key, String value) async => _storage[key] = value;

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _storage[key] = value;
}
