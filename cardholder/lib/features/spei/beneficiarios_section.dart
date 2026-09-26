import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import 'add_beneficiary_dialog.dart';
import 'spei_repository.dart';
import '../../core/models/beneficiary.dart';

/// Pestaña "Beneficiarios" — CLABE propia y el directorio de a quién se
/// le puede pagar por SPEI. Deliberadamente **no** vive aquí el saldo, ni
/// el historial de pagos/depósitos, ni el botón de enviar dinero — todo
/// eso se mudó a "Inicio"/"Movimientos" (ver
/// docs/adr/0028-reorganizacion-ux-cardholder.md): esta pantalla es
/// gestión de contactos de pago, no una segunda vista de la Cuenta.
/// "Enviar dinero" (en "Inicio") también puede agregar un Beneficiario
/// nuevo sin salir del flujo de envío — este directorio es para
/// administrarlos con calma, no el único lugar donde se puede dar de
/// alta uno.
class BeneficiariosSection extends StatefulWidget {
  const BeneficiariosSection({super.key, required this.cardholderId, required this.repository});

  final String cardholderId;
  final SpeiRepository repository;

  @override
  State<BeneficiariosSection> createState() => _BeneficiariosSectionState();
}

class _BeneficiariosSectionState extends State<BeneficiariosSection> {
  late Future<_Data> _future = _load();
  bool _busy = false;

  Future<_Data> _load() async {
    final clabe = await widget.repository.getClabe(widget.cardholderId);
    final beneficiaries = await widget.repository.listBeneficiaries(widget.cardholderId);
    return _Data(clabe, beneficiaries);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _activateClabe() async {
    setState(() => _busy = true);
    await widget.repository.ensureClabe(widget.cardholderId);
    if (!mounted) return;
    setState(() => _busy = false);
    _reload();
  }

  void _copyClabe(String clabe) {
    Clipboard.setData(ClipboardData(text: clabe));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CLABE copiada.')));
  }

  Future<void> _addBeneficiary() async {
    final added = await showDialog<Beneficiary>(
      context: context,
      builder: (context) => AddBeneficiaryDialog(cardholderId: widget.cardholderId, repository: widget.repository),
    );
    if (added == null) return;
    // Ver ADR-0025: el beneficiario recién creado se agrega directo al
    // estado ya cargado, sin depender de que un refetch lo vea a tiempo.
    final current = await _future;
    if (!mounted) return;
    setState(() {
      _future = Future.value(_Data(current.clabe, [...current.beneficiaries, added]));
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Agregaste a ${added.alias} como beneficiario.')));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Data>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ClabeCard(clabe: data.clabe, busy: _busy, onActivate: _activateClabe, onCopy: _copyClabe),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Text('Beneficiarios', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addBeneficiary,
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                        label: const Text('Agregar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A quién le puedes enviar dinero por SPEI — también puedes agregar uno nuevo desde "Enviar dinero" en Inicio.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  if (data.beneficiaries.isEmpty)
                    const _EmptyHint(text: 'Aún no tienes beneficiarios. Agrega uno para poder enviar dinero.')
                  else
                    _BeneficiariesList(beneficiaries: data.beneficiaries),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Data {
  _Data(this.clabe, this.beneficiaries);
  final String? clabe;
  final List<Beneficiary> beneficiaries;
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic)),
    );
  }
}

class _ClabeCard extends StatelessWidget {
  const _ClabeCard({required this.clabe, required this.busy, required this.onActivate, required this.onCopy});

  final String? clabe;
  final bool busy;
  final VoidCallback onActivate;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KoonsColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: KoonsColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_rounded, color: KoonsColors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MI CLABE',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  clabe ?? 'Aún no la has activado',
                  style: TextStyle(
                    fontSize: clabe != null ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    color: clabe != null ? KoonsColors.navy : Colors.grey.shade500,
                    fontStyle: clabe != null ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
                if (clabe == null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Actívala para recibir dinero por SPEI desde fuera de KBM.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else if (clabe == null)
            FilledButton(onPressed: onActivate, child: const Text('Activar'))
          else
            IconButton(
              onPressed: () => onCopy(clabe!),
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: 'Copiar CLABE',
            ),
        ],
      ),
    );
  }
}

class _BeneficiariesList extends StatelessWidget {
  const _BeneficiariesList({required this.beneficiaries});
  final List<Beneficiary> beneficiaries;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KoonsColors.border),
      ),
      child: Column(
        children: [
          for (final b in beneficiaries) ...[
            if (b != beneficiaries.first) const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: KoonsColors.blue.withValues(alpha: 0.1),
                child: Text(
                  b.alias.isNotEmpty ? b.alias[0].toUpperCase() : '?',
                  style: const TextStyle(color: KoonsColors.blue, fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(b.alias, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${b.bankName} · ${b.maskedClabe}'),
              trailing: b.isCooling
                  ? Tooltip(
                      message: 'Beneficiario nuevo: montos grandes limitados por 24 horas',
                      child: Icon(Icons.hourglass_top_rounded, size: 18, color: Colors.orange.shade700),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
