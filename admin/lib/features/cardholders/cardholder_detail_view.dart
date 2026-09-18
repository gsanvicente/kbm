import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/cardholder.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/session.dart';
import '../cards/card_list_view.dart';
import '../cards/card_repository.dart';
import 'cardholder_form_dialog.dart';
import 'cardholder_repository.dart';

class CardholderDetailView extends StatefulWidget {
  const CardholderDetailView({
    super.key,
    required this.cardholder,
    required this.clientName,
    required this.repository,
    required this.cardRepository,
    required this.session,
    required this.onChanged,
    this.onSelectCard,
  });

  final Cardholder cardholder;
  final String clientName;
  final CardholderRepository repository;
  final CardRepository cardRepository;
  final Session session;

  /// Called after a successful edit/deactivate so the caller (list views)
  /// can refresh — the fake repository mutates its own in-memory list, but
  /// already-fetched Futures elsewhere won't see the change on their own.
  final ValueChanged<Cardholder> onChanged;

  /// Tapping a card in the "Tarjetas" section bubbles up here — the
  /// parent Section widget owns the whole breadcrumb chain (see
  /// ClientesSection/TarjetahabientesSection), this view never navigates
  /// on its own.
  final ValueChanged<PaymentCard>? onSelectCard;

  @override
  State<CardholderDetailView> createState() => _CardholderDetailViewState();
}

class _CardholderDetailViewState extends State<CardholderDetailView> {
  late Cardholder _cardholder = widget.cardholder;
  bool _busy = false;

  /// Fuerza a `CardListView` (sección "Tarjetas") a remontarse y volver a
  /// pedir sus datos tras (des)activar — el Future que ya resolvió no se
  /// entera solo de que `freezeAllForCardholder` congeló sus tarjetas.
  /// Mismo truco que `CardholderSearchField` en el listado global.
  int _cardsListGeneration = 0;

  bool get _canManage => widget.session.role.canManageCardholders;

  Future<void> _editInfo() async {
    final updated = await showDialog<Cardholder>(
      context: context,
      builder: (context) => CardholderFormDialog(cardholder: _cardholder, clientId: _cardholder.clientId),
    );
    if (updated == null) return;

    setState(() => _busy = true);
    final saved = await widget.repository.update(updated);
    if (!mounted) return;
    setState(() {
      _cardholder = saved;
      _busy = false;
    });
    widget.onChanged(saved);
  }

  Future<void> _confirmToggleActive() async {
    final activating = !_cardholder.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activating ? 'Reactivar tarjetahabiente' : 'Desactivar tarjetahabiente'),
        content: Text(
          activating
              ? '${_cardholder.fullName} podrá volver a recibir tarjetas nuevas. Sus tarjetas ya congeladas '
                  'seguirán bloqueadas hasta que las desbloquees manualmente, una por una.'
              : '${_cardholder.fullName} no podrá recibir tarjetas nuevas, y todas sus tarjetas activas se '
                  'bloquearán de inmediato. Su expediente dejará de poder editarse mientras esté inactivo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: activating ? null : FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: Text(activating ? 'Reactivar' : 'Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final saved = await widget.repository.setActive(_cardholder.id, activating);
    if (!mounted) return;
    setState(() {
      _cardholder = saved;
      _busy = false;
      _cardsListGeneration++;
    });
    widget.onChanged(saved);
  }

  @override
  Widget build(BuildContext context) {
    final c = _cardholder;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: KoonsColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_rounded, color: KoonsColors.blue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.fullName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _StatusBadge(isActive: c.isActive),
                        if (c.isPoliticallyExposed)
                          _Badge(label: 'PEP', color: Colors.orange.shade800, background: Colors.orange.shade50),
                      ],
                    ),
                  ],
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              if (_canManage && !_busy) ...[
                // Un tarjetahabiente inactivo no puede editarse — ver
                // docs/business/desactivacion-de-tarjetahabientes.md. El
                // botón ni siquiera aparece (no solo se deshabilita), y
                // el repositorio también lo rechaza como defensa en
                // profundidad.
                if (c.isActive) ...[
                  OutlinedButton.icon(
                    onPressed: _editInfo,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  onPressed: _confirmToggleActive,
                  icon: Icon(c.isActive ? Icons.block_outlined : Icons.check_circle_outline, size: 18),
                  label: Text(c.isActive ? 'Desactivar' : 'Reactivar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.isActive ? Colors.red.shade700 : KoonsColors.green,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),
          _Section(
            title: 'Identificación',
            children: [
              _InfoRow(label: 'Cliente', value: widget.clientName),
              _InfoRow(label: 'Identificación oficial', value: '${c.idDocumentType.label} · ${c.idDocumentNumber}'),
              _InfoRow(label: 'CURP', value: c.curp ?? '—'),
              _InfoRow(label: 'RFC', value: c.rfc ?? '—'),
              _InfoRow(label: 'Fecha de nacimiento', value: _formatDate(c.dateOfBirth)),
              _InfoRow(label: 'Nacionalidad', value: c.nationality),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Domicilio',
            children: [
              _InfoRow(label: 'Calle', value: c.addressStreet ?? '—'),
              _InfoRow(label: 'Colonia', value: c.addressNeighborhood ?? '—'),
              _InfoRow(label: 'Ciudad', value: c.addressCity ?? '—'),
              _InfoRow(label: 'Estado', value: c.addressState ?? '—'),
              _InfoRow(label: 'Código postal', value: c.addressPostalCode ?? '—'),
              _InfoRow(label: 'País', value: c.addressCountry),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Contacto',
            children: [
              _InfoRow(label: 'Email', value: c.email ?? '—'),
              _InfoRow(label: 'Teléfono', value: c.phone ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Cumplimiento',
            children: [
              _InfoRow(label: 'Persona Políticamente Expuesta', value: c.isPoliticallyExposed ? 'Sí' : 'No'),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Tarjetas',
            children: [
              CardListView(
                key: ValueKey(_cardsListGeneration),
                repository: widget.cardRepository,
                cardholderId: c.id,
                cardholderName: c.fullName,
                onSelect: widget.onSelectCard,
              ),
            ],
          ),
          if (!_canManage) ...[
            const SizedBox(height: 16),
            Text(
              'Tu rol (${widget.session.role.label}) puede ver esta información pero no editarla ni desactivar al tarjetahabiente.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, color: KoonsColors.navy, fontSize: 13),
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? KoonsColors.green : Colors.red.shade700;
    final background = isActive ? KoonsColors.green.withValues(alpha: 0.12) : Colors.red.shade50;
    return _Badge(label: isActive ? 'Activo' : 'Inactivo', color: color, background: background);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

