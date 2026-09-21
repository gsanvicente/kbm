import 'package:flutter/foundation.dart';

import '../core/models/session.dart';
import '../features/auth/auth_repository.dart';

/// App-wide auth state. Plain ChangeNotifier on purpose — no state
/// management package added yet (Riverpod vs Bloc is still an open
/// decision, see admin/docs/tdr/_TEMPLATE.md). Revisit with a TDR once
/// state complexity actually grows.
class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  Session? _session;
  String? _error;
  bool _isLoading = false;

  Session? get session => _session;
  String? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _session = await _repository.login(email: email, password: password);
    } on AuthException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _repository.logout();
    _session = null;
    _error = null;
    notifyListeners();
  }
}
