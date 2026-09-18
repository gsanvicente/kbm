import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/cardholder.dart';
import '../../core/models/id_document_type.dart';
import '../../core/utils/nationality_options.dart';
import '../../core/utils/text_formatters.dart';
import '../../shared_widgets/date_picker_field.dart';
import '../../shared_widgets/section_label.dart';

/// Diálogo de una sola pantalla para dar de alta o editar un
/// Tarjetahabiente — a diferencia del expediente KYB de Cliente, un
/// Tarjetahabiente es una persona física con un conjunto de campos plano
/// que no justifica un wizard de varios pasos. Ver
/// docs/feature/alta-y-gestion-de-tarjetahabientes/README.md.
///
/// [cardholder] `null` significa alta (el resultado se pasa a
/// `CardholderRepository.create`); no-`null` significa edición del mismo
/// registro (el resultado se pasa a `CardholderRepository.update`) — el
/// llamador decide cuál invocar, este diálogo solo captura los datos.
class CardholderFormDialog extends StatefulWidget {
  const CardholderFormDialog({super.key, this.cardholder, required this.clientId});

  final Cardholder? cardholder;
  final String clientId;

  @override
  State<CardholderFormDialog> createState() => _CardholderFormDialogState();
}

class _CardholderFormDialogState extends State<CardholderFormDialog> {
  Cardholder? get _seed => widget.cardholder;
  bool get _isEditing => _seed != null;

  late final _nameController = TextEditingController(text: _seed?.fullName ?? '');
  late final _idNumberController = TextEditingController(text: _seed?.idDocumentNumber ?? '');
  late final _curpController = TextEditingController(text: _seed?.curp ?? '');
  late final _rfcController = TextEditingController(text: _seed?.rfc ?? '');
  late final _streetController = TextEditingController(text: _seed?.addressStreet ?? '');
  late final _neighborhoodController = TextEditingController(text: _seed?.addressNeighborhood ?? '');
  late final _cityController = TextEditingController(text: _seed?.addressCity ?? '');
  late final _stateController = TextEditingController(text: _seed?.addressState ?? '');
  late final _postalCodeController = TextEditingController(text: _seed?.addressPostalCode ?? '');
  late final _countryController = TextEditingController(text: _seed?.addressCountry ?? 'México');
  late final _emailController = TextEditingController(text: _seed?.email ?? '');
  late final _phoneController = TextEditingController(text: _seed?.phone ?? '');

  late IdDocumentType _idDocumentType = _seed?.idDocumentType ?? IdDocumentType.ine;
  late DateTime? _dateOfBirth = _seed?.dateOfBirth;
  late String _nationality = _seed?.nationality ?? 'Mexicana';
  late bool _isPoliticallyExposed = _seed?.isPoliticallyExposed ?? false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _idNumberController,
      _curpController,
      _rfcController,
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
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validate() {
    if (_nameController.text.trim().isEmpty || _idNumberController.text.trim().isEmpty) {
      return 'Completa el nombre completo y el número de identificación.';
    }
    if (isMexicanNationality(_nationality) && _curpController.text.trim().isEmpty) {
      return 'CURP es obligatorio para nacionalidad Mexicana.';
    }
    final postalCode = _postalCodeController.text.trim();
    if (postalCode.isNotEmpty && postalCode.length != 5) {
      return 'El código postal debe tener 5 dígitos.';
    }
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && phone.length != 10) {
      return 'El teléfono debe tener 10 dígitos.';
    }
    final email = _emailController.text.trim();
    if (email.isNotEmpty && !_emailPattern.hasMatch(email)) {
      return 'El email no tiene un formato válido.';
    }
    return null;
  }

  void _submit() {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    String? orNull(String value) => value.trim().isEmpty ? null : value.trim();

    Navigator.pop(
      context,
      Cardholder(
        id: _seed?.id ?? '',
        clientId: widget.clientId,
        fullName: _nameController.text.trim(),
        idDocumentType: _idDocumentType,
        idDocumentNumber: _idNumberController.text.trim(),
        curp: orNull(_curpController.text),
        rfc: orNull(_rfcController.text),
        dateOfBirth: _dateOfBirth,
        nationality: _nationality,
        addressStreet: orNull(_streetController.text),
        addressNeighborhood: orNull(_neighborhoodController.text),
        addressCity: orNull(_cityController.text),
        addressState: orNull(_stateController.text),
        addressPostalCode: orNull(_postalCodeController.text),
        addressCountry: _countryController.text.trim().isEmpty ? 'México' : _countryController.text.trim(),
        isPoliticallyExposed: _isPoliticallyExposed,
        email: orNull(_emailController.text),
        phone: orNull(_phoneController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar tarjetahabiente' : 'Nuevo Tarjetahabiente'),
      content: SizedBox(
        width: 420,
        height: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Identificación'),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre completo')),
              const SizedBox(height: 12),
              DropdownButtonFormField<IdDocumentType>(
                initialValue: _idDocumentType,
                decoration: const InputDecoration(labelText: 'Tipo de identificación'),
                items: [
                  for (final type in IdDocumentType.values) DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) => setState(() => _idDocumentType = value ?? _idDocumentType),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _idNumberController,
                decoration: const InputDecoration(labelText: 'Número de identificación'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _nationality,
                decoration: const InputDecoration(labelText: 'Nacionalidad'),
                items: [
                  for (final option in nationalityOptions) DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: (value) => setState(() => _nationality = value ?? _nationality),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _curpController,
                decoration: InputDecoration(
                  labelText: isMexicanNationality(_nationality) ? 'CURP' : 'CURP (opcional, sin nacionalidad Mexicana)',
                ),
                maxLength: 18,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [alphanumericInputFormatter, UpperCaseTextFormatter()],
              ),
              TextField(
                controller: _rfcController,
                decoration: const InputDecoration(labelText: 'RFC (opcional)'),
                maxLength: 13,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [alphanumericInputFormatter, UpperCaseTextFormatter()],
              ),
              DatePickerField(label: 'Fecha de nacimiento', value: _dateOfBirth, onPick: _pickDateOfBirth),
              const SizedBox(height: 20),
              const SectionLabel('Domicilio'),
              TextField(controller: _streetController, decoration: const InputDecoration(labelText: 'Calle y número')),
              const SizedBox(height: 12),
              TextField(controller: _neighborhoodController, decoration: const InputDecoration(labelText: 'Colonia')),
              const SizedBox(height: 12),
              TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Ciudad')),
              const SizedBox(height: 12),
              TextField(controller: _stateController, decoration: const InputDecoration(labelText: 'Estado')),
              const SizedBox(height: 12),
              TextField(
                controller: _postalCodeController,
                decoration: const InputDecoration(labelText: 'Código postal'),
                keyboardType: TextInputType.number,
                maxLength: 5,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              TextField(controller: _countryController, decoration: const InputDecoration(labelText: 'País')),
              const SizedBox(height: 20),
              const SectionLabel('Contacto'),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 20),
              const SectionLabel('Cumplimiento'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Persona Políticamente Expuesta (PEP)'),
                value: _isPoliticallyExposed,
                onChanged: (value) => setState(() => _isPoliticallyExposed = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: Text(_isEditing ? 'Guardar' : 'Crear')),
      ],
    );
  }
}
