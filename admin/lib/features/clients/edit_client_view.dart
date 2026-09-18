import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/acta_constitutiva.dart';
import '../../core/models/apoderado_legal.dart';
import '../../core/models/beneficiario_controlador.dart';
import '../../core/models/client.dart';
import '../../core/models/id_document_type.dart';
import '../../core/models/persona_fisica.dart';
import '../../core/models/tipo_poder.dart';
import '../../core/utils/text_formatters.dart';
import '../../shared_widgets/date_picker_field.dart';
import '../../shared_widgets/section_label.dart';
import 'additional_people_widgets.dart';
import 'client_repository.dart';

/// Edición del expediente KYB de un Cliente ya existente — **no** el
/// wizard de alta. Un wizard lineal es buena UX para capturar datos por
/// primera vez, pero mala UX para corregir un expediente ya completo
/// (obligaría a pasar por cada paso para arreglar un solo campo). Aquí
/// todas las secciones están visibles y desplazables a la vez, sin
/// pasos — ver docs/feature/alta-y-gestion-de-clientes/README.md,
/// "Editar un Cliente existente".
class EditClientView extends StatefulWidget {
  const EditClientView({
    super.key,
    required this.client,
    required this.clientRepository,
    required this.onSaved,
    required this.onCancel,
  });

  final Client client;
  final ClientRepository clientRepository;
  final ValueChanged<Client> onSaved;
  final VoidCallback onCancel;

  @override
  State<EditClientView> createState() => _EditClientViewState();
}

class _EditClientViewState extends State<EditClientView> {
  bool _saving = false;

  late final _razonSocialCtrl = TextEditingController(text: widget.client.razonSocial ?? '');
  late final _nombreComercialCtrl = TextEditingController(text: widget.client.nombreComercial ?? '');
  late final _rfcCtrl = TextEditingController(text: widget.client.rfc ?? '');
  late final _objetoSocialCtrl = TextEditingController(text: widget.client.objetoSocial ?? '');
  late final _actaNumeroEscrituraCtrl = TextEditingController(text: widget.client.actaConstitutiva?.numeroEscritura ?? '');
  late final _actaNotarioCtrl = TextEditingController(text: widget.client.actaConstitutiva?.notario ?? '');
  late final _actaPlazaCtrl = TextEditingController(text: widget.client.actaConstitutiva?.plaza ?? '');
  late final _actaFolioRPCCtrl = TextEditingController(text: widget.client.actaConstitutiva?.folioRPC ?? '');
  late DateTime? _fechaConstitucion = widget.client.fechaConstitucion;
  late DateTime? _actaFecha = widget.client.actaConstitutiva?.fecha;

  late final _streetCtrl = TextEditingController(text: widget.client.addressStreet ?? '');
  late final _neighborhoodCtrl = TextEditingController(text: widget.client.addressNeighborhood ?? '');
  late final _cityCtrl = TextEditingController(text: widget.client.addressCity ?? '');
  late final _stateCtrl = TextEditingController(text: widget.client.addressState ?? '');
  late final _postalCodeCtrl = TextEditingController(text: widget.client.addressPostalCode ?? '');
  late final _countryCtrl = TextEditingController(text: widget.client.addressCountry);

  ApoderadoLegal? get _principalSeed => widget.client.apoderadoPrincipal;
  late final _apoderadoNombreCtrl = TextEditingController(text: _principalSeed?.persona.fullName ?? '');
  late final _apoderadoIdNumberCtrl = TextEditingController(text: _principalSeed?.persona.idDocumentNumber ?? '');
  late final _apoderadoCurpCtrl = TextEditingController(text: _principalSeed?.persona.curp ?? '');
  late final _apoderadoRfcCtrl = TextEditingController(text: _principalSeed?.persona.rfc ?? '');
  late final _apoderadoDescripcionEspecialCtrl =
      TextEditingController(text: _principalSeed?.descripcionPoderEspecial ?? '');
  late final _apoderadoNumeroEscrituraCtrl = TextEditingController(text: _principalSeed?.numeroEscritura ?? '');
  late final _apoderadoNotarioCtrl = TextEditingController(text: _principalSeed?.notario ?? '');
  late IdDocumentType _apoderadoIdType = _principalSeed?.persona.idDocumentType ?? IdDocumentType.ine;
  late TipoPoder _apoderadoTipoPoder = _principalSeed?.tipoPoder ?? TipoPoder.actosDeAdministracion;
  late DateTime? _apoderadoFechaInstrumento = _principalSeed?.fechaInstrumento;
  late DateTime? _apoderadoVigencia = _principalSeed?.vigencia;
  late final List<ApoderadoLegal> _apoderadosAdicionales =
      widget.client.apoderados.where((a) => !a.esPrincipal).toList();

  BeneficiarioControlador? get _mayoritarioSeed => widget.client.beneficiarioMayoritario;
  late final _beneficiarioNombreCtrl = TextEditingController(text: _mayoritarioSeed?.persona.fullName ?? '');
  late final _beneficiarioIdNumberCtrl = TextEditingController(text: _mayoritarioSeed?.persona.idDocumentNumber ?? '');
  late final _beneficiarioCurpCtrl = TextEditingController(text: _mayoritarioSeed?.persona.curp ?? '');
  late final _beneficiarioRfcCtrl = TextEditingController(text: _mayoritarioSeed?.persona.rfc ?? '');
  late final _beneficiarioPorcentajeCtrl = TextEditingController(
    text: _mayoritarioSeed != null ? _mayoritarioSeed!.porcentajeParticipacion.toStringAsFixed(2) : '',
  );
  late IdDocumentType _beneficiarioIdType = _mayoritarioSeed?.persona.idDocumentType ?? IdDocumentType.ine;
  late bool _beneficiarioIsPep = _mayoritarioSeed?.isPoliticallyExposed ?? false;
  late final List<BeneficiarioControlador> _beneficiariosAdicionales =
      widget.client.beneficiariosControladores.where((b) => !b.esMayoritario).toList();

  @override
  void dispose() {
    for (final controller in [
      _razonSocialCtrl,
      _nombreComercialCtrl,
      _rfcCtrl,
      _objetoSocialCtrl,
      _actaNumeroEscrituraCtrl,
      _actaNotarioCtrl,
      _actaPlazaCtrl,
      _actaFolioRPCCtrl,
      _streetCtrl,
      _neighborhoodCtrl,
      _cityCtrl,
      _stateCtrl,
      _postalCodeCtrl,
      _countryCtrl,
      _apoderadoNombreCtrl,
      _apoderadoIdNumberCtrl,
      _apoderadoCurpCtrl,
      _apoderadoRfcCtrl,
      _apoderadoDescripcionEspecialCtrl,
      _apoderadoNumeroEscrituraCtrl,
      _apoderadoNotarioCtrl,
      _beneficiarioNombreCtrl,
      _beneficiarioIdNumberCtrl,
      _beneficiarioCurpCtrl,
      _beneficiarioRfcCtrl,
      _beneficiarioPorcentajeCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required DateTime? initial, required ValueChanged<DateTime> onPicked, bool allowFuture = false}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(1900),
      lastDate: allowFuture ? DateTime(now.year + 50) : now,
    );
    if (picked != null) onPicked(picked);
  }

  String? _validate() {
    if (_razonSocialCtrl.text.trim().isEmpty ||
        _rfcCtrl.text.trim().isEmpty ||
        _objetoSocialCtrl.text.trim().isEmpty ||
        _fechaConstitucion == null ||
        _actaNumeroEscrituraCtrl.text.trim().isEmpty ||
        _actaNotarioCtrl.text.trim().isEmpty ||
        _actaPlazaCtrl.text.trim().isEmpty ||
        _actaFolioRPCCtrl.text.trim().isEmpty ||
        _actaFecha == null) {
      return 'Completa los datos generales y del acta constitutiva.';
    }
    if (_rfcCtrl.text.trim().length != 12) {
      return 'El RFC de persona moral debe tener 12 caracteres.';
    }
    if (_streetCtrl.text.trim().isEmpty ||
        _neighborhoodCtrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty ||
        _stateCtrl.text.trim().isEmpty ||
        _postalCodeCtrl.text.trim().length != 5) {
      return 'Completa el domicilio fiscal (código postal a 5 dígitos).';
    }
    if (_apoderadoNombreCtrl.text.trim().isEmpty ||
        _apoderadoIdNumberCtrl.text.trim().isEmpty ||
        _apoderadoNumeroEscrituraCtrl.text.trim().isEmpty ||
        _apoderadoNotarioCtrl.text.trim().isEmpty ||
        _apoderadoFechaInstrumento == null) {
      return 'Completa los datos del apoderado principal.';
    }
    if (_apoderadoTipoPoder.requiereDescripcion && _apoderadoDescripcionEspecialCtrl.text.trim().isEmpty) {
      return 'Describe las facultades del poder especial.';
    }
    final beneficiarioPorcentaje = double.tryParse(_beneficiarioPorcentajeCtrl.text.trim());
    if (_beneficiarioNombreCtrl.text.trim().isEmpty ||
        _beneficiarioIdNumberCtrl.text.trim().isEmpty ||
        beneficiarioPorcentaje == null ||
        beneficiarioPorcentaje <= 0 ||
        beneficiarioPorcentaje > 100) {
      return 'Completa los datos del beneficiario controlador mayoritario, incluido su % de participación.';
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    final apoderadoPrincipal = ApoderadoLegal(
      persona: PersonaFisica(
        fullName: _apoderadoNombreCtrl.text.trim(),
        idDocumentType: _apoderadoIdType,
        idDocumentNumber: _apoderadoIdNumberCtrl.text.trim(),
        curp: _apoderadoCurpCtrl.text.trim().isEmpty ? null : _apoderadoCurpCtrl.text.trim(),
        rfc: _apoderadoRfcCtrl.text.trim().isEmpty ? null : _apoderadoRfcCtrl.text.trim(),
      ),
      tipoPoder: _apoderadoTipoPoder,
      descripcionPoderEspecial:
          _apoderadoDescripcionEspecialCtrl.text.trim().isEmpty ? null : _apoderadoDescripcionEspecialCtrl.text.trim(),
      numeroEscritura: _apoderadoNumeroEscrituraCtrl.text.trim(),
      notario: _apoderadoNotarioCtrl.text.trim(),
      fechaInstrumento: _apoderadoFechaInstrumento!,
      vigencia: _apoderadoVigencia,
      esPrincipal: true,
    );
    final beneficiarioMayoritario = BeneficiarioControlador(
      persona: PersonaFisica(
        fullName: _beneficiarioNombreCtrl.text.trim(),
        idDocumentType: _beneficiarioIdType,
        idDocumentNumber: _beneficiarioIdNumberCtrl.text.trim(),
        curp: _beneficiarioCurpCtrl.text.trim().isEmpty ? null : _beneficiarioCurpCtrl.text.trim(),
        rfc: _beneficiarioRfcCtrl.text.trim().isEmpty ? null : _beneficiarioRfcCtrl.text.trim(),
      ),
      porcentajeParticipacion: double.parse(_beneficiarioPorcentajeCtrl.text.trim()),
      isPoliticallyExposed: _beneficiarioIsPep,
      esMayoritario: true,
    );

    final updated = widget.client.copyWith(
      // Mismo criterio que en la creación (ver new_client_wizard.dart):
      // el nombre mostrado en el árbol/breadcrumb es el comercial si
      // existe, si no la razón social — se recalcula aquí para que no
      // quede desactualizado tras editar cualquiera de los dos.
      name: _nombreComercialCtrl.text.trim().isNotEmpty ? _nombreComercialCtrl.text.trim() : _razonSocialCtrl.text.trim(),
      razonSocial: _razonSocialCtrl.text.trim(),
      nombreComercial: _nombreComercialCtrl.text.trim().isEmpty ? null : _nombreComercialCtrl.text.trim(),
      rfc: _rfcCtrl.text.trim(),
      fechaConstitucion: _fechaConstitucion,
      objetoSocial: _objetoSocialCtrl.text.trim(),
      actaConstitutiva: ActaConstitutiva(
        numeroEscritura: _actaNumeroEscrituraCtrl.text.trim(),
        notario: _actaNotarioCtrl.text.trim(),
        plaza: _actaPlazaCtrl.text.trim(),
        fecha: _actaFecha!,
        folioRPC: _actaFolioRPCCtrl.text.trim(),
      ),
      addressStreet: _streetCtrl.text.trim(),
      addressNeighborhood: _neighborhoodCtrl.text.trim(),
      addressCity: _cityCtrl.text.trim(),
      addressState: _stateCtrl.text.trim(),
      addressPostalCode: _postalCodeCtrl.text.trim(),
      addressCountry: _countryCtrl.text.trim().isEmpty ? 'México' : _countryCtrl.text.trim(),
      apoderados: [apoderadoPrincipal, ..._apoderadosAdicionales],
      beneficiariosControladores: [beneficiarioMayoritario, ..._beneficiariosAdicionales],
    );

    final saved = await widget.clientRepository.update(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambios guardados.')));
    widget.onSaved(saved);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Empresa padre'),
                  child: Text(widget.client.parentClientId ?? 'Sin empresa padre (empresa raíz)'),
                ),
                const SizedBox(height: 4),
                Text(
                  'La empresa padre no se puede cambiar desde aquí.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 20),
                const SectionLabel('Datos generales'),
                TextField(controller: _razonSocialCtrl, decoration: const InputDecoration(labelText: 'Razón social')),
                const SizedBox(height: 12),
                TextField(
                  controller: _nombreComercialCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre comercial (opcional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rfcCtrl,
                  decoration: const InputDecoration(labelText: 'RFC'),
                  maxLength: 12,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [alphanumericInputFormatter, UpperCaseTextFormatter()],
                ),
                DatePickerField(
                  label: 'Fecha de constitución',
                  value: _fechaConstitucion,
                  onPick: () => _pickDate(
                    initial: _fechaConstitucion,
                    onPicked: (d) => setState(() => _fechaConstitucion = d),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _objetoSocialCtrl,
                  decoration: const InputDecoration(labelText: 'Objeto social / giro'),
                ),
                const SizedBox(height: 20),
                const SectionLabel('Acta constitutiva'),
                TextField(
                  controller: _actaNumeroEscrituraCtrl,
                  decoration: const InputDecoration(labelText: 'Número de escritura'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _actaNotarioCtrl,
                  decoration: const InputDecoration(labelText: 'Notario público (acta)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _actaPlazaCtrl,
                  decoration: const InputDecoration(labelText: 'Plaza / ciudad del notario'),
                ),
                DatePickerField(
                  label: 'Fecha del acta',
                  value: _actaFecha,
                  onPick: () => _pickDate(initial: _actaFecha, onPicked: (d) => setState(() => _actaFecha = d)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _actaFolioRPCCtrl,
                  decoration: const InputDecoration(labelText: 'Folio de Registro Público de Comercio'),
                ),
                const SizedBox(height: 20),
                const SectionLabel('Domicilio fiscal'),
                TextField(controller: _streetCtrl, decoration: const InputDecoration(labelText: 'Calle y número')),
                const SizedBox(height: 12),
                TextField(controller: _neighborhoodCtrl, decoration: const InputDecoration(labelText: 'Colonia')),
                const SizedBox(height: 12),
                TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'Ciudad')),
                const SizedBox(height: 12),
                TextField(controller: _stateCtrl, decoration: const InputDecoration(labelText: 'Estado')),
                const SizedBox(height: 12),
                TextField(
                  controller: _postalCodeCtrl,
                  decoration: const InputDecoration(labelText: 'Código postal'),
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                TextField(controller: _countryCtrl, decoration: const InputDecoration(labelText: 'País')),
                const SizedBox(height: 20),
                const SectionLabel('Apoderado principal'),
                TextField(
                  controller: _apoderadoNombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre completo del apoderado'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<IdDocumentType>(
                  initialValue: _apoderadoIdType,
                  decoration: const InputDecoration(labelText: 'Tipo de identificación (apoderado)'),
                  items: [
                    for (final type in IdDocumentType.values) DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) => setState(() => _apoderadoIdType = value ?? _apoderadoIdType),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apoderadoIdNumberCtrl,
                  decoration: const InputDecoration(labelText: 'Número de identificación (apoderado)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apoderadoCurpCtrl,
                  decoration: const InputDecoration(labelText: 'CURP (apoderado)'),
                  maxLength: 18,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [alphanumericInputFormatter, UpperCaseTextFormatter()],
                ),
                TextField(
                  controller: _apoderadoRfcCtrl,
                  decoration: const InputDecoration(labelText: 'RFC del apoderado (opcional)'),
                  maxLength: 13,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [alphanumericInputFormatter, UpperCaseTextFormatter()],
                ),
                DropdownButtonFormField<TipoPoder>(
                  initialValue: _apoderadoTipoPoder,
                  decoration: const InputDecoration(labelText: 'Tipo de poder'),
                  items: [for (final tipo in TipoPoder.values) DropdownMenuItem(value: tipo, child: Text(tipo.label))],
                  onChanged: (value) => setState(() => _apoderadoTipoPoder = value ?? _apoderadoTipoPoder),
                ),
                if (_apoderadoTipoPoder.requiereDescripcion) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apoderadoDescripcionEspecialCtrl,
                    decoration: const InputDecoration(labelText: 'Describe las facultades otorgadas'),
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _apoderadoNumeroEscrituraCtrl,
                  decoration: const InputDecoration(labelText: 'Número de escritura del poder'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apoderadoNotarioCtrl,
                  decoration: const InputDecoration(labelText: 'Notario público (del poder)'),
                ),
                DatePickerField(
                  label: 'Fecha del instrumento',
                  value: _apoderadoFechaInstrumento,
                  onPick: () => _pickDate(
                    initial: _apoderadoFechaInstrumento,
                    onPicked: (d) => setState(() => _apoderadoFechaInstrumento = d),
                  ),
                ),
                DatePickerField(
                  label: 'Vigencia (opcional)',
                  value: _apoderadoVigencia,
                  onPick: () => _pickDate(
                    initial: _apoderadoVigencia,
                    allowFuture: true,
                    onPicked: (d) => setState(() => _apoderadoVigencia = d),
                  ),
                ),
                const SizedBox(height: 24),
                AdditionalPeopleSection<ApoderadoLegal>(
                  sectionLabel: 'Apoderados adicionales (opcional)',
                  addButtonLabel: '+ Agregar apoderado adicional',
                  items: _apoderadosAdicionales,
                  itemLabel: (a) => a.persona.fullName,
                  itemSubtitle: (a) => a.tipoPoder.label,
                  onRemove: (index) => setState(() => _apoderadosAdicionales.removeAt(index)),
                  onAdd: () async {
                    final added = await showDialog<ApoderadoLegal>(
                      context: context,
                      builder: (context) => const AddApoderadoDialog(),
                    );
                    if (added != null) setState(() => _apoderadosAdicionales.add(added));
                  },
                ),
                const SizedBox(height: 20),
                const SectionLabel('Beneficiario controlador mayoritario'),
                TextField(
                  controller: _beneficiarioNombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre completo del beneficiario'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<IdDocumentType>(
                  initialValue: _beneficiarioIdType,
                  decoration: const InputDecoration(labelText: 'Tipo de identificación (beneficiario)'),
                  items: [
                    for (final type in IdDocumentType.values) DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) => setState(() => _beneficiarioIdType = value ?? _beneficiarioIdType),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _beneficiarioIdNumberCtrl,
                  decoration: const InputDecoration(labelText: 'Número de identificación (beneficiario)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _beneficiarioCurpCtrl,
                  decoration: const InputDecoration(labelText: 'CURP (beneficiario)'),
                  maxLength: 18,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [alphanumericInputFormatter, UpperCaseTextFormatter()],
                ),
                TextField(
                  controller: _beneficiarioRfcCtrl,
                  decoration: const InputDecoration(labelText: 'RFC del beneficiario (opcional)'),
                  maxLength: 13,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [alphanumericInputFormatter, UpperCaseTextFormatter()],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _beneficiarioPorcentajeCtrl,
                  decoration: const InputDecoration(labelText: '% de participación', suffixText: '%'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: percentageInputFormatters,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Persona Políticamente Expuesta (PEP)'),
                  value: _beneficiarioIsPep,
                  onChanged: (value) => setState(() => _beneficiarioIsPep = value),
                ),
                const SizedBox(height: 12),
                AdditionalPeopleSection<BeneficiarioControlador>(
                  sectionLabel: 'Beneficiarios minoritarios (opcional)',
                  addButtonLabel: '+ Agregar beneficiario minoritario',
                  items: _beneficiariosAdicionales,
                  itemLabel: (b) => b.persona.fullName,
                  itemSubtitle: (b) => '${b.porcentajeParticipacion.toStringAsFixed(2)}% de participación',
                  onRemove: (index) => setState(() => _beneficiariosAdicionales.removeAt(index)),
                  onAdd: () async {
                    final added = await showDialog<BeneficiarioControlador>(
                      context: context,
                      builder: (context) => const AddBeneficiarioDialog(),
                    );
                    if (added != null) setState(() => _beneficiariosAdicionales.add(added));
                  },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar cambios'),
              ),
              const SizedBox(width: 12),
              TextButton(onPressed: _saving ? null : widget.onCancel, child: const Text('Cancelar')),
            ],
          ),
        ),
      ],
    );
  }
}
