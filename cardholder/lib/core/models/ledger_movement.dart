import 'ledger_entry_type.dart';

/// Un movimiento de la propia tarjeta — sin filtro de fechas ni resumen
/// de periodo todavía, ver "Estado de cuenta" en
/// docs/feature/portal-autoservicio-tarjetahabiente/README.md. Duplicado
/// deliberado del concepto equivalente en `admin/` (ADR-0002): mismo
/// negocio, apps sin código compartido.
class LedgerMovement {
  final String id;
  final LedgerEntryType type;
  final double amount;
  final double balanceAfter;
  final String? description;
  final DateTime createdAt;

  const LedgerMovement({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.description,
  });
}
