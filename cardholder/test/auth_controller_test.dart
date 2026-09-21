import 'package:flutter_test/flutter_test.dart';

import 'package:kbm_cardholder/app/auth_controller.dart';
import 'package:kbm_cardholder/core/models/cardholder_session.dart';
import 'package:kbm_cardholder/features/auth/cardholder_auth_repository.dart';

/// Simula cualquier falla que no sea un rechazo de credenciales — en la
/// práctica, sobre todo errores de red hacia el backend compartido (ver
/// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md).
class _ThrowingAuthRepository implements CardholderAuthRepository {
  @override
  Future<CardholderSession> login({required String email, required String password}) {
    throw Exception('Network is unreachable');
  }

  @override
  void logout() {}
}

void main() {
  test('a non-AuthException failure (e.g. network) still surfaces an error message', () async {
    final controller = CardholderAuthController(_ThrowingAuthRepository());

    await controller.login(email: 'juan.perez@cardholder.test', password: 'LocalDevOnly123!');

    // Antes de este fix, solo se capturaba AuthException — cualquier otra
    // excepción dejaba `error` en null, el botón se reactivaba, y parecía
    // que el login "no hacía nada".
    expect(controller.error, isNotNull);
    expect(controller.isLoading, isFalse);
    expect(controller.session, isNull);
  });
}
