import 'package:flutter/material.dart';

/// Diálogo reutilizable de "¿estás seguro?" para cualquier acción que
/// mueva dinero o cambie estado con impacto real (aprobar/conciliar/
/// bloquear) — ninguna de esas acciones debe poder ejecutarse con un solo
/// toque accidental. [destructive] tiñe el botón de confirmar en rojo,
/// para acciones que restringen algo (bloquear, rechazar) en vez de
/// habilitarlo.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelLabel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
