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
    } catch (_) {
      // No es un rechazo de credenciales (AuthException) — típicamente un
      // error de red hacia el backend compartido (ver
      // docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md).
      // Sin este catch, el error quedaba sin mostrar: el botón se
      // reactivaba y parecía que "no pasaba nada".
      _error = 'No se pudo conectar. Verifica tu conexión e intenta de nuevo.';
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
