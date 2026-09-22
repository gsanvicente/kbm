import 'package:flutter/foundation.dart';

import '../core/models/cardholder_session.dart';
import '../core/models/shared/activation_failed_exception.dart';
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

  /// docs/adr/0019-cardholder-self-activation.md. La validación de
  /// longitud de la contraseña vive en el formulario (ver
  /// ActivationScreen), igual que admin/'s staff_user_form_dialog.dart —
  /// esto solo maneja el resultado del backend.
  Future<void> activate({
    required String email,
    required String idDocumentNumber,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _session = await _repository.activate(email: email, idDocumentNumber: idDocumentNumber, password: password);
    } on ActivationFailedException catch (e) {
      _error = e.message;
    } catch (_) {
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

  /// Login y activación comparten este mismo controller/campo [error] —
  /// sin esto, navegar de una pantalla a la otra podía mostrar el error
  /// de la pantalla anterior antes de siquiera enviar el nuevo formulario.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
