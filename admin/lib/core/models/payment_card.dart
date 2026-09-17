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
  }) : assert(
          (cardholderId == null) == (assignedAt == null),
          'cardholderId and assignedAt must both be null or both be set — '
          'see the matching CHECK constraint on backend cards table',
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
    );
  }
}
