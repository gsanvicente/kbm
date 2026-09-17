import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/cardholder.dart';
import '../../core/models/id_document_type.dart';
import '../../core/models/payment_card.dart';
import '../../core/models/session.dart';
import '../cards/card_list_view.dart';
import '../cards/card_repository.dart';
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

  bool get _canManage => widget.session.role.canManageCardholders;

  Future<void> _editInfo() async {
    final updated = await showDialog<Cardholder>(
      context: context,
      builder: (context) => _EditCardholderDialog(cardholder: _cardholder),
    );
    if (updated == null) return;

    setState(() => _busy = true);
    final saved = await widget.repository.update(updated);
    setState(() {
      _cardholder = saved;
      _busy = false;
    });
    widget.onChanged(saved);
  }

  Future<void> _toggleActive() async {
    setState(() => _busy = true);
    final saved = await widget.repository.setActive(_cardholder.id, !_cardholder.isActive);
    setState(() {
      _cardholder = saved;
      _busy = false;
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
                OutlinedButton.icon(
                  onPressed: _editInfo,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _toggleActive,
                  icon: Icon(c.isActive ? Icons.block_outlined : Icons.check_circle_outline, size: 18),
                  label: Text(c.isActive ? 'Desactivar' : 'Activar'),
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

class _EditCardholderDialog extends StatefulWidget {
  const _EditCardholderDialog({required this.cardholder});

  final Cardholder cardholder;

  @override
  State<_EditCardholderDialog> createState() => _EditCardholderDialogState();
}

class _EditCardholderDialogState extends State<_EditCardholderDialog> {
  late final _nameController = TextEditingController(text: widget.cardholder.fullName);
  late final _idNumberController = TextEditingController(text: widget.cardholder.idDocumentNumber);
  late final _curpController = TextEditingController(text: widget.cardholder.curp ?? '');
  late final _rfcController = TextEditingController(text: widget.cardholder.rfc ?? '');
  late final _nationalityController = TextEditingController(text: widget.cardholder.nationality);
  late final _streetController = TextEditingController(text: widget.cardholder.addressStreet ?? '');
  late final _neighborhoodController = TextEditingController(text: widget.cardholder.addressNeighborhood ?? '');
  late final _cityController = TextEditingController(text: widget.cardholder.addressCity ?? '');
  late final _stateController = TextEditingController(text: widget.cardholder.addressState ?? '');
  late final _postalCodeController = TextEditingController(text: widget.cardholder.addressPostalCode ?? '');
  late final _countryController = TextEditingController(text: widget.cardholder.addressCountry);
  late final _emailController = TextEditingController(text: widget.cardholder.email ?? '');
  late final _phoneController = TextEditingController(text: widget.cardholder.phone ?? '');

  late IdDocumentType _idDocumentType = widget.cardholder.idDocumentType;
  late DateTime? _dateOfBirth = widget.cardholder.dateOfBirth;
  late bool _isPoliticallyExposed = widget.cardholder.isPoliticallyExposed;

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _idNumberController,
      _curpController,
      _rfcController,
      _nationalityController,
      _streetController,
      _neighborhoodController,
      _cityController,
      _stateController,
      _postalCodeController,
      _countryController,
      _emailController,
      _phoneController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar tarjetahabiente'),
      content: SizedBox(
        width: 420,
        height: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DialogSectionLabel('Identificación'),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre completo')),
              const SizedBox(height: 12),
              DropdownButtonFormField<IdDocumentType>(
                initialValue: _idDocumentType,
                decoration: const InputDecoration(labelText: 'Tipo de identificación'),
                items: [
                  for (final type in IdDocumentType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) => setState(() => _idDocumentType = value ?? _idDocumentType),
              ),
              const SizedBox(height: 12),
              TextField(controller: _idNumberController, decoration: const InputDecoration(labelText: 'Número de identificación')),
              const SizedBox(height: 12),
              TextField(controller: _curpController, decoration: const InputDecoration(labelText: 'CURP'), maxLength: 18),
              TextField(controller: _rfcController, decoration: const InputDecoration(labelText: 'RFC'), maxLength: 13),
              InkWell(
                onTap: _pickDateOfBirth,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha de nacimiento'),
                  child: Text(_dateOfBirth != null ? _formatDate(_dateOfBirth) : 'Seleccionar'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _nationalityController, decoration: const InputDecoration(labelText: 'Nacionalidad')),
              const SizedBox(height: 20),
              const _DialogSectionLabel('Domicilio'),
              TextField(controller: _streetController, decoration: const InputDecoration(labelText: 'Calle y número')),
              const SizedBox(height: 12),
              TextField(controller: _neighborhoodController, decoration: const InputDecoration(labelText: 'Colonia')),
              const SizedBox(height: 12),
              TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Ciudad')),
              const SizedBox(height: 12),
              TextField(controller: _stateController, decoration: const InputDecoration(labelText: 'Estado')),
              const SizedBox(height: 12),
              TextField(controller: _postalCodeController, decoration: const InputDecoration(labelText: 'Código postal')),
              const SizedBox(height: 12),
              TextField(controller: _countryController, decoration: const InputDecoration(labelText: 'País')),
              const SizedBox(height: 20),
              const _DialogSectionLabel('Contacto'),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Teléfono')),
              const SizedBox(height: 20),
              const _DialogSectionLabel('Cumplimiento'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Persona Políticamente Expuesta (PEP)'),
                value: _isPoliticallyExposed,
                onChanged: (value) => setState(() => _isPoliticallyExposed = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              widget.cardholder.copyWith(
                fullName: _nameController.text.trim(),
                idDocumentType: _idDocumentType,
                idDocumentNumber: _idNumberController.text.trim(),
                curp: _curpController.text.trim(),
                rfc: _rfcController.text.trim(),
                dateOfBirth: _dateOfBirth,
                nationality: _nationalityController.text.trim(),
                addressStreet: _streetController.text.trim(),
                addressNeighborhood: _neighborhoodController.text.trim(),
                addressCity: _cityController.text.trim(),
                addressState: _stateController.text.trim(),
                addressPostalCode: _postalCodeController.text.trim(),
                addressCountry: _countryController.text.trim(),
                isPoliticallyExposed: _isPoliticallyExposed,
                email: _emailController.text.trim(),
                phone: _phoneController.text.trim(),
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, color: KoonsColors.navy, fontSize: 12),
      ),
    );
  }
}
