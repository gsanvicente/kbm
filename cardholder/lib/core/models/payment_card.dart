import 'card_network.dart';
import 'card_status.dart';

/// La propia tarjeta de un Tarjetahabiente. A propósito **no** tiene
/// ningún campo de PAN completo ni de hash — ese dato vive aparte, en el
/// almacén restringido que simula `FakeTransferRepository` (ver
/// docs/adr/0009-pan-hash-transit-for-c2c-transfers.md, "guardado en un
/// almacén separado... no mezclado con las lecturas normales de
/// payment_cards"). Ningún código de UI debería poder llegar al PAN a
/// través de este objeto, ni siquiera por accidente.
class PaymentCard {
  final String id;
  final String clientId;
  final String cardholderId;
  final String maskedPan;
  final CardNetwork network;
  final int expiryMonth;
  final int expiryYear;
  final CardStatus status;
  final double balance;
  final String currency;

  const PaymentCard({
    required this.id,
    required this.clientId,
    required this.cardholderId,
    required this.maskedPan,
    required this.network,
    required this.expiryMonth,
    required this.expiryYear,
    required this.status,
    required this.balance,
    this.currency = 'MXN',
  });

  String get expiryLabel => '${expiryMonth.toString().padLeft(2, '0')}/$expiryYear';

  PaymentCard copyWith({double? balance, CardStatus? status}) {
    return PaymentCard(
      id: id,
      clientId: clientId,
      cardholderId: cardholderId,
      maskedPan: maskedPan,
      network: network,
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
      status: status ?? this.status,
      balance: balance ?? this.balance,
      currency: currency,
    );
  }
}
