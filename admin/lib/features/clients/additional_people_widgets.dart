import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/apoderado_legal.dart';
import '../../core/models/beneficiario_controlador.dart';
import '../../core/models/id_document_type.dart';
import '../../core/models/persona_fisica.dart';
import '../../core/models/tipo_poder.dart';
import '../../core/utils/text_formatters.dart';
import '../../shared_widgets/date_picker_field.dart';
import '../../shared_widgets/section_label.dart';

/// Lista compacta de personas adicionales (apoderados o beneficiarios)
/// con un botón para agregar una más vía diálogo — reutilizado entre el
/// wizard de alta de Cliente y su vista de edición.
class AdditionalPeopleSection<T> extends StatelessWidget {
  const AdditionalPeopleSection({
    super.key,
    required this.sectionLabel,
    required this.addButtonLabel,
    required this.items,
    required this.itemLabel,
    required this.itemSubtitle,
    required this.onRemove,
    required this.onAdd,
  });

  final String sectionLabel;
  final String addButtonLabel;
  final List<T> items;
  final String Function(T) itemLabel;
  final String Function(T) itemSubtitle;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(sectionLabel),
        for (var i = 0; i < items.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(itemLabel(items[i])),
              subtitle: Text(itemSubtitle(items[i])),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                onPressed: () => onRemove(i),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(addButtonLabel),
        ),
      ],
    );
  }
}

class AddApoderadoDialog extends StatefulWidget {
  const AddApoderadoDialog({super.key});

  @override
  State<AddApoderadoDialog> createState() => _AddApoderadoDialogState();
}

class _AddApoderadoDialogState extends State<AddApoderadoDialog> {
  final _nombreCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _numeroEscrituraCtrl = TextEditingController();
  final _notarioCtrl = TextEditingController();
  IdDocumentType _idType = IdDocumentType.ine;
  TipoPoder _tipoPoder = TipoPoder.actosDeAdministracion;
  DateTime? _fechaInstrumento;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _idNumberCtrl.dispose();
    _numeroEscrituraCtrl.dispose();
    _notarioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar apoderado adicional'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre completo')),
              const SizedBox(height: 12),
              DropdownButtonFormField<IdDocumentType>(
                initialValue: _idType,
                decoration: const InputDecoration(labelText: 'Tipo de identificación'),
                items: [for (final type in IdDocumentType.values) DropdownMenuItem(value: type, child: Text(type.label))],
                onChanged: (value) => setState(() => _idType = value ?? _idType),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _idNumberCtrl,
                decoration: const InputDecoration(labelText: 'Número de identificación'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TipoPoder>(
                initialValue: _tipoPoder,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo de poder'),
                items: [for (final tipo in TipoPoder.values) DropdownMenuItem(value: tipo, child: Text(tipo.label))],
                onChanged: (value) => setState(() => _tipoPoder = value ?? _tipoPoder),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _numeroEscrituraCtrl,
                decoration: const InputDecoration(labelText: 'Número de escritura del poder'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              TextField(controller: _notarioCtrl, decoration: const InputDecoration(labelText: 'Notario público')),
              DatePickerField(
                label: 'Fecha del instrumento',
                value: _fechaInstrumento,
                onPick: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _fechaInstrumento = picked);
                },
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
        FilledButton(
          onPressed: () {
            if (_nombreCtrl.text.trim().isEmpty ||
                _idNumberCtrl.text.trim().isEmpty ||
                _numeroEscrituraCtrl.text.trim().isEmpty ||
                _notarioCtrl.text.trim().isEmpty ||
                _fechaInstrumento == null) {
              setState(() => _error = 'Completa todos los campos.');
              return;
            }
            Navigator.pop(
              context,
              ApoderadoLegal(
                persona: PersonaFisica(
                  fullName: _nombreCtrl.text.trim(),
                  idDocumentType: _idType,
                  idDocumentNumber: _idNumberCtrl.text.trim(),
                ),
                tipoPoder: _tipoPoder,
                descripcionPoderEspecial: _tipoPoder.requiereDescripcion ? 'Ver instrumento notarial' : null,
                numeroEscritura: _numeroEscrituraCtrl.text.trim(),
                notario: _notarioCtrl.text.trim(),
                fechaInstrumento: _fechaInstrumento!,
                esPrincipal: false,
              ),
            );
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

class AddBeneficiarioDialog extends StatefulWidget {
  const AddBeneficiarioDialog({super.key});

  @override
  State<AddBeneficiarioDialog> createState() => _AddBeneficiarioDialogState();
}

class _AddBeneficiarioDialogState extends State<AddBeneficiarioDialog> {
  final _nombreCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _porcentajeCtrl = TextEditingController();
  IdDocumentType _idType = IdDocumentType.ine;
  bool _isPep = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _idNumberCtrl.dispose();
    _porcentajeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar beneficiario minoritario'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre completo')),
              const SizedBox(height: 12),
              DropdownButtonFormField<IdDocumentType>(
                initialValue: _idType,
                decoration: const InputDecoration(labelText: 'Tipo de identificación'),
                items: [for (final type in IdDocumentType.values) DropdownMenuItem(value: type, child: Text(type.label))],
                onChanged: (value) => setState(() => _idType = value ?? _idType),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _idNumberCtrl,
                decoration: const InputDecoration(labelText: 'Número de identificación'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _porcentajeCtrl,
                decoration: const InputDecoration(labelText: '% de participación', suffixText: '%'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: percentageInputFormatters,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Persona Políticamente Expuesta (PEP)'),
                value: _isPep,
                onChanged: (value) => setState(() => _isPep = value),
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
        FilledButton(
          onPressed: () {
            final porcentaje = double.tryParse(_porcentajeCtrl.text.trim());
            if (_nombreCtrl.text.trim().isEmpty ||
                _idNumberCtrl.text.trim().isEmpty ||
                porcentaje == null ||
                porcentaje <= 0 ||
                porcentaje > 100) {
              setState(() => _error = 'Completa todos los campos con un porcentaje válido (mayor a 0 y hasta 100).');
              return;
            }
            Navigator.pop(
              context,
              BeneficiarioControlador(
                persona: PersonaFisica(
                  fullName: _nombreCtrl.text.trim(),
                  idDocumentType: _idType,
                  idDocumentNumber: _idNumberCtrl.text.trim(),
                ),
                porcentajeParticipacion: porcentaje,
                isPoliticallyExposed: _isPep,
                esMayoritario: false,
              ),
            );
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
