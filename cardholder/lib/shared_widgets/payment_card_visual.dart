import 'package:flutter/material.dart';

import '../core/models/card_status.dart';
import '../core/models/payment_card.dart';

/// Representación visual de una tarjeta — mismo diseño que
/// `admin/lib/features/cards/payment_card_visual.dart` (la plantilla en
/// blanco `assets/images/card_black_template.png`, con los datos reales
/// dibujados encima): número enmascarado, nombre del Tarjetahabiente y
/// vigencia, nunca el PAN completo. Es el mismo activo de marca en toda
/// la plataforma — código duplicado a propósito (ADR-0002: `admin/` y
/// `cardholder/` no comparten runtime), pero el diseño **no** debe
/// divergir: una tarjeta debe verse igual sin importar desde qué app se
/// mire.
///
/// Reusable a cualquier tamaño vía [width] — miniatura en "Mis
/// tarjetas", o tarjeta grande en Inicio.
class PaymentCardVisual extends StatelessWidget {
  const PaymentCardVisual({
    super.key,
    required this.card,
    required this.cardholderName,
    this.onTap,
    this.width = 220,
  });

  final PaymentCard card;
  final String cardholderName;
  final VoidCallback? onTap;
  final double width;

  // Ver el doc de la clase gemela en `admin/` para el porqué de estos
  // números exactos — el recorte y las cajas de campo deben coincidir
  // pixel a pixel con esa versión, es el mismo activo.
  static const _imageAspectRatio = 915 / 509;

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
            _field(box: _nameBox, text: cardholderName.toUpperCase()),
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
              fontSize: 40,
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
      case CardStatus.blocked:
        return Colors.red.shade400;
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
