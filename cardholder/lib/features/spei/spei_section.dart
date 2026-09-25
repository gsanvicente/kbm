import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/models/account_ledger.dart';
import '../../core/models/beneficiary.dart';
import '../../core/models/ledger_entry_type.dart';
import '../../core/models/spei_deposit.dart';
import '../../core/models/spei_payment.dart';
import '../../core/models/spei_payment_status.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/date_format.dart';
import '../../shared_widgets/pdf_download.dart';
import '../../shared_widgets/pdf_statement.dart';
import 'add_beneficiary_dialog.dart';
import 'receipt_dialog.dart';
import 'send_spei_dialog.dart';
import 'spei_repository.dart';

/// Pestaña "Cuenta" — CLABE, Beneficiarios de Pago y pagos SPEI del
/// propio Tarjetahabiente. Ver docs/adr/0021-conector-spei.md y
/// docs/adr/0020-cuenta-individual-tarjetahabiente.md: esto vive a nivel
/// de Cuenta Individual, no de tarjeta — por eso `CardholderShell` la
/// muestra igual para quien tiene una tarjeta activa y `HomeShell` la usa
/// también, sola, para quien todavía no tiene ninguna (ver ese archivo).
class SpeiSection extends StatefulWidget {
  const SpeiSection({super.key, required this.cardholderId, required this.cardholderName, required this.repository});

  final String cardholderId;
  final String cardholderName;
  final SpeiRepository repository;

  @override
  State<SpeiSection> createState() => _SpeiSectionState();
}

class _SpeiData {
  _SpeiData(this.clabe, this.ledger, this.beneficiaries, this.payments, this.deposits);
  final String? clabe;
  final AccountLedger ledger;
  final List<Beneficiary> beneficiaries;
  final List<SpeiPayment> payments;
  final List<SpeiDeposit> deposits;
}

class _SpeiSectionState extends State<SpeiSection> {
  late Future<_SpeiData> _future = _load();
  bool _busy = false;

  Future<_SpeiData> _load() async {
    final clabe = await widget.repository.getClabe(widget.cardholderId);
    final ledger = await widget.repository.getAccountLedger(widget.cardholderId);
    final beneficiaries = await widget.repository.listBeneficiaries(widget.cardholderId);
    final payments = await widget.repository.listPayments(widget.cardholderId);
    final deposits = await widget.repository.listDeposits(widget.cardholderId);
    return _SpeiData(clabe, ledger, beneficiaries, payments, deposits);
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
    // No dependemos de que un refetch (`_reload`) vea el beneficiario
    // recién creado — [added] ya es el objeto real que devolvió el
    // POST, así que se agrega directo al estado ya cargado. Bug real
    // reportado en vivo: la pantalla se quedaba sin el nuevo
    // beneficiario hasta refrescar a mano, aunque el backend sí lo
    // guardaba (confirmado con `GET .../beneficiaries` inmediatamente
    // después del alta) — nunca se pudo aislar si la causa era caché de
    // navegador u otra cosa, así que la pantalla deja de depender por
    // completo del timing de un segundo round-trip para este caso.
    final current = await _future;
    if (!mounted) return;
    setState(() {
      _future = Future.value(
        _SpeiData(current.clabe, current.ledger, [...current.beneficiaries, added], current.payments, current.deposits),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Agregaste a ${added.alias} como beneficiario.')));
  }

  Future<void> _sendMoney(List<Beneficiary> beneficiaries) async {
    final payment = await showDialog<SpeiPayment>(
      context: context,
      builder: (context) => SendSpeiDialog(
        cardholderId: widget.cardholderId,
        beneficiaries: beneficiaries,
        repository: widget.repository,
      ),
    );
    if (payment == null) return;
    _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(speiResultMessage(payment))));
  }

  void _showPaymentReceipt(SpeiPayment p) {
    showDialog(
      context: context,
      builder: (context) => ReceiptDialog(
        title: 'Comprobante de pago',
        amount: p.amount,
        isCredit: false,
        folio: p.id,
        createdAt: p.createdAt,
        rows: [
          ('Beneficiario', p.beneficiaryAlias),
          ('CLABE destino', p.beneficiaryClabe),
          ('Estatus', p.status.label),
          if (p.resolutionNotes != null) ('Notas', p.resolutionNotes!),
        ],
      ),
    );
  }

  Future<void> _downloadStatement(_SpeiData data) async {
    final bytes = await buildStatementPdf(
      accountTitle: 'Cuenta Individual',
      infoFields: [
        MapEntry('Titular', widget.cardholderName),
        MapEntry('CLABE', data.clabe ?? 'No activada'),
      ],
      balance: data.ledger.balance,
      currency: data.ledger.currency,
      periodLabel: 'Historial completo',
      rows: [
        for (final m in data.ledger.movements)
          PdfStatementRow(
            date: formatMovementDate(m.createdAt),
            isCredit: m.type == LedgerEntryType.credit,
            description: m.description ?? '',
            amount: m.amount,
            balanceAfter: m.balanceAfter,
          ),
      ],
    );
    if (!mounted) return;
    try {
      downloadPdf('estado-de-cuenta-${widget.cardholderId}-${DateTime.now().toIso8601String().split('T').first}.pdf', bytes);
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'No se pudo descargar.')));
    }
  }

  void _showDepositReceipt(SpeiDeposit d) {
    showDialog(
      context: context,
      builder: (context) => ReceiptDialog(
        title: 'Comprobante de depósito',
        amount: d.amount,
        isCredit: true,
        folio: d.id,
        createdAt: d.createdAt,
        rows: [
          ('Referencia', d.providerReference),
          ('Estatus', 'Conciliado automáticamente'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SpeiData>(
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
                  _BalanceCard(
                    balance: data.ledger.balance,
                    currency: data.ledger.currency,
                    onDownload: () => _downloadStatement(data),
                  ),
                  const SizedBox(height: 16),
                  _ClabeCard(clabe: data.clabe, busy: _busy, onActivate: _activateClabe, onCopy: _copyClabe),
                  const SizedBox(height: 32),
                  Text('Depósitos recibidos', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (data.deposits.isEmpty)
                    const _EmptyHint(text: 'Aún no has recibido ningún depósito SPEI.')
                  else
                    _DepositsList(deposits: data.deposits, onTapDeposit: _showDepositReceipt),
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
                  if (data.beneficiaries.isEmpty)
                    const _EmptyHint(text: 'Aún no tienes beneficiarios. Agrega uno para poder enviar dinero.')
                  else
                    _BeneficiariesList(beneficiaries: data.beneficiaries),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: data.beneficiaries.isEmpty ? null : () => _sendMoney(data.beneficiaries),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Enviar dinero'),
                  ),
                  const SizedBox(height: 32),
                  Text('Historial de pagos', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (data.payments.isEmpty)
                    const _EmptyHint(text: 'Aún no has enviado ningún pago SPEI.')
                  else
                    _PaymentsList(payments: data.payments, onTapPayment: _showPaymentReceipt),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
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

/// Saldo de la Cuenta Individual — la parte que faltaba para que un
/// Tarjetahabiente sin ninguna tarjeta asignada pueda ver su dinero, ver
/// docs/adr/0020-cuenta-individual-tarjetahabiente.md, punto 3. Incluye
/// "Descargar estado de cuenta" (PDF con branding de KBM, ADR-0022 punto
/// 6) — exporta exactamente los movimientos ya cargados en pantalla,
/// sin ningún endpoint de exportación dedicado.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.currency, required this.onDownload});

  final double balance;
  final String currency;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KoonsColors.border),
      ),
      child: Column(
        children: [
          Text(
            'SALDO DE MI CUENTA',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          Text(
            formatCurrency(balance, currency),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: KoonsColors.navy),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Descargar estado de cuenta'),
          ),
        ],
      ),
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

class _DepositsList extends StatelessWidget {
  const _DepositsList({required this.deposits, required this.onTapDeposit});
  final List<SpeiDeposit> deposits;
  final ValueChanged<SpeiDeposit> onTapDeposit;

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
          for (final d in deposits) ...[
            if (d != deposits.first) const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              onTap: () => onTapDeposit(d),
              leading: CircleAvatar(
                backgroundColor: KoonsColors.green.withValues(alpha: 0.12),
                child: const Icon(Icons.arrow_downward_rounded, color: KoonsColors.green, size: 18),
              ),
              title: const Text('Depósito SPEI', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(formatMovementDate(d.createdAt)),
              trailing: Text(
                '+${formatCurrency(d.amount, 'MXN')}',
                style: const TextStyle(color: KoonsColors.green, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentsList extends StatelessWidget {
  const _PaymentsList({required this.payments, required this.onTapPayment});
  final List<SpeiPayment> payments;
  final ValueChanged<SpeiPayment> onTapPayment;

  Color _colorFor(SpeiPaymentStatus status) {
    switch (status) {
      case SpeiPaymentStatus.executed:
        return KoonsColors.green;
      case SpeiPaymentStatus.pendingApproval:
        return Colors.orange.shade800;
      case SpeiPaymentStatus.rejected:
      case SpeiPaymentStatus.failed:
        return Colors.red.shade700;
    }
  }

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
          for (final p in payments) ...[
            if (p != payments.first) const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              onTap: () => onTapPayment(p),
              leading: CircleAvatar(
                backgroundColor: _colorFor(p.status).withValues(alpha: 0.12),
                child: Icon(Icons.arrow_upward_rounded, color: _colorFor(p.status), size: 18),
              ),
              title: Text(p.beneficiaryAlias, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${formatMovementDate(p.createdAt)} · ${p.status.label}'),
              trailing: Text(
                '−${formatCurrency(p.amount, 'MXN')}',
                style: const TextStyle(color: KoonsColors.navy, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
