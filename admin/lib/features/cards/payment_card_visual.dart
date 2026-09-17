import 'package:flutter/material.dart';

import '../../core/models/card_status.dart';
import '../../core/models/payment_card.dart';

/// Visual representation of a PaymentCard, reused everywhere a card needs
/// to look like a physical card: the KBM blank template
/// (assets/images/card_black_template.png) with the cardholder's real
/// data drawn directly on it. Unlike the original card_black.png asset,
/// this template has no sample PAN/company name baked into its pixels —
/// those areas are already empty, so no masking is needed, just placing
/// text in the right spot.
///
/// Reused at any size via [width] — small thumbnails in a list, or a
/// large hero card in a detail view (see CardDetailView).
class PaymentCardVisual extends StatelessWidget {
  const PaymentCardVisual({
    super.key,
    required this.card,
    this.cardholderName,
    this.onTap,
    this.width = 220,
  });

  final PaymentCard card;

  /// null for a Disponible (unassigned) card — see
  /// docs/business/tarjetas-y-asignacion.md.
  final String? cardholderName;
  final VoidCallback? onTap;
  final double width;

  // assets/images/card_black_template.png was cropped to its exact visible
  // bounds (915x509) — the original 1264x842 file had a large transparent
  // margin around the card (meant for a "floating mockup" look), which
  // silently broke this widget: the status badge landed in that dead
  // space instead of the card's corner, and field boxes proportioned for
  // a large print image rendered unreadably small at UI sizes.
  static const _imageAspectRatio = 915 / 509;

  // left, top, width, height — fractions of the CROPPED image. Boxes are
  // deliberately more generous than the exact original text placement
  // (which was sized for a large printed card) so the overlay stays
  // legible at on-screen sizes — verified against the chip/logo/ghost-icon
  // positions to avoid collisions. See
  // docs/feature/tarjetas-de-tarjetahabiente/README.md.
  static const _panBox = _FieldBox(0.090, 0.600, 0.55, 0.11);
  static const _nameBox = _FieldBox(0.090, 0.800, 0.40, 0.10);
  static const _expiryBox = _FieldBox(0.52, 0.800, 0.20, 0.10);

  static const _textColor = Color(0xFFC9CFD4);

  @override
  Widget build(BuildContext context) {
    final height = width / _imageAspectRatio;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/card_black_template.png', fit: BoxFit.fill),
            ),
            _field(box: _panBox, text: card.maskedPan, fontFamily: 'monospace', letterSpacing: 1.5),
            _field(box: _nameBox, text: (cardholderName ?? 'Sin asignar').toUpperCase()),
            _field(box: _expiryBox, text: card.expiryLabel, fontFamily: 'monospace'),
            Positioned(
              top: height * 0.02,
              right: width * 0.02,
              child: _StatusBadge(status: card.status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required _FieldBox box,
    required String text,
    String? fontFamily,
    double letterSpacing = 0.5,
  }) {
    return Positioned(
      left: box.left * width,
      top: box.top * (width / _imageAspectRatio),
      width: box.width * width,
      height: box.height * (width / _imageAspectRatio),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(
              color: _textColor,
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
              letterSpacing: letterSpacing,
              fontSize: 40, // oversized on purpose — FittedBox scales it
                            // down to the field's real size, so it never
                            // overflows regardless of text length.
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldBox {
  const _FieldBox(this.left, this.top, this.width, this.height);
  final double left;
  final double top;
  final double width;
  final double height;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final CardStatus status;

  Color get _color {
    switch (status) {
      case CardStatus.active:
        return const Color(0xFF43AB63);
      case CardStatus.unassigned:
        return Colors.grey.shade500;
      case CardStatus.blocked:
      case CardStatus.cancelled:
        return Colors.red.shade400;
      case CardStatus.frozen:
        return Colors.blue.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(4)),
      child: Text(
        status.label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
