import 'card_blocked_reason.dart';
import 'card_cancelled_reason.dart';
import 'card_network.dart';
import 'card_status.dart';

/// Named PaymentCard, not "Card" — avoids colliding with Flutter's own
/// Card widget (package:flutter/material.dart), used throughout the UI.
class PaymentCard {
  final String id;
  final String clientId;
  final String? cardholderId;
  final String maskedPan;
  final CardNetwork network;
  final int expiryMonth;
  final int expiryYear;
  final CardStatus status;
  final DateTime? assignedAt;

  /// Por qué está `blocked` — `null` para cualquier otro estado. Ver
  /// docs/business/tarjetas-y-asignacion.md, "Motivo de bloqueo". Se
  /// construye directamente (no vía [copyWith]) en `FakeCardRepository`
  /// cada vez que cambia, para poder limpiarlo a `null` explícitamente al
  /// desbloquear — mismo motivo por el que `Client.update()` no usa
  /// `copyWith` (ver fake_client_repository.dart).
  final CardBlockedReason? blockedReason;

  /// Por qué está `cancelled` — `null` para cualquier otro estado. Ver
  /// docs/adr/0020-cuenta-individual-tarjetahabiente.md, "Reemplazo de
  /// tarjeta".
  final CardCancelledReason? cancelledReason;

  PaymentCard({
    required this.id,
    required this.clientId,
    this.cardholderId,
    required this.maskedPan,
    required this.network,
    required this.expiryMonth,
    required this.expiryYear,
    required this.status,
    this.assignedAt,
    this.blockedReason,
    this.cancelledReason,
  }) : assert(
          (cardholderId == null) == (assignedAt == null),
          'cardholderId and assignedAt must both be null or both be set — '
          'see the matching CHECK constraint on backend cards table',
        ),
        assert(
          status == CardStatus.blocked || blockedReason == null,
          'blockedReason only makes sense when status is blocked',
        ),
        assert(
          status == CardStatus.cancelled || cancelledReason == null,
          'cancelledReason only makes sense when status is cancelled',
        );

  bool get isAvailable => status == CardStatus.unassigned;

  String get expiryLabel => '${expiryMonth.toString().padLeft(2, '0')}/$expiryYear';

  PaymentCard copyWith({
    String? cardholderId,
    CardStatus? status,
    DateTime? assignedAt,
  }) {
    return PaymentCard(
      id: id,
      clientId: clientId,
      cardholderId: cardholderId ?? this.cardholderId,
      maskedPan: maskedPan,
      network: network,
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
      status: status ?? this.status,
      assignedAt: assignedAt ?? this.assignedAt,
      // No hay parámetro `blockedReason` aquí a propósito — cambiar el
      // motivo de bloqueo siempre se hace con una construcción directa
      // (ver setBlocked/freezeAllForCardholder en FakeCardRepository),
      // nunca con copyWith. Aquí solo se preserva si sigue bloqueada, o
      // se limpia si el nuevo estado ya no lo es.
      blockedReason: (status ?? this.status) == CardStatus.blocked ? blockedReason : null,
      // Mismo criterio que blockedReason arriba — cambiar el motivo de
      // cancelación siempre se hace con una construcción directa (ver
      // FakeCardRepository.replace), nunca con copyWith.
      cancelledReason: (status ?? this.status) == CardStatus.cancelled ? cancelledReason : null,
    );
  }
}
