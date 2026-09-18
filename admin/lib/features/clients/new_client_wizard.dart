import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/acta_constitutiva.dart';
import '../../core/models/apoderado_legal.dart';
import '../../core/models/beneficiario_controlador.dart';
import '../../core/models/client.dart';
import '../../core/models/id_document_type.dart';
import '../../core/models/persona_fisica.dart';
import '../../core/models/role.dart';
import '../../core/models/session.dart';
import '../../core/models/tipo_poder.dart';
import '../../core/utils/text_formatters.dart';
import '../../shared_widgets/date_picker_field.dart';
import '../../shared_widgets/section_label.dart';
import 'additional_people_widgets.dart';
import 'client_repository.dart';

/// Wizard de alta de un Cliente nuevo con su expediente KYB completo —
/// ver docs/feature/alta-y-gestion-de-clientes/README.md. Vive dentro de
/// ClientesSection con el mismo criterio de navegación de breadcrumb del
/// resto de la sección — no es un diálogo modal, dado el volumen de
/// contenido (seis pasos).
class NewClientWizard extends StatefulWidget {
  const NewClientWizard({
    super.key,
    required this.session,
    required this.clientRepository,
    required this.onCreated,
  });

  final Session session;
  final ClientRepository clientRepository;
  final ValueChanged<Client> onCreated;

  @override
  State<NewClientWizard> createState() => _NewClientWizardState();
}

class _NewClientWizardState extends State<NewClientWizard> {
  late Future<List<Client>> _parentOptionsFuture;
  int _step = 0;
  bool _saving = false;

  // Paso 0: ubicación en la jerarquía.
  String? _parentClientId;
  bool _sinPadre = false;

  // Paso 1: datos generales.
  final _razonSocialCtrl = TextEditingController();
  final _nombreComercialCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _objetoSocialCtrl = TextEditingController();
  final _actaNumeroEscrituraCtrl = TextEditingController();
  final _actaNotarioCtrl = TextEditingController();
  final _actaPlazaCtrl = TextEditingController();
  final _actaFolioRPCCtrl = TextEditingController();
  DateTime? _fechaConstitucion;
  DateTime? _actaFecha;

  // Paso 2: domicilio fiscal.
  final _streetCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'México');

  // Paso 3: apoderado principal + adicionales.
  final _apoderadoNombreCtrl = TextEditingController();
  final _apoderadoIdNumberCtrl = TextEditingController();
  final _apoderadoCurpCtrl = TextEditingController();
  final _apoderadoRfcCtrl = TextEditingController();
  final _apoderadoDescripcionEspecialCtrl = TextEditingController();
  final _apoderadoNumeroEscrituraCtrl = TextEditingController();
  final _apoderadoNotarioCtrl = TextEditingController();
  IdDocumentType _apoderadoIdType = IdDocumentType.ine;
  TipoPoder _apoderadoTipoPoder = TipoPoder.actosDeAdministracion;
  DateTime? _apoderadoFechaInstrumento;
  DateTime? _apoderadoVigencia;
  final List<ApoderadoLegal> _apoderadosAdicionales = [];

  // Paso 4: beneficiario mayoritario + minoritarios.
  final _beneficiarioNombreCtrl = TextEditingController();
  final _beneficiarioIdNumberCtrl = TextEditingController();
  final _beneficiarioCurpCtrl = TextEditingController();
  final _beneficiarioRfcCtrl = TextEditingController();
  final _beneficiarioPorcentajeCtrl = TextEditingController();
  IdDocumentType _beneficiarioIdType = IdDocumentType.ine;
  bool _beneficiarioIsPep = false;
  final List<BeneficiarioControlador> _beneficiariosAdicionales = [];

  @override
  void initState() {
    super.initState();
    _parentOptionsFuture = widget.clientRepository.listAccessibleClients(widget.session);
  }

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

  bool get _isSuperAdmin => widget.session.role == Role.superAdmin;

  ApoderadoLegal get _apoderadoPrincipal => ApoderadoLegal(
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
        fechaInstrumento: _apoderadoFechaInstrumento ?? DateTime.now(),
        vigencia: _apoderadoVigencia,
        esPrincipal: true,
      );

  BeneficiarioControlador get _beneficiarioMayoritario => BeneficiarioControlador(
        persona: PersonaFisica(
          fullName: _beneficiarioNombreCtrl.text.trim(),
          idDocumentType: _beneficiarioIdType,
          idDocumentNumber: _beneficiarioIdNumberCtrl.text.trim(),
          curp: _beneficiarioCurpCtrl.text.trim().isEmpty ? null : _beneficiarioCurpCtrl.text.trim(),
          rfc: _beneficiarioRfcCtrl.text.trim().isEmpty ? null : _beneficiarioRfcCtrl.text.trim(),
        ),
        porcentajeParticipacion: double.tryParse(_beneficiarioPorcentajeCtrl.text.trim()) ?? 0,
        isPoliticallyExposed: _beneficiarioIsPep,
        esMayoritario: true,
      );

  String? _validateStep(int step) {
    switch (step) {
      case 0:
        if (!_sinPadre && _parentClientId == null) {
          return 'Elige bajo qué empresa se crea este Cliente.';
        }
        return null;
      case 1:
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
        return null;
      case 2:
        if (_streetCtrl.text.trim().isEmpty ||
            _neighborhoodCtrl.text.trim().isEmpty ||
            _cityCtrl.text.trim().isEmpty ||
            _stateCtrl.text.trim().isEmpty ||
            _postalCodeCtrl.text.trim().isEmpty) {
          return 'Completa el domicilio fiscal.';
        }
        if (_postalCodeCtrl.text.trim().length != 5) {
          return 'El código postal debe tener 5 dígitos.';
        }
        return null;
      case 3:
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
        if (_apoderadoCurpCtrl.text.trim().isNotEmpty && _apoderadoCurpCtrl.text.trim().length != 18) {
          return 'La CURP debe tener 18 caracteres.';
        }
        if (_apoderadoRfcCtrl.text.trim().isNotEmpty && _apoderadoRfcCtrl.text.trim().length != 13) {
          return 'El RFC de persona física debe tener 13 caracteres.';
        }
        return null;
      case 4:
        final porcentaje = double.tryParse(_beneficiarioPorcentajeCtrl.text.trim());
        if (_beneficiarioNombreCtrl.text.trim().isEmpty ||
            _beneficiarioIdNumberCtrl.text.trim().isEmpty ||
            porcentaje == null ||
            porcentaje <= 0) {
          return 'Completa los datos del beneficiario controlador mayoritario, incluido su % de participación.';
        }
        if (porcentaje > 100) {
          return 'El % de participación no puede ser mayor a 100.';
        }
        if (_beneficiarioCurpCtrl.text.trim().isNotEmpty && _beneficiarioCurpCtrl.text.trim().length != 18) {
          return 'La CURP debe tener 18 caracteres.';
        }
        if (_beneficiarioRfcCtrl.text.trim().isNotEmpty && _beneficiarioRfcCtrl.text.trim().length != 13) {
          return 'El RFC de persona física debe tener 13 caracteres.';
        }
        return null;
      default:
        return null;
    }
  }

  void _goNext() {
    final error = _validateStep(_step);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (_step < 5) setState(() => _step++);
  }

  void _goBack() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _create() async {
    setState(() => _saving = true);
    final draft = Client(
      id: '',
      name: _nombreComercialCtrl.text.trim().isNotEmpty ? _nombreComercialCtrl.text.trim() : _razonSocialCtrl.text.trim(),
      parentClientId: _sinPadre ? null : _parentClientId,
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
      apoderados: [_apoderadoPrincipal, ..._apoderadosAdicionales],
      beneficiariosControladores: [_beneficiarioMayoritario, ..._beneficiariosAdicionales],
    );

    final created = await widget.clientRepository.create(draft);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cliente "${created.name}" creado.')),
    );
    widget.onCreated(created);
  }

  /// [allowFuture] es para "Vigencia" de un poder — a diferencia de una
  /// fecha de constitución o de firma de un instrumento (que nunca
  /// pueden ser futuras), una fecha de vencimiento casi siempre lo es.
  Future<DateTime?> _pickDate({DateTime? initial, bool allowFuture = false}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(1900),
      lastDate: allowFuture ? DateTime(now.year + 50) : now,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Client>>(
      future: _parentOptionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar Clientes: ${snapshot.error}'));
        }
        final parentOptions = snapshot.data!;

        return Stepper(
          type: StepperType.vertical,
          currentStep: _step,
          onStepContinue: _step == 5 ? _create : _goNext,
          onStepCancel: _step > 0 ? _goBack : null,
          controlsBuilder: (context, details) {
            // Stepper vertical monta los controles de TODOS los pasos a
            // la vez (Visibility, no IndexedStack) — sin este filtro,
            // cinco filas de controles quedan invisibles pero montadas,
            // ambiguas tanto para el usuario con lector de pantalla como
            // para los tests de widget.
            if (!details.isActive) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  FilledButton(
                    onPressed: _saving ? null : details.onStepContinue,
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_step == 5 ? 'Crear Cliente' : 'Siguiente'),
                  ),
                  const SizedBox(width: 12),
                  if (details.onStepCancel != null)
                    TextButton(onPressed: _saving ? null : details.onStepCancel, child: const Text('Atrás')),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Ubicación'),
              isActive: _step >= 0,
              state: _step > 0 ? StepState.complete : StepState.indexed,
              content: _buildUbicacionStep(parentOptions),
            ),
            Step(
              title: const Text('Datos generales'),
              isActive: _step >= 1,
              state: _step > 1 ? StepState.complete : StepState.indexed,
              content: _buildDatosGeneralesStep(),
            ),
            Step(
              title: const Text('Domicilio fiscal'),
              isActive: _step >= 2,
              state: _step > 2 ? StepState.complete : StepState.indexed,
              content: _buildDomicilioStep(),
            ),
            Step(
              title: const Text('Apoderados'),
              isActive: _step >= 3,
              state: _step > 3 ? StepState.complete : StepState.indexed,
              content: _buildApoderadosStep(),
            ),
            Step(
              title: const Text('Beneficiarios'),
              isActive: _step >= 4,
              state: _step > 4 ? StepState.complete : StepState.indexed,
              content: _buildBeneficiariosStep(),
            ),
            Step(
              title: const Text('Revisión'),
              isActive: _step >= 5,
              state: StepState.indexed,
              content: _buildRevisionStep(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUbicacionStep(List<Client> parentOptions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSuperAdmin
              ? 'Elige bajo qué empresa se crea este Cliente, o créalo como una nueva empresa raíz.'
              : 'Elige bajo qué empresa (la tuya o alguna de tus filiales) se crea este Cliente.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        if (_isSuperAdmin)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Crear sin empresa padre (nueva empresa raíz)'),
            value: _sinPadre,
            onChanged: (value) => setState(() {
              _sinPadre = value;
              if (value) _parentClientId = null;
            }),
          ),
        if (!_sinPadre)
          DropdownButtonFormField<String>(
            initialValue: _parentClientId,
            decoration: const InputDecoration(labelText: 'Empresa padre'),
            items: [
              for (final client in parentOptions) DropdownMenuItem(value: client.id, child: Text(client.name)),
            ],
            onChanged: (value) => setState(() => _parentClientId = value),
          ),
      ],
    );
  }

  Widget _buildDatosGeneralesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          onPick: () async {
            final picked = await _pickDate(initial: _fechaConstitucion);
            if (picked != null) setState(() => _fechaConstitucion = picked);
          },
        ),
        const SizedBox(height: 12),
        TextField(controller: _objetoSocialCtrl, decoration: const InputDecoration(labelText: 'Objeto social / giro')),
        const SizedBox(height: 20),
        const SectionLabel('Acta constitutiva'),
        TextField(
          controller: _actaNumeroEscrituraCtrl,
          decoration: const InputDecoration(labelText: 'Número de escritura'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        TextField(controller: _actaNotarioCtrl, decoration: const InputDecoration(labelText: 'Notario público (acta)')),
        const SizedBox(height: 12),
        TextField(controller: _actaPlazaCtrl, decoration: const InputDecoration(labelText: 'Plaza / ciudad del notario')),
        DatePickerField(
          label: 'Fecha del acta',
          value: _actaFecha,
          onPick: () async {
            final picked = await _pickDate(initial: _actaFecha);
            if (picked != null) setState(() => _actaFecha = picked);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _actaFolioRPCCtrl,
          decoration: const InputDecoration(labelText: 'Folio de Registro Público de Comercio'),
        ),
      ],
    );
  }

  Widget _buildDomicilioStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildApoderadosStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Apoderado principal (requerido)'),
        TextField(
          controller: _apoderadoNombreCtrl,
          decoration: const InputDecoration(labelText: 'Nombre completo del apoderado'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<IdDocumentType>(
          initialValue: _apoderadoIdType,
          decoration: const InputDecoration(labelText: 'Tipo de identificación (apoderado)'),
          items: [for (final type in IdDocumentType.values) DropdownMenuItem(value: type, child: Text(type.label))],
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
          onPick: () async {
            final picked = await _pickDate(initial: _apoderadoFechaInstrumento);
            if (picked != null) setState(() => _apoderadoFechaInstrumento = picked);
          },
        ),
        DatePickerField(
          label: 'Vigencia (opcional)',
          value: _apoderadoVigencia,
          onPick: () async {
            final picked = await _pickDate(initial: _apoderadoVigencia, allowFuture: true);
            if (picked != null) setState(() => _apoderadoVigencia = picked);
          },
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
      ],
    );
  }

  Widget _buildBeneficiariosStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Beneficiario controlador mayoritario (requerido)'),
        TextField(
          controller: _beneficiarioNombreCtrl,
          decoration: const InputDecoration(labelText: 'Nombre completo del beneficiario'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<IdDocumentType>(
          initialValue: _beneficiarioIdType,
          decoration: const InputDecoration(labelText: 'Tipo de identificación (beneficiario)'),
          items: [for (final type in IdDocumentType.values) DropdownMenuItem(value: type, child: Text(type.label))],
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
    );
  }

  Widget _buildRevisionStep() {
    final parentLabel = _sinPadre ? 'Sin empresa padre (nueva empresa raíz)' : (_parentClientId ?? '—');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revisa la información antes de crear el Cliente.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        _ReviewRow('Empresa padre', parentLabel),
        _ReviewRow('Razón social', _razonSocialCtrl.text.trim()),
        _ReviewRow('RFC', _rfcCtrl.text.trim()),
        _ReviewRow('Domicilio', '${_streetCtrl.text.trim()}, ${_cityCtrl.text.trim()}, ${_stateCtrl.text.trim()}'),
        _ReviewRow(
          'Apoderado principal',
          '${_apoderadoNombreCtrl.text.trim()} — ${_apoderadoTipoPoder.label}',
        ),
        if (_apoderadosAdicionales.isNotEmpty) _ReviewRow('Apoderados adicionales', '${_apoderadosAdicionales.length}'),
        _ReviewRow(
          'Beneficiario mayoritario',
          '${_beneficiarioNombreCtrl.text.trim()} — ${_beneficiarioPorcentajeCtrl.text.trim()}%',
        ),
        if (_beneficiariosAdicionales.isNotEmpty)
          _ReviewRow('Beneficiarios minoritarios', '${_beneficiariosAdicionales.length}'),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 180, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

/// Lista compacta de personas adicionales (apoderados o beneficiarios)
/// con un botón para agregar una más vía diálogo — reutilizado entre el
/// paso de Apoderados y el de Beneficiarios.
