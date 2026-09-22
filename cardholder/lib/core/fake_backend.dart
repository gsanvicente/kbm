import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'models/card_network.dart';
import 'models/card_status.dart';
import 'models/cardholder.dart';
import 'models/cardholder_session.dart';
import 'models/claim_status.dart';
import 'models/ledger_entry_type.dart';
import 'models/ledger_movement.dart';
import 'models/movement_claim.dart';
import 'models/payment_card.dart';
import 'models/shared/activation_failed_exception.dart';
import 'models/shared/auth_exception.dart';
import 'models/shared/claim_already_filed_exception.dart';
import 'models/shared/insufficient_funds_exception.dart';
import 'models/shared/too_many_failed_attempts_exception.dart';
import '../features/auth/cardholder_auth_repository.dart';
import '../features/cards/card_repository.dart';
import '../features/transfer/transfer_repository.dart';

/// Único "backend" fake de esta app — sin conexión real, ver
/// `cardholder/README.md`. Implementa las tres interfaces (auth, tarjetas,
/// transferencias) en una sola clase a propósito: las tres necesitan leer
/// y mutar el mismo universo de Tarjetahabientes/Tarjetas, y aquí no hay
/// beneficio en separar eso en repositorios independientes que de todas
/// formas tendrían que inyectarse unos a otros (a diferencia de `admin/`,
/// donde cada entidad tiene su propio ciclo de vida y pantallas propias).
///
/// Universo de datos completamente independiente del de `admin/` — por
/// ADR-0002 estas dos apps no comparten código ni estado en tiempo de
/// ejecución. Los nombres/IDs coinciden con los de `admin/` solo por
/// continuidad narrativa del demo, no hay sincronización real posible
/// sin un backend compartido.
class FakeCardholderBackend implements CardholderAuthRepository, CardRepository, TransferRepository {
  static const _clientA = '00000000-0000-0000-0000-000000000002'; // Koons Subsidiaria A
  static const _clientB = '00000000-0000-0000-0000-000000000003'; // Koons Subsidiaria B
  static const _devPassword = 'LocalDevOnly123!';

  // Simula la llave secreta que en un backend real viviría en un almacén
  // de secretos, nunca hardcodeada — ver
  // docs/adr/0009-pan-hash-transit-for-c2c-transfers.md, punto 3.
  static final _hmacKey = utf8.encode('kbm-fake-pan-hmac-key-dev-only');

  static String _hashPan(String pan) => Hmac(sha256, _hmacKey).convert(utf8.encode(pan)).toString();

  final List<Cardholder> _cardholders = const [
    Cardholder(
      id: '20000000-0000-0000-0000-000000000001',
      clientId: _clientA,
      fullName: 'Juan Perez',
      email: 'juan.perez@cardholder.test',
    ),
    Cardholder(
      id: '20000000-0000-0000-0000-000000000003',
      clientId: _clientA,
      fullName: 'Ana Torres',
      email: 'ana.torres@cardholder.test',
    ),
    Cardholder(
      id: '20000000-0000-0000-0000-000000000002',
      clientId: _clientB,
      fullName: 'Maria Gomez',
      email: 'maria.gomez@cardholder.test',
    ),
    Cardholder(
      id: '20000000-0000-0000-0000-000000000004',
      clientId: _clientB,
      fullName: 'Carlos Ruiz',
      email: 'carlos.ruiz@cardholder.test',
    ),
    // Cuenta de demo dedicada a ejercer la Capa 1 de
    // docs/business/desactivacion-de-tarjetahabientes.md — ver
    // cardholder/README.md para las credenciales de prueba.
    Cardholder(
      id: '20000000-0000-0000-0000-000000000099',
      clientId: _clientA,
      fullName: 'Tarjetahabiente Inactivo (demo)',
      email: 'inactivo@cardholder.test',
      isActive: false,
    ),
    // Con dos tarjetas a propósito, para ejercer el selector de
    // "Mis tarjetas" — ver HomeShell.
    Cardholder(
      id: '20000000-0000-0000-0000-000000000005',
      clientId: _clientA,
      fullName: 'Sofia Ramirez',
      email: 'sofia.ramirez@cardholder.test',
    ),
    // Cuenta de demo dedicada a ejercer
    // docs/adr/0019-cardholder-self-activation.md — a propósito excluida
    // de _passwordByEmail más abajo, "todavía no activó su cuenta".
    Cardholder(
      id: '20000000-0000-0000-0000-000000000098',
      clientId: _clientA,
      fullName: 'Tarjetahabiente Sin Activar (demo)',
      email: 'sinactivar@cardholder.test',
    ),
  ];

  // Número de identificación oficial por email — solo para la
  // verificación de identidad de activate() (ver
  // docs/adr/0019-cardholder-self-activation.md); deliberadamente no
  // vive en el modelo Cardholder (ver su doc: "nada de KYC/domicilio").
  static const _idDocumentNumberByEmail = {
    'juan.perez@cardholder.test': 'INE1234567890123',
    'ana.torres@cardholder.test': 'INE2345678901234',
    'maria.gomez@cardholder.test': 'INE3456789012345',
    'carlos.ruiz@cardholder.test': 'G12345678',
    'inactivo@cardholder.test': 'INE9999999999999',
    'sofia.ramirez@cardholder.test': 'INE1111111111111',
    'sinactivar@cardholder.test': 'INE5555555555555',
  };

  final Map<String, int> _activationFailedAttempts = {};

  final List<PaymentCard> _cards = [
    const PaymentCard(
      id: '40000000-0000-0000-0000-000000000001',
      clientId: _clientA,
      cardholderId: '20000000-0000-0000-0000-000000000001', // Juan Perez
      maskedPan: '**** **** **** 1234',
      network: CardNetwork.visa,
      expiryMonth: 8,
      expiryYear: 2027,
      status: CardStatus.active,
      balance: 1250.00,
    ),
    const PaymentCard(
      id: '40000000-0000-0000-0000-000000000010',
      clientId: _clientA,
      cardholderId: '20000000-0000-0000-0000-000000000003', // Ana Torres
      maskedPan: '**** **** **** 5566',
      network: CardNetwork.mastercard,
      expiryMonth: 2,
      expiryYear: 2028,
      status: CardStatus.active,
      balance: 300.00,
    ),
    const PaymentCard(
      id: '40000000-0000-0000-0000-000000000002',
      clientId: _clientB,
      cardholderId: '20000000-0000-0000-0000-000000000002', // Maria Gomez
      maskedPan: '**** **** **** 5678',
      network: CardNetwork.mastercard,
      expiryMonth: 3,
      expiryYear: 2026,
      status: CardStatus.active,
      balance: 800.00,
    ),
    const PaymentCard(
      id: '40000000-0000-0000-0000-000000000004',
      clientId: _clientB,
      cardholderId: '20000000-0000-0000-0000-000000000004', // Carlos Ruiz
      maskedPan: '**** **** **** 7890',
      network: CardNetwork.visa,
      expiryMonth: 11,
      expiryYear: 2026,
      status: CardStatus.blocked,
      balance: 500.00,
    ),
    const PaymentCard(
      id: '40000000-0000-0000-0000-000000000011',
      clientId: _clientA,
      cardholderId: '20000000-0000-0000-0000-000000000005', // Sofia Ramirez
      maskedPan: '**** **** **** 4321',
      network: CardNetwork.visa,
      expiryMonth: 5,
      expiryYear: 2029,
      status: CardStatus.active,
      balance: 600.00,
    ),
    const PaymentCard(
      id: '40000000-0000-0000-0000-000000000012',
      clientId: _clientA,
      cardholderId: '20000000-0000-0000-0000-000000000005', // Sofia Ramirez
      maskedPan: '**** **** **** 8899',
      network: CardNetwork.mastercard,
      expiryMonth: 9,
      expiryYear: 2029,
      status: CardStatus.active,
      balance: 150.00,
    ),
  ];

  // PAN completo por tarjeta — solo para calcular su hash al sembrar los
  // datos. Nunca se expone fuera de este archivo, ver el doc de
  // `PaymentCard`.
  static const _fullPanByCardId = {
    '40000000-0000-0000-0000-000000000001': '4111111111111234',
    '40000000-0000-0000-0000-000000000010': '5500000000005566',
    '40000000-0000-0000-0000-000000000002': '5500000000005678',
    '40000000-0000-0000-0000-000000000004': '4111111111117890',
    '40000000-0000-0000-0000-000000000011': '4111111111114321',
    '40000000-0000-0000-0000-000000000012': '5500000000008899',
  };

  late final Map<String, String> _panHashByCardId = {
    for (final entry in _fullPanByCardId.entries) entry.key: _hashPan(entry.value),
  };

  late final Map<String, String> _passwordByEmail = {
    for (final c in _cardholders)
      if (c.email != 'sinactivar@cardholder.test') c.email: _devPassword,
  };

  final Map<String, int> _failedAttempts = {};

  // Movimientos sembrados por tarjeta — mismos montos/fechas que
  // `admin/lib/features/ledger/fake_ledger_repository.dart` donde el
  // dato coincide (Juan Perez, Ana Torres), solo por continuidad
  // narrativa del demo, sin relación técnica real (ADR-0002). `transfer`
  // agrega entradas nuevas a esta misma estructura.
  final Map<String, List<LedgerMovement>> _movementsByCard = {
    '40000000-0000-0000-0000-000000000001': [
      LedgerMovement(
        id: 'seed-0001-1',
        type: LedgerEntryType.credit,
        amount: 1000.00,
        balanceAfter: 1000.00,
        description: 'Carga inicial',
        createdAt: DateTime(2026, 1, 10, 9, 0),
      ),
      LedgerMovement(
        id: 'seed-0001-2',
        type: LedgerEntryType.debit,
        amount: 150.00,
        balanceAfter: 850.00,
        description: 'Compra en restaurante',
        createdAt: DateTime(2026, 1, 15, 14, 30),
      ),
      LedgerMovement(
        id: 'seed-0001-3',
        type: LedgerEntryType.credit,
        amount: 400.00,
        balanceAfter: 1250.00,
        description: 'Carga de fondos',
        createdAt: DateTime(2026, 1, 20, 10, 0),
      ),
    ],
    '40000000-0000-0000-0000-000000000010': [
      LedgerMovement(
        id: 'seed-0010-1',
        type: LedgerEntryType.credit,
        amount: 300.00,
        balanceAfter: 300.00,
        description: 'Carga inicial',
        createdAt: DateTime(2026, 1, 22, 9, 0),
      ),
    ],
    '40000000-0000-0000-0000-000000000002': [
      LedgerMovement(
        id: 'seed-0002-1',
        type: LedgerEntryType.credit,
        amount: 800.00,
        balanceAfter: 800.00,
        description: 'Carga inicial',
        createdAt: DateTime(2026, 1, 12, 9, 0),
      ),
    ],
    '40000000-0000-0000-0000-000000000004': [
      LedgerMovement(
        id: 'seed-0004-1',
        type: LedgerEntryType.credit,
        amount: 500.00,
        balanceAfter: 500.00,
        description: 'Carga inicial',
        createdAt: DateTime(2026, 1, 15, 9, 0),
      ),
    ],
    '40000000-0000-0000-0000-000000000011': [
      LedgerMovement(
        id: 'seed-0011-1',
        type: LedgerEntryType.credit,
        amount: 600.00,
        balanceAfter: 600.00,
        description: 'Carga inicial',
        createdAt: DateTime(2026, 1, 18, 9, 0),
      ),
    ],
    '40000000-0000-0000-0000-000000000012': [
      LedgerMovement(
        id: 'seed-0012-1',
        type: LedgerEntryType.credit,
        amount: 150.00,
        balanceAfter: 150.00,
        description: 'Carga inicial',
        createdAt: DateTime(2026, 1, 19, 9, 0),
      ),
    ],
  };

  @override
  Future<CardholderSession> login({required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final normalizedEmail = email.trim().toLowerCase();
    final cardholder = _cardholders.where((c) => c.email.toLowerCase() == normalizedEmail).firstOrNull;
    if (cardholder == null || _passwordByEmail[cardholder.email] != password) {
      throw const AuthException();
    }
    // Capa 1 — ver docs/business/desactivacion-de-tarjetahabientes.md,
    // "Enforcement". Mismo mensaje genérico, nunca se distingue de una
    // contraseña incorrecta.
    if (!cardholder.isActive) {
      throw const AuthException();
    }
    resetFailedAttempts(cardholder.id);
    return CardholderSession(cardholderId: cardholder.id, email: cardholder.email, fullName: cardholder.fullName);
  }

  // maxActivationFailedAttempts — ver
  // docs/adr/0019-cardholder-self-activation.md, "Seguridad": a
  // diferencia de _failedAttempts (transferencia C2C, se reinicia con
  // cada login), este bloqueo es permanente para efectos de esta sesión
  // de la app (no hay "reiniciar sesión" que lo levante).
  static const _maxActivationFailedAttempts = 5;

  @override
  Future<CardholderSession> activate({
    required String email,
    required String idDocumentNumber,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final normalizedEmail = email.trim().toLowerCase();

    if ((_activationFailedAttempts[normalizedEmail] ?? 0) >= _maxActivationFailedAttempts) {
      throw const ActivationFailedException();
    }

    final cardholder = _cardholders.where((c) => c.email.toLowerCase() == normalizedEmail).firstOrNull;
    final expectedDocument = _idDocumentNumberByEmail[normalizedEmail];
    final alreadyActivated = cardholder != null && _passwordByEmail.containsKey(cardholder.email);

    if (cardholder == null ||
        !cardholder.isActive ||
        expectedDocument != idDocumentNumber ||
        alreadyActivated) {
      _activationFailedAttempts[normalizedEmail] = (_activationFailedAttempts[normalizedEmail] ?? 0) + 1;
      throw const ActivationFailedException();
    }

    _passwordByEmail[cardholder.email] = password;
    _activationFailedAttempts.remove(normalizedEmail);
    return CardholderSession(cardholderId: cardholder.id, email: cardholder.email, fullName: cardholder.fullName);
  }

  @override
  void logout() {}

  @override
  Future<List<PaymentCard>> listMine(String cardholderId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _cards.where((c) => c.cardholderId == cardholderId).toList();
  }

  @override
  Future<List<LedgerMovement>> listMovements(String cardId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final movements = List<LedgerMovement>.from(_movementsByCard[cardId] ?? const []);
    movements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return movements;
  }

  final Map<String, MovementClaim> _claimsByEntryId = {};

  @override
  Future<MovementClaim?> getClaim(String ledgerEntryId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _claimsByEntryId[ledgerEntryId];
  }

  @override
  Future<MovementClaim> fileClaim(String ledgerEntryId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_claimsByEntryId.containsKey(ledgerEntryId)) {
      throw const ClaimAlreadyFiledException();
    }
    final claim = MovementClaim(
      id: 'claim-${DateTime.now().microsecondsSinceEpoch}',
      ledgerEntryId: ledgerEntryId,
      reason: reason,
      status: ClaimStatus.open,
      createdAt: DateTime.now(),
    );
    _claimsByEntryId[ledgerEntryId] = claim;
    return claim;
  }

  @override
  Future<PaymentCard> setFrozen(String cardholderId, String cardId, bool freeze) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _cards.indexWhere((c) => c.id == cardId && c.cardholderId == cardholderId);
    if (index == -1) throw StateError('Tarjeta $cardId no encontrada.');
    final card = _cards[index];

    if (freeze) {
      if (card.status != CardStatus.active) {
        throw StateError('Solo se puede aplicar un bloqueo temporal a una tarjeta activa.');
      }
      final updated = card.copyWith(status: CardStatus.frozen);
      _cards[index] = updated;
      return updated;
    }
    if (card.status != CardStatus.frozen) {
      throw StateError('Esta tarjeta no tiene un bloqueo temporal que quitar.');
    }
    final updated = card.copyWith(status: CardStatus.active);
    _cards[index] = updated;
    return updated;
  }

  @override
  Future<ResolvedTransferDestination?> resolveDestination({
    required String cardholderId,
    required String originCardId,
    required String pan,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if ((_failedAttempts[cardholderId] ?? 0) >= 5) {
      throw const TooManyFailedAttemptsException();
    }

    final origin = _cards.firstWhere((c) => c.id == originCardId);
    final hash = _hashPan(pan);
    final match = _cards.where((c) {
      if (c.clientId != origin.clientId) return false; // fuera de alcance, ver ADR-0009 punto 5
      if (c.cardholderId == origin.cardholderId) return false; // "otro" Tarjetahabiente, no uno mismo
      return _panHashByCardId[c.id] == hash;
    }).firstOrNull;

    if (match == null) {
      final next = (_failedAttempts[cardholderId] ?? 0) + 1;
      _failedAttempts[cardholderId] = next;
      // El propio intento que llega al límite ya informa el bloqueo — no
      // tiene sentido dejar que la persona use un intento más solo para
      // enterarse de que ya no puede.
      if (next >= 5) throw const TooManyFailedAttemptsException();
      return null;
    }
    final destinationCardholder = _cardholders.firstWhere((c) => c.id == match.cardholderId);
    return ResolvedTransferDestination(card: match, cardholderName: destinationCardholder.fullName);
  }

  @override
  Future<void> transfer({
    required String originCardId,
    required String destinationCardId,
    required double amount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final originIndex = _cards.indexWhere((c) => c.id == originCardId);
    final destinationIndex = _cards.indexWhere((c) => c.id == destinationCardId);
    final origin = _cards[originIndex];
    if (origin.balance < amount) {
      throw InsufficientFundsException(currentBalance: origin.balance, requestedAmount: amount);
    }
    final newOriginBalance = origin.balance - amount;
    _cards[originIndex] = origin.copyWith(balance: newOriginBalance);
    final destination = _cards[destinationIndex];
    final newDestinationBalance = destination.balance + amount;
    _cards[destinationIndex] = destination.copyWith(balance: newDestinationBalance);

    final now = DateTime.now();
    _movementsByCard.putIfAbsent(originCardId, () => []).add(
          LedgerMovement(
            id: 'transfer-${now.microsecondsSinceEpoch}-out',
            type: LedgerEntryType.debit,
            amount: amount,
            balanceAfter: newOriginBalance,
            description: 'Transferencia enviada',
            createdAt: now,
          ),
        );
    _movementsByCard.putIfAbsent(destinationCardId, () => []).add(
          LedgerMovement(
            id: 'transfer-${now.microsecondsSinceEpoch}-in',
            type: LedgerEntryType.credit,
            amount: amount,
            balanceAfter: newDestinationBalance,
            description: 'Transferencia recibida',
            createdAt: now,
          ),
        );
  }

  @override
  void resetFailedAttempts(String cardholderId) {
    _failedAttempts.remove(cardholderId);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
