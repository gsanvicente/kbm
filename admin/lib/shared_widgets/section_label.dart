import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Encabezado de una sección dentro de un formulario largo (wizard de
/// alta de Cliente, edición de Cliente) — separa visualmente bloques de
/// campos relacionados sin necesitar un `Card` o `Divider` por sección.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KoonsColors.navy),
      ),
    );
  }
}
