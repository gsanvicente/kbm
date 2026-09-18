import 'package:flutter/foundation.dart';

import '../core/models/cardholder_session.dart';
import '../core/models/shared/auth_exception.dart';
import '../features/auth/cardholder_auth_repository.dart';

class CardholderAuthController extends ChangeNotifier {
  CardholderAuthController(this._repository);

  final CardholderAuthRepository _repository;

  CardholderSession? _session;
  String? _error;
  bool _isLoading = false;

  CardholderSession? get session => _session;
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
    _session = null;
    _error = null;
    notifyListeners();
  }
}
