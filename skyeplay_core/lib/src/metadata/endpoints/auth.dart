import 'package:hetu_script/hetu_script.dart';

class MetadataAuthEndpoint {
  final Hetu hetu;

  MetadataAuthEndpoint(this.hetu);

  Stream get authStateStream => Stream.empty();

  Future<void> authenticate() async {
    // No-op in headless mode
    // Ideally log a warning that auth is not supported
    print('Auth not supported in headless mode');
  }

  bool isAuthenticated() {
    return false; 
    // Or check for a stored token file if we implement headless auth later
  }

  Future<void> logout() async {
    // No-op
  }
}
